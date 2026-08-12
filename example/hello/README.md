# Hello world

Build and run the smallest Edge bare-metal C++ program:

```sh
./example/hello/run.sh
```

Expected console output:

```text
Hello from edge-e3!
Float debug: -12.375000 2.000 +00003.50 2
Float edges: negzero=-0.00 carry=1.000 alt=2. left=[1.25    ]
Float special: nan INF -inf wide=0.500000000000
EDGE_DEMO TEST PASS
```

`run.sh` keeps LLVM and Verilator build output in `build/build.log`, so the
terminal shows the program's `printf` console directly. Simulation output is
also saved to `build/run.log`. The floating-point line covers `%f` with both a
promoted `float` and a source-level `double`, plus precision, sign, zero-pad,
rounding, negative zero, carry, alternate form, alignment, NaN, infinity, and
precision beyond the nine meaningful FP32 fractional digits.
