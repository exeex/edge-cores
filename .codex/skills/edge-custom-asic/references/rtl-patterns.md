# RTL integration patterns

Use these as structural examples, then confirm signal names and widths in the
target checkout. They are distilled from `~/n906/src/edge-e3`; do not copy the
private tree into a public release. These patterns are recommendations, not
architectural requirements. A different design is valid when it preserves its
own documented ordering, ownership, and memory-visibility contract.

## Contents

- [Snapshot-backed command issue](#snapshot-backed-command-issue)
- [IFU/predecoder sync join](#ifupredecoder-sync-join)
- [Self-serializing asynchronous starts](#self-serializing-asynchronous-starts)
- [Recommended scalar-store interlock for bring-up](#recommended-scalar-store-interlock-for-bring-up)

## Snapshot-backed command issue

Store the decoded command separately from its resolved scalar operand. Match
them with full sequence and epoch metadata even if the physical store is
indexed by low sequence bits.

```verilog
wire operand_ready = !entry_needs_gpr[head]
                   || (entry_snapshot_valid[head]
                       && entry_snapshot_gpr_valid[head]);

assign issue_valid = queue_head_live && operand_ready;
assign issue_opcode8 = entry_opcode8[head];
assign issue_imm8 = entry_imm8[head];
assign issue_gpr_valid = queue_head_live && entry_needs_gpr[head];
assign issue_gpr_value = issue_gpr_valid
                       ? entry_snapshot_gpr_value[head] : '0;

wire snapshot_matches_cmd =
    snapshot_owner_seq_id[slot] == cmd_seq_id
 && snapshot_owner_epoch[slot] == cmd_epoch;
```

Support both arrival orders: snapshot before command and command before
snapshot. Release the slot only when the command fires or is killed. Apply
redirect kill using sequence and epoch; slot equality is insufficient because
low sequence bits wrap.

In the private reference, see
`edge_accel_cmd_queue/edge_accel_cmd_queue.v` for `n_operand_ready`,
`issue_n_value`, `snapshot_matches_enqueue`, and
`cmd_matches_pending_snapshot`.

## IFU/predecoder sync join

Recognize each sync opcode in predecode and create a scalar pseudo instruction
with no GPR source:

```verilog
wire accel_sync_join = vector_valid && vector_is_accel &&
    ((subop == TENSOR_SYNC) || (subop == DMA_SYNC) ||
     (subop == ACTU_SYNC) || (subop == CUSTOM_SYNC));

assign pseudo_kind = accel_sync_join ? PSEUDO_ACCEL_JOIN
                                      : PSEUDO_ACCEL_GPR_HOLDER;
assign pseudo_source_mask = accel_sync_join ? 3'b000 : 3'b001;
```

Allocate the pseudo operation with the sync command's sequence/epoch. Do not
mark it complete at ordinary scalar issue. Complete it only when the accel
pipe reports that same sync command done:

```verilog
assign sync_done_valid = accel_done_valid &&
                         (accel_done_subop == CUSTOM_SYNC);
// Feed sync_done_valid/seq_id/epoch to the scalar placeholder completion path.
```

This is why `edge_custom_sync()` must be added to the IFU/predecoder opcode
classification as well as to the accelerator pipe. In the private reference,
see `edge_predecoder.v` around `window_tensor_sync_join` and
`edge_core_top.v` around `tensor_sync_done_valid`.

## Self-serializing asynchronous starts

Keep active and pending descriptors separate. A pending descriptor must hold
all values captured at start acceptance.

```verilog
wire pending_launch = pending_valid_q && engine_handoff_ready;
wire pending_slot_available = !pending_valid_q || pending_launch;
assign start_ready = pending_slot_available;
wire start_accept = start_req && start_ready;
wire start_direct = start_accept && engine_idle && !pending_valid_q;
wire start_queue  = start_accept && !start_direct;

always @(posedge clk or negedge reset_n) begin
  if (!reset_n) begin
    pending_valid_q <= 1'b0;
  end else begin
    if (pending_launch)
      pending_valid_q <= 1'b0;
    if (start_queue) begin
      pending_valid_q <= 1'b1;
      pending_in_q <= cfg_in_q;
      pending_out_q <= cfg_out_q;
      pending_count_q <= cfg_count_q;
      pending_mode_q <= cfg_mode_q;
    end
  end
end
```

Resolve simultaneous `pending_launch` and `start_queue` deliberately so the
slot can refill without losing a cycle. Do not use live configuration
registers for a queued job. Deassert ready when accepting another start would
overwrite the pending descriptor. The tensor reference is
`edge_tensor_unit/rtl/edge_tensor_unit_bank16.v`, especially
`start_direct_accept`, `start_queue_accept`, `start_pending_*`, and
`queued_start_*`.

This scheme permits:

```cpp
for (...) {
    edge_custom_setin(next_in);
    edge_custom_setout(next_out);
    edge_custom_setn(next_n);
    edge_custom_start();  // backpressures only when hardware lookahead is full
}
edge_custom_sync();       // one final join when software needs the results
```

Do not insert a sync after every start unless software consumes that job's
result immediately.

## Recommended scalar-store interlock for bring-up

This interlock mainly supports early software development. It lets a C++ test
initialize or patch ASIC-visible SRAM with ordinary scalar stores, then start
the ASIC without adding a custom initialization path. Blocking ASIC/DMA SRAM
requests while such a store is pending prevents the accelerator from reading
partially initialized or not-yet-visible data. That makes functional tests,
debug sessions, and failure reproduction more deterministic.

The interlock is not required for every product. It may be omitted when scalar
code never writes the accelerator SRAM, when DMA is the only data producer, or
when another ownership/fence protocol guarantees visibility. Performance
software should normally use DMA rather than scalar stores.

When choosing this bring-up convenience, apply it at the SRAM arbiter request
boundary:

Apply the LSU store interlock at the SRAM arbiter request boundary:

```verilog
assign custom_bank_req = custom_raw_bank_req &
                         {BANK_NUM{!lsu_store_block}};
assign dma_req_to_sram = dma_req && !lsu_store_block;
assign accel_load_req_to_sram = accel_load_req && !lsu_store_block;
assign accel_store_req_to_sram = accel_store_req && !lsu_store_block;
```

Keep the request and its associated address/data/write-enable stable while
blocked according to the producer's ready/valid contract. Do not allow an
active accelerator to advance internal read/write counters for a request that
the arbiter suppressed; otherwise the debug interlock itself can drop or
misalign accesses.

The private reference applies this in
`edge_dtcm_subsys/rtl/edge_dtcm_arb.v`: ACTU/tensor bank requests are masked,
and DMA, SLD, and WLD requests are individually qualified. This protects both
new starts and already-running engines from observing C++ initialization data
too early.
