#ifndef EDGE_INTRINSIC_HPP
#define EDGE_INTRINSIC_HPP

#include <stdint.h>
#include "edge_memory_map.hpp"

#define EDGE_DCACHE_LINE_SIZE 64u
#define EDGE_CSR_BREAK_ID 0x7e0u
#define EDGE_CSR_SIM_PUTCHAR_ID 0x7e1u

/*
 * C-readable wrappers for the provisional StarEdge DMA and Tensor
 * instruction surface.
 *
 * DMA and Tensor currently use provisional custom0 decode entries in RTL.
 * The Tensor encodings below keep operands visible to the decoder while the
 * final extension allocation is still being refined.
 */

#define EDGE_TENSOR_SETCSR_FUNCT7 0x10
#define EDGE_TENSOR_WLD_FUNCT7    0x11
#define EDGE_TENSOR_SETIN_FUNCT7  0x12
#define EDGE_TENSOR_SETOUT_FUNCT7 0x13
#define EDGE_TENSOR_SETPSUM_FUNCT7 0x14
#define EDGE_TENSOR_START_FUNCT7  0x15
#define EDGE_TENSOR_SYNC_FUNCT7   0x16
#define EDGE_TENSOR_SETN_FUNCT7   0x17
#define EDGE_TENSOR_WLD_T_FUNCT7  0x18
#define EDGE_TENSOR_START_TILE_FUNCT7 0x19
#define EDGE_TENSOR_SLD_STREAM_FUNCT7 0x1a
#define EDGE_TENSOR_WLD_CIRCULAR_FUNCT7 0x1b
#define EDGE_TENSOR_WLD_T_CIRCULAR_FUNCT7 0x1c
#define EDGE_TENSOR_SLD_FUNCT7    0x1d
#define EDGE_TENSOR_WSLD_CIRCULAR_FUNCT7 0x1e
#define EDGE_TENSOR_SLD_CIRCULAR_FUNCT7 0x1f

#define EDGE_ACTU_SETCSR_FUNCT7   0x20
#define EDGE_ACTU_SETIN_FUNCT7    0x21
#define EDGE_ACTU_SETOUT_FUNCT7   0x22
#define EDGE_ACTU_SETN_FUNCT7     0x23
#define EDGE_ACTU_SETSCALAR_FUNCT7 0x24
#define EDGE_ACTU_START_FUNCT7    0x25
#define EDGE_ACTU_SYNC_FUNCT7     0x26

#define EDGE_CMPU_SETCSR_FUNCT7   0x27
#define EDGE_CMPU_SETLHS_FUNCT7   0x28
#define EDGE_CMPU_SETRHS_FUNCT7   0x29
#define EDGE_CMPU_SETMASK_FUNCT7  0x2a
#define EDGE_CMPU_SETOUT_FUNCT7   0x2b
#define EDGE_CMPU_SETN_FUNCT7     0x2c
#define EDGE_CMPU_START_FUNCT7    0x2d
#define EDGE_CMPU_SYNC_FUNCT7     0x2e
#define EDGE_ACCEL_GETCSR_FUNCT7  0x2f

#define EDGE_ACCEL_CSR_CMPU_MAX_VALUE  0
#define EDGE_ACCEL_CSR_CMPU_ARGMAX_IDX 1
#define EDGE_ACCEL_CSR_CMPU_MIN_VALUE  2
#define EDGE_ACCEL_CSR_CMPU_ARGMIN_IDX 3
#define EDGE_ACCEL_CSR_ACTU_EXP_SUM    4

#define EDGE_DMA_START_FUNCT7     0x01
#define EDGE_DMA_SYNC_FUNCT7      0x02
#define EDGE_DMA_SETN_FUNCT7      0x03
#define EDGE_DMA_SETX_FUNCT7      0x04
#define EDGE_DMA_SETY_FUNCT7      0x05
#define EDGE_DMA_SETSRC_FUNCT7    0x06
#define EDGE_DMA_SETTAR_FUNCT7    0x07
#define EDGE_DMA_SETENTRY_FUNCT7  0x08

#define EDGE_DMA_MODE_USE_XY      0x1u
#define EDGE_DMA_MODE_CIRCULAR    0x2u

#define EDGE_TENSOR_WTYPE_BF16    1
#define EDGE_TENSOR_WTYPE_INT8    2
#define EDGE_TENSOR_LOAD_OPT_REUSE (1u << 1)
#define EDGE_TENSOR_LOAD_OPT_KNOWN_MASK EDGE_TENSOR_LOAD_OPT_REUSE

#define EDGE64_LENGTH_OPCODE 0x3fUL
#define EDGE_TENSOR64_HIGH_RD 1UL
#define EDGE_CUSTOM0_OPCODE 0x2bUL
#define EDGE_CUSTOM_FUNCT3  0x0UL
#define EDGE_OPCODE_LOAD_FP  0x07UL
#define EDGE_OPCODE_STORE_FP 0x27UL

#define EDGE_ENCODE_R_TYPE(funct7, rs2, rs1, funct3, rd, opcode) \
    (((uint32_t)(funct7) << 25) | ((uint32_t)(rs2) << 20) |       \
     ((uint32_t)(rs1) << 15) | ((uint32_t)(funct3) << 12) |       \
     ((uint32_t)(rd) << 7) | (uint32_t)(opcode))

#define EDGE_ENCODE_I_TYPE(imm12, rs1, funct3, rd, opcode)        \
    ((((uint32_t)(imm12) & 0xfffu) << 20) |                       \
     ((uint32_t)(rs1) << 15) | ((uint32_t)(funct3) << 12) |        \
     ((uint32_t)(rd) << 7) | (uint32_t)(opcode))

#define EDGE_ENCODE_S_TYPE(imm12, rs2, rs1, funct3, opcode)       \
    (((((uint32_t)(imm12) >> 5) & 0x7fu) << 25) |                 \
     ((uint32_t)(rs2) << 20) | ((uint32_t)(rs1) << 15) |           \
     ((uint32_t)(funct3) << 12) |                                 \
     (((uint32_t)(imm12) & 0x1fu) << 7) | (uint32_t)(opcode))

/* Provisional FP memory dtype slots: 101=bf16, 110=fp8e5m2, 111=fp8e3m4. */
#define EDGE_FP_MEM_BF16_FUNCT3 0x5u
#define EDGE_FP_MEM_FP8E5M2_FUNCT3 0x6u
#define EDGE_FP_MEM_FP8E3M4_FUNCT3 0x7u

#define EDGE_TENSOR_SETCSR_WORD(dtype, wtype)                         \
    EDGE_ENCODE_R_TYPE(EDGE_TENSOR_SETCSR_FUNCT7, (wtype), (dtype),   \
                       EDGE_CUSTOM_FUNCT3, 0, EDGE_CUSTOM0_OPCODE)

#define EDGE_TENSOR64_SETCSR_HIGH_WORD(dtype, wtype)                  \
    EDGE_ENCODE_R_TYPE(0, (wtype), (dtype), EDGE_CUSTOM_FUNCT3,       \
                       EDGE_TENSOR64_HIGH_RD, EDGE_TENSOR_SETCSR_FUNCT7)

#define EDGE_TENSOR64_HIGH_WORD(subop) ((uint32_t)(subop) | (1u << 7))
#define EDGE_TENSOR64_MODE_HIGH_WORD(subop, mode) \
    (EDGE_TENSOR64_HIGH_WORD(subop) | (((uint32_t)(mode) & 0xffu) << 24))

#define EDGE_ACTU64_SETCSR_HIGH_WORD(dtype, mode)                    \
    EDGE_ENCODE_R_TYPE(0, (mode), (dtype), EDGE_CUSTOM_FUNCT3,       \
                       EDGE_TENSOR64_HIGH_RD, EDGE_ACTU_SETCSR_FUNCT7)

#define EDGE_ACTU64_HIGH_WORD(subop) ((uint32_t)(subop) | (1u << 7))

#define EDGE_CMPU64_SETCSR_HIGH_WORD(mode)                            \
    EDGE_ENCODE_R_TYPE(0, 0, (mode), EDGE_CUSTOM_FUNCT3,              \
                       EDGE_TENSOR64_HIGH_RD, EDGE_CMPU_SETCSR_FUNCT7)

#define EDGE_CMPU64_HIGH_WORD(subop) ((uint32_t)(subop) | (1u << 7))

#define EDGE_ACCEL64_GETCSR_HIGH_WORD(csr_id)                         \
    EDGE_ENCODE_R_TYPE(0, 0, (csr_id), EDGE_CUSTOM_FUNCT3,            \
                       EDGE_TENSOR64_HIGH_RD, EDGE_ACCEL_GETCSR_FUNCT7)

#define EDGE_DMA64_STREAM_HIGH_WORD(subop) ((uint32_t)(subop) | (1u << 7))

#define EDGE_DMA64_START_HIGH_WORD(mode)                                  \
    (EDGE_DMA64_STREAM_HIGH_WORD(EDGE_DMA_START_FUNCT7) |                  \
     (((uint32_t)(mode) & 0x3u) << 24))

#define EDGE_DMA64_HIGH_WORD(subop, len_bytes)                         \
    ((uint32_t)(subop) | (1u << 7) |                                   \
     (((uint32_t)(len_bytes) & 0xffffu) << 8))

static inline uintptr_t edge_get_cycle(void)
{
    uintptr_t cycle;

    __asm__ volatile(
        "csrr %0, cycle\n"
        : "=r"(cycle)
        :
        : "memory");

    return cycle;
}

static inline void edge_sim_putchar(char ch)
{
    uintptr_t value = (uintptr_t)(unsigned char)ch;
    __asm__ volatile("csrw 0x7e1, %0" : : "r"(value) : "memory");
}

static inline void edge_exit(uintptr_t return_value)
{
    __asm__ volatile(
        "csrw %0, %1\n"
        :
        : "i"(EDGE_CSR_BREAK_ID), "r"(return_value)
        : "memory");

    for (;;) {
        __asm__ volatile("wfi" ::: "memory");
    }
}

static inline void edge_dcache_invalidate_all(void)
{
    __asm__ volatile(
        "# edge.dcache.iall\n"
        ".insn r 0x0b, 0, 0, x0, x0, x2\n"
        :
        :
        : "memory");
}

static inline void edge_dcache_clean_all(void)
{
    __asm__ volatile(
        "# edge.dcache.call\n"
        ".insn r 0x0b, 0, 0, x0, x0, x1\n"
        :
        :
        : "memory");
}

static inline void edge_dcache_clean_invalidate_all(void)
{
    __asm__ volatile(
        "# edge.dcache.ciall\n"
        ".insn r 0x0b, 0, 0, x0, x0, x3\n"
        :
        :
        : "memory");
}

static inline void edge_dcache_invalidate_va(const void *addr)
{
    register uintptr_t edge_addr __asm__("a0") = (uintptr_t)addr;

    __asm__ volatile(
        "# edge.dcache.iva addr=%0\n"
        ".insn r 0x0b, 1, 0, x0, %0, x6\n"
        :
        : "r"(edge_addr)
        : "memory");
}

static inline void edge_dcache_clean_va(const void *addr)
{
    register uintptr_t edge_addr __asm__("a0") = (uintptr_t)addr;

    __asm__ volatile(
        "# edge.dcache.cva addr=%0\n"
        ".insn r 0x0b, 1, 0, x0, %0, x5\n"
        :
        : "r"(edge_addr)
        : "memory");
}

static inline void edge_dcache_clean_invalidate_va(const void *addr)
{
    register uintptr_t edge_addr __asm__("a0") = (uintptr_t)addr;

    __asm__ volatile(
        "# edge.dcache.civa addr=%0\n"
        ".insn r 0x0b, 1, 0, x0, %0, x7\n"
        :
        : "r"(edge_addr)
        : "memory");
}

static inline uintptr_t edge_dcache_line_floor(uintptr_t addr)
{
    return addr & ~(uintptr_t)(EDGE_DCACHE_LINE_SIZE - 1u);
}

static inline uintptr_t edge_dcache_line_ceil(uintptr_t addr)
{
    return (addr + EDGE_DCACHE_LINE_SIZE - 1u) &
           ~(uintptr_t)(EDGE_DCACHE_LINE_SIZE - 1u);
}

static inline void edge_dcache_clean_range(const void *ptr, uintptr_t len)
{
    uintptr_t cur = edge_dcache_line_floor((uintptr_t)ptr);
    uintptr_t end = edge_dcache_line_ceil((uintptr_t)ptr + len);

    while (cur < end) {
        edge_dcache_clean_va((const void *)cur);
        cur += EDGE_DCACHE_LINE_SIZE;
    }
}

static inline void edge_dcache_invalidate_range(const void *ptr, uintptr_t len)
{
    uintptr_t cur = edge_dcache_line_floor((uintptr_t)ptr);
    uintptr_t end = edge_dcache_line_ceil((uintptr_t)ptr + len);

    while (cur < end) {
        edge_dcache_invalidate_va((const void *)cur);
        cur += EDGE_DCACHE_LINE_SIZE;
    }
}

static inline void edge_dcache_clean_invalidate_range(const void *ptr,
                                                      uintptr_t len)
{
    uintptr_t cur = edge_dcache_line_floor((uintptr_t)ptr);
    uintptr_t end = edge_dcache_line_ceil((uintptr_t)ptr + len);

    while (cur < end) {
        edge_dcache_clean_invalidate_va((const void *)cur);
        cur += EDGE_DCACHE_LINE_SIZE;
    }
}

static inline void edge_dma_setsrc(const void *src)
{
    register uintptr_t edge_src __asm__("a0") = (uintptr_t)src;
    __asm__ volatile(
        "# edge.dma.setsrc src=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        : "+r"(edge_src)
        : "i"(EDGE_DMA64_STREAM_HIGH_WORD(EDGE_DMA_SETSRC_FUNCT7))
        : "memory");
}

static inline void edge_dma_settar(void *dst)
{
    register uintptr_t edge_dst __asm__("a0") = (uintptr_t)dst;
    __asm__ volatile(
        "# edge.dma.settar tar=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        : "+r"(edge_dst)
        : "i"(EDGE_DMA64_STREAM_HIGH_WORD(EDGE_DMA_SETTAR_FUNCT7))
        : "memory");
}

static inline void edge_dma_start(const void *src, void *dst, uintptr_t len)
{
    register uintptr_t edge_len __asm__("a2") = len;

    edge_dma_setsrc(src);
    edge_dma_settar(dst);

    /*
     * First-slice 64-bit Tensor/DMA stream encoding:
     *   low parcel: opcode=0x3f, rd=length, rs1=x0, rs2=x0
     *   high parcel: stream bit set, subop=dma.start
     * Keep the operand substitutions in the .insn itself. If only the comment
     * names them, Clang may remove the register-value materialization.
     */
    __asm__ volatile(
        "# edge.dma.start len=%0\n"
        ".insn r 0x3f, 0, 0, %0, x0, x0\n"
        ".word %c1\n"
        : "+r"(edge_len)
        : "i"(EDGE_DMA64_START_HIGH_WORD(0))
        : "memory");
}

static inline void edge_dma_setn(uintptr_t contiguous_bytes)
{
    register uintptr_t edge_n __asm__("a0") = contiguous_bytes;
    __asm__ volatile(
        "# edge.dma.setn bytes=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        : "+r"(edge_n)
        : "i"(EDGE_DMA64_STREAM_HIGH_WORD(EDGE_DMA_SETN_FUNCT7))
        : "memory");
}

static inline void edge_dma_setentry(uintptr_t entry_bytes)
{
    register uintptr_t edge_entry __asm__("a0") = entry_bytes;
    __asm__ volatile(
        "# edge.dma.setentry bytes=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        : "+r"(edge_entry)
        : "i"(EDGE_DMA64_STREAM_HIGH_WORD(EDGE_DMA_SETENTRY_FUNCT7))
        : "memory");
}

static inline void edge_dma_setx(uintptr_t source_stride_bytes,
                                 uintptr_t axis_max)
{
    register uintptr_t edge_x __asm__("a0") =
        ((axis_max & 0xffffffffu) << 32) |
        (source_stride_bytes & 0xffffffffu);
    __asm__ volatile(
        "# edge.dma.setx packed_axis=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        : "+r"(edge_x)
        : "i"(EDGE_DMA64_STREAM_HIGH_WORD(EDGE_DMA_SETX_FUNCT7))
        : "memory");
}

static inline void edge_dma_sety(uintptr_t source_stride_bytes,
                                 uintptr_t axis_max)
{
    register uintptr_t edge_y __asm__("a0") =
        ((axis_max & 0xffffffffu) << 32) |
        (source_stride_bytes & 0xffffffffu);
    __asm__ volatile(
        "# edge.dma.sety packed_axis=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        : "+r"(edge_y)
        : "i"(EDGE_DMA64_STREAM_HIGH_WORD(EDGE_DMA_SETY_FUNCT7))
        : "memory");
}

static inline void edge_dma_start_strided(const void *src, void *dst,
                                          uintptr_t contiguous_bytes,
                                          uintptr_t source_stride_bytes,
                                          uintptr_t repeat_count)
{
    edge_dma_setn(contiguous_bytes);
    edge_dma_setx(source_stride_bytes, repeat_count);
    edge_dma_sety(0u, 1u);
    register uintptr_t edge_n __asm__("a2") = contiguous_bytes;
    edge_dma_setsrc(src);
    edge_dma_settar(dst);
    __asm__ volatile(
        "# edge.dma.start use_xy=1 len=%0\n"
        ".insn r 0x3f, 0, 0, %0, x0, x0\n"
        ".word %c1\n"
        : "+r"(edge_n)
        : "i"(EDGE_DMA64_START_HIGH_WORD(EDGE_DMA_MODE_USE_XY))
        : "memory");
}

static inline void edge_dma_start_strided_2d(
    const void *src, void *dst, uintptr_t contiguous_bytes,
    uintptr_t x_stride_bytes, uintptr_t x_max,
    uintptr_t y_stride_bytes, uintptr_t y_max)
{
    edge_dma_setn(contiguous_bytes);
    edge_dma_setx(x_stride_bytes, x_max);
    edge_dma_sety(y_stride_bytes, y_max);
    register uintptr_t edge_n __asm__("a2") = contiguous_bytes;
    edge_dma_setsrc(src);
    edge_dma_settar(dst);
    __asm__ volatile(
        "# edge.dma.start use_xy=1 len=%0\n"
        ".insn r 0x3f, 0, 0, %0, x0, x0\n"
        ".word %c1\n"
        : "+r"(edge_n)
        : "i"(EDGE_DMA64_START_HIGH_WORD(EDGE_DMA_MODE_USE_XY))
        : "memory");
}

static inline void edge_dma_sync(void)
{
    __asm__ volatile(
        "# edge.dma.sync\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c0\n"
        :
        : "i"(EDGE_DMA64_STREAM_HIGH_WORD(EDGE_DMA_SYNC_FUNCT7))
        : "memory");
}

static inline void edge_dma_start_circular(const void *src, void *ring_base,
                                           uintptr_t tile_count)
{
    register uintptr_t edge_tiles __asm__("a2") = tile_count;
    edge_dma_setsrc(src);
    edge_dma_settar(ring_base);

    __asm__ volatile(
        "# edge.dma.start_circular tiles=%0\n"
        ".insn r 0x3f, 0, 0, %0, x0, x0\n"
        ".word %c1\n"
        : "+r"(edge_tiles)
        : "i"(EDGE_DMA64_START_HIGH_WORD(EDGE_DMA_MODE_CIRCULAR))
        : "memory");
}

#ifdef __cplusplus
static inline void edge_dma_start_strided_circular(
    const void *src, void *ring_base, uintptr_t contiguous_bytes,
    uintptr_t x_stride_bytes, uintptr_t x_max,
    uintptr_t y_stride_bytes, uintptr_t y_max,
    uintptr_t entry_bytes, uintptr_t ring_capacity_entries)
{
    edge_dma_setn(contiguous_bytes);
    edge_dma_setentry(entry_bytes);
    edge_dma_setx(x_stride_bytes, x_max);
    edge_dma_sety(y_stride_bytes, y_max);
    register uintptr_t edge_entries __asm__("a2") = ring_capacity_entries;
    edge_dma_setsrc(src);
    edge_dma_settar(ring_base);
    __asm__ volatile(
        "# edge.dma.start use_xy=1 circular=1 entries=%0\n"
        ".insn r 0x3f, 0, 0, %0, x0, x0\n"
        ".word %c1\n"
        : "+r"(edge_entries)
        : "i"(EDGE_DMA64_START_HIGH_WORD(EDGE_DMA_MODE_USE_XY |
                                          EDGE_DMA_MODE_CIRCULAR))
        : "memory");
}

static inline void edge_dma_start_strided_circular(
    const void *src, void *ring_base, uintptr_t contiguous_bytes,
    uintptr_t x_stride_bytes, uintptr_t x_max,
    uintptr_t y_stride_bytes, uintptr_t y_max,
    uintptr_t ring_capacity_entries)
{
    edge_dma_start_strided_circular(
        src, ring_base, contiguous_bytes, x_stride_bytes, x_max,
        y_stride_bytes, y_max, contiguous_bytes, ring_capacity_entries);
}

static inline void edge_dma_start_strided_circular(
    const void *src, void *ring_base, uintptr_t contiguous_bytes,
    uintptr_t x_stride_bytes, uintptr_t x_max,
    uintptr_t y_stride_bytes, uintptr_t y_max)
{
    edge_dma_start_strided_circular(src, ring_base, contiguous_bytes,
                                    x_stride_bytes, x_max,
                                    y_stride_bytes, y_max, x_max);
}

static inline void edge_dma_start_strided_circular(
    const void *src, void *ring_base, uintptr_t contiguous_bytes,
    uintptr_t source_stride_bytes, uintptr_t repeat_count)
{
    edge_dma_start_strided_circular(src, ring_base, contiguous_bytes,
                                    source_stride_bytes, repeat_count,
                                    0u, 1u, repeat_count);
}
#endif

static inline float edge_bf16_load_f32_ptr(const uint16_t *ptr)
{
    float out;

    __asm__ volatile(
        "# edge.lfbf\n"
        ".insn i %c2, %c3, %0, 0(%1)\n"
        : "=f"(out)
        : "r"(ptr), "i"(EDGE_OPCODE_LOAD_FP),
          "i"(EDGE_FP_MEM_BF16_FUNCT3), "m"(*ptr)
        : "memory");

    return out;
}

#ifdef __cplusplus
static inline float edge_bf16_load_f32_ptr(const volatile uint16_t *ptr)
{
    float out;

    __asm__ volatile(
        "# edge.lfbf.volatile\n"
        ".insn i %c2, %c3, %0, 0(%1)\n"
        : "=f"(out)
        : "r"(ptr), "i"(EDGE_OPCODE_LOAD_FP),
          "i"(EDGE_FP_MEM_BF16_FUNCT3), "m"(*ptr)
        : "memory");

    return out;
}
#endif

static inline void edge_bf16_store_f32_ptr(uint16_t *ptr, float value)
{
    __asm__ volatile(
        "# edge.sfbf\n"
        ".insn s %c3, %c4, %1, 0(%2)\n"
        : "=m"(*ptr)
        : "f"(value), "r"(ptr), "i"(EDGE_OPCODE_STORE_FP),
          "i"(EDGE_FP_MEM_BF16_FUNCT3)
        : "memory");
}

#ifdef __cplusplus
static inline void edge_bf16_store_f32_ptr(volatile uint16_t *ptr, float value)
{
    __asm__ volatile(
        "# edge.sfbf.volatile\n"
        ".insn s %c3, %c4, %1, 0(%2)\n"
        : "=m"(*ptr)
        : "f"(value), "r"(ptr), "i"(EDGE_OPCODE_STORE_FP),
          "i"(EDGE_FP_MEM_BF16_FUNCT3)
        : "memory");
}
#endif

static inline uint16_t edge_bf16_from_f32_rne(float value)
{
    uint16_t out;

    edge_bf16_store_f32_ptr(&out, value);
    return out;
}

static inline float edge_f32_from_bf16(uint16_t value)
{
    return edge_bf16_load_f32_ptr(&value);
}

#ifdef __cplusplus
template <int dtype, int wtype>
static inline void edge_tensor_setcsr()
{
    static_assert(dtype >= 0 && dtype < 32, "tensor dtype must fit imm5");
    static_assert(wtype >= 0 && wtype < 32, "tensor wtype must fit imm5");

    __asm__ volatile(
        "# edge.tensor.setcsr dtype=%c0 wtype=%c1\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c2\n"
        :
        : "i"(dtype), "i"(wtype),
          "i"(EDGE_TENSOR64_SETCSR_HIGH_WORD(dtype, wtype))
        : "memory");
}
#endif

#ifdef __cplusplus
template <unsigned Options = 0>
static inline void edge_tensor_wld(const void *weight_ptr = nullptr)
{
    static_assert((Options & ~EDGE_TENSOR_LOAD_OPT_KNOWN_MASK) == 0,
                  "unknown tensor.wld option");

    if constexpr ((Options & EDGE_TENSOR_LOAD_OPT_REUSE) != 0) {
        __asm__ volatile(
            "# edge.tensor.wld reuse=1\n"
            ".insn r 0x3f, 0, 0, x0, x0, x0\n"
            ".word %c0\n"
            :
            : "i"(EDGE_TENSOR64_MODE_HIGH_WORD(
                  EDGE_TENSOR_WLD_FUNCT7, Options))
            : "memory");
    } else {
        uintptr_t edge_weight_ptr = (uintptr_t)weight_ptr;
        __asm__ volatile(
            "# edge.tensor.wld ptr=%0\n"
            ".insn r 0x3f, 0, 0, x0, %0, x0\n"
            ".word %c1\n"
            :
            : "r"(edge_weight_ptr),
              "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_WLD_FUNCT7))
            : "memory");
    }
}

template <unsigned Options = 0>
static inline void edge_tensor_wld_t(const void *weight_ptr = nullptr)
{
    static_assert((Options & ~EDGE_TENSOR_LOAD_OPT_KNOWN_MASK) == 0,
                  "unknown tensor.wld_t option");

    if constexpr ((Options & EDGE_TENSOR_LOAD_OPT_REUSE) != 0) {
        __asm__ volatile(
            "# edge.tensor.wld_t reuse=1\n"
            ".insn r 0x3f, 0, 0, x0, x0, x0\n"
            ".word %c0\n"
            :
            : "i"(EDGE_TENSOR64_MODE_HIGH_WORD(
                  EDGE_TENSOR_WLD_T_FUNCT7, Options))
            : "memory");
    } else {
        uintptr_t edge_weight_ptr = (uintptr_t)weight_ptr;
        __asm__ volatile(
            "# edge.tensor.wld_t ptr=%0\n"
            ".insn r 0x3f, 0, 0, x0, %0, x0\n"
            ".word %c1\n"
            :
            : "r"(edge_weight_ptr),
              "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_WLD_T_FUNCT7))
            : "memory");
    }
}

template <unsigned Options = 0>
static inline void edge_tensor_sld(const void *scale_ptr = nullptr)
{
    static_assert((Options & ~EDGE_TENSOR_LOAD_OPT_KNOWN_MASK) == 0,
                  "unknown tensor.sld option");

    if constexpr ((Options & EDGE_TENSOR_LOAD_OPT_REUSE) != 0) {
        __asm__ volatile(
            "# edge.tensor.sld reuse=1\n"
            ".insn r 0x3f, 0, 0, x0, x0, x0\n"
            ".word %c0\n"
            :
            : "i"(EDGE_TENSOR64_MODE_HIGH_WORD(
                  EDGE_TENSOR_SLD_FUNCT7, Options))
            : "memory");
    } else {
        uintptr_t edge_scale_ptr = (uintptr_t)scale_ptr;
        __asm__ volatile(
            "# edge.tensor.sld ptr=%0\n"
            ".insn r 0x3f, 0, 0, x0, %0, x0\n"
            ".word %c1\n"
            :
            : "r"(edge_scale_ptr),
              "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_SLD_FUNCT7))
            : "memory");
    }
}
#else
static inline void edge_tensor_wld(const void *weight_ptr)
{
    uintptr_t edge_weight_ptr = (uintptr_t)weight_ptr;
    __asm__ volatile(".insn r 0x3f, 0, 0, x0, %0, x0\n.word %c1\n" :
                     : "r"(edge_weight_ptr),
                       "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_WLD_FUNCT7))
                     : "memory");
}
static inline void edge_tensor_wld_t(const void *weight_ptr)
{
    uintptr_t edge_weight_ptr = (uintptr_t)weight_ptr;
    __asm__ volatile(".insn r 0x3f, 0, 0, x0, %0, x0\n.word %c1\n" :
                     : "r"(edge_weight_ptr),
                       "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_WLD_T_FUNCT7))
                     : "memory");
}
static inline void edge_tensor_sld(const void *scale_ptr)
{
    uintptr_t edge_scale_ptr = (uintptr_t)scale_ptr;
    __asm__ volatile(".insn r 0x3f, 0, 0, x0, %0, x0\n.word %c1\n" :
                     : "r"(edge_scale_ptr),
                       "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_SLD_FUNCT7))
                     : "memory");
}
#endif

static inline void edge_tensor_wld_circular(void)
{
    __asm__ volatile(
        "# edge.tensor.wld_circular\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c0\n"
        :
        : "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_WLD_CIRCULAR_FUNCT7))
        : "memory");
}

static inline void edge_tensor_wld_t_circular(void)
{
    __asm__ volatile(
        "# edge.tensor.wld_t_circular\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c0\n"
        :
        : "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_WLD_T_CIRCULAR_FUNCT7))
        : "memory");
}

static inline void edge_tensor_sld_circular(void)
{
    __asm__ volatile(
        "# edge.tensor.sld_circular\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c0\n"
        :
        : "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_SLD_CIRCULAR_FUNCT7))
        : "memory");
}

static inline void edge_tensor_sld_stream(const void *scale_ptr)
{
    uintptr_t edge_scale_ptr = (uintptr_t)scale_ptr;
    __asm__ volatile(
        "# edge.tensor.sld_stream ptr=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        :
        : "r"(edge_scale_ptr),
          "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_SLD_STREAM_FUNCT7))
        : "memory");
}

#ifdef __cplusplus
template <bool transpose = false>
static inline void edge_tensor_wsld_circular(void)
{
    __asm__ volatile(
        "# edge.tensor.wsld_circular transpose=%c0\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c1\n"
        :
        : "i"(transpose ? 1 : 0),
          "i"(EDGE_TENSOR64_MODE_HIGH_WORD(
              EDGE_TENSOR_WSLD_CIRCULAR_FUNCT7, transpose ? 1 : 0))
        : "memory");
}
#endif

static inline void edge_tensor_setin(const void *in_ptr)
{
    uintptr_t edge_in_ptr = (uintptr_t)in_ptr;

    __asm__ volatile(
        "# edge.tensor.setin ptr=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        :
        : "r"(edge_in_ptr),
          "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_SETIN_FUNCT7))
        : "memory");
}

static inline void edge_tensor_setout(void *out_ptr)
{
    uintptr_t edge_out_ptr = (uintptr_t)out_ptr;

    __asm__ volatile(
        "# edge.tensor.setout ptr=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        :
        : "r"(edge_out_ptr),
          "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_SETOUT_FUNCT7))
        : "memory");
}

static inline void edge_tensor_setpsum(const void *psum_ptr)
{
    uintptr_t edge_psum_ptr = (uintptr_t)psum_ptr;

    __asm__ volatile(
        "# edge.tensor.setpsum ptr=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        :
        : "r"(edge_psum_ptr),
          "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_SETPSUM_FUNCT7))
        : "memory");
}

static inline void edge_tensor_setn(uintptr_t n)
{
    uintptr_t edge_n = n;

    __asm__ volatile(
        "# edge.tensor.setn n=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        :
        : "r"(edge_n),
          "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_SETN_FUNCT7))
        : "memory");
}

#define EDGE_TENSOR_START_OPT_USE_SCALE (1u << 0)
#define EDGE_TENSOR_START_OPT_PSUM_ONCE  (1u << 1)
#define EDGE_TENSOR_START_OPT_NO_PSUM    (1u << 2)
#define EDGE_TENSOR_START_OPT_SCALE_STREAM (1u << 3)
#define EDGE_TENSOR_START_OPT_RSUM       (1u << 4)
#define EDGE_TENSOR_START_OPT_PSUM_MASK \
    (EDGE_TENSOR_START_OPT_PSUM_ONCE | EDGE_TENSOR_START_OPT_NO_PSUM)
#define EDGE_TENSOR_START_OPT_KNOWN_MASK \
    (EDGE_TENSOR_START_OPT_USE_SCALE | EDGE_TENSOR_START_OPT_PSUM_MASK | \
     EDGE_TENSOR_START_OPT_SCALE_STREAM | EDGE_TENSOR_START_OPT_RSUM)

#ifdef __cplusplus
template <unsigned Options = 0>
static inline void edge_tensor_start()
{
    static_assert((Options & ~EDGE_TENSOR_START_OPT_KNOWN_MASK) == 0,
                  "unknown tensor.start option");
    static_assert((Options & EDGE_TENSOR_START_OPT_PSUM_MASK)
                      != EDGE_TENSOR_START_OPT_PSUM_MASK,
                  "tensor.start psum modes are mutually exclusive");
    static_assert(!(Options & EDGE_TENSOR_START_OPT_SCALE_STREAM) ||
                      (Options & EDGE_TENSOR_START_OPT_USE_SCALE),
                  "tensor.start scale stream requires scale");
    static_assert(!(Options & EDGE_TENSOR_START_OPT_RSUM) ||
                      !(Options & (EDGE_TENSOR_START_OPT_USE_SCALE |
                                   EDGE_TENSOR_START_OPT_PSUM_MASK |
                                   EDGE_TENSOR_START_OPT_SCALE_STREAM)),
                  "tensor.start rsum is a standalone no-psum mode");

    __asm__ volatile(
        "# edge.tensor.start options=%c0\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c1\n"
        :
        : "i"(Options),
          "i"(EDGE_TENSOR64_MODE_HIGH_WORD(EDGE_TENSOR_START_FUNCT7, Options))
        : "memory");
}
#else
static inline void edge_tensor_start(void)
{
    __asm__ volatile(
        "# edge.tensor.start\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c0\n"
        :
        : "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_START_FUNCT7))
        : "memory");
}
#endif

static inline void edge_tensor_start_scale(void)
{
    __asm__ volatile(
        "# edge.tensor.start scale=1\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c0\n"
        :
        : "i"(EDGE_TENSOR64_MODE_HIGH_WORD(
              EDGE_TENSOR_START_FUNCT7, EDGE_TENSOR_START_OPT_USE_SCALE))
        : "memory");
}

#ifdef __cplusplus
template <unsigned Options = 0>
static inline void edge_tensor_start_tile()
{
    static_assert((Options & ~EDGE_TENSOR_START_OPT_KNOWN_MASK) == 0,
                  "unknown tensor.start_tile option");
    static_assert((Options & EDGE_TENSOR_START_OPT_PSUM_MASK)
                      != EDGE_TENSOR_START_OPT_PSUM_MASK,
                  "tensor.start_tile psum modes are mutually exclusive");
    static_assert(!(Options & EDGE_TENSOR_START_OPT_SCALE_STREAM) ||
                      (Options & EDGE_TENSOR_START_OPT_USE_SCALE),
                  "tensor.start_tile scale stream requires scale");
    static_assert(!(Options & EDGE_TENSOR_START_OPT_RSUM),
                  "tensor.start_tile does not support rsum");

    __asm__ volatile(
        "# edge.tensor.start_tile options=%c0\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c1\n"
        :
        : "i"(Options),
          "i"(EDGE_TENSOR64_MODE_HIGH_WORD(EDGE_TENSOR_START_TILE_FUNCT7,
                                           Options))
        : "memory");
}
#else
static inline void edge_tensor_start_tile(void)
{
    __asm__ volatile(
        "# edge.tensor.start_tile\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c0\n"
        :
        : "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_START_TILE_FUNCT7))
        : "memory");
}
#endif

static inline void edge_tensor_sync(void)
{
    __asm__ volatile(
        "# edge.tensor.sync\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c0\n"
        :
        : "i"(EDGE_TENSOR64_HIGH_WORD(EDGE_TENSOR_SYNC_FUNCT7))
        : "memory");
}

#ifdef __cplusplus
template <int dtype, int mode>
static inline void edge_actu_setcsr()
{
    static_assert(dtype >= 0 && dtype < 32, "actu dtype must fit imm5");
    static_assert(mode >= 0 && mode < 32, "actu mode must fit imm5");
    __asm__ volatile(
        "# edge.actu.setcsr dtype=%0 mode=%1\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c2\n"
        :
        : "i"(dtype), "i"(mode),
          "i"(EDGE_ACTU64_SETCSR_HIGH_WORD(dtype, mode))
        : "memory");
}
#endif

static inline void edge_actu_setin(const void *in_ptr)
{
    uintptr_t edge_in_ptr = (uintptr_t)in_ptr;

    __asm__ volatile(
        "# edge.actu.setin ptr=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        :
        : "r"(edge_in_ptr),
          "i"(EDGE_ACTU64_HIGH_WORD(EDGE_ACTU_SETIN_FUNCT7))
        : "memory");
}

static inline void edge_actu_setout(void *out_ptr)
{
    uintptr_t edge_out_ptr = (uintptr_t)out_ptr;

    __asm__ volatile(
        "# edge.actu.setout ptr=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        :
        : "r"(edge_out_ptr),
          "i"(EDGE_ACTU64_HIGH_WORD(EDGE_ACTU_SETOUT_FUNCT7))
        : "memory");
}

static inline void edge_actu_setn(uintptr_t n)
{
    uintptr_t edge_n = n;

    __asm__ volatile(
        "# edge.actu.setn n=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        :
        : "r"(edge_n),
          "i"(EDGE_ACTU64_HIGH_WORD(EDGE_ACTU_SETN_FUNCT7))
        : "memory");
}

static inline void edge_actu_setscalar(uintptr_t value)
{
    uintptr_t edge_value = value;

    __asm__ volatile(
        "# edge.actu.setscalar value=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n"
        :
        : "r"(edge_value),
          "i"(EDGE_ACTU64_HIGH_WORD(EDGE_ACTU_SETSCALAR_FUNCT7))
        : "memory");
}

#ifdef __cplusplus
template <uintptr_t value>
static inline void edge_actu_setscalar_imm()
{
    static_assert(value <= 0xffffu, "actu scalar immediate must fit 16 bits");

    __asm__ volatile(
        "# edge.actu.setscalar_imm value=%c0\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c1\n"
        :
        : "i"(value),
          "i"(EDGE_DMA64_HIGH_WORD(EDGE_ACTU_SETSCALAR_FUNCT7, value))
        : "memory");
}
#endif

static inline void edge_actu_start(void)
{
    __asm__ volatile(
        "# edge.actu.start\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c0\n"
        :
        : "i"(EDGE_ACTU64_HIGH_WORD(EDGE_ACTU_START_FUNCT7))
        : "memory");
}

static inline void edge_actu_sync(void)
{
    __asm__ volatile(
        "# edge.actu.sync\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c0\n"
        :
        : "i"(EDGE_ACTU64_HIGH_WORD(EDGE_ACTU_SYNC_FUNCT7))
        : "memory");
}

#ifdef __cplusplus
template <int mode>
static inline void edge_cmpu_setcsr()
{
    static_assert(mode >= 0 && mode <= 8, "cmpu mode must be 0..8");
    __asm__ volatile(
        "# edge.cmpu.setcsr mode=%0\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c1\n"
        :
        : "i"(mode), "i"(EDGE_CMPU64_SETCSR_HIGH_WORD(mode))
        : "memory");
}
#endif

static inline void edge_cmpu_setlhs(const void *ptr)
{
    uintptr_t value = (uintptr_t)ptr;
    __asm__ volatile(
        "# edge.cmpu.setlhs ptr=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n" : : "r"(value),
        "i"(EDGE_CMPU64_HIGH_WORD(EDGE_CMPU_SETLHS_FUNCT7)) : "memory");
}

static inline void edge_cmpu_setrhs(const void *ptr)
{
    uintptr_t value = (uintptr_t)ptr;
    __asm__ volatile(
        "# edge.cmpu.setrhs ptr=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n" : : "r"(value),
        "i"(EDGE_CMPU64_HIGH_WORD(EDGE_CMPU_SETRHS_FUNCT7)) : "memory");
}

static inline void edge_cmpu_setmask(const uint8_t *ptr)
{
    uintptr_t value = (uintptr_t)ptr;
    __asm__ volatile(
        "# edge.cmpu.setmask ptr=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n" : : "r"(value),
        "i"(EDGE_CMPU64_HIGH_WORD(EDGE_CMPU_SETMASK_FUNCT7)) : "memory");
}

static inline void edge_cmpu_setout(void *ptr)
{
    uintptr_t value = (uintptr_t)ptr;
    __asm__ volatile(
        "# edge.cmpu.setout ptr=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n" : : "r"(value),
        "i"(EDGE_CMPU64_HIGH_WORD(EDGE_CMPU_SETOUT_FUNCT7)) : "memory");
}

static inline void edge_cmpu_setn(uintptr_t n)
{
    __asm__ volatile(
        "# edge.cmpu.setn n=%0\n"
        ".insn r 0x3f, 0, 0, x0, %0, x0\n"
        ".word %c1\n" : : "r"(n),
        "i"(EDGE_CMPU64_HIGH_WORD(EDGE_CMPU_SETN_FUNCT7)) : "memory");
}

static inline void edge_cmpu_start(void)
{
    __asm__ volatile(
        "# edge.cmpu.start\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c0\n" : :
        "i"(EDGE_CMPU64_HIGH_WORD(EDGE_CMPU_START_FUNCT7)) : "memory");
}

static inline void edge_cmpu_sync(void)
{
    __asm__ volatile(
        "# edge.cmpu.sync\n"
        ".insn r 0x3f, 0, 0, x0, x0, x0\n"
        ".word %c0\n" : :
        "i"(EDGE_CMPU64_HIGH_WORD(EDGE_CMPU_SYNC_FUNCT7)) : "memory");
}

#ifdef __cplusplus
template <int csr_id>
static inline uintptr_t edge_accel_getcsr()
{
    static_assert(csr_id >= EDGE_ACCEL_CSR_CMPU_MAX_VALUE &&
                  csr_id <= EDGE_ACCEL_CSR_ACTU_EXP_SUM,
                  "accelerator CSR ID is out of range");
    uintptr_t value;
    __asm__ volatile(
        "# edge.accel.getcsr csr=%c1\n"
        ".insn r 0x3f, 0, 0, %0, x0, x0\n"
        ".word %c2\n"
        : "=r"(value)
        : "i"(csr_id), "i"(EDGE_ACCEL64_GETCSR_HIGH_WORD(csr_id))
        : "memory");
    return value;
}

static inline uintptr_t edge_cmpu_get_max_value()
{
    return edge_accel_getcsr<EDGE_ACCEL_CSR_CMPU_MAX_VALUE>();
}

static inline uintptr_t edge_cmpu_get_argmax_idx()
{
    return edge_accel_getcsr<EDGE_ACCEL_CSR_CMPU_ARGMAX_IDX>();
}

static inline uintptr_t edge_cmpu_get_min_value()
{
    return edge_accel_getcsr<EDGE_ACCEL_CSR_CMPU_MIN_VALUE>();
}

static inline uintptr_t edge_cmpu_get_argmin_idx()
{
    return edge_accel_getcsr<EDGE_ACCEL_CSR_CMPU_ARGMIN_IDX>();
}

static inline uintptr_t edge_actu_get_exp_sum()
{
    return edge_accel_getcsr<EDGE_ACCEL_CSR_ACTU_EXP_SUM>();
}
#endif

#ifdef __cplusplus
struct float32_t {
    float value;

    float32_t() = default;
    float32_t(float value_in) : value(value_in) {}

    operator float() const { return value; }
};

struct float16_t {
    __fp16 value;

    float16_t() = default;
    float16_t(float32_t value_in) : value((__fp16)value_in.value) {}
    float16_t(float value_in) : value((__fp16)value_in) {}

    operator float32_t() const { return float32_t((float)value); }
    operator float32_t() const volatile { return float32_t((float)value); }

    float16_t &operator=(float32_t value_in)
    {
        value = (__fp16)value_in.value;
        return *this;
    }

    float16_t &operator=(float value_in)
    {
        value = (__fp16)value_in;
        return *this;
    }

    volatile float16_t &operator=(float32_t value_in) volatile
    {
        value = (__fp16)value_in.value;
        return *this;
    }

    volatile float16_t &operator=(float value_in) volatile
    {
        value = (__fp16)value_in;
        return *this;
    }
};

struct bfloat16_t {
    uint16_t bits;

    bfloat16_t() = default;
    explicit bfloat16_t(uint16_t bits_in) : bits(bits_in) {}
    bfloat16_t(float32_t value) : bits(edge_bf16_from_f32_rne(value.value)) {}
    bfloat16_t(float value) : bits(edge_bf16_from_f32_rne(value)) {}

    static bfloat16_t from_bits(uint16_t bits_in)
    {
        bfloat16_t out;
        out.bits = bits_in;
        return out;
    }

    operator float32_t() const
    {
        return float32_t(edge_bf16_load_f32_ptr(&bits));
    }

    operator float32_t() const volatile
    {
        return float32_t(edge_bf16_load_f32_ptr(&bits));
    }

    bfloat16_t &operator=(float32_t value)
    {
        edge_bf16_store_f32_ptr(&bits, value.value);
        return *this;
    }

    bfloat16_t &operator=(float value)
    {
        edge_bf16_store_f32_ptr(&bits, value);
        return *this;
    }

    volatile bfloat16_t &operator=(float32_t value) volatile
    {
        edge_bf16_store_f32_ptr(&bits, value.value);
        return *this;
    }

    volatile bfloat16_t &operator=(float value) volatile
    {
        edge_bf16_store_f32_ptr(&bits, value);
        return *this;
    }
};

static inline float32_t edge_bfloat16_load(const bfloat16_t *ptr)
{
    return (float32_t)(*ptr);
}

static inline float32_t edge_bfloat16_load(const volatile bfloat16_t *ptr)
{
    return (float32_t)(*ptr);
}

static inline void edge_bfloat16_store(bfloat16_t *ptr, float32_t value)
{
    *ptr = value;
}

static inline void edge_bfloat16_store(volatile bfloat16_t *ptr,
                                       float32_t value)
{
    *ptr = value;
}

static inline float32_t edge_float16_load(const float16_t *ptr)
{
    return (float32_t)(*ptr);
}

static inline float32_t edge_float16_load(const volatile float16_t *ptr)
{
    return (float32_t)(*ptr);
}

static inline void edge_float16_store(float16_t *ptr, float32_t value)
{
    *ptr = value;
}

static inline void edge_float16_store(volatile float16_t *ptr, float32_t value)
{
    *ptr = value;
}

static inline float32_t operator+(float32_t lhs, float32_t rhs)
{
    return float32_t(lhs.value + rhs.value);
}

static inline float32_t operator-(float32_t lhs, float32_t rhs)
{
    return float32_t(lhs.value - rhs.value);
}

static inline float32_t operator*(float32_t lhs, float32_t rhs)
{
    return float32_t(lhs.value * rhs.value);
}

static inline float32_t operator/(float32_t lhs, float32_t rhs)
{
    return float32_t(lhs.value / rhs.value);
}

static inline float32_t operator-(float32_t value)
{
    return float32_t(-value.value);
}

static inline float32_t operator+(const float16_t &lhs, const float16_t &rhs)
{
    return (float32_t)lhs + (float32_t)rhs;
}

static inline float32_t operator-(const float16_t &lhs, const float16_t &rhs)
{
    return (float32_t)lhs - (float32_t)rhs;
}

static inline float32_t operator*(const float16_t &lhs, const float16_t &rhs)
{
    return (float32_t)lhs * (float32_t)rhs;
}

static inline float32_t operator/(const float16_t &lhs, const float16_t &rhs)
{
    return (float32_t)lhs / (float32_t)rhs;
}

static inline float32_t operator+(float32_t lhs, const float16_t &rhs)
{
    return lhs + (float32_t)rhs;
}

static inline float32_t operator-(float32_t lhs, const float16_t &rhs)
{
    return lhs - (float32_t)rhs;
}

static inline float32_t operator*(float32_t lhs, const float16_t &rhs)
{
    return lhs * (float32_t)rhs;
}

static inline float32_t operator/(float32_t lhs, const float16_t &rhs)
{
    return lhs / (float32_t)rhs;
}

static inline float32_t operator+(const float16_t &lhs, float32_t rhs)
{
    return (float32_t)lhs + rhs;
}

static inline float32_t operator-(const float16_t &lhs, float32_t rhs)
{
    return (float32_t)lhs - rhs;
}

static inline float32_t operator*(const float16_t &lhs, float32_t rhs)
{
    return (float32_t)lhs * rhs;
}

static inline float32_t operator/(const float16_t &lhs, float32_t rhs)
{
    return (float32_t)lhs / rhs;
}

static inline float32_t operator+(const bfloat16_t &lhs, const bfloat16_t &rhs)
{
    return (float32_t)lhs + (float32_t)rhs;
}

static inline float32_t operator-(const bfloat16_t &lhs, const bfloat16_t &rhs)
{
    return (float32_t)lhs - (float32_t)rhs;
}

static inline float32_t operator*(const bfloat16_t &lhs, const bfloat16_t &rhs)
{
    return (float32_t)lhs * (float32_t)rhs;
}

static inline float32_t operator/(const bfloat16_t &lhs, const bfloat16_t &rhs)
{
    return (float32_t)lhs / (float32_t)rhs;
}

static inline float32_t operator+(float32_t lhs, const bfloat16_t &rhs)
{
    return lhs + (float32_t)rhs;
}

static inline float32_t operator-(float32_t lhs, const bfloat16_t &rhs)
{
    return lhs - (float32_t)rhs;
}

static inline float32_t operator*(float32_t lhs, const bfloat16_t &rhs)
{
    return lhs * (float32_t)rhs;
}

static inline float32_t operator/(float32_t lhs, const bfloat16_t &rhs)
{
    return lhs / (float32_t)rhs;
}

static inline float32_t operator+(const bfloat16_t &lhs, float32_t rhs)
{
    return (float32_t)lhs + rhs;
}

static inline float32_t operator-(const bfloat16_t &lhs, float32_t rhs)
{
    return (float32_t)lhs - rhs;
}

static inline float32_t operator*(const bfloat16_t &lhs, float32_t rhs)
{
    return (float32_t)lhs * rhs;
}

static inline float32_t operator/(const bfloat16_t &lhs, float32_t rhs)
{
    return (float32_t)lhs / rhs;
}
#endif

#endif
