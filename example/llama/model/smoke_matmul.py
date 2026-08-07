"""Minimal matmul models used to smoke-test NNC lowering."""

from __future__ import annotations

import torch
import torch.nn as nn
from torch import Tensor


@torch.library.custom_op("nnedge::matmul", mutates_args=())
def nnedge_matmul(lhs: Tensor, rhs: Tensor, head_count: int) -> Tensor:
    heads, rows, head_width = lhs.shape
    lhs = (lhs.view(heads, head_width // 8, rows, 8)
           .permute(0, 2, 1, 3).contiguous().view(heads, rows, head_width))
    head_width = rhs.shape[1] // head_count
    rhs_heads = rhs.view(rhs.shape[0], head_count, head_width).transpose(0, 1)
    output_heads = torch.matmul(lhs, rhs_heads)
    packed = (output_heads.view(head_count, rows, head_width // 8, 8)
              .permute(0, 2, 1, 3).contiguous())
    return packed.view(rows, rhs.shape[1])


@nnedge_matmul.register_fake
def _(lhs, rhs, head_count):
    del head_count
    return torch.empty((lhs.shape[1], rhs.shape[1]), dtype=lhs.dtype, device=lhs.device)


class SmokeMatmul(nn.Module):
    def forward(self, x: Tensor, rhs: Tensor) -> Tensor:
        return torch.ops.nnedge.matmul(x, rhs, 2)


def make_example_args() -> tuple[Tensor, Tensor]:
    # Match the tiny Llama attention value product exactly: two heads of
    # [32, 32] x [32, 32], with values stored as [tokens, full_width].
    x = torch.arange(2 * 32 * 32, dtype=torch.float32).reshape(2, 32, 32)
    rhs = torch.arange(32 * 64, dtype=torch.float32).reshape(32, 64)
    x = (x.remainder(19) - 9) / 8
    rhs = (rhs.remainder(17) - 8) / 16
    x = x.view(2, 32, 4, 8).permute(0, 2, 1, 3).contiguous().view(2, 32, 32)
    return x, rhs


def make_model_and_args() -> tuple[SmokeMatmul, tuple[Tensor, Tensor]]:
    return SmokeMatmul(), make_example_args()
