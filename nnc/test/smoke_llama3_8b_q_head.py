"""Llama 3 8B eight-token Q projection for one attention head."""

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
    return torch.empty((*x.shape[:-1], weight.shape[0]),
                       dtype=x.dtype, device=x.device)


class Llama3QHead(nn.Module):
    hidden_size = 4096
    head_dim = 128

    def __init__(self) -> None:
        super().__init__()
        weight = torch.zeros((self.head_dim, self.hidden_size),
                             dtype=torch.float32)
        for out_col in range(self.head_dim):
            weight[out_col, (out_col * 31 + 7) % self.hidden_size] = 1.0
        self.weight = nn.Parameter(weight)

    def forward(self, x: Tensor) -> Tensor:
        return torch.ops.nnedge.linear(x, self.weight)


def make_example_args() -> tuple[Tensor]:
    x = torch.arange(8 * Llama3QHead.hidden_size, dtype=torch.float32)
    x = ((x * 5 + 3).remainder(13) - 6).reshape(8, -1)
    return (x,)


def make_model_and_args() -> tuple[Llama3QHead, tuple[Tensor]]:
    return Llama3QHead(), make_example_args()
