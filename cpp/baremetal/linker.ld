OUTPUT_ARCH(riscv)
ENTRY(__start)

__nnedge_output_base = DEFINED(__nnedge_output_base) ? __nnedge_output_base : 0x00100000;

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 0x00040000
    RAM (rwx) : ORIGIN = 0x00040000, LENGTH = 0x000c0000
    OUTPUTS (rw) : ORIGIN = __nnedge_output_base, LENGTH = 0x00020000
    WEIGHTS (r) : ORIGIN = 0x00200000, LENGTH = 0x00400000
}

/* Keep the CPU-visible DTCM aperture outside the ELF/DRAM address range. */
__edge_dtcm_base = 0x40000000;
__edge_dtcm_size = 0x00020000;
__edge_dtcm_mask = 0xfffffe0000;

SECTIONS
{
    .text : ALIGN(4)
    {
        KEEP(*(.init))
        *(.text .text.*)
    } > ROM

    .rodata : ALIGN(8)
    {
        *(.srodata .srodata.*)
        *(.rodata .rodata.*)
    } > ROM

    .nnedge_weights : ALIGN(64)
    {
        __nnedge_weights_start = .;
        KEEP(*(.nnedge_weights))
        . = ALIGN(64);
        __nnedge_weights_end = .;
    } > WEIGHTS
    PROVIDE(weight_begin = __nnedge_weights_start);
    PROVIDE(weight_end = __nnedge_weights_end);

    .nnedge_inputs : ALIGN(64)
    {
        __nnedge_inputs_start = .;
        KEEP(*(.nnedge_inputs))
        . = ALIGN(64);
        __nnedge_inputs_end = .;
    } > RAM
    PROVIDE(input_begin = __nnedge_inputs_start);
    PROVIDE(input_end = __nnedge_inputs_end);

    .data : ALIGN(8)
    {
        __global_pointer$ = . + 0x800;
        *(.sdata .sdata.*)
        *(.data .data.*)
    } > RAM AT > ROM

    .sim_exit : ALIGN(8)
    {
        KEEP(*(.sim_exit))
    } > RAM

    .bss (NOLOAD) : ALIGN(8)
    {
        __bss_start = .;
        *(.sbss .sbss.*)
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(8);
        __bss_end = .;
    } > RAM

    .nnedge_outputs (NOLOAD) : ALIGN(64)
    {
        __nnedge_outputs_start = .;
        KEEP(*(.nnedge_outputs))
        . = ALIGN(64);
        __nnedge_outputs_end = .;
    } > OUTPUTS
    PROVIDE(output_begin = __nnedge_outputs_start);
    PROVIDE(output_end = __nnedge_outputs_end);
    ASSERT(__nnedge_outputs_start >= 0x00100000, "NNC outputs overlap program RAM")
    ASSERT(__nnedge_outputs_end <= 0x00120000, "NNC outputs overlap DRAM heap")

    __nnedge_dram_heap_start = 0x00120000;
    __nnedge_dram_heap_end = 0x00160000;

    __stack_top = ORIGIN(RAM) + LENGTH(RAM);

    PROVIDE(end = .);
}
