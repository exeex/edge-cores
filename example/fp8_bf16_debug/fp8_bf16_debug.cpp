#include "intrinsic/edge_sim_console.hpp"

template <typename LowPrecision>
static void print_arithmetic(const char *name, const LowPrecision &lhs,
                             const LowPrecision &rhs)
{
    static_assert(__is_same(decltype(lhs * rhs), float),
                  "low-precision arithmetic must return float");

    // The overloaded operators expand their operands and return FP32. Only an
    // explicit low-precision destination rounds and stores the final result.
    const float chained = (lhs + rhs) * (lhs - rhs);
    const LowPrecision rounded_mul = lhs * rhs;
    printf("%s arithmetic: add=%f sub=%f mul=%f div=%f\n", name,
           lhs + rhs, lhs - rhs, lhs * rhs, lhs / rhs);
    printf("%s result types: chained-f32=%f rounded-lowp=%f\n", name,
           chained, static_cast<float>(rounded_mul));
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
    const fp8e5m2_t e5m2 = 1.5f;
    const fp8e4m3fn_t e4m3fn = 1.5f;
    printf("Low precision: bf16=%f e5m2=%f e4m3fn=%f\n",
           static_cast<float>(bf16),
           static_cast<float>(e5m2), static_cast<float>(e4m3fn));

    const bfloat16_t bf16_rhs = 0.5f;
    const fp8e5m2_t e5m2_rhs = 0.5f;
    const fp8e4m3fn_t e4m3fn_rhs = 0.5f;
    print_arithmetic("BF16", bf16, bf16_rhs);
    print_arithmetic("FP8 E5M2", e5m2, e5m2_rhs);
    print_arithmetic("FP8 E4M3FN", e4m3fn, e4m3fn_rhs);
    return 0;
}
