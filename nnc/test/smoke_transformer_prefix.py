"""Stage-selectable tiny Llama block smoke used to locate composed-path errors."""

from __future__ import annotations

import importlib.util
import os
import sys
from pathlib import Path

import torch
import torch.nn as nn
from torch import Tensor


def load_llama_source():
    path = Path(__file__).with_name("llama3_source.py")
    spec = importlib.util.spec_from_file_location("_nnedge_llama3_source", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


LLAMA = load_llama_source()


@torch.library.custom_op("nnedge::softmax", mutates_args=())
def nnedge_softmax(x: Tensor) -> Tensor:
    return torch.softmax(x, dim=-1)


@nnedge_softmax.register_fake
def _(x):
    return torch.empty_like(x)


@torch.library.custom_op("nnedge::matmul", mutates_args=())
def nnedge_matmul(lhs: Tensor, rhs: Tensor) -> Tensor:
    return torch.matmul(lhs, rhs)


@nnedge_matmul.register_fake
def _(lhs, rhs):
    return torch.empty((lhs.shape[0], rhs.shape[1]), dtype=lhs.dtype, device=lhs.device)


@torch.library.custom_op("nnedge::matmul_transpose", mutates_args=())
def nnedge_matmul_transpose(lhs: Tensor, rhs: Tensor) -> Tensor:
    return torch.matmul(lhs, rhs.transpose(-2, -1))


@nnedge_matmul_transpose.register_fake
def _(lhs, rhs):
    return torch.empty((lhs.shape[0], rhs.shape[0]), dtype=lhs.dtype, device=lhs.device)


class SmokeTransformerPrefix(nn.Module):
    def __init__(self, stage: str) -> None:
        super().__init__()
        self.block = LLAMA.make_tiny_llama_block()
        self.stage = stage

    def forward(self, x: Tensor, start_pos: Tensor, mask_or_params: Tensor) -> Tensor:
        norm = self.block.attention_norm(x)
        if self.stage == "attention_norm":
            return norm
        if self.stage == "double_norm":
            return self.block.ffn_norm(norm)
        if self.stage == "post_softmax_norm":
            prob = torch.ops.nnedge.softmax(norm)
            return self.block.ffn_norm(prob)
        if self.stage in {
            "xq",
            "xk",
            "xv",
            "rope_xq",
            "rope_xk",
            "keys",
            "values",
            "scores",
            "prob",
            "context",
            "fused_attention",
            "post_fused_attention_norm",
            "post_qkv_norm_x",
            "post_rope_norm_x",
            "post_kv_norm_x",
        }:
            attention = self.block.attention
            xq = torch.ops.nnedge.linear(norm, attention.wq_weight)
            if self.stage == "xq":
                return xq
            xk = torch.ops.nnedge.linear(norm, attention.wk_weight)
            if self.stage == "xk":
                return xk
            xv = torch.ops.nnedge.linear(norm, attention.wv_weight)
            if self.stage == "xv":
                return xv
            if self.stage == "post_qkv_norm_x":
                return self.block.ffn_norm(x)
            xq, xk = torch.ops.nnedge.rope(xq, xk, start_pos)
            if self.stage == "rope_xq":
                return xq
            if self.stage == "rope_xk":
                return xk
            if self.stage == "post_rope_norm_x":
                return self.block.ffn_norm(x)
            keys, values = torch.ops.nnedge.kv_cache_update(xk, xv, start_pos)
            if self.stage == "keys":
                return keys
            if self.stage == "values":
                return values
            if self.stage in {"scores", "prob", "context"}:
                scores = torch.ops.nnedge.matmul_transpose(xq, keys)
                if self.stage == "scores":
                    return scores
                prob = torch.ops.nnedge.softmax(scores)
                if self.stage == "prob":
                    return prob
                return torch.ops.nnedge.matmul(prob, values)
            if self.stage == "post_kv_norm_x":
                return self.block.ffn_norm(x)
            fused = torch.ops.nnedge.attention(xq, keys, values, mask_or_params)
            if self.stage == "fused_attention":
                return fused
            return self.block.ffn_norm(fused)

        attn = self.block.attention(norm, start_pos, mask_or_params)
        if self.stage == "attention":
            return attn
        if self.stage == "post_wo_x":
            return x
        if self.stage == "post_wo_norm":
            return self.block.ffn_norm(attn)
        if self.stage == "post_attention_norm_x":
            return self.block.ffn_norm(x)

        residual = torch.ops.aten.add.Tensor(x, attn)
        if self.stage == "attention_residual":
            return residual

        ffn_norm = self.block.ffn_norm(residual)
        if self.stage == "ffn_norm":
            return ffn_norm

        w1 = torch.ops.nnedge.linear(ffn_norm, self.block.feed_forward.w1_weight)
        if self.stage == "w1":
            return w1

        w3 = torch.ops.nnedge.linear(ffn_norm, self.block.feed_forward.w3_weight)
        if self.stage == "w3":
            return w3

        silu = torch.nn.functional.silu(w1)
        if self.stage == "silu":
            return silu

        gated = silu * w3
        if self.stage == "gated":
            return gated

        ffn = torch.ops.nnedge.linear(gated, self.block.feed_forward.w2_weight)
        if self.stage == "ffn":
            return ffn
        if self.stage != "full":
            raise RuntimeError(f"unknown NNEDGE_LLAMA_PREFIX stage: {self.stage}")
        return torch.ops.aten.add.Tensor(residual, ffn)


def make_model_and_args():
    stage = os.environ.get("NNEDGE_LLAMA_PREFIX", "full")
    return SmokeTransformerPrefix(stage), LLAMA.make_example_args()
