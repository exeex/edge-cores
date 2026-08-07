"""32x32 softmax smoke matching the tiny Llama attention score shape."""

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


class SmokeSoftmax32(nn.Module):
    def forward(self, x: Tensor) -> Tensor:
        return torch.ops.nnedge.softmax(x)


def make_example_args() -> tuple[Tensor]:
    x = torch.arange(32 * 32, dtype=torch.float32).reshape(32, 32)
    x = (x.remainder(17) - 8) / 8
    return (x,)


def make_model_and_args() -> tuple[SmokeSoftmax32, tuple[Tensor]]:
    return SmokeSoftmax32(), make_example_args()
