---
name: software-harness
description: Run, extend, debug, or review the public edge-e3 bare-metal software harness, including public-source Verilator builds, hello and tensor examples, all example/llama/model smoke cases, PyTorch BF16 comparison, llama3_source.py per-node profiling, and regression reports. Use after changes to cpp, nnc, example software, public SoC testbench output/dump behavior, or public E3 software execution.
---

# Software Harness

Use the public E3, Edge32 and shared ASIC RTL through
`scripts/build-verilator.sh`. Private test repositories such as `src/test-e3`
are optional; do not copy them into this public flow. SRAM simulation models
are provided locally under `src/soc/logical/mem`.

## Select the validation scope

See `tests/README.md` for ownership and routes. NNC owns compiler/runtime
semantic tests in `src/edge-nnc`; workspace adapters must not duplicate them.
Use `tests/run.sh nnc-unit` for unit discovery, `tests/run.sh nnc` for NNC's
full regression, `tests/run.sh interface` for direct `matmul.hpp` plus public
filelist compatibility, and `tests/run.sh examples` for the independent
examples. `tests/run.sh all` runs all groups and reports failures separately.

- For console/startup changes, run `./example/hello/run.sh`.
- For intrinsic or Tensor datapath changes, run `./example/tensor/run.sh`.
- For one NNC model, run
  `./example/llama/run.sh --model-file nnc/test/smoke_<op>.py`.
- For NNC compiler/runtime, Matmul, Attention, DMA layout, or composed-model
  changes, run the complete Llama suite with `./example/llama/test.sh`.
- For public RTL, SRAM, SoC wrapper, or testbench changes, first run
  `./scripts/build-verilator.sh`, then the relevant software cases.

Set `PYTHON=/path/to/python` when PyTorch is installed in a virtual environment.
Install the Python dependency from `nnc/requirements.txt` when needed.

## Generated models versus saved examples

NNC model authoring uses `nn.Module` wrappers and `nnc.compile()`; see
`llama-nnc` for API selection and quantization limits. The six public
`example/linear_*` directories provide FP4, MXFP4, NVFP4, Q8_0 and both FP8
presets. Their `run.sh` files replay saved headers/input/weight/expected
artifacts without importing PyTorch. Regenerate explicitly with
`.venv/bin/python -m example.linear_<spec>.model` when source or format changes,
then validate the saved runner as well as fresh generation. Preserve each
artifact set together; a changed scale encoding can invalidate old payloads.

The Llama runner regenerates its model on each run. Its canonical source
composes NNC transformer modules and calls the same `nnc.compile()` API;
it remains a reduced transformer-block workload.

MXFP4/NVFP4 examples have no bias and require zero output tolerance. Other
models retain their documented tolerances. The generic runner defaults to
absolute error `0.05`; use `--max-abs-error 0` for precision-sensitive fixtures
or exact quantized-core claims. Require both simulator `TEST PASS` and
`COMPARE PASS`; do not treat program exit alone as numerical validation.

## Run the complete public regression

Initialize the public RTL and NNC submodules, then run:

```sh
git submodule status src/edge-e3
git submodule status src/edge-asic
python3 -m unittest nnc.test_compiler
./example/hello/run.sh
./example/tensor/run.sh
./example/llama/test.sh
```

Require the public RTL submodules to be initialized at their pinned commits.
The public regression must not require private test repositories.

## Llama suite contract

`example/llama/test.sh` must:

- build the workspace simulator once, then reuse it for each model;
- discover every `nnc/test/smoke_*.py` without a skip list;
- run each model in an isolated Python process and compare its BF16 output with
  the PyTorch golden;
- verify `nnc/test/llama3_source.py` matches the user-facing
  `example/llama/model.py`, then run the test copy with
  `--profile`;
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

- `src/edge-nnc/example/llama/build/harness/harness.md`: human-readable suite summary.
- `src/edge-nnc/example/llama/build/harness/harness.tsv`: machine-readable summary.
- `src/edge-nnc/example/llama/build/harness/<model>.log`: complete per-model output.
- `src/edge-nnc/example/llama/build/llama3_source/profile.md`: ranked node cycles and share.
- `src/edge-nnc/example/llama/build/llama3_source/profile.tsv`: machine-readable profile.
- `src/edge-nnc/example/llama/build/llama3_source/software-console.log`: raw records.

Treat profile percentages as shares of summed measured operator calls, not full
simulation cycles. Allocation, copies, startup, and printf are excluded.

## Diagnose failures

1. Read the failing model log before rerunning it alone.
2. Reproduce one model with `nnc/run_smoke.py --model-file ...`.
3. Distinguish export/lowering, RISC-V build, simulator, return status, and BF16
   comparison failures.
4. For a missing simulator, verify the workspace build path. Set a distinct
   `EDGE_VERILATOR_OUT` for concurrent harnesses; never rebuild the same output
   directory concurrently.
5. After fixing one case, rerun the complete suite because tensor layout and
   allocator changes commonly affect composed paths.

Keep generated outputs under ignored `build/` directories. Do not commit ELFs,
memory images, logs, or generated profile reports.
