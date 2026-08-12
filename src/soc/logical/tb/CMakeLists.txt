set(edge_soc_build_dir "${CMAKE_CURRENT_BINARY_DIR}")
set(edge_soc_vvp_smoke_memh_src "${CMAKE_CURRENT_LIST_DIR}/edge_soc_vvp_smoke.memh")
set(edge_soc_vvp_smoke_words_src "${CMAKE_CURRENT_LIST_DIR}/edge_soc_vvp_smoke.words")
set(edge_soc_vvp_smoke_memh "${edge_soc_build_dir}/edge_soc_vvp_smoke.memh")
set(edge_soc_vvp_smoke_words "${edge_soc_build_dir}/edge_soc_vvp_smoke.words")
set(edge_soc_software_build_dir "${edge_soc_build_dir}/software")
set(edge_rv64i_smoke_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_RV64I/EDGE_RV64I_SMOKE.s")
set(edge_rv64i_smoke_obj "${edge_soc_software_build_dir}/EDGE_RV64I_SMOKE.o")
set(edge_rv64i_smoke_elf "${edge_soc_software_build_dir}/EDGE_RV64I_SMOKE.elf")
set(edge_rv64i_smoke_objdump "${edge_soc_software_build_dir}/EDGE_RV64I_SMOKE.obj")
set(edge_rv64i_smoke_memh "${edge_soc_software_build_dir}/EDGE_RV64I_SMOKE.memh")
set(edge_rv64i_smoke_words "${edge_soc_software_build_dir}/EDGE_RV64I_SMOKE.words")
set(edge_delayed_load_ret_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_RV64I/EDGE_DELAYED_LOAD_RET.s")
set(edge_delayed_load_ret_obj "${edge_soc_software_build_dir}/EDGE_DELAYED_LOAD_RET.o")
set(edge_delayed_load_ret_elf "${edge_soc_software_build_dir}/EDGE_DELAYED_LOAD_RET.elf")
set(edge_delayed_load_ret_objdump "${edge_soc_software_build_dir}/EDGE_DELAYED_LOAD_RET.obj")
set(edge_delayed_load_ret_memh "${edge_soc_software_build_dir}/EDGE_DELAYED_LOAD_RET.memh")
set(edge_delayed_load_ret_words "${edge_soc_software_build_dir}/EDGE_DELAYED_LOAD_RET.words")
set(edge_dtcm_smoke_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_DTCM/EDGE_DTCM_SMOKE.s")
set(edge_dtcm_smoke_obj "${edge_soc_software_build_dir}/EDGE_DTCM_SMOKE.o")
set(edge_dtcm_smoke_elf "${edge_soc_software_build_dir}/EDGE_DTCM_SMOKE.elf")
set(edge_dtcm_smoke_objdump "${edge_soc_software_build_dir}/EDGE_DTCM_SMOKE.obj")
set(edge_dtcm_smoke_memh "${edge_soc_software_build_dir}/EDGE_DTCM_SMOKE.memh")
set(edge_dtcm_smoke_words "${edge_soc_software_build_dir}/EDGE_DTCM_SMOKE.words")
set(edge_dma_smoke_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_DMA/EDGE_DMA_SMOKE.s")
set(edge_dma_smoke_obj "${edge_soc_software_build_dir}/EDGE_DMA_SMOKE.o")
set(edge_dma_smoke_elf "${edge_soc_software_build_dir}/EDGE_DMA_SMOKE.elf")
set(edge_dma_smoke_objdump "${edge_soc_software_build_dir}/EDGE_DMA_SMOKE.obj")
set(edge_dma_smoke_memh "${edge_soc_software_build_dir}/EDGE_DMA_SMOKE.memh")
set(edge_dma_smoke_words "${edge_soc_software_build_dir}/EDGE_DMA_SMOKE.words")
set(edge_cache_smoke_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_CACHE/EDGE_CACHE_SMOKE.s")
set(edge_cache_smoke_obj "${edge_soc_software_build_dir}/EDGE_CACHE_SMOKE.o")
set(edge_cache_smoke_elf "${edge_soc_software_build_dir}/EDGE_CACHE_SMOKE.elf")
set(edge_cache_smoke_objdump "${edge_soc_software_build_dir}/EDGE_CACHE_SMOKE.obj")
set(edge_cache_smoke_memh "${edge_soc_software_build_dir}/EDGE_CACHE_SMOKE.memh")
set(edge_cache_smoke_words "${edge_soc_software_build_dir}/EDGE_CACHE_SMOKE.words")
set(edge_dcache_victim_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_DCACHE_VICTIM/EDGE_DCACHE_VICTIM.cpp")
set(edge_dcache_victim_obj "${edge_soc_software_build_dir}/EDGE_DCACHE_VICTIM.o")
set(edge_dcache_victim_elf "${edge_soc_software_build_dir}/EDGE_DCACHE_VICTIM.elf")
set(edge_dcache_victim_objdump "${edge_soc_software_build_dir}/EDGE_DCACHE_VICTIM.obj")
set(edge_dcache_victim_memh "${edge_soc_software_build_dir}/EDGE_DCACHE_VICTIM.memh")
set(edge_dcache_victim_words "${edge_soc_software_build_dir}/EDGE_DCACHE_VICTIM.words")
set(edge_lsu_mixed_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_LSU_MIXED/EDGE_LSU_MIXED.cpp")
set(edge_lsu_mixed_obj "${edge_soc_software_build_dir}/EDGE_LSU_MIXED.o")
set(edge_lsu_mixed_elf "${edge_soc_software_build_dir}/EDGE_LSU_MIXED.elf")
set(edge_lsu_mixed_objdump "${edge_soc_software_build_dir}/EDGE_LSU_MIXED.obj")
set(edge_lsu_mixed_memh "${edge_soc_software_build_dir}/EDGE_LSU_MIXED.memh")
set(edge_lsu_mixed_words "${edge_soc_software_build_dir}/EDGE_LSU_MIXED.words")
set(edge_dma_cpp_smoke_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_DMA_CPP/EDGE_DMA_CPP_SMOKE.cpp")
set(edge_dma_cpp_smoke_obj "${edge_soc_software_build_dir}/EDGE_DMA_CPP_SMOKE.o")
set(edge_dma_cpp_smoke_elf "${edge_soc_software_build_dir}/EDGE_DMA_CPP_SMOKE.elf")
set(edge_dma_cpp_smoke_objdump "${edge_soc_software_build_dir}/EDGE_DMA_CPP_SMOKE.obj")
set(edge_dma_cpp_smoke_memh "${edge_soc_software_build_dir}/EDGE_DMA_CPP_SMOKE.memh")
set(edge_dma_cpp_smoke_words "${edge_soc_software_build_dir}/EDGE_DMA_CPP_SMOKE.words")
set(edge_dma_simple_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_DMA_SIMPLE/EDGE_DMA_SIMPLE.cpp")
set(edge_dma_simple_obj "${edge_soc_software_build_dir}/EDGE_DMA_SIMPLE.o")
set(edge_dma_simple_elf "${edge_soc_software_build_dir}/EDGE_DMA_SIMPLE.elf")
set(edge_dma_simple_objdump "${edge_soc_software_build_dir}/EDGE_DMA_SIMPLE.obj")
set(edge_dma_simple_memh "${edge_soc_software_build_dir}/EDGE_DMA_SIMPLE.memh")
set(edge_dma_simple_words "${edge_soc_software_build_dir}/EDGE_DMA_SIMPLE.words")
set(edge_dma_dtcm_to_dram_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_DMA_DTCM_TO_DRAM/EDGE_DMA_DTCM_TO_DRAM.cpp")
set(edge_dma_dtcm_to_dram_obj "${edge_soc_software_build_dir}/EDGE_DMA_DTCM_TO_DRAM.o")
set(edge_dma_dtcm_to_dram_elf "${edge_soc_software_build_dir}/EDGE_DMA_DTCM_TO_DRAM.elf")
set(edge_dma_dtcm_to_dram_objdump "${edge_soc_software_build_dir}/EDGE_DMA_DTCM_TO_DRAM.obj")
set(edge_dma_dtcm_to_dram_memh "${edge_soc_software_build_dir}/EDGE_DMA_DTCM_TO_DRAM.memh")
set(edge_dma_dtcm_to_dram_words "${edge_soc_software_build_dir}/EDGE_DMA_DTCM_TO_DRAM.words")
set(edge_dma_burst_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_DMA_BURST/EDGE_DMA_BURST.cpp")
set(edge_dma_burst_obj "${edge_soc_software_build_dir}/EDGE_DMA_BURST.o")
set(edge_dma_burst_elf "${edge_soc_software_build_dir}/EDGE_DMA_BURST.elf")
set(edge_dma_burst_objdump "${edge_soc_software_build_dir}/EDGE_DMA_BURST.obj")
set(edge_dma_burst_memh "${edge_soc_software_build_dir}/EDGE_DMA_BURST.memh")
set(edge_dma_burst_words "${edge_soc_software_build_dir}/EDGE_DMA_BURST.words")
set(edge_dma_tail_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_DMA_TAIL/EDGE_DMA_TAIL.cpp")
set(edge_dma_tail_obj "${edge_soc_software_build_dir}/EDGE_DMA_TAIL.o")
set(edge_dma_tail_elf "${edge_soc_software_build_dir}/EDGE_DMA_TAIL.elf")
set(edge_dma_tail_objdump "${edge_soc_software_build_dir}/EDGE_DMA_TAIL.obj")
set(edge_dma_tail_memh "${edge_soc_software_build_dir}/EDGE_DMA_TAIL.memh")
set(edge_dma_tail_words "${edge_soc_software_build_dir}/EDGE_DMA_TAIL.words")
set(edge_dma_ordering_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_DMA_ORDERING/EDGE_DMA_ORDERING.cpp")
set(edge_dma_ordering_obj "${edge_soc_software_build_dir}/EDGE_DMA_ORDERING.o")
set(edge_dma_ordering_elf "${edge_soc_software_build_dir}/EDGE_DMA_ORDERING.elf")
set(edge_dma_ordering_objdump "${edge_soc_software_build_dir}/EDGE_DMA_ORDERING.obj")
set(edge_dma_ordering_memh "${edge_soc_software_build_dir}/EDGE_DMA_ORDERING.memh")
set(edge_dma_ordering_words "${edge_soc_software_build_dir}/EDGE_DMA_ORDERING.words")
set(edge_tensor_control_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_TENSOR_CONTROL/EDGE_TENSOR_CONTROL.cpp")
set(edge_tensor_control_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_CONTROL.o")
set(edge_tensor_control_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_CONTROL.elf")
set(edge_tensor_control_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_CONTROL.obj")
set(edge_tensor_control_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_CONTROL.memh")
set(edge_tensor_control_words "${edge_soc_software_build_dir}/EDGE_TENSOR_CONTROL.words")
set(edge_actu_smoke_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_ACTU_SMOKE/EDGE_ACTU_SMOKE.cpp")
set(edge_actu_smoke_obj "${edge_soc_software_build_dir}/EDGE_ACTU_SMOKE.o")
set(edge_actu_smoke_elf "${edge_soc_software_build_dir}/EDGE_ACTU_SMOKE.elf")
set(edge_actu_smoke_objdump "${edge_soc_software_build_dir}/EDGE_ACTU_SMOKE.obj")
set(edge_actu_smoke_memh "${edge_soc_software_build_dir}/EDGE_ACTU_SMOKE.memh")
set(edge_actu_smoke_words "${edge_soc_software_build_dir}/EDGE_ACTU_SMOKE.words")
set(edge_actu_silu_bench_src "${STAREDGE_ROOT}/experiments/actu-silu-throughput/edge_actu_silu_bench.cpp")
set(edge_actu_silu_bench_obj "${edge_soc_software_build_dir}/EDGE_ACTU_SILU_BENCH.o")
set(edge_actu_silu_bench_elf "${edge_soc_software_build_dir}/EDGE_ACTU_SILU_BENCH.elf")
set(edge_actu_silu_bench_objdump "${edge_soc_software_build_dir}/EDGE_ACTU_SILU_BENCH.obj")
set(edge_actu_silu_bench_memh "${edge_soc_software_build_dir}/EDGE_ACTU_SILU_BENCH.memh")
set(edge_actu_silu_bench_words "${edge_soc_software_build_dir}/EDGE_ACTU_SILU_BENCH.words")
set(edge_cmpu_smoke_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_CMPU_SMOKE/EDGE_CMPU_SMOKE.cpp")
set(edge_cmpu_smoke_obj "${edge_soc_software_build_dir}/EDGE_CMPU_SMOKE.o")
set(edge_cmpu_smoke_elf "${edge_soc_software_build_dir}/EDGE_CMPU_SMOKE.elf")
set(edge_cmpu_smoke_objdump "${edge_soc_software_build_dir}/EDGE_CMPU_SMOKE.obj")
set(edge_cmpu_smoke_memh "${edge_soc_software_build_dir}/EDGE_CMPU_SMOKE.memh")
set(edge_cmpu_smoke_words "${edge_soc_software_build_dir}/EDGE_CMPU_SMOKE.words")
set(edge_actu_pygen_src "${STAREDGE_ROOT}/tests/software/cases/EDGE_ACTU_PYGEN/EDGE_ACTU_PYGEN.cpp")
set(edge_actu_pygen_script "${STAREDGE_ROOT}/tests/software/cases/EDGE_ACTU_PYGEN/actu_pygen.py")
set(edge_actu_pygen_header "${edge_soc_software_build_dir}/edge_actu_pygen_vectors.hpp")
set(edge_actu_pygen_expected "${edge_soc_software_build_dir}/EDGE_ACTU_PYGEN.expected.json")
set(edge_actu_pygen_report "${edge_soc_software_build_dir}/EDGE_ACTU_PYGEN.run_case.report")
set(edge_actu_pygen_obj "${edge_soc_software_build_dir}/EDGE_ACTU_PYGEN.o")
set(edge_actu_pygen_elf "${edge_soc_software_build_dir}/EDGE_ACTU_PYGEN.elf")
set(edge_actu_pygen_objdump "${edge_soc_software_build_dir}/EDGE_ACTU_PYGEN.obj")
set(edge_actu_pygen_memh "${edge_soc_software_build_dir}/EDGE_ACTU_PYGEN.memh")
set(edge_actu_pygen_words "${edge_soc_software_build_dir}/EDGE_ACTU_PYGEN.words")
set(edge_tensor_matvec64_1token_tiled_src "${STAREDGE_ROOT}/tests/software/tensor/matvec64_1token_tiled.cpp")
set(edge_tensor_matvec64_1token_tiled_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_MATVEC64_1TOKEN_TILED.o")
set(edge_tensor_matvec64_1token_tiled_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_MATVEC64_1TOKEN_TILED.elf")
set(edge_tensor_matvec64_1token_tiled_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_MATVEC64_1TOKEN_TILED.obj")
set(edge_tensor_matvec64_1token_tiled_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_MATVEC64_1TOKEN_TILED.memh")
set(edge_tensor_matvec64_1token_tiled_words "${edge_soc_software_build_dir}/EDGE_TENSOR_MATVEC64_1TOKEN_TILED.words")
set(edge_tensor_tile8x8_stream64tokens_src "${STAREDGE_ROOT}/tests/software/tensor/tile8x8_stream64tokens.cpp")
set(edge_tensor_tile8x8_stream64tokens_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_TILE8X8_STREAM64TOKENS.o")
set(edge_tensor_tile8x8_stream64tokens_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_TILE8X8_STREAM64TOKENS.elf")
set(edge_tensor_tile8x8_stream64tokens_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_TILE8X8_STREAM64TOKENS.obj")
set(edge_tensor_tile8x8_stream64tokens_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_TILE8X8_STREAM64TOKENS.memh")
set(edge_tensor_tile8x8_stream64tokens_words "${edge_soc_software_build_dir}/EDGE_TENSOR_TILE8X8_STREAM64TOKENS.words")
set(edge_tensor_bf16_wld_direct_circular_src "${STAREDGE_ROOT}/tests/software/tensor/bf16_wld_direct_circular.cpp")
set(edge_tensor_bf16_wld_direct_circular_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_BF16_WLD_DIRECT_CIRCULAR.o")
set(edge_tensor_bf16_wld_direct_circular_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_BF16_WLD_DIRECT_CIRCULAR.elf")
set(edge_tensor_bf16_wld_direct_circular_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_BF16_WLD_DIRECT_CIRCULAR.obj")
set(edge_tensor_bf16_wld_direct_circular_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_BF16_WLD_DIRECT_CIRCULAR.memh")
set(edge_tensor_bf16_wld_direct_circular_words "${edge_soc_software_build_dir}/EDGE_TENSOR_BF16_WLD_DIRECT_CIRCULAR.words")
set(edge_tensor_bf16_matmul8x8_src "${STAREDGE_ROOT}/tests/software/tensor/bf16_matmul8x8.cpp")
set(edge_tensor_bf16_matmul8x8_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_BF16_MATMUL8X8.o")
set(edge_tensor_bf16_matmul8x8_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_BF16_MATMUL8X8.elf")
set(edge_tensor_bf16_matmul8x8_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_BF16_MATMUL8X8.obj")
set(edge_tensor_bf16_matmul8x8_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_BF16_MATMUL8X8.memh")
set(edge_tensor_bf16_matmul8x8_words "${edge_soc_software_build_dir}/EDGE_TENSOR_BF16_MATMUL8X8.words")
set(edge_tensor_reuse_weight_pending_src "${STAREDGE_ROOT}/tests/software/tensor/reuse_weight_pending.cpp")
set(edge_tensor_reuse_weight_pending_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_REUSE_WEIGHT_PENDING.o")
set(edge_tensor_reuse_weight_pending_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_REUSE_WEIGHT_PENDING.elf")
set(edge_tensor_reuse_weight_pending_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_REUSE_WEIGHT_PENDING.obj")
set(edge_tensor_reuse_weight_pending_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_REUSE_WEIGHT_PENDING.memh")
set(edge_tensor_reuse_weight_pending_words "${edge_soc_software_build_dir}/EDGE_TENSOR_REUSE_WEIGHT_PENDING.words")
set(edge_tensor_start_tile_reuse_debug_src "${STAREDGE_ROOT}/tests/software/tensor/start_tile_reuse_debug.cpp")
set(edge_tensor_start_tile_reuse_debug_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_START_TILE_REUSE_DEBUG.o")
set(edge_tensor_start_tile_reuse_debug_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_START_TILE_REUSE_DEBUG.elf")
set(edge_tensor_start_tile_reuse_debug_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_START_TILE_REUSE_DEBUG.obj")
set(edge_tensor_start_tile_reuse_debug_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_START_TILE_REUSE_DEBUG.memh")
set(edge_tensor_start_tile_reuse_debug_words "${edge_soc_software_build_dir}/EDGE_TENSOR_START_TILE_REUSE_DEBUG.words")
set(edge_tensor_start_overlap_setn1_src "${STAREDGE_ROOT}/tests/software/tensor/start_overlap_setn1.cpp")
set(edge_tensor_start_overlap_setn1_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_START_OVERLAP_SETN1.o")
set(edge_tensor_start_overlap_setn1_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_START_OVERLAP_SETN1.elf")
set(edge_tensor_start_overlap_setn1_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_START_OVERLAP_SETN1.obj")
set(edge_tensor_start_overlap_setn1_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_START_OVERLAP_SETN1.memh")
set(edge_tensor_start_overlap_setn1_words "${edge_soc_software_build_dir}/EDGE_TENSOR_START_OVERLAP_SETN1.words")
set(edge_tensor_attention_score64_8x8_tiles_src "${STAREDGE_ROOT}/tests/software/tensor/attention_score64_8x8_tiles.cpp")
set(edge_tensor_attention_score64_8x8_tiles_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_ATTENTION_SCORE64_8X8_TILES.o")
set(edge_tensor_attention_score64_8x8_tiles_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_ATTENTION_SCORE64_8X8_TILES.elf")
set(edge_tensor_attention_score64_8x8_tiles_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_ATTENTION_SCORE64_8X8_TILES.obj")
set(edge_tensor_attention_score64_8x8_tiles_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_ATTENTION_SCORE64_8X8_TILES.memh")
set(edge_tensor_attention_score64_8x8_tiles_words "${edge_soc_software_build_dir}/EDGE_TENSOR_ATTENTION_SCORE64_8X8_TILES.words")
set(edge_tensor_attention_value64_8x8_tiles_src "${STAREDGE_ROOT}/tests/software/tensor/attention_value64_8x8_tiles.cpp")
set(edge_tensor_attention_value64_8x8_tiles_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_ATTENTION_VALUE64_8X8_TILES.o")
set(edge_tensor_attention_value64_8x8_tiles_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_ATTENTION_VALUE64_8X8_TILES.elf")
set(edge_tensor_attention_value64_8x8_tiles_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_ATTENTION_VALUE64_8X8_TILES.obj")
set(edge_tensor_attention_value64_8x8_tiles_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_ATTENTION_VALUE64_8X8_TILES.memh")
set(edge_tensor_attention_value64_8x8_tiles_words "${edge_soc_software_build_dir}/EDGE_TENSOR_ATTENTION_VALUE64_8X8_TILES.words")
set(edge_tensor_matmul64x64_64tokens_tiled_src "${STAREDGE_ROOT}/tests/software/tensor/matmul64x64_64tokens_tiled.cpp")
set(edge_tensor_matmul64x64_64tokens_tiled_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_64TOKENS_TILED.o")
set(edge_tensor_matmul64x64_64tokens_tiled_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_64TOKENS_TILED.elf")
set(edge_tensor_matmul64x64_64tokens_tiled_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_64TOKENS_TILED.obj")
set(edge_tensor_matmul64x64_64tokens_tiled_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_64TOKENS_TILED.memh")
set(edge_tensor_matmul64x64_64tokens_tiled_words "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_64TOKENS_TILED.words")
set(edge_tensor_matmul64x64_64tokens_tiled_circular_src "${STAREDGE_ROOT}/tests/software/tensor/matmul64x64_64tokens_tiled_circular.cpp")
set(edge_tensor_matmul64x64_64tokens_tiled_circular_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_64TOKENS_TILED_CIRCULAR.o")
set(edge_tensor_matmul64x64_64tokens_tiled_circular_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_64TOKENS_TILED_CIRCULAR.elf")
set(edge_tensor_matmul64x64_64tokens_tiled_circular_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_64TOKENS_TILED_CIRCULAR.obj")
set(edge_tensor_matmul64x64_64tokens_tiled_circular_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_64TOKENS_TILED_CIRCULAR.memh")
set(edge_tensor_matmul64x64_64tokens_tiled_circular_words "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_64TOKENS_TILED_CIRCULAR.words")
set(edge_tensor_matmul64x64_128tokens_tiled_circular_src "${STAREDGE_ROOT}/tests/software/tensor/matmul64x64_128tokens_tiled_circular.cpp")
set(edge_tensor_matmul64x64_128tokens_tiled_circular_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_128TOKENS_TILED_CIRCULAR.o")
set(edge_tensor_matmul64x64_128tokens_tiled_circular_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_128TOKENS_TILED_CIRCULAR.elf")
set(edge_tensor_matmul64x64_128tokens_tiled_circular_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_128TOKENS_TILED_CIRCULAR.obj")
set(edge_tensor_matmul64x64_128tokens_tiled_circular_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_128TOKENS_TILED_CIRCULAR.memh")
set(edge_tensor_matmul64x64_128tokens_tiled_circular_words "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL64X64_128TOKENS_TILED_CIRCULAR.words")
set(edge_tensor_wsld_circular_q8_src "${STAREDGE_ROOT}/tests/software/tensor/wsld_circular_q8.cpp")
set(edge_tensor_wsld_circular_q8_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_WSLD_CIRCULAR_Q8.o")
set(edge_tensor_wsld_circular_q8_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_WSLD_CIRCULAR_Q8.elf")
set(edge_tensor_wsld_circular_q8_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_WSLD_CIRCULAR_Q8.obj")
set(edge_tensor_wsld_circular_q8_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_WSLD_CIRCULAR_Q8.memh")
set(edge_tensor_wsld_circular_q8_words "${edge_soc_software_build_dir}/EDGE_TENSOR_WSLD_CIRCULAR_Q8.words")
set(edge_tensor_sld_circular_mul_src "${STAREDGE_ROOT}/tests/software/tensor/sld_circular_mul.cpp")
set(edge_tensor_sld_circular_mul_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_SLD_CIRCULAR_MUL.o")
set(edge_tensor_sld_circular_mul_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_SLD_CIRCULAR_MUL.elf")
set(edge_tensor_sld_circular_mul_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_SLD_CIRCULAR_MUL.obj")
set(edge_tensor_sld_circular_mul_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_SLD_CIRCULAR_MUL.memh")
set(edge_tensor_sld_circular_mul_words "${edge_soc_software_build_dir}/EDGE_TENSOR_SLD_CIRCULAR_MUL.words")
set(edge_tensor_sld_stream_mul_src "${STAREDGE_ROOT}/tests/software/tensor/sld_stream_mul.cpp")
set(edge_tensor_sld_stream_mul_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_SLD_STREAM_MUL.o")
set(edge_tensor_sld_stream_mul_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_SLD_STREAM_MUL.elf")
set(edge_tensor_sld_stream_mul_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_SLD_STREAM_MUL.obj")
set(edge_tensor_sld_stream_mul_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_SLD_STREAM_MUL.memh")
set(edge_tensor_sld_stream_mul_words "${edge_soc_software_build_dir}/EDGE_TENSOR_SLD_STREAM_MUL.words")
set(edge_tensor_matmul512x512_32tokens_transpose_circular_src "${STAREDGE_ROOT}/tests/software/tensor/matmul512x512_32tokens_transpose_circular.cpp")
set(edge_tensor_matmul512x512_32tokens_transpose_circular_obj "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL512X512_32TOKENS_TRANSPOSE_CIRCULAR.o")
set(edge_tensor_matmul512x512_32tokens_transpose_circular_elf "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL512X512_32TOKENS_TRANSPOSE_CIRCULAR.elf")
set(edge_tensor_matmul512x512_32tokens_transpose_circular_objdump "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL512X512_32TOKENS_TRANSPOSE_CIRCULAR.obj")
set(edge_tensor_matmul512x512_32tokens_transpose_circular_memh "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL512X512_32TOKENS_TRANSPOSE_CIRCULAR.memh")
set(edge_tensor_matmul512x512_32tokens_transpose_circular_words "${edge_soc_software_build_dir}/EDGE_TENSOR_MATMUL512X512_32TOKENS_TRANSPOSE_CIRCULAR.words")
set(edge_soc_c_recursive_dp_smoke_src "${STAREDGE_ROOT}/tests/software/bench/recursive_dp_bench.cpp")
set(edge_soc_c_recursive_dp_smoke_dir "${edge_soc_software_build_dir}/recursive_dp_bench")
set(edge_soc_c_recursive_dp_smoke_memh "${edge_soc_c_recursive_dp_smoke_dir}/recursive_dp_bench.memh")
set(edge_soc_c_recursive_dp_smoke_dump "${edge_soc_c_recursive_dp_smoke_dir}/recursive_dp_bench.dump")
set(edge_soc_c_recursive_dp_smoke_words "${edge_soc_c_recursive_dp_smoke_dir}/recursive_dp_bench.words")
set(edge_soc_c_lsu_recursive_bench_src "${STAREDGE_ROOT}/tests/software/bench/lsu_recursive_bench.cpp")
set(edge_soc_c_lsu_recursive_bench_dir "${edge_soc_software_build_dir}/lsu_recursive_bench")
set(edge_soc_c_lsu_recursive_bench_memh "${edge_soc_c_lsu_recursive_bench_dir}/lsu_recursive_bench.memh")
set(edge_soc_c_lsu_recursive_bench_dump "${edge_soc_c_lsu_recursive_bench_dir}/lsu_recursive_bench.dump")
set(edge_soc_c_lsu_recursive_bench_words "${edge_soc_c_lsu_recursive_bench_dir}/lsu_recursive_bench.words")
set(edge_soc_c_coremark_bench_src "${STAREDGE_ROOT}/tests/software/bench/coremark_bench.c")
set(edge_soc_c_coremark_bench_dir "${edge_soc_software_build_dir}/coremark_bench")
set(edge_soc_c_coremark_bench_memh "${edge_soc_c_coremark_bench_dir}/coremark_bench.memh")
set(edge_soc_c_coremark_bench_dump "${edge_soc_c_coremark_bench_dir}/coremark_bench.dump")
set(edge_soc_c_coremark_bench_words "${edge_soc_c_coremark_bench_dir}/coremark_bench.words")
set(edge_soc_c_dcache_hit_under_miss_bench_src "${STAREDGE_ROOT}/tests/software/bench/dcache_hit_under_miss_bench.cpp")
set(edge_soc_c_dcache_hit_under_miss_bench_dir "${edge_soc_software_build_dir}/dcache_hit_under_miss_bench")
set(edge_soc_c_dcache_hit_under_miss_bench_memh "${edge_soc_c_dcache_hit_under_miss_bench_dir}/dcache_hit_under_miss_bench.memh")
set(edge_soc_c_dcache_hit_under_miss_bench_dump "${edge_soc_c_dcache_hit_under_miss_bench_dir}/dcache_hit_under_miss_bench.dump")
set(edge_soc_c_dcache_hit_under_miss_bench_words "${edge_soc_c_dcache_hit_under_miss_bench_dir}/dcache_hit_under_miss_bench.words")
set(edge_soc_c_accelerator_decision_tree_bench_src "${STAREDGE_ROOT}/tests/software/bench/accelerator_decision_tree_bench.cpp")
set(edge_soc_c_accelerator_decision_tree_bench_dir "${edge_soc_software_build_dir}/accelerator_decision_tree_bench")
set(edge_soc_c_accelerator_decision_tree_bench_memh "${edge_soc_c_accelerator_decision_tree_bench_dir}/accelerator_decision_tree_bench.memh")
set(edge_soc_c_accelerator_decision_tree_bench_dump "${edge_soc_c_accelerator_decision_tree_bench_dir}/accelerator_decision_tree_bench.dump")
set(edge_soc_c_accelerator_decision_tree_bench_words "${edge_soc_c_accelerator_decision_tree_bench_dir}/accelerator_decision_tree_bench.words")
set(edge_soc_c_nelder_mead_dispatch_bench_src "${STAREDGE_ROOT}/tests/software/bench/nelder_mead_dispatch_bench.cpp")
set(edge_soc_c_nelder_mead_dispatch_bench_dir "${edge_soc_software_build_dir}/nelder_mead_dispatch_bench")
set(edge_soc_c_nelder_mead_dispatch_bench_memh "${edge_soc_c_nelder_mead_dispatch_bench_dir}/nelder_mead_dispatch_bench.memh")
set(edge_soc_c_nelder_mead_dispatch_bench_dump "${edge_soc_c_nelder_mead_dispatch_bench_dir}/nelder_mead_dispatch_bench.dump")
set(edge_soc_c_nelder_mead_dispatch_bench_words "${edge_soc_c_nelder_mead_dispatch_bench_dir}/nelder_mead_dispatch_bench.words")
set(edge_soc_c_nelder_mead_pattern "${edge_soc_c_nelder_mead_dispatch_bench_dir}/nelder_mead_pattern.h")
foreach(edge_bench_name IN ITEMS
    beam_search_dispatch_bench
    branch_bound_pruning_bench
    candidate_topk_bench
    jpeg_block_bench)
  set(edge_soc_c_${edge_bench_name}_src "${STAREDGE_ROOT}/tests/software/bench/${edge_bench_name}.cpp")
  set(edge_soc_c_${edge_bench_name}_dir "${edge_soc_software_build_dir}/${edge_bench_name}")
  set(edge_soc_c_${edge_bench_name}_memh "${edge_soc_software_build_dir}/${edge_bench_name}/${edge_bench_name}.memh")
  set(edge_soc_c_${edge_bench_name}_dump "${edge_soc_software_build_dir}/${edge_bench_name}/${edge_bench_name}.dump")
  set(edge_soc_c_${edge_bench_name}_words "${edge_soc_software_build_dir}/${edge_bench_name}/${edge_bench_name}.words")
endforeach()
set(edge_soc_c_mem_word_smoke_src "${STAREDGE_ROOT}/tools/edge_rom/edge_c_mem_word_smoke.c")
set(edge_soc_c_mem_word_smoke_dir "${edge_soc_software_build_dir}/edge_c_mem_word_smoke")
set(edge_soc_c_mem_word_smoke_memh "${edge_soc_c_mem_word_smoke_dir}/edge_c_mem_word_smoke.memh")
set(edge_soc_c_mem_word_smoke_dump "${edge_soc_c_mem_word_smoke_dir}/edge_c_mem_word_smoke.dump")
set(edge_soc_c_mem_word_smoke_words "${edge_soc_c_mem_word_smoke_dir}/edge_c_mem_word_smoke.words")
set(edge_soc_c_loop_store_cycle_smoke_src "${STAREDGE_ROOT}/tools/edge_rom/edge_c_loop_store_cycle_smoke.c")
set(edge_soc_c_loop_store_cycle_smoke_dir "${edge_soc_software_build_dir}/edge_c_loop_store_cycle_smoke")
set(edge_soc_c_loop_store_cycle_smoke_memh "${edge_soc_c_loop_store_cycle_smoke_dir}/edge_c_loop_store_cycle_smoke.memh")
set(edge_soc_c_loop_store_cycle_smoke_dump "${edge_soc_c_loop_store_cycle_smoke_dir}/edge_c_loop_store_cycle_smoke.dump")
set(edge_soc_c_loop_store_cycle_smoke_words "${edge_soc_c_loop_store_cycle_smoke_dir}/edge_c_loop_store_cycle_smoke.words")
set(edge_soc_imem_smoke_memh_src "${CMAKE_CURRENT_LIST_DIR}/edge_soc_imem_smoke.memh")
set(edge_soc_imem_smoke_memh "${edge_soc_build_dir}/edge_soc_imem_smoke.memh")
set(edge_soc_top_rtl "${STAREDGE_ROOT}/src/soc/logical/common/edge_soc_top.v")
set(edge_axi_interconnect_rtl "${STAREDGE_ROOT}/src/soc/logical/axi/edge_axi_interconnect.v")
set(edge_axi_ram_rtl "${STAREDGE_ROOT}/src/soc/logical/mem/edge_axi_ram.v")
set(edge_axi_err_rtl "${STAREDGE_ROOT}/src/soc/logical/axi/edge_axi_err.v")
set(edge_core_top_rtl "${STAREDGE_ROOT}/src/edge-e3/edge_core/edge_core_top.v")
set(edge_core_debug_rtl "${STAREDGE_ROOT}/src/edge-e3/edge_core/rtl/edge_core_debug.v")
set(edge_biu_top_rtl "${STAREDGE_ROOT}/src/edge-e3/edge_biu/edge_biu_top.v")
set(edge_dtcm_subsys_rtl "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_subsys/edge_dtcm_subsys.v")
set(edge_soc_top_biu_smoke_tb "${CMAKE_CURRENT_LIST_DIR}/edge_soc_top_biu_smoke_tb.v")
set(edge_soc_top_imem_smoke_tb "${CMAKE_CURRENT_LIST_DIR}/edge_soc_top_imem_smoke_tb.v")
set(edge_axi_ram_burst_tb "${CMAKE_CURRENT_LIST_DIR}/edge_axi_ram_burst_tb.v")
set(edge_soc_vvp_tb "${CMAKE_CURRENT_LIST_DIR}/edge_soc_vvp_tb.v")
set(edge_scalar_fast_alu_rtl "${STAREDGE_ROOT}/src/edge-e3/edge_scalar_fast_alu/edge_scalar_fast_alu.v")
set(edge_scalar_branch_rtl "${STAREDGE_ROOT}/src/edge-e3/edge_scalar_branch/edge_scalar_branch.v")
set(edge_scalar_muldiv_rtl "${STAREDGE_ROOT}/src/edge-e3/edge_scalar_muldiv/edge_scalar_muldiv.v")
set(edge_scalar_divrem_rtl "${STAREDGE_ROOT}/src/edge-e3/edge_scalar_divrem/edge_scalar_divrem.v")
set(edge_fpu_fmac_rtl_dir "${STAREDGE_ROOT}/src/edge-e3/edge_fpu_fmac/rtl")
set(edge_fpu_fmac_rtl "${STAREDGE_ROOT}/src/edge-e3/edge_fpu_fmac/edge_fpu_fmac.v")
set(edge_soc_scalar_alu_rtl_deps
  "${edge_scalar_fast_alu_rtl}"
  "${edge_scalar_branch_rtl}"
  "${edge_scalar_muldiv_rtl}"
  "${edge_scalar_divrem_rtl}"
)
set(edge_soc_fpu_fmac_rtl_deps
  "${STAREDGE_ROOT}/src/edge-e3/edge_fpu_misc/edge_fpu_misc.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_fpu_cvt/edge_fpu_cvt.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_fpu_complete_queue/edge_fpu_complete_queue.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_fpu_slow/edge_fpu_slow.v"
  "${edge_fpu_fmac_rtl_dir}/edge_fpu_fmac_align_add.v"
  "${edge_fpu_fmac_rtl_dir}/edge_fpu_fmac_narrow_fmadd.v"
  "${edge_fpu_fmac_rtl_dir}/edge_fpu_fmac_fp32_round_pack.v"
  "${edge_fpu_fmac_rtl_dir}/edge_fpu_fmac_narrow_shift_sticky_2stage.v"
  "${edge_fpu_fmac_rtl_dir}/edge_fpu_fmac_fp32_unpack.v"
  "${edge_fpu_fmac_rtl_dir}/edge_fpu_fmac_fp32_fused_round_pack.v"
  "${edge_fpu_fmac_rtl}"
)
set(edge_soc_core_rtl_deps
  "${STAREDGE_ROOT}/src/edge-e3/edge_ifu_fetch/edge_ifu_fetch.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_ifu_icache/edge_ifu_icache.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_ifu_icache/rtl/edge_ifu_icache_data_array.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_ifu_icache/rtl/edge_ifu_icache_tag_array.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_fetch_packet_fifo/edge_fetch_packet_fifo.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_ifu_predecode_frontend/edge_ifu_predecode_frontend.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_predecoder/rtl/edge_predecode_token_packer.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_predecoder/rtl/edge_predecode_issue_window.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_predecoder/edge_predecoder.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_scalar_idu_shim/edge_scalar_idu_shim.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_scalar_pipe/edge_scalar_pipe.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_scalar_snapshot/edge_scalar_snapshot.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_scalar_snapshot/edge_reverse_snapshot.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_scalar_alu/edge_scalar_alu.v"
  ${edge_soc_scalar_alu_rtl_deps}
  ${edge_soc_fpu_fmac_rtl_deps}
  "${STAREDGE_ROOT}/src/edge-e3/edge_scalar_csr_sys/edge_scalar_csr_sys.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_wbt/edge_wbt.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_lsu/edge_lsu_top.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_lsu/rtl/edge_load_queue.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_lsu/rtl/edge_load_request_fifo.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_lsu/rtl/edge_store_buffer.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_scalar_lsu/edge_scalar_lsu.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_lsu_mem_selector/edge_lsu_mem_selector.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dcache/edge_dcache.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dcache/rtl/edge_dcache_mshr.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dcache/rtl/edge_dcache_hit_queue.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dcache/rtl/edge_dcache_lookup_buffer.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dcache/rtl/edge_dcache_registered_lookup_buffer.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dcache/rtl/edge_dcache_lookup_scheduler.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dcache/rtl/edge_dcache_pair_predictor.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dcache/rtl/edge_dcache_banked_data_array.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dcache/rtl/edge_dcache_tag_array.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dcache/rtl/edge_dcache_dirty_array.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_accel_cmd_queue/edge_accel_cmd_queue.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_accel_pipe/edge_accel_pipe.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_tensor_unit/edge_tensor_unit.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_tensor_unit/rtl/edge_tensor8x8_bank16.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_tensor_unit/rtl/edge_tensor_unit_bank16.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_tensor_unit/rtl/edge_tensor_iopsum_remux.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_tensor_unit/rtl/edge_tensor_wld_reg.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_tensor_unit/rtl/edge_tensor_wld8x8_fill.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_tensor_unit/rtl/edge_bf16_int8_dot8.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_tensor_unit/rtl/edge_bf16_add_comb.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_tensor_unit/rtl/edge_bf16_int8_dot8x8_psum.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_retire_sync/edge_retire_sync.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_pc_redirect_ctrl/edge_pc_redirect_ctrl.v"
)
set(edge_soc_dtcm_rtl_deps
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_subsys/rtl/fpga_ram.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_subsys/rtl/edge_f_spsram_1024x64.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_subsys/rtl/edge_spsram_1024x64.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_subsys/rtl/edge_dtcm_spsram_1024x64.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_subsys/rtl/edge_dtcm_bank_arb.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_subsys/rtl/edge_dtcm_bank_pair_local_arb.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_subsys/rtl/edge_dtcm_bank_pair_slice.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_subsys/rtl/edge_dtcm_bank16_raw_fabric.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_subsys/rtl/edge_dtcm_other_bank16_adapter.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_subsys/rtl/edge_actu_dtcm_bank16_adapter.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_subsys/rtl/edge_dtcm_arb.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_dma/edge_dtcm_dma.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_dma/edge_dma_read_fifo.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_dma/edge_dma_a2d_stream.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_dtcm_subsys/rtl/edge_dtcm_subsys_core.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_bf16_stream.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_accel_io/edge_accel_io_unit.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_accel_io/edge_accel_unit.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_accel_io/edge_accel_io.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_accel_io/edge_accel_core_mux.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_cmpu/edge_cmpu.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_cmpu/rtl/edge_cmpu_bf16_relation.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_actu/edge_actu.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_exp_lut2base_split.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_exp_range_q16.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_exp2_split_core.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_exp2_split_mant_q14.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_exp2_pack_q28_fp32.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_exp2_pack_fp32.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_rcp_lut_nr_fp32.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_rcp_one_to_two_q16.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_rcp_radix16_seed.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_rcp_rsqrt_seed_q16.v"
  "${STAREDGE_ROOT}/src/edge-e3/edge_actu/rtl/edge_actu_rcp_rsqrt_pipe.v"
)

add_custom_command(
  OUTPUT "${edge_soc_imem_smoke_memh}"
  COMMAND "${CMAKE_COMMAND}" -E make_directory "${edge_soc_build_dir}"
  COMMAND "${CMAKE_COMMAND}" -E copy_if_different
    "$<SHELL_PATH:${edge_soc_imem_smoke_memh_src}>"
    "$<SHELL_PATH:${edge_soc_imem_smoke_memh}>"
  DEPENDS "${edge_soc_imem_smoke_memh_src}"
  VERBATIM
)
add_custom_target(edge_soc_top_imem_smoke_memh DEPENDS "${edge_soc_imem_smoke_memh}")

add_custom_command(
  OUTPUT "${edge_soc_vvp_smoke_memh}" "${edge_soc_vvp_smoke_words}"
  COMMAND "${CMAKE_COMMAND}" -E make_directory "${edge_soc_build_dir}"
  COMMAND "${CMAKE_COMMAND}" -E copy_if_different
    "$<SHELL_PATH:${edge_soc_vvp_smoke_memh_src}>"
    "$<SHELL_PATH:${edge_soc_vvp_smoke_memh}>"
  COMMAND "${CMAKE_COMMAND}" -E copy_if_different
    "$<SHELL_PATH:${edge_soc_vvp_smoke_words_src}>"
    "$<SHELL_PATH:${edge_soc_vvp_smoke_words}>"
  DEPENDS
    "${edge_soc_vvp_smoke_memh_src}"
    "${edge_soc_vvp_smoke_words_src}"
  VERBATIM
)
add_custom_target(edge_soc_vvp_inputs DEPENDS
  "${edge_soc_vvp_smoke_memh}"
  "${edge_soc_vvp_smoke_words}"
)

if(STAREDGE_VERILATOR)
  set(edge_soc_verilator_sources
    "${edge_soc_vvp_tb}"
    "${edge_soc_top_rtl}"
    "${edge_axi_interconnect_rtl}"
    "${edge_axi_ram_rtl}"
    "${edge_axi_err_rtl}"
    "${edge_core_top_rtl}"
    "${edge_core_debug_rtl}"
    "${edge_biu_top_rtl}"
    "${edge_dtcm_subsys_rtl}"
    ${edge_soc_core_rtl_deps}
    ${edge_soc_dtcm_rtl_deps}
  )

  set(edge_soc_biu_smoke_verilator_sources
    "${edge_soc_top_biu_smoke_tb}"
    "${edge_soc_top_rtl}"
    "${edge_axi_interconnect_rtl}"
    "${edge_axi_ram_rtl}"
    "${edge_axi_err_rtl}"
    "${edge_core_top_rtl}"
    "${edge_core_debug_rtl}"
    "${edge_biu_top_rtl}"
    "${edge_dtcm_subsys_rtl}"
    ${edge_soc_core_rtl_deps}
    ${edge_soc_dtcm_rtl_deps}
  )

  staredge_add_verilator_hardware_test(
    NAME edge_soc_top_biu_smoke
    TOP edge_soc_top_biu_smoke_tb
    WORK_DIR "${edge_soc_build_dir}"
    PASS_PATTERN "EDGE_SOC_TOP_BIU_SMOKE TEST PASS"
    LABELS "edge_soc;biu"
    DEFINES
      EDGE_DEBUG
    VERILATOR_ARGS --converge-limit 100000
    SOURCES ${edge_soc_biu_smoke_verilator_sources}
  )

  set(edge_soc_imem_smoke_verilator_sources
    "${edge_soc_top_imem_smoke_tb}"
    "${edge_soc_top_rtl}"
    "${edge_axi_interconnect_rtl}"
    "${edge_axi_ram_rtl}"
    "${edge_axi_err_rtl}"
    "${edge_core_top_rtl}"
    "${edge_core_debug_rtl}"
    "${edge_biu_top_rtl}"
    "${edge_dtcm_subsys_rtl}"
    ${edge_soc_core_rtl_deps}
    ${edge_soc_dtcm_rtl_deps}
  )

  staredge_add_verilator_hardware_test(
    NAME edge_soc_top_imem_smoke
    TOP edge_soc_top_imem_smoke_tb
    WORK_DIR "${edge_soc_build_dir}"
    PASS_PATTERN "EDGE_SOC_TOP_IMEM_SMOKE TEST PASS"
    LABELS "edge_soc;imem"
    DEFINES
      EDGE_DEBUG
    VERILATOR_ARGS --converge-limit 100000
    ARGS
      "+mem128=${edge_soc_imem_smoke_memh_src}"
      "+mem128_words=1"
    SOURCES ${edge_soc_imem_smoke_verilator_sources}
  )

  staredge_add_verilator_hardware_test(
    NAME edge_axi_ram_burst
    TOP edge_axi_ram_burst_tb
    WORK_DIR "${edge_soc_build_dir}"
    PASS_PATTERN "EDGE_AXI_RAM_BURST TEST PASS"
    LABELS "edge_soc;axi;mem"
    SOURCES
      "${edge_axi_ram_burst_tb}"
      "${edge_axi_ram_rtl}"
  )

  function(edge_soc_define_verilator_target variant_name out_target_var out_exe_var)
    set(edge_soc_variant_defines EDGE_DEBUG EDGE_SCALAR_PIPE_EBREAK_REPORT_ONLY)
    if(STAREDGE_DISABLE_SCALAR_ISSUE1)
      list(APPEND edge_soc_variant_defines EDGE_DISABLE_SCALAR_ISSUE1)
    endif()
    if(STAREDGE_DISABLE_SCALAR_M_FAST_PAIR)
      list(APPEND edge_soc_variant_defines EDGE_DISABLE_SCALAR_M_FAST_PAIR)
    endif()
    if(STAREDGE_ENABLE_EARLY_LOAD_RETIRE)
      list(APPEND edge_soc_variant_defines EDGE_ENABLE_EARLY_LOAD_RETIRE)
    endif()
    list(APPEND edge_soc_variant_defines
      "EDGE_SCALAR_LSU_QUEUE_DEPTH=${STAREDGE_SCALAR_LSU_QUEUE_DEPTH}"
      "EDGE_SCALAR_LOAD_QUEUE_DEPTH=${STAREDGE_SCALAR_LOAD_QUEUE_DEPTH}")
    list(APPEND edge_soc_variant_defines ${ARGN})
    staredge_add_verilator_binary(
      NAME "${variant_name}"
      TARGET "${variant_name}"
      TOP edge_soc_vvp_tb
      WORK_DIR "${edge_soc_build_dir}"
      DEFINES ${edge_soc_variant_defines}
      VERILATOR_ARGS --converge-limit 100000
      SOURCES ${edge_soc_verilator_sources}
    )
    set(${out_target_var} "${STAREDGE_VERILATOR_BINARY_TARGET}" PARENT_SCOPE)
    set(${out_exe_var} "${STAREDGE_VERILATOR_BINARY_EXE}" PARENT_SCOPE)
  endfunction()

  edge_soc_define_verilator_target(edge_soc_verilator_bin edge_soc_verilator_target edge_soc_verilator_exe)
  edge_soc_define_verilator_target(
    edge_soc_registered_lookup_verilator_bin
    edge_soc_registered_lookup_verilator_target
    edge_soc_registered_lookup_verilator_exe
    EDGE_DCACHE_REGISTERED_LOOKUP)
  edge_soc_define_verilator_target(
    edge_soc_hybrid_lookup_verilator_bin
    edge_soc_hybrid_lookup_verilator_target
    edge_soc_hybrid_lookup_verilator_exe
    EDGE_DCACHE_REGISTERED_LOOKUP EDGE_DCACHE_HYBRID_LOOKUP)

  add_custom_target(edge_soc_verilator DEPENDS
    "${edge_soc_verilator_exe}"
    "${edge_soc_vvp_smoke_memh}"
    "${edge_soc_vvp_smoke_words}"
  )
  add_custom_target(edge_soc_registered_lookup_verilator DEPENDS
    "${edge_soc_registered_lookup_verilator_exe}"
    "${edge_soc_vvp_smoke_memh}"
    "${edge_soc_vvp_smoke_words}"
  )
  add_custom_target(edge_soc_hybrid_lookup_verilator DEPENDS
    "${edge_soc_hybrid_lookup_verilator_exe}"
    "${edge_soc_vvp_smoke_memh}"
    "${edge_soc_vvp_smoke_words}"
  )
endif()

function(edge_soc_add_asm_case target_name source_path output_name obj_path elf_path objdump_path memh_path words_path)
  add_custom_command(
    OUTPUT "${obj_path}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${edge_soc_software_build_dir}"
    COMMAND "${STAREDGE_CLANG}"
      --target=${STAREDGE_RISCV_TARGET}
      -march=${STAREDGE_EDGE_ROM_MARCH}
      -mabi=${STAREDGE_EDGE_ROM_ABI}
      -mcmodel=medany
      -x assembler-with-cpp
      -c "$<SHELL_PATH:${source_path}>"
      -o "$<SHELL_PATH:${obj_path}>"
    DEPENDS "${source_path}"
    VERBATIM
  )

  add_custom_command(
    OUTPUT "${elf_path}"
    COMMAND "${STAREDGE_CLANG}"
      --target=${STAREDGE_RISCV_TARGET}
      -march=${STAREDGE_EDGE_ROM_MARCH}
      -mabi=${STAREDGE_EDGE_ROM_ABI}
      -mcmodel=medany
      -fuse-ld=lld
      -B$<SHELL_PATH:${STAREDGE_LLD_PREFIX}/bin>
      -nostdlib
      -nostartfiles
      -Wl,--image-base=0
      -Wl,-Ttext=0
      -Wl,-e,_start
      -Wl,--defsym=__edge_dtcm_base=0x40000000
      -Wl,--defsym=__edge_dtcm_size=0x20000
      -Wl,--defsym=__edge_dtcm_mask=0xfffffe0000
      -Wl,-Map,$<SHELL_PATH:${edge_soc_software_build_dir}/${output_name}.map>
      "$<SHELL_PATH:${obj_path}>"
      -o "$<SHELL_PATH:${elf_path}>"
    DEPENDS "${obj_path}"
    VERBATIM
  )

  add_custom_command(
    OUTPUT "${objdump_path}" "${memh_path}" "${words_path}"
    COMMAND "${STAREDGE_LLVM_OBJDUMP}" -d --no-show-raw-insn "$<SHELL_PATH:${elf_path}>" > "${objdump_path}"
    COMMAND "${Python3_EXECUTABLE}" "$<SHELL_PATH:${STAREDGE_ROOT}/tools/elf2mem128.py>" "$<SHELL_PATH:${elf_path}>" -o "$<SHELL_PATH:${memh_path}>" --words-file "$<SHELL_PATH:${words_path}>"
    DEPENDS "${elf_path}" "${STAREDGE_ROOT}/tools/elf2mem128.py"
    VERBATIM
  )

  add_custom_target("${target_name}" DEPENDS "${objdump_path}" "${memh_path}" "${words_path}")
endfunction()

set(edge_soc_cpp_crt0_src "${STAREDGE_ROOT}/tools/edge_rom/rv64im_cpp_crt0.s")
set(edge_soc_cpp_crt0_obj "${edge_soc_software_build_dir}/rv64im_cpp_crt0.o")
add_custom_command(
  OUTPUT "${edge_soc_cpp_crt0_obj}"
  COMMAND "${CMAKE_COMMAND}" -E make_directory "${edge_soc_software_build_dir}"
  COMMAND "${STAREDGE_CLANG}"
    --target=${STAREDGE_RISCV_TARGET}
    -march=${STAREDGE_EDGE_ROM_MARCH}
    -mabi=${STAREDGE_EDGE_ROM_ABI}
    -mcmodel=medany
    -c "$<SHELL_PATH:${edge_soc_cpp_crt0_src}>"
    -o "$<SHELL_PATH:${edge_soc_cpp_crt0_obj}>"
  DEPENDS "${edge_soc_cpp_crt0_src}"
  VERBATIM
)

function(edge_soc_add_cpp_case target_name source_path output_name include_header obj_path elf_path objdump_path memh_path words_path)
  add_custom_command(
    OUTPUT "${obj_path}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${edge_soc_software_build_dir}"
    COMMAND "${STAREDGE_CLANG}"
      --target=${STAREDGE_RISCV_TARGET}
      -march=${STAREDGE_EDGE_ROM_MARCH}
      -mabi=${STAREDGE_EDGE_ROM_ABI}
      -mcmodel=medany
      -x c++
      -std=c++17
      -ffreestanding
      -fno-builtin
      -fno-exceptions
      -fno-rtti
      -fno-pic
      -fno-pie
      -O2
      -I$<SHELL_PATH:${STAREDGE_ROOT}/tests/software/include>
      -I$<SHELL_PATH:${edge_soc_software_build_dir}>
      -c "$<SHELL_PATH:${source_path}>"
      -o "$<SHELL_PATH:${obj_path}>"
    DEPENDS "${source_path}" "${include_header}"
    VERBATIM
  )

  add_custom_command(
    OUTPUT "${elf_path}"
    COMMAND "${STAREDGE_CLANG}"
      --target=${STAREDGE_RISCV_TARGET}
      -march=${STAREDGE_EDGE_ROM_MARCH}
      -mabi=${STAREDGE_EDGE_ROM_ABI}
      -mcmodel=medany
      -fuse-ld=lld
      -B$<SHELL_PATH:${STAREDGE_LLD_PREFIX}/bin>
      -nostdlib
      -nostartfiles
      -Wl,--image-base=0
      -Wl,-Ttext=0
      -Wl,-e,_start
      -Wl,--defsym=__edge_dtcm_base=0x40000000
      -Wl,--defsym=__edge_dtcm_size=0x20000
      -Wl,--defsym=__edge_dtcm_mask=0xfffffe0000
      -Wl,-Map,$<SHELL_PATH:${edge_soc_software_build_dir}/${output_name}.map>
      "$<SHELL_PATH:${edge_soc_cpp_crt0_obj}>"
      ${ARGN}
      "$<SHELL_PATH:${obj_path}>"
      -o "$<SHELL_PATH:${elf_path}>"
    DEPENDS "${obj_path}" "${edge_soc_cpp_crt0_obj}"
    VERBATIM
  )

  add_custom_command(
    OUTPUT "${objdump_path}" "${memh_path}" "${words_path}"
    COMMAND "${STAREDGE_LLVM_OBJDUMP}" -d --no-show-raw-insn "$<SHELL_PATH:${elf_path}>" > "${objdump_path}"
    COMMAND "${Python3_EXECUTABLE}" "$<SHELL_PATH:${STAREDGE_ROOT}/tools/elf2mem128.py>" "$<SHELL_PATH:${elf_path}>" -o "$<SHELL_PATH:${memh_path}>" --words-file "$<SHELL_PATH:${words_path}>"
    DEPENDS "${elf_path}" "${STAREDGE_ROOT}/tools/elf2mem128.py"
    VERBATIM
  )

  add_custom_target("${target_name}" DEPENDS "${objdump_path}" "${memh_path}" "${words_path}")
endfunction()

edge_soc_add_asm_case(
  edge_soc_software_rv64i_smoke
  "${edge_rv64i_smoke_src}"
  EDGE_RV64I_SMOKE
  "${edge_rv64i_smoke_obj}"
  "${edge_rv64i_smoke_elf}"
  "${edge_rv64i_smoke_objdump}"
  "${edge_rv64i_smoke_memh}"
  "${edge_rv64i_smoke_words}"
)

edge_soc_add_asm_case(
  edge_soc_software_delayed_load_ret
  "${edge_delayed_load_ret_src}"
  EDGE_DELAYED_LOAD_RET
  "${edge_delayed_load_ret_obj}"
  "${edge_delayed_load_ret_elf}"
  "${edge_delayed_load_ret_objdump}"
  "${edge_delayed_load_ret_memh}"
  "${edge_delayed_load_ret_words}"
)

edge_soc_add_asm_case(
  edge_soc_software_dtcm_smoke
  "${edge_dtcm_smoke_src}"
  EDGE_DTCM_SMOKE
  "${edge_dtcm_smoke_obj}"
  "${edge_dtcm_smoke_elf}"
  "${edge_dtcm_smoke_objdump}"
  "${edge_dtcm_smoke_memh}"
  "${edge_dtcm_smoke_words}"
)

edge_soc_add_asm_case(
  edge_soc_software_dma_smoke
  "${edge_dma_smoke_src}"
  EDGE_DMA_SMOKE
  "${edge_dma_smoke_obj}"
  "${edge_dma_smoke_elf}"
  "${edge_dma_smoke_objdump}"
  "${edge_dma_smoke_memh}"
  "${edge_dma_smoke_words}"
)

edge_soc_add_asm_case(
  edge_soc_software_cache_smoke
  "${edge_cache_smoke_src}"
  EDGE_CACHE_SMOKE
  "${edge_cache_smoke_obj}"
  "${edge_cache_smoke_elf}"
  "${edge_cache_smoke_objdump}"
  "${edge_cache_smoke_memh}"
  "${edge_cache_smoke_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_dcache_victim
  "${edge_dcache_victim_src}"
  EDGE_DCACHE_VICTIM
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_dcache_victim_obj}"
  "${edge_dcache_victim_elf}"
  "${edge_dcache_victim_objdump}"
  "${edge_dcache_victim_memh}"
  "${edge_dcache_victim_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_lsu_mixed
  "${edge_lsu_mixed_src}"
  EDGE_LSU_MIXED
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_lsu_mixed_obj}"
  "${edge_lsu_mixed_elf}"
  "${edge_lsu_mixed_objdump}"
  "${edge_lsu_mixed_memh}"
  "${edge_lsu_mixed_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_dma_cpp_smoke
  "${edge_dma_cpp_smoke_src}"
  EDGE_DMA_CPP_SMOKE
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_dma_cpp_smoke_obj}"
  "${edge_dma_cpp_smoke_elf}"
  "${edge_dma_cpp_smoke_objdump}"
  "${edge_dma_cpp_smoke_memh}"
  "${edge_dma_cpp_smoke_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_dma_simple
  "${edge_dma_simple_src}"
  EDGE_DMA_SIMPLE
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_dma_simple_obj}"
  "${edge_dma_simple_elf}"
  "${edge_dma_simple_objdump}"
  "${edge_dma_simple_memh}"
  "${edge_dma_simple_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_dma_dtcm_to_dram
  "${edge_dma_dtcm_to_dram_src}"
  EDGE_DMA_DTCM_TO_DRAM
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_dma_dtcm_to_dram_obj}"
  "${edge_dma_dtcm_to_dram_elf}"
  "${edge_dma_dtcm_to_dram_objdump}"
  "${edge_dma_dtcm_to_dram_memh}"
  "${edge_dma_dtcm_to_dram_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_dma_burst
  "${edge_dma_burst_src}"
  EDGE_DMA_BURST
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_dma_burst_obj}"
  "${edge_dma_burst_elf}"
  "${edge_dma_burst_objdump}"
  "${edge_dma_burst_memh}"
  "${edge_dma_burst_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_dma_tail
  "${edge_dma_tail_src}"
  EDGE_DMA_TAIL
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_dma_tail_obj}"
  "${edge_dma_tail_elf}"
  "${edge_dma_tail_objdump}"
  "${edge_dma_tail_memh}"
  "${edge_dma_tail_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_dma_ordering
  "${edge_dma_ordering_src}"
  EDGE_DMA_ORDERING
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_dma_ordering_obj}"
  "${edge_dma_ordering_elf}"
  "${edge_dma_ordering_objdump}"
  "${edge_dma_ordering_memh}"
  "${edge_dma_ordering_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_control
  "${edge_tensor_control_src}"
  EDGE_TENSOR_CONTROL
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_control_obj}"
  "${edge_tensor_control_elf}"
  "${edge_tensor_control_objdump}"
  "${edge_tensor_control_memh}"
  "${edge_tensor_control_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_actu_smoke
  "${edge_actu_smoke_src}"
  EDGE_ACTU_SMOKE
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_actu_smoke_obj}"
  "${edge_actu_smoke_elf}"
  "${edge_actu_smoke_objdump}"
  "${edge_actu_smoke_memh}"
  "${edge_actu_smoke_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_actu_silu_bench
  "${edge_actu_silu_bench_src}"
  EDGE_ACTU_SILU_BENCH
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_actu_silu_bench_obj}"
  "${edge_actu_silu_bench_elf}"
  "${edge_actu_silu_bench_objdump}"
  "${edge_actu_silu_bench_memh}"
  "${edge_actu_silu_bench_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_cmpu_smoke
  "${edge_cmpu_smoke_src}"
  EDGE_CMPU_SMOKE
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_cmpu_smoke_obj}"
  "${edge_cmpu_smoke_elf}"
  "${edge_cmpu_smoke_objdump}"
  "${edge_cmpu_smoke_memh}"
  "${edge_cmpu_smoke_words}"
)

add_custom_command(
  OUTPUT "${edge_actu_pygen_header}" "${edge_actu_pygen_expected}"
  COMMAND "${Python3_EXECUTABLE}"
    "$<SHELL_PATH:${edge_actu_pygen_script}>"
    --repo-root "$<SHELL_PATH:${STAREDGE_ROOT}>"
    --generate
    --header "$<SHELL_PATH:${edge_actu_pygen_header}>"
    --expected-json "$<SHELL_PATH:${edge_actu_pygen_expected}>"
  DEPENDS
    "${edge_actu_pygen_script}"
    "${STAREDGE_ROOT}/tools/actu/activation_asic_model.py"
  VERBATIM
)

edge_soc_add_cpp_case(
  edge_soc_software_actu_pygen
  "${edge_actu_pygen_src}"
  EDGE_ACTU_PYGEN
  "${edge_actu_pygen_header}"
  "${edge_actu_pygen_obj}"
  "${edge_actu_pygen_elf}"
  "${edge_actu_pygen_objdump}"
  "${edge_actu_pygen_memh}"
  "${edge_actu_pygen_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_matvec64_1token_tiled
  "${edge_tensor_matvec64_1token_tiled_src}"
  EDGE_TENSOR_MATVEC64_1TOKEN_TILED
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_matvec64_1token_tiled_obj}"
  "${edge_tensor_matvec64_1token_tiled_elf}"
  "${edge_tensor_matvec64_1token_tiled_objdump}"
  "${edge_tensor_matvec64_1token_tiled_memh}"
  "${edge_tensor_matvec64_1token_tiled_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_tile8x8_stream64tokens
  "${edge_tensor_tile8x8_stream64tokens_src}"
  EDGE_TENSOR_TILE8X8_STREAM64TOKENS
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_tile8x8_stream64tokens_obj}"
  "${edge_tensor_tile8x8_stream64tokens_elf}"
  "${edge_tensor_tile8x8_stream64tokens_objdump}"
  "${edge_tensor_tile8x8_stream64tokens_memh}"
  "${edge_tensor_tile8x8_stream64tokens_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_bf16_wld_direct_circular
  "${edge_tensor_bf16_wld_direct_circular_src}"
  EDGE_TENSOR_BF16_WLD_DIRECT_CIRCULAR
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_bf16_wld_direct_circular_obj}"
  "${edge_tensor_bf16_wld_direct_circular_elf}"
  "${edge_tensor_bf16_wld_direct_circular_objdump}"
  "${edge_tensor_bf16_wld_direct_circular_memh}"
  "${edge_tensor_bf16_wld_direct_circular_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_bf16_matmul8x8
  "${edge_tensor_bf16_matmul8x8_src}"
  EDGE_TENSOR_BF16_MATMUL8X8
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_bf16_matmul8x8_obj}"
  "${edge_tensor_bf16_matmul8x8_elf}"
  "${edge_tensor_bf16_matmul8x8_objdump}"
  "${edge_tensor_bf16_matmul8x8_memh}"
  "${edge_tensor_bf16_matmul8x8_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_reuse_weight_pending
  "${edge_tensor_reuse_weight_pending_src}"
  EDGE_TENSOR_REUSE_WEIGHT_PENDING
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_reuse_weight_pending_obj}"
  "${edge_tensor_reuse_weight_pending_elf}"
  "${edge_tensor_reuse_weight_pending_objdump}"
  "${edge_tensor_reuse_weight_pending_memh}"
  "${edge_tensor_reuse_weight_pending_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_start_tile_reuse_debug
  "${edge_tensor_start_tile_reuse_debug_src}"
  EDGE_TENSOR_START_TILE_REUSE_DEBUG
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_start_tile_reuse_debug_obj}"
  "${edge_tensor_start_tile_reuse_debug_elf}"
  "${edge_tensor_start_tile_reuse_debug_objdump}"
  "${edge_tensor_start_tile_reuse_debug_memh}"
  "${edge_tensor_start_tile_reuse_debug_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_start_overlap_setn1
  "${edge_tensor_start_overlap_setn1_src}"
  EDGE_TENSOR_START_OVERLAP_SETN1
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_start_overlap_setn1_obj}"
  "${edge_tensor_start_overlap_setn1_elf}"
  "${edge_tensor_start_overlap_setn1_objdump}"
  "${edge_tensor_start_overlap_setn1_memh}"
  "${edge_tensor_start_overlap_setn1_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_attention_score64_8x8_tiles
  "${edge_tensor_attention_score64_8x8_tiles_src}"
  EDGE_TENSOR_ATTENTION_SCORE64_8X8_TILES
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_attention_score64_8x8_tiles_obj}"
  "${edge_tensor_attention_score64_8x8_tiles_elf}"
  "${edge_tensor_attention_score64_8x8_tiles_objdump}"
  "${edge_tensor_attention_score64_8x8_tiles_memh}"
  "${edge_tensor_attention_score64_8x8_tiles_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_attention_value64_8x8_tiles
  "${edge_tensor_attention_value64_8x8_tiles_src}"
  EDGE_TENSOR_ATTENTION_VALUE64_8X8_TILES
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_attention_value64_8x8_tiles_obj}"
  "${edge_tensor_attention_value64_8x8_tiles_elf}"
  "${edge_tensor_attention_value64_8x8_tiles_objdump}"
  "${edge_tensor_attention_value64_8x8_tiles_memh}"
  "${edge_tensor_attention_value64_8x8_tiles_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_matmul64x64_64tokens_tiled
  "${edge_tensor_matmul64x64_64tokens_tiled_src}"
  EDGE_TENSOR_MATMUL64X64_64TOKENS_TILED
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_matmul64x64_64tokens_tiled_obj}"
  "${edge_tensor_matmul64x64_64tokens_tiled_elf}"
  "${edge_tensor_matmul64x64_64tokens_tiled_objdump}"
  "${edge_tensor_matmul64x64_64tokens_tiled_memh}"
  "${edge_tensor_matmul64x64_64tokens_tiled_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_matmul64x64_64tokens_tiled_circular
  "${edge_tensor_matmul64x64_64tokens_tiled_circular_src}"
  EDGE_TENSOR_MATMUL64X64_64TOKENS_TILED_CIRCULAR
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_matmul64x64_64tokens_tiled_circular_obj}"
  "${edge_tensor_matmul64x64_64tokens_tiled_circular_elf}"
  "${edge_tensor_matmul64x64_64tokens_tiled_circular_objdump}"
  "${edge_tensor_matmul64x64_64tokens_tiled_circular_memh}"
  "${edge_tensor_matmul64x64_64tokens_tiled_circular_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_matmul64x64_128tokens_tiled_circular
  "${edge_tensor_matmul64x64_128tokens_tiled_circular_src}"
  EDGE_TENSOR_MATMUL64X64_128TOKENS_TILED_CIRCULAR
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_matmul64x64_128tokens_tiled_circular_obj}"
  "${edge_tensor_matmul64x64_128tokens_tiled_circular_elf}"
  "${edge_tensor_matmul64x64_128tokens_tiled_circular_objdump}"
  "${edge_tensor_matmul64x64_128tokens_tiled_circular_memh}"
  "${edge_tensor_matmul64x64_128tokens_tiled_circular_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_wsld_circular_q8
  "${edge_tensor_wsld_circular_q8_src}"
  EDGE_TENSOR_WSLD_CIRCULAR_Q8
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_wsld_circular_q8_obj}"
  "${edge_tensor_wsld_circular_q8_elf}"
  "${edge_tensor_wsld_circular_q8_objdump}"
  "${edge_tensor_wsld_circular_q8_memh}"
  "${edge_tensor_wsld_circular_q8_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_sld_circular_mul
  "${edge_tensor_sld_circular_mul_src}"
  EDGE_TENSOR_SLD_CIRCULAR_MUL
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_sld_circular_mul_obj}"
  "${edge_tensor_sld_circular_mul_elf}"
  "${edge_tensor_sld_circular_mul_objdump}"
  "${edge_tensor_sld_circular_mul_memh}"
  "${edge_tensor_sld_circular_mul_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_sld_stream_mul
  "${edge_tensor_sld_stream_mul_src}"
  EDGE_TENSOR_SLD_STREAM_MUL
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_sld_stream_mul_obj}"
  "${edge_tensor_sld_stream_mul_elf}"
  "${edge_tensor_sld_stream_mul_objdump}"
  "${edge_tensor_sld_stream_mul_memh}"
  "${edge_tensor_sld_stream_mul_words}"
)

edge_soc_add_cpp_case(
  edge_soc_software_tensor_matmul512x512_32tokens_transpose_circular
  "${edge_tensor_matmul512x512_32tokens_transpose_circular_src}"
  EDGE_TENSOR_MATMUL512X512_32TOKENS_TRANSPOSE_CIRCULAR
  "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  "${edge_tensor_matmul512x512_32tokens_transpose_circular_obj}"
  "${edge_tensor_matmul512x512_32tokens_transpose_circular_elf}"
  "${edge_tensor_matmul512x512_32tokens_transpose_circular_objdump}"
  "${edge_tensor_matmul512x512_32tokens_transpose_circular_memh}"
  "${edge_tensor_matmul512x512_32tokens_transpose_circular_words}"
  -Wl,--section-start=.weight_rom=0x40000
)

function(edge_soc_add_edge_rom_c_case target_name case_name out_dir source_path memh_path dump_path words_path)
  add_custom_command(
    OUTPUT
      "${memh_path}"
      "${dump_path}"
      "${words_path}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${out_dir}"
    COMMAND "${Python3_EXECUTABLE}"
      "$<SHELL_PATH:${STAREDGE_ROOT}/tools/build_riscv_tests_memh.py>"
      --case "${case_name}"
      --build-dir "$<SHELL_PATH:${CMAKE_BINARY_DIR}>"
      --march "${STAREDGE_EDGE_ROM_MARCH}"
      --abi "${STAREDGE_EDGE_ROM_ABI}"
      --out-dir "$<SHELL_PATH:${out_dir}>"
    WORKING_DIRECTORY "${STAREDGE_ROOT}"
    DEPENDS
      "${source_path}"
      "${STAREDGE_ROOT}/tools/build_riscv_tests_memh.py"
      "${STAREDGE_ROOT}/tools/build_rv64im_rom.py"
      "${STAREDGE_ROOT}/tools/elf2mem128.py"
      "${STAREDGE_ROOT}/tools/edge_rom/rv64im_crt0.s"
      "${STAREDGE_ROOT}/tools/edge_rom/rv64im_flat.ld"
    VERBATIM
  )

  add_custom_target("${target_name}" DEPENDS "${memh_path}" "${dump_path}" "${words_path}")
endfunction()

staredge_add_edge_rom_benchmark(
  TARGET edge_soc_software_c_accelerator_decision_tree_bench
  NAME accelerator_decision_tree_bench
  SOURCE "${edge_soc_c_accelerator_decision_tree_bench_src}"
  OUT_DIR "${edge_soc_c_accelerator_decision_tree_bench_dir}"
  MEMH "${edge_soc_c_accelerator_decision_tree_bench_memh}"
  DUMP "${edge_soc_c_accelerator_decision_tree_bench_dump}"
  WORDS "${edge_soc_c_accelerator_decision_tree_bench_words}"
  CUSTOM_HEADER "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  PLATFORM_HEADER "${STAREDGE_ROOT}/tests/software/bench/platform.hpp"
)

staredge_add_edge_rom_benchmark(
  TARGET edge_soc_software_c_dcache_hit_under_miss_bench
  NAME dcache_hit_under_miss_bench
  SOURCE "${edge_soc_c_dcache_hit_under_miss_bench_src}"
  OUT_DIR "${edge_soc_c_dcache_hit_under_miss_bench_dir}"
  MEMH "${edge_soc_c_dcache_hit_under_miss_bench_memh}"
  DUMP "${edge_soc_c_dcache_hit_under_miss_bench_dump}"
  WORDS "${edge_soc_c_dcache_hit_under_miss_bench_words}"
  CUSTOM_HEADER "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  PLATFORM_HEADER "${STAREDGE_ROOT}/tests/software/bench/platform.hpp"
)

add_custom_command(
  OUTPUT "${edge_soc_c_nelder_mead_pattern}"
  COMMAND "${CMAKE_COMMAND}" -E make_directory "${edge_soc_c_nelder_mead_dispatch_bench_dir}"
  COMMAND "${Python3_EXECUTABLE}"
    "${STAREDGE_ROOT}/tools/generate_nelder_mead_bench.py"
    --iterations 24
    --output "${edge_soc_c_nelder_mead_pattern}"
  DEPENDS "${STAREDGE_ROOT}/tools/generate_nelder_mead_bench.py"
  VERBATIM)

staredge_add_edge_rom_benchmark(
  TARGET edge_soc_software_c_nelder_mead_dispatch_bench
  NAME nelder_mead_dispatch_bench
  SOURCE "${edge_soc_c_nelder_mead_dispatch_bench_src}"
  OUT_DIR "${edge_soc_c_nelder_mead_dispatch_bench_dir}"
  MEMH "${edge_soc_c_nelder_mead_dispatch_bench_memh}"
  DUMP "${edge_soc_c_nelder_mead_dispatch_bench_dump}"
  WORDS "${edge_soc_c_nelder_mead_dispatch_bench_words}"
  CUSTOM_HEADER "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  PLATFORM_HEADER "${STAREDGE_ROOT}/tests/software/bench/platform.hpp"
  MARCH "rv64imfd_zba"
  ABI "lp64"
  EXTRA_INCLUDE_DIR "${edge_soc_c_nelder_mead_dispatch_bench_dir}"
  EXTRA_DEPENDS "${edge_soc_c_nelder_mead_pattern}"
)

foreach(edge_bench_name IN ITEMS
    beam_search_dispatch_bench
    branch_bound_pruning_bench
    candidate_topk_bench
    jpeg_block_bench)
  staredge_add_edge_rom_benchmark(
    TARGET edge_soc_software_c_${edge_bench_name}
    NAME ${edge_bench_name}
    SOURCE "${edge_soc_c_${edge_bench_name}_src}"
    OUT_DIR "${edge_soc_c_${edge_bench_name}_dir}"
    MEMH "${edge_soc_c_${edge_bench_name}_memh}"
    DUMP "${edge_soc_c_${edge_bench_name}_dump}"
    WORDS "${edge_soc_c_${edge_bench_name}_words}"
    CUSTOM_HEADER "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
    PLATFORM_HEADER "${STAREDGE_ROOT}/tests/software/bench/platform.hpp"
  )
endforeach()

staredge_add_edge_rom_benchmark(
  TARGET edge_soc_software_c_recursive_dp_smoke
  NAME recursive_dp_bench
  SOURCE "${edge_soc_c_recursive_dp_smoke_src}"
  OUT_DIR "${edge_soc_c_recursive_dp_smoke_dir}"
  MEMH "${edge_soc_c_recursive_dp_smoke_memh}"
  DUMP "${edge_soc_c_recursive_dp_smoke_dump}"
  WORDS "${edge_soc_c_recursive_dp_smoke_words}"
  CUSTOM_HEADER "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  PLATFORM_HEADER "${STAREDGE_ROOT}/tests/software/bench/platform.hpp"
)

staredge_add_edge_rom_benchmark(
  TARGET edge_soc_software_c_lsu_recursive_bench
  NAME lsu_recursive_bench
  SOURCE "${edge_soc_c_lsu_recursive_bench_src}"
  OUT_DIR "${edge_soc_c_lsu_recursive_bench_dir}"
  MEMH "${edge_soc_c_lsu_recursive_bench_memh}"
  DUMP "${edge_soc_c_lsu_recursive_bench_dump}"
  WORDS "${edge_soc_c_lsu_recursive_bench_words}"
  CUSTOM_HEADER "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  PLATFORM_HEADER "${STAREDGE_ROOT}/tests/software/bench/platform.hpp"
)

staredge_add_edge_rom_benchmark(
  TARGET edge_soc_software_c_coremark_bench
  NAME coremark_bench
  SOURCE "${edge_soc_c_coremark_bench_src}"
  OUT_DIR "${edge_soc_c_coremark_bench_dir}"
  MEMH "${edge_soc_c_coremark_bench_memh}"
  DUMP "${edge_soc_c_coremark_bench_dump}"
  WORDS "${edge_soc_c_coremark_bench_words}"
  CUSTOM_HEADER "${STAREDGE_ROOT}/tests/software/include/edge_intrinsic.hpp"
  PLATFORM_HEADER "${STAREDGE_ROOT}/tests/software/bench/platform.hpp"
  EXTRA_DEPENDS
    "${STAREDGE_ROOT}/third_party/coremark/core_main.c"
    "${STAREDGE_ROOT}/third_party/coremark/core_list_join.c"
    "${STAREDGE_ROOT}/third_party/coremark/core_matrix.c"
    "${STAREDGE_ROOT}/third_party/coremark/core_state.c"
    "${STAREDGE_ROOT}/third_party/coremark/core_util.c"
    "${STAREDGE_ROOT}/third_party/coremark/core_portme.c"
    "${STAREDGE_ROOT}/third_party/coremark/core_portme.h"
    "${STAREDGE_ROOT}/third_party/coremark/coremark.h"
)

edge_soc_add_edge_rom_c_case(
  edge_soc_software_c_mem_word_smoke
  edge-c-mem-word-smoke
  "${edge_soc_c_mem_word_smoke_dir}"
  "${edge_soc_c_mem_word_smoke_src}"
  "${edge_soc_c_mem_word_smoke_memh}"
  "${edge_soc_c_mem_word_smoke_dump}"
  "${edge_soc_c_mem_word_smoke_words}"
)

edge_soc_add_edge_rom_c_case(
  edge_soc_software_c_loop_store_cycle_smoke
  edge-c-loop-store-cycle-smoke
  "${edge_soc_c_loop_store_cycle_smoke_dir}"
  "${edge_soc_c_loop_store_cycle_smoke_src}"
  "${edge_soc_c_loop_store_cycle_smoke_memh}"
  "${edge_soc_c_loop_store_cycle_smoke_dump}"
  "${edge_soc_c_loop_store_cycle_smoke_words}"
)
