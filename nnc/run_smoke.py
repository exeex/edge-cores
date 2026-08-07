#!/usr/bin/env python3
"""Generate, build, run, and check one NNC model on encrypted Verilator."""

from __future__ import annotations

import argparse
import csv
import importlib.util
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
from typing import Any

import torch


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = REPO_ROOT / "example/llama/model/smoke_linear.py"
DEFAULT_MAIN = REPO_ROOT / "example/llama/src/smoke_main.cpp"


def compiler_module() -> Any:
    path = Path(__file__).with_name("compiler.py")
    spec = importlib.util.spec_from_file_location("edge_nnc_compiler", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def tool(env_name: str, fallback: str) -> str:
    explicit = os.environ.get(env_name)
    if explicit:
        return explicit
    path = shutil.which(fallback)
    if path:
        return path
    homebrew = Path("/opt/homebrew/opt/llvm/bin") / fallback
    if homebrew.exists():
        return str(homebrew)
    raise SystemExit(f"missing tool: {fallback} (override with {env_name})")


def generate(model_file: Path, generated_dir: Path) -> tuple[int, ...]:
    compiler = compiler_module()
    model, example_args = compiler.load_model_example(model_file)
    abi = compiler.ForwardABI.from_example(model, example_args)
    program, weights = compiler.compile_model(model, example_args)
    generated_dir.mkdir(parents=True, exist_ok=True)
    (generated_dir / "forward.hpp").write_text(
        compiler.ForwardRenderer(program, abi, weights).render(), encoding="utf-8"
    )
    (generated_dir / "init.hpp").write_text(
        compiler.InitRenderer(abi, weights).render(), encoding="utf-8"
    )
    weights.write_weight_bin(generated_dir / "weight.bin")

    with torch.no_grad():
        result = model(*example_args)
    if isinstance(result, tuple):
        if len(result) != 1:
            raise SystemExit("runner supports exactly one output tensor")
        result = result[0]
    bits = result.detach().to(torch.bfloat16).contiguous().view(torch.int16).flatten()
    return tuple(int(value) & 0xffff for value in bits.tolist())


def build(args: argparse.Namespace, generated_dir: Path, build_dir: Path) -> None:
    clang = tool("CLANG", "clang")
    clangxx = tool("CLANGXX", "clang++")
    objcopy = tool("LLVM_OBJCOPY", "llvm-objcopy")
    lld = tool("LLD", "ld.lld")
    target = [
        "--target=riscv64-unknown-elf",
        "-march=rv64imaf_zicsr_zfh_zfbfmin",
        "-mabi=lp64",
        "-mcmodel=medany",
    ]
    build_dir.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        clang, *target, "-c", str(REPO_ROOT / "cpp/baremetal/crt0.s"),
        "-o", str(build_dir / "crt0.o"),
    ], check=True)
    profile = ["-DNNEDGE_PROFILE=1"] if args.profile else []
    subprocess.run([
        clangxx, *target, "-std=c++17", "-ffreestanding", "-fno-builtin",
        "-fno-exceptions", "-fno-rtti", "-fno-pic", "-fno-pie", "-O2",
        "-Wall", "-Wextra", *profile,
        f"-DNNEDGE_OUTPUT_BASE=0x{args.output_base:x}u",
        f"-I{REPO_ROOT / 'cpp'}", f"-I{REPO_ROOT / 'cpp/intrinsic'}",
        f"-I{generated_dir}",
        "-c", str(args.main_file), "-o", str(build_dir / "main.o"),
    ], check=True)
    subprocess.run([
        objcopy, "-I", "binary", "-O", "elf64-littleriscv", "-B", "riscv",
        "--rename-section", ".data=.nnedge_weights,alloc,load,readonly,data,contents",
        str(generated_dir / "weight.bin"), str(build_dir / "weights.o"),
    ], check=True)
    subprocess.run([
        clang, *target, "-fuse-ld=lld", f"-B{Path(lld).parent}",
        "-nostdlib", "-nostartfiles",
        f"-Wl,-T,{REPO_ROOT / 'cpp/baremetal/linker.ld'}", "-Wl,--gc-sections",
        str(build_dir / "crt0.o"), str(build_dir / "main.o"),
        str(build_dir / "weights.o"), "-o", str(build_dir / "llama.elf"),
    ], check=True)
    subprocess.run([
        sys.executable, str(REPO_ROOT / "tools/elf2mem128.py"),
        str(build_dir / "llama.elf"), "-o", str(build_dir / "llama.memh"),
        "--words-file", str(build_dir / "llama.words"),
        "--base", "0x0", "--size", "0x600000",
    ], check=True)


def bf16(value: int) -> float:
    return struct.unpack("<f", struct.pack("<I", value << 16))[0]


def check_output(path: Path, expected: tuple[int, ...], tolerance: float) -> None:
    raw = bytes(int(line, 16) for line in path.read_text().splitlines() if line.strip())
    actual = struct.unpack(f"<{len(raw) // 2}H", raw)
    if len(actual) != len(expected):
        raise SystemExit(f"output size mismatch: {len(actual)} != {len(expected)}")
    errors = [abs(bf16(got) - bf16(want)) for got, want in zip(actual, expected)]
    bad = [index for index, error in enumerate(errors) if math.isnan(error) or error > tolerance]
    if bad:
        details = ", ".join(
            f"[{i}] got=0x{actual[i]:04x} want=0x{expected[i]:04x}" for i in bad[:8]
        )
        raise SystemExit(f"output mismatch ({len(bad)} values): {details}")
    print(f"COMPARE PASS values={len(expected)} max_abs={max(errors, default=0):.6g}")


def parse_profile(console: str) -> list[dict[str, int | str]]:
    records: list[dict[str, int | str]] = []
    inside = False
    saw_end = False
    for line in console.splitlines():
        if line == "NNC_PROFILE_BEGIN":
            inside = True
            continue
        if line == "NNC_PROFILE_END":
            if not inside:
                raise SystemExit("profile end marker without begin marker")
            inside = False
            saw_end = True
            continue
        if not inside:
            continue
        fields = line.split("\t")
        if len(fields) != 5 or fields[0] != "NNC_PROFILE":
            raise SystemExit(f"malformed profile record: {line!r}")
        records.append({
            "node_index": int(fields[1]), "node_name": fields[2],
            "op": fields[3], "cycles": int(fields[4]),
        })
    if inside or not saw_end or not records:
        raise SystemExit("profiling enabled but no complete profile was emitted")
    return records


def write_profile(build_dir: Path, records: list[dict[str, int | str]]) -> None:
    total = sum(int(record["cycles"]) for record in records)
    ranked = sorted(records, key=lambda record: int(record["cycles"]), reverse=True)
    tsv = build_dir / "profile.tsv"
    with tsv.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
        writer.writerow(("rank", "node_index", "node_name", "op", "cycles", "percent"))
        for rank, record in enumerate(ranked, 1):
            cycles = int(record["cycles"])
            writer.writerow((rank, record["node_index"], record["node_name"],
                             record["op"], cycles,
                             f"{100.0 * cycles / total if total else 0.0:.2f}"))

    lines = [
        "# NNC operator profile", "",
        f"Total measured operator cycles: **{total}**", "",
        "Percentages are shares of summed operator cycles; allocation, copies, and printf are excluded.",
        "", "| Rank | Node | Name | Op | Cycles | Share |",
        "| ---: | ---: | --- | --- | ---: | ---: |",
    ]
    for rank, record in enumerate(ranked, 1):
        cycles = int(record["cycles"])
        percent = 100.0 * cycles / total if total else 0.0
        lines.append(
            f"| {rank} | {record['node_index']} | `{record['node_name']}` | "
            f"`{record['op']}` | {cycles} | {percent:.2f}% |"
        )
    markdown = build_dir / "profile.md"
    markdown.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"PROFILE {markdown}")
    print(f"PROFILE {tsv}")


def run(args: argparse.Namespace, build_dir: Path, expected: tuple[int, ...]) -> None:
    subprocess.run([str(REPO_ROOT / "scripts/build-verilator.sh")], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    sim = Path(args.sim_exe) if args.sim_exe else REPO_ROOT / "build/verilator/obj/Vedge_soc_demo_tb"
    words = (build_dir / "llama.words").read_text().strip()
    dump = build_dir / "actual.hex"
    command = [
        str(sim), "+verilator+quiet", f"+mem128={build_dir / 'llama.memh'}",
        f"+mem128_words={words}", f"+max_cycles={args.max_cycles}",
        f"+dump_base={args.output_base}", f"+dump_len={len(expected) * 2}",
        f"+dump_file={dump}", f"+run_case_report={build_dir / 'run_case.report'}",
    ]
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT)
    (build_dir / "software-console.log").write_text(result.stdout, encoding="utf-8")
    print("\n".join(line for line in result.stdout.splitlines()
                    if not line.startswith("- ") or "Verilog $finish" not in line))
    if result.returncode != 0:
        raise SystemExit(result.returncode)
    check_output(dump, expected, args.max_abs_error)
    if args.profile:
        write_profile(build_dir, parse_profile(result.stdout))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-file", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--main-file", type=Path, default=DEFAULT_MAIN)
    parser.add_argument("--build-dir", type=Path)
    parser.add_argument("--build-only", action="store_true")
    parser.add_argument("--profile", action="store_true")
    parser.add_argument("--output-base", type=lambda text: int(text, 0), default=0x100000)
    parser.add_argument("--max-cycles", type=int, default=600000)
    parser.add_argument("--max-abs-error", type=float, default=0.05)
    parser.add_argument("--sim-exe")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    build_dir = args.build_dir or REPO_ROOT / "example/llama/build" / args.model_file.stem
    generated_dir = build_dir / "generated"
    expected = generate(args.model_file, generated_dir)
    build(args, generated_dir, build_dir)
    print(f"BUILT {build_dir / 'llama.elf'}")
    if not args.build_only:
        run(args, build_dir, expected)


if __name__ == "__main__":
    main()
