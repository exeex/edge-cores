# edge-e3

edge-e3 is a dual-issue RISC-V 64-bit NPU designed for local LLM inference. It
integrates:

- 16 KB instruction cache
- 16 KB data cache
- 128 KB DTCM
- 8x8 BF16 tensor unit
- Tensor, ACTU, CMPU, and DMA acceleration; vector-like operations are mapped
  onto these units without a separate vector unit

Development is guided by ChatGPT and uses standard open-source toolchains. The
design does not depend on a custom compiler or simulator fork. Its PyTorch-to-NNC
flow can compile models such as Llama, Qwen, and GPT-OSS into executable images.
llama.cpp-compatible Q8 quantization is the primary planned deployment format.

## Product Line

The suffix describes the tensor dimension: `edge-eN` uses a `2^N x 2^N` tensor
unit. This repository implements the open-source `edge-e3`.

| Specification @ 1 GHz | `edge-e3` | `edge-e4` | `edge-e5` |
| --- | ---: | ---: | ---: |
| Open source | Yes | No | No |
| Tensor unit | 8x8 | 16x16 | 32x32 |
| SRAM size (dtcm)| 128KB| 256KB | 512KB
| BF16 peak throughput (TFLOPS) | 0.128 | 0.512 | 2.048 |
| Activation units | 1 | 2 | 4 |
| SiLU throughput (G elements/s) | 1 | 2 | 4 |
| Softmax throughput (G elements/s) | 0.333 | 0.667 | 1.333 |

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

| BF16 operation | Elements | Streaming passes | Ideal cycles | Measured cycles | Pipeline utilization | Effective throughput (element/cycle) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Sigmoid | 4,096 | 1 | 4,096 | 4,117 | 99.49% | 0.995 |
| SiLU | 4,096 | 1 | 4,096 | 4,117 | 99.49% | 0.995 |
| Tanh | 4,096 | 1 | 4,096 | 4,117 | 99.49% | 0.995 |
| Softmax | 4,096 | 3 | 12,288 | 12,338 | 99.59% | 0.332 |


- [ACTU activation throughput](experiments/actu-silu-throughput/README.md):
  start-to-sync cycle benchmark for 4,096 BF16 elements.


## Development

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

## Licensing

edge-e3 is distributed under the custom edge-e3 Hardware License 1.0.
Simulation, modification, distribution, and FPGA implementation are permitted.
A manufactured physical package may contain no more than one edge-e3 core, and
products using edge-e3 must provide attribution. A package containing multiple
edge-e3 cores requires a separate written commercial license.

See [`src/edge-e3enc/LICENSE.md`](src/edge-e3enc/LICENSE.md) for the complete terms.
This is a source-available hardware license, not an OSI-approved open-source
license.
