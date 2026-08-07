---
name: edge-tensor-example
description: Build and run the public 64x64 x 128-token tiled circular tensor matmul example on the encrypted Edge Verilator simulator.
---

# Tensor example workflow

The maintained example is
`example/tensor/matmul64x64_128tokens_tiled_circular.cpp`. Its public intrinsic
surface is in `cpp/intrinsic`, and `tools/elf2mem128.py` converts the
freestanding RISC-V ELF into the testbench memory image.

Use these entry points:

```sh
./example/tensor/build.sh
./example/tensor/run.sh
```

`run.sh` must build the simulator through `scripts/build-verilator.sh`, pass
the output expectation to `edge_soc_demo_tb`, and require `TEST PASS` in
the generated report. For performance comparisons, use the `cycle_delta`
printed by the program rather than total simulator cycles. Do not publish
metrics or debug values through fixed registers such as X30/X31.
The public C++ runtime is bare-metal only: do not reintroduce `NNEDGE_HOST`
branches or an example-local `_start`/`edge_main`; startup belongs to
`cpp/baremetal/crt0.s`.

## CoreMark comparison

The same-source two-iteration CoreMark comparison uses the checked-in sources
under `third_party/coremark` and the C906 RTL under `third_party/openc906`:

```sh
.codex/skills/edge-tensor-example/scripts/run-coremark-compare.sh
```

Individual entry points are `example/coremark/run-c906.sh` and
`example/coremark/run-edge.sh`. Report the printed `cycle_delta` (internal
`rdcycle` cycles per iteration), not simulator wall time. This is an RTL smoke
comparison and is not an official ten-second CoreMark submission.
