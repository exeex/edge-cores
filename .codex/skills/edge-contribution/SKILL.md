---
name: edge-contribution
description: Prepare, validate, submit, triage, and review contributions to edge-cores and its public E3, Edge-32, ASIC and NNC integrations. Use for centralized issues, contributor forks, RTL/software changes, regression selection, GitHub pull requests and evidence-backed review.
---

# Contribute to Edge RV

Help the community evolve edge-cores through small, tested, reviewable pull
requests. The maintained public product combines E3, Edge-32 and shared ASIC
RTL with NNC compiler/runtime software. Historical `edge-rv` and `edge-rv-lite`
trees are not current submodules; inspect `.gitmodules` and the selected
filelist before assigning implementation or test ownership.

## Work through a fork

1. Fork `https://github.com/exeex/edge-cores` into the contributor's GitHub
   account.
2. Clone the fork and add the canonical repository as `upstream`.
3. Create a focused branch from current `upstream/main`.
4. Keep unrelated changes out of the branch. Never commit build products,
   private RTL, credentials, or generated reports.
5. Modify public RTL in `src/edge-e3`, `src/edge-32` or `src/edge-asic`.
   NNC compiler/runtime changes belong in `src/edge-nnc`; workspace integration
   changes belong in the parent repository. Commit submodule changes in their
   owning repository and record the intended gitlink in edge-cores. A parent
   commit alone does not include modified submodule files. When publication is
   authorized, make referenced submodule commits accessible before publishing
   a parent pin; verify the combined revisions from a clean checkout.
   Private repositories mainly hold internal tests such as `src/test-e3`;
   preserve that boundary and keep the public build independent of them.
6. Rebase or merge current `upstream/main`, rerun affected tests, push the
   branch, and open a pull request against `exeex/edge-cores:main`.

Do not create a fork, push, or open a PR unless the user explicitly authorizes
that external action. Local branches, edits, and tests remain normal
implementation steps when requested.

## File every issue in edge-cores

Open all project issues at `https://github.com/exeex/edge-cores/issues`, even
when the affected code lives in `src/edge-e3`, `src/edge-nnc`, another
submodule, an example, or the software stack. Do not split community discussion
across submodule issue trackers.

Follow `.github/ISSUE_TEMPLATE/edge_issue.md` and include the affected area,
revision, reproduction steps, observed/expected behavior, environment, and
available logs. Search existing edge-cores issues first and add evidence to an
existing issue when it covers the same problem.

Read [references/issue-triage.md](references/issue-triage.md) when preparing an
issue for periodic agent review or when reviewing and replying to the issue
queue. Do not create, comment on, label, or close a GitHub issue unless the user
has authorized that external action.

## Make a reviewable change

- Read [CONTRIBUTING.md](../../../CONTRIBUTING.md) and
  [LICENSING.md](../../../LICENSING.md) before editing. Contributions to
  files maintained directly by edge-cores use `Apache-2.0`; contributions to a
  submodule use that component's license. Check the actual changed files:
  Edge-32 RTL uses `CERN-OHL-P-2.0`, E3 RTL has its own hardware license, and
  E3 SDK software and NNC use Apache-2.0. For shared ASIC leaves consult their
  `LICENSE.md`; do not infer one license for the entire checkout.
- State the problem and why it belongs in the shared Edge RV framework.
- Prefer one architectural idea or bug fix per PR.
- Add or update a focused test that fails without the change when practical.
- Preserve instruction encodings, module ports, parameter defaults, and
  software ABI unless the PR explicitly proposes a migration. Include physical
  tensor layout (`io_layout.json`) and CPU/DMA ownership in compatibility
  review when those surfaces change.
- Document correctness, performance, area, or complexity tradeoffs instead of
  presenting an optimization as universally better.
- Treat existing user changes as owned work; do not rewrite unrelated files.

## Validate before submission

Read [references/test-matrix.md](references/test-matrix.md) and the current
[regression routing](../../../tests/README.md), select tests from the changed
surfaces, and run the smallest relevant test first. Confirm commands against
`tests/run.sh` and its adapters when older guidance differs. A ready PR
must report exact commands and outcomes. Use a Draft PR when important tests
remain unavailable or failing, and explain why.

For changes to the public E3/Edge-32/shared ASIC integration, build the
reviewed RTL and run the basic public examples:

```sh
./scripts/build-verilator.sh
./example/hello/run.sh
./example/tensor/run.sh
./example/actu/run.sh
```

Also select coverage by boundary:

- Intrinsic/runtime/RTL compatibility: `./tests/run.sh interface` plus affected
  examples. The interface runner rebuilds the simulator by default; only use
  `--skip-verilator-build` with a simulator built from the reviewed sources.
- NNC lowering: `PYTHON=.venv/bin/python ./tests/run.sh nnc-unit` and affected
  smoke models. Prepare the environment with `./scripts/setup-python.sh`.
- Runtime, layout, allocator, DMA ownership or composed models:
  `./tests/run.sh nnc`, including unit discovery, the model harness and packed
  C++/cache-ownership regressions. `example/llama/test.sh` delegates here.
- Broad cross-layer changes: `./tests/run.sh all`, which includes NNC,
  interface and independent examples and reports individual failures.
- Documentation/skill-only changes: local link/format checks and
  `git diff --check`; a full RTL build is unnecessary.

Keep NNC semantic fixtures and goldens in NNC and workspace interface
sentinels in `tests/interface`. Inspect `build/tests/<group>/summary.tsv`,
the NNC harness report and relevant per-case logs. Require the runner's
completion and numerical markers, not just shell success; see the
[software harness](../software-harness/SKILL.md) for details. Record component
revisions and distinguish newly executed evidence from historical release
results. Generated logs and binaries remain local build products.

Do not write “all tests pass” unless the listed commands actually completed
successfully. Do not require private test repositories to make a public regression pass.

## Write the pull request

Follow `.github/pull_request_template.md`. Keep the PR body self-contained so
a maintainer or review agent can understand the change without reconstructing
the implementation from chat history. Include:

- problem, motivation, and scope;
- architectural, encoding, ABI, or compatibility impact;
- exact validation commands and PASS / FAIL / NOT RUN results;
- untested cases, known limitations, and risk;
- generated artifacts or benchmark assumptions, when relevant; and
- specific areas where review attention is requested.

Read [references/review-guide.md](references/review-guide.md) when reviewing a
PR or preparing it for agent-assisted review.

## Iterate after review

Answer review comments with code or evidence. Keep follow-up commits scoped,
rerun tests affected by each revision, and update the PR validation table.
Never hide a regression by loosening a golden result, tolerance, timeout, or
skip list without explaining and justifying that semantic change.

Before handoff, report the branch, changed files, tests run, remaining risks,
and whether the PR is draft or ready.
