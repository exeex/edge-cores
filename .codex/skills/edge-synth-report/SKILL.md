---
name: edge-synth-report
description: Run and diagnose the repository-local Yosys synthesis profiles for public edge-e3 product RTL, edge-rv, and edge-rv-lite, then summarize FPGA resource reports.
---

# Edge Synth Report

Use this skill for local synthesis setup, profile selection, Yosys failures,
and resource comparisons. The maintained entry point is
`synth/run_profile.sh`; do not borrow files at runtime from `~/n906`.

## Profiles

- `edge32@e3`: full public E3 product, top `edge_core_edge32_top`. The
  profile resolves the public E3 filelist through `tools/prepare_e3_filelist.py`
  and supplies local public SRAM behavioral models. Private tests are optional.
- `edge-32`: standalone public cached-core boundary, top `edge_32_cached_core`.
- `edge-rv`: reusable public RV resource boundary, top `edge_rv_top`.
- `edge-rv-lite`: public cached lite boundary, top
  `edge_rv_lite_cached_core`.

Composed profiles use `<scalar-core>@<asic-set>`. Downstream packages may add
their own ASIC-set suffix, for example `edge-rv@some_asic_set`; names without
`@` refer to standalone scalar boundaries.

## Workflow

1. From the repository root, run a cheap source/filelist preflight:

   ```sh
   ./synth/run_profile.sh --check <profile> xilinx
   ```

2. Run synthesis only after preflight succeeds:

   ```sh
   ./synth/run_profile.sh <profile> xilinx
   ```

3. Read `synth/build/<top>/<profile>/stat.txt`. Record the Yosys version,
   target, profile, Git revisions, total cells, LUT1-6 sum, flip-flops, DSPs,
   carry cells, mux cells, and BRAMs.

4. Compare profiles only when target, Yosys version, defines, DSP policy, and
   SRAM substitution policy match. Describe results as FPGA-oriented estimates,
   not ASIC PPA or place-and-route results.

The lower-level `synth/run_yosys.sh` accepts a top, target, and filelist for
diagnostic or one-off boundaries. `STAREDGE_YOSYS_VARIANT`,
`STAREDGE_YOSYS_DEFINES`, and `STAREDGE_YOSYS_XILINX_NODSP` retain the behavior
of the reference n906 flow.
