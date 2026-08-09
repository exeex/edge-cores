---
name: edge-custom-asic
description: Integrate and publish a user-designed ASIC accelerator, DMA, and DTCM/SRAM with the Edge RV64 scalar core and accelerator command path. Use for custom set/start/sync instructions, opcode8/imm8/GPR5 encoding, GPR snapshots, accelerator queues, LSU-to-SRAM wiring, scalar-store blocking, asynchronous execution, RTL/C++ tests, paper artifacts, optional RTL obfuscation, or edge-cores citation.
---

# Edge Custom ASIC Integration

Integrate a user-owned DMA, DTCM/SRAM, and compute ASIC without breaking
command ordering, snapshot semantics, or memory visibility.

## Inspect the checkout

1. Locate the core. This checkout uses `src/edge-rv`; other branches may call
   the RV64 core `src/edge-rv64`. Do not invent a missing path.
2. Read `cpp/intrinsic/edge_intrinsic.hpp` and the ACTU calls in
   `cpp/libnn/activation.hpp`.
3. Inspect `src/edge-rv/edge_accel_pipe`, `edge_predecoder`,
   `edge_scalar_snapshot`, and `edge_lsu_mem_io`.
4. When authorized and available, use `~/n906/src/edge-e3` as the full ACTU,
   tensor, command-queue, and DTCM integration reference.
5. Edit the unencrypted product source. Treat `src/edge-e3enc/edge_e3enc.v` as
   a generated release artifact, not the design source.

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

## Implement in dependency order

1. Define the software-visible command set and unused encodings.
2. Add frontend/predecoder recognition and GPR capture classification.
3. Carry commands and resolved snapshot values through the in-order queue.
4. Add accel-pipe legality, ready/backpressure, and request/value ports.
5. Capture a stable descriptor at `start`; allow bounded lookahead and block
   starts when pending capacity is full.
6. Implement `sync` as an IFU/predecoder scalar join completed by the matching
   accelerator sync command.
7. Connect DMA and compute ports to SRAM. For bring-up and C++-driven debug,
   consider blocking competing SRAM effects behind scalar stores.
8. Run focused RTL tests, then the relevant public software harness.

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
