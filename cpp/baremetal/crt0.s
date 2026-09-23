/*
 * Minimal RV32 bare-metal startup for the public Edge-32 examples.
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

    la      t0, __bss_start
    la      t1, __bss_end
1:
    bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b

2:
    /* edge.asic.power(on): release the DTCM/accelerator access gate before main. */
    .word   0x1200103f
    call    main

    mv      s0, a0
    la      t0, __sim_exit_code
    sw      s0, 0(t0)

    slli    t1, s0, 1
    ori     t1, t1, 1
    la      t0, tohost
    sw      t1, 0(t0)

    mv      t6, s0
    ebreak

3:
    wfi
    j       3b

    .size __start, . - __start
    .option pop

    .section .sim_exit, "aw", @progbits
    .align 2
    .globl __sim_exit_code
__sim_exit_code:
    .word 0

    .globl tohost
tohost:
    .word 0

    .globl fromhost
fromhost:
    .word 0
