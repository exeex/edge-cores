# Measured Tensor matmul trace

This reuses `matmul64x64_128tokens_tiled_circular.cpp` without changing its
algorithm, inputs or control sequence. It uses INT8 identity weights with
BF16 activations and output. The public SoC testbench checks all
8,192 final BF16 output elements against its independent expected pattern.

```sh
./example/tensor/trace.sh
```

The maintained public Verilator build runs first. The runner compiles the
existing example, records the optional observer CSV and requires simulator
`TEST PASS`, `RETURN_VALUE=0` and `TENSOR_OUTPUT_CHECK=PASS`. It then validates
all 64 job launches, 64 WLD completions, 64 weight activations, 63 physical
active-bank switches and 8,192 vector/result handshakes. It rejects compute
without active weights or transport into the currently active bank.

After explicitly building the current observer and public RTL, reuse them:

```sh
./example/tensor/trace.sh --skip-verilator-build --publish-trace
```

`--publish-trace` copies the validated compact fixture into
`docs/architecture-renderer/tensor-trace-data.js`. The atlas workload selector
switches between this run and the separate ACTU demonstration. Event buttons
show feeding, first compute, actual overlap, A/B switching, output writes and
joins. The tensor_start selector opens any of the 64 software command-acceptance
boundaries and states its corresponding internal launch cycle.
The architecture diagram remains the first section of the page.

Use `EDGE_TENSOR_TRACE_OUT` for the example's generated outputs and
`EDGE_VERILATOR_OUT` for an independent simulator directory. Defaults are
`example/tensor/build/trace` and `build/architecture-trace`. Do not rebuild
one simulator directory concurrently. Raw CSV, ELF, memh, objdump, console
and report files remain under ignored build directories.

## What the signals mean

All values are sampled before the rising edge, with the public testbench
cycle counter. Pulse lanes mean a transfer accepted at that edge.

| Signal | Owner / interpretation |
| --- | --- |
| DMA busy | Public platform `dma_busy`; busy alone does not mean a transfer |
| DMA SRAM write accepted | DTCM `dma_dtcm_req && dma_ready && dma_dtcm_we` |
| WLD active / read / complete | Tensor owner `wld_active_q`, `wld_read_fire`, `wld_fill_done` |
| Fill A / B | Dot-local ingress transport busy, qualified by its fill-bank selector |
| Weight activation accepted | `edge_tensor_weight_banks.activate_accept` |
| Bank A / B active | `active_valid_q`, qualified by physical `active_bank_q` 0 / 1 |
| Compute job launch | Tensor owner `engine_start`, distinct from command acceptance |
| Compute occupied / Compute input valid | Engine `compute_busy_q` / `compute_valid_q` |
| Result enters O queue | Engine `tensor_output_valid` |
| O write accepted | Engine `output_write_fire`, not immediate visibility of the physical write |
| Physical write tail | Reduction of the engine `write_pipe` lifetime bits |
| EX Tensor sync waiting | Valid EX Tensor sync and `!ex_release_ready` |

A=physical bank 0 and B=physical bank 1. **The first tile uses B in this run.**
An activation handshake takes effect at the edge; the changed active-bank
state appears in the next sample. Do not interpret an invalid initial bank
bit as an active tile. Software tensor_start acceptance and internal engine launch are separate
events. The selector shows the command-acceptance cycle, with the later
internal launch stated explicitly. The full CSV also retains queued-start, pending-weight,
handoff and engine-done state for inspection outside the compact viewer.

The compact window begins at the initial DMA start command and ends 12 cycles
after the first DMA join following Tensor sync. The raw CSV continues through
printf and final output-copy DMA. Numerical PASS is recorded only after the
complete program and testbench output comparison have finished.

## What this example actually overlaps

Its 64-entry circular ring can hold all 64 weight tiles. DMA consequently
finishes early, while WLD continues consuming tiles and local A/B banks
alternate through the rest of the compute stream. The trace demonstrates
initial DMA/compute overlap and continuing WLD/A-B/compute/O-write overlap;
it does not demonstrate sustained DMA throughout the full kernel. This is
the standalone example, separate from the NNC runtime's eight-slot BF16 ring
and FIRST/PSUM/LAST mode scheme.

## Actual overlap definitions

The captured run contains:

- 191 cycles with **DMA SRAM write accepted AND Compute input valid**.
- 219 cycles with **WLD read accepted AND Compute input valid**.
- 7,926 cycles with **O write accepted AND Compute input valid**.
- 1,578 cycles of **WLD active AND compute-job occupied**; this is a broader
  occupancy overlap, not the same measure as simultaneous handshakes.
- 209 cycles of pending EX Tensor sync.

These counts refer to this exact example, public RTL and toolchain. They are
not three simultaneous transfers in every cycle, a generic initiation
interval, a measured utilization percentage or a throughput guarantee.

## Evidence and reproduction

The fixture records public submodule revisions, exact source hashes, tool
versions, raw-CSV/ELF hashes and the simulator report. Run:

```sh
node docs/architecture-renderer/verify.mjs
```

This checks fixture intervals, source freshness, overlap intersections, job
boundaries and links. `tools/render_tensor_trace.py` performs the raw-capture
checks before producing the fixture. The synthesizable RTL is unchanged;
only optional testbench observation is added.

## Default four-lane view

The default Tensor view retains **DMA busy**, **WLD tile loading**,
**Tensor active (busy)** and **tensor_sync wait (EX)**. Tensor active is the
observed RTL `tensor_busy`: engine work, queued/pending starts, WLD and scale
loading can all keep it high. It is outstanding Tensor work, not per-cycle
compute utilization. The software start acceptance pulse is in the internal
detail view. Sync remains high while the actual
instruction waits in EX; its completion is a separate named event.

**Show internal signals** reveals tensor_start acceptance, A/B ownership, read/complete pulses,
internal compute-job launch, **Compute input valid**, result/output handshakes
and physical write tail. Compute input valid is the engine's per-vector
`compute_valid_q`; it is not a software instruction. One software start
processes 128 input vectors in this example. The internal view retains the
same real cycles and can be compared directly with the software lanes.

### Why WLD appears short

Each load brings one 8×8 INT8 weight tile: **64 bytes**, supplied by **four
accepted 128-bit SRAM reads**. The measured full `wld_active_q` interval is
**24–29 cycles**, including the memory/staging/fill lifetime; the individual
read and complete handshakes are one-cycle pulses. This is not a four-cycle
end-to-end load claim.

The loaded weights remain in the local active bank and are reused for
**128 vectors per tensor_start**. WLD therefore need not remain active for
the compute stream's whole duration. At the full capture's **8,586-cycle**
scale, a 24–29-cycle interval looks thin. Select **WLD tile loading** and a
128-cycle window to inspect its actual width; enable internal signals to
see the four reads and the completion pulse separately.
