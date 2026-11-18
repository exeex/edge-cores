# Halted code writes need instruction-cache synchronization before execution.
# Existing backend invalidates a single 64-byte line and acknowledges completion.
proc edge_sync_range {address length} {
    if {$length <= 0} { return }
    if {([riscv dmi_read 0x11] & 0x300) != 0x300} {
        error "edge_sync_range requires a halted core"
    }
    set end [expr {$address + $length}]
    for {set line [expr {$address & ~63}]} {$line < $end} {incr line 64} {
        riscv dmi_write 0x70 8
        riscv dmi_write 0x71 $line
        riscv dmi_write 0x72 8
        if {[riscv dmi_read 0x73] != 0} { error "instruction line invalidate failed" }
    }
}
