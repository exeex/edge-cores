# Contribution test matrix

Choose tests by changed surface. Run broader coverage when a change crosses
multiple rows.

| Changed surface | Required validation |
| --- | --- |
| Documentation or skill only | Link/format checks and `git diff --check` |
| Public Edge RV RTL, filelists, SoC boundary | `./scripts/build-verilator.sh`, hello, tensor, and ACTU examples |
| Console, boot, CSR, or basic scalar behavior | Verilator build and `./example/hello/run.sh` |
| Tensor/DMA/accelerator instruction path | Verilator build and `./example/tensor/run.sh`; add ACTU when shared command/snapshot logic changes |
| ACTU/CMPU or shared accelerator I/O | Verilator build and `./example/actu/run.sh`; add tensor for shared paths |
| C++ intrinsic or bare-metal runtime | Relevant example plus hello; inspect emitted instruction encoding when changed |
| NNC compiler lowering | `python3 -m unittest nnc.test_compiler` and the affected smoke model |
| NNC runtime, tensor layout, allocator, DMA layout, or composed model | Python unit tests and `./example/llama/test.sh` |
| Release packaging or encrypted public consumer | Public build and examples with private source submodules deinitialized |

## Full public regression

Use this for broad Edge RV, command/snapshot, memory-ordering, SoC, or
cross-layer changes:

```sh
git submodule status src/edge-e3
python3 -m unittest nnc.test_compiler
./example/hello/run.sh
./example/tensor/run.sh
./example/actu/run.sh
./example/llama/test.sh
```

Require `src/edge-e3` status to begin with `-`. Inspect each generated report
for `TEST PASS`; a zero shell exit alone is insufficient when a harness writes
a separate report.

## Report results

For every command, record PASS, FAIL, or NOT RUN. For failures, link or quote a
short diagnostic and state whether the failure existed on the base revision.
Do not commit generated ELFs, memory images, logs, reports, or Verilator build
trees.

Benchmark claims must state workload, clock assumption, measured boundary,
baseline revision, and whether results are RTL simulation, synthesis, FPGA, or
silicon.
