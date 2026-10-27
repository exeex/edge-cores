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

    Tensor<dtype> x_dtcm(nnedge::Shape{9, 64});
    nnedge::malloc_tensor(x_dtcm);
    if (!nnedge::copy_tensor_payload(x_dtcm, x)) return 1;

    Tensor<dtype> linear_fp8_e5m2(nnedge::Shape{9, 16});
    nnedge::malloc_tensor(linear_fp8_e5m2);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_0 = edge_get_cycle();
#endif
    if (!nnedge::op::linear_fp8_e5m2<64, true>(linear_fp8_e5m2, x_dtcm, ctx->linear_weight_fp8_e5m2_slots)) return 1;
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_0 =
        edge_get_cycle() - profile_start_0;
#endif

    Tensor<dtype> add(nnedge::Shape{9, 16});
    nnedge::malloc_tensor(add);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_1 = edge_get_cycle();
#endif
    Tensor<dtype> layout_1_0(nnedge::Shape{9, 16});
    nnedge::malloc_tensor_dram(layout_1_0);
    if (!nnedge::convert_tensor_layout(layout_1_0, linear_fp8_e5m2, false)) return 1;
    nnedge::op::add(add, layout_1_0, ctx->linear_bias, ctx->tensor_eye8, 1.0f);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_1 =
        edge_get_cycle() - profile_start_1;
#endif
    nnedge::free_tensor(layout_1_0);
    nnedge::free_tensor(linear_fp8_e5m2);
    if (!nnedge::copy_tensor_payload(y, add)) return 1;
#if NNEDGE_PROFILE
    printf("NNC_PROFILE_BEGIN\n");
    printf("NNC_PROFILE\t0\tlinear_fp8_e5m2\tlinear_fp8_e5m2\t%llu\n", (unsigned long long)profile_cycles_0);
    printf("NNC_PROFILE\t1\tadd\tadd\t%llu\n", (unsigned long long)profile_cycles_1);
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
