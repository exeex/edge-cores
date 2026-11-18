ENTRY(_start)
PHDRS { code PT_LOAD FLAGS(5); data PT_LOAD FLAGS(6); }
SECTIONS {
 . = 0; .text : { *(.text*) } :code
 . = 0x1000; .data : { *(.data*) } :data
 .bss (NOLOAD) : { *(.bss*) *(COMMON) } :data
}
