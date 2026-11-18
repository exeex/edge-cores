---
name: integrate-your-design
description: Integrate a custom accelerator, DMA or SRAM with the public Edge-32/E3 platform in edge-cores. Use for component submodules, ASIC32 commands and intrinsics, memory ownership, RTL/software validation and research artifacts; distinguish separately supplied historical RV64 frontends when selected.
---

# Integrate Your Own Design

Integrate an independently designed accelerator, DMA, DTCM/SRAM or complete
ASIC set while preserving command ordering, operand ownership and memory
visibility. The maintained product is Edge-32 with public E3 and shared ASIC
RTL. Historical RV64 frontends require their own sources and explicit revision;
do not assume their snapshot/IFU join path is present in the current product.
Treat the user's design as the new contribution and identify reused components.

## Integration workflow

1. Inspect the checkout, `.gitmodules`, selected top and production filelist.
   Use the pinned public E3, Edge-32 and ASIC sources and NNC when needed.
   Preserve the workspace layout for maintained build and test tools; private
   test repositories remain optional. For fork/publication work follow
   [edge-contribution](../edge-contribution/SKILL.md); ordinary local integration
   does not require creating an external repository first.
2. For a separately maintained ASIC, add its repository below `src/` as a
   submodule, retaining its history, license and ownership. Record the component
   commit and parent gitlink together. Decide whether to reuse E3's existing
   DMA/SRAM or provide new blocks before expanding the integration boundary.
   A new product needs explicit filelist/build wiring; synthesis profile names
   are not discovered automatically.
3. Connect the command interface:
   - allocate an unused ASIC32 7-bit subop and register its legality and
     operand routing in the classifier/decoder;
   - provide accelerator-specific `setcsr`/`set_*`, asynchronous `start`, and
     `sync` operations, using ACTU as the reference interface;
   - carry `imm8` and the resolved GPR operand through the current Edge-32
     request/response path; split additional runtime operands into setup
     commands and follow the actual address transport protocol;
   - use the E3 SDK entry and Edge-32 encoder together with dispatch, pipe
     decode, readiness, result/error delivery and target ports; and
   - update exact-encoding and boundary tests. Modify a tagged snapshot queue
     or scalar join only when the chosen frontend actually connects one.
4. Reuse or design DMA for the ASIC's memory transfers. Define each memory's role,
   ports, address map, width, latency, and ownership policy. A TPU-style
   systolic array normally needs at least an I/O SRAM and weight buffer, with
   DMA paths between system memory and both ASIC-visible stores.
5. Add LSU read/write access when RISC-V software must initialize or inspect
   I/O SRAM, weight SRAM, or another private memory during bring-up. Inspect
   the public Edge32 LSU boundary and E3 integration in `src/edge-e3`; use an
   explicit arbiter or multi-port contract and preserve byte strobes, response
   latency, backpressure, and memory visibility. Edit the public RTL sources;
   keep private internal test repositories optional.
6. Use scalar format helpers where useful for fixtures and fallback code;
   inspect the [E3 SDK](../../../src/edge-e3/include/README.md),
   [scalar helpers](../../../src/edge-e3/include/edge_e3/edge_fp_scalar.hpp)
   and matched Edge-32 backend for actual format/mode support. Keep an
   independent numerical reference. The current
   [product top](../../../src/edge-e3/edge_core/edge_core_scalar_product_top.v)
   instantiates `ENABLE_FPU=1`; an FPU-free product requires deliberate RTL and
   software configuration changes and validation, not an existing wrapper switch.
7. Run focused command, DMA/SRAM and LSU tests, plus snapshot tests only for
   a tagged frontend. Then select interface, examples and NNC coverage from
   [tests/README.md](../../../tests/README.md). Record exact component revisions,
   PASS / FAIL / NOT RUN and any custom boundary the public harness cannot reach.

## Load only the needed reference

- Read [references/instruction-interface.md](references/instruction-interface.md)
  when allocating opcodes or adding C++ `set_*`, `start`, or `sync` wrappers.
- Read [references/execution-model.md](references/execution-model.md) when
  working on request/response, descriptor lifetime, pending starts, engine
  joins or an explicitly selected tagged frontend.
- Read [references/memory-integration.md](references/memory-integration.md)
  when connecting DMA, SRAM, LSU, arbitration, address conversion, or
  `lsu_store_block`/`mem_store_block`.
- Read [references/rtl-patterns.md](references/rtl-patterns.md) only when
  implementing current handshake/launch logic, optional snapshot issue or
  SRAM request blocking.
- Read [references/verification.md](references/verification.md) before testing
  or reviewing an implementation.
- Read [references/paper-evaluation.md](references/paper-evaluation.md) when
  defining paper contributions, claims, baselines, or PPA results.
- Read [references/paper-release.md](references/paper-release.md) only for a
  paper, source artifact release, or citation task.

## Preserve these invariants

- Consume the resolved operand associated with the accepted command, never
  a later live register value. Hold request payloads stable under backpressure.
- For a tagged frontend, match reusable snapshot slots with full sequence
  and epoch ownership and preserve its redirect/kill rules.
- Keep setup and start commands ordered; never lose commands under
  backpressure or redirect.
- Make `start` asynchronous and consecutive starts self-serializing without a
  mandatory `sync` between them.
- Make target `sync` wait for that engine's earlier work and outstanding
  transport. Use the current response path or the selected frontend's tagged
  join; do not treat a single engine sync as a global DMA/compute barrier.
- If the optional scalar-store interlock is implemented, prevent both new and
  already-running ASIC/DMA SRAM effects while it is asserted.
- Keep descriptors and buffers valid until completion. Publish CPU-written
  DRAM payloads before DMA and acquire completed outputs before scalar reads;
  match physical layouts with `io_layout.json` when integrating NNC models.
- Prefer DMA for bulk movement; scalar initialization, inspection and fallback
  code must follow the relevant ownership contract.
- Preserve behavior at supported queue depths. Do not assume same-cycle
  pending launch/refill or an active scalar-store interlock in current Tensor/E3.
- Cite edge-cores and record the exact revision in a paper artifact.
- Attribute the actual reused hardware/software to its sources; claim only
  the user's added design, integration and supported evaluation results.
- Never publish private source, symbol mappings, private paths, or unlicensed
  RTL in a protected release.

Report the files changed, exact tests run, and any integration surface that
remains unverified.
