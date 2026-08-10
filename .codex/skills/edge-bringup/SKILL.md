---
name: edge-bringup
description: Prepare a macOS or Ubuntu machine for edge-e3 development, diagnose missing Verilator/LLVM/Python dependencies, initialize the public repository, and answer or act on the example prompts in the root README. Use for first-time setup, onboarding, deciding which maintained workflow to run, RTL smoke tests, Edge-vs-C906 benchmarks, Hugging Face model questions, Q4_K_M requests, and questions about where to start adding a feature.
---

# Edge bring-up

Start by reading the root `README.md`. Run `scripts/check-env.sh` from this skill
to inspect the host without changing it. Install dependencies only when the user
asks for installation or setup.

## Prepare the environment

Do not add a uv-managed Python installation directly to the user's global
`PATH`. The repository owns its Python environment through `.venv`,
`pyproject.toml`, and `uv.lock`. Run Python entry points with
`.venv/bin/python`, set `PYTHON=.venv/bin/python` for maintained shell wrappers,
or activate `.venv` explicitly.

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

Install uv using its maintained installation instructions when `uv` is absent:
<https://docs.astral.sh/uv/getting-started/installation/>. The environment
checker and public build scripts recognize both unversioned LLVM tools and
Ubuntu names such as `llvm-objdump-19`, `llvm-objcopy-19`, and `ld.lld-19`.
Environment variables such as `CLANG`, `CLANGXX`, `LLVM_OBJCOPY`,
`LLVM_OBJDUMP`, and `LLD` remain explicit overrides.

Initialize only required public submodules:

```sh
git submodule update --init \
  src/edge-e3enc src/edge-rv third_party/coremark third_party/openc906
./scripts/setup-python.sh
```

Keep `src/edge-e3` deinitialized for the public flow. Never initialize or use a
private/non-public checkout merely to make a public test pass.

`scripts/setup-python.sh` selects one mutually exclusive PyTorch extra from
`pyproject.toml` and runs `uv sync`:

- If `nvidia-smi` is absent, cannot query a GPU, or cannot report a supported
  CUDA driver level, select `cpu`.
- Select `cu126` for a reported CUDA capability from 12.6 through 12.x,
  `cu130` for 13.0–13.1, and `cu132` for 13.2 or newer.
- After installation, require the CPU build to report no CUDA runtime, or the
  selected CUDA build to pass `torch.cuda.is_available()` and name its GPU.

For deterministic diagnosis or CI, override auto-detection explicitly:

```sh
./scripts/setup-python.sh cpu
./scripts/setup-python.sh cu126
./scripts/setup-python.sh cu130
./scripts/setup-python.sh cu132
```

The `nvidia-smi` CUDA value is the newest runtime supported by the installed
driver, not a requirement to install a matching system CUDA toolkit. The
PyTorch wheel supplies its runtime; `nvcc` is only needed for compiling custom
CUDA extensions.

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

Use this bring-up sequence:

```sh
git submodule status src/edge-e3
./.codex/skills/edge-bringup/scripts/check-env.sh
./scripts/build-verilator.sh
PYTHON=.venv/bin/python ./example/hello/run.sh
PYTHON=.venv/bin/python ./example/tensor/run.sh
```

For Python/NNC work, additionally run:

```sh
.venv/bin/python -m unittest nnc.test_compiler
PYTHON=.venv/bin/python ./example/llama/run.sh
```

Bring-up is successful when the private `src/edge-e3` status begins with `-`,
the environment checker passes, the simulator builds, hello and tensor report
`TEST PASS`, compiler unit tests pass, and the single Llama smoke reports both
`TEST PASS` and `COMPARE PASS`. Keep all generated ELF, memory images, logs, and
reports under ignored build directories.

The complete `PYTHON=.venv/bin/python ./example/llama/test.sh` suite is a wider
semantic regression, not the initial bring-up gate. Run it when changing NNC or
libnn behavior and report every failing case for follow-up; do not hide failures
or weaken their comparisons merely to declare the host environment operational.
