# edge_soc_top.v

## Purpose

`edge_soc_top` is the first Edge SoC shell. It gives the Edge path a stable
SoC-level entry point outside `edge_core_top`.

The shell follows the C906 SoC split at a clean-room implementation level:
`edge_core_top` is the production core boundary, while `edge_soc_top` owns the
SoC-side fabric and memory placeholders outside the core bus boundary.

## Current Shape

```text
bringup_core_* \
bringup_dma_*  \
edge_dma_*      edge_soc_top -> edge_core_debug -> edge_core_base
edge_dtcm_*    /                                      -> edge_axi_interconnect
                                                       -> edge_axi_ram
                                                   -> edge_axi_err
```

The `bringup_*`, `edge_dma_*`, and `edge_dtcm_*` ports are forwarded through
`edge_core_debug`, not the lean `edge_core_top`. They remain on the shell only
to preserve the early integration and Verilator test surface while production
elaboration keeps heavyweight trace/debug outputs behind `EDGE_DEBUG`.

## External Naming

The observable bus ports intentionally use the inherited C906 direction names:

- `biu_pad_*`: core BIU requests visible at the SoC boundary.
- `pad_biu_*`: legacy external response pins kept for early compatibility.
- `core_ebreak_*`: registered scalar `EBREAK` completion event from the core,
  exposed at the SoC boundary for software-runner completion and future
  host-CPU status/interrupt wiring.
- `core_csr_break_*`: registered Edge CSR break completion event from
  `csrw 0x7e0, rs1`, carrying `rs1` as the software return value.
- `core_csr_putchar_*`: non-terminating simulation-console character event
  from `csrw 0x7e1, rs1`. The shared testbench writes these bytes to the file
  selected by `+sim_console_file=...`, separate from hardware debug output.
- `debug_biu_*`: BIU owner probes available only when `EDGE_DEBUG` is defined.
  Production SoC/PnR filelists should not define `EDGE_DEBUG`, so these probes
  do not become top-level pins.

The current clean-room shell returns responses from internal SoC fabric, not
from the external `pad_biu_*` pins. Keeping those pins lets early benches and
waveform probes remain stable while the real SoC-side fabric grows.

## First-Slice Simplifications

- `edge_core_debug` is instantiated by the shell to preserve the legacy
  debug/bring-up harness surface; production builds use the same wrapper
  without `EDGE_DEBUG`, while hardware tests define `EDGE_DEBUG` for retire and
  BIU-owner observation.
- `edge_axi_interconnect` decodes the core BIU master to RAM or error slave.
- `edge_axi_ram` is the current DRAM/SRAM placeholder.
- `edge_axi_err` is the current default unmapped slave.
- Instruction fetch reaches `edge_axi_ram` through the maintained I-cache
  demand-refill path and the core BIU read channel. I-cache refill, D-cache
  refill, and bring-up core reads therefore compete at the core BIU boundary.
- `ENABLE_IMEM` is a test-only parameter. The default enables instruction
  fetch and I-cache BIU refill; focused BIU/DMA tests may set it to `0` when
  they are not loading a valid instruction image and need the bring-up BIU port
  isolated from frontend traffic.
- `ENABLE_EARLY_LOAD_RETIRE` is a default-off experiment parameter forwarded
  through `edge_core_debug`. The Verilator software harness selects it with
  the CMake cache option `STAREDGE_ENABLE_EARLY_LOAD_RETIRE`; baseline and
  experiment runs should use separate build directories so simulator binaries
  and reports cannot be mixed.
- Interrupt, CLINT, PLIC, debug module, APB, and system counter wiring are not
  connected yet.
- Retire PC is still a placeholder until core retire entries carry PC.

## Focused Test

`src/soc/logical/tb/edge_soc_top_biu_smoke_tb.v` proves the shell routes core-owned BIU and
DTCM DMA traffic through the internal SoC AXI fabric, returns RAM data, returns
SLVERR from the error slave, and exposes core-derived halted state.

`src/soc/logical/tb/edge_soc_top_imem_smoke_tb.v` proves the SoC RAM `+mem128` image feeds
the I-cache BIU refill path and reaches the frontend/tokenizer as a scalar boot
instruction block.

`src/soc/logical/tb/edge_soc_vvp_tb.v` is the first maintained Edge SoC software-runner
testbench. It instantiates `edge_soc_top`, relies on `edge_axi_ram` for
`+mem128` preload, and writes `run_case.report` when the configured
`+pass_retire_count=<count>` threshold is reached, when `+pass_on_ebreak`
observes `core_ebreak_valid` with the expected `x31` value, or when
`+pass_on_csr_break` observes `core_csr_break_valid` with the expected return
value. This is a bring-up contract: legacy C906 tohost, custom cache ops,
interrupts, and full software exit semantics are intentionally deferred.

`edge_soc_software_c_mem_word_smoke` is the first enabled small C benchmark for
the SoC demand-refill path. It disables data-side mem128 preload, finishes via
the SoC-level completion event, and checks the host-baseline checksum from
`tools/edge_rom/edge_c_mem_word_smoke.c`.

`tests/software/cases/EDGE_RV64I/EDGE_RV64I_SMOKE.s` is the first
toolchain-built software image for this runner. The current smoke proves a
small dependent RV64I scalar sequence with a scalar load can be assembled,
linked at boot address zero, converted through `elf2mem128.py`, fetched through
`edge_soc_top`, retired, and reported through the maintained Edge runner. The
runner owns a monotonic retired-instruction counter derived from `retire0_valid`
and `retire1_valid`; `edge_retire_sync.debug_count` is queue occupancy, not a
software pass counter.

`tests/software/cases/EDGE_DTCM/EDGE_DTCM_SMOKE.s` is the first Edge runner
software image that targets the configured DTCM window. The CTest entry enables
`+expect_dtcm_scalar_lsu`, so the runner requires a DTCM scalar store, a DTCM
scalar load, and a DTCM scalar load response in addition to the retire-count
pass condition.

`tests/software/cases/EDGE_DMA/EDGE_DMA_SMOKE.s` is the first Edge runner
software image that executes `dma.start` and `dma.sync` through the scalar
pipeline. The test copies one 16-byte beat from SoC RAM address zero into the
DTCM window, waits for `dma.sync`, then performs a scalar DTCM load. The runner
requires both observed scalar DMA start activity and DTCM scalar LSU activity.

`tests/software/cases/EDGE_CACHE/EDGE_CACHE_SMOKE.s` is the first Edge runner
software image that executes the provisional cache-maintenance encodings. The
runner requires observed scalar cache clean and invalidate activity. This is an
observation proof only; it does not claim the current D-cache model implements
real cache-line clean or invalidate state transitions.

`tests/software/cases/EDGE_DCACHE_VICTIM/EDGE_DCACHE_VICTIM.cpp` proves the
dirty-victim D-cache path at SoC software level. It writes one DRAM line,
cleans it to SoC RAM, dirties a same-index different-tag line, then reads the
first line to force dirty victim writeback plus refill. A final read of the
evicted line proves the victim data reached SoC RAM through the Edge core BIU
path.

`tests/software/cases/EDGE_LSU_MIXED/EDGE_LSU_MIXED.cpp` proves the scalar LSU
DTCM-window selector can alternate between D-cache/DRAM and DTCM traffic in one
software image. The runner requires both scalar DTCM LSU activity and an
observed scalar D-cache clean.

`tests/software/cases/EDGE_DMA_CPP/EDGE_DMA_CPP_SMOKE.cpp` is the first Edge
runner C++ image using `tests/software/include/edge_intrinsic.hpp`. It proves the
same wrapper path used by broader DMA tests can compile into the Edge runner and
emit cache clean/invalidate, `dma.start`, `dma.sync`, and a post-DMA scalar DTCM
load.

`tests/software/cases/EDGE_DMA_SIMPLE/EDGE_DMA_SIMPLE.cpp` mirrors the important
DRAM-to-DTCM behavior from `tests/software/dma/simple.cpp`: CPU stores fill a
cached source line, `edge_dcache_clean_range` writes that line back through the
Edge D-cache clean BIU path, a 64-byte DMA copy reads SoC RAM and writes DTCM,
and scalar byte loads verify the copied pattern plus the untouched sentinel
byte after the transfer. The scalar pipe serializes `dma.start` behind any
pending cache-maintenance command, so the DMA read cannot issue until the clean
writeback has reached its final BIU write response.

`tests/software/cases/EDGE_DMA_DTCM_TO_DRAM/EDGE_DMA_DTCM_TO_DRAM.cpp` mirrors
the important DTCM-to-DRAM behavior from `tests/software/dma/dtcm_to_dram.cpp`:
scalar byte stores fill DTCM, the destination is cleaned before DMA and pulled
into D-cache, DMA writes 80 bytes to SoC RAM, `edge_dcache_invalidate_range`
invalidates the stale destination line, and scalar byte loads miss/refill
through the D-cache BIU read path before verifying the copied pattern plus the
untouched sentinel byte after the transfer.

`tests/software/cases/EDGE_DMA_BURST/EDGE_DMA_BURST.cpp` mirrors the bidirectional
256-byte burst behavior from `tests/software/dma/burst.cpp`. It verifies
DRAM-to-DTCM and DTCM-to-DRAM pattern copies in one image and requires observed
DMA read bursts with `arlen >= 3`.

`tests/software/cases/EDGE_DMA_TAIL/EDGE_DMA_TAIL.cpp` covers DMA transfers
whose lengths are not multiples of the 16-byte DTCM DMA beat. It copies 30
bytes from DRAM to DTCM and 45 bytes from DTCM to DRAM, then verifies both the
copied bytes and the first untouched sentinel byte after each range.

The SoC VVP runner no longer mirrors clean or invalidate data between D-cache
and SoC RAM. Dirty VA clean must reach RAM through the real D-cache clean
writeback stream and BIU core write path before DMA can read the updated DRAM
source. Post-DMA CPU reads after invalidate must reach RAM through the D-cache
miss/refill BIU read path.
