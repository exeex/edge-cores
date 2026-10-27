---
name: llama-nnc
description: Compose and compile PyTorch models with NNC modules and nnc.compile(), run quantized Linear and Llama examples on public E3 RTL, or develop and profile the NNC compiler/runtime. Use for module wrappers, quantization API questions, model lowering and BF16 correctness.
---

# NNC Models and Compiler

Keep this repository's NNC path bare-metal-only and runnable with public E3 RTL.

The compiler and matched runtime are maintained in the `src/edge-nnc`
submodule. Initialize it with `git submodule update --init src/edge-nnc`.
`nnc` is a compatibility symlink. `cpp/libnn/ops.hpp` forwards to NNC's
operator umbrella; edit implementations in `src/edge-nnc/cpp/libnn`.
`cpp/baremetal` contains real workspace single-core environment files, while
NNC's standalone runners retain their own environment. Keep the NNC
compiler/runtime pair pinned together. Workspace shell entry points use
`scripts/run-nnc.sh` to supply E3 SDK, Edge32 and simulator inputs. Direct
runner calls need `--edge32-include`, `--e3-include` and `--sim-exe` (unless
`--build-only`); use the shell wrappers for the public workspace defaults.

## Read first

- Read `example/llama/README.md` for the user-facing flow and artifact locations.
- Read `nnc/compiler.py` and the affected module before changing export
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
   Add a reusable module wrapper in `nnc/modules.py` or `nnc/transformer.py`
   when the operation needs a model-authoring interface.
2. Update target mapping in `nnc/graph.py`, lowering metadata and shape
   inference in `nnc/lowering.py`, or weight packing in `nnc/weights.py` only
   where needed.
3. Render its C++ call in `nnc/codegen.py`'s `ForwardRenderer`.
4. Implement it in `src/edge-nnc/cpp/libnn/<op>.hpp` and expose it from that
   package's `ops.hpp`. Workspace examples include `cpp/libnn/ops.hpp`;
   do not add per-operator forwarding headers there.
5. Run the compiler tests and the smallest relevant public-source smoke.

```sh
python3 -m unittest nnc.test_compiler
./example/llama/run.sh --model-file nnc/test/smoke_<op>.py
```

Set `PYTHON=/path/to/python` for the shell wrapper, or invoke
`nnc/run_smoke.py` with that interpreter directly. Install dependencies from
`nnc/requirements.txt`.

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
- Do not move tensor payloads with scalar loads/stores. Scalar code may manage
  metadata and initialize operator-owned scratch only.
- Do not generalize shapes beyond layouts covered by composed Verilator tests.

## Transformer-block profiling smoke

Run `example/llama/model.py` directly as the complete tiny Llama
transformer block with compiler-owned per-node instrumentation:

```sh
./example/llama/profile.sh
```

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

After compiler or runtime changes, run:

```sh
python3 -m unittest nnc.test_compiler
./example/llama/run.sh
./example/llama/test.sh
```

The suite must cover every `nnc/test/smoke_*.py` file and finish by profiling
`nnc/test/llama3_source.py`. Keep that file byte-identical to the user-facing
`example/llama/model.py`. Require `harness.md` to report every row
as PASS; do not maintain a silent skip list.

The flat Llama example versions generated `forward.hpp` and `init.hpp` beside
`model.py` and `main.cpp`; its runner regenerates them using `--generated-dir`.
Local `.bin` files are ignored. ELF files, logs and profiles belong under
`example/llama/build/`; shared-harness outputs remain under
`src/edge-nnc/example/llama/build/`. The six small quant Linear examples also
version their input/weight/expected `.bin` snapshots for Torch-free replay.
Their models and minimal mains belong to NNC, with workspace symlinks;
saved artifacts, documentation and run adapters belong to the workspace.
Keep each header/binary artifact set consistent with the pinned runtime.
