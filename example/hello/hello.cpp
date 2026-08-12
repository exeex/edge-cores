#include "intrinsic/edge_sim_console.hpp"

extern "C" int main(void)
{
    printf("Hello from edge-e3!\n");
    const float promoted = -12.375f;
    const double native = 1.9995;
    printf("Float debug: %f %.3f %+09.2f %.0f\n",
           promoted, native, 3.5, 1.6);
    printf("Float edges: negzero=%.2f carry=%.3f alt=%#.0f "
           "left=[%-8.2f]\n",
           -0.0, 0.9996, 2.0, 1.25);
    printf("Float special: %f %F %f wide=%.12f\n",
           __builtin_nan(""), __builtin_inf(), -__builtin_inf(), 0.5);
    return 0;
}
