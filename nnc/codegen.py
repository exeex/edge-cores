"""Render the lowered program and model IO as bare-metal C++ headers."""

from __future__ import annotations

import struct

from nnc.graph import AbiValue, ForwardABI, LoweredNode, LoweredProgram, Shape
from nnc.liveness import Liveness
from nnc.weights import WeightStore


class InitRenderer:
    def __init__(self, abi: ForwardABI, weights: WeightStore) -> None:
        self.abi = abi
        self.weights = weights
        self.input_offsets, self.input_data = self.layout_inputs()
        self.output_offsets, self.output_bytes = self.layout_outputs()

    @staticmethod
    def align(value: int) -> int:
        return (value + 63) & ~63

    def layout_inputs(self) -> tuple[dict[str, int], bytes]:
        offsets: dict[str, int] = {}
        data = bytearray()
        for value in self.abi.inputs:
            if value.kind != "tensor":
                continue
            data.extend(bytes(self.align(len(data)) - len(data)))
            offsets[value.name] = len(data)
            bits = value.init_bits or (0,) * self.numel(value.shape)
            if len(bits) != self.numel(value.shape):
                raise SystemExit(f"input tensor {value.name} has mismatched shape and data")
            data.extend(struct.pack(f"<{len(bits)}H", *bits))
        return offsets, bytes(data)

    def layout_outputs(self) -> tuple[dict[str, int], int]:
        offsets: dict[str, int] = {}
        cursor = 0
        for value in self.abi.outputs:
            if value.kind != "tensor":
                continue
            cursor = self.align(cursor)
            offsets[value.name] = cursor
            cursor += self.numel(value.shape) * 2
        return offsets, self.align(cursor)

    def render_context(self) -> list[str]:
        lines = ["struct Context {"]
        for record in self.weights.records.values():
            lines.append(f"    Tensor<{record.ctype}> {record.tensor.name};")
        lines.append("};")
        return lines

    def render_weight_init(self) -> list[str]:
        lines = ["inline void init(Context *ctx, unsigned char *weight_base)", "{"]
        for record in self.weights.records.values():
            shape = self.shape_literal(record.tensor.shape)
            lines.append(
                f"    ctx->{record.tensor.name} = Tensor<{record.ctype}>({shape}, "
                f"reinterpret_cast<{record.ctype} *>(weight_base + {record.offset}));"
            )
        lines.append("}")
        return lines

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
            'static_assert(sizeof(dtype) == 2, "NNC IO payloads require BF16");',
            'static_assert(nnedge::kArenaAlign == 64, "NNC IO offsets require 64-byte alignment");',
            "",
            f"constexpr nnedge::size_t kWeightBytes = {self.weights.cursor};",
            "",
            *self.render_context(),
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
            f"alignas(nnedge::kArenaAlign) inline unsigned char output_storage[{max(self.output_bytes, 1)}]",
            '    __attribute__((used, section(".nnedge_outputs")));',
            "",
            *self.render_weight_init(),
            "",
            'extern "C" const unsigned char weight_begin[];',
            'extern "C" const unsigned char input_begin[];',
            'extern "C" unsigned char output_begin[];',
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
        return [f"inline Tensor<dtype> {value.name};"]

    def render_mio_init(self, value: AbiValue) -> list[str]:
        if value.kind == "size_t":
            return [f"    mio::{value.name} = {value.init_size};"]
        if value.name in self.input_offsets:
            offset = self.input_offsets[value.name]
            address = f"const_cast<unsigned char *>(input_begin) + {offset}"
        else:
            offset = self.output_offsets[value.name]
            address = f"output_begin + {offset}"
        lines = [f"    mio::{value.name} = Tensor<dtype>({self.shape_literal(value.shape)}, "
                 f"reinterpret_cast<dtype *>({address}));"]
        if value.name in self.input_offsets:
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
