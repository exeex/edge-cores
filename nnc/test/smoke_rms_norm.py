"""Minimal RMSNorm model used to smoke-test NNC lowering."""

from __future__ import annotations

import os

import torch
import torch.nn as nn
from torch import Tensor


@torch.library.custom_op("nnedge::rms_norm", mutates_args=())
def nnedge_rms_norm(x: Tensor, weight: Tensor, eps: float) -> Tensor:
    scale = torch.rsqrt(x.float().pow(2).mean(-1, keepdim=True) + eps)
    return (x.float() * scale).type_as(x) * weight


@nnedge_rms_norm.register_fake
def _(x, weight, eps):
    del weight, eps
    return torch.empty_like(x)


class SmokeRmsNorm(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        weight = torch.arange(64, dtype=torch.float32)
        self.weight = nn.Parameter(1.0 + weight / 128.0)
        self.eps = 1.0e-5

    def forward(self, x: Tensor) -> Tensor:
        return torch.ops.nnedge.rms_norm(x, self.weight, self.eps)


def make_example_args() -> tuple[Tensor]:
    x = torch.arange(64 * 64, dtype=torch.float32).reshape(64, 64)
    x = (x.remainder(31) - 15) / 8
    x = x * float(os.environ.get("NNEDGE_RMS_INPUT_SCALE", "1.0"))
    return (x,)


def make_model_and_args() -> tuple[SmokeRmsNorm, tuple[Tensor]]:
    return SmokeRmsNorm(), make_example_args()
