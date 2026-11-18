ENTRY(_start)
PHDRS { code PT_LOAD FLAGS(5); data PT_LOAD FLAGS(6); }
SECTIONS {
    . = 0;
    .text : { *(.text.start) *(.text*) } :code
    .rodata : { *(.rodata*) } :code
    . = ALIGN(0x1000);
    .data : { *(.data*) *(.sdata*) } :data
    .bss (NOLOAD) : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss*) *(.sbss*) *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } :data
    ASSERT(. < 0xf000, "Program overlaps stack")
}
