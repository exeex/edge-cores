# Edge intrinsic user manual

[`edge_intrinsic.hpp`](edge_intrinsic.hpp) is the low-level software interface
to the Edge RV platform and the edge-e3 DMA, Tensor, activation (ACTU), and
comparison/reduction (CMPU) engines. It also provides cache-maintenance
operations, BF16 conversion helpers, cycle counting, and simulator control.

The accelerator instruction encodings are provisional. Applications should
call the functions and use the public option constants in this header instead
of emitting instruction words or depending on `*_FUNCT7` and encoding macros.

## Requirements

- Compile for the 64-bit RISC-V Edge target. These intrinsics contain custom
  instructions and cannot execute on a normal host CPU.
- Add `cpp` to the include path and include the header as shown below.
- Prefer C++17 or newer. The basic platform, cache, DMA, BF16, and accelerator
  command functions are C-readable, but template configuration, option forms,
  circular-DMA overloads, accelerator result accessors, and numeric wrapper
  types require C++.
- Link with the Edge bare-metal linker script so that `EDGE_DTCM_BASE`,
  `EDGE_DTCM_SIZE`, and `EDGE_DTCM_MASK` resolve correctly.

```cpp
#include "intrinsic/edge_intrinsic.hpp"
```

The public examples build this interface with the repository's ordinary LLVM
flow. To build and run the smallest accelerator example:

```sh
./example/tensor/run.sh
```

## Programming model

DMA, Tensor, ACTU, and CMPU use a common command pattern:

1. Issue `set*` commands to describe a job.
2. Issue `start()` to submit it.
3. Perform independent scalar work or submit later jobs where appropriate.
4. Call the matching `sync()` before consuming results or reusing storage.

`start()` is asynchronous. Its compiler `"memory"` clobber prevents compiler
reordering, but it does not wait for the hardware operation to finish.
`sync()` is the hardware completion join for all earlier work on that engine.

```cpp
edge_actu_setcsr<0, 3>(); // Public edge-e3 mode 3: BF16 SiLU.
edge_actu_setin(input);
edge_actu_setout(output);
edge_actu_setn(element_count);
edge_actu_start();

// Independent scalar work may run here.

edge_actu_sync(); // output is now ready to consume.
```

Pointers passed to Tensor, ACTU, and CMPU normally refer to accelerator-visible
DTCM. Use DMA to stage external-memory data into DTCM and to copy results back.
The linker-defined `EDGE_DTCM_BASE`, `EDGE_DTCM_SIZE`, and `EDGE_DTCM_MASK`
describe the configured DTCM region.

## Scalar/DMA cache handoff

The normal accelerator data path does not require a cache operation for every
DMA transfer. Performance-oriented software should keep DMA buffers under DMA
or accelerator ownership and avoid scalar cached accesses to those buffers.
Adding a D-cache clean or invalidate around every transfer serializes the data
path and can be very expensive.

Cache maintenance is mainly a debug and bring-up tool for handing a cached DRAM
buffer between the scalar core and DMA. It is required only when the scalar
accessed that DRAM range through its D-cache:

| Ownership handoff | Required operation |
| --- | --- |
| Scalar writes DRAM, then DMA reads it | Clean the range after the final scalar write |
| DMA writes DRAM, then scalar reads it | After DMA completion, invalidate the range before the scalar read |
| DMA/accelerator remains the only owner | No D-cache operation |

The clean belongs to the scalar-to-DMA ownership handoff, not intrinsically to
the DMA start. Perform it once after scalar initialization or modification is
complete; later DMA reads need no additional clean until the scalar writes the
buffer again.

```cpp
// Debug/bring-up: initialize a cached DRAM buffer with scalar stores.
for (uintptr_t i = 0; i < count; ++i)
    dram_input[i] = make_input(i);

// Publish those scalar writes to DMA once.
edge_dcache_clean_range(dram_input, bytes);

// Repeated DMA reads do not need another clean while scalar leaves it alone.
edge_dma_start(dram_input, dtcm_input, bytes);
edge_dma_sync();
```

Similarly, invalidate a DMA-written DRAM range only when scalar code is about
to inspect it. If the scalar previously dirtied the same cache lines, resolve
that ownership conflict before allowing DMA to overwrite them; do not use such
shared ownership in a tuned accelerator path.

The cache line size is `EDGE_DCACHE_LINE_SIZE` (64 bytes). Range functions
round the start down and the end up to whole cache lines. Callers must ensure
that `ptr + len` does not overflow. Avoid calling a range function with a zero
length and an unaligned pointer: rounding can still select one cache line.

### Cache API

| Function | Operation |
| --- | --- |
| `edge_dcache_invalidate_all()` | Invalidate the complete D-cache |
| `edge_dcache_clean_all()` | Write back the complete D-cache |
| `edge_dcache_clean_invalidate_all()` | Write back and invalidate the complete D-cache |
| `edge_dcache_invalidate_va(addr)` | Invalidate the line containing `addr` |
| `edge_dcache_clean_va(addr)` | Write back the line containing `addr` |
| `edge_dcache_clean_invalidate_va(addr)` | Write back and invalidate the line containing `addr` |
| `edge_dcache_line_floor(addr)` | Round an address down to a cache-line boundary |
| `edge_dcache_line_ceil(addr)` | Round an address up to a cache-line boundary |
| `edge_dcache_clean_range(ptr, len)` | Write back all lines overlapping a byte range |
| `edge_dcache_invalidate_range(ptr, len)` | Invalidate all lines overlapping a byte range |
| `edge_dcache_clean_invalidate_range(ptr, len)` | Write back and invalidate all overlapping lines |

## Platform helpers

| Function | Description |
| --- | --- |
| `edge_get_cycle()` | Read the RISC-V `cycle` CSR |
| `edge_sim_putchar(ch)` | Write one byte to the simulator console CSR |

`edge_sim_console.hpp` provides a freestanding `printf`. Its `%f`/`%F`
formatter consumes the C variadic `double` argument, supports width, sign,
zero-pad and precision, and performs decimal conversion with D-encoded
floating-point operations plus `fcvt` to integer. Edge accepts the D encoding
and `double` ABI without compiler soft-float helpers, while the physical FPR
and arithmetic datapath retain FP32 precision. `fld`/`fsd` convert between an
IEEE64 memory payload and that canonical FP32 value. `%e` and `%g` remain
diagnostic placeholders.
| `edge_exit(return_value)` | Report a simulator return value, then remain in `wfi` forever |

`edge_exit()` does not return. Applications normally use the repository's
bare-metal startup and shutdown path rather than call it directly.

## DMA

All DMA sizes and strides are in bytes. DMA starts are asynchronous; call
`edge_dma_sync()` before reading the destination, reusing source or destination
storage, or assuming a circular producer has drained.

### Contiguous copy

```cpp
void edge_dma_start(const void *src, void *dst, uintptr_t len);
void edge_dma_sync();
```

`edge_dma_start()` is the preferred self-contained API for a contiguous copy.
`edge_dma_setsrc()` and `edge_dma_settar()` expose the corresponding descriptor
fields for advanced command construction.

### Strided source copies

```cpp
void edge_dma_start_strided(
    const void *src, void *dst,
    uintptr_t contiguous_bytes,
    uintptr_t source_stride_bytes,
    uintptr_t repeat_count);

void edge_dma_start_strided_2d(
    const void *src, void *dst,
    uintptr_t contiguous_bytes,
    uintptr_t x_stride_bytes, uintptr_t x_max,
    uintptr_t y_stride_bytes, uintptr_t y_max);
```

These functions gather fixed-size fragments from a strided source and pack
them into the destination stream. The one-dimensional form is equivalent to
an X axis with `repeat_count` entries and a single Y entry.

The lower-level descriptor setters are:

| Function | Descriptor field |
| --- | --- |
| `edge_dma_setn(contiguous_bytes)` | Bytes copied for each fragment |
| `edge_dma_setentry(entry_bytes)` | Transferred-byte interval for each circular synchronization event |
| `edge_dma_setx(source_stride_bytes, axis_max)` | X source stride and iteration count |
| `edge_dma_sety(source_stride_bytes, axis_max)` | Y source stride and iteration count |
| `edge_dma_setsrc(src)` | Source base address |
| `edge_dma_settar(dst)` | Target base address |

Each stride and axis count is packed into a 32-bit field. Keep both values in
the range `0..UINT32_MAX`.

### Circular producer

The C++ overload with every field explicit is:

```cpp
edge_dma_start_strided_circular(
    src, ring_base,
    contiguous_bytes,
    x_stride_bytes, x_max,
    y_stride_bytes, y_max,
    entry_bytes, ring_capacity_entries);
```

It gathers source fragments and writes them into a circular buffer for a
streaming consumer such as Tensor WLD or SLD. `entry_bytes` controls the
producer/consumer synchronization granularity: every time DMA has transferred
another `entry_bytes` bytes into the ring, it publishes one circular entry-ready
event. The consumer may then load that completed byte group.

This event is not `edge_dma_sync()`. It is the per-entry synchronization used
while DMA and an ASIC operate concurrently; `edge_dma_sync()` still waits for
completion of the DMA job as a whole. The hardware connection between an event
and a particular consumer is outside the software API.

`entry_bytes` does not select the source stride or total transfer size. Those
come from `contiguous_bytes` and the X/Y iteration fields. It only groups the
resulting byte stream into consumer-visible synchronization points. For
example, with 16-byte fragments and `entry_bytes = 128`, DMA publishes one
entry-ready event after every eight fragments have contributed 128 bytes.

`ring_capacity_entries` is the number of completed synchronization entries the
ring can hold, not a byte count. The corresponding ring storage requirement is
normally `entry_bytes * ring_capacity_entries` bytes. For current Tensor
streams, set `entry_bytes` to the number of bytes that one WLD or SLD operation
must consume. Each completed byte group then releases exactly one weight or
scale load.

C++ also provides these convenience overloads:

| Omitted arguments | Defaults |
| --- | --- |
| `entry_bytes` | `contiguous_bytes` |
| `entry_bytes`, `ring_capacity_entries` | `contiguous_bytes`, `x_max` |
| Y-axis and entry arguments | `y_stride_bytes = 0`, `y_max = 1`, `entry_bytes = contiguous_bytes`, `ring_capacity_entries = repeat_count` |

`edge_dma_start_circular(src, ring_base, tile_count)` is a lower-level circular
start that supplies only source, target, and tile count. Prefer the strided
circular API when a self-contained descriptor is required.

## BF16 conversion and scalar types

The raw BF16 helpers convert through the Edge BF16 load/store instructions:

```cpp
float edge_bf16_load_f32_ptr(const uint16_t *ptr);
void edge_bf16_store_f32_ptr(uint16_t *ptr, float value);
uint16_t edge_bf16_from_f32_rne(float value);
float edge_f32_from_bf16(uint16_t value);
```

`edge_bf16_from_f32_rne()` uses round-to-nearest-even behavior. C++ also
provides volatile-pointer overloads and these lightweight types:

| Type | Storage | Notes |
| --- | ---: | --- |
| `float32_t` | 32 bits | Wrapper around `float`; arithmetic result type |
| `float16_t` | 16 bits | Wrapper around compiler type `__fp16` |
| `bfloat16_t` | 16 bits | Raw BF16 bits with Edge load/store conversion |

Arithmetic operators on `float16_t` and `bfloat16_t` promote both operands to
`float32_t`; they do not return a 16-bit value. Use `from_bits()` only when the
input is already a raw BF16 encoding.

The explicit C++ load/store wrappers are useful in generic code and have both
ordinary and `volatile` pointer overloads:

| Function | Conversion |
| --- | --- |
| `edge_bfloat16_load(ptr)` | Load `bfloat16_t` and return `float32_t` |
| `edge_bfloat16_store(ptr, value)` | Convert and store `float32_t` as `bfloat16_t` |
| `edge_float16_load(ptr)` | Load `float16_t` and return `float32_t` |
| `edge_float16_store(ptr, value)` | Convert and store `float32_t` as `float16_t` |

```cpp
bfloat16_t a = 1.5f;
bfloat16_t b = bfloat16_t::from_bits(0x3f80u); // 1.0
float32_t sum = a + b;
```

## Tensor engine

Tensor configuration is a type-safe C++ template:

```cpp
edge_tensor_setcsr<DataType, WeightType>();
```

The data path currently supports only `bfloat16_t`. Weights may be
`bfloat16_t` or `int8_t`:

```cpp
edge_tensor_setcsr<bfloat16_t, bfloat16_t>(); // BF16 data and weights
edge_tensor_setcsr<bfloat16_t, int8_t>();     // BF16 data, INT8 weights
```

Unsupported types fail at compile time. The type-to-encoding traits keep raw
hardware integers out of application code and provide the extension point for
future FP4 and INT4 types. Format support still depends on the selected product
RTL.

### Weight and scale loading

WLD means weight load: it reads one batch of weights into the Tensor unit. SLD
means scale load: it reads one batch of scale or quantization data into the
Tensor unit. Their circular forms wait for the next DMA entry-ready event and
then consume the byte group completed at the configured `entry_bytes`
boundary.

| Function | Description |
| --- | --- |
| `edge_tensor_wld(ptr)` | Load a weight tile |
| `edge_tensor_wld_t(ptr)` | Load a weight tile using the transposed path |
| `edge_tensor_sld(ptr)` | Load a scale tile |
| `edge_tensor_wld_circular()` | Consume the next weight entry from a circular stream |
| `edge_tensor_wld_t_circular()` | Consume the next transposed-weight entry |
| `edge_tensor_sld_circular()` | Consume the next scale entry from a circular stream |
| `edge_tensor_sld_stream(ptr)` | Stream scales from a linear address |
| `edge_tensor_wsld_circular<transpose>()` | Consume a combined circular weight/scale stream |

In C++, the direct WLD, transposed WLD, and SLD functions accept the compile-time
option `EDGE_TENSOR_LOAD_OPT_REUSE`. Reuse does not read the pointer argument;
it reuses the resident data loaded by an earlier command.

```cpp
edge_tensor_wld(weight_tile);
// Later descriptor, same resident weights:
edge_tensor_wld<EDGE_TENSOR_LOAD_OPT_REUSE>();
```

WLD and SLD are software-facing operation names, not a requirement that future
products keep two separate loader modules. A later product may expose a more
general parameterized weight/scale loader, and WSLD may gain additional
configuration for quantization formats that combine weights, scales, or other
metadata in different layouts. Applications should continue to use the
intrinsic wrappers instead of depending on their current instruction encoding
or internal module split.

### Job descriptor and launch

| Function | Description |
| --- | --- |
| `edge_tensor_setin(ptr)` | Set the input base |
| `edge_tensor_setout(ptr)` | Set the output base |
| `edge_tensor_setpsum(ptr)` | Set the tile-wise accumulation or initial-bias input base |
| `edge_tensor_setn(n)` | Set the number of Tensor tile iterations |
| `edge_tensor_start<Options>()` | Submit a normal Tensor job |
| `edge_tensor_start_tile<Options>()` | Submit a tile job |
| `edge_tensor_sync()` | Wait for all earlier Tensor jobs |

`edge_tensor_setn(n)` makes the submitted Tensor job execute its product-specific
tile operation `n` times. If a product has an `M x K` Tensor tile, one job
performs `n x M x K` multiplications and their corresponding accumulations.
`n` is an execution count, not a byte count.

| Product | Tensor tile | Work for `setn(n)` | Input/output/psum elements per iteration | Datapath implication |
| --- | ---: | ---: | ---: | --- |
| edge-e3 | 8x8 | `n x 8 x 8` multiplications | 8 each | Baseline compute and IOP bandwidth |
| edge-p3 | 8x16 | `n x 8 x 16` multiplications | 8 each | 2x compute with the same IOP throughput as edge-e3 |
| edge-e4 | 16x16 | `n x 16 x 16` multiplications | 16 each | 2x IOP and SRAM bandwidth relative to edge-e3 |

Here, IOP means the input, output, and partial-sum streams. The P-series widens
the compute tile without widening those streams: edge-p3 doubles edge-e3
compute throughput while retaining eight-element input, output, and psum
transfers. Moving from edge-e3 to edge-e4 widens those transfers from eight to
16 elements and therefore doubles the required SRAM bandwidth.

### Partial-sum channel

The psum channel performs tile-wise accumulation. It feeds the partial result
from the preceding K tile into the current Tensor tile, so software does not
need a separate reduction-sum pass to combine tile results:

```text
accumulator = initial_psum + tile0_out + tile1_out + tile2_out + ...
```

Without bias, the first tile can use `EDGE_TENSOR_START_OPT_NO_PSUM`. Store its
result at the final output address, then use that output as the psum input for
each later tile:

```cpp
edge_tensor_setout(output);

for (uintptr_t k_tile = 0; k_tile < k_tile_count; ++k_tile) {
    edge_tensor_wld(weight_tiles[k_tile]);
    edge_tensor_setin(input_tiles[k_tile]);

    if (k_tile == 0) {
        edge_tensor_start<EDGE_TENSOR_START_OPT_NO_PSUM>();
    } else {
        if (k_tile == 1)
            edge_tensor_setpsum(output);
        edge_tensor_start();
    }
}
edge_tensor_sync();
```

Bias uses the same channel. Before the first tile, initialize the corresponding
psum storage with the bias values. Point both psum and output at that
accumulator, then let every tile add its result in sequence. In this pseudocode,
`stage_bias_to_dtcm()` is an application helper that copies or broadcasts the
bias into the complete psum/output region:

```cpp
stage_bias_to_dtcm(output, bias); // Initialize each output vector with bias.
edge_tensor_setpsum(output);
edge_tensor_setout(output);

for (uintptr_t k_tile = 0; k_tile < k_tile_count; ++k_tile) {
    edge_tensor_wld(weight_tiles[k_tile]);
    edge_tensor_setin(input_tiles[k_tile]);
    edge_tensor_start();
}
edge_tensor_sync();
```

The psum/output storage must remain valid until `edge_tensor_sync()` completes.
The ordered Tensor jobs produce the final result directly as
`bias + tile0 + tile1 + ...`, without a separate tile-reduction stage.
`EDGE_TENSOR_START_OPT_RSUM` is a separate Tensor reduction mode and is not
needed for this K-tile accumulation.

Tensor start options may be ORed at compile time:

| Option | Meaning |
| --- | --- |
| `EDGE_TENSOR_START_OPT_USE_SCALE` | Enable the configured scale input |
| `EDGE_TENSOR_START_OPT_PSUM_ONCE` | Apply partial-sum input once |
| `EDGE_TENSOR_START_OPT_NO_PSUM` | Do not read a partial sum |
| `EDGE_TENSOR_START_OPT_SCALE_STREAM` | Advance scale data as a stream; requires `USE_SCALE` |
| `EDGE_TENSOR_START_OPT_RSUM` | Reduction-sum mode; standalone and unavailable to `start_tile` |

`PSUM_ONCE` and `NO_PSUM` are mutually exclusive. `RSUM` cannot be combined
with scale or partial-sum options. Invalid combinations fail at compile time.
`edge_tensor_start_scale()` is the non-template convenience form for
`USE_SCALE`.

### Minimal Tensor sequence

```cpp
edge_tensor_setcsr<bfloat16_t, bfloat16_t>();
edge_tensor_wld(weight_tile);
edge_tensor_setin(input_vectors);
edge_tensor_setout(output_vectors);
edge_tensor_setn(iteration_count);
edge_tensor_start<EDGE_TENSOR_START_OPT_NO_PSUM>();
edge_tensor_sync();
```

Use a real partial-sum address and omit `NO_PSUM` when accumulating another K
tile. The complete tiled and circular example is in
[`example/tensor/matmul64x64_128tokens_tiled_circular.cpp`](../../example/tensor/matmul64x64_128tokens_tiled_circular.cpp).

## Writing efficient Tensor code

Tensor throughput depends on keeping its pipeline fed and minimizing command
boundaries. The most important techniques are circular weight streaming,
hardware-assisted transpose loading, and merging contiguous starts.

### Stream weights with circular DMA and circular WLD

For weights in DRAM, pair `edge_dma_start_strided_circular()` with
`edge_tensor_wld_circular()` or `edge_tensor_wld_t_circular()`. The DMA is the
circular producer and WLD is the consumer. Their ASIC-side ready/backpressure
handshake automatically blocks the producer when the ring is full and blocks
the consumer when the next entry is not ready. Software does not need to poll
the ring or synchronize each tile.

```cpp
edge_dma_start_strided_circular(
    weights, weight_ring,
    tile_bytes,
    x_stride_bytes, tile_count,
    0u, 1u,
    tile_bytes, ring_capacity_tiles);

edge_tensor_wld_circular();
for (uintptr_t tile = 0; tile < tile_count; ++tile) {
    edge_tensor_setin(input_for(tile));
    edge_tensor_setout(output_for(tile));
    edge_tensor_start();

    if (tile + 1u < tile_count)
        edge_tensor_wld_circular();
}

edge_tensor_sync();
edge_dma_sync();
```

Here `tile_bytes` is also the circular `entry_bytes`: every completed weight
tile produces one entry-ready event and allows one circular WLD to proceed.

If sustained DRAM fill bandwidth keeps up with Tensor consumption, the Tensor
pipeline continues without weight-load bubbles. If DRAM falls behind, the
hardware stalls correctly at the circular boundary instead of exposing a
partially filled entry. Choose a ring capacity large enough to absorb DRAM
latency and short bandwidth variation, and avoid `edge_dma_sync()` inside the
tile loop.

The weight-streaming schedule in
[`cpp/libnn/linear.hpp`](../libnn/linear.hpp) is the primary reference: it
starts one circular DMA producer, consumes weights with circular WLD, queues
Tensor starts continuously, and drains both engines only after the batch.

### Transpose weights with DMA XY mode and WLD-T

Use DMA XY mode to gather a two-dimensional weight layout from DRAM and pack
complete ring entries. Then use `edge_tensor_wld_t()` or
`edge_tensor_wld_t_circular()` when the packed tile must be transposed as it is
loaded into Tensor:

```cpp
edge_dma_start_strided_circular(
    weights, weight_ring,
    contiguous_bytes,
    x_stride_bytes, x_count,
    y_stride_bytes, y_count,
    weight_tile_bytes, ring_capacity_tiles);

edge_tensor_wld_t_circular();
```

The DMA performs the address traversal and packing; WLD-T performs the Tensor
tile transpose. This avoids a scalar transpose loop and avoids materializing a
second transposed weight matrix in memory. Use this combination for transpose
matmul dataflows. The two layout branches in
[`cpp/libnn/matmul.hpp`](../libnn/matmul.hpp) show how XY traversal, ordinary
WLD, and WLD-T are selected according to whether the source is already stored
in the orientation required by Tensor.

### Merge contiguous Tensor starts

Every `edge_tensor_start()` creates a descriptor boundary. When a loop submits
multiple jobs whose input, output, and psum regions continue in exactly the
order Tensor already advances them, merge the jobs by multiplying `setn()`.

Before merging:

```cpp
for (uintptr_t i = 0; i < m; ++i) {
    edge_tensor_setin(input + i * k * input_elements_per_iteration);
    edge_tensor_setout(output + i * k * output_elements_per_iteration);
    edge_tensor_setn(k);
    edge_tensor_start<Options>();
}
edge_tensor_sync();
```

After merging contiguous regions:

```cpp
edge_tensor_setin(input);
edge_tensor_setout(output);
edge_tensor_setn(k * m);
edge_tensor_start<Options>();
edge_tensor_sync();
```

The merged form keeps the ASIC pipeline active for a longer descriptor and
removes repeated setup, start, queue, and boundary overhead. It normally gives
the highest Tensor utilization.

Merge starts only when all of the following remain equivalent:

- Input, output, psum, and scale addresses are contiguous in Tensor traversal
  order.
- Weight state, data types, start options, and accumulation behavior do not
  change at the removed boundaries.
- The larger `k * m` count fits the product's `setn` field and does not cross a
  software-visible synchronization or ownership boundary.

If an iteration changes weights, switches psum/bias behavior, uses a
non-contiguous address, or requires its result before the next iteration, keep
separate descriptors. First make the data layout contiguous; then merge starts.

## Activation unit (ACTU)

ACTU follows the standard descriptor pattern:

```cpp
edge_actu_setcsr<dtype, mode>();
edge_actu_setin(input);
edge_actu_setout(output);
edge_actu_setscalar(scalar_bits); // Only for modes that consume a scalar.
edge_actu_setn(element_count);
edge_actu_start();
edge_actu_sync();
```

`dtype` and `mode` are compile-time values in `0..31`. The edge-e3 BF16
interface includes these configurations:

| `dtype` | `mode` | Operation |
| ---: | ---: | --- |
| 0 | 1 | Element-wise reciprocal, `1 / x` |
| 0 | 2 | Sigmoid |
| 0 | 3 | SiLU |
| 0 | 4 | Tanh |
| 0 | 5 | Softmax `exp(x - max)` pass and sum capture |
| 0 | 6 | Element-wise reciprocal square root, `1 / sqrt(x)`; RMSNorm supplies epsilon through the scalar input |
| 0 | 7 | Softmax normalization using the captured sum |

Modes not described by public software should be treated as product-specific.

### Reciprocal and reciprocal square root

RCP mode replaces element-wise division by producing the reciprocal of each
input:

```text
rcp(x) = 1 / x
a / b  = a * rcp(b)
```

Use mode 1 when the required result is `1 / x`. For a general `a / b`, follow
the RCP pass with an element-wise multiplication by `a`.

RSQRT mode directly produces the reciprocal square root:

```text
rsqrt(x) = 1 / sqrt(x)
```

It is not the same result as `sqrt(x)`. It replaces the combined square-root
and reciprocal sequence used by normalization algorithms. For example,
RMSNorm uses:

```text
normalized = x * rsqrt(mean(x * x) + epsilon)
```

RSQRT is generally more useful than a standalone square root in neural-network
workloads. A direct RCP/RSQRT datapath also maps well to a streaming ASIC
pipeline: it avoids executing a separate square-root operation followed by a
division, and successive elements can remain in flight concurrently. Exact
latency and numerical accuracy are product-specific.

Both modes use the normal ACTU descriptor and completion sequence:

```cpp
edge_actu_setcsr<0, 1>(); // RCP; use mode 6 for RSQRT.
edge_actu_setin(input);
edge_actu_setout(output);
edge_actu_setn(element_count);
edge_actu_start();
edge_actu_sync();
```

`edge_actu_setscalar(value)` accepts a runtime scalar bit pattern.
`edge_actu_setscalar_imm<value>()` embeds a compile-time value and requires it
to fit in 16 bits. Scalar encoding depends on the selected mode; for example,
the public softmax path supplies an FP32 bit pattern while RMSNorm supplies the
FP32 bits of epsilon.

After the softmax exponent pass and `edge_actu_sync()`,
`edge_actu_get_exp_sum()` returns the captured sum register.

## Comparison and reduction unit (CMPU)

CMPU accepts up to two data inputs, an optional byte mask, an output, and an
element count:

```cpp
edge_cmpu_setcsr<mode>();
edge_cmpu_setlhs(lhs);
edge_cmpu_setrhs(rhs);       // When required by the mode.
edge_cmpu_setmask(mask);     // When required by the mode.
edge_cmpu_setout(output);    // When the mode writes a vector result.
edge_cmpu_setn(element_count);
edge_cmpu_start();
edge_cmpu_sync();
```

`mode` must be a compile-time value in `0..9`. Public software demonstrates:

| Mode | Operation |
| ---: | --- |
| 0 | BF16 reduction; public softmax reads the maximum result |
| 9 | Copy 16-bit elements between aligned DTCM buffers |

Other modes are part of the product-specific CMPU contract and are not defined
by this header alone. Public software treats the CMPU count as a 16-bit field;
split larger jobs into chunks no greater than `UINT16_MAX`. For mode 9, public
code keeps non-final chunks and both addresses aligned to a 128-bit DTCM beat.

After completion, C++ result helpers provide:

| Function | Result register |
| --- | --- |
| `edge_cmpu_get_max_value()` | Maximum value bits |
| `edge_cmpu_get_argmax_idx()` | Index of the maximum |
| `edge_cmpu_get_min_value()` | Minimum value bits |
| `edge_cmpu_get_argmin_idx()` | Index of the minimum |

The value helpers return raw hardware bits in a `uintptr_t`. For BF16 mode 0,
public softmax code converts the maximum to an FP32 bit container with:

```cpp
uintptr_t max_f32_bits = (edge_cmpu_get_max_value() & 0xffffu) << 16;
```

## Accelerator result CSR access

`edge_accel_getcsr<csr_id>()` is the generic C++ accessor. The ID must be one
of the constants from `EDGE_ACCEL_CSR_CMPU_MAX_VALUE` through
`EDGE_ACCEL_CSR_ACTU_EXP_SUM`. Prefer the named helpers above because they
make ownership and result format clearer.

Call the producing engine's `sync()` before reading a result CSR. A result is
a raw register value; interpret it according to the mode that produced it.

## Complete DMA and ACTU example

The following function stages DMA-owned BF16 input into DTCM, runs SiLU, and
copies the result to a DMA-owned external-memory buffer. It deliberately has no
per-transfer cache maintenance:

```cpp
void silu_bf16(const uint16_t *input, uint16_t *output,
               uint16_t *dtcm_input, uint16_t *dtcm_output,
               uintptr_t count)
{
    const uintptr_t bytes = count * sizeof(uint16_t);

    edge_dma_start(input, dtcm_input, bytes);
    edge_dma_sync();

    edge_actu_setcsr<0, 3>();
    edge_actu_setin(dtcm_input);
    edge_actu_setout(dtcm_output);
    edge_actu_setn(count);
    edge_actu_start();
    edge_actu_sync();

    edge_dma_start(dtcm_output, output, bytes);
    edge_dma_sync();
}
```

The caller must allocate non-overlapping, suitably aligned regions inside the
configured DTCM and keep all buffers alive until the matching sync completes.
If scalar code creates `input` or inspects `output` through the D-cache during
debug, perform the corresponding one-time ownership handoff described above.

## Common mistakes

- Consuming output immediately after `start()` instead of after `sync()`.
- Passing cached external-memory pointers directly to an engine that expects
  DTCM-visible storage.
- Adding D-cache maintenance to every DMA transfer instead of keeping hot-path
  buffers under DMA/accelerator ownership.
- Failing to clean or invalidate at the ownership boundary when debug code
  mixes scalar cached access with DMA access to the same DRAM range.
- Treating Tensor `setn()` as bytes; only DMA sizes and strides are bytes.
- Passing runtime values as C++ template arguments. Template fields and
  options must be compile-time constants.
- Combining mutually exclusive Tensor partial-sum options.
- Reusing a weight or scale before it has first been loaded.
- Reading an accelerator result CSR before the producing engine has completed.
- Using low-level encoding macros as a stable application ABI.

## API stability

The custom accelerator encodings and product mode assignments remain
provisional. The inline function names, compile-time validation, and examples
are the intended software-facing layer. When upgrading the repository, rebuild
all bare-metal images against the matching `edge_intrinsic.hpp` and product RTL
rather than reusing previously compiled instruction streams.
