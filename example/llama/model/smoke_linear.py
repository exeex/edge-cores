"""Minimal linear model used to smoke-test the NNC C++ shell."""

from __future__ import annotations

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch import Tensor


@torch.library.custom_op("nnedge::linear", mutates_args=())
def nnedge_linear(x: Tensor, weight: Tensor) -> Tensor:
    return F.linear(x, weight)


@nnedge_linear.register_fake
def _(x, weight):
    return torch.empty((*x.shape[:-1], weight.shape[0]), dtype=x.dtype, device=x.device)


class SmokeLinear(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.weight = nn.Parameter(torch.eye(64, dtype=torch.float32))

    def forward(self, x: Tensor) -> Tensor:
        return torch.ops.nnedge.linear(x, self.weight)


def make_example_args() -> tuple[Tensor]:
    x = torch.arange(64 * 64, dtype=torch.float32).reshape(64, 64)
    x = (x.remainder(17) - 8) / 4
    return (x,)


def make_model_and_args() -> tuple[SmokeLinear, tuple[Tensor]]:
    return SmokeLinear(), make_example_args()
