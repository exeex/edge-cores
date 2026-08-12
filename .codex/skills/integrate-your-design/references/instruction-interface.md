# Instruction and C++ interface

Model the custom API after ACTU:

```cpp
edge_actu_setin(in);
edge_actu_setout(out);
edge_actu_setn(count);
edge_actu_start();
edge_actu_sync();
```

Provide explicit accelerator-specific `setcsr` or `set_*` commands, an
asynchronous `start`, and an await-like `sync`. Use the naming that best fits
the public software API, but keep parameter mutation out of `start`.
Add compile-time immediate forms only when useful and enforce their ranges
with `static_assert`. Include a `"memory"` clobber when a command orders
accelerator-visible memory.

Treat `opcode8 + imm8 + GPR5` as a 21-bit logical command space:

- allocate an unused opcode8 per operation;
- use imm8 for modes, flags, or small immediate fields; and
- use at most one GPR operand per command.

Split a multi-GPR operation into multiple `set_*` commands because the current
frontend supports one capture per accelerator command. Do not infer physical
bit positions from the logical fields: confirm the legacy 64-bit and compact
packing in the checked-out intrinsic encoder, predecoder, command queue, and
accel pipe.

Register the allocated opcode and capture class in the IFU/predecoder. Update
every matching point together:

1. intrinsic constants and `.insn`/`.word` encoder;
2. frontend/predecoder opcode and capture classification;
3. command queue compact opcode8/imm8 representation;
4. accel-pipe legality, readiness, decode, and output ports; and
5. exact-encoding tests.

Use ACTU suboperations `0x20`–`0x26` as a structural example, not as reusable
allocation for an unrelated accelerator. Reject unknown opcodes and invalid
immediate combinations.
