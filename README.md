# edge-cores

**The shortest way from PyTorch to ASICs.**

Export PyTorch to bare-metal C++ and run it on ASIC RTL with Verilator. Use the
open-source `edge-rv` or `edge-rv-lite` control plane with your own accelerator,
or start with the source-available `edge-e3` reference NPU.

The maintained [`example/tensor`](example/tensor/README.md) reaches **94.72%
effective MAC utilization** on a 64x64x128 BF16 matmul. The end-to-end measured
interval includes packed weight DMA, circular weight loads, Tensor execution,
and synchronization.

## Run Llama 3 and Qwen 3.6 on edge-rv@e3 ASIC RTL

The current public flow demonstrates a **single Llama 3 transformer block** and
a **reduced single Qwen 3.6 full-attention decoder layer** running on the
`edge-rv@e3` ASIC RTL through Verilator. `edge-rv@e3` combines the open
`edge-rv` control plane with e3, a deliberately tiny 8x8 BF16 Tensor ASIC with
128 KB of DTCM. This MVP demonstrates the complete PyTorch-to-ASIC path with
compact single-layer workloads.

Both examples start as small PyTorch modules, compile to bare-metal C++,
execute on the RTL, and compare their BF16 outputs with PyTorch.

First follow the
[`edge-bringup`](.codex/skills/edge-bringup/SKILL.md) workflow. It installs the
required public submodules and creates the repository-owned `.venv` used by the
commands below.

Run the Llama 3 block:

```sh
PYTHON=.venv/bin/python ./example/llama/run.sh
```

Run the Qwen 3.6 layer:

```sh
PYTHON=.venv/bin/python ./example/llama/run.sh \
  --model-file nnc/test/qwen36_source.py
```

The Qwen example is a 32-token, 64-wide, one-head compatibility slice. It
preserves Q/K RMSNorm, the attention-output gate, SwiGLU MLP, and residual
structure. See [`qwen36_coverage.md`](nnc/test/qwen36_coverage.md) for the
current MVP coverage and next implementation steps.

## PyTorch to ASIC RTL: Minimal Example

The SiLU smoke test demonstrates the complete path with the smallest useful
model.

### 1. Write and export a PyTorch model

```python
import torch
import torch.nn as nn
import torch.nn.functional as F


class SmokeSilu(nn.Module):
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return F.silu(x)


model = SmokeSilu().eval()
example_args = (torch.randn(64, 64),)
exported = torch.export.export(model, example_args)
```

NNC consumes the same model and example arguments. Internally it reads the
`ExportedProgram`, maps the exported `aten.silu` node to the Edge operator, and
infers the generated ABI and tensor shapes.

### 2. Generate bare-metal C++

The compiler turns the exported graph into `forward.hpp`, `init.hpp`, and an
optional `weight.bin`. The generated forward path contains a direct libnn call:

```cpp
nnedge::op::silu(silu, x);
```

The generated headers are compiled with the shared C++ runtime into a
freestanding RV64 ELF. There is no host-side PyTorch dependency in the target
program.

### 3. Run it on the Verilated RTL

After the initial setup, one command generates the code, builds the RV64 image,
runs it on the encrypted edge-e3 Verilator model, and compares the BF16 output
against PyTorch:

```sh
PYTHON=.venv/bin/python ./example/llama/run.sh \
  --model-file nnc/test/smoke_silu.py
```

Expected final result:

```text
TEST PASS
COMPARE PASS values=4096
```

Generated C++, weights, ELF, memory image, simulator output, and comparison logs
are kept under `example/llama/build/smoke_silu/`.

```text
PyTorch model
    -> torch.export
    -> NNC graph lowering
    -> generated bare-metal C++
    -> RV64 ELF
    -> Verilated edge-e3 RTL
    -> BF16 comparison with PyTorch
```

## Choose Your Path

- **Run edge-e3:** build the encrypted Verilator model and execute the hello,
  tensor, and PyTorch-to-NNC examples.
- **Integrate your own accelerator:** combine your RTL with `edge-rv` or
  `edge-rv-lite`, then define its instruction, memory, and verification paths.
- **Explore architecture research:** experiment with dataflows, numerical
  formats, DMA, SRAM, interconnects, chiplets, or clusters.
- **Contribute to edge-rv:** file a centralized issue and prepare a focused,
  tested pull request.

## Quick Start

Follow the maintained
[`edge-bringup`](.codex/skills/edge-bringup/SKILL.md) workflow for dependencies,
repository setup, simulator builds, and smoke tests on macOS or Ubuntu.

```text
Use $edge-bringup to set up this machine and run the initial smoke tests.
```

## Architecture

### Open RV64 integration platform

`edge-rv` provides scalar control, instruction decode, asynchronous accelerator
commands, snapshot-based GPR parameter capture, caches, optional floating
point, and integration points for DMA, SRAM, and custom compute.

`edge-rv-lite` provides a smaller serialized control plane for accelerators
that do not require the full snapshot and overlap machinery.

Composed cores use this naming convention:

```text
rv_core_name@asic_core_name
```

For example, `edge-rv@e3` combines the open `edge-rv` control plane with the e3
ASIC set. A custom integration could use a name such as
`edge-rv-lite@your_asic_name`.

### edge-rv@e3 reference composition

![edge-rv@e3 architecture showing the edge-rv control plane, tensor unit, DMA,
accelerator units, and shared DTCM](docs/images/edge-rv-e3-architecture.svg)

The current reference composition includes:

- 16 KB instruction cache
- 16 KB data cache
- 128 KB DTCM
- 8x8 BF16 tensor unit
- DMA, activation, comparison, and cache-control interfaces

Use edge-e3 as a working system reference, not as a required template. Its
public boundaries and encrypted RTL demonstrate one integration while your
design retains its own architecture, repository, and license.

## Bring Your Own Design

Add an accelerator or ASIC repository below `src/` as a Git submodule and
connect it to `edge-rv` or `edge-rv-lite`. A design can range from one operator
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
`edge-rv` can support, and their RTL is not uniformly open.

### Product overview

| Product | Positioning | Tensor unit | DTCM | RTL availability |
| --- | --- | ---: | ---: | --- |
| `edge-e3` | Transformer and CNN classifiers | 8x8 | 128 KB | Encrypted RTL available; open release planned |
| `edge-e4` | Compute-intensive workloads such as segmentation | 16x16 | 256 KB | Encrypted release planned |
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

The **[Edge intrinsic user manual](cpp/intrinsic/README.md)** is the main guide
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

All results below are RTL simulation checkpoints, not silicon measurements.

### Scalar

The scalar reference is the T-Head C906 RTL from
[OpenC906](https://github.com/XUANTIE-RV/openc906).

| Benchmark | edge-e3 | T-Head C906 | Relative result |
| --- | ---: | ---: | --- |
| CoreMark, cycles/iteration | 409,490 | 432,703 | edge-e3 1.06x faster |
| FP32 Nelder-Mead, cycles | 7,860 | 10,924 | edge-e3 1.39x faster |
| JPEG block, cycles | 161,281 | 101,108 | C906 1.60x faster |

### Tensor

The maintained [`example/tensor`](example/tensor/README.md) case runs a
64x64x128 BF16 matrix multiplication with packed weight DMA and transpose
circular weight loads:

| Ideal MAC cycles | Measured end-to-end cycles | Effective MAC utilization |
| ---: | ---: | ---: |
| 8,192 | 8,649 | **94.72%** |

Effective MAC utilization is calculated as `ideal MAC cycles / measured
cycles`. The measured RTL interval starts before the packed weight DMA and ends
after both `edge_tensor_sync()` and `edge_dma_sync()`, so it includes DMA,
circular weight loading, Tensor execution, loop/control overhead, and final
synchronization. One-time test-data initialization and the subsequent output
copy back to DRAM are outside this interval.

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
| Write high-performance software | **[Edge intrinsic user manual](cpp/intrinsic/README.md)** |
| Run the hello smoke | [Hello example](example/hello/README.md) |
| Debug FP8/BF16 and floating `printf` | [FP8/BF16 debug example](example/fp8_bf16_debug/README.md) |
| Run tensor matmul | [Tensor example](example/tensor/README.md) |
| Run PyTorch-to-NNC | [Llama example](example/llama/README.md) |
| Run synthesis profiles | [Synthesis guide](synth/README.md) |
| Understand the SoC harness | [SoC guide](src/soc/README.md) |
| Contribute a change | [Contributing guide](CONTRIBUTING.md) |
| Review repository licenses | [Licensing guide](LICENSING.md) |

## Research

Use Edge RV to avoid rebuilding scalar control, asynchronous command issue,
simulation, and software infrastructure for each architecture experiment.
Unconventional or deliberately idealized assumptions are welcome when they are
stated clearly and help isolate a research question.

When publishing results, distinguish the edge-cores contribution—such as its
snapshot mechanism and tightly integrated dual-issue, in-order issue and
out-of-order execution model—from the new accelerator, dataflow, PPA, or
application contribution. Use [`references.bib`](references.bib) for the
canonical citation.

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

The reusable `edge-rv` framework is licensed under CERN-OHL-P-2.0. Edge product
repositories and generated RTL may use different licenses. In particular,
edge-e3 is source-available under the edge-e3 Hardware License 1.0 and is not
OSI-approved open-source hardware.

See [LICENSING.md](LICENSING.md) for the repository and submodule boundaries,
and [`src/edge-e3enc/LICENSE.md`](src/edge-e3enc/LICENSE.md) for the complete
edge-e3 terms.
