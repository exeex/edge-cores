# Minimal ACTU fork/join example

This self-checking bare-metal program demonstrates captured GPR parameters,
independent ASIC execution, scalar progress and an EX-owned join. It uses the
public Edge32/E3/ASIC RTL with the existing SoC Verilator testbench.

## Run

From the repository root, with public submodules initialized, Verilator and
RISC-V-capable LLVM installed:

```sh
./example/fork_join/run.sh
```

The runner builds the public simulator in `build/architecture-trace`, compiles
`fork_join.cpp` with the standard bare-metal toolchain, runs the program and
validates the observed trace. It requires simulator **TEST PASS**, correct
captured `setn(4096)`, at least 32 scalar integer commits while ACTU is busy,
and a nonzero EX sync wait. The program itself checks its scalar result and
all 4,096 BF16 outputs; nonzero return values fail the simulator run.

After explicitly building the simulator from the current source, reuse it:

```sh
./example/fork_join/run.sh --skip-verilator-build
```

Set `EDGE_VERILATOR_OUT` and `EDGE_FORK_JOIN_OUT` to choose independent build
locations. Do not rebuild a simulator directory used by another process.

## Program

1. Initialize 4,096 BF16 inputs to zero and outputs to a sentinel in DTCM.
2. Publish the stores with the existing fence convention, then configure
   ACTU for BF16 sigmoid, input/output pointers and element count.
3. Issue `edge_actu_start()`. Command response and whole-job completion are
   distinct events.
4. Execute 32 scalar increments. Inline assembly prevents constant folding;
   the observer validates integer retirement while ACTU is busy.
5. Issue `edge_actu_sync()`. The instruction retains EX until ACTU drains.
   The existing intrinsic also supplies the post-join fence.
6. Check the scalar result is 32 and every output is BF16 `0x3f00` (0.5).

This is a correctness/architecture demonstration, not a performance benchmark.
Initialization and validation deliberately dominate total program runtime.
It does not exercise every ACTU mode, parameter reuse, DMA or Tensor behavior.

## Trace and artifacts

Generated files remain under the ignored `build/` directory:

- `fork_join.elf`, `.memh`, `.words`, `.objdump`: the executable and image.
- `run_case.report`, `run.log`: actual simulator completion and return value.
- `trace.csv`: consecutive pre-rising-edge signal snapshots.
- `trace-data.js`: a compact validated fixture for the documentation viewer.

The optional observer is `src/soc/logical/tb/edge_soc_arch_trace.svh`, included
by the public SoC testbench. It reads hierarchical signals and never drives
core or engine state. It is inactive unless `+arch_trace=<file>` is supplied.
`+arch_trace_command=32` starts recording when the first ACTU setcsr command
is accepted; 32 is the SDK command index encoded in instruction bits [31:25],
not the instruction's low opcode bits or the accel-pipe's full opcode8.
`+arch_trace_limit=200000` bounds output and fails instead of truncating.

Definitions:

| Channel | Meaning at the sampled edge |
| --- | --- |
| IF parcel valid | The IFU has an instruction parcel; this is not fetch-request occupancy |
| ID / EX / WB occupied | The respective RTL valid / pending slot state |
| WB commit | The actual `wb_commit` signal, including non-GPR retirements |
| ACTU busy | Platform `actu_busy` |
| Scalar commit while busy | Derived: WB commit of an integer ALU/branch instruction while ACTU busy; the instruction tag is shadowed from the preceding EX transfer |
| EX sync waiting | EX valid, ACTU sync instruction, and `!ex_release_ready` |
| EX transfer | Actual `ex_done` transfer into WB |
| ASIC command accepted | Dispatch `cmd_valid && cmd_ready` |

The CSV also carries instruction/PC values, ready/completion, captured GPR
parameters and response state. A PC/instruction is meaningful only when its
owning slot is valid. The viewer distills the first configuration through
12 cycles after sync completion; the raw capture continues through output
validation. High intervals are represented as `[start, end)` runs.

## Refresh the documentation fixture

```sh
./example/fork_join/run.sh --publish-trace
node docs/architecture-renderer/verify.mjs
```

This explicitly copies the validated compact fixture to
`docs/architecture-renderer/trace-data.js`. Raw logs, images and ELFs remain
ignored. The fixture records the base repository revision, public submodule
revisions, tool versions and SHA-256 hashes of the observer, program, build
scripts, parser, raw CSV and ELF. The workspace additions are identified by
hashes; the base revision alone does not include them.

Open `docs/architecture-renderer/index.html` and select **Observed RTL** events
in the measured trace section. The page works without fetching external data.
The existing Tensor source walkthrough and illustrative timeline remain
separate from this ACTU measurement.
