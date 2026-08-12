# Hello world

Build and run the smallest Edge bare-metal C++ program:

```sh
./example/hello/run.sh
```

Expected console output:

```text
Hello from edge-e3!
EDGE_DEMO TEST PASS
```

`run.sh` keeps LLVM and Verilator build output in `build/build.log`, so the
terminal shows the program's `printf` console directly. Simulation output is
also saved to `build/run.log`. See the
[FP8/BF16 debug example](../fp8_bf16_debug/README.md) for floating-point
formatting and low-precision conversion tests.
