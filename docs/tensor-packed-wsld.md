# Parameterized packed WSLD

[NNC packed WSLD regression](../src/edge-nnc/nnc/test/packed_wsld_main.cpp) is a direct intrinsic tutorial covering 26 configurations.
It builds three packed slots at compile time, transfers them through a two-entry
circular DMA ring, and checks every output against a separate integer matrix
calculation. Signed, asymmetric weights distinguish transpose modes. Canary
words guard the ring allocation and output region.

Each slot has this layout:

```text
[ 1 or 8 little-endian BF16 scales ][ T packed 8x8 weight tiles ][ end padding ]
slot_bytes = align_up(2*scale_count + T*tile_bytes, 16)
```

| Weight format | Intrinsic constant | Tile bytes |
| --- | --- | ---: |
| BF16 | `EDGE_TENSOR_WTYPE_BF16` | 128 |
| Signed INT8 | `EDGE_TENSOR_WTYPE_INT8` | 64 |
| FP4 E2M1 | `EDGE_TENSOR_WTYPE_FP4` | 32 |
| FP8 E4M3FN | `EDGE_TENSOR_WTYPE_FP8_E4M3FN` | 64 |
| FP8 E5M2 | `EDGE_TENSOR_WTYPE_FP8_E5M2` | 64 |

FP4 stores the earlier element in the low nibble. Weight payloads immediately
follow the scale bytes, including when a single two-byte scale makes the first
weight tile unaligned; padding belongs only at the end of the slot.

```cpp
// Four K8 tiles share eight BF16 output-lane scales: K32 INT8 grouping.
edge_tensor_wsld_circular<false, 4, EDGE_TENSOR_WTYPE_INT8, 8>();
// Eight K8 tiles: K64 FP4 grouping.
edge_tensor_wsld_circular<false, 8, EDGE_TENSOR_WTYPE_FP4, 8>();
```

The first configuration has Q8_0-style group length and dequantization
`w = scale*q`; it needs conversion from llama.cpp's FP16-scaled Q8_0 file
layout to BF16 scales and E3 tile order. See the
[release note](releases/v0.3.md#q8_0-style-configuration).
The examples use already encoded representable weights, so they check
packing, loading and execution rather than quantizer quality or GGUF import.

All five formats exercise K8/K32 slots, one/eight scales and both transpose
modes. FP4 and both FP8 formats additionally exercise K16/K64 slots.
These direct cases check each tile output separately. The direct FP4 Linear cases
exercise accumulation across K tiles with the current runtime's K32 groups.

Run the low-level regression and typed weight-pack regression with:

```sh
./tests/nnc/packed.sh
```

They remain part of `./tests/run.sh nnc`. User-facing quantized Linear examples
live in `example/linear_fp4`, `example/linear_q8_0`,
`example/linear_fp8_e4m3fn`, and `example/linear_fp8_e5m2`.
