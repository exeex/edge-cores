# Tensor formats and direct FP4 Linear examples

Run the v0.3 Tensor features on the public E3/Edge32 Verilator simulator:

```sh
./example/tensor_formats/run.sh
```

Requires the initialized public RTL and NNC submodules, Verilator, LLVM and
Python 3 for ELF conversion. PyTorch is needed only to refresh the fixtures.
The runner builds the simulator once and then six bare-metal programs, using
the shared startup, linker and runtime. Each program checks every output
bit-for-bit, returns nonzero on a mismatch, and must produce simulator
`TEST PASS`. The packed program also checks its 26-case completion marker.
Logs and `summary.tsv` are written under the ignored `build/` directory.
Set `EDGE_TENSOR_FORMATS_OUT` or `EDGE_VERILATOR_OUT` to override build locations.
After explicitly building the current RTL, reuse the simulator with
`./example/tensor_formats/run.sh --skip-verilator-build`.

## Direct FP4 Linear examples

Start with [group32/main.cpp](group32/main.cpp) and its
[data.hpp](group32/data.hpp). Each FP4 example has only these two files:

- `data.hpp`: literal BF16 input, packed FP4 weights with BF16 scales, expected
  output bits and an output buffer.
- `main.cpp`: wrap the arrays in Tensor views, call
  `nnedge::op::linear_fp4()`, and compare output.

There is no generated forward function, Context, model initialization wrapper,
custom memcpy or model-specific linker symbol. `main.cpp` includes just
`libnn/ops.hpp` and `data.hpp`; NNC's umbrella header exposes the direct kernel. The runtime manages its private
scratch, DMA, circular weight loads and BF22 partial sums. Input and output
are ordinary contiguous external-memory arrays. The CPU reads output after
this synchronous call has completed its cache maintenance.

```cpp
Tensor<data::Bf16> x(Shape(1, 32), data::input);
Tensor<data::Bf16> y(Shape(1, 8), data::output);
using Pack = nnedge::FP4WeightPack;
// data::weights is an array of Pack objects (144 bytes each).
Tensor<Pack> weights(Shape(sizeof(data::weights) / sizeof(Pack)), data::weights);
nnedge::op::linear_fp4(y, x, weights);
```

`WeightPack<WType, SType, Tiles, Scales>` describes one complete output-major
slot. `SType=0` selects BF16 scales; other scale types are reserved and rejected
at compile time. `Tiles` is the number of consecutive 8x8 weight tiles after
the scales (1–255), so the K group is `8*Tiles`. `Scales` defaults to 8 for
quantized weights; use 1 for a broadcast scale. `WeightPack<BF16>` defaults to
one scale-free tile (`Scales=0`); explicitly select 1 or 8 for scaled BF16.
Only the slot end is padded to 16 bytes. `sizeof(Pack)` is the DMA stride;
`Tensor<Pack>` shapes count packs, not bytes. Packs are ordered by output block,
then K group, so `[N/8, K/(8*Tiles)]` is a natural shape. For group64, this is
`[2,2]`: four packs, each containing eight BF16 scales and four FP4 tiles.
The general `linear_weight_slots(y, x, weights)` call derives the format from
its element type. Named presets are defined in NNC's `linear_quant.hpp` and
exposed by `libnn/ops.hpp`:

| Entry point | Pack alias | Weight encoding |
| --- | --- | --- |
| `linear_fp4` | `FP4WeightPack` | FP4 E2M1 |
| `linear_q8_0` | `Q8_0WeightPack` | signed INT8 |
| `linear_fp8_e4m3fn` | `FP8E4M3FNWeightPack` | FP8 E4M3FN |
| `linear_fp8_e5m2` | `FP8E5M2WeightPack` | FP8 E5M2 |

These presets fix `SType=0, Tiles=4, Scales=8` (K32) and forward to the same
kernel. Each accepts its exact typed pack or a compiler-style byte tensor.
Use the general template for other group sizes or broadcast scales. NNC's
existing FP4 codegen keeps emitting `linear_fp4`; FP8/Q8 graph lowering is
not yet implemented. `linear_q8_0` expects converted E3 packing, not raw GGUF.
 The legacy
`linear_weight_slots<WType>(..., Tensor<uint8_t>)` overload remains available
for existing byte payloads and generated code.

The `weight_pack` program runs the NNC-owned typed runtime regression:
16 configurations covering all five weight formats, broadcast and per-lane
scales, K16/K32/K64 groups, scale-free BF16, nine input rows, ring wrap, and
invalid pack counts/K dimensions. It compares against a scalar integer golden. Default quant configurations
exercise all four named entry points; the other configurations use the
general template.

Only data and goldens are frozen from NNC; the entry points are handwritten.

| Program | Original NNC smoke | What it demonstrates |
| --- | --- | --- |
| `group32` | `smoke_linear_fp4_group32.py` | M1/K32/N8, signed E2M1 weights and distinct BF16 scales per lane |
| `group64` | `smoke_linear_fp4_group64.py` | M1/K64/N16, two **K32** groups with changing scales; scale applies only to the new dot, not the accumulated psum |
| `precision` | `smoke_linear_fp4_precision.py` | M1/K256/N8, BF22 intermediate accumulation: `1 + 31*2^-12` rounds to final BF16 `0x3f81`, or `1.0078125` |
| `ring_wrap` | `smoke_linear_fp4.py` | M1/K128/N24, twelve packed slots through a four-slot circular ring, including a zero weight group |

`group64` retains its upstream case name; it means total K=64, not a K64 scale
group. The direct example below is what checks configurable K64 grouping.
The [manifest](data_manifest.json) records the NNC revision, model hashes,
payload hashes and golden hashes. The goldens come from evaluating the original
models, rather than copying simulator results. `Bf16(0x...)` in `data.hpp`
specifies raw BF16 bits; weights are already serialized as packed E2M1 slots.

To deliberately refresh the literal data after reviewing a compiler change,
use the repository PyTorch environment and rerun the examples. This only
rewrites `data.hpp` and the manifest; it does not rewrite `main.cpp`:

```sh
.venv/bin/python example/tensor_formats/freeze_nnc.py
./example/tensor_formats/run.sh
```

The literal arrays are a release snapshot of selected NNC data. Add new
operator semantics and compiler tests in NNC; these fixtures do not replace `tests/run.sh nnc`.

## Parameterized packed WSLD

[packed.cpp](packed.cpp) is a direct intrinsic tutorial covering 26 configurations.
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
[release note](../../docs/releases/v0.3.md#q8_0-style-configuration).
The examples use already encoded representable weights, so they check
packing, loading and execution rather than quantizer quality or GGUF import.

All five formats exercise K8/K32 slots, one/eight scales and both transpose
modes. FP4 and both FP8 formats additionally exercise K16/K64 slots.
These direct cases check each tile output separately. The direct FP4 Linear cases
exercise accumulation across K tiles with the current runtime's K32 groups.
