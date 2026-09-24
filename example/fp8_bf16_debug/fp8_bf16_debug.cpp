#include "intrinsic/edge_sim_console.hpp"

template <typename LowPrecision>
static bool check_arithmetic(const char *name, const LowPrecision &lhs,
                             const LowPrecision &rhs, unsigned expected_lhs,
                             unsigned expected_rhs, unsigned expected_product)
{
    static_assert(__is_same(decltype(lhs * rhs), float),
                  "low-precision arithmetic must return float");

    const float sum = lhs + rhs;
    const float difference = lhs - rhs;
    const float product = lhs * rhs;
    const float quotient = lhs / rhs;
    const float chained = (lhs + rhs) * (lhs - rhs);
    const LowPrecision rounded = product;
    const bool passed = lhs.bits == expected_lhs &&
                        rhs.bits == expected_rhs &&
                        static_cast<float>(lhs) == 1.5f &&
                        static_cast<float>(rhs) == 0.5f &&
                        sum == 2.0f && difference == 1.0f &&
                        product == 0.75f && quotient == 3.0f &&
                        chained == 2.0f &&
                        rounded.bits == expected_product &&
                        static_cast<float>(rounded) == 0.75f;

    printf("%s arithmetic: add=%f sub=%f mul=%f div=%f\n", name,
           sum, difference, product, quotient);
    printf("%s result types: chained-f32=%f rounded-lowp=%f\n", name,
           chained, static_cast<float>(rounded));
    printf("%s scalar %s lhs=0x%04x rhs=0x%04x rounded=0x%04x\n",
           name, passed ? "PASS" : "FAIL",
           static_cast<unsigned>(lhs.bits),
           static_cast<unsigned>(rhs.bits),
           static_cast<unsigned>(rounded.bits));
    return passed;
}

extern "C" int main(void)
{
    const float promoted = -12.375f;
    const double native = 1.9995;
    printf("Float debug: %f %.3f %+09.2f %.0f\n",
           promoted, native, 3.5, 1.6);
    printf("Float edges: negzero=%.2f carry=%.3f alt=%#.0f "
           "left=[%-8.2f]\n",
           -0.0, 0.9996, 2.0, 1.25);
    printf("Float special: %f %F %f wide=%.12f\n",
           __builtin_nan(""), __builtin_inf(), -__builtin_inf(), 0.5);

    const bfloat16_t bf16 = 1.5f;
    const bfloat16_t bf16_rhs = 0.5f;
    const fp8e5m2_t e5m2 = 1.5f;
    const fp8e5m2_t e5m2_rhs = 0.5f;
    const fp8e4m3fn_t e4m3fn = 1.5f;
    const fp8e4m3fn_t e4m3fn_rhs = 0.5f;
    printf("Low precision: bf16=%f e5m2=%f e4m3fn=%f\n",
           static_cast<float>(bf16),
           static_cast<float>(e5m2), static_cast<float>(e4m3fn));

    const bool bf16_ok = check_arithmetic("BF16", bf16, bf16_rhs,
                                          0x3fc0u, 0x3f00u, 0x3f40u);
    const bool e5m2_ok = check_arithmetic("FP8 E5M2", e5m2, e5m2_rhs,
                                          0x3eu, 0x38u, 0x3au);
    const bool e4m3fn_ok = check_arithmetic("FP8 E4M3FN", e4m3fn,
                                            e4m3fn_rhs,
                                            0x3cu, 0x30u, 0x34u);
    return (bf16_ok && e5m2_ok && e4m3fn_ok) ? 0 : 1;
}
