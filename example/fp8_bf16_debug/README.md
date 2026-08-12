# FP8 and BF16 debug

Build and run the floating-point formatter and low-precision scalar example:

```sh
./example/fp8_bf16_debug/run.sh
```

The example constructs BF16, FP8 E5M2, and FP8 E4M3FN values from FP32. FP8
conversion uses the custom load/store encodings documented in
`src/edge-rv-lite/README.md`. An explicit cast at each FP8 variadic call site
loads and expands the byte into an FP32 FPR; the C++ default argument promotion
then supplies the `double` consumed by `%f`.

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

The formatter checks also cover precision, signs, zero padding, rounding,
negative zero, alternate form, alignment, NaN, infinity, and precision beyond
the nine meaningful FP32 fractional digits.
