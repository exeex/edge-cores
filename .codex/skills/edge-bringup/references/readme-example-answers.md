# README example answers

Use these as current capability answers. Inspect the named workflow before
claiming a fresh test or benchmark result.

## How do I run the edge-e3 RTL smoke tests?

Install the host dependencies, initialize `src/edge-e3`, `src/edge-32` and `src/edge-asic`, then run:

```sh
./scripts/build-verilator.sh
./example/hello/run.sh
./example/tensor/run.sh
```

Use `./example/llama/test.sh` only when the full public software/NNC regression
is needed. Every executed example must produce `TEST PASS`.

## Run the Edge vs T-Head C906 benchmarks and summarize the results

For the currently maintained CoreMark comparison, run:

```sh
.codex/skills/edge-tensor-example/scripts/run-coremark-compare.sh
```

Report `cycle_delta` as internal `rdcycle` cycles per iteration and state the
ISA/configuration difference. This fixed two-iteration RTL run is not an
official ten-second CoreMark submission. Rerun before quoting a current result.

## I downloaded a model from Hugging Face. How do I run it on edge-e3?

The public flow composes PyTorch `nn.Module` models with NNC modules and calls
`nnc.compile()`. It includes six quantized Linear presets (including native
MXFP4/NVFP4) and a reduced Llama transformer graph. Map the downloaded model's
architecture and operators to supported NNC modules/lowering/runtime ops,
then validate a reduced model with `./example/llama/run.sh --model-file <file.py>`.
The source adapter expects `make_model_and_args()`.

There is no general Hugging Face checkpoint loader. Current quantized module
constructors wrap ordinary `torch.nn.Linear` and use preset quantizers;
constructing them from user-quantized Linear weights/scales is pending.
Existing function ops support explicit static codes/scales in their supported
formats. Do not claim arbitrary downloaded checkpoints run unchanged.

## Add llama.cpp Q4_K_M support to the tensor unit and NNC runtime

E3 RTL is public in `src/edge-e3`, with reusable datapaths in `src/edge-asic`
and compiler/runtime code in `src/edge-nnc`. Q4_K_M still requires its own
format decoding, hardware mapping, lowering and correctness work; existing
FP4 support does not establish Q4_K_M support. Define a reduced golden model,
implement the affected layers, then run compiler and RTL regressions.

## I want to add <feature>. Where should I start, and which tests should I run?

For RTL features, start in public `src/edge-e3`, `src/edge-asic` or
`src/edge-32`, depending on ownership. For compiler/runtime changes, work in
`src/edge-nnc` through the `nnc` and `cpp/libnn` compatibility paths. Select
public examples and NNC tests from `software-harness` and `edge-nnc`.
Private test repositories such as `src/test-e3` remain optional and should not
be copied into the public workspace.
