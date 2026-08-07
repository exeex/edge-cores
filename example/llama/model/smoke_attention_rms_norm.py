"""Composed fused attention followed by RMSNorm."""

from __future__ import annotations

import os

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch import Tensor


@torch.library.custom_op("nnedge::attention", mutates_args=())
def nnedge_attention(xq: Tensor, keys: Tensor, values: Tensor, params: Tensor) -> Tensor:
    del params
    scores = torch.matmul(xq, keys.transpose(-2, -1))
    probs = F.softmax(scores.float(), dim=-1).type_as(xq)
    return torch.matmul(probs, values)


@nnedge_attention.register_fake
def _(xq, keys, values, params):
    del keys, params
    return torch.empty_strided(xq.shape, xq.stride(), dtype=values.dtype, device=values.device)


@torch.library.custom_op("nnedge::rms_norm", mutates_args=())
def nnedge_rms_norm(x: Tensor, weight: Tensor, eps: float) -> Tensor:
    scale = torch.rsqrt(x.float().pow(2).mean(-1, keepdim=True) + eps)
    return (x.float() * scale).type_as(x) * weight


@nnedge_rms_norm.register_fake
def _(x, weight, eps):
    del weight, eps
    return torch.empty_like(x)


class SmokeAttentionRmsNorm(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.pre_norm = os.environ.get("NNEDGE_ATTENTION_PRE_RMS", "0") == "1"
        self.pre_weight = nn.Parameter(torch.ones(64, dtype=torch.float32))
        self.weight = nn.Parameter(torch.ones(64, dtype=torch.float32))

    def forward(self, xq: Tensor, keys: Tensor, values: Tensor, params: Tensor) -> Tensor:
        if self.pre_norm:
            xq = torch.ops.nnedge.rms_norm(xq, self.pre_weight, 1.0e-5)
        context = torch.ops.nnedge.attention(xq, keys, values, params)
        return torch.ops.nnedge.rms_norm(context, self.weight, 1.0e-5)


def make_model_and_args():
    torch.manual_seed(11)
    xq = torch.randn(32, 64, dtype=torch.float32) * 0.1
    keys = torch.randn(32, 64, dtype=torch.float32) * 0.1
    values = torch.randn(32, 64, dtype=torch.float32) * 0.1
    params = torch.zeros(1, dtype=torch.float32)
    return SmokeAttentionRmsNorm(), (xq, keys, values, params)
