"""Minimal RoPE model used to smoke-test NNC lowering."""

from __future__ import annotations

import torch
import torch.nn as nn
from torch import Tensor


@torch.library.custom_op("nnedge::rope", mutates_args=())
def nnedge_rope(xq: Tensor, xk: Tensor, start_pos: Tensor) -> tuple[Tensor, Tensor]:
    return rope_reference(xq, start_pos), rope_reference(xk, start_pos)


@nnedge_rope.register_fake
def _(xq, xk, start_pos):
    del start_pos
    return torch.empty_like(xq), torch.empty_like(xk)


def rope_reference(x: Tensor, start_pos: Tensor) -> Tensor:
    tokens, dim = x.shape
    pair = torch.arange(0, dim, 2, dtype=torch.float32, device=x.device)
    theta = 1.0 / (10000.0 ** (pair / dim))
    pos = torch.arange(tokens, dtype=torch.float32, device=x.device) + start_pos.to(torch.float32)
    angles = pos[:, None] * theta[None, :]
    cos = torch.cos(angles).type_as(x)
    sin = torch.sin(angles).type_as(x)
    even = x[:, 0::2]
    odd = x[:, 1::2]
    out = torch.empty_like(x)
    out[:, 0::2] = even * cos - odd * sin
    out[:, 1::2] = even * sin + odd * cos
    return out


class SmokeRope(nn.Module):
    def forward(self, xq: Tensor, xk: Tensor, start_pos: Tensor) -> Tensor:
        xq_out, xk_out = torch.ops.nnedge.rope(xq, xk, start_pos)
        return xq_out + xk_out


def make_example_args() -> tuple[Tensor, Tensor, Tensor]:
    xq = torch.arange(64 * 64, dtype=torch.float32).reshape(64, 64)
    xk = torch.arange(64 * 64, dtype=torch.float32).reshape(64, 64)
    xq = (xq.remainder(17) - 8) / 8
    xk = (xk.remainder(19) - 9) / 8
    start_pos = torch.tensor(0, dtype=torch.int64)
    return xq, xk, start_pos


def make_model_and_args() -> tuple[SmokeRope, tuple[Tensor, Tensor, Tensor]]:
    return SmokeRope(), make_example_args()
