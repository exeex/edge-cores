# C++ entry point for the public examples

This directory connects examples to the submodule APIs and supplies this
workspace's single-core RV32 execution environment. It contains real files,
without symlinks.

| Entry | Purpose |
| --- | --- |
| `libnn/ops.hpp` | Relative include of NNC's umbrella header, exposing all runtime operators |
| `intrinsic/edge_intrinsic.hpp` | Relative includes of the selected Edge-32 backend and E3 SDK, including scalar helpers and console |
| `intrinsic/edge_memory_map.hpp` | Workspace memory-map declarations, matching the linker symbols |
| `baremetal/crt0.s` | Initialize `.data` and `.bss`, power on the accelerator and handle simulator exit |
| `baremetal/linker.ld` | Single-core code/data, DTCM, model I/O and heap layout |
| `baremetal/soft_double.c` | RV32 floating-point promotion support for the example console |

Examples need only `-Icpp -Icpp/intrinsic` and these public headers:

```cpp
#include "intrinsic/edge_intrinsic.hpp"
#include "libnn/ops.hpp"
```

Add operators to `src/edge-nnc/cpp/libnn/ops.hpp` and product APIs to
`src/edge-e3/include/edge_e3/edge_intrinsic.hpp`. The outer entry headers
forward to those umbrella headers; do not mirror every implementation header
here. Memory-map, startup and linker settings remain workspace-owned.

Ordinary writable arrays with literal initializers use `.data`; the linker
places their initial bytes in ROM, and `crt0.s` copies them to RAM before
`main()`. Zero-initialized arrays use `.bss`, which startup clears. Examples
do not need generated model wrappers or special sections for these arrays.

Initialize `src/edge-e3`, `src/edge-32` and `src/edge-nnc` before building.
NNC's standalone runners retain their own environment and receive platform
SDK paths through `scripts/run-nnc.sh`. Keep the E3 SDK and NNC adapter
revisions matched in consuming workspaces.

The hardware-ID diagnostic source is `example/hello/hardware_id.cpp`.
