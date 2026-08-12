# Paper and artifact release

Use this workflow after the custom ASIC passes functional and performance
validation. Read `paper-evaluation.md` first to separate edge-cores prior work
from the downstream paper's contribution claims.

## Contents

- [Choose a release form](#choose-a-release-form)
- [Protect proprietary RTL](#protect-proprietary-rtl)
- [Build the artifact](#build-the-artifact)
- [Cite edge-cores](#cite-edge-cores)

## Choose a release form

Choose one of these forms explicitly:

1. Publish the custom ASIC RTL as source when disclosure is acceptable.
2. Publish a mixed package containing unchanged public Edge RV64 RTL and
   obfuscated proprietary ASIC RTL when reviewers need simulation and
   reproduction but source disclosure would compromise later publication or
   commercialization.
3. Publish only software traces or results when RTL redistribution is not
   authorized; state that limitation clearly and do not call the artifact
   fully reproducible.

Prefer the least restrictive form permitted by the authors' disclosure and
license constraints. Never obfuscate merely to conceal missing evidence.

## Protect proprietary RTL

Use the `rtl-release-packager` skill. Keep the public/private ABI stable and
leave public RTL dependencies unchanged. Generate the protected artifact from
the authorized private tree into a separate output or release submodule.

Require all of the following before release:

- no private source path contents, symbol mapping, credentials, or unlicensed
  dependency in the package;
- deterministic manifest and hashes;
- successful source, mixed-boundary, and SoC elaboration;
- successful public consumer smoke tests without private submodules; and
- reviewed license and attribution files.

Describe the result as symbol-obfuscated or protected RTL. Do not claim
cryptographic secrecy or guaranteed resistance to reverse engineering or AI
analysis unless a separately audited encryption mechanism supports that
claim.

## Build the artifact

Include:

- compiler, simulator, and host dependency versions;
- exact edge-cores commit or release tag;
- intrinsic header and example program using `set_*`, `start`, and final
  `sync`;
- RTL/filelist or protected RTL manifest;
- scripts for functional tests and benchmark reproduction;
- expected checksums and concise expected output;
- workload shapes, clock assumption, cycle-count boundaries, and whether
  numbers are simulation or silicon measurements; and
- a license and attribution statement for edge-cores and every redistributed
  dependency.

Verify the artifact from a clean checkout with private source deinitialized.
Do not report the private build as evidence that the public package works.

## Cite edge-cores

For any paper using this core or custom-ASIC integration, cite:

`https://github.com/exeex/edge-cores`

Use the repository root `references.bib` entry with key `exeex_edge_cores`.
Record the exact experiment revision separately because the canonical entry
points to the evolving repository. In prose, distinguish repository RTL
simulation results from manufactured-silicon measurements.
