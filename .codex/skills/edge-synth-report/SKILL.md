---
name: edge-synth-report
description: Select, preflight and diagnose repository-local Yosys profiles for E3/Edge-32 and separately supplied historical Edge RV sources, then summarize FPGA resource estimates with their configuration and coverage limits.
---

# Edge Synth Report

Use [synth/run_profile.sh](../../../synth/run_profile.sh) for maintained
profiles and inspect [run_yosys.sh](../../../synth/run_yosys.sh) when diagnosing
behavior. All normal E3 inputs come from public checkout sources; do not
borrow private files to make an estimate pass.

## Select a supported profile

| Profile | Top and source boundary |
| --- | --- |
| `edge32@e3` | `edge_core_edge32_top`; public E3, Edge-32 and shared ASIC product |
| `edge-32` | `edge_32_cached_core`; standalone cached scalar core |
| `edge-rv` | `edge_rv_top`; historical RV resource boundary |
| `edge-rv-lite` | `edge_rv_lite_cached_core`; historical cached lite boundary |

These are the four names implemented by the runner. `<scalar-core>@<asic-set>`
is a naming convention, not dynamic discovery: another ASIC set needs an
explicit profile/filelist implementation.

`edge32@e3` uses [prepare_e3_filelist.py](../../../tools/prepare_e3_filelist.py)
to flatten the public E3 manifests, resolve `-f`/`-F`, reject cycles and
substitute the workspace `src/soc/logical/mem/edge_sram_sim.v` behavioral SRAM
model. It does not require private test repositories.

`edge-32` currently references `synth/rtl/edge32_fpga_ram.v`, which is absent
from the workspace checked for this update. Its preflight fails on that path.
Recheck the current checkout and report the failure; do not silently swap in
a different RAM model or claim the standalone estimate is available.

Historical `edge-rv` and `edge-rv-lite` source trees are no longer checkout
submodules. Supply their explicit revisions with `EDGE_RV_ROOT` and, for lite,
`EDGE_RV_LITE_ROOT` before attempting those profiles. `EDGE32_ROOT` expands
references inside filelists; the `edge-32` profile still selects its entry
filelist from `src/edge-32/filelists/edge_32.fl`. These overrides do not
retarget the E3 Python resolver's fixed public roots.

## Preflight before synthesis

Run from the repository root:

```sh
./synth/run_profile.sh --check edge32@e3 xilinx
```

Record the top, target, resolved filelist, source count and any warning or
missing path. `--check` expands filelists and checks RTL file existence; it
exits before invoking Yosys. It does not prove parsing/elaboration, top-module
existence, complete include resolution, target validity or successful mapping.
The E3 resolver may write an ignored generated filelist during this check.

The lower-level filelist reader handles `-f`, `+incdir+` and listed Verilog/
SystemVerilog files; unsupported entries are warned about and ignored.
It is not a general replacement for the E3 `-f`/`-F` resolver. Investigate
ignored entries before trusting a source count.

Run synthesis only when requested and preflight succeeds. The executable is
`yosys` from PATH. Supported targets are `generic`, `xilinx` (default) and
`ecp5`. For example:

```sh
STAREDGE_YOSYS_VARIANT=e3-xilinx ./synth/run_profile.sh edge32@e3 xilinx
```

## Preserve the effective configuration

The runner always defines `SYNTHESIS` and `EDGE_YOSYS_SYNTH` and reads sources
with `read_verilog -sv -defer`. Record these controls:

- `STAREDGE_YOSYS_DEFINES`: whitespace-separated additional define tokens
  without the `-D` prefix; the runner adds that prefix.
- `STAREDGE_YOSYS_XILINX_NODSP=1`: passes `-nodsp` for Xilinx only.
- `STAREDGE_YOSYS_VARIANT`: output directory label. The profile wrapper
  defaults it to the profile name with `@` replaced by `-`.
- Xilinx uses `synth_xilinx -family xc7 -noiopad -noclkbuf` and selects a
  sibling `_yosys.v` source when present. ECP5 uses `synth_ecp5`; generic uses
  the runner's generic mapping/ABC sequence. These are different mappings.

Outputs are `synth/build/<top>/<variant>/`, not universally `<top>/<profile>`.
The default E3 path is `synth/build/edge_core_edge32_top/edge32-e3/`.
Use distinct variants for targets, defines and DSP policies: the wrapper's
variant does not include the target, and another run can overwrite `run.ys`,
`yosys.log` and `stat.txt`. Do not run concurrent jobs into the same directory.

## Inspect and summarize results

Check the actual exit status, `yosys.log`, generated `run.ys` and fresh
`stat.txt`. A report left by an older run is not evidence of a failed run's
success. Verilog netlists are written for all targets; JSON netlists are
written for Xilinx/ECP5. Keep generated outputs under ignored `synth/build/`.

Report Yosys version, target, profile/top, effective variant/defines, DSP
policy, source/SRAM substitutions, workspace and component revisions, and
local modifications. For Xilinx, summarize total cells, LUT1–6 sum,
flip-flops, DSPs, carry/mux cells and BRAMs as present. For ECP5/generic use
the actual cell classes in their reports rather than applying a Xilinx LUT
sum. Distinguish top-local counts from design-hierarchy totals and inspect
remaining memories, unresolved modules or black boxes before comparing area.

Compare like boundaries with matched tool, mapping and memory assumptions.
A standalone cached core and a full E3 product are different scopes. These
are FPGA-oriented synthesis/resource estimates, not place-and-route timing,
ASIC PPA, power measurements or silicon performance. See
[paper evaluation](../integrate-your-design/references/paper-evaluation.md)
for claim boundaries.

When blocked, report the exact failing phase and path/diagnostic, what was
checked, and what remains NOT RUN. For this document update, E3 source
preflight passed while standalone Edge-32 preflight failed on the RAM model;
no fresh Yosys resource result follows from those checks.
