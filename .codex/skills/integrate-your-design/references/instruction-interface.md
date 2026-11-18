# Instruction and C++ interface

## Public SDK and command lifecycle

Use the E3 [SDK entry](../../../../src/edge-e3/include/edge_e3/edge_intrinsic.hpp)
with both E3 and Edge-32 include directories. E3 owns the product entry and
memory map; [edge32_intrinsic.hpp](../../../../src/edge-32/include/edge32_intrinsic.hpp)
owns the current ISA encoder and public wrappers. Encodings are provisional:
applications should call the wrappers and rebuild against matching RTL.

Model a custom interface after the public ACTU API:

```cpp
#include <edge_e3/edge_intrinsic.hpp>

// input/output are suitable accelerator-visible DTCM buffers.
edge_actu_setcsr<0, 3>(); // BF16 SiLU
edge_actu_setin(input);
edge_actu_setout(output);
edge_actu_setn(count);
edge_actu_start();
// Independent scalar work may run here.
edge_actu_sync();
```

Provide explicit configuration commands, an asynchronous start and a matching
engine sync. A start may carry launch options but must preserve the descriptor
accepted for earlier work. A compiler `"memory"` clobber prevents compiler
reordering; it neither waits for completion nor performs CPU/DMA cache
ownership transfer. See [execution model](execution-model.md) for backpressure,
completion and ownership rules. The current ACTU sync wrapper emits the sync
command followed by `fence rw, rw`; this fence does not replace cache handoff.

## Current ASIC32 encoding

The maintained E3/Edge-32 path uses one fixed 32-bit instruction per encoded
command. `edge32::asic_word` and `asic_result_word` define these fields:

| Instruction bits | Meaning |
| --- | --- |
| `[31:25]` | 7-bit suboperation (`funct7`) |
| `[24:20]` | `imm8[7:3]`, not a second source register |
| `[19:15]` | `rs1`, the captured scalar operand when required |
| `[14:12]` | `imm8[2:0]` |
| `[11:7]` | Zero for ordinary commands; result destination for GETCSR |
| `[6:0]` | ASIC opcode `0x3f` |

The operand emitter binds its RV32 value to `a0` and emits `.word`; commands
without an operand use `rs1=0`. GETCSR uses the result emitter and the normal
accelerator response path. Do not copy encoding syntax from cache/FPU
instructions, which use different instruction families.

E3's [dispatch](../../../../src/edge-e3/edge_core/rtl/edge_lite_accel_dispatch.v)
reconstructs internal `opcode8 = {1'b1, inst[31:25]}` and
`imm8 = {inst[24:20], inst[14:12]}` for `COMPACT_CMD_INPUT=1`. Therefore
`opcode8 + imm8 + GPR5` is not a standalone 21-bit instruction encoding or
an unrestricted 8-bit opcode allocation space. Allocate an unused 7-bit
subop after checking the encoder, classifier and pipe; ACTU `0x20`–`0x26`
are already assigned, and CMPU/GETCSR continue through `0x2f`.

There is one captured GPR value per command. Split multiple runtime operands
into setup commands. Transport width and engine field width are distinct:
ACTU `setn` accepts a C++ `uintptr_t`, but the pipe consumes only its low
16 bits. Validate or chunk counts rather than silently relying on truncation.

DMA/Tensor address helpers using `emit_address` send low then high 32-bit
halves with `imm8` values 0 and 1, even when the high half is zero. Preserve
that pair and its order to clear stale high-address state. ACTU pointer
wrappers instead emit a single RV32 value; do not generalize the two-command
address protocol to every `set_*` operation.

## Immediate fields and legality

Enforce template ranges against the actual encoder and product decode, not
just the C++ argument type. In the current header and
[accelerator pipe](../../../../src/edge-32/rtl/edge_accel_pipe.v):

- `edge_actu_setcsr<dtype, mode>()` requires each value in `0..15` and packs
  `(mode << 4) | dtype` into `imm8`. The pipe reads the corresponding nibbles.
  Representable values are not proof that every product mode is implemented.
- `edge_actu_setscalar_imm<value>()` accepts values through `0xffffffff` and
  calls the GPR operand emitter. Its template argument is compile-time, but
  it is not a 16-bit immediate embedded in the ASIC instruction.
- Unknown suboperations are illegal. Immediate validation is operation-specific
  (for example GETCSR checks its CSR ID); do not assume every reserved bit
  combination is already rejected by hardware. Define and test the legality
  policy when adding an operation.

The [SDK manual](../../../../src/edge-e3/include/README.md) explains product
usage, but its ACTU `0..31` field range and 16-bit scalar-immediate description
are stale relative to these checked-in implementations. Use the header/RTL
limits above until that manual is reconciled.

## Update the complete selected path

When implementing a new command, update these connected points together:

1. The Edge-32 command enum, encoder and public wrapper, plus any E3-specific
   API or memory-map requirements.
2. [edge_instruction_classifier.v](../../../../src/edge-32/rtl/edge_instruction_classifier.v)
   for subop legality and capture classification, and
   [edge_32_decode.v](../../../../src/edge-32/rtl/edge_32_decode.v) for local
   operand routing, including the early capture list. Check result writeback
   if the operation returns a GPR value.
3. E3 dispatch field extraction and product wiring, then accelerator-pipe
   legality, capture requirements, readiness and output ports.
4. Target configuration, start and drain behavior, with stable operands under
   backpressure and no mutation of previously accepted descriptors.
5. Exact emitted-word and operand tests, illegal/reserved encodings, and the
   affected public interface/example regression. The header's existing
   `asic_word`/`asic_result_word` static assertions are encoding sentinels,
   not complete command-path tests. Follow the
   [regression routing](../../../../tests/README.md) for integration coverage.

Only update a snapshot command queue and IFU scalar join when the selected
frontend actually uses them. The current public Edge-32 path uses
request/response and fixes command sequence/epoch to zero; retained legacy
64-bit decoding or tagged queue modules do not establish its active ABI.
