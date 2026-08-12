/* Copyright 2026 StarEdge contributors.
 *
 * Licensed under the Apache License, Version 2.0.
 */

#include <stdint.h>

#include "intrinsic/edge_intrinsic.hpp"
#include "intrinsic/edge_sim_console.hpp"

extern "C" int main(void)
{
    const uint64_t raw = edge_get_hardware_id();
    const edge_hardware_info info = edge_decode_hardware_id(raw);

    printf("Edge hardware ID: 0x%016llx\n", (unsigned long long)raw);
    printf("  model ID:   0x%06x\n", edge_get_hardware_model_id(raw));
    printf("  RV core ID: %u\n", (unsigned)info.rv_core_id);
    printf("  product ID: %u\n", (unsigned)info.product_id);
    printf("  FPU ver:    %u\n", (unsigned)info.fpu_ver);
    printf("  VPU ver:    %u\n", (unsigned)info.vpu_ver);
    printf("  Tensor:     %ux%u (P=%u Q=%u)\n",
           1u << info.tensor_p, 1u << info.tensor_q,
           (unsigned)info.tensor_p, (unsigned)info.tensor_q);
    printf("  weight:     0x%02x\n", (unsigned)info.weight_spec);
    printf("  scale:      0x%02x\n", (unsigned)info.scale_spec);
    printf("  tensor:     0x%02x\n", (unsigned)info.tensor_spec);

    const bool valid =
        info.rv_core_id == EDGE_RV_CORE_ID_EDGE_RV &&
        info.product_id == 3u && info.fpu_ver == 1u && info.vpu_ver == 0u &&
        info.tensor_p == 3u && info.tensor_q == 3u &&
        info.weight_spec ==
            (EDGE_WEIGHT_SPEC_BF16 | EDGE_WEIGHT_SPEC_INT8) &&
        info.scale_spec == EDGE_SCALE_SPEC_BF16 &&
        info.tensor_spec == EDGE_TENSOR_SPEC_V1;
    return valid ? 0 : 1;
}
