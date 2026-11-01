// SPDX-License-Identifier: Apache-2.0
#include <stdint.h>
#include "intrinsic/edge_intrinsic.hpp"

namespace {
constexpr unsigned kCount = 4096;
struct Buffers { uint16_t input[kCount]; uint16_t output[kCount]; };
volatile Buffers *const buffers =
    reinterpret_cast<volatile Buffers *>(EDGE_DTCM_BASE);
}

extern "C" int main()
{
    edge_asic_on();
    for (unsigned i = 0; i < kCount; ++i) {
        buffers->input[i] = 0;          // BF16 zero
        buffers->output[i] = 0xffff;    // Detect incomplete writes
    }
    __asm__ volatile("fence rw, rw" ::: "memory");

    edge_actu_setcsr<0, 2>();            // BF16 sigmoid
    edge_actu_setin((const void *)buffers->input);
    edge_actu_setout((void *)buffers->output);
    edge_actu_setn(kCount);
    edge_actu_start();                  // Fork: command response precedes drain

    unsigned scalar = 0;
    for (unsigned i = 0; i < 32; ++i)
        __asm__ volatile("addi %0, %0, 1" : "+r"(scalar));

    edge_actu_sync();                   // Join: retain EX until ACTU drains
    if (scalar != 32) return 1;
    for (unsigned i = 0; i < kCount; ++i)
        if (buffers->output[i] != 0x3f00) return 2; // sigmoid(0) = 0.5
    return 0;
}
