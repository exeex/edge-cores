---
name: llama-nnc
description: Develop and profile the edge-e3 PyTorch-to-NNC flow, including nnc/compiler.py lowering and generated ABI, example/llama smoke models, cpp/libnn runtime operators, BF16 correctness checks, and per-node cycle reports on the encrypted Verilator core.
---

# Llama NNC

Keep this repository's NNC path bare-metal-only and runnable with the public
encrypted core.

## Read first

- Read `example/llama/README.md` for the user-facing flow and artifact locations.
- Read `nnc/compiler.py` before changing export, lowering, ABI, liveness, DRAM
  preferences, or weight packing.
- Read the affected header in `cpp/libnn/` before changing an operator.
- Read `.codex/skills/edge-tensor-example/SKILL.md` for Tensor/DMA intrinsic
  changes and `.codex/skills/edge-verilator-demo/SKILL.md` for simulator changes.

Do not add an example-local libnn, startup, host runner, `NNEDGE_HOST` branch,
private RTL dependency, or old CMake harness. Use `cpp/libnn/`,
`cpp/baremetal/`, and `scripts/build-verilator.sh`.

## Development workflow

For a semantic operator change:

1. Define or update its PyTorch custom op in `nnc/test/smoke_<op>.py`.
2. Update target mapping, lowering metadata, shape inference, or weight packing
   in `nnc/compiler.py` only where needed.
3. Render its C++ call in `ForwardRenderer`.
4. Implement it in `cpp/libnn/<op>.hpp` and expose it from `cpp/libnn/ops.hpp`.
5. Run the compiler tests and the smallest relevant encrypted-core smoke.

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

Run `example/llama/model/llama3_source.py` directly as the complete tiny Llama
transformer block with compiler-owned per-node instrumentation:

```sh
./example/llama/profile.sh
```

The compiler measures immediately around each
lowered operator call, completes the final output copy, and prints all records
afterward. Do not add temporary cycle reads or printf calls inside operators
for node-level reports.

Require all of these results:

- encrypted Verilator exits with `TEST PASS`;
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
`example/llama/model/llama3_source.py`. Require `harness.md` to report every row
as PASS; do not maintain a silent skip list.

Generated files belong under `example/llama/build/` and must remain untracked.
