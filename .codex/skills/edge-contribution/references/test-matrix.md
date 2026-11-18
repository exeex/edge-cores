# Contribution test matrix

Choose tests by changed surface, starting with the smallest focused case.
Combine coverage when a change crosses rows. Run commands from the workspace
root; [tests/README.md](../../../../tests/README.md) describes ownership and
[tests/run.sh](../../../../tests/run.sh) implements the current routes.

| Changed surface | Required validation |
| --- | --- |
| Documentation or skill only | Local link/format checks and `git diff --check` |
| Public E3/Edge-32/shared ASIC RTL, filelists or SoC boundary | Public Verilator build, hello/tensor/ACTU examples and `./tests/run.sh interface`; broaden for affected software |
| Console, boot, CSR or basic scalar behavior | `./example/hello/run.sh`; add relevant scalar-format examples when affected |
| Tensor/DMA/accelerator instruction path | `./example/tensor/run.sh` and interface; add ACTU for shared command/I/O changes and NNC for runtime/composed paths |
| ACTU/CMPU or shared accelerator I/O | `./example/actu/run.sh`; add tensor/interface and affected NNC models for shared paths |
| C++ intrinsic or bare-metal runtime | Hello, affected examples and interface; inspect emitted instruction words/operands when encodings change |
| NNC compiler lowering | `PYTHON=.venv/bin/python ./tests/run.sh nnc-unit` and affected smoke models |
| NNC runtime, tensor layout, allocator, DMA ownership or composed model | `./tests/run.sh nnc`, interface and affected examples |
| Saved model/quantization artifacts | Fresh generation plus saved-artifact replay, matched headers/payloads/`io_layout.json` and unchanged logical goldens |
| Public source integration or broad cross-layer change | `./tests/run.sh all` using the intended public pins, without private test dependencies |

For RTL changes add focused tests of the actual command/memory contract;
software regression does not exhaust queue, reset or simultaneous-event
corner cases. See [integration verification](../../integrate-your-design/references/verification.md).
Historical `edge-rv`/`edge-rv-lite` frontends need their own declared sources
and tests; the current product routes validate Edge-32/E3.

## Prepare and select the route

Initialize `src/edge-e3`, `src/edge-32` and `src/edge-asic` at their intended
pins, plus `src/edge-nnc` for compiler/runtime tests and examples that use it.
Record parent and component revisions and any local changes. Prepare NNC with
`./scripts/setup-python.sh`; use the project `.venv` or an explicit prepared
`PYTHON` containing PyTorch and editable NNC from this checkout.

`./tests/run.sh --list` lists these groups:

- `nnc-unit`: NNC Python unit discovery; no RTL execution.
- `nnc`: units, every discovered model smoke and Llama profiling, then packed
  C++ tests for WSLD, weight packing and cache ownership. The adapter attempts
  all three phases and returns failure if any fails.
- `interface`: filelist tests plus six direct Matmul cases against independent
  bit-exact goldens, using workspace intrinsics and public RTL.
- `examples`: independent hello, tensor, ACTU, scalar-format and six saved
  quantized Linear examples.
- `all`: NNC, interface and examples, continuing across failed groups and
  returning nonzero if any group fails.

`example/llama/test.sh` is a compatibility entry for `nnc`, not a single-model
test. Run an affected smoke via `./example/llama/run.sh --model-file <path>`.
Keep semantic tests and golden generation in NNC; the workspace owns adapters
and interface sentinels. CoreMark and Tensor performance benchmarks are
separate from this correctness regression.

## Full public regression

For broad instruction, memory-ordering, SoC or cross-layer changes:

```sh
git submodule status -- src/edge-e3 src/edge-32 src/edge-asic src/edge-nnc
PYTHON=.venv/bin/python ./tests/run.sh all
```

The runners build the simulator as needed. Hello, tensor and ACTU each rebuild
it and have no generic skip-build option. Interface supports
`./tests/run.sh interface --skip-verilator-build` only after an explicit build
of the reviewed sources with `./scripts/build-verilator.sh`.
Never rebuild the same simulator output concurrently; use a distinct absolute
`EDGE_VERILATOR_OUT` for independent runs. See
[Verilator workflow](../../edge-verilator-demo/SKILL.md) for output ownership.

## Inspect reports and report results

Require fresh logs/reports from the stated command, not artifacts left by an
older run. Default evidence paths and checks are:

| Route | Evidence |
| --- | --- |
| `all` / `examples` | `build/tests/<group>/summary.tsv` and per-case logs; every scheduled entry must pass |
| NNC model harness | `src/edge-nnc/example/llama/build/harness/harness.md`, `harness.tsv` and per-model logs; every discovered model accounted for |
| Interface | `tests/interface/build/run.log` contains `MATMUL_INTERFACE PASS cases=6`; `run_case.report` contains `TEST PASS` |
| Packed C++ | `tests/nnc/build/packed/summary.tsv`, per-case simulator reports and `PACKED ALL PASS cases=26`, `WEIGHT PACK ALL PASS cases=16`, `CACHE OWNERSHIP PASS` markers |
| Individual examples | Their build/run logs, simulator report and workload-specific completion/comparison checks |

Output overrides can relocate these paths; report the actual location.
Require simulator `TEST PASS` plus `COMPARE PASS` where the model runner uses
that comparator. A zero exit alone is insufficient when a separate report
carries the result. Do not loosen tolerances, alter logical goldens or skip
models to hide a regression. See [software harness](../../software-harness/SKILL.md)
for comparison and profile interpretation.

For every command record PASS, FAIL or NOT RUN. Include exact commands,
versions/revisions, short failure diagnostics and whether the base revision
was tested. Report unexercised custom tops or optional mechanisms explicitly;
a passing standard example does not establish their correctness. Keep generated
ELFs, memory images, logs and Verilator trees out of ordinary source commits.

Benchmark claims additionally need workload, precision, timing boundary,
baseline, clock assumption where relevant and simulation/synthesis/FPGA/silicon
context. Historical release results are evidence for their recorded revisions,
not a substitute for validating the changed contribution.
