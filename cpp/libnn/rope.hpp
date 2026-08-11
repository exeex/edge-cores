#pragma once


#include "tensor.hpp"

namespace nnedge::op {

template <typename DType>
inline void rope(Tensor<DType> xq_out, Tensor<DType> xk_out,
                 Tensor<DType> xq, Tensor<DType> xk, size_t start_pos,
                 Tensor<DType> rope_table)
{
    const size_t tokens = xq.shape.dims[0];
    const size_t dim = xq.shape.dims[xq.shape.rank - 1u];

    if ((dim % 8u) != 0u) {
        return;
    }

    constexpr size_t kTileElements = 8u * 8u;
    constexpr size_t kScratchStride = 32u;
    DType *scratch = dtcm_op_scratch<DType>();
    DType *x_stage = scratch;
    DType *out_stage = x_stage + kScratchStride;
    DType *w_stage = out_stage + kScratchStride;
    const size_t dim_blocks = dim / 8u;
    const bool q_input_dram = !is_dtcm_addr(xq.data);
    const bool k_input_dram = !is_dtcm_addr(xk.data);
    const bool q_output_dram = !is_dtcm_addr(xq_out.data);
    const bool k_output_dram = !is_dtcm_addr(xk_out.data);
    const bool table_dram = !is_dtcm_addr(rope_table.data);
    const size_t vector_bytes = 8u * sizeof(DType);
    const size_t tile_bytes = kTileElements * sizeof(DType);

    edge_tensor_setcsr<::bfloat16_t, ::bfloat16_t>();
    edge_tensor_setn(1);
    if (q_input_dram) {
        edge_dcache_clean_range(xq.data, numel(xq) * sizeof(DType));
    }
    if (k_input_dram) {
        edge_dcache_clean_range(xk.data, numel(xk) * sizeof(DType));
    }
    if (table_dram) {
        edge_dcache_clean_range(rope_table.data,
                                numel(rope_table) * sizeof(DType));
    }

    // The full Llama path keeps Q, K, and both outputs in DTCM.  Stream the
    // complete contiguous token/block sequence through a small circular ring:
    // DMA produces rotation tiles while Tensor consumes them.  Q uses the
    // fresh tile token and K reuses it.  setn must remain one because every
    // token has a different rotation tile.
    if (!q_input_dram && !k_input_dram &&
        !q_output_dram && !k_output_dram) {
        const size_t tile_count = tokens * dim_blocks;
        constexpr size_t kWeightRingTiles = 8u;
        if (table_dram) {
            const size_t ring_tiles =
                tile_count < kWeightRingTiles ? tile_count : kWeightRingTiles;
            DType *table_src = &rope_table.data[
                (start_pos * dim_blocks) * kTileElements];
            edge_dma_start_strided_circular(
                table_src, scratch, tile_bytes, tile_bytes, tile_count,
                0u, 1u, ring_tiles);
            edge_tensor_wld_circular();
        }

        size_t tile_index = 0u;
        for (size_t token = 0; token < tokens; ++token) {
            const size_t pos = start_pos + token;
            for (size_t block = 0; block < dim_blocks; ++block) {
                if (!table_dram) {
                    edge_tensor_wld(&rope_table.data[
                        (pos * dim_blocks + block) * kTileElements]);
                }

                const size_t data_base = token * dim + block * 8u;
                edge_tensor_setin(&xq.data[data_base]);
                edge_tensor_setout(&xq_out.data[data_base]);
                edge_tensor_start<EDGE_TENSOR_START_OPT_NO_PSUM>();

                edge_tensor_wld<EDGE_TENSOR_LOAD_OPT_REUSE>();
                edge_tensor_setin(&xk.data[data_base]);
                edge_tensor_setout(&xk_out.data[data_base]);
                edge_tensor_start<EDGE_TENSOR_START_OPT_NO_PSUM>();

                ++tile_index;
                if (table_dram && tile_index < tile_count)
                    edge_tensor_wld_circular();
            }
        }
        edge_tensor_sync();
        if (table_dram)
            edge_dma_sync();
        return;
    }

    for (size_t token = 0; token < tokens; ++token) {
        const size_t pos = start_pos + token;
        for (size_t block = 0; block < dim_blocks; ++block) {
            DType *tile = &rope_table.data[(pos * dim_blocks + block) * kTileElements];
            if (table_dram) {
                edge_dma_start(tile, w_stage, tile_bytes);
                edge_dma_sync();
                tile = w_stage;
            }
            edge_tensor_wld(tile);
            edge_tensor_sync();

            const size_t data_base = token * dim + block * 8u;
            DType *q_input = &xq.data[data_base];
            if (q_input_dram) {
                edge_dma_start(q_input, x_stage, vector_bytes);
                edge_dma_sync();
                q_input = x_stage;
            }
            DType *q_output = q_output_dram ? out_stage : &xq_out.data[data_base];
            edge_tensor_setin(q_input);
            edge_tensor_setout(q_output);
            edge_tensor_start<EDGE_TENSOR_START_OPT_NO_PSUM>();
            edge_tensor_sync();
            if (q_output_dram) {
                DType *q_dst = &xq_out.data[data_base];
                edge_dcache_clean_range(q_dst, vector_bytes);
                edge_dma_start(out_stage, q_dst, vector_bytes);
                edge_dma_sync();
                edge_dcache_invalidate_range(q_dst, vector_bytes);
            }

            edge_tensor_wld<EDGE_TENSOR_LOAD_OPT_REUSE>();
            DType *k_input = &xk.data[data_base];
            if (k_input_dram) {
                edge_dma_start(k_input, x_stage, vector_bytes);
                edge_dma_sync();
                k_input = x_stage;
            }
            DType *k_output = k_output_dram ? out_stage : &xk_out.data[data_base];
            edge_tensor_setin(k_input);
            edge_tensor_setout(k_output);
            edge_tensor_start<EDGE_TENSOR_START_OPT_NO_PSUM>();
            edge_tensor_sync();
            if (k_output_dram) {
                DType *k_dst = &xk_out.data[data_base];
                edge_dcache_clean_range(k_dst, vector_bytes);
                edge_dma_start(out_stage, k_dst, vector_bytes);
                edge_dma_sync();
                edge_dcache_invalidate_range(k_dst, vector_bytes);
            }
        }
    }
}

} // namespace nnedge::op
