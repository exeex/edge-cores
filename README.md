# edge-cores

edge-cores is a family of 64-bit RISC-V NPUs designed for neural
network acceleration. Depending on the model, each NPU integrates:

- 16–32 KB instruction cache
- 16–32 KB data cache
- 128–1,024 KB DTCM
- An 8x8 to 32x64 BF16 tensor unit

The SDK is developed with guidance from ChatGPT and uses standard open-source
toolchains. The design does not depend on a custom compiler or simulator fork.
Its PyTorch-to-NNC flow can compile models such as Llama, Qwen, and GPT-OSS into
executable images.
llama.cpp-compatible Q8 quantization and gpt-oss-xB mxfp4 quantization is the primary planned deployment format.

The SDK currently supports Llama 3, qwen3.6. Support for additional models, including
Qwen and YOLO, is under development.

## Product Line

### E Series

| Specification @ 1 GHz | `edge-e3` | `edge-e4` | `edge-e5` |
| --- | ---: | ---: | ---: |
| Product positioning | License-free Transformer/CNN classifiers (including YOLO) | Compute-intensive workloads such as segmentation | LLM inference with Q8/FP8 quantization |
| Encrypted RTL available | Yes | July 2027 | No |
| Fully open source | July 2027 | No | No |
| Tensor unit | 8x8 | 16x16 | 32x32 |
| SRAM size (DTCM) | 128 KB | 256 KB | 512 KB |
| BF16 peak throughput (TFLOPS) | 0.128 | 0.512 | 2.048 |
| Activation units | 1 | 2 | 4 |
| SiLU throughput (G elements/s) | 1 | 2 | 4 |
| Softmax throughput (G elements/s) | 0.333 | 0.667 | 1.333 |

### P Series

| Specification @ 1 GHz | `edge-p3` | `edge-p4` | `edge-p5` |
| --- | ---: | ---: | ---: |
| Product positioning | Higher-throughput Transformer/CNN classifiers | Higher-throughput segmentation workloads | Higher-throughput LLM inference with Q4/FP4 quantization |
| Open source | No | No | No |
| Tensor unit | 8x16 | 16x32 | 32x64 |
| SRAM size (DTCM) | 128 KB | 256 KB | 1 MB |
| BF16 peak throughput (TFLOPS) | 0.256 | 1.024 | 4.096 |

### Cluster

| Specification | `edge-p5 x8` |
| --- | ---: |
| Product positioning | Cluster-scale LLM inference |
| NPU configuration | 8x edge-p5 |
| Recommended process | TSMC N7 / N12, Samsung 8nm |
| Estimated die area on TSMC N12 | 100–146 mm² (includes LPDDR5 PHY/controllers and NoC; varies with optional IP) |
| Memory configuration | 8x 32-bit LPDDR5-6400 devices |
| Aggregate theoretical memory bandwidth | 204.8 GB/s |
| Estimated GPT-OSS-120B MXFP4 decode throughput | 56.7 token/s |
| Estimated GPT-OSS-120B MXFP4 prefill throughput | 158 token/s |

Both estimates assume 4.25-bit MXFP4 weights, a single user with `batch_size=1`,
and 75% of theoretical memory bandwidth. The 75% factor includes simple
contiguous KV-cache appends plus activation, interconnect, routing, DMA/DRAM,
and compute overhead. Decode uses 5.1B active parameters; MoE prefill uses all
117B parameters and the 32x64 tensor unit's 64x reuse factor.

```text
bandwidth = 8 * 32 bits * 6,400 MT/s / 8 = 204.8 GB/s
decode = 0.75 * 204.8 / (5.1B * 4.25 / 8) = 56.7 token/s
prefill = 64 * 0.75 * 204.8 / (117B * 4.25 / 8) = 158 token/s
```

Paged attention, multi-user KV-cache management, and vLLM multi-user batching
are not modeled; they may provide higher aggregate throughput. On sufficiently
large matrices, edge-p5 is expected to reach up to 99% MAC utilization.

## Edge E3 Performance

### Scalar performance
All values are RTL simulation checkpoints, not silicon measurements. The scalar
reference is the T-Head C906 RTL from
[OpenC906](https://github.com/XUANTIE-RV/openc906).

| Scalar benchmark | edge-e3 cycles | T-Head C906 cycles | Relative result |
| --- | ---: | ---: | --- |
| CoreMark (cycles/iteration) | 409,490 | 432,703 | edge-e3 1.06x faster |
| Decision tree | 12,975 | 15,298 | edge-e3 1.18x faster |
| Top-K | 44,059 | 43,203 | C906 1.02x faster |
| Branch-and-bound | 14,415 | 13,384 | C906 1.08x faster |
| Beam search | 22,128 | 21,596 | C906 1.02x faster |
| FP32 Nelder-Mead | 7,860 | 10,924 | edge-e3 1.39x faster |
| JPEG block | 161,281 | 101,108 | C906 1.60x faster |

### Tensor performance

Tensor utilization is `ideal MAC cycles / measured X30 loop cycles`.

| Tensor shape | Weight path | Ideal cycles | Measured cycles | MAC utilization |
| --- | --- | ---: | ---: | ---: |
| 64x64x64 | Circular WLD | 4,096 | 4,521 | 90.60% |
| 64x64x128 | Packed-XY DMA + transpose circular WLD | 8,192 | 8,649 | 94.72% |
| 512x512x32 | Packed-XY + transpose, resident X/Y | 131,072 | 155,829 | 84.11% |



### Activation performance

Effective throughput assumes a 1 GHz clock and is calculated as
`elements * 1,000,000,000 / measured cycles`. RMSNorm is the average of the two
32x64 RMSNorm calls in the tiny Llama transformer-block profile. Its ideal
cycle count uses useful pipeline work: eight elements per cycle for the Tensor
square, reduction, normalization, and weight streams, plus one RSQRT element
per row at one element per ACTU cycle.

| BF16 operation | Elements | Ideal cycles | Measured cycles | Pipeline utilization | Effective throughput @ 1 GHz (element/s) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Sigmoid | 4,096 | 4,096 | 4,117 | 99.49% | 0.994G |
| SiLU | 4,096 | 4,096 | 4,117 | 99.49% | 0.994G |
| Tanh | 4,096 | 4,096 | 4,117 | 99.49% | 0.994G |
| Softmax | 4,096 | 12,288 | 12,338 | 99.59% | 0.331G |
| RMSNorm (32x64) | 2,048 | 1,056 | 9,985 | 10.58% | 0.205G |


- [ACTU activation throughput](experiments/actu-silu-throughput/README.md):
  start-to-sync cycle benchmark for 4,096 BF16 elements.
- [Tiny Llama operator profile](example/llama/README.md): per-node cycle
  measurements including RMSNorm.


## Development

Low-level bare-metal software can use the DMA, Tensor, ACTU, CMPU, cache, and
BF16 interfaces documented in the
[Edge intrinsic user manual](cpp/intrinsic/README.md).

The smallest NNC end-to-end example exports a PyTorch linear model, runs it on
the encrypted-core Verilator model, and compares its BF16 output with PyTorch:

```sh
git submodule update --init src/edge-e3enc src/edge-rv
./scripts/setup-python.sh
PYTHON=.venv/bin/python ./example/llama/run.sh
```

The setup script uses the locked uv project environment in `.venv`. It selects
a CPU PyTorch build when no usable NVIDIA GPU is reported, otherwise choosing a
compatible CUDA wheel from the driver capability reported by `nvidia-smi`.
Override detection with `./scripts/setup-python.sh cpu`, `cu126`, `cu130`, or
`cu132`. Do not add uv's managed Python directory to the global `PATH`.

Install the [ChatGPT desktop app](https://learn.chatgpt.com/docs/app) and select
Codex for software development, or use the
[Codex IDE extension](https://learn.chatgpt.com/docs/codex/ide) in VS Code. Open
this repository and describe the task in your preferred language; the repository
skills contain the maintained build, test, benchmark, synthesis, and debug
workflows.

Example prompts:

```text
How do I run the edge-e3 RTL smoke tests?
Run the Edge vs T-Head C906 benchmarks and summarize the results.
I downloaded a model from Hugging Face. How do I run it on edge-e3?
Add llama.cpp Q4_K_M support to the tensor unit and NNC runtime.
I want to add <feature>. Where should I start, and which tests should I run?
```

## For Research Teams

Use Edge RV as the scalar and accelerator framework for integrating a custom
ASIC, DMA, and DTCM/SRAM. The
[`edge-custom-asic`](.codex/skills/edge-custom-asic/SKILL.md) skill explains the
instruction interface, snapshot mechanism, LSU integration, verification, and
paper-artifact workflow.

When publishing results, distinguish the edge-cores contribution—its snapshot
mechanism and tightly integrated dual-issue, in-order issue/out-of-order
execution model—from your contribution, such as the custom ASIC architecture,
dataflow, PPA, or application-level performance. Use
[`references.bib`](references.bib) for the canonical edge-cores citation.

Example prompt:

```text
Use $edge-custom-asic to connect my accelerator and plan its paper artifact.
```

## For Open-Source Contributors

Help evolve the shared Edge RV framework through focused, tested pull requests.
File every issue in the
[edge-cores issue tracker](https://github.com/exeex/edge-cores/issues), including
issues involving submodules; do not file them in a submodule's own tracker.

The [`edge-contribution`](.codex/skills/edge-contribution/SKILL.md) skill covers
forking the repository, choosing regression tests, preparing a pull request,
and supplying evidence for human and agent-assisted review. The repository also
provides an [issue template](.github/ISSUE_TEMPLATE/edge_issue.md) and a
[pull request template](.github/pull_request_template.md).

Example prompt:

```text
Use $edge-contribution to prepare this change for an edge-cores pull request.
```

## Licensing

The C++ libraries, Python compiler and runtime tools, scripts, examples, SoC
harness RTL, documentation, and automation maintained directly in edge-cores
are licensed under the Apache License, Version 2.0 (`Apache-2.0`). See
[`LICENSE`](LICENSE).

The reusable [`edge-rv`](src/edge-rv) framework is open-source hardware under
the permissive CERN Open Hardware Licence Version 2
(`CERN-OHL-P-2.0`). Product-specific repositories and generated RTL may use
different licenses.

edge-e3 is distributed under the custom edge-e3 Hardware License 1.0.
Simulation, modification, distribution, and FPGA implementation are permitted.
A manufactured physical package may contain no more than one edge-e3 core, and
products using edge-e3 must provide attribution. A package containing multiple
edge-e3 cores requires a separate written commercial license.

See [`src/edge-e3enc/LICENSE.md`](src/edge-e3enc/LICENSE.md) for the complete terms.
This is a source-available hardware license, not an OSI-approved open-source
license.

See [`LICENSING.md`](LICENSING.md) for the complete repository and submodule
license boundary.
