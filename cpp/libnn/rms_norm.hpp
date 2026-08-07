#pragma once

#include "tensor.hpp"

namespace nnedge::op {

inline float rsqrt_f32(float value)
{
    union {
        float f32;
        unsigned int u32;
    } bits = { value };
    bits.u32 = 0x5f3759dfu - (bits.u32 >> 1u);
    float estimate = bits.f32;
    const float half = 0.5f * value;
    estimate = estimate * (1.5f - half * estimate * estimate);
    estimate = estimate * (1.5f - half * estimate * estimate);
    return estimate;
}

constexpr size_t kRmsNormVectorElements = 8u;
constexpr size_t kRmsNormTileElements = 8u * 8u;

template <typename DType>
__attribute__((always_inline)) inline void rms_norm_square_row(
    DType *square, DType *input, DType *square_mean_weight, size_t blocks)
{
    // The diagonal WLD holds exact 1/cols powers of two. dot(W, x) therefore
    // produces x/cols while the scale stream supplies x, yielding x*x/cols
    // for the complete row in one descriptor.
    edge_tensor_wld(square_mean_weight);
    edge_tensor_sld_stream(input);
    edge_tensor_setin(input);
    edge_tensor_setout(square);
    edge_tensor_setn(blocks);
    edge_tensor_start<EDGE_TENSOR_START_OPT_USE_SCALE |
                      EDGE_TENSOR_START_OPT_SCALE_STREAM |
                      EDGE_TENSOR_START_OPT_NO_PSUM>();
    edge_tensor_sync();
}

template <typename DType>
__attribute__((always_inline)) inline void rms_norm_reduce_mean_square(
    DType *mean_square, DType *square, DType *reduce_weight, size_t blocks)
{
    // Eight all-one rows produce eight identical partial sums. RSUM keeps
    // each lane in BF22 across every block and emits one BF16x8 vector.
    edge_tensor_wld(reduce_weight);
    edge_tensor_setin(square);
    edge_tensor_setout(mean_square);
    edge_tensor_setn(blocks);
    edge_tensor_start<EDGE_TENSOR_START_OPT_RSUM>();
    edge_tensor_sync();
}

template <typename DType>
__attribute__((always_inline)) inline void rms_norm_inverse_rms(
    DType *inverse_rms, DType *mean_square, float epsilon)
{
    union {
        float f32;
        unsigned int u32;
    } epsilon_bits = { epsilon };
    edge_actu_setcsr<0, 6>();
    edge_actu_setscalar(static_cast<uintptr_t>(epsilon_bits.u32));
    edge_actu_setin(mean_square);
    edge_actu_setout(inverse_rms);
    edge_actu_setn(kRmsNormVectorElements);
    edge_actu_start();
    edge_actu_sync();
}

template <typename DType>
__attribute__((always_inline)) inline void rms_norm_apply_scale(
    DType *output, DType *input, DType *inverse_rms,
    Tensor<DType> packed_weight, DType *weight_stage,
    bool weight_dram, bool stage_all_weights, size_t blocks,
    size_t weight_capacity_tiles)
{
    const size_t tile_bytes = kRmsNormTileElements * sizeof(DType);

    // One inverse-RMS vector is shared by every block. Independent diagonal
    // weight starts are queued continuously and drained only after the row.
    edge_tensor_sld(inverse_rms);
    edge_tensor_sync();

    const bool stream_weights = weight_dram && !stage_all_weights;
    if (stream_weights) {
        const size_t ring_tiles =
            blocks < weight_capacity_tiles ? blocks : weight_capacity_tiles;
        edge_dma_start_strided_circular(
            packed_weight.data, weight_stage, tile_bytes, tile_bytes, blocks,
            0u, 1u, ring_tiles);
        edge_tensor_wld_circular();
    }

    for (size_t block = 0; block < blocks; ++block) {
        if (!stream_weights) {
            DType *weight_ptr =
                stage_all_weights
                    ? &weight_stage[block * kRmsNormTileElements]
                    : &packed_weight.data[block * kRmsNormTileElements];
            edge_tensor_wld(weight_ptr);
        }
        if (block != 0u)
            edge_tensor_sld<EDGE_TENSOR_LOAD_OPT_REUSE>();
        edge_tensor_setin(&input[block * kRmsNormVectorElements]);
        edge_tensor_setout(&output[block * kRmsNormVectorElements]);
        edge_tensor_start<EDGE_TENSOR_START_OPT_USE_SCALE |
                          EDGE_TENSOR_START_OPT_NO_PSUM>();
        if (stream_weights && block + 1u < blocks)
            edge_tensor_wld_circular();
    }
    edge_tensor_sync();
    if (stream_weights)
        edge_dma_sync();
}

template <bool InputDram, bool OutputDram, typename DType>
__attribute__((always_inline)) inline void rms_norm_impl(
    Tensor<DType> y, Tensor<DType> x, Tensor<DType> packed_weight,
    Tensor<DType> reduce_weight, Tensor<DType> square_weight, float epsilon)
{
    constexpr size_t kBatchElements = 512u;
    const size_t cols = x.shape.dims[x.shape.rank - 1u];
    const size_t rows = numel(x) / cols;
    const size_t blocks = cols / kRmsNormVectorElements;
    const size_t tile_bytes = kRmsNormTileElements * sizeof(DType);

    size_t batch_rows = kBatchElements / cols;
    batch_rows = batch_rows == 0u ? 1u : batch_rows;
    batch_rows = batch_rows > rows ? rows : batch_rows;
    const size_t batch_capacity = batch_rows * cols;

    DType *scratch = dtcm_op_scratch<DType>();
    DType *input_stage = scratch;
    const size_t input_stage_elements = InputDram ? batch_capacity : 0u;
    DType *output_stage = input_stage + input_stage_elements;
    const size_t output_stage_elements = OutputDram ? batch_capacity : 0u;
    DType *square_stage = output_stage + output_stage_elements;
    DType *square_weight_stage = square_stage + cols;
    DType *reduce_stage = square_weight_stage + kRmsNormTileElements;
    DType *mean_square_stage = reduce_stage + kRmsNormTileElements;
    DType *inv_stage = mean_square_stage + kRmsNormVectorElements;
    DType *weight_stage = inv_stage + kRmsNormVectorElements;

    const size_t fixed_elements = static_cast<size_t>(weight_stage - scratch);
    const size_t scratch_elements = kDtcmOpScratchBytes / sizeof(DType);
    if (fixed_elements > scratch_elements) {
        alloc_failed() = true;
        return;
    }

    const bool weight_dram = !is_dtcm_addr(packed_weight.data);
    const size_t weight_capacity_tiles =
        (scratch_elements - fixed_elements) / kRmsNormTileElements;
    if (weight_dram && weight_capacity_tiles == 0u) {
        alloc_failed() = true;
        return;
    }
    const bool stage_all_weights =
        weight_dram && weight_capacity_tiles >= blocks;

    edge_dma_start(square_weight.data, square_weight_stage, tile_bytes);
    edge_dma_sync();
    edge_dma_start(reduce_weight.data, reduce_stage, tile_bytes);
    edge_dma_sync();

    if (weight_dram) {
        if (stage_all_weights) {
            edge_dma_start(packed_weight.data, weight_stage,
                           blocks * tile_bytes);
            edge_dma_sync();
        }
    }

    edge_tensor_setcsr<1, EDGE_TENSOR_WTYPE_BF16>();

    for (size_t batch_base = 0; batch_base < rows;
         batch_base += batch_rows) {
        const size_t batch_count =
            (rows - batch_base) > batch_rows ? batch_rows
                                             : (rows - batch_base);
        const size_t batch_elements = batch_count * cols;
        const size_t batch_bytes = batch_elements * sizeof(DType);
        DType *batch_input = &x.data[batch_base * cols];
        DType *batch_output = &y.data[batch_base * cols];

        if constexpr (InputDram) {
            edge_dma_start(batch_input, input_stage, batch_bytes);
            edge_dma_sync();
            batch_input = input_stage;
        }
        if constexpr (OutputDram)
            batch_output = output_stage;

        for (size_t row = 0; row < batch_count; ++row) {
            DType *row_input = &batch_input[row * cols];
            DType *row_output = &batch_output[row * cols];

            rms_norm_square_row(square_stage, row_input, square_weight_stage,
                                blocks);
            rms_norm_reduce_mean_square(
                mean_square_stage, square_stage, reduce_stage, blocks);
            rms_norm_inverse_rms(inv_stage, mean_square_stage, epsilon);
            rms_norm_apply_scale(
                row_output, row_input, inv_stage, packed_weight, weight_stage,
                weight_dram, stage_all_weights, blocks,
                weight_capacity_tiles);
        }

        if constexpr (OutputDram) {
            DType *output_dst = &y.data[batch_base * cols];
            edge_dma_start(output_stage, output_dst, batch_bytes);
            edge_dma_sync();
            edge_dcache_invalidate_range(output_dst, batch_bytes);
        }
    }
}

template <typename DType, typename Eps>
inline void rms_norm(Tensor<DType> y, Tensor<DType> x,
                     Tensor<DType> packed_weight,
                     Tensor<DType> reduce_weight,
                     Tensor<DType> square_weight,
                     Eps eps)
{
    const size_t cols = x.shape.dims[x.shape.rank - 1u];
    const size_t rows = numel(x) / cols;
    const float epsilon = static_cast<float>(eps);

    if (rows == 0u || cols == 0u || (cols % 8u) != 0u ||
        x.data == nullptr || y.data == nullptr || packed_weight.data == nullptr ||
        reduce_weight.data == nullptr || square_weight.data == nullptr) {
        return;
    }
    const bool input_dram = !is_dtcm_addr(x.data);
    const bool output_dram = !is_dtcm_addr(y.data);
    if (input_dram && output_dram) {
        rms_norm_impl<true, true>(y, x, packed_weight, reduce_weight,
                                  square_weight, epsilon);
    } else if (input_dram) {
        rms_norm_impl<true, false>(y, x, packed_weight, reduce_weight,
                                   square_weight, epsilon);
    } else if (output_dram) {
        rms_norm_impl<false, true>(y, x, packed_weight, reduce_weight,
                                   square_weight, epsilon);
    } else {
        rms_norm_impl<false, false>(y, x, packed_weight, reduce_weight,
                                    square_weight, epsilon);
    }
}

} // namespace nnedge::op
