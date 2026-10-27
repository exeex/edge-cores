# edge-cores

**The shortest way from PyTorch to ASICs.**

Export PyTorch models to bare-metal C++ and run them on ASIC RTL with Verilator.
Bring your own accelerator to the open-source `edge-32` control processor, or
start with the source-available `edge-e3` reference NPU.

The flow uses the standard **Clang/LLVM toolchain**--installed with
`apt-get install` on Ubuntu--instead of a custom compiler or patched LLVM/MLIR
stack. Rather than adding an ASIC backend to the compiler, each ASIC exposes
its operations through a C++ intrinsics header such as
[`edge_intrinsic.hpp`](src/edge-e3/include/edge_e3/edge_intrinsic.hpp).

Document that interface in an
[`intrinsic manual`](src/edge-e3/include/README.md) and capture the kernel workflow in
a [`SKILL.md`](.codex/skills/edge-tensor-example/SKILL.md). GPT-5.5 and GPT-5.6
coding agents can then create hardware-aware kernels with the same ordinary
`clang++` toolchain on any ASIC platform. This removes custom compiler bring-up
from the critical path and makes zero-day support for newly released Hugging
Face models practical.

The simpler toolchain does not come at the expense of accelerator utilization.
The maintained [`example/tensor`](example/tensor/README.md) reaches **94.84%
effective MAC utilization** on a 64x64x128 BF16 matmul, including packed weight
DMA, circular weight loads, Tensor execution, and synchronization.

See the [v0.3 release note](docs/releases/v0.3.md) for the SRAM scheduling,
BF22 partial-sum, native MXFP4/NVFP4 and PyTorch module API updates. Run the
named quantized Linear examples:
[FP4](example/linear_fp4/README.md),
[MXFP4](example/linear_mxfp4/README.md),
[NVFP4](example/linear_nvfp4/README.md),
[Q8_0](example/linear_q8_0/README.md),
[FP8 E4M3FN](example/linear_fp8_e4m3fn/README.md), and
[FP8 E5M2](example/linear_fp8_e5m2/README.md).
Each includes its PyTorch/NNC source model and generates the C++ and packed
weights through NNC.

## Run Llama 3 and Qwen 3.6 on edge-e3 ASIC RTL

The current public flow demonstrates a **single Llama 3 transformer block** and
a **reduced single Qwen 3.6 full-attention decoder layer** running on the
`edge-e3` ASIC RTL through Verilator. The simulator builds the public E3, Edge32 and shared ASIC RTL directly,
with local public SRAM behavioral models. The
8x8 BF16 Tensor ASIC has 128 KB of DTCM. This MVP demonstrates the complete
PyTorch-to-ASIC path with compact single-layer workloads.

Both examples start as small PyTorch modules, compile to bare-metal C++,
execute on the RTL, and compare their BF16 outputs with PyTorch.

The Qwen 3.6 path also demonstrates the zero-day workflow. After Llama 3 was
supported, a follow-up agent prompt added the reduced Qwen 3.6 path in about
five minutes without changing the existing C++ kernels. This is an MVP result,
not a general five-minute guarantee; a new model requiring additional
adaptation is expected to take closer to half an hour rather than days of
compiler development.

First follow the
[`edge-bringup`](.codex/skills/edge-bringup/SKILL.md) workflow. It installs the
required public submodules and creates the repository-owned `.venv` used by the
commands below.

E3 RTL and the shared ASIC RTL are public in `src/edge-e3` and
`src/edge-asic`; Edge32 is public in `src/edge-32`. Private repositories mainly
contain internal tests such as `src/test-e3`. They are optional: the public
build and examples do not require them. Public documentation and examples
remain in this repository.

NNC is pinned as the `src/edge-nnc` Git submodule, matching the compiler and
C++ runtime used by n906. Initialize it before running the examples:

```sh
git submodule update --init src/edge-e3 src/edge-asic src/edge-32 src/edge-nnc
```

`nnc` is a compatibility symlink into that submodule. The outer `cpp/` is
the public examples' C++ entry point: `cpp/libnn/ops.hpp` and
`cpp/intrinsic/edge_intrinsic.hpp` forward to the NNC and E3 umbrella headers.
The memory map, startup and linker settings remain workspace-owned.
There are no symlinks under `cpp/`; see [C++ ownership](cpp/README.md).
The workspace supplies the E3 SDK, Edge32 backend and public-source Verilator harness;
`scripts/run-nnc.sh` connects these inputs to the shared runner.

Regression ownership and commands are listed in [tests/README.md](tests/README.md):
`tests/run.sh nnc` delegates to NNC's tests, `tests/run.sh interface` checks
standalone `matmul.hpp` against the workspace hardware, and
`tests/run.sh examples` validates the runnable examples separately.
Use `PYTHON=.venv/bin/python ./tests/run.sh all` for the complete public suite.

Run the Llama 3 block:

```sh
PYTHON=.venv/bin/python ./example/llama/run.sh
```

The flat [Llama example](example/llama/README.md) contains `model.py`,
`main.cpp`, and tracked generated `forward.hpp` / `init.hpp`. The model imports
reusable NNC modules for its custom ops and calls `nnc.compile()` explicitly.
Llama binary payloads are regenerated locally and ignored by Git.

Run the Qwen 3.6 layer:

```sh
PYTHON=.venv/bin/python ./example/llama/run.sh \
  --model-file nnc/test/qwen36_source.py
```

The Qwen example is a 32-token, 64-wide, one-head compatibility slice. It
preserves Q/K RMSNorm, the attention-output gate, SwiGLU MLP, and residual
structure. See [`qwen36_coverage.md`](nnc/test/qwen36_coverage.md) for the
current MVP coverage and next implementation steps.

## PyTorch to ASIC RTL with NNC

Import `nnc`, compose ordinary PyTorch modules with NNC modules, and call
`nnc.compile()` to generate bare-metal C++ and packed weights. The module API
wraps the existing function-form ops, so model code can use familiar
`nn.Module` composition without declaring custom ops itself.

### 1. Compose and compile a model

Run this Python example from the workspace root using `.venv/bin/python`:

```python
import torch
import torch.nn as nn
import nnc


class QuantMLP(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nnc.LinearFp4(nn.Linear(64, 64, bias=False))
        self.act = nn.SiLU()
        self.fc2 = nnc.LinearNvFp4(nn.Linear(64, 16, bias=False))

    def forward(self, x):
        return self.fc2(self.act(self.fc1(x)))


torch.manual_seed(0)
model = QuantMLP().eval()
x = ((torch.arange(9 * 64).reshape(9, 64) % 13 - 6).float() / 16).to(torch.bfloat16)
nnc.compile(model, (x,), out_dir="build/nnc-demo", save_reference=True)
```

The wrappers copy the original Linear weights into frozen BF16 inference
parameters. NNC exports the composed graph, quantizes its static weights
with the selected presets, and emits the corresponding runtime calls.
`save_reference=True` also saves the quantized PyTorch model's BF16 output
for simulator comparison.

The available quantized Linear modules are:

| Module | Weight format and scales |
| --- | --- |
| `nnc.LinearFp4` | E2M1, K32 BF16 scales |
| `nnc.LinearMxFp4` | E2M1, K32 E8M0 byte scales |
| `nnc.LinearNvFp4` | E2M1, K16 E4M3FN byte scales plus a BF16-rounded global scale |
| `nnc.LinearQ8_0` | signed INT8, K32 native FP16 scales |
| `nnc.LinearFp8E4M3FN` | E4M3FN, K32 BF16 scales |
| `nnc.LinearFp8E5M2` | E5M2, K32 BF16 scales |

Each constructor currently accepts an ordinary `torch.nn.Linear`. N must be
a positive multiple of 8; K must be divisible by the preset's group length.
Optional bias is a separate BF16 add. See the runnable examples linked above
for each format's complete source, saved artifacts and numerical contract.

### 2. Build and run on public E3 RTL

The compile call writes `forward.hpp`, `init.hpp`, `input.bin`, `weight.bin`
and `expected.bin`. Build and run this saved artifact set using the shared
[minimal C++ main](src/edge-nnc/example/linear_fp4/main.cpp):

```sh
PYTHON=.venv/bin/python ./scripts/run-nnc.sh smoke \
  --artifacts-dir build/nnc-demo \
  --main-file src/edge-nnc/example/linear_fp4/main.cpp \
  --build-dir build/nnc-demo/run
```

The workspace supplies the E3/Edge32 SDKs, LLVM bare-metal build and public
Verilator simulator. The runner compares all 144 BF16 outputs with the saved
quantized reference and prints `TEST PASS` and `COMPARE PASS`. Saved-artifact
replay does not import PyTorch. ELF files, simulator output and comparison
dumps stay under `build/nnc-demo/run/`.

```text
nn.Module model + example inputs
    -> nnc.compile() (torch.export + NNC lowering)
    -> generated C++ + packed weights + saved reference
    -> RV32 ELF
    -> Verilated edge-e3 RTL
    -> BF16 comparison with the quantized PyTorch model
```

### 3. Compile a complete model graph

The same API is used throughout the [Llama 3 example](example/llama/model.py).
Its attention projections, RMSNorm, RoPE, KV-cache interface, attention and
feed-forward layers compose reusable NNC modules in a PyTorch `nn.Module`;
residual paths and activations remain ordinary PyTorch expressions. Compile
the whole example graph with:

```python
import nnc
from example.llama.model import make_tiny_llama_block, make_example_args

model = make_tiny_llama_block().eval()
nnc.compile(model, make_example_args(), out_dir="build/llama3")
```

`PYTHON=.venv/bin/python ./example/llama/run.sh` generates, builds and runs
that model end to end. The current public workload is a reduced Llama 3
transformer block; its [README](example/llama/README.md) describes the model
scope and runtime behavior. Module composition and `nnc.compile()` cover the
full example graph, beyond a single quantized Linear layer.

### Quantization API status

The planned extension lets users choose their own quantization strategies,
provided the resulting weights and scales satisfy an NNC op's supported
format and packing contract. Current module constructors use NNC's preset
quantizers; accepting an already user-quantized Linear in a constructor is
**not yet implemented**. Existing lower-level function ops accept explicit
static weights/scales for supported formats, but the complete user-facing
quantized Linear construction API is still pending.

## Choose Your Path

The maintained Edge example run scripts use `scripts/build-verilator.sh`, which
builds the `edge-e3` simulator. CoreMark also includes a separate C906 run
script for comparison.

- **Run edge-e3:** build the public-source Verilator model and execute the hello,
  tensor, and PyTorch-to-NNC examples.
- **Integrate your own accelerator:** combine your RTL with `edge-32`, then
  define its instruction, memory, and verification paths.
- **Explore architecture research:** experiment with dataflows, numerical
  formats, DMA, SRAM, interconnects, chiplets, or clusters.
- **Contribute to edge-32:** file a centralized issue and prepare a focused,
  tested pull request.

## Quick Start

Follow the maintained
[`edge-bringup`](.codex/skills/edge-bringup/SKILL.md) workflow for dependencies,
repository setup, simulator builds, and smoke tests on macOS or Ubuntu.

```text
Use $edge-bringup to set up this machine and run the initial smoke tests.
```

## Architecture

### Open RV32 integration platform

`edge-32` provides a four-stage, single-issue, in-order RV32IMF processor with
Zba for scalar control. It includes instruction decode, accelerator commands,
caches, floating point, and integration points for DMA, SRAM, and custom
compute.

Composed cores use this naming convention:

```text
rv_core_name@asic_core_name
```

For example, `edge-32@e3` combines the open `edge-32` processor with the e3
ASIC set. A custom integration could use a name such as
`edge-32@your_asic_name`.

### edge-32@e3 reference composition

![edge-32@e3 architecture showing the edge-32 processor, tensor unit, DMA,
accelerator units, and shared DTCM](docs/images/edge-32-e3-architecture.svg)

The current reference composition includes:

- 16 KB instruction cache
- 16 KB data cache
- 128 KB DTCM
- 8x8 BF16 tensor unit
- DMA, activation(ACTU), comparison(CMPU), and cache-control interfaces

Use edge-e3 as a working system reference, not as a required template. Its
public boundaries and public RTL demonstrate one integration while your
design retains its own architecture, repository, and license.

## Bring Your Own Design

Add an accelerator or ASIC repository below `src/` as a Git submodule and
connect it to `edge-32`. A design can range from one operator
to a complete compute and memory subsystem.

The [`integrate-your-design`](.codex/skills/integrate-your-design/SKILL.md)
workflow covers the maintained integration path:

- allocate an `opcode8`;
- implement `setcsr`, `start`, and `sync` commands;
- carry `imm8` and GPR parameters through the snapshot path;
- connect DMA, SRAM, and optional LSU debug access;
- use the optional low-precision FPU instructions during bring-up; and
- validate the integration with RTL and C++ tests.

Two development styles are equally welcome:

- Start from real model, format, latency, cost, and deployment requirements and
  make product-level tradeoffs.
- State a research scenario explicitly and push architecture, PPA, memory, or
  cluster scale as far as the experiment requires.

Example request for Codex:

```text
Use $integrate-your-design to connect my accelerator and define its software, memory, and verification plan.
```

## Reference Products

The Edge E/P families demonstrate complete NPU configurations built on the
shared framework. They are reference products rather than limits on what
`edge-32` can support, and their RTL is not uniformly open.

### Product overview

| Product | Positioning | Tensor unit | DTCM | RTL availability |
| --- | --- | ---: | ---: | --- |
| `edge-e3` | Transformer and CNN classifiers | 8x8 | 128 KB | Public source RTL available |
| `edge-e4` | Compute-intensive workloads such as segmentation | 16x16 | 256 KB | Release planned |
| `edge-e5` | LLM inference with Q8/FP8 quantization | 32x32 | 512 KB | Not currently available |
| `edge-p3` | Higher-throughput classifiers | 8x16 | 128 KB | Not currently open |
| `edge-p4` | Higher-throughput segmentation | 16x32 | 256 KB | Not currently open |
| `edge-p5` | LLM inference with Q4/FP4 quantization | 32x64 | 1 MB | Not currently open |

At 1 GHz, the E-series BF16 peak throughput ranges from 0.128 TFLOPS for
edge-e3 to 2.048 TFLOPS for edge-e5. The P-series range is 0.256 to 4.096
TFLOPS. These are architectural peak values, not measured silicon results.

Release timing and licensing can change. Treat the product repository and its
license as the authoritative source for availability.

## High-Performance Software

The **[Edge intrinsic user manual](src/edge-e3/include/README.md)** is the main guide
for writing efficient bare-metal software on Edge. It documents the DMA,
Tensor, ACTU, CMPU, cache, BF16, cycle-counting, and simulator interfaces, with
working C++ examples.

More importantly, it explains the programming patterns needed for performance:
asynchronous `start()`/`sync()`, overlapping scalar and accelerator work, DMA
buffer ownership, avoiding unnecessary cache maintenance, DTCM data placement,
and circular DMA/weight-loading pipelines. Start there when writing a custom
operator or tuning generated C++.

```sh
./example/tensor/run.sh
```

The tensor example is the smallest end-to-end demonstration of these patterns.

## Performance Snapshot

The Tensor result below comes from the maintained example on the current
`edge-e3` RTL (`5fc26eec`, Edge32 `f3648524`, shared ASIC `d751a2e5`).
The Activation results are historical RTL simulation
checkpoints. These are not silicon measurements.

### Tensor

The maintained [`example/tensor`](example/tensor/README.md) case runs a
64x64x128 BF16 matrix multiplication with packed weight DMA and transpose
circular weight loads:

| Ideal MAC cycles | Measured `rdcycle` interval | Effective MAC utilization |
| ---: | ---: | ---: |
| 8,192 | 8,638 | **94.84%** |

Effective MAC utilization is calculated as `ideal MAC cycles / cycle_delta`.
The measured RTL interval starts before the packed weight DMA and ends
after both `edge_tensor_sync()` and `edge_dma_sync()`, so it includes DMA,
circular weight loading, Tensor execution, loop/control overhead, and final
synchronization. One-time test-data initialization and the subsequent output
copy back to DRAM are outside this interval. Older checkpoints published this
same timing boundary through X30; the current example prints `cycle_delta`.
X31 carries the program exit code in the current harness.

Run the same public example with:

```sh
./example/tensor/run.sh
```

### Activation

| Workload | Result |
| --- | ---: |
| 4,096-element BF16 SiLU | 99.49% pipeline utilization |
| 4,096-element BF16 Softmax | 99.59% pipeline utilization |

See the [tensor example](example/tensor/README.md),
[ACTU example](example/actu/README.md), and
[Llama operator profile](example/llama/README.md) for implementation and
measurement details.

## Documentation

| Goal | Entry point |
| --- | --- |
| Set up and run edge-e3 | [`edge-bringup`](.codex/skills/edge-bringup/SKILL.md) |
| Integrate an accelerator | [`integrate-your-design`](.codex/skills/integrate-your-design/SKILL.md) |
| Write high-performance software | **[Edge intrinsic user manual](src/edge-e3/include/README.md)** |
| Run the hello smoke | [Hello example](example/hello/README.md) |
| Debug FP4 scalar conversion | [FP4 debug example](example/fp4_debug/README.md) |
| Debug FP8/BF16 and floating `printf` | [FP8/BF16 debug example](example/fp8_bf16_debug/README.md) |
| Run tensor matmul | [Tensor example](example/tensor/README.md) |
| Compare scalar CoreMark cycles | [CoreMark example](example/coremark/README.md) |
| Run PyTorch-to-NNC | [Llama example](example/llama/README.md) |
| Run synthesis profiles | [Synthesis guide](synth/README.md) |
| Understand the SoC harness | [SoC guide](src/soc/README.md) |
| Contribute a change | [Contributing guide](CONTRIBUTING.md) |
| Review repository licenses | [Licensing guide](LICENSING.md) |

## Research

Use Edge32 to avoid rebuilding scalar control, accelerator command issue,
simulation, and software infrastructure for each architecture experiment.
Unconventional or deliberately idealized assumptions are welcome when they are
stated clearly and help isolate a research question.

When publishing results, distinguish the edge-cores contribution—such as the
four-stage, single-issue Edge32 processor and its accelerator integration—from
the new accelerator, dataflow, PPA, or application contribution. Use
[`references.bib`](references.bib) for the canonical citation.

## Contributing

File issues in the centralized
[edge-cores issue tracker](https://github.com/exeex/edge-cores/issues), including
issues involving submodules. Do not file them in a submodule's own tracker.

Read [CONTRIBUTING.md](CONTRIBUTING.md) for the development and validation
workflow. Repository templates are provided for both issues and pull requests.

Codex users can also invoke the maintained contribution workflow:

```text
Use $edge-contribution to prepare this change for an edge-cores pull request.
```

## License

The C++ libraries, Python compiler and runtime tools, scripts, examples, SoC
harness RTL, documentation, and automation maintained directly in edge-cores
are licensed under Apache-2.0.

The reusable `edge-32` processor is licensed under CERN-OHL-P-2.0. Edge product
repositories and generated RTL may use different licenses. In particular,
edge-e3 is source-available under the edge-e3 Hardware License 1.0 and is not
OSI-approved open-source hardware.

See [LICENSING.md](LICENSING.md) for the repository and submodule boundaries,
and [`src/edge-e3/LICENSE.md`](src/edge-e3/LICENSE.md) for the complete
edge-e3 terms.
