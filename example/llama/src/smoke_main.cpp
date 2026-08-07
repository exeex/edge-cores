#include "forward.hpp"
#include "intrinsic/edge_sim_console.hpp"

#ifndef NNEDGE_OUTPUT_BASE
#define NNEDGE_OUTPUT_BASE 0x100000u
#endif

extern "C" void *memcpy(void *dst, const void *src, unsigned long size)
{
    auto *out = static_cast<unsigned char *>(dst);
    const auto *in = static_cast<const unsigned char *>(src);
    for (unsigned long i = 0; i < size; ++i) {
        out[i] = in[i];
    }
    return dst;
}

extern "C" int main(void)
{
    model::init();
    model::mio::y.data = reinterpret_cast<model::dtype *>(NNEDGE_OUTPUT_BASE);
    const int status = model::forward();
    if (status != 0) {
        return status;
    }

    printf("llama smoke output=%p\n", model::mio::y.data);
    return 0;
}
