---
name: rtl-release-packager
description: Generate, compare, validate, and prepare mixed public/private RTL release packages with symbol-obfuscated proprietary RTL and unchanged public RTL dependencies. Use for encrypted or obfuscated Verilog/SystemVerilog releases, source-available ASIC simulation packages, private-to-public RTL ABI boundaries, edge-e3enc regeneration, deterministic release diffs, or publishing an RTL release submodule without exposing private source or symbol mappings.
---

# RTL release packager

Use `tools/package_obfuscated_rtl.py` for the generic flow and
`tools/obfuscate_edge_e3.py` for the backward-compatible edge-e3 defaults.

## Protect the boundary

- Confirm the user is authorized to read the private RTL before initializing or
  accessing a private submodule.
- Never add a symbol mapping, private source path contents, credentials, or
  unlicensed RTL to the public repository.
- Treat obfuscation as reverse-engineering resistance, not cryptographic secrecy.
- Require a clean output submodule before overwriting it. Stop if it contains
  unrelated edits.
- Do not commit or push the output submodule or parent gitlink unless requested.

## Generate a package

Resolve every private root, the public root, production filelist, SoC boundary,
license, output submodule, top module, and SoC core module. The maintained
`edge-cores` defaults obfuscate both `src/edge-e3` and `src/edge-asic`, leaving
only `src/edge-32` as unchanged public RTL:

```sh
python3 tools/package_obfuscated_rtl.py
```

For another checkout, pass `--private-root` once for each private source tree.
For another design, set at least `--product-name`, `--artifact-stem`,
`--namespace`, `--top`, `--soc-top`, `--soc-core-module`, and
`--regenerate-command`. Add `--sram-pattern` or `--keep` only for genuine hard
macro boundaries or stable public ABI symbols.

The generator must pass all built-in Verilator stages before replacing the
output: source elaboration, mixed public/private elaboration, and SoC boundary
elaboration. Preserve the output submodule's `.git` entry.

## Review deterministic output

Inspect the output submodule, not only the parent gitlink:

```sh
git -C src/edge-e3enc status --short
git -C src/edge-e3enc diff --stat
git -C src/edge-e3enc diff -- manifest.json '*.fl' README.md LICENSE.md
git -C src/edge-e3enc diff -- edge_e3enc.v edge_e3enc_sram.v
```

Accept metadata, documentation, or generator-banner changes only when expected.
Investigate changes to filelists, module headers, port names, license text,
symbol counts, or RTL bodies. For a banner-only RTL change, compare body hashes:

```sh
git -C src/edge-e3enc show HEAD:edge_e3enc.v | tail -n +2 | shasum -a 256
tail -n +2 src/edge-e3enc/edge_e3enc.v | shasum -a 256
```

Use `sha256sum` instead of `shasum -a 256` where appropriate.

## Validate the public consumer

Use a checkout with only `src/edge-32` and `src/edge-e3enc` initialized.
Keep `src/edge-e3`, `src/edge-asic`, and `src/test-e3` absent, then run:

```sh
./scripts/build-verilator.sh
./example/hello/run.sh
./example/tensor/run.sh
```

Require `TEST PASS` in both reports. Never initialize private RTL merely to make
the public build pass.

## Restore or publish

For a comparison-only run, restore the output submodule exactly:

```sh
git -C src/edge-e3enc reset --hard HEAD
git -C src/edge-e3enc clean -fd
```

For a release, review and commit inside the output submodule first, push it only
with explicit authorization, then update and commit the parent gitlink. Report
the two commits separately.
