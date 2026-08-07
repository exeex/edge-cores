"""Minimal softmax model used to smoke-test NNC lowering."""

from __future__ import annotations

import torch
import torch.nn as nn
from torch import Tensor


@torch.library.custom_op("nnedge::softmax", mutates_args=())
def nnedge_softmax(x: Tensor) -> Tensor:
    return torch.softmax(x, dim=-1)


@nnedge_softmax.register_fake
def _(x):
    return torch.empty_like(x)


class SmokeSoftmax(nn.Module):
    def forward(self, x: Tensor) -> Tensor:
        return torch.ops.nnedge.softmax(x)


def make_example_args() -> tuple[Tensor]:
    x = torch.arange(64 * 64, dtype=torch.float32).reshape(64, 64)
    x = (x.remainder(17) - 8) / 8
    return (x,)


def make_model_and_args() -> tuple[SmokeSoftmax, tuple[Tensor]]:
    return SmokeSoftmax(), make_example_args()
