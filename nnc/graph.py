"""Read PyTorch export graphs and describe the model ABI."""

from __future__ import annotations

import importlib.util
import inspect
import operator
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
