#ifndef EDGE_COREMARK_PLATFORM_HPP
#define EDGE_COREMARK_PLATFORM_HPP

#include <stdint.h>

static inline uintptr_t staredge_bench_get_cycle(void)
{
    uintptr_t value;
    __asm__ volatile("rdcycle %0" : "=r"(value));
    return value;
}

static inline void edge_coremark_putc(char ch)
{
#if defined(STAREDGE_BENCH_EDGE)
    uintptr_t value = (unsigned char)ch;
    __asm__ volatile("csrw 0x7e1, %0" : : "r"(value));
#else
    volatile uint32_t *uart = (volatile uint32_t *)(uintptr_t)0x10015000;
    *uart = (unsigned char)ch;
    __asm__ volatile("fence iorw, iorw" ::: "memory");
#endif
}

static inline void edge_coremark_print_cycles(uintptr_t value)
{
    char digits[24];
    unsigned count = 0;
    do {
        digits[count++] = (char)('0' + value % 10);
        value /= 10;
    } while (value != 0);
    const char prefix[] = "cycle_delta=";
    for (unsigned i = 0; i < sizeof(prefix) - 1; ++i) edge_coremark_putc(prefix[i]);
    while (count != 0) edge_coremark_putc(digits[--count]);
    edge_coremark_putc('\n');
}

#endif
