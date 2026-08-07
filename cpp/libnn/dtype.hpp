#pragma once

#include <stdint.h>

namespace nnedge {

using size_t = unsigned long;

struct bfloat16_t {
    uint16_t bits;

    constexpr bfloat16_t() : bits(0) {}
    explicit constexpr bfloat16_t(uint16_t raw_bits) : bits(raw_bits) {}

    static constexpr bfloat16_t from_bits(uint16_t raw_bits)
    {
        return bfloat16_t(raw_bits);
    }

    static bfloat16_t from_float(float value)
    {
        union {
            float f32;
            uint32_t u32;
        } bits = { value };
        bits.u32 += 0x7fffu + ((bits.u32 >> 16) & 1u);
        return bfloat16_t(static_cast<uint16_t>(bits.u32 >> 16));
    }

    float to_float() const
    {
        union {
            uint32_t u32;
            float f32;
        } bits = { static_cast<uint32_t>(this->bits) << 16 };
        return bits.f32;
    }
};

} // namespace nnedge
