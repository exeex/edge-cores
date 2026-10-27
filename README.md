# edge-cores

**The shortest way from PyTorch to ASICs.**

Compile PyTorch models to bare-metal C++ and run them on edge-e3 RTL using
standard LLVM and Verilator. Build on the open-source **edge-32** control
processor and the source-available **edge-e3** reference NPU.

## New in v0.3

**MXFP4 · NVFP4 · FP8 E4M3FN / E5M2 · FP4 · Q8_0**

Packed quantized weights, native byte scales, BF22 partial sums, and PyTorch
`nn.Module` wrappers through `import nnc` and `nnc.compile()`.
See the [release note](docs/releases/v0.3.md) for format details and scope.

## PyTorch to ASIC RTL with NNC

Compose supported PyTorch/NNC modules and compile the whole graph:

```python
import torch
from torch import nn
from collections import OrderedDict
import nnc

model = nn.Sequential(OrderedDict(
    fc1=nnc.LinearMxFp4(nn.Linear(64, 64, bias=False)),
    act=nn.SiLU(),
    fc2=nnc.LinearNvFp4(nn.Linear(64, 16, bias=False)),
)).eval()

x = torch.ones(9, 64, dtype=torch.bfloat16)
nnc.compile(model, (x,), out_dir="build/nnc-demo", save_reference=True)
```

For runnable models, saved artifacts and simulator runners, see the examples:

| Quantized Linear | Composed models |
| --- | --- |
| [MXFP4](example/linear_mxfp4/README.md) · [NVFP4](example/linear_nvfp4/README.md) | [Llama 3 transformer block](example/llama/README.md) |
| [FP4](example/linear_fp4/README.md) · [Q8_0](example/linear_q8_0/README.md) | [Reduced Qwen 3.6 layer](nnc/test/qwen36_coverage.md) |
| [FP8 E4M3FN](example/linear_fp8_e4m3fn/README.md) · [FP8 E5M2](example/linear_fp8_e5m2/README.md) | |

## Setup

Use the [edge-bringup skill](.codex/skills/edge-bringup/SKILL.md) for macOS or
Ubuntu dependencies, public submodules and initial smoke tests. In Codex,
ask: **Use `$edge-bringup` to set up this machine.**

## Performance Snapshot

Rerun on **v0.3 public E3 RTL, 2026-10-27**. Both examples validate their
outputs and report `TEST PASS`. These are RTL simulation measurements.

| Workload | Ideal cycles | Measured cycles | Effective utilization |
| --- | ---: | ---: | ---: |
| [Tensor: 64×64 × 128 tokens](example/tensor/README.md), BF16 I/O + INT8 weights | 8,192 | 8,638 | **94.84%** |
| [SiLU: 4,096 BF16 elements](example/actu/README.md) | 4,096 | 4,149 | **98.72%** |
| [Softmax: 4,096 BF16 elements, three passes](example/actu/README.md) | 12,288 | 12,413 | **98.99%** |

Utilization = ideal / measured cycles. Tensor includes packed weight DMA,
circular loading and final synchronization. Activation measures warmed
`start`-through-`sync` intervals; Softmax sums its three pass intervals.
See [revisions, commands and measurement details](docs/releases/v0.3-performance.md).

## Build on Edge

[Integrate your accelerator](.codex/skills/integrate-your-design/SKILL.md) ·
[Intrinsic manual](src/edge-e3/include/README.md) ·
[Public regressions](tests/README.md) · [Synthesis](synth/README.md) ·
[Contributing](CONTRIBUTING.md) · [Research citation](references.bib)

Workspace software is Apache-2.0; edge-32 is CERN-OHL-P-2.0. Edge-e3 uses its
own source-available hardware license. See [licensing](LICENSING.md).
