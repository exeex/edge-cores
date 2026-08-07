"""Llama-sized gated feed-forward smoke for composed accelerator paths."""

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


class SmokeFeedForward(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        torch.manual_seed(0)
        self.w1_weight = nn.Parameter(torch.randn(192, 64) * 0.02)
        self.w2_weight = nn.Parameter(torch.randn(64, 192) * 0.02)
        self.w3_weight = nn.Parameter(torch.randn(192, 64) * 0.02)

    def forward(self, x: Tensor) -> Tensor:
        w1 = torch.ops.nnedge.linear(x, self.w1_weight)
        w3 = torch.ops.nnedge.linear(x, self.w3_weight)
        return torch.ops.nnedge.linear(F.silu(w1) * w3, self.w2_weight)


def make_example_args() -> tuple[Tensor]:
    torch.manual_seed(1)
    return (torch.randn(32, 64, dtype=torch.float32),)


def make_model_and_args() -> tuple[SmokeFeedForward, tuple[Tensor]]:
    return SmokeFeedForward(), make_example_args()
