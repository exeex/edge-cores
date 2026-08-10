#!/usr/bin/env python3
"""Lower semantic NNC graph nodes into forward.hpp/init.hpp/weight.bin.

Tensor sources:
- static: forward inputs, forward outputs, and weights
- dynamic: SSA node outputs

Each op lowerer owns its metadata. For example LinearLowerer records that its
second operand is a weight, asks the weight store to mount/pack it, infers the
output shape, and emits one C++ call.
"""

from __future__ import annotations

import argparse
import importlib.util
import inspect
import math
import operator
import struct
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import torch


Shape = tuple[int, ...]


@dataclass(frozen=True)
class TensorSpec:
    name: str
    shape: Shape
    source: str
    target: str = ""


@dataclass(frozen=True)
class GraphNode:
    outputs: tuple[str, ...]
    op: str
    args: tuple[str, ...]
    attrs: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class Graph:
    static_tensors: tuple[TensorSpec, ...]
    nodes: tuple[GraphNode, ...]
    output: str


@dataclass(frozen=True)
class LoweredNode:
    outputs: tuple[TensorSpec, ...]
    op: str
    args: tuple[str, ...]
    attrs: dict[str, str]
    dram_preferred: tuple[str, ...] = ()


@dataclass(frozen=True)
class LoweredProgram:
    nodes: tuple[LoweredNode, ...]
    output: str


@dataclass(frozen=True)
class AbiValue:
    name: str
    kind: str
    shape: Shape = ()
    init_bits: tuple[int, ...] = ()
    init_size: int = 0


@dataclass(frozen=True)
class ForwardABI:
    inputs: tuple[AbiValue, ...]
    outputs: tuple[AbiValue, ...]

    @classmethod
    def from_example(cls, model: Any, args: tuple[Any, ...]) -> "ForwardABI":
        parameters = tuple(inspect.signature(model.forward).parameters)
        if len(parameters) != len(args):
            raise SystemExit(
                f"forward expects {len(parameters)} args, got {len(args)} example args"
            )

        inputs = tuple(
            cls.value_from_example(name, value, fill=True)
            for name, value in zip(parameters, args)
        )
        with torch.no_grad():
            result = model(*args)
        outputs = cls.outputs_from_result(result)
        return cls(inputs, outputs)

    @classmethod
    def outputs_from_result(cls, result: Any) -> tuple[AbiValue, ...]:
        if isinstance(result, tuple):
            return tuple(cls.value_from_example(f"y{index}", value, fill=False)
                         for index, value in enumerate(result))
        return (cls.value_from_example("y", result, fill=False),)

    @staticmethod
    def value_from_example(name: str, value: Any, fill: bool) -> AbiValue:
        if isinstance(value, torch.Tensor):
            if value.ndim == 0 and value.dtype in (torch.int32, torch.int64):
                return AbiValue(name, "size_t", init_size=int(value.item()))
            shape = tuple(int(dim) for dim in value.shape)
            bits = ForwardABI.bf16_bits(value) if fill else ()
            return AbiValue(name, "tensor", shape, bits)
        if isinstance(value, int):
            return AbiValue(name, "size_t", init_size=int(value))
        raise SystemExit(f"unsupported ABI value {name}: {type(value).__name__}")

    @staticmethod
    def bf16_bits(value: torch.Tensor) -> tuple[int, ...]:
        bf16 = value.detach().to(torch.bfloat16).contiguous().view(torch.int16).flatten()
        return tuple(int(item) & 0xffff for item in bf16.tolist())


def export_graph(model: Any, args: tuple[Any, ...]) -> Graph:
    return ExportGraphReader(torch.export.export(model, args)).read()


class ExportGraphReader:
    OP_TARGETS = {
        ("nnedge::rms_norm", "default"): "rms_norm",
        ("nnedge::linear", "default"): "linear",
        ("nnedge::rope", "default"): "rope",
        ("nnedge::kv_cache_update", "default"): "kv_cache_update",
        ("nnedge::attention", "default"): "attention",
        ("nnedge::matmul", "default"): "matmul",
        ("nnedge::matmul_transpose", "default"): "matmul_transpose",
        ("nnedge::softmax", "default"): "softmax",
        ("aten::add", "Tensor"): "add",
        ("aten::mul", "Tensor"): "mul",
        ("aten::sigmoid", "default"): "sigmoid",
        ("aten::silu", "default"): "silu",
        ("aten::tanh", "default"): "tanh",
    }

    def __init__(self, exported: Any) -> None:
        self.exported = exported
        self.placeholder_names = self.read_placeholder_names()
        self.names: dict[Any, str] = {}
        self.static_tensors: list[TensorSpec] = []
        self.nodes: list[GraphNode] = []

    def read_placeholder_names(self) -> dict[str, tuple[str, str, str]]:
        names: dict[str, tuple[str, str, str]] = {}
        for spec in self.exported.graph_signature.input_specs:
            arg = spec.arg
            if not hasattr(arg, "name"):
                continue
            name = str(arg.name)
            kind = str(spec.kind)
            if "PARAMETER" in kind:
                names[name] = (self.cpp_name(spec.target), "param", spec.target)
            elif "USER_INPUT" in kind:
                names[name] = (name, "input", "")
        return names

    def read(self) -> Graph:
        for node in self.exported.graph.nodes:
            if node.op == "placeholder":
                self.read_placeholder(node)
            elif node.op == "call_function":
                self.read_call_function(node)
            elif node.op == "output":
                return Graph(tuple(self.static_tensors), tuple(self.nodes), self.output_name(node))
            else:
                raise SystemExit(f"unsupported graph node op: {node.op}")
        raise SystemExit("exported graph has no output node")

    def read_placeholder(self, node: Any) -> None:
        name, source, target = self.placeholder_names[node.name]
        spec = TensorSpec(name, self.node_shape(node), source, target)
        self.names[node] = spec.name
        self.static_tensors.append(spec)

    def read_call_function(self, node: Any) -> None:
        if node.target is operator.getitem:
            self.names[node] = node.name
            return

        op = self.op_name(node)
        outputs = self.output_names(node)
        args, attrs = self.args_and_attrs(op, node)
        self.nodes.append(GraphNode(outputs, op, args, attrs))
        if len(outputs) == 1:
            self.names[node] = outputs[0]

    def op_name(self, node: Any) -> str:
        target = self.target_key(node.target)
        try:
            return self.OP_TARGETS[target]
        except KeyError as exc:
            raise SystemExit(f"unsupported call target: {target}") from exc

    def output_names(self, node: Any) -> tuple[str, ...]:
        value = node.meta.get("val")
        if not isinstance(value, tuple):
            return (node.name,)
        users = sorted(
            (user for user in node.users if user.target is operator.getitem),
            key=lambda user: user.args[1],
        )
        if len(users) != len(value):
            raise SystemExit(f"tuple output {node.name} is not fully unpacked")
        return tuple(user.name for user in users)

    def args_and_attrs(self, op: str, node: Any) -> tuple[tuple[str, ...], dict[str, str]]:
        attrs: dict[str, str] = {}
        raw_args = list(node.args)
        if op == "rms_norm":
            attrs["eps"] = self.float_literal(raw_args.pop())
        if op == "attention":
            attrs["head_count"] = str(int(raw_args.pop()))
        if op in ("matmul", "matmul_transpose") and len(raw_args) == 3:
            attrs["head_count"] = str(int(raw_args.pop()))
        if op == "add":
            attrs["alpha"] = self.float_literal(node.kwargs.get("alpha", 1.0))
        return tuple(self.name(arg) for arg in raw_args), attrs

    def name(self, value: Any) -> str:
        if value in self.names:
            return self.names[value]
        raise SystemExit(f"unsupported node argument: {value!r}")

    def output_name(self, node: Any) -> str:
        value = node.args[0]
        if isinstance(value, tuple) and len(value) == 1:
            return self.name(value[0])
        return self.name(value)

    @staticmethod
    def node_shape(node: Any) -> Shape:
        return tuple(int(dim) for dim in node.meta["val"].shape)

    @staticmethod
    def float_literal(value: Any) -> str:
        text = f"{float(value):.8g}"
        if "e" not in text and "." not in text:
            text += ".0"
        return f"{text}f"

    @staticmethod
    def cpp_name(name: str) -> str:
        return name.replace(".", "_")

    @staticmethod
    def target_key(target: Any) -> tuple[str, str]:
        schema = getattr(target, "_schema", None)
        if schema is None:
            raise SystemExit(f"unsupported call target: {target}")
        return str(schema.name), str(schema.overload_name or "default")


def load_model_example(model_path: Path) -> tuple[Any, tuple[Any, ...]]:
    spec = importlib.util.spec_from_file_location("llama3_source", model_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"cannot import {model_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)

    if hasattr(module, "make_model_and_args"):
        model, args = module.make_model_and_args()
    else:
        model = module.make_tiny_llama_block()
        args = module.make_example_args()
    return model.eval(), tuple(args)


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


@dataclass(frozen=True)
class WeightRecord:
    tensor: TensorSpec
    offset: int
    nbytes: int
    ctype: str


class WeightStore:
    def __init__(self, parameters: dict[str, torch.Tensor]) -> None:
        self.parameters = parameters
        self.records: dict[str, WeightRecord] = {}
        self.data = bytearray()
        self.cursor = 0

    def use(self, tensor: TensorSpec, ctype: str = "dtype") -> None:
        if tensor.name in self.records:
            return
        payload = self.weight_bytes(tensor, ctype)
        self.use_payload(tensor, payload, ctype)

    def use_payload(self, tensor: TensorSpec, payload: bytes, ctype: str = "dtype") -> None:
        if tensor.name in self.records:
            return
        nbytes = len(payload)
        self.records[tensor.name] = WeightRecord(tensor, self.cursor, nbytes, ctype)
        self.data.extend(payload)
        self.cursor += nbytes

    def use_rope_table(self, name: str, max_seq_len: int, dim: int) -> TensorSpec:
        if dim % 8 != 0:
            raise SystemExit(f"Tensor RoPE dim must be a multiple of 8, got {dim}")
        shape = (max_seq_len, dim // 8, 8, 8)
        tensor = TensorSpec(name, shape, "synthetic")
        if name not in self.records:
            self.use_payload(tensor, self.rope_table_bytes(max_seq_len, dim))
        return tensor

    def use_eye8(self, name: str) -> TensorSpec:
        tensor = TensorSpec(name, (8, 8), "synthetic")
        if name not in self.records:
            self.use_payload(tensor, self.eye8_bytes())
        return tensor

    def use_rms_diag(self, name: str, weight: TensorSpec) -> TensorSpec:
        if len(weight.shape) != 1 or weight.shape[0] % 8 != 0:
            raise SystemExit(f"Tensor RMSNorm weight must be 1-D and a multiple of 8: {weight.shape}")
        tensor = TensorSpec(name, (weight.shape[0] // 8, 8, 8), "synthetic")
        if name not in self.records:
            self.use_payload(tensor, self.rms_diag_bytes(weight))
        return tensor

    def use_rms_square_mean(self, name: str, cols: int) -> TensorSpec:
        if cols <= 0 or cols % 8 != 0:
            raise SystemExit(f"Tensor RMSNorm width must be a positive multiple of 8: {cols}")
        tensor = TensorSpec(name, (8, 8), "synthetic")
        if name not in self.records:
            values = torch.eye(8, dtype=torch.float32) / float(cols)
            self.use_payload(tensor, self.bf16_bytes(values))
        return tensor

    def use_rms_reduce_sum8(self, name: str) -> TensorSpec:
        tensor = TensorSpec(name, (8, 8), "synthetic")
        if name not in self.records:
            values = torch.ones((8, 8), dtype=torch.float32)
            self.use_payload(tensor, self.bf16_bytes(values))
        return tensor

    def render_context(self) -> list[str]:
        lines = ["struct Context {"]
        for record in self.records.values():
            lines.append(f"    Tensor<{record.ctype}> {record.tensor.name};")
        lines.append("};")
        return lines

    def render_weight_init(self) -> list[str]:
        lines = ["inline void init(Context *ctx, unsigned char *weight_base)", "{"]
        for record in self.records.values():
            shape = self.shape_literal(record.tensor.shape)
            lines.append(
                f"    ctx->{record.tensor.name} = Tensor<{record.ctype}>({shape}, "
                f"reinterpret_cast<{record.ctype} *>(weight_base + {record.offset}));"
            )
        lines.append("}")
        return lines

    def write_weight_bin(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(self.data)

    def weight_bytes(self, tensor: TensorSpec, ctype: str) -> bytes:
        try:
            value = self.parameters[tensor.target]
        except KeyError as exc:
            raise SystemExit(f"missing parameter tensor: {tensor.target}") from exc
        if ctype == "int8_t":
            return self.q8_bytes(value)
        if value.ndim == 2 and value.shape[0] % 8 == 0 and value.shape[1] % 8 == 0:
            return self.bf16_packed_tile_bytes(value)
        bf16 = value.detach().to(torch.bfloat16).contiguous().view(torch.int16).flatten()
        return struct.pack(f"<{bf16.numel()}H", *(int(item) & 0xffff for item in bf16.tolist()))

    def rms_diag_bytes(self, tensor: TensorSpec) -> bytes:
        try:
            value = self.parameters[tensor.target]
        except KeyError as exc:
            raise SystemExit(f"missing RMSNorm weight tensor: {tensor.target}") from exc
        if value.ndim != 1 or value.numel() % 8 != 0:
            raise SystemExit(f"Tensor RMSNorm weight must be 1-D and a multiple of 8: {tuple(value.shape)}")
        blocks = int(value.numel()) // 8
        diagonal = torch.zeros((blocks, 8, 8), dtype=torch.float32)
        bf16_weight = value.detach().to(torch.bfloat16).to(torch.float32)
        for block in range(blocks):
            for lane in range(8):
                diagonal[block, lane, lane] = bf16_weight[block * 8 + lane]
        return self.bf16_bytes(diagonal)

    @staticmethod
    def bf16_bytes(value: torch.Tensor) -> bytes:
        bf16 = value.to(torch.bfloat16).contiguous().view(torch.int16).flatten()
        bits = [int(item) & 0xffff for item in bf16.tolist()]
        return struct.pack(f"<{len(bits)}H", *bits)

    @staticmethod
    def rope_table_bytes(max_seq_len: int, dim: int) -> bytes:
        values: list[float] = []
        dim_blocks = dim // 8
        for pos in range(max_seq_len):
            for block in range(dim_blocks):
                tile = [[0.0 for _ in range(8)] for _ in range(8)]
                for local_pair in range(4):
                    pair = block * 4 + local_pair
                    theta = 1.0 / (10000.0 ** ((2.0 * pair) / float(dim)))
                    angle = float(pos) * theta
                    cos_value = math.cos(angle)
                    sin_value = math.sin(angle)
                    row = local_pair * 2
                    col = local_pair * 2
                    tile[row][col] = cos_value
                    tile[row][col + 1] = -sin_value
                    tile[row + 1][col] = sin_value
                    tile[row + 1][col + 1] = cos_value
                for row in range(8):
                    values.extend(tile[row])
        bf16 = torch.tensor(values, dtype=torch.float32).to(torch.bfloat16)
        bits = bf16.contiguous().view(torch.int16).flatten().tolist()
        return struct.pack(f"<{len(bits)}H", *(int(item) & 0xffff for item in bits))

    @staticmethod
    def eye8_bytes() -> bytes:
        values = torch.eye(8, dtype=torch.float32).to(torch.bfloat16)
        bits = values.contiguous().view(torch.int16).flatten().tolist()
        return struct.pack("<64H", *(int(item) & 0xffff for item in bits))

    @staticmethod
    def bf16_packed_tile_bytes(value: torch.Tensor) -> bytes:
        if value.ndim != 2 or value.shape[0] % 8 != 0 or value.shape[1] % 8 != 0:
            raise SystemExit(f"BF16 tiled linear weight must be PxQ with P,Q multiple of 8: {tuple(value.shape)}")
        p, q = (int(value.shape[0]), int(value.shape[1]))
        bf16 = value.detach().to(torch.bfloat16).contiguous()
        tiled = bf16.reshape(p // 8, 8, q // 8, 8).permute(0, 2, 1, 3).contiguous()
        packed = [int(item) & 0xffff for item in tiled.view(torch.int16).flatten().tolist()]
        return struct.pack(f"<{len(packed)}H", *packed)

    @staticmethod
    def q8_bytes(value: torch.Tensor) -> bytes:
        quant = value.detach().round().clamp(-128, 127).to(torch.int8).contiguous()
        if tuple(quant.shape) == (64, 64):
            packed: list[int] = []
            for out_blk in range(8):
                for k_blk in range(8):
                    for out_lane in range(8):
                        for k_lane in range(8):
                            packed.append(int(quant[out_blk * 8 + out_lane, k_blk * 8 + k_lane]))
            return struct.pack("<4096b", *packed)
        quant = quant.flatten()
        return struct.pack(f"<{quant.numel()}b", *(int(item) for item in quant.tolist()))

    @staticmethod
    def numel(shape: Shape) -> int:
        total = 1
        for dim in shape:
            total *= dim
        return total

    @staticmethod
    def shape_literal(shape: Shape) -> str:
        return "nnedge::Shape{" + ", ".join(str(dim) for dim in shape) + "}"


class InitRenderer:
    def __init__(self, abi: ForwardABI, weights: WeightStore) -> None:
        self.abi = abi
        self.weights = weights

    def render(self) -> str:
        lines = [
            "#pragma once",
            "",
            '#include "libnn/ops.hpp"',
            "",
            "namespace model {",
            "",
            "using dtype = nnedge::bfloat16_t;",
            "using nnedge::Tensor;",
            "",
            f"constexpr nnedge::size_t kWeightBytes = {self.weights.cursor};",
            "",
            *self.weights.render_context(),
            "",
            "namespace mio {",
            "",
            "inline Context ctx;",
        ]
        for value in self.abi.inputs + self.abi.outputs:
            lines.extend(self.render_mio_decl(value))
        lines.extend([
            "",
            "} // namespace mio",
            "",
            *self.weights.render_weight_init(),
            "",
            'extern "C" const unsigned char weight_begin[];',
            "",
            "inline void init()",
            "{",
            "    nnedge::reset_allocator();",
            "    init(&mio::ctx, const_cast<unsigned char *>(weight_begin));",
        ])
        for value in self.abi.inputs + self.abi.outputs:
            lines.extend(self.render_mio_init(value))
        lines.extend([
            "}",
            "",
            "} // namespace model",
            "",
        ])
        return "\n".join(lines)

    def render_mio_decl(self, value: AbiValue) -> list[str]:
        if value.kind == "size_t":
            return [f"inline nnedge::size_t {value.name};"]
        return [
            f"alignas(nnedge::kArenaAlign) inline dtype {value.name}_storage["
            f"{self.numel(value.shape)}];",
            f"inline Tensor<dtype> {value.name};",
        ]

    def render_mio_init(self, value: AbiValue) -> list[str]:
        if value.kind == "size_t":
            return [f"    mio::{value.name} = {value.init_size};"]
        lines = [
            f"    mio::{value.name} = Tensor<dtype>({self.shape_literal(value.shape)}, "
            f"mio::{value.name}_storage);"
        ]
        if value.init_bits:
            for index, bits in enumerate(value.init_bits):
                lines.append(f"    mio::{value.name}_storage[{index}] = dtype::from_bits(0x{bits:04x});")
        else:
            lines.append(f"    nnedge::zero(mio::{value.name});")
        lines.append(
            f"    edge_dcache_clean_range(mio::{value.name}.data, "
            f"nnedge::numel(mio::{value.name}) * sizeof(dtype));"
        )
        return lines

    @staticmethod
    def numel(shape: Shape) -> int:
        total = 1
        for dim in shape:
            total *= dim
        return total

    @staticmethod
    def shape_literal(shape: Shape) -> str:
        return "nnedge::Shape{" + ", ".join(str(dim) for dim in shape) + "}"


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


class Liveness:
    def __init__(self, program: LoweredProgram) -> None:
        self.temp_names = {output.name for node in program.nodes for output in node.outputs}
        self.last_use = self.compute_last_use(program)

    def compute_last_use(self, program: LoweredProgram) -> dict[str, int]:
        last: dict[str, int] = {}
        for index, node in enumerate(program.nodes):
            for arg in node.args:
                if arg in self.temp_names:
                    last[arg] = index
        last[program.output] = len(program.nodes)
        return last

    def frees_after(self, index: int, node: LoweredNode) -> list[str]:
        return [
            arg for arg in node.args
            if arg in self.temp_names and self.last_use.get(arg) == index
        ]


class ForwardRenderer:
    def __init__(self, program: LoweredProgram, abi: ForwardABI, weights: WeightStore) -> None:
        self.program = program
        self.abi = abi
        self.weight_names = set(weights.records)
        self.liveness = Liveness(program)
        self.dram_names = self.compute_dram_preferences(program)
        self.input_remap = {
            value.name: f"{value.name}_dtcm"
            for value in abi.inputs
            if value.kind == "tensor" and value.name not in self.dram_names
        }

    @staticmethod
    def compute_dram_preferences(program: LoweredProgram) -> set[str]:
        return {
            name
            for node in program.nodes
            for name in node.dram_preferred
        }

    def render(self) -> str:
        lines = [
            "#pragma once",
            "",
            '#include "init.hpp"',
            "",
            "#ifndef NNEDGE_PROFILE",
            "#define NNEDGE_PROFILE 0",
            "#endif",
            "",
            "#if NNEDGE_PROFILE",
            '#include "edge_sim_console.hpp"',
            "#endif",
            "",
            "namespace model {",
            "",
            self.render_forward_signature(),
            "{",
        ]
        lines.extend(self.render_input_dma())
        for index, node in enumerate(self.program.nodes):
            lines.extend(self.render_node(index, node))
        lines.append(f"    nnedge::copy({self.primary_output().name}, {self.program.output});")
        lines.extend(self.render_profile_report())
        lines.extend([
            "    return 0;",
            "}",
            "",
            *self.render_mio_wrapper(),
            "",
            *self.render_mio_no_arg_wrapper(),
            "",
            "} // namespace model",
        ])
        return "\n".join(lines) + "\n"

    def render_input_dma(self) -> list[str]:
        lines: list[str] = []
        for value in self.abi.inputs:
            if value.kind != "tensor" or value.name not in self.input_remap:
                continue
            name = self.input_remap[value.name]
            lines.extend([
                "",
                f"    Tensor<dtype> {name}({self.shape_literal(value.shape)});",
                f"    nnedge::malloc_tensor({name});",
                f"    nnedge::copy({name}, {value.name});",
            ])
        return lines

    def render_forward_signature(self) -> str:
        outputs = ", ".join(self.render_param(value) for value in self.abi.outputs)
        inputs = ", ".join(self.render_param(value) for value in self.abi.inputs)
        params = ", ".join(part for part in (outputs, inputs, "Context *ctx") if part)
        if len(params) <= 88:
            return f"int forward({params})"
        pieces = [part.strip() for part in params.split(", ")]
        lines = [f"int forward({pieces[0]},"]
        for piece in pieces[1:-1]:
            lines.append(f"            {piece},")
        lines.append(f"            {pieces[-1]})")
        return "\n".join(lines)

    @staticmethod
    def render_param(value: AbiValue) -> str:
        if value.kind == "size_t":
            return f"nnedge::size_t {value.name}"
        return f"Tensor<dtype> {value.name}"

    def render_mio_wrapper(self) -> list[str]:
        output = self.primary_output()
        input_value = self.primary_input()
        args = [output.name]
        args.extend(
            input_value.name if value == input_value else f"mio::{value.name}"
            for value in self.abi.inputs
        )
        args.append("&mio::ctx")
        return [
            f"inline int forward({self.render_param(output)}, {self.render_param(input_value)})",
            "{",
            f"    return forward({', '.join(args)});",
            "}",
        ]

    def render_mio_no_arg_wrapper(self) -> list[str]:
        args = [f"mio::{value.name}" for value in self.abi.outputs]
        args.extend(f"mio::{value.name}" for value in self.abi.inputs)
        args.append("&mio::ctx")
        return [
            "inline int forward()",
            "{",
            f"    return forward({', '.join(args)});",
            "}",
        ]

    def primary_output(self) -> AbiValue:
        return self.primary_tensor(self.abi.outputs, "output")

    def primary_input(self) -> AbiValue:
        return self.primary_tensor(self.abi.inputs, "input")

    @staticmethod
    def primary_tensor(values: tuple[AbiValue, ...], role: str) -> AbiValue:
        for value in values:
            if value.kind == "tensor":
                return value
        raise SystemExit(f"forward ABI has no tensor {role}")

    def render_node(self, index: int, node: LoweredNode) -> list[str]:
        lines = [""]
        for output in node.outputs:
            lines.append(f"    Tensor<dtype> {output.name}({self.shape_literal(output.shape)});")
            allocator = (
                "malloc_tensor_dram"
                if output.name in self.dram_names
                else "malloc_tensor"
            )
            lines.append(f"    nnedge::{allocator}({output.name});")
        lines.extend([
            "#if NNEDGE_PROFILE",
            f"    const nnedge::size_t profile_start_{index} = edge_get_cycle();",
            "#endif",
            f"    {self.render_call(node)};",
            "#if NNEDGE_PROFILE",
            f"    const nnedge::size_t profile_cycles_{index} =",
            f"        edge_get_cycle() - profile_start_{index};",
            "#endif",
        ])
        for name in self.liveness.frees_after(index, node):
            lines.append(f"    nnedge::free_tensor({name});")
        return lines

    def render_profile_report(self) -> list[str]:
        lines = [
            "#if NNEDGE_PROFILE",
            '    printf("NNC_PROFILE_BEGIN\\n");',
        ]
        for index, node in enumerate(self.program.nodes):
            label = ",".join(output.name for output in node.outputs) or f"node_{index}"
            lines.append(
                f'    printf("NNC_PROFILE\\t{index}\\t{label}\\t{node.op}\\t%llu\\n", '
                f"(unsigned long long)profile_cycles_{index});"
            )
        lines.extend([
            '    printf("NNC_PROFILE_END\\n");',
            "#endif",
        ])
        return lines

    def render_call(self, node: LoweredNode) -> str:
        args = ", ".join(self.arg(arg) for arg in node.args)
        outs = ", ".join(output.name for output in node.outputs)
        match node.op:
            case "rms_norm":
                return (
                    f"nnedge::op::rms_norm({outs}, {args}, "
                    f"ctx->{node.attrs['weight']}, "
                    f"ctx->{node.attrs['eye']}, "
                    f"ctx->{node.attrs['reduce_weight']}, "
                    f"ctx->{node.attrs['square_weight']}, "
                    f"{node.attrs['eps']})"
                )
            case "linear":
                return (
                    f"nnedge::op::linear({outs}, {args}, "
                    f"nnedge::Quant::{node.attrs['quant']}, "
                    f"nnedge::Tile::{self.cpp_enum(node.attrs['tile'])})"
                )
            case "rope":
                return f"nnedge::op::rope({outs}, {args}, ctx->{node.attrs['rope_table']})"
            case "kv_cache_update":
                return f"nnedge::op::kv_cache_update({outs}, {args})"
            case "attention":
                return (
                    f"nnedge::op::attention({outs}, {args}, "
                    f"ctx->{node.attrs['eye']}, {node.attrs['head_count']}u)"
                )
            case "add":
                return f"nnedge::op::add({outs}, {args}, ctx->{node.attrs['eye']}, {node.attrs['alpha']})"
            case "mul":
                return f"nnedge::op::mul({outs}, {args}, ctx->{node.attrs['eye']})"
            case "softmax":
                return f"nnedge::op::softmax({outs}, {args}, ctx->{node.attrs['eye']})"
            case "matmul" | "matmul_transpose":
                return (
                    f"nnedge::op::{node.op}({outs}, {args}, "
                    f"{node.attrs.get('head_count', '1')}u)"
                )
            case "sigmoid" | "silu" | "tanh":
                return f"nnedge::op::{node.op}({outs}, {args})"
            case _:
                raise SystemExit(f"unsupported render op: {node.op}")

    @staticmethod
    def shape_literal(shape: Shape) -> str:
        return "nnedge::Shape{" + ", ".join(str(dim) for dim in shape) + "}"

    def arg(self, name: str) -> str:
        if name in self.input_remap:
            return self.input_remap[name]
        return f"ctx->{name}" if name in self.weight_names else name

    @staticmethod
    def cpp_enum(name: str) -> str:
        return f"{name}_" if name in {"auto"} else name


def compile_model(model: Any, example_args: tuple[Any, ...]) -> tuple[LoweredProgram, WeightStore]:
    lowerer = Lowerer(export_graph(model, example_args), dict(model.named_parameters()))
    return lowerer.lower(), lowerer.weights


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, default=Path("example/llama/build/generated"))
    parser.add_argument(
        "--model-file",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "example" / "llama" / "model" / "llama3_source.py",
    )
    args = parser.parse_args()

    model, example_args = load_model_example(args.model_file)
    abi = ForwardABI.from_example(model, example_args)
    program, weight_store = compile_model(model, example_args)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "forward.hpp").write_text(
        ForwardRenderer(program, abi, weight_store).render(),
        encoding="utf-8",
    )
    (args.out_dir / "init.hpp").write_text(InitRenderer(abi, weight_store).render(), encoding="utf-8")
    weight_store.write_weight_bin(args.out_dir / "weight.bin")


if __name__ == "__main__":
    main()
