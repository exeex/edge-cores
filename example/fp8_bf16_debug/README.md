# FP8 and BF16 scalar debug

Build and run the low-precision scalar example on the `edge-e3enc` simulator:

```sh
./example/fp8_bf16_debug/run.sh
```

The example converts 1.5 and 0.5 from FP32 to BF16, FP8 E5M2, and FP8
E4M3FN. It checks the stored bits, conversion back to FP32, arithmetic results,
and a rounded low-precision product. Each format prints `scalar PASS` only
after every check succeeds, and the program returns nonzero on a mismatch.

Arithmetic operators expand their operands and return `float`, so source code
can use low-precision values directly while expressions remain FP32:

```cpp
fp8e5m2_t a = 1.5f;
fp8e5m2_t b = 0.5f;

const float mul = a * b;
const float chained = (a + b) * (a - b);
fp8e5m2_t rounded = a * b;
```

The first two results stay FP32. Only the explicitly declared `rounded` result
is converted and stored back to FP8.

The example also checks the RV32 simulator console's `%f`/`%F` formatting:
precision, signs, padding, rounding, negative zero, alignment, NaN, infinity,
and precision beyond nine fractional digits.
