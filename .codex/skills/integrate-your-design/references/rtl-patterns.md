# RTL integration patterns

Use the public sources linked below and confirm the selected top/filelist.
Excerpts illustrate local contracts, not complete replacement modules.
Distinguish current product behavior from optional designs; see
[execution model](execution-model.md) for lifecycle and
[instruction interface](instruction-interface.md) for command encoding.

## Current Edge-32 request/response path

E3's [dispatch](../../../../src/edge-e3/edge_core/rtl/edge_lite_accel_dispatch.v)
connects Edge-32 to
[`edge_asic_accel_owner`](../../../../src/edge-asic/rtl/control/edge_asic_accel_owner.v)
and `edge_accel_pipe`. It fixes `cmd_seq_id` and `cmd_epoch` to zero rather
than allocating tagged scalar placeholders. The owner uses:

```verilog
wire cmd_fire = cmd_valid && cmd_ready;
assign cmd_valid = req_valid && !resp_valid;
assign req_ready = cmd_ready && !resp_valid;
assign cmd_inst = req_inst;
assign cmd_capture_valid = 1'b1;
assign cmd_capture_value = req_capture_value;
```

The owner registers `resp_valid` from `cmd_fire`, with the decoded error and
optional result. It does not buffer an independent operand snapshot. The
request producer must retain its instruction and resolved operand until
acceptance. [Edge-32 completion](../../../../src/edge-32/rtl/ex/completion.svh)
records `accel_req_fire` and completes the instruction only after
`accel_started_q && accel_resp_valid`.

For a valid start, this response means the target accepted the descriptor,
not that compute finished. For sync, the
[pipe](../../../../src/edge-32/rtl/edge_accel_pipe.v) withholds target readiness
until the corresponding Tensor/ACTU/CMPU stall clears or `dma_sync_done`
asserts. Preserve that target-specific drain condition and the error response;
do not turn decode errors into accelerator side effects.

## Snapshot-backed issue for a tagged frontend

Use this pattern only when the chosen frontend sends commands and operands
separately. The public
[`edge_accel_cmd_queue`](../../../../src/edge-e3/edge_accel_cmd_queue/edge_accel_cmd_queue.v)
contains the actual signal names:

```verilog
assign n_operand_ready = !entry_n_capture_valid[head_ptr] ||
                         (entry_snapshot_valid[head_ptr] &&
                          entry_snapshot_n_valid[head_ptr]);
assign issue_valid = head_live && n_operand_ready;
assign issue_n_valid = head_live && entry_n_capture_valid[head_ptr];
assign issue_n_value = issue_n_valid ? entry_snapshot_n_value[head_ptr] :
                                     {VALUE_WIDTH{1'b0}};
assign issue_fire = issue_valid && issue_ready;
```

`head_live` excludes redirect-killed entries. Check both command-first and
snapshot-first arrival: `snapshot_matches_enqueue` and
`cmd_matches_pending_snapshot` use full sequence/epoch ownership even though
low sequence bits index a slot. Preserve the queue-entry operand and release
matching ownership on issue or kill; slot equality alone fails after wrap.
The current queue's `cmd_ready` is capacity-only, independent of command
sequence and downstream readiness, to avoid feeding frontend bundle selection
back into itself.

For a frontend with scalar join placeholders, a sync join must have no GPR
source and retain the command's sequence/epoch. Complete it only from the
matching sync notification after the target drains, never ordinary scalar
issue. This describes a tagged-frontend integration contract; the maintained
Edge-32 path above has no such IFU pseudo-instruction mechanism. Do not copy
historical private predecoder/core-top names as current wiring instructions.

## Tensor start acceptance and handoff

The maintained reference is
[`edge_tensor_unit/edge_tensor_unit.v`](../../../../src/edge-e3/edge_tensor_unit/edge_tensor_unit.v),
not the old `edge_tensor_unit_bank16` path. Its configuration gate is:

```verilog
assign cfg_cmd_ready = !queued_start_valid_q && !start_pending_q;
assign tensor_cmd_ready = cfg_cmd_ready;
```

`tensor_start_ready` excludes those same queued/pending states and additionally
checks mode, scale and weight readiness. Inspect the full expression rather
than using configuration readiness as start readiness.

The non-copy launch branches include:

```verilog
assign start_direct_accept =
    start_accept && !copy_mode_req
    && (weight_reuse_token_q || weight_loaded_q)
    && !queued_start_valid_q && !engine_busy;
assign start_queue_accept =
    start_accept && !copy_mode_req
    && (weight_reuse_token_q || weight_loaded_q)
    && !queued_start_valid_q && engine_busy;
```

The distinct `start_wait_accept` branch captures work whose weights are still
pending. Preserve the accepted descriptor's `start_pending_*` fields through
`start_pending_direct_launch` or `start_pending_queue_launch`; do not substitute
later live configuration. Copy-mode behavior is separate. Sync must account
for queued/pending work and transport activity as well as `engine_busy`.

A new accelerator may implement a one-slot pending queue with simultaneous
launch/refill, but that is an alternative design, not the current Tensor
handshake. For such a design, derive acceptance from actual free capacity,
select the old pending descriptor for launch, and give a newly accepted
queued descriptor precedence over clearing the slot. Verify empty/direct,
busy/enqueue, full/backpressure, launch/refill and reset cases together.
Capture every job field and hold it stable until transfer. Do not assume the
current Tensor slot can refill in the same cycle that a pending job launches.

Batching starts with one final sync is valid only while buffers remain live
and inter-job dependencies permit it. Insert joins for buffer reuse or
cross-engine consumers; see the example in [execution model](execution-model.md).

## Optional scalar-store interlock

The public [arbiter](../../../../src/edge-e3/edge_dtcm_subsys/rtl/edge_dtcm_arb.v)
retains `lsu_store_block` gating, but the current
[Edge-32 platform](../../../../src/edge-e3/edge_core/rtl/edge_lite_accel_platform.v)
ties `scalar_lsu_store_block` to zero. Do not describe this as an active global
pause of competing engines in the product.

If adding an interlock to a conventional ready/valid SRAM client, qualify
both sides of the handshake. The following is conceptual, with placeholder
signal names, not a drop-in E3 bank interface:

```verilog
assign sram_valid = producer_valid && !store_block;
assign producer_ready = sram_ready && !store_block;
wire transfer = sram_valid && sram_ready;
// Producer address/data/state advances only on transfer.
```

Masking only request while returning an unqualified ready can lose work.
Keep the producer's payload stable while stalled. E3's scheduled H4/bank
adapters have their own grant and response contracts: trace each selected
compute, DMA, WLD and SLD path before applying a gate. Cover already-running
and buffered requests, not just starts. If scalar acknowledgement precedes
physical SRAM visibility, protect through the visibility point.

An interlock can simplify initialization/debug, but it does not replace
DRAM cache publication/acquisition or application ownership. See
[memory integration](memory-integration.md) for the active product limits.

## Validate an implementation

For changes based on these patterns, test request stability and single
acceptance under stalls, response/error delivery, descriptor immutability,
pending launch and complete drain. Add sequence wrap, both operand arrival
orders and redirect kills only for a connected tagged frontend; add partial
stores and in-flight transport checks when changing an interlock.

Then use [public regression routing](../../../../tests/README.md) for the
affected interface, examples and NNC paths. Passing a software case alone does
not establish all queue-depth, reset or simultaneous-event corner cases.
