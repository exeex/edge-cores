# CoreMark example

Run the Edge build on the public `edge-e3enc` Verilator simulator:

```sh
./example/coremark/run-edge.sh
```

`build-edge.sh` compiles an RV32 image for the Edge32 control core. The
`run-edge.sh` script builds the simulator through `scripts/build-verilator.sh`
and prints the measured `cycle_delta` for two CoreMark iterations.

The `run-c906.sh` and `build-c906-sim.sh` scripts are a separate T-Head C906
comparison path. They do not run an Edge example.
