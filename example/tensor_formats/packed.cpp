// Parameterized WSLD tutorial: Y[v,r] = scale[r] * sum_k W[r,k]*X[v,k].
#include "intrinsic/edge_intrinsic.hpp"

constexpr unsigned lanes = 8, groups = 3;
struct Arena {
    alignas(32) uint8_t ring[4096];
    uint32_t ring_guard[8];
    alignas(32) uint16_t x[8][8];
    alignas(32) uint16_t y[24][8][8];
    uint32_t output_guard[8];
};

static constexpr int weight(unsigned group, unsigned tile, unsigned r, unsigned k)
{
    return int((group + tile * 2 + r * 3 + k) % 5) - 2;
}
static int input(unsigned v, unsigned k) { return int((v + k * 2) % 5) - 2; }
static uint16_t bf16(float value) { return bfloat16_t::from_float(value).bits; }

template<unsigned W, unsigned S, unsigned T> struct Slots {
    static constexpr unsigned tile_bytes = W == 1 ? 128 : W == 4 ? 32 : 64;
    static constexpr unsigned stride = (2*S + T*tile_bytes + 15) & ~15u;
    uint8_t bytes[groups][stride];
};

// Explicit encodings keep this packing example independent of scalar converters.
template<unsigned W> static constexpr unsigned code(int q)
{
    const unsigned magnitude = q < 0 ? -q : q;
    if constexpr (W == EDGE_TENSOR_WTYPE_BF16)
        return (magnitude == 2 ? 0x4000 : magnitude == 1 ? 0x3f80 : 0) | (q < 0 ? 0x8000 : 0);
    if constexpr (W == EDGE_TENSOR_WTYPE_INT8) return unsigned(q) & 255;
    if constexpr (W == EDGE_TENSOR_WTYPE_FP4)
        return (magnitude == 2 ? 4 : magnitude == 1 ? 2 : 0) | (q < 0 ? 8 : 0);
    const unsigned one = W == EDGE_TENSOR_WTYPE_FP8_E4M3FN ? 0x38 : 0x3c;
    return (magnitude == 2 ? 0x40 : magnitude == 1 ? one : 0) | (q < 0 ? 0x80 : 0);
}

template<unsigned W, unsigned S, unsigned T> static constexpr Slots<W,S,T> pack()
{
    Slots<W,S,T> slots = {};
    for (unsigned g = 0; g < groups; ++g) {
        for (unsigned s = 0; s < S; ++s) {
            const unsigned bits = (g+s)%3 == 0 ? 0x3f00 : (g+s)%3 == 1 ? 0x3f80 : 0x4000;
            slots.bytes[g][s*2] = bits;
            slots.bytes[g][s*2+1] = bits >> 8;
        }
        for (unsigned t = 0; t < T; ++t)
            for (unsigned r = 0; r < lanes; ++r)
                for (unsigned k = 0; k < lanes; ++k) {
                    const unsigned i = r*lanes+k, value = code<W>(weight(g,t,r,k));
                    const unsigned base = 2*S+t*Slots<W,S,T>::tile_bytes;
                    if constexpr (W == EDGE_TENSOR_WTYPE_BF16) {
                        slots.bytes[g][base+2*i] = value;
                        slots.bytes[g][base+2*i+1] = value >> 8;
                    } else if constexpr (W == EDGE_TENSOR_WTYPE_FP4) {
                        slots.bytes[g][base+i/2] |= value << (4*(i%2));
                    } else slots.bytes[g][base+i] = value;
                }
    }
    return slots;
}

template<unsigned W, unsigned S, unsigned T, bool Transpose> static int run()
{
    alignas(64) static constexpr auto slots = pack<W,S,T>();
    volatile Arena *a = reinterpret_cast<volatile Arena *>(EDGE_DTCM_BASE);
    constexpr unsigned stride = Slots<W,S,T>::stride;
    static_assert(2*stride <= sizeof(a->ring), "two complete circular slots must fit");
    for (unsigned v = 0; v < lanes; ++v)
        for (unsigned k = 0; k < lanes; ++k) a->x[v][k] = bf16(input(v,k));
    for (unsigned i = 0; i < 8; ++i) a->ring_guard[i] = a->output_guard[i] = 0xcafebabe;
    for (unsigned t = 0; t < groups*T; ++t)
        for (unsigned v = 0; v < lanes; ++v)
            for (unsigned r = 0; r < lanes; ++r) a->y[t][v][r] = 0xdead;
    edge_sim_printf("PACKED BEGIN W=%u scales=%u group_k=%u transpose=%u cycle=%u\n", W,S,T*8,Transpose,unsigned(edge_get_cycle()));
    edge_tensor_setwtype<W>();
    edge_tensor_setn(lanes);
    edge_dcache_clean_range(&slots, sizeof(slots));
    // Third slot wraps a two-slot ring. Padding occurs only at the slot end.
    edge_dma_start_strided_circular(&slots, (void *)a->ring,
                                    stride, stride, groups, 0, 1, stride, 2);
    edge_tensor_wsld_circular<Transpose,T,W,S>();
    for (unsigned g = 0; g < groups; ++g)
        for (unsigned t = 0; t < T; ++t) {
            edge_tensor_setin((const void *)a->x);
            edge_tensor_setout((void *)a->y[g*T+t]);
            edge_tensor_start<EDGE_TENSOR_START_OPT_USE_SCALE | EDGE_TENSOR_START_OPT_NO_PSUM>();
        }
    edge_tensor_sync();
    edge_dma_sync();
    for (unsigned g = 0; g < groups; ++g)
        for (unsigned t = 0; t < T; ++t)
            for (unsigned v = 0; v < lanes; ++v)
                for (unsigned r = 0; r < lanes; ++r) {
                    int dot = 0;
                    for (unsigned k = 0; k < lanes; ++k)
                        dot += input(v,k) * (Transpose ? weight(g,t,k,r) : weight(g,t,r,k));
                    const unsigned s = (g + (S == 1 ? 0 : r)) % 3;
                    const uint16_t expected = bf16(dot * (s == 0 ? .5f : s == 1 ? 1.f : 2.f));
                    if (a->y[g*T+t][v][r] != expected) {
                        edge_sim_printf("PACKED FAIL W=%u S=%u T=%u tr=%u g=%u t=%u v=%u r=%u got=%x expected=%x\n",
                                        W,S,T,Transpose,g,t,v,r,a->y[g*T+t][v][r],expected);
                        return 1;
                    }
                }
    for (unsigned i = 0; i < 8; ++i)
        if (a->ring_guard[i] != 0xcafebabe || a->output_guard[i] != 0xcafebabe) return 2;
    edge_sim_printf("PACKED PASS W=%u scales=%u group_k=%u transpose=%u\n", W,S,T*8,Transpose);
    return 0;
}

template<unsigned W> static int formats()
{
    return run<W,1,1,false>() || run<W,8,1,true>() ||
           run<W,1,4,true>() || run<W,8,4,false>();
}
template<unsigned W> static int group_sizes()
{
    return run<W,8,2,false>() || run<W,8,8,true>();
}
extern "C" int main()
{
    if (formats<EDGE_TENSOR_WTYPE_BF16>() || formats<EDGE_TENSOR_WTYPE_INT8>() ||
        formats<EDGE_TENSOR_WTYPE_FP4>() || formats<EDGE_TENSOR_WTYPE_FP8_E4M3FN>() ||
        formats<EDGE_TENSOR_WTYPE_FP8_E5M2>() || group_sizes<EDGE_TENSOR_WTYPE_FP4>() ||
        group_sizes<EDGE_TENSOR_WTYPE_FP8_E4M3FN>() || group_sizes<EDGE_TENSOR_WTYPE_FP8_E5M2>()) return 1;
    edge_sim_printf("PACKED ALL PASS cases=26\n");
    return 0;
}
