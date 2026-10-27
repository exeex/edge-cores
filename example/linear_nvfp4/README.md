# linear_nvfp4

[model.py](model.py) wraps an ordinary PyTorch Linear with `nnc.LinearNvFp4`:

```python
self.linear = LinearNvFp4(torch.nn.Linear(64, 16, bias=False))
```

The example uses contiguous BF16 input `[9,64]`, E2M1 FP4 weights `[16,64]`,
and contiguous BF16 output `[9,16]`. Each output lane has one E4M3FN byte
scale per K16 group. Nine rows exercise token batching and a tail; sixteen
outputs and K64 exercise multiple output blocks and scale groups.

NVFP4 uses one positive per-tensor global scale, RNE-rounded to BF16 and
carried in an FP32 container. NNC emits its bits as the final
`linear_nvfp4` argument in `forward.hpp`; it is not repeated in DMA slots.

This is weight-only quantization: activations and public output stay BF16.
NNC quantizes the frozen BF16 weights at compile time, packs scales and codes,
and generates `nnedge::op::linear_nvfp4` using the shared slot kernel.
Two adjacent groups share a 144-byte physical DMA slot, with no interior
padding. See the [native FP4 format and numerical contract](../../src/edge-nnc/MICROSCALE_LINEAR.md)
for scale selection, BF22 arithmetic and storage limits.

## Run the saved example

From the workspace root, first run `./scripts/setup-python.sh` to install PyTorch and editable NNC in
the project `.venv`; the runner uses this environment by default.

```sh
./example/linear_nvfp4/run.sh
```

The runner builds the public E3 simulator and the saved C++/binary artifacts,
then compares all 144 BF16 output values against `expected.bin` with **zero
absolute tolerance**. There is no bias add. The golden is the quantized
PyTorch reference with the documented E3 arithmetic boundaries; it is not
an unquantized Linear accuracy or vendor GEMM bit-identity claim.

The saved runner does not import PyTorch, export the model or requantize
weights. It requires the normal LLVM/Verilator tools and a Python interpreter.
Use `--skip-verilator-build` to reuse a simulator built from the current RTL,
`--build-only` to compile without simulation, or `--profile` for node cycles.
Execution logs, ELF files and output dumps stay under `build/`.

## Regenerate from PyTorch

```sh
.venv/bin/python -m example.linear_nvfp4.model
```

This explicitly calls `nnc.compile(..., save_reference=True)` and replaces
`forward.hpp`, `init.hpp`, `input.bin`, `weight.bin` and `expected.bin` beside
the model. Keep these five versioned artifacts together. Inspect the named
Linear call in [forward.hpp](forward.hpp), bindings in [init.hpp](init.hpp),
and the minimal [main.cpp](main.cpp) that initializes and calls the model.

The source model and C++ main are maintained in public `edge-nnc` and linked
here. Its `smoke_linear_nvfp4_example.py` entry is automatically discovered by
`tests/run.sh nnc`; this saved-artifact example is also part of
`tests/run.sh examples`. Private test repositories are not required.
