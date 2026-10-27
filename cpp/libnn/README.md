# Runtime operator entry point

[ops.hpp](ops.hpp) includes NNC's `cpp/libnn/ops.hpp` by relative path. That
submodule header exposes all runtime operators, including
`linear_weight_slots<EDGE_TENSOR_WTYPE_FP4>()`.

Examples use `#include "libnn/ops.hpp"` with `-Icpp`. Maintain operator
implementations and their umbrella includes in edge-nnc; this directory does
not mirror its individual operator headers.
