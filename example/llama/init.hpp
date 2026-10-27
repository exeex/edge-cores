#pragma once

#include "libnn/ops.hpp"

namespace model {

using dtype = nnedge::bfloat16_t;
using nnedge::Tensor;
static_assert(sizeof(dtype) == 2, "NNC IO payloads require BF16");
static_assert(nnedge::kArenaAlign == 64, "NNC IO offsets require 64-byte alignment");

constexpr nnedge::size_t kWeightBytes = 172672;

struct Context {
    Tensor<dtype> attention_norm_weight;
    Tensor<dtype> tensor_eye8;
    Tensor<dtype> rms_square_mean_64;
    Tensor<dtype> rms_reduce_sum8;
    Tensor<dtype> attention_wq_weight;
    Tensor<dtype> attention_wk_weight;
    Tensor<dtype> attention_wv_weight;
    Tensor<dtype> rope_table;
    Tensor<dtype> attention_wo_weight;
    Tensor<dtype> ffn_norm_weight;
    Tensor<dtype> feed_forward_w1_weight;
    Tensor<dtype> feed_forward_w3_weight;
    Tensor<dtype> feed_forward_w2_weight;
};

namespace mio {

inline Context ctx;
inline Tensor<dtype> x;
inline nnedge::size_t start_pos;
inline Tensor<dtype> mask_or_params;
inline Tensor<dtype> y;

} // namespace mio

alignas(nnedge::kArenaAlign) inline unsigned char output_storage[4096]
    __attribute__((used, section(".nnedge_outputs")));

inline void init(Context *ctx, unsigned char *weight_base)
{
    ctx->attention_norm_weight = Tensor<dtype>(nnedge::Shape{64}, reinterpret_cast<dtype *>(weight_base + 0));
    ctx->tensor_eye8 = Tensor<dtype>(nnedge::Shape{8, 8}, reinterpret_cast<dtype *>(weight_base + 128));
    ctx->rms_square_mean_64 = Tensor<dtype>(nnedge::Shape{8, 8}, reinterpret_cast<dtype *>(weight_base + 256));
    ctx->rms_reduce_sum8 = Tensor<dtype>(nnedge::Shape{8, 8}, reinterpret_cast<dtype *>(weight_base + 384));
    ctx->attention_wq_weight = Tensor<dtype>(nnedge::Shape{64, 64}, reinterpret_cast<dtype *>(weight_base + 512));
    ctx->attention_wk_weight = Tensor<dtype>(nnedge::Shape{64, 64}, reinterpret_cast<dtype *>(weight_base + 8704));
    ctx->attention_wv_weight = Tensor<dtype>(nnedge::Shape{64, 64}, reinterpret_cast<dtype *>(weight_base + 16896));
    ctx->rope_table = Tensor<dtype>(nnedge::Shape{64, 8, 8, 8}, reinterpret_cast<dtype *>(weight_base + 25088));
    ctx->attention_wo_weight = Tensor<dtype>(nnedge::Shape{64, 64}, reinterpret_cast<dtype *>(weight_base + 90624));
    ctx->ffn_norm_weight = Tensor<dtype>(nnedge::Shape{64}, reinterpret_cast<dtype *>(weight_base + 98816));
    ctx->feed_forward_w1_weight = Tensor<dtype>(nnedge::Shape{192, 64}, reinterpret_cast<dtype *>(weight_base + 98944));
    ctx->feed_forward_w3_weight = Tensor<dtype>(nnedge::Shape{192, 64}, reinterpret_cast<dtype *>(weight_base + 123520));
    ctx->feed_forward_w2_weight = Tensor<dtype>(nnedge::Shape{64, 192}, reinterpret_cast<dtype *>(weight_base + 148096));
}

extern "C" const unsigned char weight_begin[];
extern "C" const unsigned char input_begin[];
extern "C" unsigned char output_begin[];

inline void init()
{
    nnedge::reset_allocator();
    init(&mio::ctx, const_cast<unsigned char *>(weight_begin));
    mio::x = Tensor<dtype>(nnedge::Shape{32, 64}, reinterpret_cast<dtype *>(const_cast<unsigned char *>(input_begin) + 0));
    mio::start_pos = 0;
    mio::mask_or_params = Tensor<dtype>(nnedge::Shape{32, 32}, reinterpret_cast<dtype *>(const_cast<unsigned char *>(input_begin) + 4096));
    mio::y = Tensor<dtype>(nnedge::Shape{32, 64}, reinterpret_cast<dtype *>(output_begin + 0));
}

} // namespace model
