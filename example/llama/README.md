# Llama 3 NNC example

[model.py](model.py) contains a tiny Llama 3 transformer block composed from
reusable NNC modules. The example directory is flat:

```text
model.py       PyTorch model and explicit nnc.compile(...) entry
main.cpp       initialize and call the generated forward function
forward.hpp    generated C++ operator calls, tracked in Git
init.hpp       generated tensor bindings, tracked in Git
input.bin      local generated input, ignored
weight.bin     local generated weights, ignored
run.sh         generate, build, simulate and compare with PyTorch
build/         ELF, simulator logs and profiling reports, ignored
```

The canonical model and minimal main live in edge-nnc and are linked here.
The former `model/llama3_source.py` and `src/smoke_main.cpp` paths remain
available for compatibility. The NNC smoke suite links to the same model.

## Model modules

The model imports `Linear`, `RMSNorm`, `RoPE`, `KVCacheUpdate`, and `Attention`
from `nnc`. Their implementations live in `nnc/transformer.py`, with custom-op
registration and fake implementations in `nnc/ops.py`.

```python
from nnc import Linear, RMSNorm, RoPE, KVCacheUpdate, Attention

projection = Linear(torch.nn.Linear(64, 64, bias=False))
normalization = RMSNorm(64, eps=1e-5)
rope = RoPE()
cache = KVCacheUpdate()
attention = Attention(head_count=2)
```

`Model.forward()` composes modules instead of declaring or invoking custom
ops directly. Export still sees `nnedge::linear`, `rms_norm`, `rope`,
`kv_cache_update`, and `attention`. Fake implementations infer metadata only.
The runtime consumes BF16 payloads; the original PyTorch fixture's parameter
values, reference output and lowered operator sequence are preserved.
The current attention op is unscaled/unmasked and KV update is a prefill
pass-through, as in the original reduced model.

## Generate and run

```sh
./scripts/setup-python.sh
.venv/bin/python -m example.llama.model
PYTHON=.venv/bin/python ./example/llama/run.sh
```

The model's visible entry point is:

```python
if __name__ == "__main__":
    m = make_tiny_llama_block().eval()
    nnc.compile(m, make_example_args(), out_dir=Path(__file__).parent)
```

Unlike the six small quant Linear examples, this Llama example does not
version `.bin` files. Its runner regenerates headers and payloads from the
model on every run, builds them, and compares all 2048 output values with the
PyTorch golden. This requires the repository PyTorch environment, LLVM and
the initialized public E3, Edge32, ASIC and NNC submodules. Hardware comparison
uses the existing normal-range BF16 tolerance; the model is one reduced block.

```sh
./example/llama/build.sh                         # generate and build only
PYTHON=.venv/bin/python ./example/llama/profile.sh
```

The generated headers stay beside `main.cpp` for review. Binaries remain
local and ignored. The ELF, `software-console.log`, output dump, and
`profile.md` / `profile.tsv` live in `example/llama/build/`. Profile shares are
shares of summed operator-call cycles, excluding allocation and final copying.
Pass `--skip-verilator-build` after building the current RTL to reuse the
simulator.

Other source models remain supported through the general smoke adapter:

```sh
PYTHON=.venv/bin/python ./example/llama/run.sh --model-file nnc/test/smoke_silu.py
PYTHON=.venv/bin/python ./example/llama/run.sh --model-file nnc/test/qwen36_source.py
```

Those calls use isolated `example/llama/build/<model-name>/generated/`
artifacts and the generic NNC main, so they do not replace the Llama headers.

## Regression

```sh
PYTHON=.venv/bin/python ./tests/run.sh nnc
```

NNC owns Python tests, all `nnc/test/smoke_*.py` models, Llama profiling and the
low-level packed-weight C++ test sources. The workspace supplies the public
SDK, simulator, startup and test adapters. Suite reports remain under
`src/edge-nnc/example/llama/build/harness/`, with the suite's Llama profile in
`src/edge-nnc/example/llama/build/llama3_source/`. See [test routing](../../tests/README.md).
