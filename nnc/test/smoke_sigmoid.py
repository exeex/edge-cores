"""Minimal sigmoid model used to smoke-test NNC lowering."""

from __future__ import annotations

import torch
import torch.nn as nn
from torch import Tensor


class SmokeSigmoid(nn.Module):
    def forward(self, x: Tensor) -> Tensor:
        return torch.sigmoid(x)


def make_example_args() -> tuple[Tensor]:
    x = torch.arange(64 * 64, dtype=torch.float32).reshape(64, 64)
    return ((x.remainder(33) - 16) / 4,)


def make_model_and_args() -> tuple[SmokeSigmoid, tuple[Tensor]]:
    return SmokeSigmoid(), make_example_args()
