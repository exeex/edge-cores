# Runtime operator entry point

[ops.hpp](ops.hpp) includes NNC's `cpp/libnn/ops.hpp` by relative path. That
submodule header exposes all runtime operators, including
`linear_weight_slots(y, x, Tensor<WeightPack<...>>)`. The pack element type
encodes weight type, scale type, tiles per group, and scale count.
NNC's `linear_quant.hpp` defines the thin named presets `linear_fp4`,
`linear_q8_0`, `linear_fp8_e4m3fn`, and `linear_fp8_e5m2`; all use that kernel
with fixed K32/eight-BF16-scale layouts. Each accepts typed packs or serialized
bytes. FP4 codegen uses the named FP4 entry; FP8/Q8 graph lowering is not yet
implemented. Q8_0 payloads must be converted to the E3 runtime layout.

Examples use `#include "libnn/ops.hpp"` with `-Icpp`. Maintain operator
implementations and their umbrella includes in edge-nnc; this directory does
not mirror its individual operator headers.
