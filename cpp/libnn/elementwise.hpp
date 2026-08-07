#pragma once

#include "tensor.hpp"

namespace nnedge::op {

inline size_t add_stage_count(size_t n, size_t offset)
{
    constexpr size_t kMaxElements = 32u * 8u;
    const size_t remaining = n - offset;
    return remaining > kMaxElements ? kMaxElements : remaining;
}

template <bool LhsDram, bool RhsDram, bool OutputDram, typename DType>
inline void add_impl(Tensor<DType> y, Tensor<DType> lhs, Tensor<DType> rhs,
                     Tensor<DType> eye)
{
    const size_t n = numel(y);
    if ((n % 8u) != 0u) {
        return;
    }
    DType *scratch = dtcm_op_scratch<DType>();
    DType *lhs_stage = scratch;
    DType *rhs_stage = lhs_stage + 32u * 8u;
    DType *out_stage = rhs_stage + 32u * 8u;
    DType *w_stage = out_stage + 32u * 8u;

    edge_tensor_setcsr<1, EDGE_TENSOR_WTYPE_BF16>();
    edge_dcache_clean_range(eye.data, 8u * 8u * sizeof(DType));
    edge_dma_start(eye.data, w_stage, 8u * 8u * sizeof(DType));
    edge_dma_sync();
    edge_tensor_wld(w_stage);

    edge_tensor_sync();

    for (size_t offset = 0; offset < n;) {
        const size_t count = add_stage_count(n, offset);
        const size_t vectors = (count + 7u) / 8u;
        DType *lhs_ptr = &lhs.data[offset];
        DType *rhs_ptr = &rhs.data[offset];
        DType *out_ptr = &y.data[offset];

        if constexpr (LhsDram) {
            edge_dcache_clean_range(lhs_ptr, count * sizeof(DType));
            edge_dma_start(lhs_ptr, lhs_stage, count * sizeof(DType));
            edge_dma_sync();
            lhs_ptr = lhs_stage;
        }
        if constexpr (RhsDram) {
            edge_dcache_clean_range(rhs_ptr, count * sizeof(DType));
            edge_dma_start(rhs_ptr, rhs_stage, count * sizeof(DType));
            edge_dma_sync();
            rhs_ptr = rhs_stage;
        }
        if constexpr (OutputDram)
            out_ptr = out_stage;

        if (offset != 0u) {
            edge_tensor_wld<EDGE_TENSOR_LOAD_OPT_REUSE>();
        }
        edge_tensor_setin(lhs_ptr);
        edge_tensor_setpsum(rhs_ptr);
        edge_tensor_setout(out_ptr);
        edge_tensor_setn(vectors);
        edge_tensor_start();
        edge_tensor_sync();

        if constexpr (OutputDram) {
            DType *output_dst = &y.data[offset];
            edge_dcache_clean_range(output_dst, count * sizeof(DType));
            edge_dma_start(out_stage, output_dst, count * sizeof(DType));
            edge_dma_sync();
            edge_dcache_invalidate_range(output_dst, count * sizeof(DType));
        }
        offset += count;
    }
}

template <typename DType, typename Alpha>
inline void add(Tensor<DType> y, Tensor<DType> lhs, Tensor<DType> rhs,
                Tensor<DType> eye, Alpha alpha)
{
    const size_t n = numel(y);
    const float scale = static_cast<float>(alpha);
    if (scale != 1.0f) {
        for (size_t i = 0; i < n; ++i) {
            y.data[i] = DType::from_float(lhs.data[i].to_float() + rhs.data[i].to_float() * scale);
        }
        return;
    }
    const bool lhs_dram = !is_dtcm_addr(lhs.data);
    const bool rhs_dram = !is_dtcm_addr(rhs.data);
    const bool output_dram = !is_dtcm_addr(y.data);
    if (lhs_dram && rhs_dram && output_dram) {
        add_impl<true, true, true>(y, lhs, rhs, eye);
    } else if (lhs_dram && rhs_dram) {
        add_impl<true, true, false>(y, lhs, rhs, eye);
    } else if (lhs_dram && output_dram) {
        add_impl<true, false, true>(y, lhs, rhs, eye);
    } else if (rhs_dram && output_dram) {
        add_impl<false, true, true>(y, lhs, rhs, eye);
    } else if (lhs_dram) {
        add_impl<true, false, false>(y, lhs, rhs, eye);
    } else if (rhs_dram) {
        add_impl<false, true, false>(y, lhs, rhs, eye);
    } else if (output_dram) {
        add_impl<false, false, true>(y, lhs, rhs, eye);
    } else {
        add_impl<false, false, false>(y, lhs, rhs, eye);
    }
}

template <typename DType>
inline void mul_scalar(Tensor<DType> y, Tensor<DType> lhs, Tensor<DType> rhs)
{
    const size_t n = numel(y);
    for (size_t i = 0; i < n; ++i) {
        y.data[i] = DType::from_float(lhs.data[i].to_float() * rhs.data[i].to_float());
    }
}

template <bool LhsDram, bool RhsDram, bool OutputDram, typename DType>
inline void mul_impl(Tensor<DType> y, Tensor<DType> lhs, Tensor<DType> rhs,
                     Tensor<DType> eye)
{
    constexpr size_t kBatchElements = 512u;
    const size_t n = numel(y);
    if ((n % 8u) != 0u) {
        return;
    }
    DType *scratch = dtcm_op_scratch<DType>();
    DType *lhs_stage = scratch;
    DType *rhs_stage = lhs_stage + kBatchElements;
    DType *out_stage = rhs_stage + kBatchElements;
    DType *w_stage = out_stage + kBatchElements;

    edge_tensor_setcsr<1, EDGE_TENSOR_WTYPE_BF16>();
    edge_dcache_clean_range(eye.data, 8u * 8u * sizeof(DType));
    edge_dma_start(eye.data, w_stage, 8u * 8u * sizeof(DType));
    edge_dma_sync();
    edge_tensor_wld(w_stage);

    bool first_vector = true;
    for (size_t batch_base = 0; batch_base < n;
         batch_base += kBatchElements) {
        const size_t batch_elements =
            (n - batch_base) < kBatchElements
                ? (n - batch_base)
                : kBatchElements;
        const size_t batch_bytes = batch_elements * sizeof(DType);

        DType *lhs_ptr = &lhs.data[batch_base];
        if constexpr (LhsDram) {
            edge_dcache_clean_range(lhs_ptr, batch_bytes);
            edge_dma_start(lhs_ptr, lhs_stage, batch_bytes);
            edge_dma_sync();
            lhs_ptr = lhs_stage;
        }

        DType *rhs_ptr = &rhs.data[batch_base];

        DType *output_ptr = &y.data[batch_base];
        if constexpr (OutputDram) {
            output_ptr = out_stage;
        }

        const size_t vector_count = batch_elements / 8u;
        if (!first_vector) {
            edge_tensor_wld<EDGE_TENSOR_LOAD_OPT_REUSE>();
        }
        if constexpr (RhsDram) {
            constexpr size_t kScaleRingVectors = 8u;
            edge_dcache_clean_range(rhs_ptr, batch_bytes);
            edge_dma_start_strided_circular(
                rhs_ptr, rhs_stage, 8u * sizeof(DType),
                8u * sizeof(DType), vector_count, 0u, 1u,
                kScaleRingVectors);
            edge_tensor_sld_circular();
        } else {
            edge_tensor_sld_stream(rhs_ptr);
        }
        edge_tensor_setin(lhs_ptr);
        edge_tensor_setout(output_ptr);
        edge_tensor_setn(vector_count);
        edge_tensor_start<EDGE_TENSOR_START_OPT_USE_SCALE |
                          EDGE_TENSOR_START_OPT_SCALE_STREAM |
                          EDGE_TENSOR_START_OPT_NO_PSUM>();
        first_vector = false;

        if constexpr (OutputDram) {
            edge_tensor_sync();
            DType *output_dst = &y.data[batch_base];
            edge_dcache_clean_range(output_dst, batch_bytes);
            edge_dma_start(out_stage, output_dst, batch_bytes);
            edge_dma_sync();
            edge_dcache_invalidate_range(output_dst, batch_bytes);
        } else {
            // The next batch reprograms the direct stream and weight token.
            edge_tensor_sync();
        }
    }
}

template <typename DType>
inline void mul(Tensor<DType> y, Tensor<DType> lhs, Tensor<DType> rhs,
                Tensor<DType> eye)
{
    const bool lhs_dram = !is_dtcm_addr(lhs.data);
    const bool rhs_dram = !is_dtcm_addr(rhs.data);
    const bool output_dram = !is_dtcm_addr(y.data);
    if (lhs_dram && rhs_dram && output_dram) {
        mul_impl<true, true, true>(y, lhs, rhs, eye);
    } else if (lhs_dram && rhs_dram) {
        mul_impl<true, true, false>(y, lhs, rhs, eye);
    } else if (lhs_dram && output_dram) {
        mul_impl<true, false, true>(y, lhs, rhs, eye);
    } else if (rhs_dram && output_dram) {
        mul_impl<false, true, true>(y, lhs, rhs, eye);
    } else if (lhs_dram) {
        mul_impl<true, false, false>(y, lhs, rhs, eye);
    } else if (rhs_dram) {
        mul_impl<false, true, false>(y, lhs, rhs, eye);
    } else if (output_dram) {
        mul_impl<false, false, true>(y, lhs, rhs, eye);
    } else {
        mul_impl<false, false, false>(y, lhs, rhs, eye);
    }
}

} // namespace nnedge::op
