---
name: edge-bringup
description: Prepare a macOS or Ubuntu machine for edge-e3 development, diagnose missing Verilator/LLVM/Python dependencies, initialize the public repository, and answer or act on the example prompts in the root README. Use for first-time setup, onboarding, deciding which maintained workflow to run, RTL smoke tests, Edge-vs-C906 benchmarks, Hugging Face model questions, Q4_K_M requests, and questions about where to start adding a feature.
---

# Edge bring-up

Start by reading the root `README.md`. Run `scripts/check-env.sh` from this skill
to inspect the host without changing it. Install dependencies only when the user
asks for installation or setup.

## Prepare the environment

For macOS with Homebrew:

```sh
brew install verilator llvm lld python cmake
```

The maintained scripts default to Homebrew LLVM paths under
`/opt/homebrew/opt/llvm` and `/opt/homebrew/opt/lld`. On Intel macOS, or when
Homebrew uses another prefix, export `LLVM_PREFIX="$(brew --prefix llvm)"` and
`LLD_PREFIX="$(brew --prefix lld)"`.

For Ubuntu:

```sh
sudo apt-get update
sudo apt-get install -y build-essential git cmake verilator llvm clang lld python3 python3-pip python3-venv
```

Ubuntu LLVM paths differ from the script defaults. Resolve `clang`,
`llvm-objdump`, and `ld.lld`, then pass `LLVM_PREFIX` and `LLD_PREFIX` where the
entry point supports them. Prefer fixing the maintained scripts to discover
system tools when doing a durable Linux bring-up; do not create local symlinks
inside the repository.

Initialize only required public submodules:

```sh
git submodule update --init src/edge-e3enc third_party/coremark third_party/openc906
python3 -m pip install -r nnc/requirements.txt
```

Keep `src/edge-e3` deinitialized for the public flow. Never initialize or use a
private/non-public checkout merely to make a public test pass.

## Route README questions

Read `references/readme-example-answers.md` whenever the request matches one of
the root README example prompts. Give the direct answer there before running a
long build. Then use the maintained specialist skill:

- RTL smoke or public simulator: `edge-verilator-demo` and `software-harness`.
- Edge versus C906 benchmark: `edge-tensor-example` CoreMark comparison flow.
- Supported PyTorch/NNC model smoke: `llama-nnc` and `software-harness`.
- Tensor or NNC feature implementation requiring editable RTL: explain the
  public-source availability boundary from the reference instead of attempting
  encrypted RTL edits.

Do not imply that an arbitrary Hugging Face checkpoint is already accepted by
the NNC compiler. Distinguish the available small PyTorch-export smoke flow from
a future full-model import and quantized-weight pipeline.

## Verify bring-up

Use the smallest relevant sequence:

```sh
./scripts/build-verilator.sh
./example/hello/run.sh
./example/tensor/run.sh
```

For Python/NNC work, additionally run:

```sh
python3 -m unittest nnc.test_compiler
./example/llama/run.sh
```

Require the generated report to contain `TEST PASS`. Keep all generated ELF,
memory images, logs, and reports under ignored build directories.
