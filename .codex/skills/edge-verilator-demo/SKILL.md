---
name: edge-verilator-demo
description: Build or debug the public Edge SoC Verilator demo using the public E3, Edge32 and shared ASIC RTL sources.
---

# Public Edge Verilator demo

Use `scripts/build-verilator.sh` as the maintained simulator build entry point.
Initialize `src/edge-e3`, `src/edge-32` and `src/edge-asic`. E3 RTL is public;
private test repositories such as `src/test-e3` are optional and must not be
required by the public build. Do not copy internal test suites into this repo.

`tools/prepare_e3_filelist.py` resolves the upstream E3 filelist to public RTL
inputs and replaces its internal test-model reference with the local public
SRAM behavioral model in `src/soc/logical/mem/edge_sram_sim.v`. The generated
filelist belongs under the ignored simulator build directory. Keep the SoC
wrapper and testbench under `src/soc`. Build directly from the public source
filelist.

Validate with `./scripts/build-verilator.sh`, hello, tensor and ACTU examples.
For compiler/runtime or accelerator changes, also run the complete NNC suite.
Inspect `TEST PASS` and BF16 comparison results, not just shell exit codes.

The executable is `build/verilator/obj/Vedge_soc_demo_tb` unless
`EDGE_VERILATOR_OUT` overrides the build directory. Never rebuild the same
simulator directory concurrently.
