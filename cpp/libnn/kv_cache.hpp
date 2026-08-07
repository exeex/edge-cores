#pragma once

#include "tensor.hpp"

namespace nnedge::op {

template <typename DType>
inline void kv_cache_update(Tensor<DType> keys, Tensor<DType> values,
                            Tensor<DType> xk, Tensor<DType> xv, size_t start_pos)
{
    (void)start_pos;
    copy(keys, xk);
    copy(values, xv);
}

} // namespace nnedge::op
