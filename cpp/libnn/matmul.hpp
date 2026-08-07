#pragma once

#include "tensor.hpp"
#include "edge_sim_console.hpp"

namespace nnedge::op {

inline size_t mm_read_cycle()
{
    size_t value;
    __asm__ volatile("rdcycle %0" : "=r"(value));
    return value;
}

inline size_t mm_blocked_index(size_t blk, size_t token, size_t lane)
{
    return (blk * 64u * 8u) + (token * 8u) + lane;
}

inline size_t mm_row_major_index(size_t row, size_t col, size_t cols)
{
    return row * cols + col;
}

inline size_t mm_packed_stage_index(size_t row, size_t col)
{
    return row * 8u + col;
}

struct alignas(16) MmBf16x8 {
    uint64_t lo;
    uint64_t hi;
};

inline void mm_copy_bf16x8(bfloat16_t *dst, const bfloat16_t *src)
{
    const MmBf16x8 value = *reinterpret_cast<const MmBf16x8 *>(src);
    *reinterpret_cast<MmBf16x8 *>(dst) = value;
}

template <typename DType>
inline void matmul_reference(Tensor<DType> y, Tensor<DType> lhs, Tensor<DType> rhs,
                             bool rhs_transposed, size_t head_count)
{
    const bool lhs_has_head_axis = !rhs_transposed && lhs.shape.rank >= 3u;
    const size_t rows = rhs_transposed ? lhs.shape.dims[0]
                                       : (lhs_has_head_axis ? lhs.shape.dims[1]
                                                            : lhs.shape.dims[0]);
    const size_t k_cols = rhs_transposed
                              ? lhs.shape.dims[1] / head_count
                              : (lhs_has_head_axis ? lhs.shape.dims[2]
                                                   : lhs.shape.dims[1]);
    const size_t out_cols = rhs_transposed
                                ? rhs.shape.dims[0]
                                : rhs.shape.dims[1] / head_count;
    const size_t lhs_row_stride = rhs_transposed ? lhs.shape.dims[1] : k_cols;
    const size_t rhs_row_stride = rhs.shape.dims[1];
    const size_t out_row_stride = rhs_transposed ? out_cols : y.shape.dims[1];

    for (size_t head = 0; head < head_count; ++head) {
        const size_t lhs_head_offset = rhs_transposed
                                           ? head * k_cols
                                           : (lhs_has_head_axis
                                                  ? head * rows * k_cols
                                                  : 0u);
        const size_t rhs_head_offset =
            head * (rhs_transposed ? k_cols : out_cols);
        const size_t out_head_offset = rhs_transposed
                                           ? head * rows * out_cols
                                           : head * out_cols;
        for (size_t row = 0; row < rows; ++row) {
            for (size_t out_col = 0; out_col < out_cols; ++out_col) {
                float acc = 0.0f;
                for (size_t k = 0; k < k_cols; ++k) {
                    const float av =
                        lhs.data[lhs_head_offset + row * lhs_row_stride + k]
                            .to_float();
                    const size_t rhs_index = rhs_transposed
                        ? out_col * rhs_row_stride + rhs_head_offset + k
                        : k * rhs_row_stride + rhs_head_offset + out_col;
                    acc += av * rhs.data[rhs_index].to_float();
                }
                y.data[out_head_offset + row * out_row_stride + out_col] =
                    DType::from_float(acc);
            }
        }
    }
}

template <typename DType>
inline void matmul_dispatch(Tensor<DType> y, Tensor<DType> lhs, Tensor<DType> rhs,
                            bool rhs_transposed, size_t head_count)
{
    if (head_count == 0u) {
        return;
    }
    const bool lhs_has_head_axis = !rhs_transposed && lhs.shape.rank >= 3u;
    const size_t rows = rhs_transposed ? lhs.shape.dims[0]
                                       : (lhs_has_head_axis ? lhs.shape.dims[1]
                                                            : lhs.shape.dims[0]);
    const size_t total_width = rhs_transposed ? lhs.shape.dims[1] : rhs.shape.dims[1];
    if ((total_width % head_count) != 0u) {
        return;
    }
    const size_t k_cols = rhs_transposed
                              ? total_width / head_count
                              : (lhs_has_head_axis ? lhs.shape.dims[2]
                                                   : lhs.shape.dims[1]);
    const size_t out_cols = rhs_transposed
                                ? rhs.shape.dims[0]
                                : total_width / head_count;
    const size_t lhs_row_stride = lhs.shape.dims[lhs.shape.rank - 1u];
    if ((k_cols % 8u) != 0u || (out_cols % 8u) != 0u) {
        return;
    }
    const bool lhs_dram = !is_dtcm_addr(lhs.data);
    const bool rhs_dram = !is_dtcm_addr(rhs.data);
    const bool output_dram = !is_dtcm_addr(y.data);
    if (!lhs_dram || !rhs_dram || !output_dram) {
        alloc_failed() = true;
        return;
    }
    const size_t rhs_row_stride = rhs.shape.dims[1];
    const size_t output_stage_elems = head_count * rows * out_cols;
    const size_t input_stage_elems = head_count * rows * k_cols;
    const size_t weight_stage_elems =
        head_count * (k_cols / 8u) * (out_cols / 8u) * 8u * 8u;
    const size_t scratch_bytes =
        (output_stage_elems + input_stage_elems + weight_stage_elems) *
        sizeof(bfloat16_t);
    if (scratch_bytes > kDtcmOpScratchBytes) {
        alloc_failed() = true;
        return;
    }
    bfloat16_t *scratch = dtcm_op_scratch<bfloat16_t>();
    bfloat16_t *output_stage = scratch;
    bfloat16_t *input_stage = output_stage + output_stage_elems;
    bfloat16_t *w_stage = input_stage + input_stage_elems;

    const size_t k_blocks = k_cols / 8u;
    const size_t out_blocks = out_cols / 8u;
    const size_t total_tiles = head_count * k_blocks * out_blocks;
    edge_tensor_setcsr<1, EDGE_TENSOR_WTYPE_BF16>();
    edge_tensor_setn(rows);
    const size_t profile_begin = mm_read_cycle();
    size_t profile_lhs_issue = 0u;
    size_t profile_lhs_wait = 0u;

    // Public tensors are contiguous [row, width] or [head, row, width].
    // Tensor consumes [head, k_block, row, lane], so keep that packing private.
    for (size_t global_k = 0; global_k < head_count * k_blocks; ++global_k) {
        const size_t head = global_k / k_blocks;
        const size_t k_blk = global_k % k_blocks;
        const size_t head_offset = lhs_has_head_axis
            ? head * rows * k_cols
            : head * k_cols;
        const size_t lhs_issue_begin = mm_read_cycle();
        edge_dma_start_strided(
            lhs.data + head_offset + k_blk * 8u,
            input_stage + global_k * rows * 8u,
            8u * sizeof(DType), lhs_row_stride * sizeof(DType), rows);
        profile_lhs_issue += mm_read_cycle() - lhs_issue_begin;
        const size_t lhs_wait_begin = mm_read_cycle();
        edge_dma_sync();
        profile_lhs_wait += mm_read_cycle() - lhs_wait_begin;
    }
    const size_t profile_lhs_done = mm_read_cycle();

    if (rhs_transposed) {
        // Entry order: head, k_blk, out_blk. X walks output rows and every
        // eight fragments publish one BF16 8x8 entry.
        edge_dma_start_strided_circular(
            rhs.data, w_stage, 8u * sizeof(bfloat16_t),
            rhs_row_stride * sizeof(bfloat16_t), out_cols,
            8u * sizeof(bfloat16_t), head_count * k_blocks,
            8u * 8u * sizeof(bfloat16_t), total_tiles);
        edge_tensor_wld_circular();

        for (size_t global_k = 0; global_k < head_count * k_blocks;
             ++global_k) {
            const size_t head = global_k / k_blocks;
            const size_t k_blk = global_k % k_blocks;
            for (size_t out_blk = 0; out_blk < out_blocks; ++out_blk) {
                bfloat16_t *output_ptr = output_stage +
                    (head * out_blocks + out_blk) * rows * 8u;
                edge_tensor_setin(input_stage + global_k * rows * 8u);
                edge_tensor_setout(output_ptr);
                if (k_blk == 0u) {
                    edge_tensor_start<EDGE_TENSOR_START_OPT_NO_PSUM>();
                } else {
                    edge_tensor_setpsum(output_ptr);
                    edge_tensor_start();
                }
                const size_t tile_id = global_k * out_blocks + out_blk;
                if (tile_id + 1u < total_tiles)
                    edge_tensor_wld_circular();
            }
        }
    } else {
        // Entry order: head, out_blk, k_blk. X walks K rows and every eight
        // fragments publish one transposed-WLD entry.
        edge_dma_start_strided_circular(
            rhs.data, w_stage, 8u * sizeof(bfloat16_t),
            rhs_row_stride * sizeof(bfloat16_t), k_cols,
            8u * sizeof(bfloat16_t), head_count * out_blocks,
            8u * 8u * sizeof(bfloat16_t), total_tiles);
        edge_tensor_wld_t_circular();

        for (size_t global_out = 0; global_out < head_count * out_blocks;
             ++global_out) {
            const size_t head = global_out / out_blocks;
            for (size_t k_blk = 0; k_blk < k_blocks; ++k_blk) {
                bfloat16_t *output_ptr =
                    output_stage + global_out * rows * 8u;
                edge_tensor_setin(input_stage +
                    (head * k_blocks + k_blk) * rows * 8u);
                edge_tensor_setout(output_ptr);
                if (k_blk == 0u) {
                    edge_tensor_start<EDGE_TENSOR_START_OPT_NO_PSUM>();
                } else {
                    edge_tensor_setpsum(output_ptr);
                    edge_tensor_start();
                }
                const size_t tile_id = global_out * k_blocks + k_blk;
                if (tile_id + 1u < total_tiles)
                    edge_tensor_wld_t_circular();
            }
        }
    }
    edge_tensor_sync();
    edge_dma_sync();
    const size_t profile_tensor_done = mm_read_cycle();

    const size_t output_bytes = numel(y) * sizeof(DType);
    edge_dcache_clean_range(y.data, output_bytes);
    const size_t profile_output_clean_done = mm_read_cycle();
    size_t profile_output_issue = 0u;
    size_t profile_output_wait = 0u;
    // Tensor produces [head, out_block, row, lane]. Restore the public
    // contiguous layout with one source-strided DMA per output row/head.
    for (size_t head = 0; head < head_count; ++head) {
        for (size_t row = 0; row < rows; ++row) {
            const size_t output_issue_begin = mm_read_cycle();
            DType *output_dst = rhs_transposed
                ? y.data + (head * rows + row) * out_cols
                : y.data + row * y.shape.dims[1] + head * out_cols;
            edge_dma_start_strided(
                output_stage + head * out_blocks * rows * 8u + row * 8u,
                output_dst, 8u * sizeof(DType),
                rows * 8u * sizeof(DType), out_blocks);
            profile_output_issue += mm_read_cycle() - output_issue_begin;
            const size_t output_wait_begin = mm_read_cycle();
            edge_dma_sync();
            profile_output_wait += mm_read_cycle() - output_wait_begin;
        }
    }
    const size_t profile_output_done = mm_read_cycle();
    edge_sim_printf("MATMUL_PHASE lhs=%lu(lhs_issue=%lu lhs_wait=%lu) tensor=%lu output_clean=%lu output_dma=%lu(out_issue=%lu out_wait=%lu) total=%lu\n",
           profile_lhs_done - profile_begin,
           profile_lhs_issue, profile_lhs_wait,
           profile_tensor_done - profile_lhs_done,
           profile_output_clean_done - profile_tensor_done,
           profile_output_done - profile_output_clean_done,
           profile_output_issue, profile_output_wait,
           profile_output_done - profile_begin);
}

template <typename DType>
inline void matmul_transpose(Tensor<DType> y, Tensor<DType> lhs,
                             Tensor<DType> rhs, size_t head_count)
{
    matmul_dispatch(y, lhs, rhs, true, head_count);
}

template <typename DType>
inline void matmul_transpose(Tensor<DType> y, Tensor<DType> lhs,
                             Tensor<DType> rhs)
{
    matmul_transpose(y, lhs, rhs, 1u);
}

template <typename DType>
inline void matmul(Tensor<DType> y, Tensor<DType> lhs, Tensor<DType> rhs,
                   size_t head_count)
{
    matmul_dispatch(y, lhs, rhs, false, head_count);
}

template <typename DType>
inline void matmul(Tensor<DType> y, Tensor<DType> lhs, Tensor<DType> rhs)
{
    matmul(y, lhs, rhs, 1u);
}

} // namespace nnedge::op
