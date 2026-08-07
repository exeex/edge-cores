/*
 * Minimal RV64 bare-metal startup for the ATen reference example.
 */

    .option push
    .option norelax
    .equ __SIM_EXIT_MAGIC_VALUE, 0x435239305f455849
    .section .init, "ax", @progbits
    .globl __start
    .globl _start
    .type __start, @function
    .type _start, @function

__start:
_start:
    la      gp, __global_pointer$
    la      sp, __stack_top

    /*
     * Enable Edge implementation-defined extensions and FPU state.  These
     * numeric CSR forms keep the file portable across LLVM assembler versions.
     */
    li      t0, 0x400000
    csrs    0x7c0, t0
    li      t0, 0x802000
    csrs    mstatus, t0

    la      t0, __edge_dtcm_base
    csrw    0x7d8, t0
    la      t0, __edge_dtcm_size
    neg     t0, t0
    csrw    0x7d9, t0
    li      t0, 1
    csrw    0x7da, t0

    la      t0, __bss_start
    la      t1, __bss_end
1:
    bgeu    t0, t1, 2f
    sd      zero, 0(t0)
    addi    t0, t0, 8
    j       1b

2:
    call    main

    mv      s0, a0
    la      t0, __sim_exit_code
    sd      s0, 0(t0)

    li      t1, __SIM_EXIT_MAGIC_VALUE
    la      t0, __sim_exit_magic
    sd      t1, 0(t0)

    slli    t1, s0, 1
    ori     t1, t1, 1
    la      t0, tohost
    sd      t1, 0(t0)

    li      t0, 0x10016000
    sd      s0, 0(t0)

    mv      a0, s0
    csrw    0x7e0, a0
    ebreak

3:
    wfi
    j       3b

    .size __start, . - __start
    .option pop

    .section .sim_exit, "aw", @progbits
    .align 3
    .globl __sim_exit_code
__sim_exit_code:
    .dword 0

    .globl __sim_exit_magic
__sim_exit_magic:
    .dword 0

    .globl tohost
tohost:
    .dword 0

    .globl fromhost
fromhost:
    .dword 0
