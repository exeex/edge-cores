# Llama NNC example

This example exports the tiny Llama 3 transformer block in
`model/llama3_source.py`, lowers it through `nnc/compiler.py`,
links the generated weights and example inputs into a bare-metal RISC-V image, and checks the
`edge-e3` Verilator output against PyTorch.

```sh
git submodule update --init src/edge-e3 src/edge-asic src/edge-32 src/edge-nnc
./scripts/setup-python.sh
PYTHON=.venv/bin/python ./example/llama/run.sh
```

Pass another model with `--model-file`, or generate and build without running
the simulator with `./example/llama/build.sh`. Compiler regression models live
under `nnc/test/`; this example intentionally contains only the user-facing
Llama source model.

The compiler and matched C++ runtime live in the `src/edge-nnc` submodule.
The root `nnc` and `cpp/libnn` paths are compatibility symlinks. The shell
entry points use `scripts/run-nnc.sh` to provide this workspace's Edge32
include directory, simulator executable, and simulator build script.
Pass `--skip-verilator-build` to reuse an existing simulator for a single model.

The n906-aligned compiler/runtime and public E3 RTL support the FP4/WSLD
fixtures. See `src/edge-nnc/FP4_LINEAR.md` for their hardware contract.
Private hardware regression repositories are not required by this example.

The repository setup selects CPU or a compatible NVIDIA CUDA PyTorch build and
syncs the locked `.venv`. Set `PYTHON=/path/to/python` only when intentionally
using another virtual environment.

Profile every lowered node in the complete tiny Llama transformer block:

```sh
./example/llama/profile.sh
```

The profiling smoke compiles `model/llama3_source.py` directly, checks its BF16
result against PyTorch, and writes
`profile.md`, `profile.tsv`, and `software-console.log` below
`example/llama/build/llama3_source/`.

Run every `nnc/test/smoke_*.py` case and the copied `llama3_source.py`
profiling case:

```sh
./example/llama/test.sh
```

The suite writes its summary to
`src/edge-nnc/example/llama/build/harness/harness.md` and
keeps one log per model in the same directory. Suite model binaries and the
Llama profile are generated under `src/edge-nnc/example/llama/build/`; single
model commands retain `example/llama/build/<model>/`.

Generated headers, weights, binaries, and logs are written below the build
directories above and are ignored by Git.

The compiler is split by responsibility: `nnc/graph.py` reads the PyTorch
export and forward ABI, `nnc/lowering.py` maps graph operations to kernels,
`nnc/weights.py` packs static data, `nnc/liveness.py` finds temporary tensor
last uses, and `nnc/codegen.py` renders the C++ headers. `nnc/compiler.py`
provides the command-line entry point and writes the artifacts.

The generated `weight.bin` and `input.bin` are linked into `.nnedge_weights`
and `.nnedge_inputs`. `init.hpp` binds tensors using each section's start
address plus the compiler's offset. Output storage lives in the ELF's
`.nnedge_outputs` section at the runner's `--output-base` address (default
`0x100000`).
