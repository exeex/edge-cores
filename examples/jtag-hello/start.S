.option norvc
.section .text.start,"ax"
.global _start, hello_done
_start:
    lui sp, 0x10
    addi sp, sp, -16
    la t0, __bss_start
    la t1, __bss_end
1:
    bgeu t0, t1, 2f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 1b
2:
    call main
hello_done:
    ebreak
    j hello_done
