"""Minimal SiLU model used to smoke-test NNC lowering."""

from __future__ import annotations

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch import Tensor


class SmokeSilu(nn.Module):
    def forward(self, x: Tensor) -> Tensor:
        return F.silu(x)


def make_example_args() -> tuple[Tensor]:
    x = torch.arange(64 * 64, dtype=torch.float32).reshape(64, 64)
    x = (x.remainder(33) - 16) / 4
    return (x,)


def make_model_and_args() -> tuple[SmokeSilu, tuple[Tensor]]:
    return SmokeSilu(), make_example_args()
