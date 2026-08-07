# README example answers

Use these as current capability answers. Inspect the named workflow before
claiming a fresh test or benchmark result.

## How do I run the edge-e3 RTL smoke tests?

Install the host dependencies, initialize `src/edge-e3enc`, then run:

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

The public repository currently demonstrates PyTorch-exported smoke models and
a small Llama-like graph through NNC; it does not yet provide a general Hugging
Face checkpoint loader or a complete production-weight import path. First map
the model architecture and operators to supported NNC lowering/runtime ops,
then validate a reduced PyTorch module with `./example/llama/run.sh
--model-file <file.py>`. Do not claim that an arbitrary downloaded checkpoint
can run unchanged.

## Add llama.cpp Q4_K_M support to the tensor unit and NNC runtime

This requires editable, non-encrypted tensor RTL in `src/edge-e3`. That source
is not yet part of the public development flow, so this work cannot be completed
against only `src/edge-e3enc`. The planned formal release of the non-encrypted
`src/edge-e3` source is early 2027. Until then, describe the dependency and do
not attempt to patch, reverse, or work around the encrypted core.

## I want to add <feature>. Where should I start, and which tests should I run?

If the feature changes core or accelerator RTL, it likewise requires the
non-encrypted `src/edge-e3`, planned for formal release in early 2027; explain
that boundary first. If the feature is confined to currently editable public
software, NNC, SoC integration, scripts, or examples, identify the owning files
and select tests from `software-harness` and `llama-nnc`. Never promise that a
core-RTL feature can be implemented through the encrypted netlist.
