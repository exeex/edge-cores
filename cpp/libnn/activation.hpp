#pragma once

#include "tensor.hpp"

namespace nnedge::op {

template <int Mode, typename DType>
inline void actu_unary(Tensor<DType> y, Tensor<DType> x)
{
    const size_t n = numel(x);
    if (n != numel(y) || x.data == nullptr || y.data == nullptr) {
        alloc_failed() = true;
        return;
    }

    const bool input_dtcm = is_dtcm_addr(x.data);
    const bool output_dtcm = is_dtcm_addr(y.data);
    DType *scratch = dtcm_op_scratch<DType>();
    const size_t scratch_elements = kDtcmOpScratchBytes / sizeof(DType);
    const size_t staged_buffers = (input_dtcm ? 0u : 1u) +
                                  (output_dtcm ? 0u : 1u);
    const size_t chunk_limit = staged_buffers == 0u
                                   ? 0xfff8u
                                   : scratch_elements / staged_buffers;
    if (chunk_limit == 0u) {
        alloc_failed() = true;
        return;
    }

    edge_actu_setcsr<0, Mode>();
    for (size_t offset = 0; offset < n;) {
        const size_t remaining = n - offset;
        const size_t count = remaining > chunk_limit ? chunk_limit : remaining;
        DType *actu_in = input_dtcm ? x.data + offset : scratch;
        DType *actu_out = output_dtcm
                              ? y.data + offset
                              : scratch + (input_dtcm ? 0u : chunk_limit);
        const size_t bytes = count * sizeof(DType);

        if (!input_dtcm) {
            edge_dcache_clean_range(x.data + offset, bytes);
            edge_dma_start(x.data + offset, actu_in, bytes);
            edge_dma_sync();
        }

        edge_actu_setin(actu_in);
        edge_actu_setout(actu_out);
        edge_actu_setn(count);
        edge_actu_start();
        edge_actu_sync();

        if (!output_dtcm) {
            edge_dcache_clean_range(y.data + offset, bytes);
            edge_dma_start(actu_out, y.data + offset, bytes);
            edge_dma_sync();
            edge_dcache_invalidate_range(y.data + offset, bytes);
        }
        offset += count;
    }
}

template <typename DType>
inline void sigmoid(Tensor<DType> y, Tensor<DType> x)
{
    actu_unary<2>(y, x);
}

template <typename DType>
inline void silu(Tensor<DType> y, Tensor<DType> x)
{
    actu_unary<3>(y, x);
}

template <typename DType>
inline void tanh(Tensor<DType> y, Tensor<DType> x)
{
    actu_unary<4>(y, x);
}

} // namespace nnedge::op
