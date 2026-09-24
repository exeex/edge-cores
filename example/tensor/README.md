# Tensor example

This directory contains the `64x64 x 128-token` tiled circular matmul demo.
The simulator builds against `src/edge-e3enc/edge_e3enc.v`, the public Edge32
RTL in `src/edge-32`, and `src/edge-e3enc/edge_e3enc_sram.v`.

Shared freestanding C++ headers live under `cpp/`; intrinsics and the simulator
console `printf` implementation live under `cpp/intrinsic/`.
The example prints its measured cycle interval directly; it does not reserve
X30/X31 as simulator-only metric or debug channels.
Startup and exit are owned by `cpp/baremetal/crt0.s`; the example only defines
`main()` and contains no private `_start`/`edge_main` assembly shim.

Build only the software image:

```sh
./example/tensor/build.sh
```

Build the encrypted-core Verilator simulator and run the example:

```sh
./example/tensor/run.sh
```

The terminal shows runtime `printf` output rather than compiler output. Build
details are saved to `build/build.log`, and simulator output to `build/run.log`.

Set `LLVM_PREFIX`, `LLD_PREFIX`, `VERILATOR`, `EDGE_TENSOR_OUT`, or
`EDGE_VERILATOR_OUT` to override local tool and output paths.
