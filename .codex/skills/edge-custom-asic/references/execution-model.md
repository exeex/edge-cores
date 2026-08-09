# Snapshot and asynchronous execution

Keep the scalar thread ahead of the ASIC thread. Scalar work calculates
branches, pointers, and indices and may enqueue iteration `i+1` while the ASIC
runs iteration `i`. Size command, snapshot, pending-start, DMA descriptor, and
accelerator-local state for the intended lookahead.

## Snapshot ownership

Resolve every GPR-backed `set_*` through the snapshot path. Store the value
with the command; never make the ASIC read the live register file later.
Support both command-first and snapshot-first arrival. Low sequence bits may
index a physical slot, but full `seq_id` and `epoch` establish ownership.
Release the value only when the command fires or is killed, and preserve
redirect handling.

## Start behavior

Treat start acceptance as ownership transfer of a complete stable descriptor,
not compute completion. Launch directly when idle. While busy, accept one or
more bounded pending descriptors only when capacity exists. Deassert
`start_ready` before an invocation could be overwritten.

Follow tensor's active-plus-pending behavior for the basic design: job `i+1`
may queue while job `i` runs; later starts backpressure until the slot advances.
Allow simultaneous pending launch and refill when implemented deliberately.
Later `set_*` commands must not mutate a previously accepted descriptor.

This permits one final synchronization instead of one per iteration:

```cpp
for (...) {
    edge_custom_setin(next_in);
    edge_custom_setout(next_out);
    edge_custom_setn(next_n);
    edge_custom_start();
}
edge_custom_sync();
```

## Sync behavior

Implement sync in IFU/predecoder as a no-GPR scalar join pseudo-operation with
the command's sequence and epoch. Do not complete it during ordinary scalar
issue. Complete the placeholder only when the accel pipe reports the matching
sync command done after all earlier accelerator work drains.

The accelerator still exposes the busy/drained state used by accel-pipe
readiness. Do not implement sync solely as a compiler memory barrier or solely
inside the compute block.
