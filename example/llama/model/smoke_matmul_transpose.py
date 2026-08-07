"""Minimal matmul-transpose model used to smoke-test NNC lowering."""

from __future__ import annotations

import torch
import torch.nn as nn
from torch import Tensor


@torch.library.custom_op("nnedge::matmul_transpose", mutates_args=())
def nnedge_matmul_transpose(lhs: Tensor, rhs: Tensor, head_count: int) -> Tensor:
    rows, width = lhs.shape
    head_width = width // head_count
    lhs_heads = (lhs.view(head_count, head_width // 8, rows, 8)
                 .permute(0, 2, 1, 3).contiguous().view(head_count, rows, head_width))
    rhs_heads = rhs.view(rhs.shape[0], head_count, head_width).transpose(0, 1)
    output = torch.matmul(lhs_heads, rhs_heads.transpose(-2, -1))
    return (output.view(head_count, rows, rhs.shape[0] // 8, 8)
            .permute(0, 2, 1, 3).contiguous()
            .view(head_count, rows, rhs.shape[0]))


@nnedge_matmul_transpose.register_fake
def _(lhs, rhs, head_count):
    return torch.empty((head_count, lhs.shape[0], rhs.shape[0]), dtype=lhs.dtype, device=lhs.device)


class SmokeMatmulTranspose(nn.Module):
    def forward(self, x: Tensor, rhs: Tensor) -> Tensor:
        return torch.ops.nnedge.matmul_transpose(x, rhs, 2)


def make_example_args() -> tuple[Tensor, Tensor]:
    # Match the tiny Llama attention score product exactly: two heads of
    # [32, 32] x [32, 32]^T in full-width token-major storage.
    x = torch.arange(32 * 64, dtype=torch.float32).reshape(32, 64)
    rhs = torch.arange(32 * 64, dtype=torch.float32).reshape(32, 64)
    x = (x.remainder(23) - 11) / 8
    rhs = (rhs.remainder(17) - 8) / 16
    x = (x.view(32, 2, 4, 8).permute(1, 2, 0, 3)
         .contiguous().view(32, 64))
    return x, rhs


def make_model_and_args() -> tuple[SmokeMatmulTranspose, tuple[Tensor, Tensor]]:
    return SmokeMatmulTranspose(), make_example_args()
