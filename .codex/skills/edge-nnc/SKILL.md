---
name: edge-nnc
description: Compose, compile, validate and profile PyTorch models with NNC on public E3 RTL, or develop its compiler/runtime. Use for editable Python/PyTorch environments, module wrappers, quantization formats and API limits, model lowering, generated artifacts and numerical correctness.
---

# NNC Models and Compiler

Keep this repository's NNC path bare-metal-only and runnable with public E3 RTL.

The compiler and matched runtime are maintained in the `src/edge-nnc`
submodule. Initialize it with `git submodule update --init src/edge-nnc`.
The importable `nnc` package is installed editable from that checkout;
there is no root `nnc` symlink. `cpp/libnn/ops.hpp` forwards to NNC's
operator umbrella; edit implementations in `src/edge-nnc/cpp/libnn`.
`cpp/baremetal` contains real workspace single-core environment files, while
NNC's standalone runners retain their own environment. Keep the NNC
compiler/runtime pair pinned together. Workspace shell entry points use
`scripts/run-nnc.sh` to supply E3 SDK, Edge32 and simulator inputs. Direct
runner calls need `--edge32-include`, `--e3-include` and `--sim-exe` (unless
`--build-only`); use the shell wrappers for the public workspace defaults.

## Python environment

NNC model generation and references require PyTorch in the same Python
environment as the editable `edge-nnc` distribution. From the workspace root:

```sh
./scripts/setup-python.sh             # CPU/CUDA auto selection, Python 3.12 .venv
.venv/bin/python -c 'import torch, nnc; print(torch.__version__, nnc.__file__)'
source .venv/bin/activate             # optional; direct interpreter paths also work
```

Setup requires `uv` on PATH, runs `uv sync` with exactly one CPU/CUDA extra,
and installs NNC editable from `src/edge-nnc`. Its import path must resolve to this checkout. Source
edits take effect immediately; rerun setup after dependency metadata changes.
Do not use system Python, add a symlink, or set `PYTHONPATH` to bypass setup.

For a separate project environment, set `UV_PROJECT_ENVIRONMENT=/absolute/path`
when running setup and runners. `scripts/run-nnc.sh` defaults to that
environment, otherwise the repository `.venv`; `PYTHON=/absolute/path/bin/python`
overrides the interpreter. `PYTHON` selects an existing environment and does
not install dependencies. Do not change an unrelated active environment.
For a deliberately user-managed environment, install the chosen PyTorch build
there first using Python 3.12, then
`uv pip install --python /path/bin/python -e ./src/edge-nnc`.
Verify both imports with that exact interpreter before running models. The
runner checks installed PyTorch and editable NNC metadata against this checkout;
an environment bound to a different checkout must be reinstalled deliberately.
Use the workspace setup rather than creating a second `.venv` in the submodule.
When using an alternate environment, also use its interpreter for Python
snippets and `python -m example...` regeneration, not `.venv/bin/python`.

## Read first

- Read `README.md`, the relevant `example/linear_*/README.md`, and
  `tests/README.md` for the public model flow, artifacts and validation routes.
  Read `example/llama/README.md` when working on that composed model.
- Read `src/edge-nnc/nnc/compiler.py` and the affected module before changing export
  (`graph.py`), lowering and DRAM preferences (`lowering.py`), liveness
  (`liveness.py`), weight packing (`weights.py`), or generated headers
  (`codegen.py`).
- Read the affected implementation in `src/edge-nnc/cpp/libnn/` before changing an operator.
- Read `.codex/skills/edge-tensor-example/SKILL.md` for Tensor/DMA intrinsic
  changes and `.codex/skills/edge-verilator-demo/SKILL.md` for simulator changes.

Do not add an example-local libnn, startup, host runner, `NNEDGE_HOST` branch,
private RTL dependency, or old CMake harness. Use `cpp/libnn/`,
`cpp/baremetal/`, and `scripts/build-verilator.sh`.

## Use the public module API

For model authoring, start with `import nnc`, compose `nn.Module` wrappers
around ordinary `torch.nn.Linear` layers, and call
`nnc.compile(model.eval(), example_args, out_dir=...)`. Reuse existing NNC
modules instead of redeclaring their custom ops in each model. Function-form
ops remain available for explicit static code/scale fixtures.

Read [references/module-api.md](references/module-api.md) for the six quant
Linear presets, generation/replay commands and current custom-quantization
limits. Use the root README's composed model demo and the canonical Llama
model as working examples. The Llama graph uses `Linear`, `RMSNorm`, `RoPE`,
`KVCacheUpdate` and `Attention` modules; its public workload remains a reduced
transformer block.

Current quantized constructors accept an ordinary `torch.nn.Linear` and use
preset quantizers. A constructor accepting user-quantized Linear weights and
scales is not implemented. Present user-defined quantization strategies as
the planned direction, subject to supported op/packing contracts.

## Development workflow

For a semantic operator change:

1. Reuse the registered op where possible. For a new semantic op, implement
   registration/reference/fake behavior in the owning NNC module (`fp4.py`,
   `quant.py`, `microscale.py` or `ops.py`), and add a focused NNC smoke fixture.
   Add a reusable module wrapper in `src/edge-nnc/nnc/modules.py` or `src/edge-nnc/nnc/transformer.py`
   when the operation needs a model-authoring interface.
2. Update target mapping in `src/edge-nnc/nnc/graph.py`, lowering metadata and shape
   inference in `src/edge-nnc/nnc/lowering.py`, or weight packing in `src/edge-nnc/nnc/weights.py` only
   where needed.
3. Render its C++ call in `src/edge-nnc/nnc/codegen.py`'s `ForwardRenderer`.
4. Implement it in `src/edge-nnc/cpp/libnn/<op>.hpp` and expose it from that
   package's `ops.hpp`. Workspace examples include `cpp/libnn/ops.hpp`;
   do not add per-operator forwarding headers there.
5. Run the compiler tests and the smallest relevant public-source smoke.

```sh
./tests/run.sh nnc-unit
./scripts/run-nnc.sh smoke --model-file src/edge-nnc/nnc/test/smoke_<op>.py \
  --build-dir build/nnc-smoke
```

Set `PYTHON=/path/to/python` for the shell wrapper, or invoke
`src/edge-nnc/nnc/run_smoke.py` with that initialized interpreter directly.

## Correctness and memory rules

- Preserve PyTorch contiguous public input/output byte order. Treat packed or
  tiled accelerator buffers as operator-private layouts.
- Pack only static Linear weights in the compiler. Keep Linear input/output
  tensors contiguous.
- Pass values between operators only through `Tensor` objects. Never retain a
  `dtcm_op_scratch()` pointer as tensor storage.
- Keep the first 96 KiB of DTCM for the tensor arena and the final 32 KiB for
  synchronous operator scratch. Check worst-case byte sizes.
- Treat `free_tensor()` as LIFO-only reclamation and never use a cleared tensor.
- Do not use DMA for DTCM-to-DTCM copies. `nnedge::copy()` uses CMPU COPY mode 9
  for aligned BF16 DTCM transfers.
- Clean DRAM sources before DMA, synchronize producers before consumers, and
  clean/invalidate DRAM destinations around accelerator output DMA.
- Route payload transfers through `nnedge::copy` or existing DMA/CMPU helpers
  instead of adding manual scalar copy loops to new operators. The maintained
  DRAM-to-DRAM `copy` fallback does use scalar loads/stores with cache handling;
  this is not a universal scalar-copy ban. Scalar setup may manage metadata
  and initialize operator-owned scratch.
- Do not generalize shapes beyond layouts covered by composed Verilator tests.

## Model profiling

Profile a source model with compiler-owned per-node instrumentation. For
example, use the native MXFP4 wrapper fixture:

```sh
./scripts/run-nnc.sh smoke \
  --model-file src/edge-nnc/nnc/test/smoke_linear_mxfp4_example.py \
  --build-dir build/nnc-profile --profile --max-abs-error 0
```

For other models, use their documented comparison tolerance. The same
`--profile` option works with saved-artifact runners. Llama's maintained
`example/llama/profile.sh` is one composed-model example, not a required
entry point for unrelated models.

The compiler measures immediately around each
lowered operator call, completes the final output copy, and prints all records
afterward. Do not add temporary cycle reads or printf calls inside operators
for node-level reports.

Require all of these results:

- public E3 Verilator exits with `TEST PASS`;
- all output BF16 values match the PyTorch golden within the runner tolerance;
- `profile.md` and `profile.tsv` exist beside the ELF;
- `software-console.log` retains the raw profile records.

Interpret each percentage as a share of the sum of measured operator calls,
not total simulation cycles. Allocation, input/final copies, startup, and
printing are excluded. Preserve node indices and names so repeated operations
remain distinguishable.

## Validation

For model-only changes, run unit discovery and the affected source fixture;
for saved examples, also regenerate/replay the corresponding artifact set.
After compiler or runtime changes, run the full public NNC route:

```sh
./tests/run.sh nnc
```

This includes unit discovery, every `src/edge-nnc/nnc/test/smoke_*.py` fixture,
the Llama profiling case, and packed C++ regressions. Keep
`src/edge-nnc/nnc/test/llama3_source.py` byte-identical to its canonical example.
Require `harness.md` and packed summaries to report all cases PASS; do not
maintain a silent skip list. Add affected workspace examples, and interface
checks when the runtime/intrinsic boundary changes; see `tests/README.md`.

The flat Llama example versions generated `forward.hpp` and `init.hpp` beside
`model.py` and `main.cpp`; its runner regenerates them using `--generated-dir`.
Local `.bin` files are ignored. ELF files, logs and profiles belong under
`example/llama/build/`; shared-harness outputs remain under
`src/edge-nnc/example/llama/build/`. The six small quant Linear examples also
version their input/weight/expected `.bin` snapshots for replay without
re-exporting the model or importing PyTorch. The prepared environment still
contains PyTorch and editable NNC, as required by the runner's metadata check.
Their models and minimal mains belong to NNC, with workspace symlinks;
saved artifacts, documentation and run adapters belong to the workspace.
Keep each header/binary artifact set consistent with the pinned runtime.
