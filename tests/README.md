# Public software regression routing

Tests are grouped by ownership and by the boundary they validate. Run from
the workspace root after `./scripts/setup-python.sh`. NNC runners default to
the project `.venv` containing PyTorch and editable `edge-nnc`. Set `PYTHON`
to an explicit prepared interpreter when needed; `UV_PROJECT_ENVIRONMENT`
selects a different project environment for both setup and the NNC runner.

| Group | Command | Owner and purpose |
| --- | --- | --- |
| NNC Python | `./tests/run.sh nnc-unit` | `src/edge-nnc/nnc/test_*.py`: compiler, lowering and quantized weight packing tests; no RTL required |
| NNC integration | `./tests/run.sh nnc` | NNC unit tests, every NNC-owned `smoke_*.py`, then the Llama profile and NNC-owned packed C++ regressions; this workspace supplies the Edge32 includes and public simulator |
| Software/hardware interface | `./tests/run.sh interface` | Workspace filelist checks and direct NNC matmul execution via `libnn/ops.hpp` against the pinned public RTL; no PyTorch or compiler lowering |
| Runnable examples | `./tests/run.sh examples` | hello, tensor, ACTU, scalar FP4/FP8 and named quant Linear examples, each with its existing correctness checks |
| Complete public regression | `./tests/run.sh all` | All three groups, continuing after failures and returning nonzero if any group fails |

`./tests/run.sh --list` lists these routes. The `examples` and `all` runs
write per-case logs and `summary.tsv` under `build/tests/<group>/`. Individual
runners retain their detailed build, simulator and comparison reports.
CoreMark is a separate benchmark: `example/coremark/run-edge.sh`; it is not
part of the correctness regression.
Private RTL tests under `src/test-e3` remain optional and independent.

## NNC owns compiler and runtime semantics

Keep model fixtures, PyTorch goldens, Python unit tests and model-discovery
logic in `src/edge-nnc`. Add a new compiler/operator regression there, not in
this repository's `example/` directory. `tests/nnc/run.sh` calls that package's
unit discovery and `src/edge-nnc/nnc/run_harness.py` through `scripts/run-nnc.sh`; it has no
local model list or tolerance overrides. Both phases run even if one fails.
Extra arguments to `tests/run.sh nnc` are passed to NNC's model harness.
`tests/nnc/packed.sh` supplies the workspace build and simulator adapter for
NNC's `packed_wsld_main.cpp` (26 configurations) and `weight_pack_main.cpp`
(16 configurations). Low-level packing and DMA tests live with NNC rather
than in the user-facing Linear examples.

`example/llama/test.sh` remains a compatibility entry point for this group.
The flat `example/llama/model.py` and `main.cpp` link to the canonical NNC
example. Its generated `forward.hpp` and `init.hpp` are versioned beside the
main; local `.bin` files are ignored. The legacy source paths remain available.
NNC suite reports remain at
`src/edge-nnc/example/llama/build/harness/harness.md` and `harness.tsv`.

## The workspace owns interface compatibility

`tests/interface/matmul.cpp` includes the workspace `libnn/ops.hpp` entry and
calls the pinned NNC matmul runtime directly,
using this workspace's intrinsic adapters, Edge32 include, bare-metal
startup, linker and public E3 simulator. It checks six BF16 cases: normal and
transposed RHS, one and two heads, and nine-row tails. K=16 and N=16 exercise
multiple K/output tiles, partial sums, strided/circular DMA and public
contiguous layouts. Each value is compared bit-for-bit with an independent
integer golden; no runtime reference helper or NNC-generated model is used.
It requires both the six-case completion marker and simulator `TEST PASS`.

This sentinel belongs here even though the tested header belongs to NNC:
its purpose is to detect a runtime/intrinsic/RTL version mismatch. It is a
small boundary test, not exhaustive operator coverage. Extend NNC's tests
for operator semantics; add workspace sentinels for new hardware interfaces.

The filelist checks cover `-f` versus `-F` path resolution, cyclic includes,
and resolution of the pinned public product sources without private models.
The runner rebuilds the simulator by default. After an explicit build of the
current pinned RTL, reuse it with:

```sh
./tests/run.sh interface --skip-verilator-build
```

Reports are in `tests/interface/build/`. Set `EDGE_INTERFACE_OUT` or
`EDGE_VERILATOR_OUT` to use another output directory.

## Examples are separately visible

| Example | Boundary checked by its existing runner |
| --- | --- |
| `example/hello` | startup, scalar execution, console and program exit |
| `example/tensor` | direct tensor/DMA intrinsics and tiled circular matmul; does not call `matmul.hpp` |
| `example/actu` | direct ACTU commands, BF16 output and throughput measurement |
| `example/fp4_debug` | scalar FP4 conversion, packing and storage |
| `example/fp8_bf16_debug` | scalar BF16/FP8 arithmetic and floating-point console formatting |
| `example/linear_fp4` | PyTorch/NNC FP4 model, generated C++ and packed weights, BF16 comparison |
| `example/linear_mxfp4` | same flow for K32 E2M1 with E8M0 byte scales, no bias, zero-tolerance comparison |
| `example/linear_nvfp4` | same flow for K16 E2M1 with E4M3FN byte scales and BF16 global scale, no bias, zero-tolerance comparison |
| `example/linear_q8_0` | same flow for K32 signed INT8 with native FP16 scales |
| `example/linear_fp8_e4m3fn` | same flow for FP8 E4M3FN |
| `example/linear_fp8_e5m2` | same flow for FP8 E5M2 |
| `example/llama` | flat, module-based Llama source and tracked C++ headers; regenerated binary payloads stay local; regression ownership stays with NNC |
| `example/coremark` | scalar benchmark, run separately |

When RTL, instructions, memory layout or a runtime header changes, run the
interface group and affected examples, then the NNC group for composed-model
coverage. If NNC passes but the interface sentinel fails, inspect the
workspace startup, intrinsics, cache/DMA contract and pinned RTL versions.
If the sentinel passes but an NNC model fails, inspect lowering, generated
ABI, layouts and composed operators; neither result alone proves the other
layer correct.
