# Paper and artifact release

Use this workflow after the custom ASIC passes functional and performance
validation. Read `paper-evaluation.md` first to separate edge-cores prior work
from the downstream paper's contribution claims.

## Contents

- [Choose a release form](#choose-a-release-form)
- [Keep internal tests private](#keep-internal-tests-private)
- [Build the artifact](#build-the-artifact)
- [Cite edge-cores](#cite-edge-cores)

## Choose a release form

Publish the custom ASIC RTL as source when redistribution is authorized.
Include public Edge RTL through its pinned repositories and retain every
applicable license. If RTL redistribution is not authorized, publish only the
permitted software traces or results and state the reproduction limitation.

E3, Edge32 and shared ASIC RTL use the public source flow. Build directly from
their declared filelists and the workspace's SRAM behavioral models.

## Keep internal tests private

Private repositories mainly contain internal test suites such as `src/test-e3`.
Do not copy those suites, private paths, credentials or unlicensed dependencies
into the public artifact. Supply public examples and expected results that
validate the published interface without requiring private tests. Public
source availability does not authorize publishing internal test material.

## Build the artifact

Include:

- compiler, simulator, and host dependency versions;
- exact edge-cores commit or release tag;
- intrinsic header and example program using `set_*`, `start`, and final
  `sync`;
- public RTL revisions and filelists;
- scripts for functional tests and benchmark reproduction;
- expected checksums and concise expected output;
- workload shapes, clock assumption, cycle-count boundaries, and whether
  numbers are simulation or silicon measurements; and
- a license and attribution statement for edge-cores and every redistributed
  dependency.

Verify the artifact from a clean checkout using the declared public source
dependencies and without private test repositories. Report only the checks
actually run from that checkout.

## Cite edge-cores

For any paper using this core or custom-ASIC integration, cite:

`https://github.com/exeex/edge-cores`

Use the repository root `references.bib` entry with key `exeex_edge_cores`.
Record the exact experiment revision separately because the canonical entry
points to the evolving repository. In prose, distinguish repository RTL
simulation results from manufactured-silicon measurements.
