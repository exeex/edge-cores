"""Minimal KV cache pass-through model used to smoke-test NNC lowering."""

from __future__ import annotations

import torch
import torch.nn as nn
from torch import Tensor


@torch.library.custom_op("nnedge::kv_cache_update", mutates_args=())
def nnedge_kv_cache_update(xk: Tensor, xv: Tensor, start_pos: Tensor) -> tuple[Tensor, Tensor]:
    del start_pos
    return xk.clone(), xv.clone()


@nnedge_kv_cache_update.register_fake
def _(xk, xv, start_pos):
    del start_pos
    return torch.empty_like(xk), torch.empty_like(xv)


class SmokeKvCache(nn.Module):
    def forward(self, xk: Tensor, xv: Tensor, start_pos: Tensor) -> Tensor:
        keys, values = torch.ops.nnedge.kv_cache_update(xk, xv, start_pos)
        return keys + values


def make_example_args() -> tuple[Tensor, Tensor, Tensor]:
    xk = torch.arange(64 * 64, dtype=torch.float32).reshape(64, 64)
    xv = torch.arange(64 * 64, dtype=torch.float32).reshape(64, 64)
    xk = (xk.remainder(17) - 8) / 8
    xv = (xv.remainder(23) - 11) / 8
    start_pos = torch.tensor(0, dtype=torch.int64)
    return xk, xv, start_pos


def make_model_and_args() -> tuple[SmokeKvCache, tuple[Tensor, Tensor, Tensor]]:
    return SmokeKvCache(), make_example_args()
