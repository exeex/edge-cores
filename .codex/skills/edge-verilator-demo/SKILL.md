---
name: edge-verilator-demo
description: Build or debug the public Edge SoC Verilator demo that uses only src/edge-e3enc/edge_e3enc.v as its core RTL input.
---

# Encrypted Edge Verilator demo

Use `scripts/build-verilator.sh` as the maintained simulator build entry point.
The core RTL input must remain `src/edge-e3enc/edge_e3enc.v`; do not silently
switch the public flow back to files under private `src/edge-e3`.

The SoC wrapper and testbench live under `src/soc`. SRAM boundary models are
listed in `src/edge-e3enc/edge_e3enc_sram.fl` and currently come from the
optional private product submodule. Keep any failure about missing encrypted
RTL, SoC files, or SRAM models explicit.

Validate changes by running:

```sh
./scripts/build-verilator.sh
```

The expected executable is `build/verilator/obj/Vedge_soc_demo_tb` unless
`EDGE_VERILATOR_OUT` overrides the build directory.
