---
name: edge-verilator-demo
description: Build and diagnose the public E3/Edge-32 SoC Verilator simulator, including source resolution, build outputs, runtime arguments and example pass/fail evidence.
---

# Public Edge Verilator demo

Use [scripts/build-verilator.sh](../../../scripts/build-verilator.sh) as the
maintained simulator build entry. Initialize pinned `src/edge-e3`,
`src/edge-32` and `src/edge-asic` sources. Private test repositories such as
`src/test-e3` are optional and must not be required by the public build.
Record revisions and local changes before diagnosing a reported failure.

## Source and tool prerequisites

[prepare_e3_filelist.py](../../../tools/prepare_e3_filelist.py) resolves the
upstream E3 production filelist, including `-f`/`-F` nesting and cycle checks.
It restricts sources to public RTL roots and replaces the internal test-model
reference with `src/soc/logical/mem/edge_sram_sim.v`. The build adds the
workspace SoC wrapper, AXI interconnect/error/RAM modules and
[testbench](../../../src/soc/logical/tb/edge_soc_demo_tb.v) under `src/soc`.

For a cheap source-resolution check without compiling a simulator:

```sh
python3 -m unittest discover -s tests/interface -p 'test_*.py'
```

These tests cover the pinned filelist and resolver behavior, not Verilog
elaboration or runtime correctness. Use [edge-bringup](../edge-bringup/SKILL.md)
for missing host tools. Simulator compilation needs Python 3, Verilator and
its host C++ build toolchain. Bare-metal examples additionally need the LLVM
RISC-V tools used by `scripts/build-cpp-example.sh`; that script targets
`riscv32-unknown-elf`, `rv32imf_zba`, `ilp32`. Compiler/runtime workflows also
need NNC and the prepared Python environment.

## Build and output ownership

Run from the repository root:

```sh
./scripts/build-verilator.sh
```

The default executable is `build/verilator/obj/Vedge_soc_demo_tb` and the
resolved filelist is `build/verilator/edge_e3_public.fl`. `VERILATOR` selects
the executable instead of the default `verilator` on PATH. It is an
executable name/path, not a string of extra flags.

`EDGE_VERILATOR_OUT` selects the build directory. Prefer an absolute path and
keep the same value for the builder and consumer:

```sh
export EDGE_VERILATOR_OUT="$PWD/build/verilator-debug"
./scripts/build-verilator.sh
```

The script removes that directory's `obj` tree on every build. Do not rebuild
while another task uses the same output directory, and do not place unrelated
files there. Generated outputs belong under ignored build directories.

The script uses `--binary --timing`, top `edge_soc_demo_tb`, `-Wno-fatal` and
`--converge-limit 100000`. It defines `VERILATOR_SIM`, `IVERILOG_SIM`,
`EDGE_DEBUG`, `EDGE_SCALAR_PIPE_EBREAK_REPORT_ONLY`,
`EDGE_SCALAR_LSU_QUEUE_DEPTH=4` and `EDGE_SCALAR_LOAD_QUEUE_DEPTH=2`.
Record the effective command and selected configuration when comparing runs;
these flags do not prove that every leaf implements a configurable depth.

## Validate with maintained runners

```sh
./example/hello/run.sh
./example/tensor/run.sh
./example/actu/run.sh
```

Each of these runners rebuilds the simulator and its bare-metal program;
they do not implement a generic `--skip-verilator-build` option. Run them
sequentially when sharing `EDGE_VERILATOR_OUT`. Their default output directories
are `example/<name>/build`, with `build.log`, `run.log` and `run_case.report`.
`EDGE_HELLO_OUT`, `EDGE_TENSOR_OUT` and `EDGE_ACTU_OUT` override the respective
example directory; use absolute paths.

Hello requires its greeting and `TEST PASS`; ACTU requires its throughput
completion text and `TEST PASS`; tensor enables the testbench output checker
and requires the report to pass. A shell exit or old report alone is not
sufficient. For direct diagnostic runs remove prior report/log artifacts or
use a fresh output directory before interpreting results.

For runtime/intrinsic compatibility use `./tests/run.sh interface`. Its runner
supports `--skip-verilator-build` after a build of the reviewed sources.
For NNC compiler/runtime, layout or composed-model changes use the relevant
unit/model tests and `./tests/run.sh nnc`; use `./tests/run.sh all` for broad
cross-layer regression. Follow [regression routing](../../../tests/README.md)
and [software-harness](../software-harness/SKILL.md) for numerical comparison
and report requirements. The basic examples do not cover all NNC behavior.

## Runtime arguments and completion

Prefer the maintained runner for a workload. For manual diagnosis, match its
memory image, word count and checks:

| Argument | Current behavior |
| --- | --- |
| `+mem128=<path>` / `+mem128_words=<count>` | AXI RAM preloads a 128-bit-word memory image; use the matching generated `.memh` and `.words` |
| `+max_cycles=<count>` | Testbench timeout, default 500000 cycles |
| `+run_case_report=<path>` | PASS/FAIL report, default `run_case.report` relative to simulation cwd |
| `+check_tensor_output` | Enables the built-in tensor fixture checker; not a generic model comparator |
| `+dump_base=<decimal>` / `+dump_len=<decimal>` / `+dump_file=<path>` | Optional output dump controls; consumers must interpret the recorded layout |
| `+profile_mac` / `+trace_cmd` | Opt-in public MAC counters and command trace |

The current testbench succeeds on CSR break code zero after any enabled
output check. Nonzero code, illegal-instruction indication or timeout reports
failure. Some runners still pass `+expected_return=0` or `+pass_on_csr_break`;
the current testbench does not parse these flags, so they do not change its
completion policy. NNC BF16 comparison happens in the software harness and
requires its own `COMPARE PASS`, beyond simulator success.

## Diagnose by failing phase

- **Missing input/filelist:** verify public pins and the first missing path;
  do not substitute private sources to bypass the resolver.
- **Verilator or host compilation:** read the build output and exact tool
  version. `-Wno-fatal` permits warnings; it does not establish correctness.
- **Bare-metal compilation/link:** inspect the example build log and LLVM
  selection; this is distinct from simulator compilation.
- **Timeout/illegal/nonzero return:** read the current simulation log/report,
  confirm image and simulator revisions, then narrow to the affected command
  or memory boundary. Increasing timeout alone is not a correctness fix.
- **Output mismatch:** inspect dump/layout and numerical evidence; preserve
  documented goldens and tolerances.

Report exact commands, versions/revisions, PASS / FAIL / NOT RUN and evidence
paths. Distinguish resolver-only checks, a successful build and an executed
passing workload; do not infer a fresh simulation result from historical logs.
