"""Dynamic linear smoke with more than one 32-token tensor tile."""

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


class SmokeLinearDynamicTokens(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        weight = torch.arange(48 * 56, dtype=torch.float32).reshape(48, 56)
        weight = (weight.remainder(29) - 14) / 64
        self.weight = nn.Parameter(weight)

    def forward(self, x: Tensor) -> Tensor:
        return torch.ops.nnedge.linear(x, self.weight)


def make_example_args() -> tuple[Tensor]:
    x = torch.arange(48 * 56, dtype=torch.float32).reshape(48, 56)
    x = (x.remainder(31) - 15) / 32
    return (x,)


def make_model_and_args() -> tuple[SmokeLinearDynamicTokens, tuple[Tensor]]:
    return SmokeLinearDynamicTokens(), make_example_args()
