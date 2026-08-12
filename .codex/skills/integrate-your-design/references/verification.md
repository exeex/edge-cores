# Verification checklist

Run the smallest focused RTL test first, then the relevant public software
harness using the new intrinsic. Cover:

1. Exact opcode8, imm8, and GPR selection for every wrapper.
2. A GPR produced out of order immediately before a consuming `set_*`; verify
   the ASIC receives the resolved snapshot value.
3. Snapshot-before-command and command-before-snapshot arrival.
4. Full sequence/epoch ownership across low-bit slot wrap and redirect kill.
5. Multiple loop iterations queued while an earlier job runs.
6. Direct start, pending start, simultaneous pending launch/refill, queue-full
   backpressure, and configurable depth boundaries.
7. `start` returning before completion and further starts blocking without
   being lost or overwritten.
8. IFU/predecoder sync join remaining incomplete until all earlier work drains.
9. When the optional debug interlock is implemented, a scalar C++ SRAM
   initialization store with delayed ready/visibility while every affected
   ASIC and DMA request remains blocked and stable.
10. DMA-to-SRAM-to-ASIC and reverse paths, partial strobes, and boundary
    addresses.
11. Reset, illegal commands, redirect/kill, and outstanding commands or
    snapshots.
12. Early FPU-generated NVFP4, FP8, BF16, or FP16 inputs against a software
    reference, including conversion edge cases for every format the ASIC uses.

Test depth 1 and the intended production depths. Verify the public consumer
without private submodules when preparing a release. If no testbench exposes
the custom top, add a focused unit test and report that full integration
coverage remains unavailable.

Report exact commands, pass/fail output, clock assumptions, and whether cycle
numbers come from RTL simulation or silicon.
