// SPDX-License-Identifier: Apache-2.0
#include "libnn/ops.hpp"
#include "data.hpp"

extern "C" int main()
{
    using nnedge::Shape;
    using nnedge::Tensor;
    nnedge::reset_allocator();

    // One input row [1, K] produces [1, N]; packed weights include BF16 scales.
    Tensor<data::Bf16> x(Shape(1, 256), data::input);
    Tensor<data::Bf16> y(Shape(1, 8), data::output);
    // Packs are ordered [N/8, K/group_k].
    Tensor<data::Pack> weights(Shape(1, 8), data::weights);

    if (!nnedge::op::linear_fp4(y, x, weights))
        return 1;

    // The synchronous runtime returns with output ready for CPU reads.
    for (unsigned i = 0; i < 8; ++i)
        if (data::output[i].bits != data::expected_output[i])
            return 2;
    return 0;
}
