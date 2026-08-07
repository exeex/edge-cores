"""Dynamic-shape linear smoke for 8-aligned non-64 dimensions."""

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


class SmokeLinearDynamic(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        weight = torch.arange(48 * 56, dtype=torch.float32).reshape(48, 56)
        weight = (weight.remainder(23) - 11) / 64
        self.weight = nn.Parameter(weight)

    def forward(self, x: Tensor) -> Tensor:
        return torch.ops.nnedge.linear(x, self.weight)


def make_example_args() -> tuple[Tensor]:
    x = torch.arange(32 * 56, dtype=torch.float32).reshape(32, 56)
    x = (x.remainder(19) - 9) / 16
    return (x,)


def make_model_and_args() -> tuple[SmokeLinearDynamic, tuple[Tensor]]:
    return SmokeLinearDynamic(), make_example_args()
