# Pull request review guide

Use the same evidence for maintainer and agent-assisted review.
Read the [contribution workflow](../SKILL.md) and the
[PR template](../../../../.github/pull_request_template.md) for scope,
compatibility, validation and licensing expectations.

## Review in order

1. Confirm the PR states one concrete problem and that the diff matches its
   declared scope.
2. Identify affected architectural contracts: instruction encoding, module
   ports, snapshot/sequence ownership, redirect handling, memory visibility,
   ready/valid backpressure, reset, software ABI, physical tensor layout, and
   CPU/DMA cache ownership.
3. Inspect correctness before style or performance.
4. Check that new behavior has a focused test and that existing regression
   evidence covers shared paths.
5. Reproduce the smallest important test when practical.
6. Verify performance or PPA claims use a stated baseline and comparable
   assumptions.
7. Report actionable findings with file/line location, failure scenario, and
   severity. Do not manufacture findings merely to populate a review.

## Match evidence to the current public flow

Use the [test matrix](test-matrix.md) to select coverage and
[regression routing](../../../../tests/README.md) for current ownership and
commands. Confirm routes against `tests/run.sh` and its adapters when they
change; `./tests/run.sh --list` lists the available groups.

- Documentation or skill changes need link/format checks and `git diff --check`.
- Public RTL, filelist or SoC changes use `./scripts/build-verilator.sh` and
  affected examples. Check that the public E3, Edge-32 and ASIC submodules
  match the reviewed pins; include the NNC pin for compiler/runtime changes.
  Public validation must not depend on optional private `src/test-e3` sources.
- Compiler/lowering changes need `./tests/run.sh nnc-unit` and affected
  models. For runtime, layout or composed-model changes, use
  `./tests/run.sh nnc`: it runs NNC unit discovery, the model harness and
  packed C++ regressions, including cache ownership. `example/llama/test.sh`
  delegates to this group; it is not merely a single Llama model test.
- Runtime/intrinsic/RTL compatibility changes also need
  `./tests/run.sh interface` and affected examples. The direct Matmul
  sentinel checks six cases against independent integer goldens; it does
  not replace compiler or composed-model coverage. Keep semantic fixtures
  in NNC and workspace boundary tests in `tests/interface`.
- Broad cross-layer changes use `./tests/run.sh all`, which runs NNC,
  interface and independent examples and retains individual failures.

For NNC tests use the prepared project `.venv` or an explicit `PYTHON`
interpreter with PyTorch and editable NNC. See the
[software harness skill](../../software-harness/SKILL.md) for setup and
report details. Reuse a simulator only when it was built from the reviewed
sources; concurrent builds need distinct `EDGE_VERILATOR_OUT` directories.

Record exact commands, revisions and PASS / FAIL / NOT RUN. Inspect
`build/tests/<group>/summary.tsv` for `all` or `examples`, the NNC
`src/edge-nnc/example/llama/build/harness/harness.md`, and relevant per-case
logs. Require simulator `TEST PASS` and numerical `COMPARE PASS` where the
runner performs a comparison; the interface runner instead requires
`MATMUL_INTERFACE PASS cases=6` plus simulator `TEST PASS`. A successful
shell exit or partial report alone is insufficient. Historical release
validation is a reproduction reference, not evidence that a new PR passes.

## Review layout and performance claims

For generated models, verify physical input/output storage against
`io_layout.json` while preserving logical PyTorch values. Review generated
headers, layout metadata and saved payloads as a matched artifact set.
The direct Matmul fixture currently uses `[head, channel/8, token, 8]`
LHS/output storage with row-major RHS in DRAM; do not assume that one layout
applies to every operator. CPU producers must publish payload writes before
DMA and CPU readers must acquire completed DMA outputs. Engine sync alone
does not establish CPU cache ownership; see NNC's
[memory contract](../../../../src/edge-nnc/MEMORY_OWNERSHIP.md).

Reject regression masking through looser tolerances, altered logical
goldens or skipped models. Check saved-artifact replay as well as fresh
generation when compiler storage or weight encoding changes. Distinguish
intentionally versioned example artifacts from ignored build products.

Performance evidence must state workload, baseline and component revisions,
measurement boundary, numerical checks, and simulation/synthesis/FPGA/silicon
context. For Tensor claims distinguish stream cycles, operator cycles and
full-model time; profile shares of measured operator calls exclude other
work. State the clock assumption for time/throughput claims. The
[v0.3.1 validation record](../../../../docs/releases/v0.3.1-validation.md)
illustrates source provenance and exact comparisons; its operator utilization
numbers are not full-model throughput or measured silicon performance.

## Agent review expectations

An internal review agent should read the PR description, base/head diff,
changed tests, and validation evidence. It should independently verify claims
against source and run safe local tests when useful. It must not infer PASS for
untested commands or accept prose as proof of architectural compatibility.

Prioritize:

- silent command loss, duplication, or reordering under backpressure;
- stale snapshot values, sequence wrap, epoch mismatch, and redirect kills;
- ready/valid instability and state advancement without a fired request;
- reset or parameter-depth corner cases;
- encoding or public ABI collisions;
- physical-layout mismatches and missing scalar/DMA ownership transitions;
- tests weakened to accommodate a regression; and
- accidental private source, generated output, or secrets in the diff.

Approve only when no actionable correctness issue remains and validation is
proportional to the risk. Missing optional optimization or style preferences
should not block an otherwise correct contribution.
