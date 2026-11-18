# Snapshot and asynchronous execution

Keep scalar address/control work ahead of accelerator execution where the
interface permits it. Size command, operand, pending-start, DMA descriptor,
and accelerator-local storage for the intended lookahead. Command acceptance,
engine launch, and compute completion are distinct events.

## Select the actual scalar integration

The maintained public E3 product uses Edge-32 through
[`edge_core_edge32_top`](../../../../src/edge-e3/edge_core/edge_core_scalar_product_top.v),
as documented in the [E3 integration guide](../../../../src/edge-e3/README.md).
It does not require the older RV64 snapshot/IFU join interface. Follow the
selected top and its production filelist before choosing a command protocol;
the presence of a queue module in the source tree does not prove it is on the
active product path.

In the current Edge-32 path:

- [`ex/completion.svh`](../../../../src/edge-32/rtl/ex/completion.svh)
  presents the instruction and resolved GPR operands, records request
  acceptance, and waits for `accel_resp_valid` before completing the scalar
  accelerator instruction.
- E3's [`edge_lite_accel_dispatch`](../../../../src/edge-e3/edge_core/rtl/edge_lite_accel_dispatch.v)
  passes the operand to the ASIC command path and ties `cmd_seq_id` and
  `cmd_epoch` to zero. It does not allocate tagged scalar join placeholders.
- [`edge_asic_accel_owner`](../../../../src/edge-asic/rtl/control/edge_asic_accel_owner.v)
  forwards the request and operand, gates acceptance with `cmd_ready`, and
  registers a response on command fire. Keep request data stable until the
  handshake; this owner is not a separate queue of GPR snapshots.

Thus scalar instruction completion after a successful start acknowledges
acceptance by the target, not completion of its computation. Scalar software
can continue while the engine runs, but lookahead is bounded by downstream
readiness rather than an assumed RV64 command queue depth.

## Snapshot ownership for a tagged command frontend

When integrating a frontend that sends commands and scalar snapshots
separately, resolve every GPR-backed `set_*` through that snapshot interface;
never reread the live register file later. The public
[`edge_accel_cmd_queue`](../../../../src/edge-e3/edge_accel_cmd_queue/edge_accel_cmd_queue.v)
provides this pattern: command-first and snapshot-first arrival are supported,
low sequence bits select a slot, and full `seq_id` and `epoch` establish
ownership. Its queue entries retain the resolved operand, and its issue path
waits for that operand before firing.

Preserve redirect kills and release matching ownership on command fire or
kill. Check sequence wrap and slot reuse against the selected frontend's
in-flight limits. These tagged-queue rules apply when that interface is
actually connected; they do not describe the current Edge-32 product wiring.

## Start behavior

Treat start acceptance as ownership transfer of a complete stable descriptor,
not compute completion. A custom accelerator may launch when idle and accept
bounded pending descriptors while busy. Backpressure before a descriptor can
be overwritten; later `set_*` commands must not mutate accepted work.

Use the current
[`edge_tensor_unit`](../../../../src/edge-e3/edge_tensor_unit/edge_tensor_unit.v)
as a concrete reference, rather than assuming a generic one-slot handshake:

- `start_accept` requires `tensor_start_ready`, which checks queued/pending
  capacity as well as mode, scale and weight conditions.
- `start_direct_accept` launches a non-copy job with available weights while
  idle; `start_queue_accept` accepts it while the engine is busy.
- `start_wait_accept` captures a descriptor while its weights are still
  pending. `start_pending_*` preserves its identity until direct or queued
  launch is possible. Acceptance does not authorize compute before weights
  are available.
- `cfg_cmd_ready` blocks configuration while `queued_start_valid_q` or
  `start_pending_q` is set. `tensor_start_ready` also excludes both states;
  do not assume same-cycle pending launch/refill is supported. A different
  design may implement it deliberately and verify the simultaneous case.

A final join can replace per-job joins only when buffer lifetimes and data
hazards permit overlap. For a hypothetical custom interface:

```cpp
for (...) {
    // Publish CPU-written inputs before handing them to DMA, if applicable.
    // Keep each job's input/output buffers valid until its completion.
    edge_custom_setin(next_in);
    edge_custom_setout(next_out);
    edge_custom_setn(next_n);
    edge_custom_start();  // may stall when downstream capacity is full
}
edge_custom_sync();
// Acquire DMA-produced outputs before reading them on the CPU.
```

These `edge_custom_*` names illustrate a proposed API, not existing SDK
functions. Add intermediate synchronization when reusing buffers, consuming
results, or crossing engine dependencies requires it.

## Sync and memory visibility

In the current public path,
[`edge_accel_pipe`](../../../../src/edge-32/rtl/edge_accel_pipe.v)
withholds readiness for Tensor, ACTU and CMPU sync until the corresponding
`*_sync_stall` clears, and for DMA sync until `dma_sync_done`. The owner then
responds and Edge-32 completes the scalar instruction. A sync joins its target
engine; it is not automatically a global drain of every accelerator and DMA.
Arrange the appropriate joins for the producer/consumer chain.

Tensor's busy calculation includes queued and pending starts, copy work,
weight loads and scale activity as well as `engine_busy`. Preserve the full
drain condition when extending the engine; compute-idle alone is insufficient.

For a tagged RV64-style frontend, implement sync as a no-GPR scalar join
associated with the command's sequence/epoch, completed by the matching
accelerator notification after the target drains. Do not complete that
placeholder during ordinary scalar issue. This is an integration requirement
for that frontend design, not an IFU mechanism present in the Edge-32 path.

Neither a compiler memory clobber nor engine completion establishes CPU cache
ownership. NNC's [memory contract](../../../../src/edge-nnc/MEMORY_OWNERSHIP.md)
requires CPU producers to publish DRAM payload writes before DMA and CPU
readers to acquire completed DMA outputs. The NNC helpers skip DTCM tensors;
DTCM arbitration and engine ordering still need their own contract. Review
these boundaries alongside [memory integration](memory-integration.md) and
validate the selected public path with the
[software harness](../../software-harness/SKILL.md).
