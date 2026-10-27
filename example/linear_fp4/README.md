# linear_fp4

[model.py](model.py) is the original PyTorch/NNC model: BF16 input `[9,64]`,
FP4 weights `[16,64]`, and BF16 output `[9,16]`. Each output lane has
one BF16 scale per K32 group (`nnedge::FP4WeightPack`).

```sh
./example/linear_fp4/run.sh
```

The model wraps an ordinary PyTorch Linear with the selected quant module:

```python
from nnc import LinearFp4
self.linear = LinearFp4(torch.nn.Linear(64, 16))
```

The wrapper copies weights and optional bias into frozen BF16 inference
parameters. Its forward calls the registered `nnedge::linear_fp4` op; NNC selects
the format from that op name and quantizes/packs the original weights during
compile. Bias stays a separate BF16 add. No manual quantization is needed in
the model. The `register_fake` implementation only infers BF16 output metadata.

To generate C++ directly from the visible `__main__` in the model, run from
the workspace root:

```sh
.venv/bin/python -m example.linear_fp4.model
```

```python
m = Model().eval()
nnc.compile(m, make_example_args(), out_dir=Path(__file__).parent, save_reference=True)
```

The repository is used in place, so module invocation makes the local `nnc`
package importable. This is the explicit regeneration step and requires PyTorch.
`run.sh` builds and runs the saved headers and binaries, comparing every output
with the saved `expected.bin`; it does not import PyTorch, re-export the model,
or requantize weights.
[main.cpp](main.cpp) only initializes and calls the generated forward function.
The source model and main are maintained in edge-nnc and linked here.

Inspect the generated `nnedge::op::linear_fp4` call in
[forward.hpp](forward.hpp), tensor bindings in
[init.hpp](init.hpp), and packed weights in
`weight.bin`. The two headers and three binaries (`input.bin`, `weight.bin`,
and the BF16 golden `expected.bin`) live beside `main.cpp` and are versioned
in Git as one artifact set. They can be rerun after a Torch update without
regeneration. ELF files and execution logs stay under `build/`.

Use `--build-only` to build the saved artifacts without simulation, or
`--skip-verilator-build` to reuse the current simulator. `--profile` reports
cycles for the Linear and optional bias nodes.
