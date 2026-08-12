# DMA, SRAM, and LSU integration

Require the user to supply DMA, DTCM/SRAM, and compute ASIC. For a systolic
array, inventory the I/O SRAM, weight buffer, accumulator/output storage, and
every system-memory transfer before choosing the DMA topology. Connect scalar
LSU and ASIC/DMA access through an explicit arbiter or multi-port SRAM contract.
Confirm:

- configured region base/mask matching;
- byte address to SRAM word-address conversion;
- byte write strobes and partial stores;
- SRAM read latency and ready/valid behavior; and
- stable request, address, data, and write-enable under backpressure.

## Scalar-store interlock

Treat the scalar-store interlock as a recommended bring-up/debug feature, not
an architectural requirement. It allows C++ tests to initialize ASIC-visible
SRAM using ordinary scalar stores and keeps the test environment stable by
preventing the ASIC from observing a pending or only partially visible write.

It is reasonable to omit this feature when scalar code never writes the ASIC
SRAM or when another ownership/fence protocol provides the same visibility
guarantee. Tuned software should use DMA for normal data movement.

When implementing the interlock, qualify every competing SRAM request with
`!lsu_store_block` or the current checkout's equivalent `!mem_store_block`.
Cover compute bank reads/writes, DMA, SLD, WLD, and any already-running
accelerator, not only new `start` requests.

Do not advance an accelerator address, counter, or state machine for a request
suppressed by the arbiter. If SRAM acknowledges a scalar store before the
write becomes visible to the ASIC port, extend the product-side interlock
through the actual visibility point.

The private reference applies this at
`~/n906/src/edge-e3/edge_dtcm_subsys/rtl/edge_dtcm_arb.v`: ACTU/tensor bank
requests are masked and DMA, SLD, and WLD requests are individually qualified.

Treat scalar SRAM loads/stores as debug, bring-up, or temporary
incomplete-functionality paths.
