#include "intrinsic/edge_intrinsic.hpp"

extern "C" int main(void)
{
    static const char message[] = "Hello from edge-e3!\n";
    for (const char *cursor = message; *cursor != '\0'; ++cursor)
        edge_sim_putchar(*cursor);
    return 0;
}
