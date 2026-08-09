---
name: edge-contribution
description: Prepare, validate, submit, triage, and review open-source contributions to the shared Edge RV framework in edge-cores. Use when contributors need to file a centralized edge-cores issue, fork the repository, modify public edge-rv RTL or related software, choose regression tests, write a structured GitHub pull request, respond to review, or provide evidence suitable for human and agent-assisted issue and PR review.
---

# Contribute to Edge RV

Help the community evolve the shared public Edge RV framework through small,
tested, reviewable pull requests.

## Work through a fork

1. Fork `https://github.com/exeex/edge-cores` into the contributor's GitHub
   account.
2. Clone the fork and add the canonical repository as `upstream`.
3. Create a focused branch from current `upstream/main`.
4. Keep unrelated changes out of the branch. Never commit build products,
   private RTL, credentials, or generated reports.
5. Modify public source and tests. Preserve existing public/private boundaries;
   do not edit generated `src/edge-e3enc/edge_e3enc.v` as design source.
6. Rebase or merge current `upstream/main`, rerun affected tests, push the
   branch, and open a pull request against `exeex/edge-cores:main`.

Do not create a fork, push, or open a PR unless the user explicitly authorizes
that external action. Local branches, edits, and tests remain normal
implementation steps when requested.

## File every issue in edge-cores

Open all project issues at `https://github.com/exeex/edge-cores/issues`, even
when the affected code lives in `src/edge-rv`, `src/edge-e3enc`, another
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

- State the problem and why it belongs in the shared Edge RV framework.
- Prefer one architectural idea or bug fix per PR.
- Add or update a focused test that fails without the change when practical.
- Preserve instruction encodings, module ports, parameter defaults, and
  software ABI unless the PR explicitly proposes a migration.
- Document correctness, performance, area, or complexity tradeoffs instead of
  presenting an optimization as universally better.
- Treat existing user changes as owned work; do not rewrite unrelated files.

## Validate before submission

Read [references/test-matrix.md](references/test-matrix.md), select tests from
the changed surfaces, and run the smallest relevant test first. A ready PR
must report exact commands and outcomes. Use a Draft PR when important tests
remain unavailable or failing, and explain why.

For changes to public `src/edge-rv` RTL, run at least:

```sh
./scripts/build-verilator.sh
./example/hello/run.sh
./example/tensor/run.sh
./example/actu/run.sh
```

Add compiler/runtime and Llama regressions when those surfaces are affected.
Do not write “all tests pass” unless the listed commands actually completed
successfully. Do not initialize private RTL to make a public regression pass.

## Write the pull request

Follow `.github/pull_request_template.md`. Keep the PR body self-contained so
a maintainer or review agent can understand the change without reconstructing
the implementation from chat history. Include:

- problem, motivation, and scope;
- architectural, encoding, ABI, or compatibility impact;
- exact validation commands and PASS/FAIL results;
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
