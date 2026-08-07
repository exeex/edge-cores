#!/usr/bin/env python3
"""Run every Llama NNC smoke and profile llama3_source.py."""

from __future__ import annotations

import argparse
import csv
import os
from pathlib import Path
import re
import subprocess
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
TEST_DIR = REPO_ROOT / "nnc/test"
EXAMPLE_MODEL = REPO_ROOT / "example/llama/model/llama3_source.py"
DEFAULT_OUT = REPO_ROOT / "example/llama/build/harness"


def run_case(model: Path, out_dir: Path, sim_exe: Path, *, profile: bool) -> dict[str, object]:
    build_dir = REPO_ROOT / "example/llama/build" / model.stem
    command = [
        sys.executable, str(REPO_ROOT / "nnc/run_smoke.py"),
        "--model-file", str(model), "--build-dir", str(build_dir),
        "--sim-exe", str(sim_exe), "--skip-verilator-build",
        "--max-cycles", "2000000",
    ]
    if profile:
        command.append("--profile")
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / f"{model.stem}.log").write_text(result.stdout, encoding="utf-8")
    cycle_match = re.search(r"EDGE_DEMO TEST PASS cycle=(\d+)", result.stdout)
    compare_match = re.search(r"COMPARE PASS values=(\d+) max_abs=([^\s]+)", result.stdout)
    return {
        "model": model.name,
        "status": "PASS" if result.returncode == 0 else "FAIL",
        "cycles": int(cycle_match.group(1)) if cycle_match else "",
        "values": int(compare_match.group(1)) if compare_match else "",
        "max_abs": compare_match.group(2) if compare_match else "",
        "profile": profile,
        "log": out_dir / f"{model.stem}.log",
    }


def write_report(out_dir: Path, records: list[dict[str, object]]) -> None:
    tsv = out_dir / "harness.tsv"
    with tsv.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
        writer.writerow(("model", "status", "simulation_cycles", "values", "max_abs", "profile"))
        for record in records:
            writer.writerow((record["model"], record["status"], record["cycles"],
                             record["values"], record["max_abs"],
                             "yes" if record["profile"] else "no"))

    passed = sum(record["status"] == "PASS" for record in records)
    lines = [
        "# Llama NNC harness", "",
        f"Result: **{passed}/{len(records)} passed**", "",
        "| Model | Status | Simulation cycles | BF16 values | Max abs error | Profile |",
        "| --- | --- | ---: | ---: | ---: | --- |",
    ]
    for record in records:
        profile = "[report](../llama3_source/profile.md)" if record["profile"] else ""
        lines.append(
            f"| `{record['model']}` | {record['status']} | {record['cycles']} | "
            f"{record['values']} | {record['max_abs']} | {profile} |"
        )
    (out_dir / "harness.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    verilator_out = args.out_dir / "verilator"
    sim_exe = verilator_out / "obj/Vedge_soc_demo_tb"
    env = os.environ.copy()
    env["EDGE_VERILATOR_OUT"] = str(verilator_out)
    subprocess.run([str(REPO_ROOT / "scripts/build-verilator.sh")], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                   env=env)
    test_llama = TEST_DIR / "llama3_source.py"
    if test_llama.read_bytes() != EXAMPLE_MODEL.read_bytes():
        raise SystemExit(
            "nnc/test/llama3_source.py is out of sync with "
            "example/llama/model/llama3_source.py"
        )
    models = sorted(TEST_DIR.glob("smoke_*.py"))
    models.append(test_llama)
    records = []
    for index, model in enumerate(models, 1):
        profile = model.name == "llama3_source.py"
        print(f"[{index}/{len(models)}] {model.name}", flush=True)
        record = run_case(model, args.out_dir, sim_exe, profile=profile)
        records.append(record)
        print(f"  {record['status']} cycles={record['cycles']} max_abs={record['max_abs']}",
              flush=True)
    write_report(args.out_dir, records)
    print(f"HARNESS {args.out_dir / 'harness.md'}")
    if any(record["status"] != "PASS" for record in records):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
