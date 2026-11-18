# Edge32 hello world through JTAG

Debug a real RV32 program with the VS Code C/C++ debugger, RISC-V GDB,
OpenOCD and the Edge32 JTAG adapter. Program bytes enter through JTAG system
bus access; the greeting returns through the hardware CSR `0x7e1` and DMI
console FIFO. The simulator has no program-image preload.

## Prepare the simulator

This example now lives under `example/`, matching the other public examples.
When updating from an earlier checkout using `examples/`, remove the generated `build/jtag-hello/sim/` directory
before rebuilding and refresh your copied `.vscode/tasks.json`.

Install Verilator, LLVM clang/LLD with RISC-V support, Python 3, OpenOCD with
RISC-V and remote_bitbang support, RISC-V GDB, and the VS Code Microsoft C/C++
extension. `CLANG` overrides the compiler. The supplied launch configuration
uses `/opt/homebrew/bin/riscv64-elf-gdb`; edit `miDebuggerPath` on other systems.

Only the public Edge32 submodule is needed:

```sh
git submodule update --init src/edge-32
python3 example/jtag-hello/debug.py build
```

`build` compiles a fresh local Verilator simulator from `src/edge-32`, enables
its optional `EDGE32_DEBUG` native interface, and builds the debug ELF.
The simulation support is versioned in this example: a shared 64 KiB behavioral
RAM, a remote_bitbang socket server, OpenOCD configuration and a console client.
There is no private test repository, prepared RTL view, APR database or existing
simulator dependency. The target advertises RV32IM; FPU operations and FPU debug
state are excluded. Source hashes are recorded in `build/jtag-hello/sim/inputs.json`.

## VS Code GUI

Open the repository root in VS Code. Copy/merge this directory's `launch.json`
and `tasks.json` into the root `.vscode/` directory (which Git ignores). Select
**Edge32: Hello world (JTAG)** in Run and Debug and press F5. The tasks rebuild
the simulator and ELF, start OpenOCD and the console, and stop at `main()`.

- Set a C breakpoint on the `edge_putchar(...)` call in `main`.
- F10 steps a source line; F11 steps into `edge_putchar`.
- Watch `characters_written`, `message`, or `i` while in scope.
- Continue to print `Hello world from Edge32!` in the JTAG server task terminal.
  Completion stops at `hello_done`'s EBREAK; the final count is **25**.
- Shift+F5 disconnects GDB and runs the cleanup task. The next F5 starts fresh.
- Manual cleanup: `python3 example/jtag-hello/debug.py stop`.

The supervisor owns its simulator, OpenOCD and console processes, waits for them
on shutdown, and does not kill unrelated processes. It refuses occupied loopback
ports 9824 (remote_bitbang), 3333 (GDB) and 6666 (Tcl). Service logs and all build
products stay under `build/jtag-hello/`.

**cppdbg compatibility:** the tested cpptools 1.35.6 MIEngine rejects automatic
RISC-V detection. `targetArchitecture: "x86"` is its 32-bit adapter fallback;
GDB is explicitly set to `riscv:rv32` and performs target decoding/execution.
Do not force hardware breakpoints: standard GDB `hbreak` integration is pending.
Custom launch commands explicitly load the ELF symbols and program bytes.

## Repeatable validation

```sh
./example/jtag-hello/run.sh
```

This rebuilds the simulator/ELF, checks pin-level JTAG/DMI, GPR access,
cache coherence and target/TAP resets, then exercises the installed cppdbg adapter over
DAP: launch, stop at main, C source breakpoint, stack trace, Watch, disassembly,
source step, completion with `characters_written == 25`, and the JTAG greeting.
It then verifies cleanup, repeated stop, released ports, and a fresh start/stop.
`CPPDBG_ADAPTER` selects `OpenDebugAD7`; `GDB` overrides the test's debugger.
Reports: `build/jtag-hello/test.report`, `dap-check.log`, and `session.log`.

Verified on 2026-11-18 with Verilator 5.050, OpenOCD 0.12.0, GDB 18.1 and
cppdbg 1.35.6 on macOS ARM64. The actual VS Code GUI was also exercised: launch
to main, C breakpoint, Step Over/Into, Watch, complete greeting, Stop with
post-debug cleanup, and a fresh launch/stop. See the
[release validation record](../../docs/releases/v0.4-validation.md) for revisions
and clean-checkout results. No APR or physical-board timing claim follows.
