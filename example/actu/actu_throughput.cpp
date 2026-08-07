#include <stdint.h>

#include "intrinsic/edge_intrinsic.hpp"
#include "intrinsic/edge_sim_console.hpp"

namespace {

constexpr uintptr_t kElementCount = 4096u;
constexpr int kActuModeSigmoid = 2;
constexpr int kActuModeSilu = 3;
constexpr int kActuModeTanh = 4;
constexpr int kActuModeSoftmaxExp = 5;
constexpr int kActuModeSoftmaxNormalize = 7;

struct ActuDtcm {
    uint16_t input[kElementCount];
    uint16_t output[kElementCount];
};

volatile ActuDtcm *const kDtcm =
    reinterpret_cast<volatile ActuDtcm *>(EDGE_DTCM_BASE);

template <int Mode>
__attribute__((noinline)) uintptr_t run_actu()
{
    edge_actu_setcsr<0, Mode>();
    edge_actu_setin((const void *)kDtcm->input);
    edge_actu_setout((void *)kDtcm->output);
    edge_actu_setn(kElementCount);
    const uintptr_t start = edge_get_cycle();
    edge_actu_start();
    edge_actu_sync();
    return edge_get_cycle() - start;
}

__attribute__((noinline)) uintptr_t run_softmax()
{
    edge_cmpu_setcsr<0>();
    edge_cmpu_setlhs((const void *)kDtcm->input);
    edge_cmpu_setn(kElementCount);
    uintptr_t start = edge_get_cycle();
    edge_cmpu_start();
    edge_cmpu_sync();
    uintptr_t cycles = edge_get_cycle() - start;
    const uintptr_t max_bits = (edge_cmpu_get_max_value() & 0xffffu) << 16;

    edge_actu_setcsr<0, kActuModeSoftmaxExp>();
    edge_actu_setin((const void *)kDtcm->input);
    edge_actu_setout((void *)kDtcm->output);
    edge_actu_setscalar(max_bits);
    edge_actu_setn(kElementCount);
    start = edge_get_cycle();
    edge_actu_start();
    edge_actu_sync();
    cycles += edge_get_cycle() - start;

    edge_actu_setcsr<0, kActuModeSoftmaxNormalize>();
    edge_actu_setin((const void *)kDtcm->output);
    edge_actu_setout((void *)kDtcm->output);
    edge_actu_setn(kElementCount);
    start = edge_get_cycle();
    edge_actu_start();
    edge_actu_sync();
    return cycles + edge_get_cycle() - start;
}

void fill(uint16_t value)
{
    for (uintptr_t i = 0; i < kElementCount; ++i) {
        kDtcm->input[i] = value;
        kDtcm->output[i] = 0xffffu;
    }
    __asm__ volatile("fence rw, rw" ::: "memory");
}

bool output_is(uint16_t expected)
{
    for (uintptr_t i = 0; i < kElementCount; ++i) {
        if (kDtcm->output[i] != expected)
            return false;
    }
    return true;
}

} // namespace

extern "C" int main(void)
{
    fill(0x0000u);
    (void)run_actu<kActuModeSigmoid>();
    const uintptr_t sigmoid_cycles = run_actu<kActuModeSigmoid>();
    if (!output_is(0x3f00u))
        return 2;

    fill(0x0000u);
    (void)run_actu<kActuModeSilu>();
    const uintptr_t silu_cycles = run_actu<kActuModeSilu>();
    if (!output_is(0x0000u))
        return 3;

    fill(0x0000u);
    (void)run_actu<kActuModeTanh>();
    const uintptr_t tanh_cycles = run_actu<kActuModeTanh>();
    if (!output_is(0x0000u))
        return 4;

    fill(0x0000u);
    (void)run_softmax();
    const uintptr_t softmax_cycles = run_softmax();
    if (!output_is(0x3980u))
        return 5;

    printf("edge ACTU throughput: elements=%lu sigmoid_cycles=%lu "
           "silu_cycles=%lu tanh_cycles=%lu softmax_cycles=%lu\n",
           (unsigned long)kElementCount,
           (unsigned long)sigmoid_cycles,
           (unsigned long)silu_cycles,
           (unsigned long)tanh_cycles,
           (unsigned long)softmax_cycles);
    return 0;
}
