# Central issue triage

Use `https://github.com/exeex/edge-cores/issues` as the single community issue
tracker. Do not redirect reporters to E3, Edge-32, NNC, test, or
third-party submodule trackers. Record the affected submodule or component as
issue metadata while keeping discussion in edge-cores. Follow the
[contribution workflow](../SKILL.md) and
[issue template](../../../../.github/ISSUE_TEMPLATE/edge_issue.md).

## Prepare an actionable issue

Require enough information to reproduce or evaluate the request:

- concise problem or proposal;
- affected component, exact edge-cores commit/tag and relevant submodule
  revisions, including local modifications or mismatches with the parent pin;
- minimal reproduction steps or motivating use case;
- observed and expected behavior;
- host, simulator/toolchain, and relevant configuration;
- exact failing command and short log excerpt; and
- whether reproduction uses the maintained public source flow or an older
  or private setup, without posting private source or symbol mappings.

For a bug, preserve the failing checkout before updating dependencies. Use
`git status --short` and `git submodule status` to identify local changes and
uninitialized or mismatched pins; inspect status inside the affected submodule
as needed. Do not replace a reporter's failing revision with current HEAD and
then claim the original problem was reproduced. A proposal instead needs a
concrete use case and affected contract, not an invented failing command.

For NNC environment failures, record the selected interpreter, PyTorch/NNC
versions and relevant `PYTHON` or `UV_PROJECT_ENVIRONMENT` override. The
workspace [NNC adapter](../../../../scripts/run-nnc.sh) checks that NNC is
editable from this checkout; an installed package of the same name elsewhere
is not equivalent. For simulator issues record `EDGE_VERILATOR_OUT` overrides
and which source revisions produced the binary. Request only relevant
configuration, not a full environment dump.

Search for duplicates before filing. Link related PRs and issues in edge-cores.
For a security-sensitive report, avoid public disclosure and follow any
repository security-reporting channel when one is configured.

## Route by ownership and failure boundary

Use the current `.gitmodules`, selected filelist and
[regression routing](../../../../tests/README.md) to assign ownership:

| Surface | Initial investigation |
| --- | --- |
| E3 product/DTCM/DMA/Tensor integration | `src/edge-e3`, workspace SoC/filelists and public build |
| Scalar execution, encoding, cache or FPU | `src/edge-32` and the E3 instruction boundary |
| Shared accelerator leaves | `src/edge-asic` and its product wiring |
| Compiler, runtime, layout or numerical semantics | `src/edge-nnc` and the selected Python environment |
| Workspace adapters/examples | `scripts/`, `tests/interface`, startup/intrinsics and the affected example |

Historical `edge-rv` or `edge-rv-lite` reports need their actual source revision
and configuration; those trees are not current checkout submodules. Older
template examples do not prove a path is present in the current product.

Choose the smallest test that reaches the failing boundary. NNC lowering may
start with `./tests/run.sh nnc-unit` or one smoke model. Runtime/RTL compatibility
uses `./tests/run.sh interface`; composed-model and cache-ownership failures
may require `./tests/run.sh nnc`. `example/llama/test.sh` delegates to that NNC
group. Use `./tests/run.sh all` for broad confirmation after a cross-layer fix,
not as the only way to diagnose every issue.

Separate setup/import, lowering, C++ build, simulator, numerical comparison
and performance failures. Read the failing case log and report, not just the
top-level exit code. Interface success requires its six-case completion marker
and simulator `TEST PASS`; model runners also check numerical comparison.
For `all`/`examples`, inspect `build/tests/<group>/summary.tsv`; for NNC, inspect
`src/edge-nnc/example/llama/build/harness/harness.md` and per-model logs. See
[review guide](review-guide.md) for evidence standards. A passing boundary
test does not prove every operator or another layer correct.

## Periodic agent review

For each new or updated issue, the review agent should:

1. Read the complete issue and linked edge-cores context.
2. Classify the affected surface and check for duplicates.
3. Verify referenced paths, commands, and revision against the repository.
4. Reproduce with the smallest safe public test when practical.
5. Prepare a concise status: reproducible, needs information, expected
   behavior, proposed work, fixed by a linked PR, or not currently actionable.
6. Ask only for missing information that would change the next action.
7. Link the proposed resolution and confirm validation of the reported case
   before recommending close. Distinguish a proposed fix from a merged fix,
   and record both component and parent revisions for a submodule integration.

Never claim reproduction without running it. Never initialize private RTL,
expose confidential information, or make external changes beyond the user's
authorization. Keep unresolved technical disagreement visible rather than
closing the issue merely because an automated review cycle completed.
Only post the prepared reply, change labels or close an issue when authorized;
reading this workflow does not create a recurring review schedule. Verify
existing repository labels before using them rather than treating the status
phrases above as predefined labels.

## Reply style

Lead with the current conclusion, then give evidence and the next concrete
step. Distinguish verified facts from hypotheses. When blocked, name the exact
missing log, command, revision, or decision instead of posting a generic status
message.
