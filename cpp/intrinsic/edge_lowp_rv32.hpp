#ifndef EDGE_LOWP_RV32_HPP
#define EDGE_LOWP_RV32_HPP

#include <stdint.h>

// Edge32 uses the same scalar FP4 move and FP8 memory encodings as the
// earlier core. Keep these C++ wrappers available to RV32 examples.
struct fp4x16_t {
    uint64_t data;
};

static_assert(sizeof(fp4x16_t) == 8, "FP4 vector must hold 16 nibbles");

static inline float edge_fp4_to_fp32(uint8_t fp4)
{
    float result;
    uintptr_t nibble = fp4 & 0x0fu;
    __asm__ volatile(".insn r 0x53, 0, 0x7b, %0, %1, x0"
                     : "=f"(result) : "r"(nibble));
    return result;
}

static inline uint8_t edge_fp32_to_fp4(float value)
{
    uintptr_t nibble;
    __asm__ volatile(".insn r 0x53, 0, 0x73, %0, %1, x0"
                     : "=r"(nibble) : "f"(value));
    return static_cast<uint8_t>(nibble);
}

static inline float get_element_fp4(fp4x16_t value, int index)
{
    return edge_fp4_to_fp32(
        static_cast<uint8_t>((value.data >> (index * 4)) & 0x0fu));
}

static inline void set_element_fp4(fp4x16_t &value, float element, int index)
{
    const unsigned shift = static_cast<unsigned>(index) * 4u;
    const uint64_t mask = UINT64_C(0xf) << shift;
    const uint64_t nibble = edge_fp32_to_fp4(element) & 0x0fu;
    value.data = (value.data & ~mask) | (nibble << shift);
}

static inline float unpack_next_fp4(fp4x16_t &value)
{
    const float result = edge_fp4_to_fp32(static_cast<uint8_t>(value.data));
    value.data >>= 4;
    return result;
}

static inline void pack_next_fp4(fp4x16_t &value, float element)
{
    value.data = (value.data >> 4) |
                 (static_cast<uint64_t>(edge_fp32_to_fp4(element) & 0x0fu)
                  << 60);
}

template <int Format>
struct edge_fp8_t {
    static_assert(Format == 6 || Format == 7, "unsupported FP8 format");
    uint8_t bits;

    edge_fp8_t() = default;
    edge_fp8_t(float value) { *this = value; }

    static edge_fp8_t from_bits(uint8_t raw_bits)
    {
        edge_fp8_t result;
        result.bits = raw_bits;
        return result;
    }

    operator float() const
    {
        float result;
        __asm__ volatile(".insn i 0x07, %c2, %0, 0(%1)"
                         : "=f"(result)
                         : "r"(&bits), "i"(Format), "m"(bits)
                         : "memory");
        return result;
    }

    edge_fp8_t &operator=(float value)
    {
        __asm__ volatile(".insn s 0x27, %c3, %1, 0(%2)"
                         : "=m"(bits)
                         : "f"(value), "r"(&bits), "i"(Format)
                         : "memory");
        return *this;
    }
};

using fp8e5m2_t = edge_fp8_t<6>;
using fp8e4m3fn_t = edge_fp8_t<7>;

static_assert(sizeof(fp8e5m2_t) == 1, "FP8 E5M2 must occupy one byte");
static_assert(sizeof(fp8e4m3fn_t) == 1, "FP8 E4M3FN must occupy one byte");

template <int Format>
static inline float operator+(const edge_fp8_t<Format> &lhs,
                              const edge_fp8_t<Format> &rhs)
{
    return static_cast<float>(lhs) + static_cast<float>(rhs);
}

template <int Format>
static inline float operator-(const edge_fp8_t<Format> &lhs,
                              const edge_fp8_t<Format> &rhs)
{
    return static_cast<float>(lhs) - static_cast<float>(rhs);
}

template <int Format>
static inline float operator*(const edge_fp8_t<Format> &lhs,
                              const edge_fp8_t<Format> &rhs)
{
    return static_cast<float>(lhs) * static_cast<float>(rhs);
}

template <int Format>
static inline float operator/(const edge_fp8_t<Format> &lhs,
                              const edge_fp8_t<Format> &rhs)
{
    return static_cast<float>(lhs) / static_cast<float>(rhs);
}

static inline float operator+(const bfloat16_t &lhs, const bfloat16_t &rhs)
{
    return static_cast<float>(lhs) + static_cast<float>(rhs);
}

static inline float operator-(const bfloat16_t &lhs, const bfloat16_t &rhs)
{
    return static_cast<float>(lhs) - static_cast<float>(rhs);
}

static inline float operator*(const bfloat16_t &lhs, const bfloat16_t &rhs)
{
    return static_cast<float>(lhs) * static_cast<float>(rhs);
}

static inline float operator/(const bfloat16_t &lhs, const bfloat16_t &rhs)
{
    return static_cast<float>(lhs) / static_cast<float>(rhs);
}

#endif
