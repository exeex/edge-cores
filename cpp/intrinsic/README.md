# Product API entry point and workspace memory map

[edge_intrinsic.hpp](edge_intrinsic.hpp) selects the Edge-32 instruction
backend and includes the [E3 SDK](../../src/edge-e3/include/README.md) by relative
path. This single entry exposes accelerator APIs, scalar-format helpers and
simulator console support.

[edge_memory_map.hpp](edge_memory_map.hpp) is workspace-owned and declares the
DTCM symbols defined by `../baremetal/linker.ld`. Keep memory layout changes
consistent with that script and `../baremetal/crt0.s`.

Examples use `#include "intrinsic/edge_intrinsic.hpp"` with
`-Icpp -Icpp/intrinsic`. Maintain product APIs in edge-e3; do not add separate
workspace forwarding headers for its implementation files.
