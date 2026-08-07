"""Small Llama-style source model for NNC lowering experiments.

The structure mirrors Meta Llama's `model.py`, but compiler-hostile pieces are
explicit `nnedge` custom ops. Those ops are the semantic boundaries NNC lowers
to hand-written C++ functions: RMSNorm, RoPE, KV cache update, and attention.
"""

from __future__ import annotations

from dataclasses import dataclass

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch import Tensor


@torch.library.custom_op("nnedge::rms_norm", mutates_args=())
def nnedge_rms_norm(x: Tensor, weight: Tensor, eps: float) -> Tensor:
    return (x.float() * torch.rsqrt(x.float().pow(2).mean(-1, keepdim=True) + eps)).type_as(x) * weight


@nnedge_rms_norm.register_fake
def _(x, weight, eps):
    del weight, eps
    return torch.empty_like(x)


def rope_reference(x: Tensor, start_pos: Tensor) -> Tensor:
    tokens, dim = x.shape
    pair = torch.arange(0, dim, 2, dtype=torch.float32, device=x.device)
    theta = 1.0 / (10000.0 ** (pair / dim))
    pos = torch.arange(tokens, dtype=torch.float32, device=x.device) + start_pos.to(torch.float32)
    angles = pos[:, None] * theta[None, :]
    cos = torch.cos(angles).type_as(x)
    sin = torch.sin(angles).type_as(x)
    even = x[:, 0::2]
    odd = x[:, 1::2]
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
    query_len, width = xq.shape
    key_len = keys.shape[0]
    head_dim = width // head_count
    q_heads = xq.view(query_len, head_count, head_dim).transpose(0, 1)
    k_heads = keys.view(key_len, head_count, head_dim).transpose(0, 1)
    v_heads = values.view(key_len, head_count, head_dim).transpose(0, 1)
    scores = torch.matmul(q_heads, k_heads.transpose(-2, -1))
    scores = F.softmax(scores.float(), dim=-1).type_as(xq)
    context = torch.matmul(scores, v_heads)
    return context.transpose(0, 1).contiguous().view(query_len, width)


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


@dataclass(frozen=True)
class ModelArgs:
    dim: int = 64
    n_heads: int = 2
    n_kv_heads: int | None = None
    multiple_of: int = 64
    ffn_dim_multiplier: float | None = None
    norm_eps: float = 1.0e-5


def llama_hidden_dim(args: ModelArgs) -> int:
    hidden_dim = int(2 * (4 * args.dim) / 3)
    if args.ffn_dim_multiplier is not None:
        hidden_dim = int(args.ffn_dim_multiplier * hidden_dim)
    return args.multiple_of * ((hidden_dim + args.multiple_of - 1) // args.multiple_of)


class RMSNorm(nn.Module):
    def __init__(self, dim: int, eps: float):
        super().__init__()
        self.eps = eps
        self.weight = nn.Parameter(torch.ones(dim))

    def forward(self, x: Tensor) -> Tensor:
        return torch.ops.nnedge.rms_norm(x, self.weight, self.eps)


class Attention(nn.Module):
    def __init__(self, args: ModelArgs):
        super().__init__()
        self.n_heads = args.n_heads
        self.n_kv_heads = args.n_heads if args.n_kv_heads is None else args.n_kv_heads
        self.head_dim = args.dim // args.n_heads

        self.wq_weight = nn.Parameter(torch.empty(args.n_heads * self.head_dim, args.dim))
        self.wk_weight = nn.Parameter(torch.empty(self.n_kv_heads * self.head_dim, args.dim))
        self.wv_weight = nn.Parameter(torch.empty(self.n_kv_heads * self.head_dim, args.dim))
        self.wo_weight = nn.Parameter(torch.empty(args.dim, args.n_heads * self.head_dim))

    def forward(self, x: Tensor, start_pos: Tensor, mask_or_params: Tensor) -> Tensor:
        xq = torch.ops.nnedge.linear(x, self.wq_weight)
        xk = torch.ops.nnedge.linear(x, self.wk_weight)
        xv = torch.ops.nnedge.linear(x, self.wv_weight)
        xq, xk = torch.ops.nnedge.rope(xq, xk, start_pos)
        keys, values = torch.ops.nnedge.kv_cache_update(xk, xv, start_pos)
        attn = torch.ops.nnedge.attention(
            xq, keys, values, mask_or_params, self.n_heads
        )
        return torch.ops.nnedge.linear(attn, self.wo_weight)


class FeedForward(nn.Module):
    def __init__(self, args: ModelArgs):
        super().__init__()
        hidden_dim = llama_hidden_dim(args)
        self.w1_weight = nn.Parameter(torch.empty(hidden_dim, args.dim))
        self.w2_weight = nn.Parameter(torch.empty(args.dim, hidden_dim))
        self.w3_weight = nn.Parameter(torch.empty(hidden_dim, args.dim))

    def forward(self, x: Tensor) -> Tensor:
        w1 = torch.ops.nnedge.linear(x, self.w1_weight)
        w3 = torch.ops.nnedge.linear(x, self.w3_weight)
        return torch.ops.nnedge.linear(F.silu(w1) * w3, self.w2_weight)


class TransformerBlock(nn.Module):
    def __init__(self, args: ModelArgs):
        super().__init__()
        self.attention = Attention(args)
        self.feed_forward = FeedForward(args)
        self.attention_norm = RMSNorm(args.dim, eps=args.norm_eps)
        self.ffn_norm = RMSNorm(args.dim, eps=args.norm_eps)

    def forward(self, x: Tensor, start_pos: Tensor, mask_or_params: Tensor) -> Tensor:
        h = torch.ops.aten.add.Tensor(
            x,
            self.attention(self.attention_norm(x), start_pos, mask_or_params),
        )
        return torch.ops.aten.add.Tensor(h, self.feed_forward(self.ffn_norm(h)))


def make_tiny_llama_block() -> TransformerBlock:
    torch.manual_seed(0)
    model = TransformerBlock(ModelArgs())
    for name, param in model.named_parameters():
        if name.endswith("norm.weight"):
            param.data.fill_(1.0)
        else:
            param.data.copy_(torch.randn_like(param) * 0.02)
    return model


def make_example_args() -> tuple[Tensor, Tensor, Tensor]:
    return (
        torch.randn(32, 64, dtype=torch.float32),
        torch.tensor(0, dtype=torch.int64),
        torch.zeros(32, 32, dtype=torch.float32),
    )


def make_model_and_args() -> tuple[TransformerBlock, tuple[Tensor, Tensor, Tensor]]:
    return make_tiny_llama_block(), make_example_args()
