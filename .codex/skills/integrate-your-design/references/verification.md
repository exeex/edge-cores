# Verification checklist

Run the smallest focused test for the changed contract, then the relevant
public software harness using the new intrinsic. Select tests from the actual
product top and connected interfaces. The maintained E3 product uses Edge-32
request/response; tagged snapshots and IFU join placeholders are conditional
frontend features, not universal requirements. See
[execution model](execution-model.md) and [RTL patterns](rtl-patterns.md).

## Check the implemented hardware contract

1. **Encoding and operand delivery.** Verify exact ASIC32 words, subop,
   split `imm8`, `rs1` and result `rd` where applicable, using the current
   [instruction interface](instruction-interface.md). Exercise a scalar result
   immediately consumed by `set_*`, stalled request stability, exactly one
   acceptance and the matching response/error. Do not infer RTL execution
   from a host-only intrinsic test or constexpr encoding assertion.
2. **Start and descriptor lifetime.** Check direct launch, busy acceptance,
   full-capacity backpressure and later configuration writes. Accepted work
   must keep its addresses, counts and modes. For current Tensor, include
   weight-wait `start_pending_*`, queued work and copy-mode behavior. Test
   simultaneous pending launch/refill only if the design supports it; it is
   not the current Tensor readiness contract.
3. **Asynchronous completion.** Show that accepted starts can return before
   compute finishes and later starts are neither lost nor overwritten.
   Exercise a target sync with active, queued and pending work and outstanding
   transport. Edge-32 must not complete that instruction before its response;
   sync must honor the target's complete drain condition.
4. **Memory paths.** Exercise DMA-to-SRAM-to-ASIC and the reverse direction,
   partial byte strobes, alignment/range boundaries, delayed ready/response,
   bank conflicts and actual write visibility. Check scalar publication before
   DMA and acquisition after completion, plus physical payload layout and
   output guards. Follow [memory integration](memory-integration.md).
5. **Reset and errors.** Check reset with outstanding requests and pending
   work, unknown suboperations and operation-specific invalid fields. Verify
   no unintended engine side effects on error and no stale completion after
   reset. Check flush/redirect behavior at the boundary the frontend actually
   exposes rather than assuming sequence/epoch ports are connected.
6. **Numerics.** Compare every supported format and mode with an independent
   reference, including conversion, rounding, saturation and relevant special
   values. Scalar FPU helpers may generate fixtures, but sharing the same
   faulty conversion logic with the checker can hide errors. Preserve the
   documented tolerance; exact tests must remain exact.

For configurable queues test depth 1 and intended production depths where
supported. Record unsupported configurations instead of forcing a generic
parameter sweep onto fixed-topology hardware.

## Additional checks for optional mechanisms

For a connected tagged command frontend, test command-before-snapshot and
snapshot-before-command, dependency resolution (including out-of-order GPR
production if supported), full sequence/epoch matching across low-bit slot
wrap, redirect kills and slot reuse. A scalar sync placeholder must stay
incomplete until the matching tagged completion arrives. These tests do not
substitute for the public Edge-32 request/response tests.

For an implemented scalar-store interlock, delay scalar ready and physical
visibility while exercising all affected compute/DMA request paths. Verify
blocked payload stability, no producer advance on suppressed transfers and
handling of already-buffered work. Current `edge_lite_accel_platform` ties
`scalar_lsu_store_block` to zero: do not claim this feature was validated by
running the unmodified product's examples.

## Use the current public test routes

Run from the workspace root. Follow [regression routing](../../../../tests/README.md)
and the [test matrix](../../edge-contribution/references/test-matrix.md).
Initialize the pinned public E3, Edge-32 and ASIC submodules, plus NNC for its
software tests. Prepare NNC's Python environment with
`./scripts/setup-python.sh`; use the project `.venv` or an explicit prepared
`PYTHON` with PyTorch and editable NNC.

| Changed surface | Validation route |
| --- | --- |
| Documentation/skill only | Local links, format checks and `git diff --check` |
| Public RTL, filelists or SoC integration | `./scripts/build-verilator.sh`, hello, tensor and ACTU examples; add interface and affected software coverage |
| Intrinsics/runtime hardware boundary | `./tests/run.sh interface`, hello and affected examples |
| NNC lowering | `./tests/run.sh nnc-unit` plus affected smoke models |
| Runtime/layout/allocator/DMA ownership or composed models | `./tests/run.sh nnc` plus the interface sentinel and affected examples |
| Broad cross-layer integration | `./tests/run.sh all` |

`./tests/run.sh --list` lists routes. The `nnc` adapter runs unit discovery,
the model harness and packed C++ regressions (including weight packing and
cache ownership). `example/llama/test.sh` delegates to that group.
`all` combines NNC, interface and independent examples, continues across
failed groups and exits nonzero on failure. CoreMark is a separate benchmark.

The interface runner rebuilds the simulator by default. Use
`./tests/run.sh interface --skip-verilator-build` only after building the
reviewed sources. Give concurrent builds separate `EDGE_VERILATOR_OUT`
directories. Keep semantic tests in NNC and workspace compatibility sentinels
in `tests/interface`; do not duplicate model lists or golden logic locally.

## Inspect evidence and report limits

Check detailed reports, not only shell status:

- `build/tests/<group>/summary.tsv` and per-case logs for `all` or `examples`.
- NNC `src/edge-nnc/example/llama/build/harness/harness.md` and `harness.tsv`,
  with every discovered model accounted for and numerical comparison passing.
- Interface `tests/interface/build/run.log` for
  `MATMUL_INTERFACE PASS cases=6` and `run_case.report` for `TEST PASS`.
- Packed regression `tests/nnc/build/packed/summary.tsv`, simulator reports
  and the respective completion markers: `PACKED ALL PASS cases=26`,
  `WEIGHT PACK ALL PASS cases=16`, and `CACHE OWNERSHIP PASS`.

Require simulator `TEST PASS` and `COMPARE PASS` where a runner uses that
numerical comparator. Preserve logical goldens and tolerances; do not turn a
failure into a pass by skipping models or weakening comparisons. The six-case
Matmul sentinel verifies a specific runtime/intrinsic/RTL boundary, not every
operator or a newly attached accelerator.

Report exact commands, workspace/submodule revisions, environment, PASS /
FAIL / NOT RUN, diagnostics and remaining coverage gaps. If no public testbench
reaches the custom top, add focused coverage and explicitly report full
integration as unavailable. Validate release consumers without requiring
private test repositories. Keep generated binaries, logs and simulator trees
out of ordinary source commits.

Benchmark evidence needs separate workload, baseline and timing boundaries;
see [paper evaluation](paper-evaluation.md). Historical release PASS results
and a passing software suite do not establish untested RTL corner cases,
physical timing or silicon performance.
