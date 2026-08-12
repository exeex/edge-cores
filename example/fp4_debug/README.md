# FP4 debug

Build and run a small C++ example that computes values in FP32, packs them as
sixteen E2M1 FP4 nibbles in `fp4x16_t`, and reads them back for printing:

```sh
./example/fp4_debug/run.sh
```

The example covers three API patterns:

1. Compute values in ordinary FP32, then use `set_element_fp4` and
   `get_element_fp4` for random access to any index from 0 through 15.
2. Start with zero and call `pack_next_fp4` exactly sixteen times to produce a
   CUDA-compatible linear FP4 vector. It prints the incomplete four-element
   intermediate state, compares the completed result against random-access
   packing, and prints the bytes produced by a normal little-endian RV64 store.
3. Call `unpack_next_fp4` sixteen times to recover the values in element order
   as FP32 and print them.

Nibble index 0 is the least-significant four bits. A partial streaming pack is
high-aligned and must not be stored as a completed vector; use
`set_element_fp4` when writing fewer than sixteen elements.
