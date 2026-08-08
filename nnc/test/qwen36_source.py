"""Tiny Qwen3.6 full-attention decoder layer for NNC coverage testing.

Qwen3.6 uses the Qwen3.5 text backbone.  This 32x64 slice preserves the
full-attention layer's Q/K RMSNorm, attention output gate, SwiGLU MLP, and two
residual paths.  A single attention head keeps the semantic attention boundary
compatible with the current runtime; see ``qwen36_coverage.md`` for omitted
Qwen3.6 features and the compiler gaps they expose.
"""

from __future__ import annotations

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch import Tensor


@torch.library.custom_op("nnedge::rms_norm", mutates_args=())
def nnedge_rms_norm(x: Tensor, weight: Tensor, eps: float) -> Tensor:
    normalized = x.float() * torch.rsqrt(x.float().pow(2).mean(-1, keepdim=True) + eps)
    return normalized.type_as(x) * weight


@nnedge_rms_norm.register_fake
def _(x, weight, eps):
    del weight, eps
    return torch.empty_like(x)


def rope_reference(x: Tensor, start_pos: Tensor) -> Tensor:
    tokens, dim = x.shape
    pair = torch.arange(0, dim, 2, dtype=torch.float32, device=x.device)
    theta = 1.0 / (10000.0 ** (pair / dim))
    pos = torch.arange(tokens, dtype=torch.float32, device=x.device) + start_pos.float()
    angles = pos[:, None] * theta[None, :]
    cos, sin = torch.cos(angles).type_as(x), torch.sin(angles).type_as(x)
    even, odd = x[:, 0::2], x[:, 1::2]
    out = torch.empty_like(x)
    out[:, 0::2] = even * cos - odd * sin
    out[:, 1::2] = even * sin + odd * cos
    return out


@torch.library.custom_op("nnedge::rope", mutates_args=())
def nnedge_rope(xq: Tensor, xk: Tensor, start_pos: Tensor) -> tuple[Tensor, Tensor]:
    return rope_reference(xq, start_pos), rope_reference(xk, start_pos)


@nnedge_rope.register_fake
def _(xq, xk, start_pos):
    del start_pos
    return torch.empty_like(xq), torch.empty_like(xk)


@torch.library.custom_op("nnedge::kv_cache_update", mutates_args=())
def nnedge_kv_cache_update(xk: Tensor, xv: Tensor, start_pos: Tensor) -> tuple[Tensor, Tensor]:
    del start_pos
    return xk.clone(), xv.clone()


@nnedge_kv_cache_update.register_fake
def _(xk, xv, start_pos):
    del start_pos
    return torch.empty_like(xk), torch.empty_like(xv)


@torch.library.custom_op("nnedge::attention", mutates_args=())
def nnedge_attention(xq: Tensor, keys: Tensor, values: Tensor,
                     mask_or_params: Tensor, head_count: int) -> Tensor:
    del mask_or_params
    tokens, width = xq.shape
    head_dim = width // head_count
    q = xq.view(tokens, head_count, head_dim).transpose(0, 1)
    k = keys.view(tokens, head_count, head_dim).transpose(0, 1)
    v = values.view(tokens, head_count, head_dim).transpose(0, 1)
    scores = torch.matmul(q, k.transpose(-2, -1))
    probs = F.softmax(scores.float(), dim=-1).type_as(xq)
    return torch.matmul(probs, v).transpose(0, 1).contiguous().view(tokens, width)


@nnedge_attention.register_fake
def _(xq, keys, values, mask_or_params, head_count):
    del keys, mask_or_params, head_count
    return torch.empty_strided(xq.shape, xq.stride(), dtype=values.dtype, device=values.device)


@torch.library.custom_op("nnedge::linear", mutates_args=())
def nnedge_linear(x: Tensor, weight: Tensor) -> Tensor:
    return F.linear(x, weight)


@nnedge_linear.register_fake
def _(x, weight):
    return torch.empty((*x.shape[:-1], weight.shape[0]), dtype=x.dtype, device=x.device)


class RMSNorm(nn.Module):
    def __init__(self, width: int, eps: float = 1.0e-6):
        super().__init__()
        self.eps = eps
        # Qwen stores a zero-centred delta and applies (1 + weight).  NNC's
        # semantic op receives the already-materialized effective multiplier.
        self.weight = nn.Parameter(torch.ones(width))

    def forward(self, x: Tensor) -> Tensor:
        return torch.ops.nnedge.rms_norm(x, self.weight, self.eps)


class TinyQwen36FullAttentionLayer(nn.Module):
    def __init__(self, width: int = 64, intermediate: int = 128):
        super().__init__()
        self.input_layernorm = RMSNorm(width)
        self.post_attention_layernorm = RMSNorm(width)
        self.q_norm = RMSNorm(width)
        self.k_norm = RMSNorm(width)
        self.q_weight = nn.Parameter(torch.empty(width, width))
        self.gate_weight = nn.Parameter(torch.empty(width, width))
        self.k_weight = nn.Parameter(torch.empty(width, width))
        self.v_weight = nn.Parameter(torch.empty(width, width))
        self.o_weight = nn.Parameter(torch.empty(width, width))
        self.mlp_gate_weight = nn.Parameter(torch.empty(intermediate, width))
        self.mlp_up_weight = nn.Parameter(torch.empty(intermediate, width))
        self.mlp_down_weight = nn.Parameter(torch.empty(width, intermediate))

    def forward(self, x: Tensor, start_pos: Tensor, mask_or_params: Tensor) -> Tensor:
        normed = self.input_layernorm(x)
        query = self.q_norm(torch.ops.nnedge.linear(normed, self.q_weight))
        gate = torch.ops.nnedge.linear(normed, self.gate_weight)
        key = self.k_norm(torch.ops.nnedge.linear(normed, self.k_weight))
        value = torch.ops.nnedge.linear(normed, self.v_weight)
        query, key = torch.ops.nnedge.rope(query, key, start_pos)
        keys, values = torch.ops.nnedge.kv_cache_update(key, value, start_pos)
        attended = torch.ops.nnedge.attention(query, keys, values, mask_or_params, 1)
        gated = attended * torch.sigmoid(gate)
        hidden = x + torch.ops.nnedge.linear(gated, self.o_weight)
        mlp_input = self.post_attention_layernorm(hidden)
        mlp_gate = torch.ops.nnedge.linear(mlp_input, self.mlp_gate_weight)
        mlp_up = torch.ops.nnedge.linear(mlp_input, self.mlp_up_weight)
        mlp = torch.ops.nnedge.linear(F.silu(mlp_gate) * mlp_up, self.mlp_down_weight)
        return hidden + mlp


def make_model_and_args() -> tuple[TinyQwen36FullAttentionLayer, tuple[Tensor, Tensor, Tensor]]:
    torch.manual_seed(36)
    model = TinyQwen36FullAttentionLayer()
    for name, parameter in model.named_parameters():
        if name.endswith("layernorm.weight") or name in {"q_norm.weight", "k_norm.weight"}:
            parameter.data.fill_(1.0)
        else:
            parameter.data.copy_(torch.randn_like(parameter) * 0.02)
    args = (
        torch.randn(32, 64, dtype=torch.float32),
        torch.tensor(0, dtype=torch.int64),
        torch.zeros(32, 32, dtype=torch.float32),
    )
    return model, args
