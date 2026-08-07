#pragma once

#include "tensor.hpp"

namespace nnedge::op {

template <typename DType>
inline void softmax_matrix(Tensor<DType> y, Tensor<DType> x,
                           Tensor<DType> eye_weight)
{
    const size_t rows = x.shape.dims[0];
    const size_t cols = x.shape.dims[1];

    (void)eye_weight;
    if (rows == 0u || cols == 0u || cols > 64u ||
        x.data == nullptr || y.data == nullptr) {
        return;
    }

    const bool input_dram = !is_dtcm_addr(x.data);
    const bool output_dram = !is_dtcm_addr(y.data);
    const size_t staged_matrices = (input_dram ? 1u : 0u) +
                                   (output_dram ? 1u : 0u);
    const size_t row_stage_bytes = staged_matrices * cols * sizeof(DType);
    if (row_stage_bytes == 0u) {
        // Both matrices already live in DTCM; no batch staging is required.
    } else if (row_stage_bytes > kDtcmOpScratchBytes) {
        alloc_failed() = true;
        return;
    }

    DType *scratch = dtcm_op_scratch<DType>();
    const size_t bytes_per_staged_row = staged_matrices * cols * sizeof(DType);
    size_t batch_rows = bytes_per_staged_row == 0u
                            ? rows
                            : kDtcmOpScratchBytes / bytes_per_staged_row;
    batch_rows = batch_rows > rows ? rows : batch_rows;
    if (batch_rows == 0u) {
        alloc_failed() = true;
        return;
    }

    edge_cmpu_setcsr<0>();
    edge_cmpu_setn(cols);

    for (size_t batch_base = 0; batch_base < rows; batch_base += batch_rows) {
        const size_t batch_count = (rows - batch_base) > batch_rows
                                       ? batch_rows
                                       : (rows - batch_base);
        const size_t batch_elements = batch_count * cols;
        DType *batch_in = input_dram ? scratch : &x.data[batch_base * cols];
        DType *batch_exp = output_dram
                               ? scratch + (input_dram ? batch_elements : 0u)
                               : &y.data[batch_base * cols];

        if (input_dram) {
            DType *input_src = &x.data[batch_base * cols];
            edge_dcache_clean_range(input_src,
                                    batch_elements * sizeof(DType));
            edge_dma_start(input_src, batch_in,
                           batch_elements * sizeof(DType));
            edge_dma_sync();
        }

        for (size_t row = 0; row < batch_count; ++row) {
            DType *row_in = &batch_in[row * cols];
            DType *row_exp = &batch_exp[row * cols];

            // Pass 1: CMPU reduces the complete BF16 key row. Its CSR exposes
            // the raw BF16 maximum; placing those bits in the high half of an
            // FP32 container is the exact scalar encoding expected by ACTU.
            edge_cmpu_setlhs(row_in);
            edge_cmpu_start();
            edge_cmpu_sync();
            const size_t max_value_bits =
                (edge_cmpu_get_max_value() & 0xffffu) << 16;

            // Pass 2: mode 5 stores BF16 exp(x-max) while accumulating BF22
            // internal EXP values into a job-local FP32 sum inside ACTU.
            edge_actu_setcsr<0, 5>();
            edge_actu_setin(row_in);
            edge_actu_setout(row_exp);
            edge_actu_setscalar(max_value_bits);
            edge_actu_setn(cols);
            edge_actu_start();
            edge_actu_sync();

            // Pass 3: mode 7 reuses the captured sum and emits
            // exp(x-max) * rcp(sum). In-place DTCM streaming is safe because
            // ACTU IO reads each beat before committing the corresponding
            // delayed output beat.
            edge_actu_setcsr<0, 7>();
            edge_actu_setin(row_exp);
            edge_actu_setout(row_exp);
            edge_actu_setn(cols);
            edge_actu_start();
            edge_actu_sync();
        }

        if (output_dram) {
            DType *output_dst = &y.data[batch_base * cols];
            edge_dcache_clean_range(output_dst,
                                    batch_elements * sizeof(DType));
            edge_dma_start(batch_exp, output_dst,
                           batch_elements * sizeof(DType));
            edge_dma_sync();
            edge_dcache_invalidate_range(output_dst,
                                         batch_elements * sizeof(DType));
        }
    }
}

template <typename DType>
inline void softmax(Tensor<DType> y, Tensor<DType> x,
                    Tensor<DType> eye_weight, size_t head_count)
{
    if (head_count == 0u) {
        return;
    }
    if (head_count == 1u && x.shape.rank == 2u) {
        softmax_matrix(y, x, eye_weight);
        return;
    }
    if (x.shape.rank != 3u || y.shape.rank != 3u ||
        x.shape.dims[0] != head_count || y.shape.dims[0] != head_count) {
        return;
    }

    const size_t rows = x.shape.dims[1];
    const size_t cols = x.shape.dims[2];
    Tensor<DType> x_batches(Shape{head_count * rows, cols}, x.data);
    Tensor<DType> y_batches(Shape{head_count * rows, cols}, y.data);
    softmax_matrix(y_batches, x_batches, eye_weight);
}

template <typename DType>
inline void softmax(Tensor<DType> y, Tensor<DType> x,
                    Tensor<DType> eye_weight)
{
    softmax(y, x, eye_weight, 1u);
}

} // namespace nnedge::op
