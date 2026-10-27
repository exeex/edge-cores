# linear_q8_0

[model.py](model.py) is the original PyTorch/NNC model: BF16 input `[9,64]`,
Q8_0 weights `[16,64]`, and BF16 output `[9,16]`. Each output lane has
one native FP16 scale per K32 group (`nnedge::Q8_0WeightPack`).

```sh
./example/linear_q8_0/run.sh
```

The model wraps an ordinary PyTorch Linear with the selected quant module:

```python
from nnc import LinearQ8_0
self.linear = LinearQ8_0(torch.nn.Linear(64, 16))
```

The wrapper copies weights and optional bias into frozen BF16 inference
parameters. Its forward calls the registered `nnedge::linear_q8_0` op; NNC selects
the format from that op name and quantizes/packs the original weights during
compile. Bias stays a separate BF16 add. No manual quantization is needed in
the model. The `register_fake` implementation only infers BF16 output metadata.

To generate C++ directly from the visible `__main__` in the model, run from
the workspace root:

```sh
.venv/bin/python -m example.linear_q8_0.model
```

```python
m = Model().eval()
nnc.compile(m, make_example_args(), out_dir=Path(__file__).parent, save_reference=True)
```

Run `./scripts/setup-python.sh` first to install PyTorch and editable NNC
into `.venv`. Module invocation from the workspace root locates this example;
`import nnc` resolves through the editable install in that environment.
This is the explicit regeneration step and requires PyTorch.
`run.sh` builds and runs the saved headers and binaries, comparing every output
with the saved `expected.bin`; it does not import PyTorch, re-export the model,
or requantize weights.
[main.cpp](main.cpp) only initializes and calls the generated forward function.
The source model and main are maintained in edge-nnc and linked here.

Inspect the generated `nnedge::op::linear_q8_0` call in
[forward.hpp](forward.hpp), tensor bindings in
[init.hpp](init.hpp), and packed weights in
`weight.bin`. The two headers and three binaries (`input.bin`, `weight.bin`,
and the BF16 golden `expected.bin`) live beside `main.cpp` and are versioned
in Git as one artifact set. They can be rerun after a Torch update without
regeneration. ELF files and execution logs stay under `build/`.

Use `--build-only` to build the saved artifacts without simulation, or
`--skip-verilator-build` to reuse the current simulator. `--profile` reports
cycles for the Linear and optional bias nodes.

Q8_0 preserves native FP16 scale bits and INT8 codes in E3 tile order.
Extracted Q8_0 row blocks require repacking before use; there is no GGUF
file importer. See the [public format contract](../../src/edge-nnc/QUANT_LINEAR.md).
