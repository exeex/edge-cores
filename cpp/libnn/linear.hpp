#pragma once

#include "tensor.hpp"

namespace nnedge {

enum class Quant {
    bf16,
};

enum class Tile {
    auto_,
};

namespace op {

inline size_t packed_weight_index(size_t out_blk, size_t k_blk, size_t out_lane, size_t k_lane)
{
    return (((out_blk * 8u + k_blk) * 8u + out_lane) * 8u) + k_lane;
}

inline size_t packed_weight_index(size_t out_blk, size_t k_blk, size_t out_lane,
                                  size_t k_lane, size_t k_blocks)
{
    return (((out_blk * k_blocks + k_blk) * 8u + out_lane) * 8u) + k_lane;
}

template <bool InputDram, bool OutputDram>
inline void linear_impl(Tensor<bfloat16_t> y, Tensor<bfloat16_t> x,
                        Tensor<bfloat16_t> weight)
{
    constexpr size_t kTokenTile = 32u;
    const size_t rows = x.shape.dims[0];
    const size_t in_cols = x.shape.dims[1];
    const size_t out_cols = weight.shape.dims[0];
    const size_t k_blocks = in_cols / 8u;
    const size_t out_blocks = out_cols / 8u;

    bfloat16_t *scratch = dtcm_op_scratch<bfloat16_t>();
    bfloat16_t *x_stage = scratch;
    const size_t max_token_count = rows < kTokenTile ? rows : kTokenTile;
    const size_t x_stage_elems = InputDram ? max_token_count * 8u : 0u;
    bfloat16_t *y_stage = x_stage + x_stage_elems;
    const size_t y_stage_elems =
        OutputDram ? max_token_count * 8u : 0u;
    bfloat16_t *w_stage = y_stage + y_stage_elems;

    constexpr size_t kWeightTileBytes =
        8u * 8u * sizeof(bfloat16_t);
    const size_t stage_bytes =
        (x_stage_elems + y_stage_elems) * sizeof(bfloat16_t);
    if (stage_bytes + kWeightTileBytes > kDtcmOpScratchBytes) {
        return;
    }
    const size_t weight_ring_capacity =
        (kDtcmOpScratchBytes - stage_bytes) / kWeightTileBytes;

    const bool weight_dram = !is_dtcm_addr(weight.data);
    if (weight_dram) {
        edge_dcache_clean_range(weight.data,
                                out_cols * in_cols * sizeof(bfloat16_t));
    }
    edge_tensor_setcsr<1, EDGE_TENSOR_WTYPE_BF16>();

    for (size_t token_base = 0; token_base < rows; token_base += kTokenTile) {
        const size_t token_count =
            (rows - token_base) > kTokenTile ? kTokenTile : (rows - token_base);
        edge_tensor_setn(1u);
        const size_t weight_tile_count = out_blocks * k_blocks;
        if (weight_dram) {
            const size_t ring_tiles =
                weight_tile_count < weight_ring_capacity
                    ? weight_tile_count
                    : weight_ring_capacity;
            edge_dma_start_strided_circular(
                weight.data, w_stage, kWeightTileBytes, kWeightTileBytes,
                weight_tile_count, 0u, 1u, ring_tiles);
            edge_tensor_wld_circular();
        }

        for (size_t out_blk = 0; out_blk < out_blocks; ++out_blk) {
            for (size_t k_blk = 0; k_blk < k_blocks; ++k_blk) {
                if constexpr (InputDram) {
                    for (size_t token = 0; token < token_count; ++token) {
                        bfloat16_t *input_src =
                            &x.data[(token_base + token) * in_cols + k_blk * 8u];
                        edge_dcache_clean_range(input_src, 8u * sizeof(bfloat16_t));
                        edge_dma_start(input_src, &x_stage[token * 8u],
                                       8u * sizeof(bfloat16_t));
                        edge_dma_sync();
                    }
                }
                bfloat16_t *w_src =
                    &weight.data[packed_weight_index(out_blk, k_blk, 0u, 0u, k_blocks)];
                if (!weight_dram) {
                    edge_tensor_wld(w_src);
                }

                for (size_t token = 0; token < token_count; ++token) {
                    if (token != 0u) {
                        edge_tensor_wld<EDGE_TENSOR_LOAD_OPT_REUSE>();
                    }
                    bfloat16_t *input_ptr = InputDram
                        ? &x_stage[token * 8u]
                        : &x.data[(token_base + token) * in_cols + k_blk * 8u];
                    bfloat16_t *output_ptr = OutputDram
                        ? &y_stage[token * 8u]
                        : &y.data[(token_base + token) * out_cols + out_blk * 8u];
                    edge_tensor_setin(input_ptr);
                    edge_tensor_setout(output_ptr);
                    if (k_blk == 0u) {
                        edge_tensor_start<EDGE_TENSOR_START_OPT_NO_PSUM>();
                    } else {
                        edge_tensor_setpsum(output_ptr);
                        edge_tensor_start();
                    }
                }

                const size_t tile_id = out_blk * k_blocks + k_blk;
                if (weight_dram && tile_id + 1u < weight_tile_count) {
                    edge_tensor_wld_circular();
                }
            }
        }

        // Match the high-utilization circular matmul schedule: all starts are
        // queued continuously and drained once at the end of the token batch.
        edge_tensor_sync();
        if (weight_dram) {
            edge_dma_sync();
        }

        if constexpr (OutputDram) {
            for (size_t out_blk = 0; out_blk < out_blocks; ++out_blk) {
                for (size_t token = 0; token < token_count; ++token) {
                    bfloat16_t *output_dst =
                        &y.data[(token_base + token) * out_cols + out_blk * 8u];
                    edge_dcache_clean_range(output_dst, 8u * sizeof(bfloat16_t));
                    edge_dma_start(&y_stage[token * 8u], output_dst,
                                   8u * sizeof(bfloat16_t));
                    edge_dma_sync();
                    edge_dcache_invalidate_range(output_dst,
                                                 8u * sizeof(bfloat16_t));
                }
            }
        }
    }
}

inline void linear(Tensor<bfloat16_t> y, Tensor<bfloat16_t> x, Tensor<bfloat16_t> weight,
                   Quant quant, Tile tile)
{
    (void)quant;
    (void)tile;

    const size_t in_cols = x.shape.dims[1];
    const size_t out_cols = weight.shape.dims[0];
    if ((in_cols % 8u) != 0u || (out_cols % 8u) != 0u) {
        return;
    }
    const bool input_dram = !is_dtcm_addr(x.data);
    const bool output_dram = !is_dtcm_addr(y.data);
    if (input_dram && output_dram) {
        linear_impl<true, true>(y, x, weight);
    } else if (input_dram) {
        linear_impl<true, false>(y, x, weight);
    } else if (output_dram) {
        linear_impl<false, true>(y, x, weight);
    } else {
        linear_impl<false, false>(y, x, weight);
    }
}

} // namespace op
} // namespace nnedge
