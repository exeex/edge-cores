# ACTU throughput example

This bare-metal example measures 4,096-element sigmoid, SiLU, tanh, and
three-pass softmax pipelines on the public encrypted edge-e3 core. Each kernel
runs once to warm the instruction path, then a second time at the same address;
only the second `start`-through-`sync` interval is reported. Input preparation
and BF16 result validation are outside the timing window.

Build only the software image:

```sh
./example/actu/build.sh
```

Build the encrypted-core Verilator simulator and run the example:

```sh
./example/actu/run.sh
```

The terminal prints the four measured cycle counts. Build details are saved to
`build/build.log`, simulator output to `build/run.log`, and the simulator test
result to `build/run_case.report`.

This example intentionally contains only the edge-e3 workload. The original
C906 comparison, plotting utility, and dated synthesis reports are experiment
artifacts rather than dependencies of the runnable public example.

Set `LLVM_PREFIX`, `LLD_PREFIX`, `VERILATOR`, `EDGE_ACTU_OUT`, or
`EDGE_VERILATOR_OUT` to override local tool and output paths.
