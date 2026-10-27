# CoreMark example

Run the Edge build on the public `edge-e3` Verilator simulator:

```sh
./example/coremark/run-edge.sh
```

`build-edge.sh` compiles an RV32 image for the Edge32 control core. The
`run-edge.sh` script builds the simulator through `scripts/build-verilator.sh`
and prints the measured `cycle_delta` for two CoreMark iterations.

Initialize `third_party/coremark` before running this benchmark. This fixed
two-iteration RTL run is not an official ten-second CoreMark submission.
