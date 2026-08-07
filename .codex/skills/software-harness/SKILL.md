---
name: software-harness
description: Run, extend, debug, or review the public edge-e3 bare-metal software harness, including encrypted Verilator builds, hello and tensor examples, all example/llama/model smoke cases, PyTorch BF16 comparison, llama3_source.py per-node profiling, and regression reports. Use after changes to cpp, nnc, example software, public SoC testbench output/dump behavior, or encrypted-core software execution.
---

# Software Harness

Use only the public encrypted-core path. Keep `src/edge-e3` deinitialized while
validating the public harness; `scripts/build-verilator.sh` must obtain the core
and SRAM models exclusively from `src/edge-e3enc`.

## Select the validation scope

- For console/startup changes, run `./example/hello/run.sh`.
- For intrinsic or Tensor datapath changes, run `./example/tensor/run.sh`.
- For one NNC model, run
  `./example/llama/run.sh --model-file example/llama/model/smoke_<op>.py`.
- For NNC compiler/runtime, Matmul, Attention, DMA layout, or composed-model
  changes, run the complete Llama suite with `./example/llama/test.sh`.
- For public RTL, SRAM, SoC wrapper, or testbench changes, first run
  `./scripts/build-verilator.sh`, then the relevant software cases.

Set `PYTHON=/path/to/python` when PyTorch is installed in a virtual environment.
Install the Python dependency from `nnc/requirements.txt` when needed.

## Run the complete public regression

Verify the private source submodule is absent, then run:

```sh
git submodule status src/edge-e3
python3 -m unittest nnc.test_compiler
./example/hello/run.sh
./example/tensor/run.sh
./example/llama/test.sh
```

The submodule status must begin with `-`. Do not initialize `src/edge-e3` to
make a public case pass.

## Llama suite contract

`example/llama/test.sh` must:

- build one suite-private simulator below `example/llama/build/harness/verilator`;
- discover every `example/llama/model/smoke_*.py` without a skip list;
- run each model in an isolated Python process and compare its BF16 output with
  the PyTorch golden;
- run `example/llama/model/llama3_source.py` directly with `--profile`;
- continue after individual failures so the final report is complete;
- exit nonzero unless every model passes.

Do not replace a failing semantic test by loosening tolerance, changing its
golden layout, or adding a skip. Remove a model only when the user identifies it
as obsolete. Preserve PyTorch-contiguous public tensor layouts; accelerator
packing belongs inside an operator. Use the `llama-nnc` skill for detailed NNC
lowering and memory rules.

## Require and inspect reports

The Llama suite succeeds only when `harness.md` reports every discovered case
as PASS. Inspect these artifacts:

- `example/llama/build/harness/harness.md`: human-readable suite summary.
- `example/llama/build/harness/harness.tsv`: machine-readable summary.
- `example/llama/build/harness/<model>.log`: complete per-model output.
- `example/llama/build/llama3_source/profile.md`: ranked node cycles and share.
- `example/llama/build/llama3_source/profile.tsv`: machine-readable profile.
- `example/llama/build/llama3_source/software-console.log`: raw records.

Treat profile percentages as shares of summed measured operator calls, not full
simulation cycles. Allocation, copies, startup, and printf are excluded.

## Diagnose failures

1. Read the failing model log before rerunning it alone.
2. Reproduce one model with `nnc/run_smoke.py --model-file ...`.
3. Distinguish export/lowering, RISC-V build, simulator, return status, and BF16
   comparison failures.
4. For a missing simulator during a suite, verify the suite-private path; do
   not share `build/verilator/obj` across concurrent harnesses.
5. After fixing one case, rerun the complete suite because tensor layout and
   allocator changes commonly affect composed paths.

Keep generated outputs under ignored `build/` directories. Do not commit ELFs,
memory images, logs, or generated profile reports.
