"""Minimal add model used to smoke-test NNC lowering."""

from __future__ import annotations

import torch
import torch.nn as nn
from torch import Tensor


class SmokeAdd(nn.Module):
    def forward(self, x: Tensor, rhs: Tensor) -> Tensor:
        return torch.ops.aten.add.Tensor(x, rhs)


def make_example_args() -> tuple[Tensor, Tensor]:
    x = torch.arange(64 * 64, dtype=torch.float32).reshape(64, 64)
    rhs = torch.arange(64 * 64, dtype=torch.float32).reshape(64, 64)
    x = (x.remainder(17) - 8) / 8
    rhs = (rhs.remainder(19) - 9) / 16
    return x, rhs


def make_model_and_args() -> tuple[SmokeAdd, tuple[Tensor, Tensor]]:
    return SmokeAdd(), make_example_args()
