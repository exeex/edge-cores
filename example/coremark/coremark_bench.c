/* Deterministic two-iteration Edge CoreMark RTL benchmark. */
#define ITERATIONS 2
#define FLAGS_STR "-O2"
#define EDGE_COREMARK_FIXED_RUN 1
#define main coremark_main
int ee_printf(const char *fmt, ...) { (void)fmt; return 0; }
#include "../../third_party/coremark/core_list_join.c"
#include "../../third_party/coremark/core_matrix.c"
#include "../../third_party/coremark/core_state.c"
#include "../../third_party/coremark/core_util.c"
#include "../../third_party/coremark/core_portme.c"
#include "../../third_party/coremark/core_main.c"
#undef main

int main(void)
{
    int cycles = coremark_main();
    if (cycles <= 0) return 1;
    edge_coremark_print_cycles((uintptr_t)(unsigned)cycles);
    return 0;
}
