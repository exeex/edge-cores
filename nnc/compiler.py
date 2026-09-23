#!/usr/bin/env python3
"""Compile a PyTorch model to NNC headers and ELF payloads.

The public compiler entry point keeps graph reading, lowering, and C++
generation separate. Tensor allocation remains in the runtime.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

# Allow both `python -m nnc.compiler` and `python nnc/compiler.py`.
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

# Keep existing `nnc.compiler` imports working while implementation lives in
# smaller modules.
from nnc.codegen import ForwardRenderer, InitRenderer
from nnc.graph import (
    AbiValue, ExportGraphReader, ForwardABI, Graph, GraphNode, LoweredNode,
    LoweredProgram, Shape, TensorSpec, export_graph, load_model_example,
)
from nnc.liveness import Liveness
from nnc.lowering import (
    OP_LOWERERS, AddLowerer, AttentionLowerer, BinarySameShapeLowerer,
    KvCacheLowerer, LinearLowerer, Lowerer, MatmulLowerer, MulLowerer,
    OpLowerer, RmsNormLowerer, RopeLowerer, SoftmaxLowerer, TensorTable,
    UnarySameShapeLowerer,
)
from nnc.weights import WeightRecord, WeightStore


def compile_model(model: Any, example_args: tuple[Any, ...]) -> tuple[LoweredProgram, WeightStore]:
    lowerer = Lowerer(export_graph(model, example_args), dict(model.named_parameters()))
    return lowerer.lower(), lowerer.weights


def write_artifacts(abi: ForwardABI, program: LoweredProgram,
                    weights: WeightStore, out_dir: Path) -> None:
    """Write every artifact consumed by the bare-metal build."""
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "forward.hpp").write_text(
        ForwardRenderer(program, abi, weights).render(), encoding="utf-8"
    )
    init = InitRenderer(abi, weights)
    (out_dir / "init.hpp").write_text(init.render(), encoding="utf-8")
    (out_dir / "input.bin").write_bytes(init.input_data)
    (out_dir / "weight.bin").write_bytes(weights.data)


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
    program, weights = compile_model(model, example_args)
    write_artifacts(abi, program, weights, args.out_dir)


if __name__ == "__main__":
    main()
