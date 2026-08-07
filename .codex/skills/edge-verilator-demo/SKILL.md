---
name: edge-verilator-demo
description: Build or debug the public Edge SoC Verilator demo that uses only src/edge-e3enc/edge_e3enc.v as its core RTL input.
---

# Encrypted Edge Verilator demo

Use `scripts/build-verilator.sh` as the maintained simulator build entry point.
The core RTL input must remain `src/edge-e3enc/edge_e3enc.v`; do not silently
switch the public flow back to files under private `src/edge-e3`.

The SoC wrapper and testbench live under `src/soc`. Public SRAM boundary models
live under `src/edge-e3enc/sram` and are listed by
`src/edge-e3enc/edge_e3enc_sram.fl`. The build must not read `src/edge-e3`;
keep failures about missing encrypted RTL, SoC files, or SRAM models explicit.

Validate changes by running:

```sh
./scripts/build-verilator.sh
```

The expected executable is `build/verilator/obj/Vedge_soc_demo_tb` unless
`EDGE_VERILATOR_OUT` overrides the build directory.
