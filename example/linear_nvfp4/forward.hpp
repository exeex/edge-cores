#pragma once

#include "init.hpp"

#ifndef NNEDGE_PROFILE
#define NNEDGE_PROFILE 0
#endif

#if NNEDGE_PROFILE
#include "edge_intrinsic.hpp"
#endif

namespace model {

int forward(Tensor<dtype> y, Tensor<dtype> x, Context *ctx)
{

    Tensor<dtype> linear_nvfp4(nnedge::Shape{9, 16});
    nnedge::malloc_tensor_dram(linear_nvfp4);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_0 = edge_get_cycle();
#endif
    if (!nnedge::op::linear_nvfp4(linear_nvfp4, x, ctx->linear_weight_nvfp4_slots, 0x38430000u)) return 1;
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_0 =
        edge_get_cycle() - profile_start_0;
#endif
    nnedge::copy(y, linear_nvfp4);
#if NNEDGE_PROFILE
    printf("NNC_PROFILE_BEGIN\n");
    printf("NNC_PROFILE\t0\tlinear_nvfp4\tlinear_nvfp4\t%llu\n", (unsigned long long)profile_cycles_0);
    printf("NNC_PROFILE_END\n");
#endif
    return 0;
}

inline int forward(Tensor<dtype> y, Tensor<dtype> x)
{
    return forward(y, x, &mio::ctx);
}

inline int forward()
{
    return forward(mio::y, mio::x, &mio::ctx);
}

} // namespace model
