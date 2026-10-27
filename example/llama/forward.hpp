#pragma once

#include "init.hpp"

#ifndef NNEDGE_PROFILE
#define NNEDGE_PROFILE 0
#endif

#if NNEDGE_PROFILE
#include "edge_intrinsic.hpp"
#endif

namespace model {

int forward(Tensor<dtype> y,
            Tensor<dtype> x,
            nnedge::size_t start_pos,
            Tensor<dtype> mask_or_params,
            Context *ctx)
{

    Tensor<dtype> x_dtcm(nnedge::Shape{32, 64});
    nnedge::malloc_tensor(x_dtcm);
    if (!nnedge::copy_tensor_payload(x_dtcm, x)) return 1;

    Tensor<dtype> mask_or_params_dtcm(nnedge::Shape{32, 32});
    nnedge::malloc_tensor(mask_or_params_dtcm);
    if (!nnedge::copy_tensor_payload(mask_or_params_dtcm, mask_or_params)) return 1;

    Tensor<dtype> rms_norm(nnedge::Shape{32, 64});
    nnedge::malloc_tensor(rms_norm);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_0 = edge_get_cycle();
#endif
    nnedge::op::rms_norm(rms_norm, x_dtcm, ctx->attention_norm_weight, ctx->tensor_eye8, ctx->rms_reduce_sum8, ctx->rms_square_mean_64, 1e-05f);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_0 =
        edge_get_cycle() - profile_start_0;
#endif

    Tensor<dtype> linear(nnedge::Shape{32, 64});
    nnedge::malloc_tensor(linear);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_1 = edge_get_cycle();
#endif
    nnedge::op::linear(linear, rms_norm, ctx->attention_wq_weight, nnedge::Quant::bf16, nnedge::Tile::auto_);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_1 =
        edge_get_cycle() - profile_start_1;
#endif

    Tensor<dtype> linear_1(nnedge::Shape{32, 64});
    nnedge::malloc_tensor(linear_1);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_2 = edge_get_cycle();
#endif
    nnedge::op::linear(linear_1, rms_norm, ctx->attention_wk_weight, nnedge::Quant::bf16, nnedge::Tile::auto_);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_2 =
        edge_get_cycle() - profile_start_2;
#endif

    Tensor<dtype> linear_2(nnedge::Shape{32, 64});
    nnedge::malloc_tensor(linear_2);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_3 = edge_get_cycle();
#endif
    nnedge::op::linear(linear_2, rms_norm, ctx->attention_wv_weight, nnedge::Quant::bf16, nnedge::Tile::auto_);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_3 =
        edge_get_cycle() - profile_start_3;
#endif
    nnedge::free_tensor(rms_norm);

    Tensor<dtype> getitem(nnedge::Shape{32, 64});
    nnedge::malloc_tensor(getitem);
    Tensor<dtype> getitem_1(nnedge::Shape{32, 64});
    nnedge::malloc_tensor(getitem_1);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_4 = edge_get_cycle();
#endif
    nnedge::op::rope(getitem, getitem_1, linear, linear_1, start_pos, ctx->rope_table);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_4 =
        edge_get_cycle() - profile_start_4;
#endif
    nnedge::free_tensor(linear);
    nnedge::free_tensor(linear_1);

    Tensor<dtype> getitem_2(nnedge::Shape{32, 64});
    nnedge::malloc_tensor_dram(getitem_2);
    Tensor<dtype> getitem_3(nnedge::Shape{32, 64});
    nnedge::malloc_tensor_dram(getitem_3);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_5 = edge_get_cycle();
#endif
    nnedge::op::kv_cache_update(getitem_2, getitem_3, getitem_1, linear_2, start_pos);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_5 =
        edge_get_cycle() - profile_start_5;
#endif
    nnedge::free_tensor(getitem_1);
    nnedge::free_tensor(linear_2);

    Tensor<dtype> attention_scores(nnedge::Shape{2, 32, 32});
    nnedge::malloc_tensor(attention_scores);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_6 = edge_get_cycle();
#endif
    Tensor<dtype> layout_6_0(nnedge::Shape{32, 64});
    nnedge::malloc_tensor(layout_6_0);
    if (!nnedge::convert_tensor_layout(layout_6_0, getitem, true)) return 1;
    nnedge::op::matmul_transpose(attention_scores, layout_6_0, getitem_2, 2u); if (nnedge::alloc_failed()) return 1;
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_6 =
        edge_get_cycle() - profile_start_6;
#endif
    nnedge::free_tensor(layout_6_0);
    nnedge::free_tensor(getitem);
    nnedge::free_tensor(getitem_2);

    Tensor<dtype> attention_prob(nnedge::Shape{2, 32, 32});
    nnedge::malloc_tensor(attention_prob);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_7 = edge_get_cycle();
#endif
    Tensor<dtype> layout_7_0(nnedge::Shape{2, 32, 32});
    nnedge::malloc_tensor_dram(layout_7_0);
    if (!nnedge::convert_tensor_layout(layout_7_0, attention_scores, false)) return 1;
    nnedge::op::softmax(attention_prob, layout_7_0, ctx->tensor_eye8, 2u);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_7 =
        edge_get_cycle() - profile_start_7;
#endif
    nnedge::free_tensor(layout_7_0);
    nnedge::free_tensor(attention_scores);

    Tensor<dtype> attention(nnedge::Shape{32, 64});
    nnedge::malloc_tensor(attention);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_8 = edge_get_cycle();
#endif
    Tensor<dtype> layout_8_0(nnedge::Shape{2, 32, 32});
    nnedge::malloc_tensor(layout_8_0);
    if (!nnedge::convert_tensor_layout(layout_8_0, attention_prob, true)) return 1;
    nnedge::op::matmul(attention, layout_8_0, getitem_3, 2u); if (nnedge::alloc_failed()) return 1;
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_8 =
        edge_get_cycle() - profile_start_8;
#endif
    nnedge::free_tensor(layout_8_0);
    nnedge::free_tensor(attention_prob);
    nnedge::free_tensor(getitem_3);

    Tensor<dtype> linear_3(nnedge::Shape{32, 64});
    nnedge::malloc_tensor(linear_3);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_9 = edge_get_cycle();
#endif
    Tensor<dtype> layout_9_0(nnedge::Shape{32, 64});
    nnedge::malloc_tensor_dram(layout_9_0);
    if (!nnedge::convert_tensor_layout(layout_9_0, attention, false)) return 1;
    nnedge::op::linear(linear_3, layout_9_0, ctx->attention_wo_weight, nnedge::Quant::bf16, nnedge::Tile::auto_);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_9 =
        edge_get_cycle() - profile_start_9;
#endif
    nnedge::free_tensor(layout_9_0);
    nnedge::free_tensor(attention);

    Tensor<dtype> add(nnedge::Shape{32, 64});
    nnedge::malloc_tensor(add);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_10 = edge_get_cycle();
#endif
    nnedge::op::add(add, x_dtcm, linear_3, ctx->tensor_eye8, 1.0f);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_10 =
        edge_get_cycle() - profile_start_10;
#endif
    nnedge::free_tensor(linear_3);

    Tensor<dtype> rms_norm_1(nnedge::Shape{32, 64});
    nnedge::malloc_tensor(rms_norm_1);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_11 = edge_get_cycle();
#endif
    nnedge::op::rms_norm(rms_norm_1, add, ctx->ffn_norm_weight, ctx->tensor_eye8, ctx->rms_reduce_sum8, ctx->rms_square_mean_64, 1e-05f);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_11 =
        edge_get_cycle() - profile_start_11;
#endif

    Tensor<dtype> linear_4(nnedge::Shape{32, 192});
    nnedge::malloc_tensor(linear_4);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_12 = edge_get_cycle();
#endif
    nnedge::op::linear(linear_4, rms_norm_1, ctx->feed_forward_w1_weight, nnedge::Quant::bf16, nnedge::Tile::auto_);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_12 =
        edge_get_cycle() - profile_start_12;
#endif

    Tensor<dtype> linear_5(nnedge::Shape{32, 192});
    nnedge::malloc_tensor(linear_5);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_13 = edge_get_cycle();
#endif
    nnedge::op::linear(linear_5, rms_norm_1, ctx->feed_forward_w3_weight, nnedge::Quant::bf16, nnedge::Tile::auto_);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_13 =
        edge_get_cycle() - profile_start_13;
#endif
    nnedge::free_tensor(rms_norm_1);

    Tensor<dtype> silu(nnedge::Shape{32, 192});
    nnedge::malloc_tensor(silu);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_14 = edge_get_cycle();
#endif
    nnedge::op::silu(silu, linear_4);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_14 =
        edge_get_cycle() - profile_start_14;
#endif
    nnedge::free_tensor(linear_4);

    Tensor<dtype> mul(nnedge::Shape{32, 192});
    nnedge::malloc_tensor(mul);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_15 = edge_get_cycle();
#endif
    nnedge::op::mul(mul, silu, linear_5, ctx->tensor_eye8);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_15 =
        edge_get_cycle() - profile_start_15;
#endif
    nnedge::free_tensor(silu);
    nnedge::free_tensor(linear_5);

    Tensor<dtype> linear_6(nnedge::Shape{32, 64});
    nnedge::malloc_tensor(linear_6);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_16 = edge_get_cycle();
#endif
    nnedge::op::linear(linear_6, mul, ctx->feed_forward_w2_weight, nnedge::Quant::bf16, nnedge::Tile::auto_);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_16 =
        edge_get_cycle() - profile_start_16;
#endif
    nnedge::free_tensor(mul);

    Tensor<dtype> add_1(nnedge::Shape{32, 64});
    nnedge::malloc_tensor(add_1);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_start_17 = edge_get_cycle();
#endif
    nnedge::op::add(add_1, add, linear_6, ctx->tensor_eye8, 1.0f);
#if NNEDGE_PROFILE
    const nnedge::size_t profile_cycles_17 =
        edge_get_cycle() - profile_start_17;
#endif
    nnedge::free_tensor(add);
    nnedge::free_tensor(linear_6);
    if (!nnedge::copy_tensor_payload(y, add_1)) return 1;
#if NNEDGE_PROFILE
    printf("NNC_PROFILE_BEGIN\n");
    printf("NNC_PROFILE\t0\trms_norm\trms_norm\t%llu\n", (unsigned long long)profile_cycles_0);
    printf("NNC_PROFILE\t1\tlinear\tlinear\t%llu\n", (unsigned long long)profile_cycles_1);
    printf("NNC_PROFILE\t2\tlinear_1\tlinear\t%llu\n", (unsigned long long)profile_cycles_2);
    printf("NNC_PROFILE\t3\tlinear_2\tlinear\t%llu\n", (unsigned long long)profile_cycles_3);
    printf("NNC_PROFILE\t4\tgetitem,getitem_1\trope\t%llu\n", (unsigned long long)profile_cycles_4);
    printf("NNC_PROFILE\t5\tgetitem_2,getitem_3\tkv_cache_update\t%llu\n", (unsigned long long)profile_cycles_5);
    printf("NNC_PROFILE\t6\tattention_scores\tmatmul_transpose\t%llu\n", (unsigned long long)profile_cycles_6);
    printf("NNC_PROFILE\t7\tattention_prob\tsoftmax\t%llu\n", (unsigned long long)profile_cycles_7);
    printf("NNC_PROFILE\t8\tattention\tmatmul\t%llu\n", (unsigned long long)profile_cycles_8);
    printf("NNC_PROFILE\t9\tlinear_3\tlinear\t%llu\n", (unsigned long long)profile_cycles_9);
    printf("NNC_PROFILE\t10\tadd\tadd\t%llu\n", (unsigned long long)profile_cycles_10);
    printf("NNC_PROFILE\t11\trms_norm_1\trms_norm\t%llu\n", (unsigned long long)profile_cycles_11);
    printf("NNC_PROFILE\t12\tlinear_4\tlinear\t%llu\n", (unsigned long long)profile_cycles_12);
    printf("NNC_PROFILE\t13\tlinear_5\tlinear\t%llu\n", (unsigned long long)profile_cycles_13);
    printf("NNC_PROFILE\t14\tsilu\tsilu\t%llu\n", (unsigned long long)profile_cycles_14);
    printf("NNC_PROFILE\t15\tmul\tmul\t%llu\n", (unsigned long long)profile_cycles_15);
    printf("NNC_PROFILE\t16\tlinear_6\tlinear\t%llu\n", (unsigned long long)profile_cycles_16);
    printf("NNC_PROFILE\t17\tadd_1\tadd\t%llu\n", (unsigned long long)profile_cycles_17);
    printf("NNC_PROFILE_END\n");
#endif
    return 0;
}

inline int forward(Tensor<dtype> y, Tensor<dtype> x)
{
    return forward(y, x, mio::start_pos, mio::mask_or_params, &mio::ctx);
}

inline int forward()
{
    return forward(mio::y, mio::x, mio::start_pos, mio::mask_or_params, &mio::ctx);
}

} // namespace model
