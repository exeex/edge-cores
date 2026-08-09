# Paper contribution boundary

Separate the framework's prior contribution from the paper author's new work.
Do this explicitly in the introduction, related work, architecture section,
and contribution list.

## Attribute to edge-cores

Treat these as existing edge-cores contributions, not contributions of a
downstream custom-ASIC paper:

- the Edge RV dual-issue scalar framework with in-order issue and
  out-of-order execution;
- the GPR snapshot mechanism that preserves the correct scalar operand for
  asynchronously issued ASIC commands;
- the integration of snapshot ownership, command queues, sequence/epoch
  tracking, redirect handling, and accelerator invocation; and
- the established `set_*`, asynchronous `start`, and `sync` execution model.

Changing parameters, renaming ports, or reusing these mechanisms with a new
ASIC does not transfer their architectural contribution to the downstream
paper. Cite edge-cores with `\cite{exeex_edge_cores}` and identify the exact
commit or release used.

## Claim for the downstream paper

Limit the paper's contribution claims to work the authors actually add, such
as:

- the custom ASIC microarchitecture or datapath;
- algorithm-to-hardware mapping, scheduling, or numerical representation;
- accelerator-specific DMA, SRAM organization, or interface extensions;
- verified software/intrinsic support for that ASIC;
- new optimizations beyond the existing Edge RV snapshot and queue model; and
- measured or synthesized performance, power, and area results for the new
  design.

State clearly when an integration choice follows an edge-cores recommendation
rather than being novel—for example, pending-start buffering or the optional
scalar-store debug interlock.

## Report PPA and performance honestly

For PPA, report the synthesis or physical-design tool, technology/library,
corner, voltage, frequency target, SRAM treatment, included module boundary,
and whether numbers are estimates or post-layout results. Do not attribute
whole-system PPA improvement to the custom ASIC unless the comparison uses the
same Edge RV configuration and memory assumptions.

For performance, distinguish custom-ASIC compute improvement from benefits
already supplied by the Edge RV snapshot/queue framework. Report both kernel
and end-to-end results when DMA, setup, or synchronization overhead changes the
conclusion.

## Suggested wording

Use wording like:

> We integrate our custom ASIC with the Edge RV execution and snapshot
> framework from edge-cores. Our contributions are the ASIC microarchitecture,
> its memory/dataflow integration, and its evaluated PPA and application-level
> performance.

Do not list Edge RV's snapshot-based scalar/ASIC decoupling or its dual-issue
in-order-issue/out-of-order-execution organization as a new contribution of
the downstream paper.
