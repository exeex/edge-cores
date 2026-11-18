.option norvc
.section .text,"ax"
.global _start, done
// Earlier run-control regression fixtures, now downloaded through JTAG as ELF bytes.
addi x31,x31,1
j .
addi x30,x31,2
ebreak
.org 64
li x1,65
csrw 0x7e1,x1
li x1,66
csrw 0x7e1,x1
li x1,10
csrw 0x7e1,x1
j .
.org 128
li x1,88
1: csrw 0x7e1,x1
j 1b
.org 512
_start:
  lui sp,0x10
  addi sp,sp,-16
  la t0,seed
  lw t6,0(t0)
  addi t6,t6,1
  li t0,74
  csrw 0x7e1,t0
  li t0,84
  csrw 0x7e1,t0
  li t0,65
  csrw 0x7e1,t0
  li t0,71
  csrw 0x7e1,t0
  li t0,10
  csrw 0x7e1,t0
 done:
  ebreak
.section .data,"aw"
.global seed
seed: .word 41

.section .text,"ax"
.org 768
.global bp_start, bp_a, bp_b, bp_branch, bp_done
bp_start:
  li t6,0
  li t1,3
bp_a:
  addi t6,t6,1
  j bp_b
.org 832
bp_b:
  addi t6,t6,10
  addi t1,t1,-1
bp_branch:
  bnez t1,bp_a
bp_done:
  ebreak

.org 896
.global dirty_store, dirty_done
// Leave dirty values in D-cache; no software cache operation is issued.
dirty_store:
  la t0,seed
  li t6,0x12345663
  sw t6,0(t0)
  li t6,77
  sw t6,4(t0)
dirty_done:
  ebreak

.org 960
.global dirty_reload, dirty_reload_done
dirty_reload:
  la t0,seed
  lw t6,0(t0)
  lw t5,4(t0)
dirty_reload_done:
  ebreak

.org 1024
.global running_memory, running_loop
running_memory:
  lui t0,1
  li t1,0x12345663
  sw t1,0(t0)
  li t1,77
  sw t1,4(t0)
running_loop:
  lw t4,0(t0)
  addi t3,t3,1
  j running_loop
