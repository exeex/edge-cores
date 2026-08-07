#pragma once

#include "dtype.hpp"

#include "edge_intrinsic.hpp"

namespace nnedge {

constexpr size_t kArenaAlign = 64u;
constexpr size_t kHostArenaBytes = 256u * 1024u;

constexpr size_t kDtcmBytes = 128u * 1024u;
constexpr size_t kDtcmTensorArenaOffset = 0u;
constexpr size_t kDtcmTensorArenaBytes = 96u * 1024u;
constexpr size_t kDtcmOpScratchOffset =
    kDtcmTensorArenaOffset + kDtcmTensorArenaBytes;
constexpr size_t kDtcmOpScratchBytes =
    kDtcmBytes - kDtcmOpScratchOffset;
extern "C" unsigned char __nnedge_dram_heap_start[];
extern "C" unsigned char __nnedge_dram_heap_end[];

inline size_t dtcm_base()
{
    return reinterpret_cast<size_t>(__edge_dtcm_base);
}

inline bool &alloc_failed()
{
    static bool failed = false;
    return failed;
}

inline size_t &dtcm_cursor()
{
    static size_t cursor = 0;
    return cursor;
}

inline size_t &dram_cursor()
{
    static size_t cursor = 0;
    return cursor;
}


inline bool is_dtcm_addr(const void *ptr)
{
    const size_t addr = reinterpret_cast<size_t>(ptr);
    const size_t base = dtcm_base();
    return addr >= base && addr < (base + kDtcmBytes);
}

inline size_t align_bytes(size_t bytes)
{
    return (bytes + kArenaAlign - 1u) & ~(kArenaAlign - 1u);
}

template <typename DType>
inline DType *dtcm_op_scratch()
{
    return reinterpret_cast<DType *>(dtcm_base() + kDtcmOpScratchOffset);
}

struct Shape {
    size_t rank;
    size_t dims[8];

    constexpr Shape() : rank(0), dims{} {}

    template <typename... Dims>
    constexpr Shape(Dims... values) : rank(sizeof...(Dims)), dims{static_cast<size_t>(values)...}
    {
    }
};

template <typename DType>
struct Tensor {
    DType *data;
    Shape shape;

    constexpr Tensor() : data(nullptr), shape() {}
    explicit constexpr Tensor(Shape tensor_shape) : data(nullptr), shape(tensor_shape) {}
    constexpr Tensor(Shape tensor_shape, DType *tensor_data) : data(tensor_data), shape(tensor_shape) {}
};

template <typename DType>
inline size_t numel(const Tensor<DType> &tensor)
{
    size_t total = 1;
    for (size_t i = 0; i < tensor.shape.rank; ++i) {
        total *= tensor.shape.dims[i];
    }
    return total;
}

template <typename DType>
inline void malloc_tensor(Tensor<DType> &tensor)
{
    const size_t bytes = align_bytes(numel(tensor) * sizeof(DType));
    size_t &dtcm = dtcm_cursor();
    if (dtcm + bytes <= kDtcmTensorArenaBytes) {
        tensor.data =
            reinterpret_cast<DType *>(dtcm_base() + kDtcmTensorArenaOffset + dtcm);
        dtcm += bytes;
        return;
    }

    size_t &dram = dram_cursor();
    const size_t heap_bytes =
        static_cast<size_t>(__nnedge_dram_heap_end - __nnedge_dram_heap_start);
    if (dram + bytes > heap_bytes) {
        tensor.data = nullptr;
        alloc_failed() = true;
        return;
    }
    tensor.data = reinterpret_cast<DType *>(__nnedge_dram_heap_start + dram);
    dram += bytes;
    (void)kDtcmBytes;
}

template <typename DType>
inline void malloc_tensor_dram(Tensor<DType> &tensor)
{
    const size_t bytes = align_bytes(numel(tensor) * sizeof(DType));
    size_t &dram = dram_cursor();
    const size_t heap_bytes =
        static_cast<size_t>(__nnedge_dram_heap_end - __nnedge_dram_heap_start);
    if (dram + bytes > heap_bytes) {
        tensor.data = nullptr;
        alloc_failed() = true;
        return;
    }
    tensor.data = reinterpret_cast<DType *>(__nnedge_dram_heap_start + dram);
    dram += bytes;
}

inline void reset_allocator()
{
    dtcm_cursor() = 0;
    dram_cursor() = 0;
    alloc_failed() = false;
}

template <typename DType>
inline void free_tensor(Tensor<DType> &tensor)
{
    if (tensor.data == nullptr) {
        return;
    }
    const size_t bytes = align_bytes(numel(tensor) * sizeof(DType));
    const size_t addr = reinterpret_cast<size_t>(tensor.data);
    if (is_dtcm_addr(tensor.data)) {
        size_t &cursor = dtcm_cursor();
        const size_t offset = addr - dtcm_base();
        if (offset + bytes == cursor) {
            cursor = offset;
        }
    } else {
        size_t &cursor = dram_cursor();
        const size_t offset =
            addr - reinterpret_cast<size_t>(__nnedge_dram_heap_start);
        if (offset + bytes == cursor) {
            cursor = offset;
        }
    }
    tensor.data = nullptr;
}

template <typename DType>
inline void copy(Tensor<DType> dst, Tensor<DType> src)
{
    const size_t n = numel(dst);
    const size_t bytes = n * sizeof(DType);
    if (src.data == nullptr || dst.data == nullptr) {
        alloc_failed() = true;
        return;
    }
    if (src.data == dst.data || n == 0u) {
        return;
    }
    const bool src_dtcm = is_dtcm_addr(src.data);
    const bool dst_dtcm = is_dtcm_addr(dst.data);
    if (src_dtcm && dst_dtcm) {
        if (sizeof(DType) != sizeof(uint16_t) ||
            (reinterpret_cast<size_t>(src.data) & 0xfu) != 0u ||
            (reinterpret_cast<size_t>(dst.data) & 0xfu) != 0u) {
            alloc_failed() = true;
            return;
        }

        // CMPU consumes a 16-bit element count. Keep every non-final chunk a
        // multiple of one 128-bit DTCM beat so the next base remains aligned.
        constexpr size_t kCmpuCopyChunkElements = 0xfff8u;
        edge_cmpu_setcsr<9>();
        for (size_t offset = 0; offset < n;) {
            const size_t remaining = n - offset;
            const size_t count = remaining > kCmpuCopyChunkElements
                                     ? kCmpuCopyChunkElements
                                     : remaining;
            edge_cmpu_setlhs(src.data + offset);
            edge_cmpu_setout(dst.data + offset);
            edge_cmpu_setn(count);
            edge_cmpu_start();
            edge_cmpu_sync();
            offset += count;
        }
        return;
    }
    if (!is_dtcm_addr(src.data) && !is_dtcm_addr(dst.data)) {
        edge_dcache_invalidate_range(src.data, bytes);
        for (size_t i = 0; i < n; ++i) {
            dst.data[i] = src.data[i];
        }
        edge_dcache_clean_range(dst.data, bytes);
        return;
    }
    if (!src_dtcm) {
        edge_dcache_clean_range(src.data, bytes);
    }
    edge_dma_start(src.data, dst.data, bytes);
    edge_dma_sync();
    if (!dst_dtcm) {
        edge_dcache_invalidate_range(dst.data, bytes);
    }
}

template <typename DType>
inline void zero(Tensor<DType> tensor)
{
    const size_t n = numel(tensor);
    for (size_t i = 0; i < n; ++i) {
        tensor.data[i] = DType();
    }
}

} // namespace nnedge
