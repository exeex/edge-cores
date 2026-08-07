#pragma once

#include "matmul.hpp"
#include "softmax.hpp"
#include "tensor.hpp"

namespace nnedge::op {

template <typename DType>
inline void attention(Tensor<DType> y, Tensor<DType> xq, Tensor<DType> keys,
                      Tensor<DType> values, Tensor<DType> mask_or_params,
                      Tensor<DType> eye_weight, size_t head_count)
{
    (void)mask_or_params;

    Tensor<DType> score(Shape{head_count, xq.shape.dims[0], keys.shape.dims[0]});
    Tensor<DType> prob(Shape{head_count, xq.shape.dims[0], keys.shape.dims[0]});
    malloc_tensor_dram(score);
    malloc_tensor_dram(prob);

    matmul_transpose(score, xq, keys, head_count);
    softmax(prob, score, eye_weight, head_count);
    matmul(y, prob, values, head_count);

    free_tensor(prob);
    free_tensor(score);
}

template <typename DType>
inline void attention(Tensor<DType> y, Tensor<DType> xq, Tensor<DType> keys,
                      Tensor<DType> values, Tensor<DType> mask_or_params,
                      Tensor<DType> eye_weight)
{
    attention(y, xq, keys, values, mask_or_params, eye_weight, 1u);
}

} // namespace nnedge::op
