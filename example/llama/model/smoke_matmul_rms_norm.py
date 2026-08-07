"""Composed runtime matmul followed by RMSNorm."""

from __future__ import annotations

import torch
import torch.nn as nn
from torch import Tensor


@torch.library.custom_op("nnedge::matmul", mutates_args=())
def nnedge_matmul(lhs: Tensor, rhs: Tensor) -> Tensor:
    return torch.matmul(lhs, rhs)


@nnedge_matmul.register_fake
def _(lhs, rhs):
    return torch.empty((lhs.shape[0], rhs.shape[1]), dtype=lhs.dtype, device=lhs.device)


@torch.library.custom_op("nnedge::rms_norm", mutates_args=())
def nnedge_rms_norm(x: Tensor, weight: Tensor, eps: float) -> Tensor:
    scale = torch.rsqrt(x.float().pow(2).mean(-1, keepdim=True) + eps)
    return (x.float() * scale).type_as(x) * weight


@nnedge_rms_norm.register_fake
def _(x, weight, eps):
    del weight, eps
    return torch.empty_like(x)


class SmokeMatmulRmsNorm(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.weight = nn.Parameter(torch.ones(64, dtype=torch.float32))

    def forward(self, x: Tensor, rhs: Tensor) -> Tensor:
        product = torch.ops.nnedge.matmul(x, rhs)
        return torch.ops.nnedge.rms_norm(product, self.weight, 1.0e-5)


def make_model_and_args():
    torch.manual_seed(7)
    x = torch.randn(32, 64, dtype=torch.float32)
    rhs = torch.randn(64, 64, dtype=torch.float32) * 0.02
    return SmokeMatmulRmsNorm(), (x, rhs)
