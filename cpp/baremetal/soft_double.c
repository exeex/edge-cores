#include <stdint.h>

// RV32IMF has no D conversion instruction. C varargs still promote float to
// double, so provide the exact widening operation used by printf("%f", value).
double __extendsfdf2(float value)
{
    union {
        float f32;
        uint32_t bits;
    } input = { .f32 = value };
    union {
        double f64;
        uint64_t bits;
    } output;

    const uint32_t sign = input.bits >> 31;
    const uint32_t exponent = (input.bits >> 23) & 0xffu;
    uint32_t fraction = input.bits & 0x7fffffu;
    uint64_t exponent64;

    if (exponent == 0xffu) {
        exponent64 = 0x7ffu;
        if (fraction != 0u)
            fraction |= 0x400000u;
    } else if (exponent != 0u) {
        exponent64 = exponent + (1023u - 127u);
    } else if (fraction != 0u) {
        int unbiased = -126;
        while ((fraction & 0x800000u) == 0u) {
            fraction <<= 1;
            --unbiased;
        }
        exponent64 = (uint64_t)(unbiased + 1023);
        fraction &= 0x7fffffu;
    } else {
        exponent64 = 0u;
    }

    output.bits = ((uint64_t)sign << 63) |
                  (exponent64 << 52) | ((uint64_t)fraction << 29);
    return output.f64;
}
