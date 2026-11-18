# Edge32 hello world through JTAG

Debug a real RV32 program with the VS Code C/C++ debugger, RISC-V GDB,
OpenOCD and the Edge32 JTAG adapter. Program bytes enter through JTAG system
bus access; the greeting returns through the hardware CSR `0x7e1` and DMI
console FIFO. The simulator has no program-image preload.

## Prepare the simulator

Install Verilator, LLVM clang/LLD with RISC-V support, Python 3, OpenOCD with
RISC-V and remote_bitbang support, RISC-V GDB, and the VS Code Microsoft C/C++
extension. `CLANG` overrides the compiler. The supplied launch configuration
uses `/opt/homebrew/bin/riscv64-elf-gdb`; edit `miDebuggerPath` on other systems.

This optional example currently requires access to the private `src/test-32`
submodule **and prepared `edge32_full_core_debug_rtl` views from the maintained
full-core-debug-mainline producer**. A public-only checkout is not sufficient.
The normal `tests/run.sh all` regression remains independent of these inputs.
The APR view generator and its input artifacts are owned by the composed
physical-design workspace; this example does not run APR to produce them.

Initialize the private test submodule, then import the prepared RTL:

```sh
git submodule update --init src/test-32
python3 examples/jtag-hello/debug.py import-views \
  /path/to/physical-workspace/build/apr-mainline-debug/edge32_full_core_debug_rtl
python3 examples/jtag-hello/debug.py build
```

`import-views` checks the producer output hashes and copies RTL and JSON receipts
into ignored `build/jtag-hello/views/`. It records source/hash provenance in
`build/jtag-hello/views-import.json`. Alternatively, set `EDGE32_DEBUG_VIEWS`
to the prepared directory. Keep the prepared views matched to the Edge32 and
test-32 revisions; they are an explicit dependency, not generated from the
public RTL checkout alone. Import refreshed views after changing the producer.

`build` compiles a **new local** Verilator JTAG simulator from those views,
this checkout's Edge32 RTL and test-32 simulation support, then builds the ELF.
No n906 simulator executable, gate netlist or routed database is reused.
The simulation uses the current native req/resp debug interface, synchronous
core reset bridge, I/D caches and a shared 64 KiB behavioral RAM. FPU operations
and FPU debug state are outside this example's coverage.

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
- Manual cleanup: `python3 examples/jtag-hello/debug.py stop`.

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
./examples/jtag-hello/run.sh
```

This rebuilds the simulator/ELF and exercises the installed cppdbg adapter over
DAP: launch, stop at main, C source breakpoint, stack trace, Watch, disassembly,
source step, completion with `characters_written == 25`, and the JTAG greeting.
It then verifies cleanup, repeated stop, released ports, and a fresh start/stop.
`CPPDBG_ADAPTER` selects `OpenDebugAD7`; `GDB` overrides the test's debugger.
Reports: `build/jtag-hello/test.report`, `dap-check.log`, and `session.log`.

Verified on 2026-11-18 against Edge32 `160d678`, test-32 `8065fbe`, Verilator
5.050, OpenOCD and the installed cppdbg/GDB tools. This tests the actual debug
adapter protocol; the VS Code GUI and its task orchestration were not driven
automatically. No APR or physical-board timing claim follows from this test.
