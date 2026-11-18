# Paper and artifact release

Use this workflow after the custom ASIC passes functional and performance
validation. Read [paper-evaluation.md](paper-evaluation.md) first to separate edge-cores prior work
from the downstream paper's contribution claims.

## Contents

- [Choose a release form](#choose-a-release-form)
- [Keep internal tests private](#keep-internal-tests-private)
- [Build the artifact](#build-the-artifact)
- [Reproduce from public dependencies](#reproduce-from-public-dependencies)
- [Cite edge-cores](#cite-edge-cores)

## Choose a release form

Publish the custom ASIC RTL as source when redistribution is authorized.
Include public Edge RTL through its pinned repositories and retain every
applicable license. If RTL redistribution is not authorized, publish only the
permitted software traces or results and state the reproduction limitation.

E3, Edge32 and shared ASIC RTL use the public source flow. Build directly from
their declared filelists and the workspace's SRAM behavioral models.
The current product uses Edge-32/E3; a historical RV64 artifact needs its own
declared sources and revisions. Consult [LICENSING.md](../../../../LICENSING.md)
and each component's license instead of assigning the root license to the
entire bundle. Keep the E3 software SDK and hardware license boundaries clear.

## Keep internal tests private

Private repositories mainly contain internal test suites such as `src/test-e3`.
Do not copy those suites, private paths, credentials or unlicensed dependencies
into the public artifact. Supply public examples and expected results that
validate the published interface without requiring private tests. Public
source availability does not authorize publishing internal test material.

## Build the artifact

Include:

- compiler, simulator, and host dependency versions;
- exact edge-cores commit and tag when present, plus each included submodule's
  path, URL and full commit hash;
- intrinsic header and example program using `set_*`, `start`, and final
  `sync`;
- public RTL revisions, top/filelists, defines and SRAM model/layout choices;
- scripts for functional tests and benchmark reproduction;
- expected checksums and concise expected output;
- workload shapes, clock assumption, cycle-count boundaries, and whether
  numbers are simulation or silicon measurements; and
- a license and attribution statement for edge-cores and every redistributed
  dependency.

For NNC models, record the compiler/runtime revision and environment/lockfiles.
Preserve generated headers, payloads and `io_layout.json` as a matched set,
with regeneration commands and logical golden checks. A saved example replay
and a fresh model compilation validate different parts of the artifact.

For benchmark claims retain the relevant results, numerical checks, source
hashes, tool/simulator provenance and baseline revisions. The
[v0.3.1 validation record](../../../../docs/releases/v0.3.1-validation.md)
illustrates this evidence; its PASS results do not validate a new artifact.
Keep normal build output ignored, and deliberately select the logs/checksums
needed for the published artifact rather than committing an entire build tree.

A parent commit records submodule gitlinks, not uncommitted component edits.
Commit intended changes in the owning repositories and, when publication is
authorized, make those revisions accessible before publishing the parent pin.
Do not release a parent reference that consumers cannot fetch. A source-only
archive of the parent does not include submodule contents; provide explicit
checkout instructions or an authorized bundle with a component manifest.

## Reproduce from public dependencies

Start from a clean checkout of the exact artifact commit. For the current
E3/NNC public flow, initialize only the needed public paths:

```sh
git submodule update --init --recursive -- src/edge-e3 src/edge-32 src/edge-asic src/edge-nnc
git submodule status -- src/edge-e3 src/edge-32 src/edge-asic src/edge-nnc
```

Add the custom design's declared submodule and other public dependencies only
when the artifact requires them. For example, CoreMark needs
`third_party/coremark`; the documentation renderer is a separate dependency.
Avoid an unqualified recursive initialization for a public-only reproduction:
the current `.gitmodules` also lists optional private `src/test-e3`.
Use pinned commits, not `git submodule update --remote`, for reproduction.

Follow [verification.md](verification.md) and
[regression routing](../../../../tests/README.md) for setup and checks. A broad
E3/NNC artifact can use `./scripts/setup-python.sh` then `./tests/run.sh all`;
include a public test that actually reaches the custom accelerator. Existing
examples alone do not validate an unexercised custom top. Compare both saved
artifact replay and regeneration when compiler/layout changes are involved.

Record PASS / FAIL / NOT RUN for each command, inspect detailed reports and
numerical markers, and state unavailable tests or dependencies. Verify declared
checksums and output paths from that clean checkout without private tests.
An intentionally limited software/results artifact must say which RTL or
physical-design steps cannot be reproduced.

Prepare the local bundle and release description before publishing. Creating
remote repositories, pushing tags/commits or publishing a release requires
the user's authorization; this document by itself does not authorize them.

## Cite edge-cores

For any paper using this core or custom-ASIC integration, cite:

`https://github.com/exeex/edge-cores`

Use the repository root [references.bib](../../../../references.bib) entry with
key `wu_edge_cores_2026` (`\cite{wu_edge_cores_2026}`).
Record the exact experiment revision separately because the canonical entry
points to the evolving repository. In prose, distinguish repository RTL
simulation results from manufactured-silicon measurements.
