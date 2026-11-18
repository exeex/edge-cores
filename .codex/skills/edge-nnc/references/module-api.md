# Public NNC module and artifact workflow

Run commands from the edge-cores workspace root. Both generation and replay
use its prepared Python environment with PyTorch and editable `edge-nnc`.
Saved-artifact replay does not import/evaluate PyTorch, but the shell runner
still requires installed PyTorch and editable NNC distribution metadata.
LLVM and the public RTL simulator are supplied by the workspace.

Run `./scripts/setup-python.sh` first. It installs PyTorch plus editable NNC
from `src/edge-nnc` into Python 3.12 `.venv`. Run Python snippets with
`.venv/bin/python`, or activate that environment. `import nnc` works outside
the repository too; no `PYTHONPATH` or root symlink is needed. Shell adapters
default to the project interpreter and accept `PYTHON` overrides; use
`UV_PROJECT_ENVIRONMENT` consistently for an alternate setup environment.

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
NNC quantizes static weights at compile time. Logical activations and outputs
are BF16, but external payloads may use compiler-planned tiled storage rather
than logical contiguous order. Follow `io_layout.json` for physical I/O. K must
be a positive multiple of the group size and N
a positive multiple of 8. Optional bias is a separate BF16 add.

The same public API compiles composed graphs. Read the [root README](../../../../README.md)
for a two-layer quantized MLP, and [Llama model](../../../../example/llama/model.py) for the reduced Llama
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

The outputs are `forward.hpp`, `init.hpp`, `input.bin`, `weight.bin` and
`io_layout.json`, plus `expected.bin` with `save_reference=True`.
`nnc.compile` returns the output directory as a `Path`. It evaluates the
provided model for the saved reference, converts the result to BF16 and writes
it in the planned physical output order. For quantized wrappers that reference
uses their quantized operator semantics, not the original full-precision layer.
The saved-reference API currently accepts one Tensor output, or a singleton
tuple containing one Tensor. It does not build an ELF or run RTL itself;
the workspace runner performs those steps.

The public [compile API](../../../../src/edge-nnc/nnc/__init__.py) also accepts
`quant_token_capacity=None` and `matmul_token_capacity=None`; supplied values
must be positive and select runtime template capacities for applicable calls.
They do not establish support for arbitrary shapes or SRAM footprints. Check
the [code generator](../../../../src/edge-nnc/nnc/codegen.py), matched runtime
and relevant composed tests before choosing new values. Omit them to keep the
current default behavior.

`io_layout.json` records logical shapes, per-input/output layouts and lane
count. The [compiler](../../../../src/edge-nnc/nnc/compiler.py) reorders tiled
inputs and saved outputs consistently. Preserve logical values when decoding
or migrating payloads; changing metadata alone does not convert old binaries.

```sh
./scripts/run-nnc.sh smoke \
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
`.venv/bin/python -m example.linear_mxfp4.model` (substitute the spec and use
the selected environment's interpreter if it differs from `.venv`).
Preserve both headers, all payload/reference binaries and `io_layout.json`
together with the compiler/runtime revision. Check both regenerated
execution and saved replay when a quantization or scale encoding changes.

For source-model tests use `scripts/run-nnc.sh smoke --model-file <file.py>`;
the source exposes `make_model_and_args()`. This route generates fresh
artifacts. NNC owns canonical model/main sources and `src/edge-nnc/nnc/test/smoke_*.py`
fixtures; workspace examples link to them and own saved artifact sets/runners.
`tests/run.sh nnc` discovers the source fixtures; `tests/run.sh examples`
independently checks saved examples.

The [smoke runner](../../../../src/edge-nnc/nnc/run_smoke.py) checks headers and
input/weight binaries when replaying, and requires `expected.bin` for execution.
It currently does not require `io_layout.json` in that file-presence check;
successful preflight alone therefore does not prove artifact layout provenance
or compatibility. Retain the metadata even when the runner would accept its
absence. `--build-only` compiles an ELF without RTL execution or numerical
validation. For an executed replay require simulator `TEST PASS` and numerical
`COMPARE PASS`; its default absolute tolerance is `0.05`, so use the explicit
zero tolerance above for the unbiased native fixture.

## API and numerical boundaries

- Transformer wrappers retain the reduced ops' current behavior:
  `KVCacheUpdate` is a prefill pass-through, and `Attention` is unscaled and
  unmasked. These wrappers do not establish stateful decoding-cache support.
- Quantized Linear constructors accept ordinary `torch.nn.Linear` and select built-in presets.
  A constructor accepting an already user-quantized Linear is not implemented.
- User-defined quantization strategies are not exposed as a general wrapper
  constructor API. Function-form ops already
  accept explicit static codes/scales for supported formats; this is not a
  complete generic quantized Linear construction API.
- MXFP4 and NVFP4 are weight-only flows. NVFP4's global scalar is RNE-rounded
  to BF16 in an FP32 container; no full-FP32 global precision claim.
- Q8_0 retains native FP16 scale bits and INT8 codes in E3 tile order; there
  is no GGUF importer or llama.cpp GEMM bit-identity guarantee.
- Consult [MICROSCALE_LINEAR.md](../../../../src/edge-nnc/MICROSCALE_LINEAR.md)
  and [QUANT_LINEAR.md](../../../../src/edge-nnc/QUANT_LINEAR.md) before
  changing scales, packing or numerical reference behavior. Use zero
  tolerance for the unbiased native examples and BF22 precision fixtures;
  retain documented tolerances for biased/composed models.
- For custom scalar producers/consumers follow
  [MEMORY_OWNERSHIP.md](../../../../src/edge-nnc/MEMORY_OWNERSHIP.md): publish
  CPU-written DRAM payloads before DMA and acquire completed outputs before
  scalar reads. Layout correctness and cache visibility are separate contracts.
