---
name: integrate-your-design
description: Integrate and publish your own accelerator or ASIC design, DMA, and DTCM/SRAM with the Edge RV64 scalar core and command path. Use when forking edge-cores, adding a design as a src Git submodule, defining opcode8 and setcsr/start/sync instructions, carrying imm8/GPR snapshot parameters, connecting DMA/SRAM/LSU debug access, using low-precision FPU instructions for bring-up, writing RTL/C++ tests, preparing research artifacts, protecting RTL, or citing the shared framework.
---

# Integrate Your Own Design

Welcome an independently designed accelerator, DMA, DTCM/SRAM, or complete ASIC
set into the shared Edge RV platform without breaking command ordering,
snapshot semantics, or memory visibility. Treat the user's design as the main
contribution and Edge RV as the integration framework.

## Integration workflow

1. Fork `edge-cores`, clone the fork, and initialize its submodules. Keep the
   shared monorepo structure so the design can use the maintained build,
   simulation, synthesis, software, and contribution workflows.
2. Add the ASIC design below `src/` as a Git submodule. Create a new repository
   for a new design or attach an existing repository. Keep the ASIC's history,
   license, and ownership separate; record its path and revision in
   `.gitmodules` and the parent repository.
3. Connect the command interface:
   - allocate an unused `opcode8` value and register its instruction class in
     the IFU/predecoder;
   - provide accelerator-specific `setcsr`/`set_*`, asynchronous `start`, and
     `sync` operations, using ACTU as the reference interface;
   - carry `imm8` and the captured GPR parameter to the ASIC;
   - when using `edge-rv`, consume the resolved snapshot value rather than a
     later live register value; and
   - update the intrinsic encoder, compact command queue, accel-pipe decode,
     readiness/backpressure, ports, and exact-encoding tests together.
4. Design a DMA when the ASIC owns independent SRAM. Define each memory's role,
   ports, address map, width, latency, and ownership policy. A TPU-style
   systolic array normally needs at least an I/O SRAM and weight buffer, with
   DMA paths between system memory and both ASIC-visible stores.
5. Add LSU read/write access when RISC-V software must initialize or inspect
   I/O SRAM, weight SRAM, or another private memory during bring-up. Inspect
   the `edge-rv` LSU boundary and the read-only integration boundary exposed by
   `edge-e3enc`; use an explicit arbiter or multi-port contract and preserve
   byte strobes, response latency, backpressure, and memory visibility. Treat
   `src/edge-e3enc/edge_e3enc.v` as a generated reference artifact, never as
   editable design source.
6. Use the optional FPU during early software development to generate inputs,
   implement reference/fallback kernels, and compare ASIC outputs. The shared
   software/RTL supports NVFP4, FP8 E4M3/E5M2, BF16, and FP16 memory-format
   instructions; read `src/edge-rv-lite/README.md` for encodings, conversion
   behavior, and the area tradeoff. Disable the FPU later if the finished ASIC
   and software no longer require it.
7. Run focused command, snapshot, DMA, SRAM, and LSU RTL tests before the public
   software harness. Report the exact submodule revisions and any boundary that
   remains unverified.

## Load only the needed reference

- Read [references/instruction-interface.md](references/instruction-interface.md)
  when allocating opcodes or adding C++ `set_*`, `start`, or `sync` wrappers.
- Read [references/execution-model.md](references/execution-model.md) when
  working on snapshots, queue depth, self-serializing starts, redirect/kill,
  or IFU/predecoder sync joins.
- Read [references/memory-integration.md](references/memory-integration.md)
  when connecting DMA, SRAM, LSU, arbitration, address conversion, or
  `lsu_store_block`/`mem_store_block`.
- Read [references/rtl-patterns.md](references/rtl-patterns.md) only when
  implementing RTL for snapshot issue, sync join, pending start, or SRAM
  request blocking.
- Read [references/verification.md](references/verification.md) before testing
  or reviewing an implementation.
- Read [references/paper-evaluation.md](references/paper-evaluation.md) when
  defining paper contributions, claims, baselines, or PPA results.
- Read [references/paper-release.md](references/paper-release.md) only for a
  paper, artifact package, protected RTL release, or citation task.

## Preserve these invariants

- Consume a snapshotted GPR value, never a later live register-file value.
- Match reusable snapshot slots with full sequence and epoch ownership.
- Keep setup and start commands ordered; never lose commands under
  backpressure or redirect.
- Make `start` asynchronous and consecutive starts self-serializing without a
  mandatory `sync` between them.
- Make `sync` await all earlier work through the scalar join path.
- If the optional scalar-store interlock is implemented, prevent both new and
  already-running ASIC/DMA SRAM effects while it is asserted.
- Use DMA for performance data movement; reserve scalar SRAM access for debug
  and bring-up.
- Preserve behavior when command, pending-start, or snapshot depth changes.
- Cite edge-cores and record the exact revision in a paper artifact.
- Attribute the Edge RV execution/snapshot framework to edge-cores; claim only
  the user's new ASIC and integration work as the paper's contribution.
- Never publish private source, symbol mappings, private paths, or unlicensed
  RTL in a protected release.

Report the files changed, exact tests run, and any integration surface that
remains unverified.
