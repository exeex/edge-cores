# Generated edge-e3 RTL

`edge_e3enc.v` contains obfuscated non-SRAM RTL. The synthesizable SRAM
boundary models required by the public build are included in `sram/`; the
public flow does not require `src/edge-e3`.

Use `edge_e3enc_mixed.fl` for simulation, or combine the single RTL file with
target-specific SRAM replacements for FPGA/OpenROAD.

Generate from the repository root with:

```sh
cmake --build build/cmake-harness --target edge_e3_obfuscate
```

FPGA/Yosys can consume the mixed list and select its `_yosys.v` SRAM variants:

```sh
synth/run_yosys.sh edge_core_top xilinx src/edge-e3enc/edge_e3enc_mixed.fl
```

OpenROAD can consume the same list; its runner substitutes central `*_openroad.v` blackboxes for matching SRAM/cache-array entries.
