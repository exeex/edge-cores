# Public NNC module and artifact workflow

Run commands from the edge-cores workspace root. Model authoring and explicit
regeneration require its PyTorch environment; saved-artifact replay requires
Python, LLVM and the public RTL simulator, without importing PyTorch.

## Choose a module

Import `nnc` and wrap an ordinary `torch.nn.Linear`, for example
`nnc.LinearMxFp4(torch.nn.Linear(64, 16, bias=False))`. Compose wrappers with
other supported PyTorch/NNC modules inside a normal `nn.Module`.

| Wrapper | Weights | K group | Scale encoding |
| --- | --- | ---: | --- |
| `nnc.LinearFp4` | E2M1 | 32 | BF16 |
| `nnc.LinearMxFp4` | E2M1 | 32 | E8M0 byte |
| `nnc.LinearNvFp4` | E2M1 | 16 | E4M3FN byte plus BF16-rounded per-tensor global |
| `nnc.LinearQ8_0` | signed INT8 | 32 | native FP16 |
| `nnc.LinearFp8E4M3FN` | E4M3FN | 32 | BF16 |
| `nnc.LinearFp8E5M2` | E5M2 | 32 | BF16 |

Quantized modules copy frozen BF16 inference parameters from the source layer;
NNC quantizes static weights at compile time. Public activations and output
are contiguous BF16. K must be a positive multiple of the group size and N
a positive multiple of 8. Optional bias is a separate BF16 add.

The same public API compiles composed graphs. Read the root README for a
two-layer quantized MLP, and `example/llama/model.py` for the reduced Llama
graph using `nnc.Linear`, `RMSNorm`, `RoPE`, `KVCacheUpdate` and `Attention`.
Do not equate compiling this graph with importing a full pretrained checkpoint.

With the current codegen, use named layer attributes or
`nn.Sequential(OrderedDict(...))` for composed examples. An unnamed top-level
`nn.Sequential` can emit invalid C++ members such as `0_weight_mxfp4_slots`.

## Compile and replay

For example, compile the maintained MXFP4 model into an isolated directory:

```python
import nnc
from example.linear_mxfp4.model import make_model_and_args

model, example_args = make_model_and_args()
nnc.compile(model.eval(), example_args, out_dir="build/nnc-model", save_reference=True)
```

The outputs are `forward.hpp`, `init.hpp`, `input.bin`, `weight.bin` and,
with `save_reference=True`, the quantized reference `expected.bin`.

```sh
PYTHON=.venv/bin/python ./scripts/run-nnc.sh smoke \
  --artifacts-dir build/nnc-model \
  --main-file src/edge-nnc/example/linear_mxfp4/main.cpp \
  --build-dir build/nnc-model/run --max-abs-error 0
```

The canonical minimal main above has no adjacent saved headers, so its
`#include "forward.hpp"` resolves to the supplied artifact directory. When
compiling a different generated model, avoid a main beside another example's
saved headers: quoted includes search that directory before `-I` paths.

The six workspace `example/linear_*` runners replay their saved artifacts.
Regenerate a specific example explicitly with
`.venv/bin/python -m example.linear_mxfp4.model` (substitute the spec).
Preserve the two headers and three binaries together. Check both regenerated
execution and saved replay when a quantization or scale encoding changes.

For source-model tests use `scripts/run-nnc.sh smoke --model-file <file.py>`;
the source exposes `make_model_and_args()`. This route generates fresh
artifacts. NNC owns canonical model/main sources and `nnc/test/smoke_*.py`
fixtures; workspace examples link to them and own saved artifact sets/runners.
`tests/run.sh nnc` discovers the source fixtures; `tests/run.sh examples`
independently checks saved examples.

## API and numerical boundaries

- Constructors accept ordinary `torch.nn.Linear` and select built-in presets.
  A constructor accepting an already user-quantized Linear is not implemented.
- User-defined quantization strategies are planned, constrained by supported
  op encodings, shapes and packing contracts. Function-form ops already
  accept explicit static codes/scales for supported formats; this is not a
  complete generic quantized Linear construction API.
- MXFP4 and NVFP4 are weight-only flows. NVFP4's global scalar is RNE-rounded
  to BF16 in an FP32 container; no full-FP32 global precision claim.
- Q8_0 retains native FP16 scale bits and INT8 codes in E3 tile order; there
  is no GGUF importer or llama.cpp GEMM bit-identity guarantee.
- Consult `src/edge-nnc/MICROSCALE_LINEAR.md` and `QUANT_LINEAR.md` before
  changing scales, packing or numerical reference behavior. Use zero
  tolerance for the unbiased native examples and BF22 precision fixtures;
  retain documented tolerances for biased/composed models.
