    .option push
    .option norelax
    .section .init, "ax", @progbits
    .globl __start
    .globl _start
__start:
_start:
    la gp, __global_pointer$
    la sp, __stack_top
    li t0, 0x400000
    csrs 0x7c0, t0
    li t0, 0x802000
    csrs mstatus, t0
    li t0, 0x30013
    csrs 0x7c2, t0
    li t0, 0x7f
    csrs 0x7c1, t0
    li t0, 0x610c
    csrs 0x7c5, t0
    la t0, __bss_start
    la t1, __bss_end
1:  bgeu t0, t1, 2f
    sd zero, 0(t0)
    addi t0, t0, 8
    j 1b
2:  call main
    mv s0, a0
    li t0, 0x7f
    csrc 0x7c1, t0
    li t0, 0x10015000
    la t1, return_prefix
4:  lbu t2, 0(t1)
    beqz t2, 5f
    sw t2, 0(t0)
    fence iorw, iorw
    addi t1, t1, 1
    j 4b
5:  li t1, 60
6:  srl t2, s0, t1
    andi t2, t2, 0xf
    li t3, 10
    bltu t2, t3, 7f
    addi t2, t2, 87
    j 8f
7:  addi t2, t2, 48
8:  sw t2, 0(t0)
    fence iorw, iorw
    addi t1, t1, -4
    bgez t1, 6b
    li t2, 10
    sw t2, 0(t0)
    fence iorw, iorw
    li t0, 0x10016000
    sd s0, 0(t0)
    fence iorw, iorw
3:  wfi
    j 3b
    .option pop

    .section .rodata, "a", @progbits
return_prefix:
    .asciz "\nRETURN_VALUE 0x"
