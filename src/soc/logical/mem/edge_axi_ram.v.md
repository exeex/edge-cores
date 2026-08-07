# edge_axi_ram.v

## Purpose

`edge_axi_ram` is the clean-room Edge SoC DRAM/SRAM placeholder. It is the first
replacement for the C906 simulation memory role inside `soc`.

## Behavior

- Accepts one read transaction at a time and returns an incrementing burst of
  `arlen+1` 128-bit beats with `OKAY`; `rlast` is asserted only on the final
  beat.
- Accepts one write address followed by one write data beat and returns `OKAY`.
- Writes update a byte-writeable memory. The simulation default is sized by
  `RAM_ADDR_BITS`; the Edge SoC testbench uses 23 address bits, or 128 MiB at
  128 bits per word, so larger CNN/LLM-like software images and output buffers
  can fit without changing the memory model.
- The memory is preloaded with a deterministic index-derived pattern so bring-up
  tests do not depend on external initialization files.
- In simulation, accepts `+mem128=<path>` and optional
  `+mem128_words=<count>` plusargs to preload the same 128-bit word image used
  by the maintained software-test conversion flow.
- In simulation, `+axi_read_latency=<cycles>` delays the first AXI read beat
  after address acceptance. It defaults to zero and does not affect the direct
  instruction-memory port. This provides a deterministic D-cache miss-latency
  knob for cache-pressure experiments.
- Provides a first-slice direct instruction-memory read port for
  `edge_core_top.imem_*`. This is a simulation/bring-up path into the unified
  SoC RAM image until the I-cache miss/refill contract is implemented.
- Under `EDGE_YOSYS_SYNTH`, the module is a black-box memory placeholder. This
  keeps `edge_soc_top` synthesis focused on the core plus SoC AXI glue instead
  of charging the behavioral simulation DRAM to Edge core logic.

## Non-Goals

This is not the final memory controller. It is intentionally small and exists to
make the Edge SoC boundary real for simulation and synthesis estimates.
