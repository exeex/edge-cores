"""Minimal mul model used to smoke-test NNC lowering."""

from __future__ import annotations

import torch
import torch.nn as nn
from torch import Tensor


class SmokeMul(nn.Module):
    def forward(self, x: Tensor, rhs: Tensor) -> Tensor:
        return x * rhs


def make_example_args() -> tuple[Tensor, Tensor]:
    x = torch.arange(64 * 64, dtype=torch.float32).reshape(64, 64)
    rhs = torch.arange(64 * 64, dtype=torch.float32).reshape(64, 64)
    x = (x.remainder(17) - 8) / 8
    rhs = (rhs.remainder(13) - 6) / 8
    return x, rhs


def make_model_and_args() -> tuple[SmokeMul, tuple[Tensor, Tensor]]:
    return SmokeMul(), make_example_args()
