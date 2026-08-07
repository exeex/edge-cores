OUTPUT_ARCH(riscv)
ENTRY(__start)
MEMORY {
  ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 0x00040000
  RAM (rwx) : ORIGIN = 0x00040000, LENGTH = 0x000c0000
}
__stack_top = ORIGIN(RAM) + LENGTH(RAM);
SECTIONS {
  .text : ALIGN(4) { KEEP(*(.init)) *(.text .text.*) } > ROM
  .rodata : ALIGN(8) { *(.srodata .srodata.*) *(.rodata .rodata.*) } > ROM
  .data : ALIGN(8) { __global_pointer$ = . + 0x800; *(.sdata .sdata.*) *(.data .data.*) } > RAM AT > ROM
  .bss (NOLOAD) : ALIGN(8) { __bss_start = .; *(.sbss .sbss.*) *(.bss .bss.*) *(COMMON) . = ALIGN(8); __bss_end = .; } > RAM
}
