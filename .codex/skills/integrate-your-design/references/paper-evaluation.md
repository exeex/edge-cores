# Paper contribution boundary

Separate the reused framework from the paper author's new work in the
introduction, related work, architecture section and contribution list.
Describe the actual checked-out product, not a historical architecture that
happens to share the Edge name.

## Attribute the implementation actually used

The maintained public E3 product uses the
[Edge-32](../../../../src/edge-32/README.md) single-issue, four-stage, in-order
RV32 core. E3 owns product integration, DMA/DTCM and accelerator composition;
Edge-32 owns the scalar core and ISA backend, and NNC owns compiler/runtime
software. Identify reused blocks and their pinned revisions separately.

For this product, do not claim RV64 dual-issue execution, tagged snapshot
queues or IFU sync-join placeholders as active mechanisms. The public path
uses resolved operands and an accelerator request/response interface; see
[execution model](execution-model.md) and
[instruction interface](instruction-interface.md). If a downstream design
actually uses a historical RV64 frontend, document its source revision and
attribute its snapshot, sequence/epoch, redirect and queue mechanisms to that
implementation.

The established `set_*`, asynchronous `start` and engine `sync` model, existing
DMA/SRAM infrastructure and reused software kernels remain prior work.
Changing parameters, renaming ports or attaching a new ASIC does not make
those mechanisms a new contribution of the downstream paper.

Use `\cite{wu_edge_cores_2026}`, the current key in
[references.bib](../../../../references.bib), and record the experiment's exact
workspace and submodule commits separately. Older guidance using
`exeex_edge_cores` does not match the current bibliography.

## Claim the downstream contribution

Limit novelty claims to work the authors actually add, such as:

- the custom ASIC microarchitecture or datapath;
- algorithm-to-hardware mapping, scheduling or numerical representation;
- accelerator-specific DMA, SRAM organization or interface extensions;
- verified software/intrinsic support for the new ASIC;
- optimizations beyond the reused implementation, isolated by a controlled
  baseline; and
- measured or synthesized performance, power and area for the new design.

Explain when a choice follows an existing recommendation, such as pending
start buffering or an optional scalar-store interlock. Do not claim the latter
is active in the public Edge-32 platform merely because a lower-level arbiter
has the port; see [memory integration](memory-integration.md).

## Make performance measurements comparable

Record workload dimensions, precision/quantization, input generation and
numerical checks, token capacity/chunking, SRAM size, memory layout, warmup,
compiler/options, tool versions and exact component revisions. Keep these
fixed across a controlled A/B comparison, or explicitly identify each changed
factor. Include buffer ownership and cache handoffs when they affect the
claimed measurement boundary.

Distinguish these timing scopes:

| Scope | What the current evidence measures |
| --- | --- |
| Tensor stream | Weight/RHS DMA submission through final Tensor/DMA sync |
| Complete operator | Stream plus kernel validation/setup, still excluding ordinary model boundary input/output DMA |
| NNC profile share | A node's share of summed measured operator calls; allocation, copies, startup and printf are excluded |
| End-to-end application | Requires its own declared boundary and measurement; it cannot be inferred from operator utilization or profile share |

The [versioned Tensor benchmark](../../../../src/edge-nnc/benchmarks/tensor-64x64-128/README.md)
and [v0.3.1 validation](../../../../docs/releases/v0.3.1-validation.md) provide
concrete examples, not new measurements for a downstream design. Their
64×64, 128-token workload has 524,288 MACs and an ideal 8,192 cycles at
64 MACs/cycle; reported MAC utilization is ideal cycles divided by measured
cycles. It is not a direct measurement of silicon throughput or clock speed.
State the clock assumption when converting cycles to time, and distinguish
MACs from FLOPs when quoting peak rates.

The [release comparison](../../../../docs/releases/v0.3.1.md) isolates NNC
control optimization (`7f0946a` to `79091dc`) with matched RTL and workload.
It does not establish a full-model or universal v0.3-to-v0.3.1 speedup.
Report kernel and end-to-end results separately when DMA, setup or
synchronization changes the conclusion; mark unmeasured scopes explicitly.

## Preserve evidence and correctness

The public [benchmark runner](../../../../src/edge-nnc/nnc/benchmark_tensor.py)
combines Matmul and quant Linear results into 24 operator/capacity rows.
Retain the per-run results, logs and `matmul/provenance.json` and
`quant/provenance.json`, including source hashes, dirty state, tool versions
and simulator hash. Distinguish the original upstream benchmark revision
from the consuming workspace's reproduction pins; matching results do not
make their source revisions identical.

Require numerical checks as well as timing evidence. The current operator
benchmark uses exact BF16 comparison and checks MAC/command evidence; do not
silently relax that criterion to improve a result. Record failures and any
unrun tests. An old release PASS does not validate a modified design.
Follow the [software harness](../../software-harness/SKILL.md) for current
regression and profile interpretation, and
[artifact release](paper-release.md) for packaging. Raw generated evidence
stays in ignored build directories unless deliberately packaged as an artifact.

## Report PPA at the supported level

For PPA, report the tool/version, technology/library, corner, voltage,
frequency target, SRAM treatment, module boundary and implementation stage.
Distinguish synthesis estimates, pre-CTS timing, routed results and measured
silicon. Report a power methodology and activity assumptions before making
power or energy claims.

The repository's [Yosys profiles](../../../../synth/README.md) produce
FPGA-oriented resource estimates, not placed-and-routed or ASIC PPA.
`edge32@e3` and `edge-32` cover different boundaries. Historical `edge-rv`
and `edge-rv-lite` profiles require separately supplied source trees; they
are not current checkout submodules. Keep core, memory and tool assumptions
comparable before attributing whole-system gains to a custom ASIC.

## Suggested wording

For a study using the current product, adapt wording such as:

> We build on the Edge-32/E3 integration and software stack from edge-cores,
> with component revisions recorded in our artifact. Our contributions are
> the custom accelerator datapath and its memory/dataflow integration. We
> evaluate these changes against a matched baseline using the measurement
> boundaries and implementation stages stated for each result.

Only include contribution and evaluation claims actually supported by the
paper's implementation and evidence.
