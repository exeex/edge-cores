#!/usr/bin/env python3
"""Focused tests for NNC lowering metadata and forward allocation."""

from __future__ import annotations

import struct
import unittest

import torch

from nnc import compiler


class RmsNormWeightTest(unittest.TestCase):
    def test_rms_norm_uses_dedicated_mean_and_sum_weights(self) -> None:
        tensors = compiler.TensorTable()
        tensors.add(compiler.TensorSpec("x", (32, 64), "input"))
        tensors.add(
            compiler.TensorSpec("weight", (64,), "weight", "norm.weight")
        )
        weights = compiler.WeightStore(
            {"norm.weight": torch.ones(64, dtype=torch.float32)}
        )
        node = compiler.GraphNode(
            ("out",), "rms_norm", ("x", "weight"), {"eps": "1e-05f"}
        )

        lowered = compiler.RmsNormLowerer().lower(node, tensors, weights)

        self.assertEqual(lowered.attrs["square_weight"], "rms_square_mean_64")
        self.assertEqual(lowered.attrs["reduce_weight"], "rms_reduce_sum8")
        self.assertEqual(lowered.attrs["weight"], "weight")
        self.assertEqual(lowered.attrs["eye"], "tensor_eye8")
        self.assertNotIn("setup", lowered.attrs)
        self.assertNotIn("out_rms_setup16", weights.records)

        square = weights.records["rms_square_mean_64"]
        square_bits = struct.unpack(
            "<64H", weights.data[square.offset:square.offset + square.nbytes]
        )
        self.assertEqual(
            square_bits,
            tuple(
                0x3C80 if row == col else 0
                for row in range(8)
                for col in range(8)
            ),
        )

        reduce_sum = weights.records["rms_reduce_sum8"]
        reduce_bits = struct.unpack(
            "<64H",
            weights.data[
                reduce_sum.offset:reduce_sum.offset + reduce_sum.nbytes
            ],
        )
        self.assertEqual(reduce_bits, (0x3F80,) * 64)


class DramPreferenceTest(unittest.TestCase):
    def test_softmax_prefers_input_and_output_in_dram(self) -> None:
        tensors = compiler.TensorTable()
        tensors.add(compiler.TensorSpec("score", (32, 32), "ssa"))
        node = compiler.GraphNode(("prob",), "softmax", ("score",))

        lowered = compiler.SoftmaxLowerer().lower(
            node, tensors, compiler.WeightStore({})
        )

        self.assertEqual(lowered.dram_preferred, ("score", "prob"))

    def test_elementwise_lowerers_do_not_force_rhs_to_dram(self) -> None:
        tensors = compiler.TensorTable()
        tensors.add(compiler.TensorSpec("lhs", (32, 64), "ssa"))
        tensors.add(compiler.TensorSpec("rhs", (32, 64), "ssa"))
        weights = compiler.WeightStore({})

        add = compiler.AddLowerer().lower(
            compiler.GraphNode(("add_out",), "add", ("lhs", "rhs")),
            tensors,
            weights,
        )
        mul = compiler.MulLowerer().lower(
            compiler.GraphNode(("mul_out",), "mul", ("lhs", "rhs")),
            tensors,
            weights,
        )

        self.assertEqual(add.dram_preferred, ())
        self.assertEqual(mul.dram_preferred, ())

    def test_matmul_lowerer_marks_rhs(self) -> None:
        tensors = compiler.TensorTable()
        tensors.add(compiler.TensorSpec("lhs", (32, 64), "input"))
        tensors.add(compiler.TensorSpec("rhs", (64, 64), "ssa"))
        node = compiler.GraphNode(("out",), "matmul", ("lhs", "rhs"))

        lowered = compiler.MatmulLowerer(False).lower(
            node, tensors, compiler.WeightStore({})
        )

        self.assertEqual(lowered.dram_preferred, ("lhs", "rhs", "out"))

    def test_attention_lowerer_keeps_rhs_and_unused_params_in_dram(self) -> None:
        tensors = compiler.TensorTable()
        for name in ("xq", "keys", "values", "params"):
            tensors.add(compiler.TensorSpec(name, (32, 64), "ssa"))
        node = compiler.GraphNode(
            ("out",), "attention", ("xq", "keys", "values", "params"),
            {"head_count": "2"},
        )

        lowered = compiler.AttentionLowerer().lower(
            node, tensors, compiler.WeightStore({})
        )

        self.assertEqual(
            lowered.dram_preferred,
            ("xq", "keys", "values", "params", "out"),
        )
        self.assertEqual(lowered.attrs["head_count"], "2")

    def test_attention_renderer_passes_head_count(self) -> None:
        out = compiler.TensorSpec("out", (32, 64), "ssa")
        program = compiler.LoweredProgram(
            (
                compiler.LoweredNode(
                    (out,),
                    "attention",
                    ("xq", "keys", "values", "params"),
                    {"eye": "tensor_eye8", "head_count": "2"},
                ),
            ),
            "out",
        )
        abi = compiler.ForwardABI(
            tuple(
                compiler.AbiValue(name, "tensor", (32, 64))
                for name in ("xq", "keys", "values", "params")
            ),
            (compiler.AbiValue("y", "tensor", (32, 64)),),
        )
        weights = compiler.WeightStore({})
        weights.use_eye8("tensor_eye8")

        rendered = compiler.ForwardRenderer(program, abi, weights).render()

        self.assertIn(
            "ctx->tensor_eye8, 2u)",
            rendered,
        )

    def test_kv_cache_lowerer_keeps_cache_outputs_in_dram(self) -> None:
        tensors = compiler.TensorTable()
        tensors.add(compiler.TensorSpec("xk", (32, 64), "ssa"))
        tensors.add(compiler.TensorSpec("xv", (32, 64), "ssa"))
        tensors.add(compiler.TensorSpec("start_pos", (), "input"))
        node = compiler.GraphNode(
            ("keys", "values"),
            "kv_cache_update",
            ("xk", "xv", "start_pos"),
        )

        lowered = compiler.KvCacheLowerer().lower(
            node, tensors, compiler.WeightStore({})
        )

        self.assertEqual(lowered.dram_preferred, ("keys", "values"))

    def test_renderer_allocates_preferred_ssa_value_in_dram(self) -> None:
        rhs = compiler.TensorSpec("rhs", (64, 64), "ssa")
        out = compiler.TensorSpec("out", (32, 64), "ssa")
        program = compiler.LoweredProgram(
            (
                compiler.LoweredNode((rhs,), "silu", ("x",), {}),
                compiler.LoweredNode(
                    (out,),
                    "matmul",
                    ("x", "rhs"),
                    {},
                    dram_preferred=("rhs",),
                ),
            ),
            "out",
        )
        abi = compiler.ForwardABI(
            (compiler.AbiValue("x", "tensor", (32, 64)),),
            (compiler.AbiValue("y", "tensor", (32, 64)),),
        )

        rendered = compiler.ForwardRenderer(
            program, abi, compiler.WeightStore({})
        ).render()

        self.assertIn("nnedge::malloc_tensor_dram(rhs);", rendered)

    def test_renderer_keeps_preferred_input_in_dram(self) -> None:
        out = compiler.TensorSpec("out", (32, 64), "ssa")
        program = compiler.LoweredProgram(
            (
                compiler.LoweredNode(
                    (out,),
                    "matmul",
                    ("lhs", "rhs"),
                    {},
                    dram_preferred=("rhs",),
                ),
            ),
            "out",
        )
        abi = compiler.ForwardABI(
            (
                compiler.AbiValue("lhs", "tensor", (32, 64)),
                compiler.AbiValue("rhs", "tensor", (64, 64)),
            ),
            (compiler.AbiValue("y", "tensor", (32, 64)),),
        )

        rendered = compiler.ForwardRenderer(
            program, abi, compiler.WeightStore({})
        ).render()

        self.assertIn("Tensor<dtype> lhs_dtcm", rendered)
        self.assertNotIn("Tensor<dtype> rhs_dtcm", rendered)
        self.assertIn("nnedge::op::matmul(out, lhs_dtcm, rhs, 1u)", rendered)


class InitRendererTest(unittest.TestCase):
    def test_tensor_storage_is_dma_beat_aligned(self) -> None:
        abi = compiler.ForwardABI(
            (compiler.AbiValue("x", "tensor", (3,)),),
            (compiler.AbiValue("y", "tensor", (3,)),),
        )

        rendered = compiler.InitRenderer(
            abi, compiler.WeightStore({})
        ).render()

        self.assertIn(
            "alignas(nnedge::kArenaAlign) inline dtype x_storage[3];",
            rendered,
        )
        self.assertIn(
            "alignas(nnedge::kArenaAlign) inline dtype y_storage[3];",
            rendered,
        )


if __name__ == "__main__":
    unittest.main()
