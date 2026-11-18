# DMA, SRAM, and LSU integration

Identify which DMA, DTCM/SRAM and compute blocks the new design supplies and
which it reuses from E3. For a systolic array, inventory I/O SRAM, weight
buffers, accumulator/output storage and every system-memory transfer before
choosing the topology. The public E3 product already provides DMA and DTCM;
a custom compute block does not necessarily need to replace them.

## Follow the public product boundary

The maintained [E3 top](../../../../src/edge-e3/edge_core/edge_core_scalar_product_top.v)
connects Edge-32's scalar DTCM interface to
[`edge_lite_accel_platform`](../../../../src/edge-e3/edge_core/rtl/edge_lite_accel_platform.v).
The scalar compatibility port carries 64-bit data and eight byte strobes,
with separate request acceptance (`ready`) and read response (`rvalid`).
Do not infer its width from the RV32 GPR width.

Inspect the selected product filelist and
[`edge_dtcm_subsys`](../../../../src/edge-e3/edge_dtcm_subsys/edge_dtcm_subsys.v)
before copying an older bank arrangement. The current default is wide H4
when `SRAM_H4=1`; `EDGE_DTCM_LEGACY_H4` selects the legacy layout. Memory
layout choices must agree between RTL and software. The
[E3 integration guide](../../../../src/edge-e3/README.md) describes native
256-bit P/O access and the locally reordered 128-bit narrow-client paths;
these are not interchangeable with historical SRAM fixtures.

Connect scalar and accelerator accesses through an explicit arbiter or
multi-port contract. Confirm:

- Region base/mask/enable in RTL agrees with linker symbols exposed by the
  [SDK memory map](../../../../src/edge-e3/include/edge_e3/edge_memory_map.hpp):
  `EDGE_DTCM_BASE`, `EDGE_DTCM_SIZE` and `EDGE_DTCM_MASK`.
- Byte addresses, DTCM offsets and SRAM word/lane addresses are distinguished.
  The [accelerator pipe](../../../../src/edge-32/rtl/edge_accel_pipe.v)
  recognizes the configured region and converts its byte offset to an
  eight-byte word address. Follow the individual engine adapter after that
  conversion; do not pass a byte address unchanged to a word-indexed port.
- Byte strobes and partial stores survive width conversion and bank selection.
- SRAM read latency, response ownership and outstanding request limits match
  each client. Acceptance is not necessarily physical write completion.
- Request, address, data and write-enable remain stable as required under
  backpressure, and producers advance only on accepted transfers.

## DMA completion and buffer ownership

A descriptor must retain its addresses, length and mode after acceptance.
Separate command acceptance, AXI completion and SRAM visibility. For example,
[`edge_dma_h4`](../../../../src/edge-e3/edge_dtcm_subsys/rtl/edge_dma_h4.v)
requires both engine completion and drained read/write transport and response
state before reporting completion. It also checks alignment/range before
accepting a start. Do not generalize its exact limits to every DMA mode or
report success merely because an AXI beat was accepted.

Keep buffers valid until the relevant engine completes. Join DMA before a
consumer reads staged data, join compute before copying its output, and join
output DMA before CPU acquisition. Use the selected engine's supported
ordering/streaming protocol if overlapping those steps; see
[execution model](execution-model.md). A single engine sync is not a global
join of every producer and consumer.

For DRAM tensors, engine completion and CPU cache ownership are separate.
NNC's [memory contract](../../../../src/edge-nnc/MEMORY_OWNERSHIP.md) and
[`tensor.hpp`](../../../../src/edge-nnc/cpp/libnn/tensor.hpp) implement:

- `scalar_tensor_publish`: clean CPU-written payloads before DMA consumes them.
- `scalar_tensor_acquire`: invalidate an old CPU view before scalar access to
  a completed DMA result. The prior scalar producer must have published its
  writes; acquisition is not permission to discard unpublished dirty data.
- Both helpers skip DTCM tensors. DTCM still requires correct arbitration,
  store visibility and engine ordering.

Keep scalar metadata and DMA payloads on separate cache lines, including
alignment and arena-end padding. DMA-owned buffers do not require redundant
cache maintenance on every transfer when scalar code never accesses them.
Compiler memory clobbers and scalar fences do not replace the ownership
handoff. Physical tensor layout must also match `io_layout.json`; logically
identical shapes alone do not guarantee compatible payload storage.

## Optional scalar-store interlock

An interlock can support bring-up by preventing accelerator access while a
scalar store is still becoming visible. It is an optional integration feature,
not a guarantee provided by every E3 configuration.

The public [arbiter](../../../../src/edge-e3/edge_dtcm_subsys/rtl/edge_dtcm_arb.v)
contains `lsu_store_block` gating for competing bank and DMA/SLD/WLD requests.
However, the maintained Edge-32 `edge_lite_accel_platform` ties
`scalar_lsu_store_block` to `1'b0`. The presence of this port does not mean
scalar writes globally pause already-running engines in the current product.
Use explicit ownership and completion ordering when software accesses shared
storage; arbitration alone does not make concurrent accesses race-free.

If adding an interlock, trace every active path in the selected H4/bank
configuration. Cover already-running compute and DMA traffic, not only new
starts. Preserve client handshakes: do not advance counters or state for a
request that is suppressed. If a store is acknowledged before its data becomes
visible, keep protection through the actual visibility point. Verify buffered
and in-flight requests as well as requests entering the arbiter.

Prefer DMA for bulk data movement. Scalar SRAM access remains useful for
initialization and inspection; scalar DRAM fallback operators are also valid
when they follow the cache ownership contract.

## Validate the changed boundary

For memory integration changes, follow the
[public regression routing](../../../../tests/README.md): rebuild public RTL,
run the interface sentinel and affected examples, and include the NNC group
for layout/allocator/cache-ownership changes. The
[Matmul sentinel](../../../../tests/interface/matmul.cpp) publishes scalar
fixtures and output guards before DMA, acquires outputs afterward, and checks
independent bit-exact goldens. NNC's cache-ownership regression exercises the
scalar/DMA transitions. These tests complement focused checks for partial
stores, backpressure, reset, bank conflicts and completion timing; they do
not prove every custom arbiter or optional interlock correct.
