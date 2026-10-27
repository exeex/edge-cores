#pragma once

#include "libnn/ops.hpp"

namespace model {

using dtype = nnedge::bfloat16_t;
using nnedge::Tensor;
static_assert(sizeof(dtype) == 2, "NNC IO payloads require BF16");
static_assert(nnedge::kArenaAlign == 64, "NNC IO offsets require 64-byte alignment");

constexpr nnedge::size_t kWeightBytes = 576;

struct Context {
    Tensor<uint8_t> linear_weight_nvfp4_slots;
};

namespace mio {

inline Context ctx;
inline Tensor<dtype> x;
inline Tensor<dtype> y;

} // namespace mio

alignas(nnedge::kArenaAlign) inline unsigned char output_storage[320]
    __attribute__((used, section(".nnedge_outputs")));

inline void init(Context *ctx, unsigned char *weight_base)
{
    ctx->linear_weight_nvfp4_slots = Tensor<uint8_t>(nnedge::Shape{576}, reinterpret_cast<uint8_t *>(weight_base + 0));
}

extern "C" const unsigned char weight_begin[];
extern "C" const unsigned char input_begin[];
extern "C" unsigned char output_begin[];

inline void init()
{
    nnedge::reset_allocator();
    init(&mio::ctx, const_cast<unsigned char *>(weight_begin));
    mio::x = Tensor<dtype>(nnedge::Shape{9, 64}, reinterpret_cast<dtype *>(const_cast<unsigned char *>(input_begin) + 0));
    edge_dcache_clean_range(mio::x.data, nnedge::numel(mio::x) * sizeof(dtype));
    mio::y = Tensor<dtype>(nnedge::Shape{9, 16}, reinterpret_cast<dtype *>(output_begin + 0));
}

} // namespace model
