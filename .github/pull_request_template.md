## Problem and motivation

<!-- What problem does this solve, and why should it live in the shared Edge RV framework? -->

## Changes

<!-- Summarize the implementation. Keep unrelated work out of this PR. -->

## Architecture and compatibility

<!-- Describe effects on instruction encodings, RTL ports/parameters, snapshot or ordering behavior, software ABI, and existing users. Write "None" when applicable. -->

## Validation

| Command | Result | Evidence or notes |
| --- | --- | --- |
| `command` | PASS / FAIL / NOT RUN | report, output, or reason not run |

<!-- For public src/edge-rv RTL, normally include build-verilator, hello, tensor, and ACTU. Add NNC/Llama tests when affected. -->

## Risks and limitations

<!-- List untested cases, known limitations, migration concerns, performance/PPA assumptions, or remaining follow-up work. -->

## Review focus

<!-- Point maintainers and review agents to the highest-risk files, invariants, or design decisions. -->

## Checklist

- [ ] This PR contains one focused contribution and no unrelated changes.
- [ ] I added or updated tests where practical.
- [ ] I recorded exact test commands and did not report unrun tests as passing.
- [ ] I checked `git diff --check` and reviewed the complete diff.
- [ ] I did not commit generated build output, private RTL, credentials, or symbol mappings.
- [ ] I documented compatibility changes and benchmark assumptions, or marked them not applicable.
- [ ] I have the right to submit this contribution under the license applicable to the changed files.
