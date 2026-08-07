#include <stdint.h>
#include "intrinsic/edge_intrinsic.hpp"
#include "intrinsic/edge_sim_console.hpp"

#define MM64_DIM        64u
#define MM64_TILE       8u
#define MM64_BLOCKS     (MM64_DIM / MM64_TILE)
#define MM64_TOKENS      128u
#define MM64_STREAM_ELEMS (MM64_DIM * MM64_TOKENS)
#define MM64_ELEMS      (MM64_DIM * MM64_DIM)
#define MM64_SETN       MM64_TOKENS
#define MM64_W_BYTES    (MM64_DIM * MM64_DIM)
#define MM64_W_TILE_BYTES (MM64_TILE * MM64_TILE)
#define MM64_W_STRIDE_BYTES (MM64_BLOCKS * MM64_W_TILE_BYTES)
#define MM64_W_RING_TILES (MM64_BLOCKS * MM64_BLOCKS)
#define MM64_Y_DRAM_BASE ((uintptr_t)0x100000u)

typedef struct bf16 {
    uint16_t value;
} bf16_t;

/*
 * Circular DMA/WLD version of the 64x64 x 128-token tensor case.
 *
 * This is the 128-token scaling variant of the 64x64 circular tensor benchmark.
 * The weight tile count is unchanged, while each tile start runs twice as
 * many token vector steps to isolate long-stream MAC utilization.
 *
 * The weight ROM uses transposed [k_block][out_block][k_lane][out_lane]
 * storage. One packed-XY circular DMA visits it in output-block-major order,
 * while tensor.wld_t_circular performs the 8x8 in-tile transpose.
 */

struct Mm64Dtcm {
    bf16_t x[MM64_STREAM_ELEMS];
    bf16_t y[MM64_STREAM_ELEMS];
    bf16_t zero[MM64_STREAM_ELEMS];
    int8_t w_ring[MM64_W_RING_TILES][MM64_W_TILE_BYTES];
};

struct PackedWeightRom {
    int8_t data[MM64_W_BYTES];
};

static constexpr uint16_t x_pattern(unsigned int idx)
{
    switch (idx % 13u) {
    case 0: return 0xc0c0u;
    case 1: return 0xc0a0u;
    case 2: return 0xc080u;
    case 3: return 0xc040u;
    case 4: return 0xc000u;
    case 5: return 0xbf80u;
    case 6: return 0x0000u;
    case 7: return 0x3f80u;
    case 8: return 0x4000u;
    case 9: return 0x4040u;
    case 10: return 0x4080u;
    case 11: return 0x40a0u;
    default: return 0x40c0u;
    }
}

static constexpr unsigned int packed_weight_index(unsigned int out_blk,
                                                  unsigned int k_blk,
                                                  unsigned int out_lane,
                                                  unsigned int k_lane)
{
    return (((k_blk * MM64_BLOCKS + out_blk) * MM64_TILE + k_lane)
            * MM64_TILE) + out_lane;
}

static constexpr PackedWeightRom make_identity_weight_rom(void)
{
    PackedWeightRom rom = {};

    for (unsigned int out_blk = 0; out_blk < MM64_BLOCKS; ++out_blk) {
        for (unsigned int k_blk = 0; k_blk < MM64_BLOCKS; ++k_blk) {
            for (unsigned int out_lane = 0; out_lane < MM64_TILE;
                 ++out_lane) {
                for (unsigned int k_lane = 0; k_lane < MM64_TILE;
                     ++k_lane) {
                    rom.data[packed_weight_index(out_blk, k_blk,
                                                 out_lane, k_lane)] =
                        (out_blk == k_blk && out_lane == k_lane) ? 1 : 0;
                }
            }
        }
    }

    return rom;
}

alignas(64) static constexpr PackedWeightRom kMm64WIdentity =
    make_identity_weight_rom();

extern "C" int main(void)
{
    volatile Mm64Dtcm *dtcm = (volatile Mm64Dtcm *)EDGE_DTCM_BASE;

    for (unsigned int idx = 0; idx < MM64_STREAM_ELEMS; ++idx) {
        dtcm->x[idx].value = x_pattern(idx);
        dtcm->y[idx].value = 0xdeadu;
        dtcm->zero[idx].value = 0;
    }

    edge_tensor_setcsr<1, 2>();
    edge_tensor_setn(MM64_SETN);

    uintptr_t cycle_start = edge_get_cycle();

    edge_dma_start_strided_circular((const void *)kMm64WIdentity.data,
                                    (void *)dtcm->w_ring,
                                    MM64_W_TILE_BYTES,
                                    MM64_W_STRIDE_BYTES,
                                    MM64_BLOCKS,
                                    MM64_W_TILE_BYTES,
                                    MM64_BLOCKS,
                                    MM64_BLOCKS * MM64_BLOCKS);
    edge_tensor_wld_t_circular();

    for (unsigned int out_blk = 0; out_blk < MM64_BLOCKS; ++out_blk) {
        for (unsigned int k_blk = 0; k_blk < MM64_BLOCKS; ++k_blk) {
            unsigned int tile_id = out_blk * MM64_BLOCKS + k_blk;
            volatile bf16_t *psum_ptr =
                (k_blk == 0)
                ? &dtcm->zero[out_blk * MM64_TOKENS * MM64_TILE]
                : &dtcm->y[out_blk * MM64_TOKENS * MM64_TILE];

            edge_tensor_setin((const void *)&dtcm->x[
                k_blk * MM64_TOKENS * MM64_TILE]);
            edge_tensor_setout((void *)&dtcm->y[
                out_blk * MM64_TOKENS * MM64_TILE]);
            edge_tensor_setpsum((const void *)psum_ptr);
            edge_tensor_start();
            if (tile_id + 1u < (MM64_BLOCKS * MM64_BLOCKS))
                edge_tensor_wld_t_circular();
        }
    }

    edge_tensor_sync();
    edge_dma_sync();

    uintptr_t cycle_end = edge_get_cycle();
    uintptr_t cycle_delta = cycle_end - cycle_start;

    printf("edge tensor matmul64x64x128: cycle_start=%lu cycle_end=%lu "
           "cycle_delta=%lu starts=%u setn=%u\n",
           (unsigned long)cycle_start,
           (unsigned long)cycle_end,
           (unsigned long)cycle_delta,
           MM64_BLOCKS * MM64_BLOCKS,
           MM64_SETN);

    edge_dma_start((const void *)dtcm->y, (void *)MM64_Y_DRAM_BASE,
                   MM64_STREAM_ELEMS * sizeof(bf16_t));
    edge_dma_sync();

    return 0;
}
