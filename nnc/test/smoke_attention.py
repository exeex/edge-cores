"""Minimal attention model used to smoke-test NNC lowering."""

from __future__ import annotations

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch import Tensor


@torch.library.custom_op("nnedge::attention", mutates_args=())
def nnedge_attention(xq: Tensor, keys: Tensor, values: Tensor,
                     mask_or_params: Tensor, head_count: int) -> Tensor:
    del mask_or_params
    del head_count
    scores = torch.matmul(xq, keys.transpose(-2, -1))
    probs = F.softmax(scores.float(), dim=-1).type_as(xq)
    return torch.matmul(probs, values)


@nnedge_attention.register_fake
def _(xq, keys, values, mask_or_params, head_count):
    del keys, mask_or_params, head_count
    return torch.empty_strided(xq.shape, xq.stride(), dtype=values.dtype, device=values.device)


class SmokeAttention(nn.Module):
    def forward(self, xq: Tensor, keys: Tensor, values: Tensor, mask_or_params: Tensor) -> Tensor:
        return torch.ops.nnedge.attention(xq, keys, values, mask_or_params, 1)


def make_example_args() -> tuple[Tensor, Tensor, Tensor, Tensor]:
    xq = torch.arange(48 * 40, dtype=torch.float32).reshape(48, 40)
    keys = torch.arange(32 * 40, dtype=torch.float32).reshape(32, 40)
    values = torch.arange(32 * 40, dtype=torch.float32).reshape(32, 40)
    xq = (xq.remainder(17) - 8) / 32
    keys = (keys.remainder(19) - 9) / 32
    values = (values.remainder(13) - 6) / 16
    mask_or_params = torch.zeros(1, dtype=torch.float32)
    return xq, keys, values, mask_or_params


def make_model_and_args() -> tuple[SmokeAttention, tuple[Tensor, Tensor, Tensor, Tensor]]:
    return SmokeAttention(), make_example_args()
