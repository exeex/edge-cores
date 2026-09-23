"""Lower graph nodes to kernel calls and record their tensor shapes."""

from __future__ import annotations

import torch

from nnc.graph import Graph, GraphNode, LoweredNode, LoweredProgram, Shape, TensorSpec
from nnc.weights import WeightStore


class TensorTable:
    def __init__(self) -> None:
        self.specs: dict[str, TensorSpec] = {}

    def add(self, spec: TensorSpec) -> None:
        self.specs[spec.name] = spec

    def require(self, name: str) -> TensorSpec:
        try:
            return self.specs[name]
        except KeyError as exc:
            raise SystemExit(f"unknown tensor: {name}") from exc


class OpLowerer:
    def lower(self, node: GraphNode, tensors: TensorTable, weights: WeightStore) -> LoweredNode:
        raise NotImplementedError

    @staticmethod
    def static_or_dynamic(tensors: TensorTable, name: str) -> TensorSpec:
        return tensors.require(name)

    @staticmethod
    def output(name: str, shape: Shape) -> TensorSpec:
        return TensorSpec(name, shape, "ssa")


class UnarySameShapeLowerer(OpLowerer):
    def __init__(self, op: str) -> None:
        self.op = op

    def lower(self, node: GraphNode, tensors: TensorTable, weights: WeightStore) -> LoweredNode:
        del weights
        src = self.static_or_dynamic(tensors, node.args[0])
        return LoweredNode((self.output(node.outputs[0], src.shape),), self.op, node.args, node.attrs)


class BinarySameShapeLowerer(OpLowerer):
    def __init__(self, op: str) -> None:
        self.op = op

    def lower(self, node: GraphNode, tensors: TensorTable, weights: WeightStore) -> LoweredNode:
        del weights
        lhs = self.static_or_dynamic(tensors, node.args[0])
        return LoweredNode((self.output(node.outputs[0], lhs.shape),), self.op, node.args, node.attrs)


class AddLowerer(OpLowerer):
    def lower(self, node: GraphNode, tensors: TensorTable, weights: WeightStore) -> LoweredNode:
        lhs = self.static_or_dynamic(tensors, node.args[0])
        eye = weights.use_eye8("tensor_eye8")
        return LoweredNode(
            (self.output(node.outputs[0], lhs.shape),),
            "add",
            node.args,
            {"eye": eye.name, **node.attrs},
        )


class MulLowerer(OpLowerer):
    def lower(self, node: GraphNode, tensors: TensorTable, weights: WeightStore) -> LoweredNode:
        lhs = self.static_or_dynamic(tensors, node.args[0])
        eye = weights.use_eye8("tensor_eye8")
        return LoweredNode(
            (self.output(node.outputs[0], lhs.shape),),
            "mul",
            node.args,
            {"eye": eye.name, **node.attrs},
        )


class SoftmaxLowerer(OpLowerer):
    def lower(self, node: GraphNode, tensors: TensorTable, weights: WeightStore) -> LoweredNode:
        src = self.static_or_dynamic(tensors, node.args[0])
        if len(src.shape) != 2:
            raise SystemExit(f"Tensor softmax currently requires a rank-2 tensor: {src.shape}")
        cols = src.shape[1]
        if cols <= 0 or cols > 64 or cols % 8 != 0:
            raise SystemExit(
                f"Tensor softmax width must be a positive multiple of 8 up to 64: {cols}"
            )
        eye = weights.use_eye8("tensor_eye8")
        return LoweredNode(
            (self.output(node.outputs[0], src.shape),),
            "softmax",
            node.args,
            {"eye": eye.name, **node.attrs},
            dram_preferred=(node.args[0], node.outputs[0]),
        )


class RmsNormLowerer(OpLowerer):
    def lower(self, node: GraphNode, tensors: TensorTable, weights: WeightStore) -> LoweredNode:
        src = self.static_or_dynamic(tensors, node.args[0])
        weight = self.static_or_dynamic(tensors, node.args[1])
        if not src.shape:
            raise SystemExit("Tensor RMSNorm input must have at least one dimension")
        cols = src.shape[-1]
        if weight.shape != (cols,):
            raise SystemExit(f"RMSNorm weight shape {weight.shape} does not match width {cols}")
        weights.use(weight)
        eye = weights.use_eye8("tensor_eye8")
        square_weight = weights.use_rms_square_mean(
            f"rms_square_mean_{cols}", cols
        )
        reduce_weight = weights.use_rms_reduce_sum8("rms_reduce_sum8")
        return LoweredNode(
            (self.output(node.outputs[0], src.shape),),
            "rms_norm",
            (node.args[0],),
            {
                "weight": weight.name,
                "eye": eye.name,
                "reduce_weight": reduce_weight.name,
                "square_weight": square_weight.name,
                **node.attrs,
            },
        )


class LinearLowerer(OpLowerer):
    def lower(self, node: GraphNode, tensors: TensorTable, weights: WeightStore) -> LoweredNode:
        x = self.static_or_dynamic(tensors, node.args[0])
        weight = self.static_or_dynamic(tensors, node.args[1])
        weights.use(weight)
        out_shape = (*x.shape[:-1], weight.shape[0])
        attrs = {"quant": "bf16", "tile": "auto", **node.attrs}
        return LoweredNode((self.output(node.outputs[0], out_shape),), "linear", node.args, attrs)


class RopeLowerer(OpLowerer):
    def lower(self, node: GraphNode, tensors: TensorTable, weights: WeightStore) -> LoweredNode:
        xq = self.static_or_dynamic(tensors, node.args[0])
        xk = self.static_or_dynamic(tensors, node.args[1])
        start_pos = self.static_or_dynamic(tensors, node.args[2])
        del start_pos
        rope_table = weights.use_rope_table("rope_table", max(64, xq.shape[0]), xq.shape[-1])
        return LoweredNode(
            (self.output(node.outputs[0], xq.shape), self.output(node.outputs[1], xk.shape)),
            "rope",
            node.args,
            {"rope_table": rope_table.name, **node.attrs},
        )


class KvCacheLowerer(OpLowerer):
    def lower(self, node: GraphNode, tensors: TensorTable, weights: WeightStore) -> LoweredNode:
        del weights
        xk = self.static_or_dynamic(tensors, node.args[0])
        xv = self.static_or_dynamic(tensors, node.args[1])
        return LoweredNode(
            (self.output(node.outputs[0], xk.shape), self.output(node.outputs[1], xv.shape)),
            "kv_cache_update",
            node.args,
            node.attrs,
            dram_preferred=node.outputs,
        )


class AttentionLowerer(OpLowerer):
    def lower(self, node: GraphNode, tensors: TensorTable, weights: WeightStore) -> LoweredNode:
        xq = self.static_or_dynamic(tensors, node.args[0])
        head_count = int(node.attrs.get("head_count", "1"))
        if head_count <= 0 or xq.shape[-1] % head_count != 0:
            raise SystemExit(
                f"attention width {xq.shape[-1]} is not divisible by {head_count} heads"
            )
        if (xq.shape[-1] // head_count) % 8 != 0:
            raise SystemExit("attention head dimension must be a multiple of 8")
        eye = weights.use_eye8("tensor_eye8")
        return LoweredNode(
            (self.output(node.outputs[0], xq.shape),),
            "attention",
            node.args,
            {"eye": eye.name, **node.attrs},
            dram_preferred=node.args[:4] + node.outputs,
        )


class MatmulLowerer(OpLowerer):
    def __init__(self, rhs_transposed: bool) -> None:
        self.rhs_transposed = rhs_transposed

    def lower(self, node: GraphNode, tensors: TensorTable, weights: WeightStore) -> LoweredNode:
        del weights
        lhs = self.static_or_dynamic(tensors, node.args[0])
        rhs = self.static_or_dynamic(tensors, node.args[1])
        head_count = int(node.attrs.get("head_count", "1"))
        if head_count <= 0:
            raise SystemExit("matmul head_count must be positive")
        if self.rhs_transposed:
            if lhs.shape[1] % head_count != 0:
                raise SystemExit("matmul_transpose width must be divisible by head_count")
            out_shape = (head_count, lhs.shape[0], rhs.shape[0])
        else:
            if rhs.shape[1] % head_count != 0:
                raise SystemExit("matmul output width must be divisible by head_count")
            rows = lhs.shape[1] if len(lhs.shape) >= 3 else lhs.shape[0]
            out_shape = (rows, rhs.shape[1])
        return LoweredNode(
            (self.output(node.outputs[0], out_shape),),
            "matmul_transpose" if self.rhs_transposed else "matmul",
            node.args,
            node.attrs,
            dram_preferred=(
                node.args[:2] + node.outputs
            ),
        )


OP_LOWERERS: dict[str, OpLowerer] = {
    "rms_norm": RmsNormLowerer(),
    "linear": LinearLowerer(),
    "rope": RopeLowerer(),
    "kv_cache_update": KvCacheLowerer(),
    "attention": AttentionLowerer(),
    "matmul": MatmulLowerer(False),
    "matmul_transpose": MatmulLowerer(True),
    "softmax": SoftmaxLowerer(),
    "add": AddLowerer(),
    "mul": MulLowerer(),
    "sigmoid": UnarySameShapeLowerer("sigmoid"),
    "silu": UnarySameShapeLowerer("silu"),
    "tanh": UnarySameShapeLowerer("tanh"),
}


class Lowerer:
    def __init__(self, graph: Graph, parameters: dict[str, torch.Tensor]) -> None:
        self.graph = graph
        self.tensors = TensorTable()
        self.weights = WeightStore(parameters)
        self.nodes: list[LoweredNode] = []

    def lower(self) -> LoweredProgram:
        for spec in self.graph.static_tensors:
            self.tensors.add(spec)

        for node in self.graph.nodes:
            lowered = OP_LOWERERS[node.op].lower(node, self.tensors, self.weights)
            for output in lowered.outputs:
                self.tensors.add(output)
            self.nodes.append(lowered)

        return LoweredProgram(tuple(self.nodes), self.graph.output)
