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
__attribute__((always_inline)) inline void rms_norm_square_batch(
    DType *square, DType *input, DType *square_mean_weight,
    size_t vector_count)
{
    // The diagonal WLD holds exact 1/cols powers of two. dot(W, x) therefore
    // produces x/cols while the scale stream supplies x, yielding x*x/cols
    // for the complete row in one descriptor.
    edge_tensor_wld(square_mean_weight);
    edge_tensor_sld_stream(input);
    edge_tensor_setin(input);
    edge_tensor_setout(square);
    edge_tensor_setn(vector_count);
    edge_tensor_start<EDGE_TENSOR_START_OPT_USE_SCALE |
                      EDGE_TENSOR_START_OPT_SCALE_STREAM |
                      EDGE_TENSOR_START_OPT_NO_PSUM>();
    edge_tensor_sync();
}

template <typename DType>
__attribute__((always_inline)) inline void rms_norm_reduce_mean_square_batch(
    DType *mean_square, DType *square, DType *reduce_weight, size_t rows,
    size_t cols, size_t blocks)
{
    // Eight all-one rows produce eight identical partial sums. RSUM keeps
    // each lane in BF22 across every block and emits one BF16x8 vector.
    for (size_t row = 0; row < rows; ++row) {
        if (row == 0u)
            edge_tensor_wld(reduce_weight);
        else
            edge_tensor_wld<EDGE_TENSOR_LOAD_OPT_REUSE>();
        edge_tensor_setin(&square[row * cols]);
        edge_tensor_setout(
            &mean_square[row * kRmsNormVectorElements]);
        edge_tensor_setn(blocks);
        edge_tensor_start<EDGE_TENSOR_START_OPT_RSUM>();
    }
    edge_tensor_sync();
}

template <typename DType>
__attribute__((always_inline)) inline void rms_norm_inverse_rms_batch(
    DType *inverse_rms, DType *mean_square, size_t rows, float epsilon)
{
    union {
        float f32;
        unsigned int u32;
    } epsilon_bits = { epsilon };
    edge_actu_setcsr<0, 6>();
    edge_actu_setscalar(static_cast<uintptr_t>(epsilon_bits.u32));
    edge_actu_setin(mean_square);
    edge_actu_setout(inverse_rms);
    edge_actu_setn(rows * kRmsNormVectorElements);
    edge_actu_start();
    edge_actu_sync();
}

template <typename DType>
__attribute__((always_inline)) inline void rms_norm_normalize_batch(
    DType *output, DType *input, DType *inverse_rms, DType *eye_stage,
    size_t rows, size_t cols, size_t blocks)
{
    edge_tensor_wld(eye_stage);
    for (size_t row = 0; row < rows; ++row) {
        if (row != 0u)
            edge_tensor_wld<EDGE_TENSOR_LOAD_OPT_REUSE>();
        edge_tensor_sld(&inverse_rms[row * kRmsNormVectorElements]);
        edge_tensor_setin(&input[row * cols]);
        edge_tensor_setout(&output[row * cols]);
        edge_tensor_setn(blocks);
        edge_tensor_start<EDGE_TENSOR_START_OPT_USE_SCALE |
                          EDGE_TENSOR_START_OPT_NO_PSUM>();
    }
    edge_tensor_sync();
}

template <typename DType>
__attribute__((always_inline)) inline void rms_norm_apply_weight_batch(
    DType *output, DType *input, Tensor<DType> weight, DType *eye_stage,
    DType *weight_ring, size_t rows, size_t cols, size_t blocks)
{
    edge_tensor_wld(eye_stage);
    if (!is_dtcm_addr(weight.data)) {
        constexpr size_t kWeightRingVectors = 8u;
        edge_dcache_clean_range(weight.data, cols * sizeof(DType));
        edge_dma_start_strided_circular(
            weight.data, weight_ring, kRmsNormVectorElements * sizeof(DType),
            kRmsNormVectorElements * sizeof(DType), blocks,
            0u, rows, kWeightRingVectors);
        edge_tensor_sld_circular();
        edge_tensor_setin(input);
        edge_tensor_setout(output);
        edge_tensor_setn(rows * blocks);
        edge_tensor_start<EDGE_TENSOR_START_OPT_USE_SCALE |
                          EDGE_TENSOR_START_OPT_SCALE_STREAM |
                          EDGE_TENSOR_START_OPT_NO_PSUM>();
        edge_tensor_sync();
        edge_dma_sync();
        return;
    }

    for (size_t row = 0; row < rows; ++row) {
        if (row != 0u)
            edge_tensor_wld<EDGE_TENSOR_LOAD_OPT_REUSE>();
        edge_tensor_sld_stream(weight.data);
        edge_tensor_setin(&input[row * cols]);
        edge_tensor_setout(&output[row * cols]);
        edge_tensor_setn(blocks);
        edge_tensor_start<EDGE_TENSOR_START_OPT_USE_SCALE |
                          EDGE_TENSOR_START_OPT_SCALE_STREAM |
                          EDGE_TENSOR_START_OPT_NO_PSUM>();
    }
    edge_tensor_sync();
}

template <bool InputDram, bool OutputDram, typename DType>
__attribute__((always_inline)) inline void rms_norm_impl(
    Tensor<DType> y, Tensor<DType> x, Tensor<DType> weight,
    Tensor<DType> eye, Tensor<DType> reduce_weight,
    Tensor<DType> square_weight, float epsilon)
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
    DType *square_weight_stage = square_stage + batch_capacity;
    DType *reduce_stage = square_weight_stage + kRmsNormTileElements;
    DType *eye_stage = reduce_stage + kRmsNormTileElements;
    DType *mean_square_stage = eye_stage + kRmsNormTileElements;
    DType *inv_stage =
        mean_square_stage + batch_rows * kRmsNormVectorElements;
    DType *weight_ring =
        inv_stage + batch_rows * kRmsNormVectorElements;

    const size_t fixed_elements = static_cast<size_t>(weight_ring - scratch);
    const size_t scratch_elements = kDtcmOpScratchBytes / sizeof(DType);
    if (fixed_elements + kRmsNormTileElements > scratch_elements) {
        alloc_failed() = true;
        return;
    }

    edge_dma_start(square_weight.data, square_weight_stage, tile_bytes);
    edge_dma_sync();
    edge_dma_start(reduce_weight.data, reduce_stage, tile_bytes);
    edge_dma_sync();
    edge_dma_start(eye.data, eye_stage, tile_bytes);
    edge_dma_sync();

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

        rms_norm_square_batch(square_stage, batch_input, square_weight_stage,
                              batch_elements / kRmsNormVectorElements);
        rms_norm_reduce_mean_square_batch(
            mean_square_stage, square_stage, reduce_stage, batch_count, cols,
            blocks);
        rms_norm_inverse_rms_batch(
            inv_stage, mean_square_stage, batch_count, epsilon);
        rms_norm_normalize_batch(
            square_stage, batch_input, inv_stage, eye_stage, batch_count,
            cols, blocks);
        rms_norm_apply_weight_batch(
            batch_output, square_stage, weight, eye_stage, weight_ring,
            batch_count, cols, blocks);

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
                     Tensor<DType> weight, Tensor<DType> eye,
                     Tensor<DType> reduce_weight,
                     Tensor<DType> square_weight,
                     Eps eps)
{
    const size_t cols = x.shape.dims[x.shape.rank - 1u];
    const size_t rows = numel(x) / cols;
    const float epsilon = static_cast<float>(eps);

    if (rows == 0u || cols == 0u || (cols % 8u) != 0u ||
        x.data == nullptr || y.data == nullptr || weight.data == nullptr ||
        eye.data == nullptr ||
        reduce_weight.data == nullptr || square_weight.data == nullptr) {
        return;
    }
    const bool input_dram = !is_dtcm_addr(x.data);
    const bool output_dram = !is_dtcm_addr(y.data);
    if (input_dram && output_dram) {
        rms_norm_impl<true, true>(y, x, weight, eye, reduce_weight,
                                  square_weight, epsilon);
    } else if (input_dram) {
        rms_norm_impl<true, false>(y, x, weight, eye, reduce_weight,
                                   square_weight, epsilon);
    } else if (output_dram) {
        rms_norm_impl<false, true>(y, x, weight, eye, reduce_weight,
                                   square_weight, epsilon);
    } else {
        rms_norm_impl<false, false>(y, x, weight, eye, reduce_weight,
                                    square_weight, epsilon);
    }
}

} // namespace nnedge::op
