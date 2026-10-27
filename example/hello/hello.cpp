#include "intrinsic/edge_intrinsic.hpp"

extern "C" int main(void)
{
    // Volatile keeps this writable initializer in .data, exercising ROM-to-RAM startup.
    static volatile char message[] = "hello from edge-e3!\n";
    message[0] = 'H';
    for (const volatile char *cursor = message; *cursor != '\0'; ++cursor)
        edge_sim_putchar(*cursor);
    return 0;
}
