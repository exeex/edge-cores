# Licensing

Unless a file or directory states otherwise, files maintained directly in the
edge-cores repository are licensed under the Apache License, Version 2.0
(`Apache-2.0`). This includes the C++ libraries, Python compiler and runtime
tools, scripts, examples, SoC harness RTL, documentation, and repository
automation. See `LICENSE`.

Git submodules and third-party material retain their own licenses. In
particular:

| Path | License |
| --- | --- |
| `src/edge-rv` | CERN Open Hardware Licence Version 2 - Permissive (`CERN-OHL-P-2.0`) |
| `src/edge-nnc` (also `cpp/libnn`) | Apache-2.0 |
| `src/edge-32` | CERN Open Hardware Licence Version 2 - Permissive (`CERN-OHL-P-2.0`) |
| `src/edge-e3` RTL | edge-e3 Hardware License 1.0 |
| `src/edge-e3/include` software SDK (also `cpp/intrinsic`) | Apache-2.0 |
| `src/edge-asic` | Applicable Edge product source license; see its LICENSE.md |
| `src/test-e3`, `src/test-rv` (optional private tests) | License declared by the corresponding repository |
| `third_party/coremark` | Upstream project license |

A root checkout does not relicense submodule contents. When redistributing a
combined checkout, release package, or binary, comply with every applicable
component license and retain its notices.
