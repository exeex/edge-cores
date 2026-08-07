`timescale 1ns/1ps

module edge_soc_vvp_tb;
  localparam ADDR_WIDTH = 40;
  localparam DATA_WIDTH = 128;
  localparam ID_WIDTH = 8;
  localparam LEN_WIDTH = 8;
  localparam SOC_RAM_ADDR_BITS = 23;
`ifdef EDGE_ENABLE_EARLY_LOAD_RETIRE
  localparam ENABLE_EARLY_LOAD_RETIRE = 1;
`else
  localparam ENABLE_EARLY_LOAD_RETIRE = 0;
`endif
  localparam [6:0] TB_TENSOR_SETIN = 7'h12;
  localparam [6:0] TB_TENSOR_SETOUT = 7'h13;
  localparam [6:0] TB_TENSOR_SETPSUM = 7'h14;
  localparam [6:0] TB_TENSOR_START = 7'h15;
  localparam [6:0] TB_TENSOR_SYNC = 7'h16;
  localparam [6:0] TB_TENSOR_WLD_CIRCULAR = 7'h1b;
  localparam [6:0] TB_TENSOR_WLD_T_CIRCULAR = 7'h1c;
  localparam [6:0] TB_OPCODE_LOAD = 7'b0000011;
  localparam [6:0] TB_OPCODE_STORE = 7'b0100011;
  localparam [6:0] TB_OPCODE_LUI = 7'b0110111;
  localparam [6:0] TB_OPCODE_AUIPC = 7'b0010111;
  localparam [6:0] TB_OPCODE_OP_IMM = 7'b0010011;
  localparam [6:0] TB_OPCODE_OP = 7'b0110011;
  localparam [6:0] TB_OPCODE_OP_IMM32 = 7'b0011011;
  localparam [6:0] TB_OPCODE_OP32 = 7'b0111011;
  localparam [6:0] TB_OPCODE_JAL = 7'b1101111;
  localparam [6:0] TB_OPCODE_JALR = 7'b1100111;
  localparam [6:0] TB_OPCODE_BRANCH = 7'b1100011;
  localparam [6:0] TB_OPCODE_SYSTEM = 7'b1110011;
  localparam [6:0] TB_EDGE64_LENGTH_MARKER = 7'b0111111;
  localparam [2:0] TB_PRODUCER_OTHER = 3'd0;
  localparam [2:0] TB_PRODUCER_ALU = 3'd1;
  localparam [2:0] TB_PRODUCER_LOAD = 3'd2;
  localparam [2:0] TB_PRODUCER_MUL = 3'd3;
  localparam [2:0] TB_PRODUCER_SYSTEM = 3'd4;
  localparam [2:0] TB_M_KIND_OTHER = 3'd0;
  localparam [2:0] TB_M_KIND_MUL64 = 3'd1;
  localparam [2:0] TB_M_KIND_MULH64 = 3'd2;
  localparam [2:0] TB_M_KIND_MULW = 3'd3;
  localparam [2:0] TB_M_KIND_DIV64 = 3'd4;
  localparam [2:0] TB_M_KIND_REM64 = 3'd5;
  localparam [2:0] TB_M_KIND_DIVW = 3'd6;
  localparam [2:0] TB_M_KIND_REMW = 3'd7;

  reg clk;
  reg rst_b;
  reg core_start;
  reg core_force_stop;
  reg [ADDR_WIDTH-1:0] core_boot_pc;
  integer max_cycles;
  integer pass_retire_count;
  integer scalar_lane0_retire_count;
  integer scalar_lane1_retire_count;
  integer accel_lane_retire_count;
  integer min_dtcm_load_count;
  integer min_dtcm_store_count;
  integer min_dma_arlen;
  integer pass_on_ebreak;
  integer pass_on_csr_break;
  integer retired_total;
  integer retired_this_cycle;
  integer expect_dtcm_scalar_lsu;
  integer expect_dma_start;
  integer expect_scalar_dma_start;
  integer expect_tensor_control;
  integer expect_tensor_start;
  integer expect_tensor_sync;
  integer expect_tensor_matvec64_1token_tiled_output;
  integer expect_tensor_tile8x8_stream64tokens_output;
  integer expect_tensor_matmul64x64_64tokens_tiled_output;
  integer expect_tensor_matmul64x64_64tokens_tiled_permuted_output;
  integer expect_tensor_matmul64x64_128tokens_tiled_output;
  integer expect_tensor_matmul512x512_32tokens_transpose_output;
  integer expect_scalar_cache_ops;
  integer expect_scalar_cache_clean;
  integer dtcm_store_count;
  integer dtcm_load_count;
  integer dtcm_load_resp_count;
  integer scalar_dma_start_count;
  integer tensor_dma_start_count;
  integer tensor_control_count;
  integer tensor_start_count;
  integer tensor_start_full_count;
  integer tensor_start_tile_count;
  integer tensor_sync_count;
  integer tensor_start_accept_count;
  integer tensor_start_accept_run_sum;
  integer tensor_start_accept_run_max;
  integer tensor_stream_out_push_count;
  integer tensor_next_i_prefetch_accept_count;
  integer tensor_next_psum_prefetch_accept_count;
  integer tensor_engine_compute_valid_count;
  integer tensor_engine_compute_busy_count;
  integer tensor_engine_i_not_owned_count;
  integer tensor_engine_psum_not_owned_count;
  integer tensor_engine_out_not_owned_count;
  integer tensor_engine_i_output_conflict_count;
  integer tensor_engine_psum_output_conflict_count;
  integer tensor_engine_output_write_count;
  integer tensor_queued_handoff_count;
  integer tensor_engine_start_count;
  integer dma_start_count;
  integer scalar_cache_clean_count;
  integer scalar_cache_invalidate_count;
  integer scalar_load_pair_count;
  integer scalar_store_pair_count;
  integer scalar_m_fast_pair_count;
  integer scalar_fast_m_pair_count;
  integer scalar_fast_fast_pair_count;
  integer max_retire_queue_count;
  integer retire_queue_full_count;
  integer scalar_load_pair_block_count;
  integer scalar_load_pair_block_issue0_count;
  integer scalar_load_pair_block_policy_count;
  integer scalar_load_pair_block_retire_count;
  integer scalar_load_pair_block_gpr_count;
  integer scalar_load_pair_block_store_order_count;
  integer scalar_load_pair_block_lsu_count;
  integer scalar_load_pair_block_other_count;
  integer scalar_issue_block_count;
  integer scalar_issue_block_redirect_count;
  integer scalar_issue_block_cache_count;
  integer scalar_issue_block_retire_count;
  integer scalar_issue_block_producer_count;
  integer scalar_issue_block_gpr_count;
  integer scalar_issue_block_fpr_count;
  integer scalar_issue_block_fpu_count;
  integer scalar_issue_block_alu_count;
  integer scalar_issue_block_store_order_count;
  integer scalar_issue_block_lsu_count;
  integer scalar_issue_block_system_count;
  integer scalar_issue_block_other_count;
  integer max_lsu_stb_count;
  integer max_lsu_loadq_count;
  integer dcache_hit_under_miss_accept_count;
  integer dcache_hit_under_miss_complete_count;
  integer dcache_hit_queue_full_count;
  integer max_dcache_hit_queue_count;
  integer dcache_lookup_accept_count;
  integer dcache_lookup_launch_count;
  integer dcache_lookup_lane1_launch_count;
  integer dcache_lookup_bypass_count;
  integer dcache_lookup_capture_count;
  integer dcache_lookup_occupancy1_cycles;
  integer dcache_lookup_occupancy2_cycles;
  integer dcache_lookup_phase_wait_cycles;
  integer dcache_lookup_hit_queue_wait_cycles;
  integer dcache_lookup_mshr_park_count;
  integer dcache_lookup_parked_retry_cycles;
  integer dcache_lookup_backend_pause_cycles;
  integer lsu_loadreq_fifo_full_count;
  integer max_lsu_loadreq_fifo_count;
  integer dma_max_arlen;
  integer pre_token_stall_count;
  integer pre_token_stall_hold_count;
  integer pre_token_stall_issue_window_count;
  integer pre_token_stall_pipe_busy_count;
  integer pre_token_stall_scalar_ready_count;
  integer pre_token_stall_capture_count;
  integer pre_token_stall_accel_ready_count;
  integer pre_token_stall_unsupported_count;
  integer pre_token_stall_other_count;
  integer timing_window_cycle_count;
  integer timing_window_productive_cycle_count;
  integer timing_window_zero_retire_count;
  integer timing_no_retire_redirect_frontend_refill_count;
  integer timing_no_retire_icache_refill_count;
  integer timing_no_retire_head_gpr_count;
  integer timing_head_gpr_producer_queue_count;
  integer timing_head_gpr_raw_src0_count;
  integer timing_head_gpr_raw_src1_count;
  integer timing_head_gpr_raw_src2_count;
  integer timing_head_gpr_waw_dst_count;
  integer timing_head_gpr_other_count;
  integer timing_raw_src0_producer_alu_count;
  integer timing_raw_src0_producer_load_count;
  integer timing_raw_src0_producer_mul_count;
  integer timing_raw_src0_producer_system_count;
  integer timing_raw_src0_producer_other_count;
  integer timing_raw_src0_age0_count;
  integer timing_raw_src0_age1_count;
  integer timing_raw_src0_age2_count;
  integer timing_raw_src0_age3plus_count;
  integer timing_m_issue_mul64_count;
  integer timing_m_issue_mulh64_count;
  integer timing_m_issue_mulw_count;
  integer timing_m_issue_div64_count;
  integer timing_m_issue_rem64_count;
  integer timing_m_issue_divw_count;
  integer timing_m_issue_remw_count;
  integer timing_m_raw_mul64_count;
  integer timing_m_raw_mulh64_count;
  integer timing_m_raw_mulw_count;
  integer timing_m_raw_div64_count;
  integer timing_m_raw_rem64_count;
  integer timing_m_raw_divw_count;
  integer timing_m_raw_remw_count;
  integer timing_m_raw_other_count;
  integer timing_m_raw_remaining1_count;
  integer timing_m_raw_remaining2_count;
  integer timing_m_raw_remaining3_count;
  integer timing_m_raw_remaining4_count;
  integer timing_m_raw_remaining5_count;
  integer timing_m_raw_remaining6_count;
  integer timing_m_raw_remaining7_count;
  integer timing_m_raw_remaining8_count;
  integer timing_m_raw_remaining9_16_count;
  integer timing_m_raw_remaining17_32_count;
  integer timing_m_raw_state_mismatch_count;
  integer mul_busy_cycles;
  integer mul_blocked_m_request_count;
  integer mul_blocked_m_request_cycles;
  integer mul_blocked_mulw_request_count;
  integer mul_blocked_other_request_count;
  integer mul_blocked_current_run;
  integer mul_blocked_max_run;
  integer mul_issue_word_count;
  integer mul_issue_low_one_partial_count;
  integer mul_issue_low_two_partial_count;
  integer mul_issue_low_two_lh_count;
  integer mul_issue_low_two_hl_count;
  integer mul_issue_low_three_partial_count;
  integer mul_issue_low_both_signext32_count;
  integer mul_issue_high_count;
  integer timing_younger_load_visible_count;
  integer timing_younger_load_eligible_count;
  integer timing_younger_load_eligible_head1_count;
  integer timing_younger_load_block_gpr_count;
  integer timing_younger_load_block_dependency_count;
  integer timing_younger_load_block_memory_order_count;
  integer timing_younger_load_block_lsu_count;
  integer timing_younger_load_block_retire_count;
  integer timing_younger_load_block_other_count;
  integer timing_no_retire_lsu_count;
  integer timing_waw_complete_match_count;
  integer timing_waw_complete_load_count;
  integer timing_waw_complete_mul_count;
  integer timing_waw_complete_fast0_count;
  integer timing_waw_complete_fast1_count;
  integer timing_waw_producer_alu_count;
  integer timing_waw_producer_load_count;
  integer timing_waw_producer_mul_count;
  integer timing_waw_producer_other_count;
  integer timing_waw_stall_run_count;
  integer timing_waw_stall_max_run;
  integer timing_waw_stall_current_run;
  integer timing_lsu_head_store_capacity_count;
  integer timing_lsu_head_load_capacity_count;
  integer timing_lsu_head_pipe_count;
  integer timing_lsu_response_backpressure_count;
  integer timing_lsu_store_drain_backend_count;
  integer timing_lsu_load_request_backend_count;
  integer timing_lsu_mshr_count;
  integer timing_lsu_loadq_wait_count;
  integer timing_lsu_store_buffer_wait_count;
  integer timing_lsu_other_count;
  integer timing_no_retire_retire_full_count;
  integer timing_no_retire_backend_resource_count;
  integer timing_no_retire_other_count;
  integer timing_redirect_count;
  integer timing_redirect_to_req_sum;
  integer timing_redirect_to_req_max;
  integer timing_redirect_to_resp_sum;
  integer timing_redirect_to_resp_max;
  integer timing_redirect_to_packet_sum;
  integer timing_redirect_to_packet_max;
  integer timing_redirect_to_fifo_sum;
  integer timing_redirect_to_fifo_max;
  integer timing_redirect_to_token_sum;
  integer timing_redirect_to_token_max;
  integer timing_redirect_to_token_0_count;
  integer timing_redirect_to_token_1_count;
  integer timing_redirect_to_token_2_count;
  integer timing_redirect_to_token_3_count;
  integer timing_redirect_to_token_4_count;
  integer timing_redirect_to_token_5plus_count;
  integer timing_redirect_to_issue_sum;
  integer timing_redirect_to_issue_max;
  integer timing_redirect_to_issue_0_count;
  integer timing_redirect_to_issue_1_count;
  integer timing_redirect_to_issue_2_count;
  integer timing_redirect_to_issue_3_count;
  integer timing_redirect_to_issue_4_count;
  integer timing_redirect_to_issue_5plus_count;
  integer timing_control_branch_issue_count;
  integer timing_control_jal_issue_count;
  integer timing_control_jalr_issue_count;
  integer timing_control_branch_taken_count;
  integer timing_control_jal_taken_count;
  integer timing_control_jalr_taken_count;
  integer timing_early_redirect_req_launchable_count;
  integer timing_early_redirect_req_block_outstanding_count;
  integer timing_early_redirect_req_block_icache_count;
  integer timing_early_redirect_target_outstanding_count;
  integer timing_early_redirect_target_primary_count;
  integer timing_early_redirect_target_skid_count;
  integer timing_redirect_scalar32_empty_parcel_count;
  integer timing_redirect_edge64_empty_parcel_count;
  integer timing_redirect_scalar32_busy_parcel_count;
  integer timing_redirect_edge64_busy_parcel_count;
  integer setin_ready_target_stall_count;
  integer tensor_command_accept_stall_count;
  integer tensor_issue_stall_count;
  integer tensor_issue_setin_stall_count;
  integer tensor_issue_setout_stall_count;
  integer tensor_issue_setpsum_stall_count;
  integer tensor_issue_start_stall_count;
  integer tensor_issue_sync_stall_count;
  integer tensor_issue_wld_circular_stall_count;
  integer tensor_issue_other_stall_count;
  integer circular_wld_empty_stall_count;
  integer circular_wld_pipe_stall_count;
  integer circular_dma_busy_wait_count;
  integer circular_dma_ring_full_wait_count;
  integer circular_dma_inflight_count;
  integer circular_dma_launch_count;
  integer circular_dma_done_count;
  integer circular_wld_consume_count;
  integer circular_max_occupancy;
  integer circular_occupancy;
  integer cycle;
  integer report_fd;
  integer sim_console_fd;
  integer dump_fd;
  integer dump_len;
  integer dump_i;
  integer dump_word_i;
  integer dump_byte_i;
  integer trace_fd;
  integer trace_start_cycle;
  integer trace_stop_cycle;
  integer fatal_fd;
  integer fpu_vec_fd;
  integer fpu_vec_count;
  integer fpu_vec_seen;
  integer fpu_vec_scan_count;
  reg matvec64_1token_tiled_output_ok;
  reg tile8x8_stream64tokens_output_ok;
  reg matmul64x64_64tokens_tiled_output_ok;
  reg matmul512x512_32tokens_transpose_output_ok;
  reg matmul64x64_128tokens_tiled_output_ok;
  reg sim_done;
  reg [63:0] expected_x31;
  reg [63:0] expected_return;
  reg [63:0] report_return_value;
  reg [4095:0] report_path;
  reg [4095:0] sim_console_path;
  reg [4095:0] dump_path;
  reg [4095:0] trace_path;
  reg [63:0] dump_base;
  reg [4095:0] fpu_vec_path;
  reg mul_blocked_request_active;
  reg [7:0] mul_blocked_request_seq;
  reg [3:0] mul_blocked_request_epoch;
  string fpu_vec_line;
  reg [7:0] fpu_expected_rm;
  reg [7:0] fpu_expected_fflags;
  reg [31:0] fpu_expected_y;
  reg [31:0] fpu_expected_x;
  reg [31:0] fpu_expected_a;
  reg [31:0] fpu_expected_b;
  reg [31:0] fpu_actual_y;
  reg [4:0] fpu_actual_fflags;
  reg trace_enable;
  reg timing_window_enable;
  reg timing_window_active;
  reg timing_window_seen_start;
  reg timing_window_seen_stop;
  reg timing_start_configured;
  reg timing_stop_configured;
  reg [ADDR_WIDTH-1:0] timing_start_pc;
  reg [ADDR_WIDTH-1:0] timing_stop_pc;
  reg timing_redirect_wait_token;
  reg timing_redirect_wait_issue;
  reg timing_redirect_wait_req;
  reg timing_redirect_wait_resp;
  reg timing_redirect_wait_packet;
  reg timing_redirect_wait_fifo;
  reg timing_waw_stall_active;
  integer timing_redirect_req_latency;
  integer timing_redirect_resp_latency;
  integer timing_redirect_packet_latency;
  integer timing_redirect_fifo_latency;
  integer timing_redirect_token_latency;
  integer timing_redirect_issue_latency;
  reg [2:0] timing_gpr_producer_type [0:31];
  reg [2:0] timing_gpr_producer_m_kind [0:31];
  reg [7:0] timing_gpr_producer_seq [0:31];
  integer timing_producer_i;
  wire core_ebreak_valid;
  wire [7:0] core_ebreak_seq_id;
  wire [3:0] core_ebreak_epoch;
  wire core_csr_break_valid;
  wire [63:0] core_csr_break_code;
  wire [7:0] core_csr_break_seq_id;
  wire [3:0] core_csr_break_epoch;
  wire core_csr_putchar_valid;
  wire [7:0] core_csr_putchar_char;

  function tb_reads_rs1;
    input [31:0] inst;
    begin
      case (inst[6:0])
        TB_OPCODE_LOAD,
        TB_OPCODE_STORE,
        TB_OPCODE_OP_IMM,
        TB_OPCODE_OP,
        TB_OPCODE_OP_IMM32,
        TB_OPCODE_OP32,
        TB_OPCODE_JALR,
        TB_OPCODE_BRANCH: tb_reads_rs1 = inst[19:15] != 5'd0;
        default: tb_reads_rs1 = 1'b0;
      endcase
    end
  endfunction

  function tb_reads_rs2;
    input [31:0] inst;
    begin
      case (inst[6:0])
        TB_OPCODE_STORE,
        TB_OPCODE_OP,
        TB_OPCODE_OP32,
        TB_OPCODE_BRANCH: tb_reads_rs2 = inst[24:20] != 5'd0;
        default: tb_reads_rs2 = 1'b0;
      endcase
    end
  endfunction

  function tb_writes_rd;
    input [31:0] inst;
    begin
      case (inst[6:0])
        TB_OPCODE_LOAD,
        TB_OPCODE_LUI,
        TB_OPCODE_AUIPC,
        TB_OPCODE_OP_IMM,
        TB_OPCODE_OP,
        TB_OPCODE_OP_IMM32,
        TB_OPCODE_OP32,
        TB_OPCODE_JAL,
        TB_OPCODE_JALR: tb_writes_rd = inst[11:7] != 5'd0;
        TB_OPCODE_SYSTEM: tb_writes_rd = (inst[14:12] != 3'b000) &&
                                               (inst[11:7] != 5'd0);
        default: tb_writes_rd = 1'b0;
      endcase
    end
  endfunction

  function tb_skip_safe_nonmemory;
    input [31:0] inst;
    begin
      case (inst[6:0])
        TB_OPCODE_LUI,
        TB_OPCODE_AUIPC,
        TB_OPCODE_OP_IMM,
        TB_OPCODE_OP,
        TB_OPCODE_OP_IMM32,
        TB_OPCODE_OP32: tb_skip_safe_nonmemory = 1'b1;
        default: tb_skip_safe_nonmemory = 1'b0;
      endcase
    end
  endfunction

  function tb_full_gpr_hazard;
    input [31:0] older;
    input [31:0] younger;
    begin
      tb_full_gpr_hazard =
        (tb_writes_rd(older) && tb_reads_rs1(younger) &&
         (older[11:7] == younger[19:15])) ||
        (tb_writes_rd(older) && tb_reads_rs2(younger) &&
         (older[11:7] == younger[24:20])) ||
        (tb_writes_rd(younger) && tb_reads_rs1(older) &&
         (younger[11:7] == older[19:15])) ||
        (tb_writes_rd(younger) && tb_reads_rs2(older) &&
         (younger[11:7] == older[24:20])) ||
        (tb_writes_rd(older) && tb_writes_rd(younger) &&
         (older[11:7] == younger[11:7]));
    end
  endfunction

  function [2:0] tb_producer_type;
    input [31:0] inst;
    begin
      case (inst[6:0])
        TB_OPCODE_LOAD: tb_producer_type = TB_PRODUCER_LOAD;
        TB_OPCODE_OP,
        TB_OPCODE_OP32: tb_producer_type =
          (inst[31:25] == 7'b0000001) ? TB_PRODUCER_MUL : TB_PRODUCER_ALU;
        TB_OPCODE_LUI,
        TB_OPCODE_AUIPC,
        TB_OPCODE_OP_IMM,
        TB_OPCODE_OP_IMM32,
        TB_OPCODE_JAL,
        TB_OPCODE_JALR: tb_producer_type = TB_PRODUCER_ALU;
        TB_OPCODE_SYSTEM: tb_producer_type = TB_PRODUCER_SYSTEM;
        default: tb_producer_type = TB_PRODUCER_OTHER;
      endcase
    end
  endfunction

  function [2:0] tb_m_kind;
    input [31:0] inst;
    begin
      if ((inst[31:25] != 7'b0000001) ||
          ((inst[6:0] != TB_OPCODE_OP) &&
           (inst[6:0] != TB_OPCODE_OP32))) begin
        tb_m_kind = TB_M_KIND_OTHER;
      end else if (!inst[14]) begin
        if (inst[6:0] == TB_OPCODE_OP32)
          tb_m_kind = TB_M_KIND_MULW;
        else if (inst[14:12] == 3'b000)
          tb_m_kind = TB_M_KIND_MUL64;
        else
          tb_m_kind = TB_M_KIND_MULH64;
      end else if (inst[6:0] == TB_OPCODE_OP32) begin
        tb_m_kind = inst[13] ? TB_M_KIND_REMW : TB_M_KIND_DIVW;
      end else begin
        tb_m_kind = inst[13] ? TB_M_KIND_REM64 : TB_M_KIND_DIV64;
      end
    end
  endfunction

  task check_tensor_matvec64_1token_tiled_output;
    output ok;
    reg ok;
    integer word_i;
    reg [127:0] expected_word;
    reg [127:0] got_word;
  begin
    ok = 1'b1;
    for (word_i = 0; word_i < 8; word_i = word_i + 1) begin
      case (word_i)
        0: expected_word = 128'hc20041984180c224c20c420842444120;
        1: expected_word = 128'h41984180c224c20c420842444120c1a0;
        2: expected_word = 128'h4180c224c20c420842444120c1a0c200;
        3: expected_word = 128'hc224c20c420842444120c1a0c2004198;
        4: expected_word = 128'hc20c420842444120c1a0c20041984180;
        5: expected_word = 128'h420842444120c1a0c20041984180c224;
        6: expected_word = 128'h42444120c1a0c20041984180c224c20c;
        default: expected_word = 128'h4120c1a0c20041984180c224c20c4208;
      endcase
      got_word = dut.soc_ram.mem[(40'h3800 >> 4) + word_i];
      if (got_word !== expected_word) begin
        ok = 1'b0;
        $display("EDGE_SOC_VVP MATVEC64_1TOKEN_TILED MISMATCH word=%0d got=%032h expected=%032h",
                 word_i, got_word, expected_word);
      end
    end
  end
  endtask

  function [15:0] matmul512x512_32tokens_transpose_expected_bf16;
    input integer elem_i;
    integer out_block;
    integer token;
    integer out_lane;
    integer k_block;
    integer k_lane;
    integer k;
    integer pattern;
  begin
    out_block = elem_i / (32 * 8);
    token = (elem_i % (32 * 8)) / 8;
    out_lane = elem_i % 8;
    k_block = (out_block * 17 + 5) & 63;
    k_lane = (out_lane * 3 + 1) & 7;
    k = k_block * 8 + k_lane;
    pattern = (token * 7 + k * 3 + 2) % 13;
    case (pattern)
      0: matmul512x512_32tokens_transpose_expected_bf16 = 16'hc0c0;
      1: matmul512x512_32tokens_transpose_expected_bf16 = 16'hc0a0;
      2: matmul512x512_32tokens_transpose_expected_bf16 = 16'hc080;
      3: matmul512x512_32tokens_transpose_expected_bf16 = 16'hc040;
      4: matmul512x512_32tokens_transpose_expected_bf16 = 16'hc000;
      5: matmul512x512_32tokens_transpose_expected_bf16 = 16'hbf80;
      6: matmul512x512_32tokens_transpose_expected_bf16 = 16'h0000;
      7: matmul512x512_32tokens_transpose_expected_bf16 = 16'h3f80;
      8: matmul512x512_32tokens_transpose_expected_bf16 = 16'h4000;
      9: matmul512x512_32tokens_transpose_expected_bf16 = 16'h4040;
      10: matmul512x512_32tokens_transpose_expected_bf16 = 16'h4080;
      11: matmul512x512_32tokens_transpose_expected_bf16 = 16'h40a0;
      default: matmul512x512_32tokens_transpose_expected_bf16 = 16'h40c0;
    endcase
  end
  endfunction

  task check_tensor_matmul512x512_32tokens_transpose_output;
    output ok;
    reg ok;
    integer word_i;
    integer lane_i;
    integer elem_i;
    reg [127:0] expected_word;
    reg [127:0] got_word;
  begin
    ok = 1'b1;
    for (word_i = 0; word_i < 2048; word_i = word_i + 1) begin
      expected_word = 128'b0;
      for (lane_i = 0; lane_i < 8; lane_i = lane_i + 1) begin
        elem_i = word_i * 8 + lane_i;
        expected_word[lane_i * 16 +: 16] =
            matmul512x512_32tokens_transpose_expected_bf16(elem_i);
      end
      got_word = dut.soc_ram.mem[(40'h0010_0000 >> 4) + word_i];
      if (got_word !== expected_word) begin
        ok = 1'b0;
        $display("EDGE_SOC_VVP MATMUL512X512_32TOKENS_TRANSPOSE MISMATCH word=%0d got=%032h expected=%032h",
                 word_i, got_word, expected_word);
      end
    end
  end
  endtask

  function [127:0] tile8x8_stream64tokens_expected_word;
    input integer word_i;
  begin
    case ((word_i * 8) % 13)
      0: tile8x8_stream64tokens_expected_word = 128'h4040c188c1e0c1f0c1b8c0e041904250;
      1: tile8x8_stream64tokens_expected_word = 128'h40c0c170c1d8c1f0c1c0c11041704240;
      2: tile8x8_stream64tokens_expected_word = 128'h4110c150c1d0c1f0c1c8c13041404230;
      3: tile8x8_stream64tokens_expected_word = 128'h4140c130c1c8c1f0c1d0c15041104220;
      4: tile8x8_stream64tokens_expected_word = 128'h4170c110c1c0c1f0c1d8c17040c04210;
      5: tile8x8_stream64tokens_expected_word = 128'h4190c0e0c1b8c1f0c1e0c18840404200;
      6: tile8x8_stream64tokens_expected_word = 128'h429242084080c188c1e8c200c1d0c130;
      7: tile8x8_stream64tokens_expected_word = 128'h41c042b042304110c188c208c228c224;
      8: tile8x8_stream64tokens_expected_word = 128'hc140421842c242404100c1b8c234c268;
      9: tile8x8_stream64tokens_expected_word = 128'hc20c3f80423842c842383f80c20cc278;
      10: tile8x8_stream64tokens_expected_word = 128'hc234c1b84100424042c24218c140c254;
      11: tile8x8_stream64tokens_expected_word = 128'hc228c208c1884110423042b041c0c1f8;
      default: tile8x8_stream64tokens_expected_word = 128'hc1d0c200c1e8c1884080420842924080;
    endcase
  end
  endfunction

  task check_tensor_tile8x8_stream64tokens_output;
    output ok;
    reg ok;
    integer word_i;
    reg [127:0] expected_word;
    reg [127:0] got_word;
  begin
    ok = 1'b1;
    for (word_i = 0; word_i < 512; word_i = word_i + 1) begin
      expected_word = tile8x8_stream64tokens_expected_word(word_i);
      got_word = dut.soc_ram.mem[(40'h0010_0000 >> 4) + word_i];
      if (got_word !== expected_word) begin
        ok = 1'b0;
        $display("EDGE_SOC_VVP TILE8X8_STREAM64TOKENS MISMATCH word=%0d got=%032h expected=%032h",
                 word_i, got_word, expected_word);
      end
    end
  end
  endtask

  function [15:0] matmul64x64_64tokens_tiled_expected_bf16;
    input integer elem_i;
    input integer permuted;
    integer out_block;
    integer token;
    integer out_lane;
    integer out_col;
    integer expected_k;
    integer input_elem_i;
  begin
    out_block = elem_i / 512;
    token = (elem_i % 512) / 8;
    out_lane = elem_i % 8;
    out_col = out_block * 8 + out_lane;
    expected_k = permuted ? (out_col + 63) % 64 : out_col;
    input_elem_i = (expected_k / 8) * 512 + token * 8 + expected_k % 8;
    case (input_elem_i % 13)
      0: matmul64x64_64tokens_tiled_expected_bf16 = 16'hc0c0;
      1: matmul64x64_64tokens_tiled_expected_bf16 = 16'hc0a0;
      2: matmul64x64_64tokens_tiled_expected_bf16 = 16'hc080;
      3: matmul64x64_64tokens_tiled_expected_bf16 = 16'hc040;
      4: matmul64x64_64tokens_tiled_expected_bf16 = 16'hc000;
      5: matmul64x64_64tokens_tiled_expected_bf16 = 16'hbf80;
      6: matmul64x64_64tokens_tiled_expected_bf16 = 16'h0000;
      7: matmul64x64_64tokens_tiled_expected_bf16 = 16'h3f80;
      8: matmul64x64_64tokens_tiled_expected_bf16 = 16'h4000;
      9: matmul64x64_64tokens_tiled_expected_bf16 = 16'h4040;
      10: matmul64x64_64tokens_tiled_expected_bf16 = 16'h4080;
      11: matmul64x64_64tokens_tiled_expected_bf16 = 16'h40a0;
      default: matmul64x64_64tokens_tiled_expected_bf16 = 16'h40c0;
    endcase
  end
  endfunction

  task check_tensor_matmul64x64_64tokens_tiled_output;
    output ok;
    input integer permuted;
    reg ok;
    integer word_i;
    integer lane_i;
    integer elem_i;
    reg [127:0] expected_word;
    reg [127:0] got_word;
  begin
    ok = 1'b1;
    for (word_i = 0; word_i < 512; word_i = word_i + 1) begin
      expected_word = 128'b0;
      for (lane_i = 0; lane_i < 8; lane_i = lane_i + 1) begin
        elem_i = word_i * 8 + lane_i;
        expected_word[lane_i * 16 +: 16] =
            matmul64x64_64tokens_tiled_expected_bf16(elem_i, permuted);
      end
      got_word = dut.soc_ram.mem[(40'h0010_0000 >> 4) + word_i];
      if (got_word !== expected_word) begin
        ok = 1'b0;
        $display("EDGE_SOC_VVP MATMUL64X64_64TOKENS_TILED MISMATCH word=%0d got=%032h expected=%032h",
                 word_i, got_word, expected_word);
      end
    end
  end
  endtask

  task check_tensor_matmul64x64_128tokens_tiled_output;
    output ok;
    reg ok;
    integer word_i;
    integer lane_i;
    integer elem_i;
    reg [127:0] expected_word;
    reg [127:0] got_word;
  begin
    ok = 1'b1;
    for (word_i = 0; word_i < 1024; word_i = word_i + 1) begin
      expected_word = 128'b0;
      for (lane_i = 0; lane_i < 8; lane_i = lane_i + 1) begin
        elem_i = word_i * 8 + lane_i;
        expected_word[lane_i * 16 +: 16] =
            matmul64x64_64tokens_tiled_expected_bf16(elem_i, 0);
      end
      got_word = dut.soc_ram.mem[(40'h0010_0000 >> 4) + word_i];
      if (got_word !== expected_word) begin
        ok = 1'b0;
        $display("EDGE_SOC_VVP MATMUL64X64_128TOKENS_TILED MISMATCH word=%0d got=%032h expected=%032h",
                 word_i, got_word, expected_word);
      end
    end
  end
  endtask

  edge_soc_top #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .SOC_RAM_ADDR_BITS(SOC_RAM_ADDR_BITS),
    .ENABLE_EARLY_LOAD_RETIRE(ENABLE_EARLY_LOAD_RETIRE)
  ) dut (
    .pll_core_cpuclk(clk),
    .pad_cpu_rst_b(rst_b),
    .core_boot_pc(core_boot_pc),
    .core_start(core_start),
    .core_force_stop(core_force_stop),
    .edge_dtcm_base(40'h0040_0000_00),
    .edge_dtcm_mask(40'hffff_fe00_00),
    .edge_dtcm_enable(1'b1),
    .edge_dma_start_addr_src(40'h0),
    .edge_dma_start_addr_dst(40'h0),
    .edge_dma_start_len(32'd0),
    .edge_dma_start_req(1'b0),
    .bringup_core_araddr({ADDR_WIDTH{1'b0}}),
    .bringup_core_arburst(2'b01),
    .bringup_core_arcache(4'h0),
    .bringup_core_arid({ID_WIDTH{1'b0}}),
    .bringup_core_arlen({LEN_WIDTH{1'b0}}),
    .bringup_core_arlock(1'b0),
    .bringup_core_arprot(3'b000),
    .bringup_core_arsize(3'b100),
    .bringup_core_arvalid(1'b0),
    .bringup_core_rready(1'b0),
    .bringup_core_awaddr({ADDR_WIDTH{1'b0}}),
    .bringup_core_awburst(2'b01),
    .bringup_core_awcache(4'h0),
    .bringup_core_awid({ID_WIDTH{1'b0}}),
    .bringup_core_awlen({LEN_WIDTH{1'b0}}),
    .bringup_core_awlock(1'b0),
    .bringup_core_awprot(3'b000),
    .bringup_core_awsize(3'b100),
    .bringup_core_awvalid(1'b0),
    .bringup_core_bready(1'b0),
    .bringup_core_wdata({DATA_WIDTH{1'b0}}),
    .bringup_core_wlast(1'b0),
    .bringup_core_wstrb({(DATA_WIDTH/8){1'b0}}),
    .bringup_core_wvalid(1'b0),
    .bringup_dma_araddr({ADDR_WIDTH{1'b0}}),
    .bringup_dma_arburst(2'b01),
    .bringup_dma_arcache(4'h0),
    .bringup_dma_arid({ID_WIDTH{1'b0}}),
    .bringup_dma_arlen({LEN_WIDTH{1'b0}}),
    .bringup_dma_arlock(1'b0),
    .bringup_dma_arprot(3'b000),
    .bringup_dma_arsize(3'b100),
    .bringup_dma_arvalid(1'b0),
    .bringup_dma_rready(1'b0),
    .bringup_dma_awaddr({ADDR_WIDTH{1'b0}}),
    .bringup_dma_awburst(2'b01),
    .bringup_dma_awcache(4'h0),
    .bringup_dma_awid({ID_WIDTH{1'b0}}),
    .bringup_dma_awlen({LEN_WIDTH{1'b0}}),
    .bringup_dma_awlock(1'b0),
    .bringup_dma_awprot(3'b000),
    .bringup_dma_awsize(3'b100),
    .bringup_dma_awvalid(1'b0),
    .bringup_dma_bready(1'b0),
    .bringup_dma_wdata({DATA_WIDTH{1'b0}}),
    .bringup_dma_wlast(1'b0),
    .bringup_dma_wstrb({(DATA_WIDTH/8){1'b0}}),
    .bringup_dma_wvalid(1'b0),
    .pad_biu_arready(1'b0),
    .pad_biu_rdata({DATA_WIDTH{1'b0}}),
    .pad_biu_rid({ID_WIDTH{1'b0}}),
    .pad_biu_rlast(1'b0),
    .pad_biu_rresp(2'b00),
    .pad_biu_rvalid(1'b0),
    .pad_biu_awready(1'b0),
    .pad_biu_bid({ID_WIDTH{1'b0}}),
    .pad_biu_bresp(2'b00),
    .pad_biu_bvalid(1'b0),
    .pad_biu_wready(1'b0),
    .core_ebreak_valid(core_ebreak_valid),
    .core_ebreak_seq_id(core_ebreak_seq_id),
    .core_ebreak_epoch(core_ebreak_epoch),
    .core_csr_break_valid(core_csr_break_valid),
    .core_csr_break_code(core_csr_break_code),
    .core_csr_break_seq_id(core_csr_break_seq_id),
    .core_csr_break_epoch(core_csr_break_epoch)
    ,.core_csr_putchar_valid(core_csr_putchar_valid)
    ,.core_csr_putchar_char(core_csr_putchar_char)
  );

  wire [31:0] timing_probe_head0_inst =
    dut.core_top.base.ifu_predecode_frontend.predecode.scalar_iw_head0_inst[31:0];
  wire [31:0] timing_probe_head1_inst =
    dut.core_top.base.ifu_predecode_frontend.predecode.scalar_iw_head1_inst[31:0];
  wire [31:0] timing_probe_gpr_busy =
    dut.core_top.base.scalar_pipe.gpr_busy_status;
  wire timing_probe_head_gpr_stall =
    dut.core_top.base.frontend_scalar_valid &&
    !dut.core_top.base.pipe_issue_ready &&
    (!dut.core_top.base.scalar_pipe.producer_queue_issue_ready ||
     (dut.core_top.base.scalar_pipe.issue_gpr_check_candidate &&
      !dut.core_top.base.scalar_pipe.gpr_issue_ready));
  wire timing_probe_head1_visible =
    dut.core_top.base.ifu_predecode_frontend.predecode.scalar_iw_head1_valid &&
    (timing_probe_head1_inst[6:0] == TB_OPCODE_LOAD);
  wire timing_probe_head1_gpr_ready =
    !timing_probe_gpr_busy[timing_probe_head1_inst[19:15]] &&
    ((timing_probe_head1_inst[11:7] == 5'd0) ||
     !timing_probe_gpr_busy[timing_probe_head1_inst[11:7]]);
  wire timing_probe_head1_dependency_safe =
    !tb_full_gpr_hazard(timing_probe_head0_inst, timing_probe_head1_inst);
  wire timing_probe_head1_memory_safe =
    tb_skip_safe_nonmemory(timing_probe_head0_inst);
  wire timing_probe_lsu_ready =
    dut.core_top.base.scalar_pipe.lsu_issue_ready &&
    dut.core_top.base.scalar_pipe.lsu_stores_drained;
  wire timing_probe_retire_ready =
    dut.core_top.base.scalar_pipe.retire_alloc_ready &&
    dut.core_top.base.scalar_pipe.producer_queue_issue_ready;
  wire timing_probe_head1_eligible = timing_probe_head1_visible &&
    timing_probe_head1_gpr_ready && timing_probe_head1_dependency_safe &&
    timing_probe_head1_memory_safe && timing_probe_lsu_ready &&
    timing_probe_retire_ready;
  wire timing_probe_any_visible = timing_probe_head1_visible;
  wire timing_probe_any_gpr_ready =
    timing_probe_head1_visible && timing_probe_head1_gpr_ready;
  wire timing_probe_any_dependency_safe =
    (timing_probe_head1_visible && timing_probe_head1_gpr_ready &&
     timing_probe_head1_dependency_safe);
  wire timing_probe_any_memory_safe =
    (timing_probe_head1_visible && timing_probe_head1_gpr_ready &&
     timing_probe_head1_dependency_safe && timing_probe_head1_memory_safe);
  wire timing_probe_any_eligible = timing_probe_head1_eligible;
  wire [4:0] timing_probe_blocked_src0 =
    dut.core_top.base.scalar_pipe.issue_inst[19:15];
  wire [2:0] timing_probe_src0_producer_type =
    timing_gpr_producer_type[timing_probe_blocked_src0];
  wire [4:0] timing_probe_head_dst = timing_probe_head0_inst[11:7];
  wire timing_probe_head_waw_stall =
    timing_probe_head_gpr_stall &&
    !dut.core_top.base.scalar_pipe.redirect_kill_valid &&
    !timing_redirect_wait_issue &&
    !dut.core_top.base.ifu_cache_debug_miss_pending &&
    dut.core_top.base.scalar_pipe.producer_queue_issue_ready &&
    !dut.core_top.base.scalar_pipe.gpr_wbt.src0_blocked &&
    !dut.core_top.base.scalar_pipe.gpr_wbt.src1_blocked &&
    !dut.core_top.base.scalar_pipe.gpr_wbt.src2_blocked &&
    dut.core_top.base.scalar_pipe.gpr_wbt.dst_blocked;
  wire timing_probe_waw_complete_load =
    dut.core_top.base.scalar_pipe.gpr_load_complete_valid &&
    (dut.core_top.base.scalar_pipe.gpr_load_complete_reg ==
     timing_probe_head_dst);
  wire timing_probe_waw_complete_mul =
    dut.core_top.base.scalar_pipe.alu_m_complete_valid &&
    dut.core_top.base.scalar_pipe.alu_m_complete_rd_valid &&
    (dut.core_top.base.scalar_pipe.alu_m_complete_rd ==
     timing_probe_head_dst);
  wire timing_probe_waw_complete_fast0 =
    dut.core_top.base.scalar_pipe.gpr_complete_valid &&
    (dut.core_top.base.scalar_pipe.gpr_complete_rd ==
     timing_probe_head_dst);
  wire timing_probe_waw_complete_fast1 =
    dut.core_top.base.scalar_pipe.alu_fast1_complete_valid &&
    dut.core_top.base.scalar_pipe.alu_fast1_complete_rd_valid &&
    (dut.core_top.base.scalar_pipe.alu_fast1_complete_rd ==
     timing_probe_head_dst);
  wire timing_probe_waw_complete_match =
    timing_probe_waw_complete_load || timing_probe_waw_complete_mul ||
    timing_probe_waw_complete_fast0 || timing_probe_waw_complete_fast1;
  wire [7:0] timing_probe_src0_producer_age =
    dut.core_top.base.scalar_pipe.issue_seq_id -
    timing_gpr_producer_seq[timing_probe_blocked_src0];
  wire [2:0] timing_probe_src0_m_kind =
    timing_gpr_producer_m_kind[timing_probe_blocked_src0];
  wire timing_probe_mul_state_match =
    dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.mul_busy_r &&
    dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.mul_rd_valid_r &&
    (dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.mul_rd_r ==
     timing_probe_blocked_src0) &&
    (dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.mul_seq_id_r ==
     timing_gpr_producer_seq[timing_probe_blocked_src0]);
  wire timing_probe_div_state_match =
    dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.divrem.busy_r &&
    dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.divrem.complete_rd_valid_r &&
    (dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.divrem.complete_rd_r ==
     timing_probe_blocked_src0) &&
    (dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.divrem.complete_seq_id_r ==
     timing_gpr_producer_seq[timing_probe_blocked_src0]);
  wire timing_probe_m_state_match = timing_probe_mul_state_match ||
                                    timing_probe_div_state_match;
  wire [5:0] timing_probe_m_remaining = timing_probe_mul_state_match ?
    dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.mul_count_r :
    dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.divrem.count_r;
  wire timing_probe_mul_lane0_other_ready =
    !dut.core_top.base.scalar_pipe.redirect_kill_valid &&
    (!dut.core_top.base.scalar_pipe.cache_op_pending_q ||
     dut.core_top.base.scalar_pipe.cache_op_complete_valid) &&
    dut.core_top.base.scalar_pipe.retire_alloc_ready &&
    dut.core_top.base.scalar_pipe.producer_queue_issue_ready &&
    (!dut.core_top.base.scalar_pipe.issue_gpr_check_candidate ||
     dut.core_top.base.scalar_pipe.gpr_issue_ready);
  wire timing_probe_mul_lane0_blocked =
    dut.core_top.base.scalar_pipe.issue_valid &&
    dut.core_top.base.scalar_pipe.issue0_is_pairable_m &&
    !dut.core_top.base.scalar_pipe.funct3[2] &&
    timing_probe_mul_lane0_other_ready &&
    !dut.core_top.base.scalar_pipe.alu_mul_issue_ready;
  wire timing_probe_mul_lane1_blocked =
    dut.core_top.base.scalar_pipe.issue1_valid &&
    dut.core_top.base.scalar_pipe.issue1_is_pairable_m &&
    !dut.core_top.base.scalar_pipe.funct3_1[2] &&
    !dut.core_top.base.scalar_pipe.redirect_kill_valid &&
    dut.core_top.base.scalar_pipe.retire_alloc_ready &&
    dut.core_top.base.scalar_pipe.issue1_pair_allowed &&
    (!dut.core_top.base.scalar_pipe.issue1_gpr_check_candidate ||
     dut.core_top.base.scalar_pipe.gpr_issue1_ready) &&
    !dut.core_top.base.scalar_pipe.alu_mul_issue_ready;
  wire timing_probe_mul_blocked = timing_probe_mul_lane0_blocked ||
                                  timing_probe_mul_lane1_blocked;
  wire [7:0] timing_probe_mul_blocked_seq = timing_probe_mul_lane0_blocked ?
    dut.core_top.base.scalar_pipe.issue_seq_id :
    dut.core_top.base.scalar_pipe.issue1_seq_id;
  wire [3:0] timing_probe_mul_blocked_epoch = timing_probe_mul_lane0_blocked ?
    dut.core_top.base.scalar_pipe.issue_epoch :
    dut.core_top.base.scalar_pipe.issue1_epoch;
  wire timing_probe_mul_blocked_is_word = timing_probe_mul_lane0_blocked ?
    (dut.core_top.base.scalar_pipe.issue_inst[6:0] == 7'b0111011) :
    (dut.core_top.base.scalar_pipe.issue1_inst[6:0] == 7'b0111011);
  wire timing_probe_mul_accept =
    dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.mul_accept;
  wire timing_probe_mul_accept_word =
    dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.issue_is_word;
  wire timing_probe_mul_accept_high =
    dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.issue_is_mul_high;
  wire [63:0] timing_probe_mul_src0 =
    dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.m_issue_src0_value;
  wire [63:0] timing_probe_mul_src1 =
    dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.m_issue_src1_value;
  wire timing_probe_mul_src0_upper_zero = timing_probe_mul_src0[63:32] == 32'd0;
  wire timing_probe_mul_src1_upper_zero = timing_probe_mul_src1[63:32] == 32'd0;
  wire timing_probe_mul_both_signext32 =
    timing_probe_mul_src0[63:32] == {32{timing_probe_mul_src0[31]}} &&
    timing_probe_mul_src1[63:32] == {32{timing_probe_mul_src1[31]}};

  always begin
    #5;
`ifdef VERILATOR_SIM
    if (sim_done)
      $finish;
    else
`endif
      clk = ~clk;
  end

  task finish_sim;
    input integer exit_code;
    begin
`ifdef VERILATOR_SIM
      sim_done = 1'b1;
`else
      $finish;
`endif
    end
  endtask

  task write_report;
    input passed;
    input [1023:0] reason;
    begin
      report_fd = $fopen(report_path, "w");
      if (report_fd == 0) begin
        $display("EDGE_SOC_VVP unable to open report: %0s", report_path);
        finish_sim(1);
      end
      if (passed) begin
        $fdisplay(report_fd, "TEST PASS");
        $fdisplay(report_fd, "RETURN_VALUE=%0d", report_return_value);
      end else begin
        $fdisplay(report_fd, "TEST FAIL");
        $fdisplay(report_fd, "RETURN_VALUE=%0d", report_return_value);
        $fdisplay(report_fd, "REASON=%0s", reason);
      end
      $fdisplay(report_fd, "RETIRE_COUNT=%0d", retired_total);
      $fdisplay(report_fd, "SCALAR_LANE0_RETIRE_COUNT=%0d", scalar_lane0_retire_count);
      $fdisplay(report_fd, "SCALAR_LANE1_RETIRE_COUNT=%0d", scalar_lane1_retire_count);
      $fdisplay(report_fd, "ACCEL_LANE_RETIRE_COUNT=%0d", accel_lane_retire_count);
      $fdisplay(report_fd, "DTCM_STORE_COUNT=%0d", dtcm_store_count);
      $fdisplay(report_fd, "DTCM_LOAD_COUNT=%0d", dtcm_load_count);
      $fdisplay(report_fd, "DTCM_LOAD_RESP_COUNT=%0d", dtcm_load_resp_count);
      $fdisplay(report_fd, "SCALAR_DMA_START_COUNT=%0d", scalar_dma_start_count);
      $fdisplay(report_fd, "TENSOR_DMA_START_COUNT=%0d", tensor_dma_start_count);
      $fdisplay(report_fd, "TENSOR_CONTROL_COUNT=%0d", tensor_control_count);
      $fdisplay(report_fd, "TENSOR_START_COUNT=%0d", tensor_start_count);
      $fdisplay(report_fd, "TENSOR_START_FULL_COUNT=%0d", tensor_start_full_count);
      $fdisplay(report_fd, "TENSOR_START_TILE_COUNT=%0d", tensor_start_tile_count);
      $fdisplay(report_fd, "TENSOR_SYNC_COUNT=%0d", tensor_sync_count);
      $fdisplay(report_fd, "TENSOR_START_ACCEPT_COUNT=%0d", tensor_start_accept_count);
      $fdisplay(report_fd, "TENSOR_START_ACCEPT_RUN_SUM=%0d", tensor_start_accept_run_sum);
      $fdisplay(report_fd, "TENSOR_START_ACCEPT_RUN_MAX=%0d", tensor_start_accept_run_max);
      $fdisplay(report_fd, "TENSOR_STREAM_OUT_PUSH_COUNT=%0d", tensor_stream_out_push_count);
      $fdisplay(report_fd, "TENSOR_NEXT_I_PREFETCH_ACCEPT_COUNT=%0d", tensor_next_i_prefetch_accept_count);
      $fdisplay(report_fd, "TENSOR_NEXT_PSUM_PREFETCH_ACCEPT_COUNT=%0d", tensor_next_psum_prefetch_accept_count);
      $fdisplay(report_fd, "TENSOR_ENGINE_COMPUTE_VALID_COUNT=%0d", tensor_engine_compute_valid_count);
      $fdisplay(report_fd, "TENSOR_ENGINE_COMPUTE_BUSY_COUNT=%0d", tensor_engine_compute_busy_count);
      $fdisplay(report_fd, "TENSOR_ENGINE_I_NOT_OWNED_COUNT=%0d", tensor_engine_i_not_owned_count);
      $fdisplay(report_fd, "TENSOR_ENGINE_PSUM_NOT_OWNED_COUNT=%0d", tensor_engine_psum_not_owned_count);
      $fdisplay(report_fd, "TENSOR_ENGINE_OUT_NOT_OWNED_COUNT=%0d", tensor_engine_out_not_owned_count);
      $fdisplay(report_fd, "TENSOR_ENGINE_I_OUTPUT_CONFLICT_COUNT=%0d", tensor_engine_i_output_conflict_count);
      $fdisplay(report_fd, "TENSOR_ENGINE_PSUM_OUTPUT_CONFLICT_COUNT=%0d", tensor_engine_psum_output_conflict_count);
      $fdisplay(report_fd, "TENSOR_ENGINE_OUTPUT_WRITE_COUNT=%0d", tensor_engine_output_write_count);
      $fdisplay(report_fd, "TENSOR_QUEUED_HANDOFF_COUNT=%0d", tensor_queued_handoff_count);
      $fdisplay(report_fd, "TENSOR_ENGINE_START_COUNT=%0d", tensor_engine_start_count);
      $fdisplay(report_fd, "DMA_START_COUNT=%0d", dma_start_count);
      $fdisplay(report_fd, "SCALAR_CACHE_CLEAN_COUNT=%0d", scalar_cache_clean_count);
      $fdisplay(report_fd, "SCALAR_CACHE_INVALIDATE_COUNT=%0d", scalar_cache_invalidate_count);
      $fdisplay(report_fd, "SCALAR_LOAD_PAIR_COUNT=%0d", scalar_load_pair_count);
      $fdisplay(report_fd, "SCALAR_STORE_PAIR_COUNT=%0d", scalar_store_pair_count);
      $fdisplay(report_fd, "SCALAR_M_FAST_PAIR_COUNT=%0d", scalar_m_fast_pair_count);
      $fdisplay(report_fd, "SCALAR_FAST_M_PAIR_COUNT=%0d", scalar_fast_m_pair_count);
      $fdisplay(report_fd, "SCALAR_FAST_FAST_PAIR_COUNT=%0d", scalar_fast_fast_pair_count);
      $fdisplay(report_fd, "MAX_RETIRE_QUEUE_COUNT=%0d", max_retire_queue_count);
      $fdisplay(report_fd, "RETIRE_QUEUE_FULL_COUNT=%0d", retire_queue_full_count);
      $fdisplay(report_fd, "SCALAR_LOAD_PAIR_BLOCK_COUNT=%0d", scalar_load_pair_block_count);
      $fdisplay(report_fd, "SCALAR_LOAD_PAIR_BLOCK_ISSUE0_COUNT=%0d", scalar_load_pair_block_issue0_count);
      $fdisplay(report_fd, "SCALAR_LOAD_PAIR_BLOCK_POLICY_COUNT=%0d", scalar_load_pair_block_policy_count);
      $fdisplay(report_fd, "SCALAR_LOAD_PAIR_BLOCK_RETIRE_COUNT=%0d", scalar_load_pair_block_retire_count);
      $fdisplay(report_fd, "SCALAR_LOAD_PAIR_BLOCK_GPR_COUNT=%0d", scalar_load_pair_block_gpr_count);
      $fdisplay(report_fd, "SCALAR_LOAD_PAIR_BLOCK_STORE_ORDER_COUNT=%0d", scalar_load_pair_block_store_order_count);
      $fdisplay(report_fd, "SCALAR_LOAD_PAIR_BLOCK_LSU_COUNT=%0d", scalar_load_pair_block_lsu_count);
      $fdisplay(report_fd, "SCALAR_LOAD_PAIR_BLOCK_OTHER_COUNT=%0d", scalar_load_pair_block_other_count);
      $fdisplay(report_fd, "SCALAR_ISSUE_BLOCK_COUNT=%0d", scalar_issue_block_count);
      $fdisplay(report_fd, "SCALAR_ISSUE_BLOCK_REDIRECT_COUNT=%0d", scalar_issue_block_redirect_count);
      $fdisplay(report_fd, "SCALAR_ISSUE_BLOCK_CACHE_COUNT=%0d", scalar_issue_block_cache_count);
      $fdisplay(report_fd, "SCALAR_ISSUE_BLOCK_RETIRE_COUNT=%0d", scalar_issue_block_retire_count);
      $fdisplay(report_fd, "SCALAR_ISSUE_BLOCK_PRODUCER_COUNT=%0d", scalar_issue_block_producer_count);
      $fdisplay(report_fd, "SCALAR_ISSUE_BLOCK_GPR_COUNT=%0d", scalar_issue_block_gpr_count);
      $fdisplay(report_fd, "SCALAR_ISSUE_BLOCK_FPR_COUNT=%0d", scalar_issue_block_fpr_count);
      $fdisplay(report_fd, "SCALAR_ISSUE_BLOCK_FPU_COUNT=%0d", scalar_issue_block_fpu_count);
      $fdisplay(report_fd, "SCALAR_ISSUE_BLOCK_ALU_COUNT=%0d", scalar_issue_block_alu_count);
      $fdisplay(report_fd, "SCALAR_ISSUE_BLOCK_STORE_ORDER_COUNT=%0d", scalar_issue_block_store_order_count);
      $fdisplay(report_fd, "SCALAR_ISSUE_BLOCK_LSU_COUNT=%0d", scalar_issue_block_lsu_count);
      $fdisplay(report_fd, "SCALAR_ISSUE_BLOCK_SYSTEM_COUNT=%0d", scalar_issue_block_system_count);
      $fdisplay(report_fd, "SCALAR_ISSUE_BLOCK_OTHER_COUNT=%0d", scalar_issue_block_other_count);
      $fdisplay(report_fd, "MAX_LSU_STB_COUNT=%0d", max_lsu_stb_count);
      $fdisplay(report_fd, "MAX_LSU_LOADQ_COUNT=%0d", max_lsu_loadq_count);
      $fdisplay(report_fd, "DCACHE_HIT_UNDER_MISS_ACCEPT_COUNT=%0d",
                dcache_hit_under_miss_accept_count);
      $fdisplay(report_fd, "DCACHE_HIT_UNDER_MISS_COMPLETE_COUNT=%0d",
                dcache_hit_under_miss_complete_count);
      $fdisplay(report_fd, "DCACHE_HIT_QUEUE_FULL_COUNT=%0d",
                dcache_hit_queue_full_count);
      $fdisplay(report_fd, "MAX_DCACHE_HIT_QUEUE_COUNT=%0d",
                max_dcache_hit_queue_count);
      $fdisplay(report_fd, "DCACHE_LOOKUP_ACCEPT_COUNT=%0d",
                dcache_lookup_accept_count);
      $fdisplay(report_fd, "DCACHE_LOOKUP_LAUNCH_COUNT=%0d",
                dcache_lookup_launch_count);
      $fdisplay(report_fd, "DCACHE_LOOKUP_LANE1_LAUNCH_COUNT=%0d",
                dcache_lookup_lane1_launch_count);
      $fdisplay(report_fd, "DCACHE_LOOKUP_BYPASS_COUNT=%0d",
                dcache_lookup_bypass_count);
      $fdisplay(report_fd, "DCACHE_LOOKUP_CAPTURE_COUNT=%0d",
                dcache_lookup_capture_count);
      $fdisplay(report_fd, "DCACHE_LOOKUP_OCCUPANCY1_CYCLES=%0d",
                dcache_lookup_occupancy1_cycles);
      $fdisplay(report_fd, "DCACHE_LOOKUP_OCCUPANCY2_CYCLES=%0d",
                dcache_lookup_occupancy2_cycles);
      $fdisplay(report_fd, "DCACHE_LOOKUP_PHASE_WAIT_CYCLES=%0d",
                dcache_lookup_phase_wait_cycles);
      $fdisplay(report_fd, "DCACHE_LOOKUP_HIT_QUEUE_WAIT_CYCLES=%0d",
                dcache_lookup_hit_queue_wait_cycles);
      $fdisplay(report_fd, "DCACHE_LOOKUP_MSHR_PARK_COUNT=%0d",
                dcache_lookup_mshr_park_count);
      $fdisplay(report_fd, "DCACHE_LOOKUP_PARKED_RETRY_CYCLES=%0d",
                dcache_lookup_parked_retry_cycles);
      $fdisplay(report_fd, "DCACHE_LOOKUP_BACKEND_PAUSE_CYCLES=%0d",
                dcache_lookup_backend_pause_cycles);
      $fdisplay(report_fd, "LSU_LOADREQ_FIFO_FULL_COUNT=%0d",
                lsu_loadreq_fifo_full_count);
      $fdisplay(report_fd, "MAX_LSU_LOADREQ_FIFO_COUNT=%0d",
                max_lsu_loadreq_fifo_count);
      $fdisplay(report_fd, "DMA_MAX_ARLEN=%0d", dma_max_arlen);
      $fdisplay(report_fd, "PRE_TOKEN_STALL_COUNT=%0d", pre_token_stall_count);
      $fdisplay(report_fd, "PRE_TOKEN_STALL_HOLD_COUNT=%0d", pre_token_stall_hold_count);
      $fdisplay(report_fd, "PRE_TOKEN_STALL_ISSUE_WINDOW_COUNT=%0d", pre_token_stall_issue_window_count);
      $fdisplay(report_fd, "PRE_TOKEN_STALL_PIPE_BUSY_COUNT=%0d", pre_token_stall_pipe_busy_count);
      $fdisplay(report_fd, "PRE_TOKEN_STALL_SCALAR_READY_COUNT=%0d", pre_token_stall_scalar_ready_count);
      $fdisplay(report_fd, "PRE_TOKEN_STALL_CAPTURE_COUNT=%0d", pre_token_stall_capture_count);
      $fdisplay(report_fd, "PRE_TOKEN_STALL_ACCEL_READY_COUNT=%0d", pre_token_stall_accel_ready_count);
      $fdisplay(report_fd, "PRE_TOKEN_STALL_UNSUPPORTED_COUNT=%0d", pre_token_stall_unsupported_count);
      $fdisplay(report_fd, "PRE_TOKEN_STALL_OTHER_COUNT=%0d", pre_token_stall_other_count);
      $fdisplay(report_fd, "TIMING_WINDOW_ENABLED=%0d", timing_window_enable);
      $fdisplay(report_fd, "TIMING_WINDOW_SEEN_START=%0d", timing_window_seen_start);
      $fdisplay(report_fd, "TIMING_WINDOW_SEEN_STOP=%0d", timing_window_seen_stop);
      $fdisplay(report_fd, "TIMING_WINDOW_CYCLE_COUNT=%0d", timing_window_cycle_count);
      $fdisplay(report_fd, "TIMING_WINDOW_PRODUCTIVE_CYCLE_COUNT=%0d", timing_window_productive_cycle_count);
      $fdisplay(report_fd, "TIMING_WINDOW_ZERO_RETIRE_COUNT=%0d", timing_window_zero_retire_count);
      $fdisplay(report_fd, "TIMING_NO_RETIRE_REDIRECT_FRONTEND_REFILL_COUNT=%0d", timing_no_retire_redirect_frontend_refill_count);
      $fdisplay(report_fd, "TIMING_NO_RETIRE_ICACHE_REFILL_COUNT=%0d", timing_no_retire_icache_refill_count);
      $fdisplay(report_fd, "TIMING_NO_RETIRE_HEAD_GPR_COUNT=%0d", timing_no_retire_head_gpr_count);
      $fdisplay(report_fd, "TIMING_HEAD_GPR_PRODUCER_QUEUE_COUNT=%0d", timing_head_gpr_producer_queue_count);
      $fdisplay(report_fd, "TIMING_HEAD_GPR_RAW_SRC0_COUNT=%0d", timing_head_gpr_raw_src0_count);
      $fdisplay(report_fd, "TIMING_HEAD_GPR_RAW_SRC1_COUNT=%0d", timing_head_gpr_raw_src1_count);
      $fdisplay(report_fd, "TIMING_HEAD_GPR_RAW_SRC2_COUNT=%0d", timing_head_gpr_raw_src2_count);
      $fdisplay(report_fd, "TIMING_HEAD_GPR_WAW_DST_COUNT=%0d", timing_head_gpr_waw_dst_count);
      $fdisplay(report_fd, "TIMING_HEAD_GPR_OTHER_COUNT=%0d", timing_head_gpr_other_count);
      $fdisplay(report_fd, "TIMING_RAW_SRC0_PRODUCER_ALU_COUNT=%0d", timing_raw_src0_producer_alu_count);
      $fdisplay(report_fd, "TIMING_RAW_SRC0_PRODUCER_LOAD_COUNT=%0d", timing_raw_src0_producer_load_count);
      $fdisplay(report_fd, "TIMING_RAW_SRC0_PRODUCER_MUL_COUNT=%0d", timing_raw_src0_producer_mul_count);
      $fdisplay(report_fd, "TIMING_RAW_SRC0_PRODUCER_SYSTEM_COUNT=%0d", timing_raw_src0_producer_system_count);
      $fdisplay(report_fd, "TIMING_RAW_SRC0_PRODUCER_OTHER_COUNT=%0d", timing_raw_src0_producer_other_count);
      $fdisplay(report_fd, "TIMING_RAW_SRC0_AGE_HIST=%0d,%0d,%0d,%0d",
                timing_raw_src0_age0_count, timing_raw_src0_age1_count,
                timing_raw_src0_age2_count, timing_raw_src0_age3plus_count);
      $fdisplay(report_fd, "TIMING_M_ISSUE_KIND_HIST=%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                timing_m_issue_mul64_count, timing_m_issue_mulh64_count,
                timing_m_issue_mulw_count, timing_m_issue_div64_count,
                timing_m_issue_rem64_count, timing_m_issue_divw_count,
                timing_m_issue_remw_count);
      $fdisplay(report_fd, "TIMING_M_RAW_KIND_HIST=%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                timing_m_raw_mul64_count, timing_m_raw_mulh64_count,
                timing_m_raw_mulw_count, timing_m_raw_div64_count,
                timing_m_raw_rem64_count, timing_m_raw_divw_count,
                timing_m_raw_remw_count, timing_m_raw_other_count);
      $fdisplay(report_fd, "TIMING_M_RAW_REMAINING_HIST=%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                timing_m_raw_remaining1_count, timing_m_raw_remaining2_count,
                timing_m_raw_remaining3_count, timing_m_raw_remaining4_count,
                timing_m_raw_remaining5_count,
                timing_m_raw_remaining6_count,
                timing_m_raw_remaining7_count,
                timing_m_raw_remaining8_count,
                timing_m_raw_remaining9_16_count,
                timing_m_raw_remaining17_32_count,
                timing_m_raw_state_mismatch_count);
      $fdisplay(report_fd, "MUL_BUSY_CYCLES=%0d", mul_busy_cycles);
      $fdisplay(report_fd, "MUL_BLOCKED_M_REQUEST_COUNT=%0d",
                mul_blocked_m_request_count);
      $fdisplay(report_fd, "MUL_BLOCKED_M_REQUEST_CYCLES=%0d",
                mul_blocked_m_request_cycles);
      $fdisplay(report_fd, "MUL_BLOCKED_MULW_REQUEST_COUNT=%0d",
                mul_blocked_mulw_request_count);
      $fdisplay(report_fd, "MUL_BLOCKED_OTHER_REQUEST_COUNT=%0d",
                mul_blocked_other_request_count);
      $fdisplay(report_fd, "MUL_BLOCKED_MAX_RUN=%0d", mul_blocked_max_run);
      $fdisplay(report_fd, "MUL_ISSUE_WORD_COUNT=%0d", mul_issue_word_count);
      $fdisplay(report_fd, "MUL_ISSUE_LOW_PARTIAL_HIST=%0d,%0d,%0d",
                mul_issue_low_one_partial_count,
                mul_issue_low_two_partial_count,
                mul_issue_low_three_partial_count);
      $fdisplay(report_fd, "MUL_ISSUE_LOW_TWO_PARTIAL_DIRECTION=%0d,%0d",
                mul_issue_low_two_lh_count, mul_issue_low_two_hl_count);
      $fdisplay(report_fd, "MUL_ISSUE_LOW_BOTH_SIGNEXT32_COUNT=%0d",
                mul_issue_low_both_signext32_count);
      $fdisplay(report_fd, "MUL_ISSUE_HIGH_COUNT=%0d", mul_issue_high_count);
      $fdisplay(report_fd, "TIMING_YOUNGER_LOAD_VISIBLE_COUNT=%0d", timing_younger_load_visible_count);
      $fdisplay(report_fd, "TIMING_YOUNGER_LOAD_ELIGIBLE_COUNT=%0d", timing_younger_load_eligible_count);
      $fdisplay(report_fd, "TIMING_YOUNGER_LOAD_ELIGIBLE_HEAD1_COUNT=%0d", timing_younger_load_eligible_head1_count);
      $fdisplay(report_fd, "TIMING_YOUNGER_LOAD_BLOCK_GPR_COUNT=%0d", timing_younger_load_block_gpr_count);
      $fdisplay(report_fd, "TIMING_YOUNGER_LOAD_BLOCK_DEPENDENCY_COUNT=%0d", timing_younger_load_block_dependency_count);
      $fdisplay(report_fd, "TIMING_YOUNGER_LOAD_BLOCK_MEMORY_ORDER_COUNT=%0d", timing_younger_load_block_memory_order_count);
      $fdisplay(report_fd, "TIMING_YOUNGER_LOAD_BLOCK_LSU_COUNT=%0d", timing_younger_load_block_lsu_count);
      $fdisplay(report_fd, "TIMING_YOUNGER_LOAD_BLOCK_RETIRE_COUNT=%0d", timing_younger_load_block_retire_count);
      $fdisplay(report_fd, "TIMING_YOUNGER_LOAD_BLOCK_OTHER_COUNT=%0d", timing_younger_load_block_other_count);
      $fdisplay(report_fd, "TIMING_NO_RETIRE_LSU_COUNT=%0d", timing_no_retire_lsu_count);
      $fdisplay(report_fd, "TIMING_WAW_COMPLETE_MATCH_COUNT=%0d",
                timing_waw_complete_match_count);
      $fdisplay(report_fd, "TIMING_WAW_COMPLETE_KIND_HIST=%0d,%0d,%0d,%0d",
                timing_waw_complete_load_count, timing_waw_complete_mul_count,
                timing_waw_complete_fast0_count, timing_waw_complete_fast1_count);
      $fdisplay(report_fd, "TIMING_WAW_PRODUCER_HIST=%0d,%0d,%0d,%0d",
                timing_waw_producer_alu_count, timing_waw_producer_load_count,
                timing_waw_producer_mul_count, timing_waw_producer_other_count);
      $fdisplay(report_fd, "TIMING_WAW_STALL_RUN_COUNT_MAX=%0d,%0d",
                timing_waw_stall_run_count, timing_waw_stall_max_run);
      $fdisplay(report_fd, "TIMING_LSU_STALL_HIST=%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                timing_lsu_head_store_capacity_count,
                timing_lsu_head_load_capacity_count,
                timing_lsu_head_pipe_count,
                timing_lsu_response_backpressure_count,
                timing_lsu_store_drain_backend_count,
                timing_lsu_load_request_backend_count,
                timing_lsu_mshr_count,
                timing_lsu_loadq_wait_count,
                timing_lsu_store_buffer_wait_count,
                timing_lsu_other_count);
      $fdisplay(report_fd, "TIMING_NO_RETIRE_RETIRE_FULL_COUNT=%0d", timing_no_retire_retire_full_count);
      $fdisplay(report_fd, "TIMING_NO_RETIRE_BACKEND_RESOURCE_COUNT=%0d", timing_no_retire_backend_resource_count);
      $fdisplay(report_fd, "TIMING_NO_RETIRE_OTHER_COUNT=%0d", timing_no_retire_other_count);
      $fdisplay(report_fd, "TIMING_REDIRECT_COUNT=%0d", timing_redirect_count);
      $fdisplay(report_fd, "TIMING_REDIRECT_TO_REQ_SUM_MAX=%0d,%0d",
                timing_redirect_to_req_sum, timing_redirect_to_req_max);
      $fdisplay(report_fd, "TIMING_REDIRECT_TO_RESP_SUM_MAX=%0d,%0d",
                timing_redirect_to_resp_sum, timing_redirect_to_resp_max);
      $fdisplay(report_fd, "TIMING_REDIRECT_TO_PACKET_SUM_MAX=%0d,%0d",
                timing_redirect_to_packet_sum, timing_redirect_to_packet_max);
      $fdisplay(report_fd, "TIMING_REDIRECT_TO_FIFO_SUM_MAX=%0d,%0d",
                timing_redirect_to_fifo_sum, timing_redirect_to_fifo_max);
      $fdisplay(report_fd, "TIMING_REDIRECT_TO_TOKEN_SUM=%0d", timing_redirect_to_token_sum);
      $fdisplay(report_fd, "TIMING_REDIRECT_TO_TOKEN_MAX=%0d", timing_redirect_to_token_max);
      $fdisplay(report_fd, "TIMING_REDIRECT_TO_TOKEN_HIST=%0d,%0d,%0d,%0d,%0d,%0d",
                timing_redirect_to_token_0_count, timing_redirect_to_token_1_count,
                timing_redirect_to_token_2_count, timing_redirect_to_token_3_count,
                timing_redirect_to_token_4_count, timing_redirect_to_token_5plus_count);
      $fdisplay(report_fd, "TIMING_REDIRECT_TO_ISSUE_SUM=%0d", timing_redirect_to_issue_sum);
      $fdisplay(report_fd, "TIMING_REDIRECT_TO_ISSUE_MAX=%0d", timing_redirect_to_issue_max);
      $fdisplay(report_fd, "TIMING_REDIRECT_TO_ISSUE_HIST=%0d,%0d,%0d,%0d,%0d,%0d",
                timing_redirect_to_issue_0_count, timing_redirect_to_issue_1_count,
                timing_redirect_to_issue_2_count, timing_redirect_to_issue_3_count,
                timing_redirect_to_issue_4_count, timing_redirect_to_issue_5plus_count);
      $fdisplay(report_fd, "TIMING_CONTROL_ISSUE_COUNTS=%0d,%0d,%0d",
                timing_control_branch_issue_count, timing_control_jal_issue_count,
                timing_control_jalr_issue_count);
      $fdisplay(report_fd, "TIMING_CONTROL_TAKEN_COUNTS=%0d,%0d,%0d",
                timing_control_branch_taken_count, timing_control_jal_taken_count,
                timing_control_jalr_taken_count);
      $fdisplay(report_fd, "TIMING_EARLY_REDIRECT_REQ=%0d,%0d,%0d",
                timing_early_redirect_req_launchable_count,
                timing_early_redirect_req_block_outstanding_count,
                timing_early_redirect_req_block_icache_count);
      $fdisplay(report_fd, "TIMING_EARLY_REDIRECT_TARGET_PRESENT=%0d,%0d,%0d",
                timing_early_redirect_target_outstanding_count,
                timing_early_redirect_target_primary_count,
                timing_early_redirect_target_skid_count);
      $fdisplay(report_fd, "TIMING_REDIRECT_TOKEN_BYPASS_SHAPE=%0d,%0d,%0d,%0d",
                timing_redirect_scalar32_empty_parcel_count,
                timing_redirect_edge64_empty_parcel_count,
                timing_redirect_scalar32_busy_parcel_count,
                timing_redirect_edge64_busy_parcel_count);
      $fdisplay(report_fd, "SETIN_READY_TARGET_STALL_COUNT=%0d", setin_ready_target_stall_count);
      $fdisplay(report_fd, "TENSOR_COMMAND_ACCEPT_STALL_COUNT=%0d", tensor_command_accept_stall_count);
      $fdisplay(report_fd, "TENSOR_ISSUE_STALL_COUNT=%0d", tensor_issue_stall_count);
      $fdisplay(report_fd, "TENSOR_ISSUE_SETIN_STALL_COUNT=%0d", tensor_issue_setin_stall_count);
      $fdisplay(report_fd, "TENSOR_ISSUE_SETOUT_STALL_COUNT=%0d", tensor_issue_setout_stall_count);
      $fdisplay(report_fd, "TENSOR_ISSUE_SETPSUM_STALL_COUNT=%0d", tensor_issue_setpsum_stall_count);
      $fdisplay(report_fd, "TENSOR_ISSUE_START_STALL_COUNT=%0d", tensor_issue_start_stall_count);
      $fdisplay(report_fd, "TENSOR_ISSUE_SYNC_STALL_COUNT=%0d", tensor_issue_sync_stall_count);
      $fdisplay(report_fd, "TENSOR_ISSUE_WLD_CIRCULAR_STALL_COUNT=%0d", tensor_issue_wld_circular_stall_count);
      $fdisplay(report_fd, "TENSOR_ISSUE_OTHER_STALL_COUNT=%0d", tensor_issue_other_stall_count);
      $fdisplay(report_fd, "CIRCULAR_WLD_EMPTY_STALL_COUNT=%0d", circular_wld_empty_stall_count);
      $fdisplay(report_fd, "CIRCULAR_WLD_PIPE_STALL_COUNT=%0d", circular_wld_pipe_stall_count);
      $fdisplay(report_fd, "CIRCULAR_DMA_BUSY_WAIT_COUNT=%0d", circular_dma_busy_wait_count);
      $fdisplay(report_fd, "CIRCULAR_DMA_RING_FULL_WAIT_COUNT=%0d", circular_dma_ring_full_wait_count);
      $fdisplay(report_fd, "CIRCULAR_DMA_INFLIGHT_COUNT=%0d", circular_dma_inflight_count);
      $fdisplay(report_fd, "CIRCULAR_DMA_LAUNCH_COUNT=%0d", circular_dma_launch_count);
      $fdisplay(report_fd, "CIRCULAR_DMA_DONE_COUNT=%0d", circular_dma_done_count);
      $fdisplay(report_fd, "CIRCULAR_WLD_CONSUME_COUNT=%0d", circular_wld_consume_count);
      $fdisplay(report_fd, "CIRCULAR_MAX_OCCUPANCY=%0d", circular_max_occupancy);
      $fdisplay(report_fd, "CYCLE=%0d", cycle);
      $fdisplay(report_fd, "X30=%0d", dut.core_top.base.scalar_pipe.gpr[30]);
      $fdisplay(report_fd, "X31=%0d", dut.core_top.base.scalar_pipe.gpr[31]);
      $fclose(report_fd);
    end
  endtask

  task dump_memory_range;
    reg [127:0] dump_word;
    reg [7:0] dump_byte;
  begin
    if (dump_len > 0) begin
      dump_fd = $fopen(dump_path, "w");
      if (dump_fd == 0) begin
        $display("EDGE_SOC_VVP unable to open dump file: %0s", dump_path);
        finish_sim(1);
      end
      for (dump_i = 0; dump_i < dump_len; dump_i = dump_i + 1) begin
        dump_word_i = (dump_base + dump_i) >> 4;
        dump_byte_i = (dump_base + dump_i) & 15;
        dump_word = dut.soc_ram.mem[dump_word_i];
        dump_byte = dump_word[dump_byte_i * 8 +: 8];
        $fdisplay(dump_fd, "%02x", dump_byte);
      end
      $fclose(dump_fd);
    end
  end
  endtask

  initial begin : edge_soc_vvp_main
    clk = 1'b0;
    rst_b = 1'b0;
    core_start = 1'b0;
    core_force_stop = 1'b0;
    core_boot_pc = {ADDR_WIDTH{1'b0}};
    sim_done = 1'b0;
    max_cycles = 1000;
    pass_retire_count = 0;
    scalar_lane0_retire_count = 0;
    scalar_lane1_retire_count = 0;
    accel_lane_retire_count = 0;
    min_dtcm_load_count = 0;
    min_dtcm_store_count = 0;
    min_dma_arlen = 0;
    pass_on_ebreak = 0;
    pass_on_csr_break = 0;
    retired_total = 0;
    retired_this_cycle = 0;
    expect_dtcm_scalar_lsu = 0;
    expect_dma_start = 0;
    expect_scalar_dma_start = 0;
    expect_tensor_control = 0;
    expect_tensor_start = 0;
    expect_tensor_sync = 0;
    expect_tensor_matvec64_1token_tiled_output = 0;
    expect_tensor_tile8x8_stream64tokens_output = 0;
    expect_tensor_matmul64x64_64tokens_tiled_output = 0;
    expect_tensor_matmul64x64_64tokens_tiled_permuted_output = 0;
    expect_tensor_matmul64x64_128tokens_tiled_output = 0;
    expect_tensor_matmul512x512_32tokens_transpose_output = 0;
    expect_scalar_cache_ops = 0;
    expect_scalar_cache_clean = 0;
    dtcm_store_count = 0;
    dtcm_load_count = 0;
    dtcm_load_resp_count = 0;
    scalar_dma_start_count = 0;
    tensor_dma_start_count = 0;
    tensor_control_count = 0;
    tensor_start_count = 0;
    tensor_start_full_count = 0;
    tensor_start_tile_count = 0;
    tensor_sync_count = 0;
    tensor_start_accept_count = 0;
    tensor_start_accept_run_sum = 0;
    tensor_start_accept_run_max = 0;
    tensor_stream_out_push_count = 0;
    tensor_next_i_prefetch_accept_count = 0;
    tensor_next_psum_prefetch_accept_count = 0;
    tensor_engine_compute_valid_count = 0;
    tensor_engine_compute_busy_count = 0;
    tensor_engine_i_not_owned_count = 0;
    tensor_engine_psum_not_owned_count = 0;
    tensor_engine_out_not_owned_count = 0;
    tensor_engine_i_output_conflict_count = 0;
    tensor_engine_psum_output_conflict_count = 0;
    tensor_engine_output_write_count = 0;
    tensor_queued_handoff_count = 0;
    tensor_engine_start_count = 0;
    dma_start_count = 0;
    scalar_cache_clean_count = 0;
    scalar_cache_invalidate_count = 0;
    scalar_load_pair_count = 0;
    scalar_store_pair_count = 0;
    scalar_m_fast_pair_count = 0;
    scalar_fast_m_pair_count = 0;
    scalar_fast_fast_pair_count = 0;
    max_retire_queue_count = 0;
    retire_queue_full_count = 0;
    scalar_load_pair_block_count = 0;
    scalar_load_pair_block_issue0_count = 0;
    scalar_load_pair_block_policy_count = 0;
    scalar_load_pair_block_retire_count = 0;
    scalar_load_pair_block_gpr_count = 0;
    scalar_load_pair_block_store_order_count = 0;
    scalar_load_pair_block_lsu_count = 0;
    scalar_load_pair_block_other_count = 0;
    scalar_issue_block_count = 0;
    scalar_issue_block_redirect_count = 0;
    scalar_issue_block_cache_count = 0;
    scalar_issue_block_retire_count = 0;
    scalar_issue_block_producer_count = 0;
    scalar_issue_block_gpr_count = 0;
    scalar_issue_block_fpr_count = 0;
    scalar_issue_block_fpu_count = 0;
    scalar_issue_block_alu_count = 0;
    scalar_issue_block_store_order_count = 0;
    scalar_issue_block_lsu_count = 0;
    scalar_issue_block_system_count = 0;
    scalar_issue_block_other_count = 0;
    max_lsu_stb_count = 0;
    max_lsu_loadq_count = 0;
    dcache_hit_under_miss_accept_count = 0;
    dcache_hit_under_miss_complete_count = 0;
    dcache_hit_queue_full_count = 0;
    max_dcache_hit_queue_count = 0;
    dcache_lookup_accept_count = 0;
    dcache_lookup_launch_count = 0;
    dcache_lookup_lane1_launch_count = 0;
    dcache_lookup_bypass_count = 0;
    dcache_lookup_capture_count = 0;
    dcache_lookup_occupancy1_cycles = 0;
    dcache_lookup_occupancy2_cycles = 0;
    dcache_lookup_phase_wait_cycles = 0;
    dcache_lookup_hit_queue_wait_cycles = 0;
    dcache_lookup_mshr_park_count = 0;
    dcache_lookup_parked_retry_cycles = 0;
    dcache_lookup_backend_pause_cycles = 0;
    lsu_loadreq_fifo_full_count = 0;
    max_lsu_loadreq_fifo_count = 0;
    dma_max_arlen = 0;
    pre_token_stall_count = 0;
    pre_token_stall_hold_count = 0;
    pre_token_stall_issue_window_count = 0;
    pre_token_stall_pipe_busy_count = 0;
    pre_token_stall_scalar_ready_count = 0;
    pre_token_stall_capture_count = 0;
    pre_token_stall_accel_ready_count = 0;
    pre_token_stall_unsupported_count = 0;
    pre_token_stall_other_count = 0;
    timing_window_cycle_count = 0;
    timing_window_productive_cycle_count = 0;
    timing_window_zero_retire_count = 0;
    timing_no_retire_redirect_frontend_refill_count = 0;
    timing_no_retire_icache_refill_count = 0;
    timing_no_retire_head_gpr_count = 0;
    timing_head_gpr_producer_queue_count = 0;
    timing_head_gpr_raw_src0_count = 0;
    timing_head_gpr_raw_src1_count = 0;
    timing_head_gpr_raw_src2_count = 0;
    timing_head_gpr_waw_dst_count = 0;
    timing_head_gpr_other_count = 0;
    timing_raw_src0_producer_alu_count = 0;
    timing_raw_src0_producer_load_count = 0;
    timing_raw_src0_producer_mul_count = 0;
    timing_raw_src0_producer_system_count = 0;
    timing_raw_src0_producer_other_count = 0;
    timing_raw_src0_age0_count = 0;
    timing_raw_src0_age1_count = 0;
    timing_raw_src0_age2_count = 0;
    timing_raw_src0_age3plus_count = 0;
    timing_m_issue_mul64_count = 0;
    timing_m_issue_mulh64_count = 0;
    timing_m_issue_mulw_count = 0;
    timing_m_issue_div64_count = 0;
    timing_m_issue_rem64_count = 0;
    timing_m_issue_divw_count = 0;
    timing_m_issue_remw_count = 0;
    timing_m_raw_mul64_count = 0;
    timing_m_raw_mulh64_count = 0;
    timing_m_raw_mulw_count = 0;
    timing_m_raw_div64_count = 0;
    timing_m_raw_rem64_count = 0;
    timing_m_raw_divw_count = 0;
    timing_m_raw_remw_count = 0;
    timing_m_raw_other_count = 0;
    timing_m_raw_remaining1_count = 0;
    timing_m_raw_remaining2_count = 0;
    timing_m_raw_remaining3_count = 0;
    timing_m_raw_remaining4_count = 0;
    timing_m_raw_remaining5_count = 0;
    timing_m_raw_remaining6_count = 0;
    timing_m_raw_remaining7_count = 0;
    timing_m_raw_remaining8_count = 0;
    timing_m_raw_remaining9_16_count = 0;
    timing_m_raw_remaining17_32_count = 0;
    timing_m_raw_state_mismatch_count = 0;
    mul_busy_cycles = 0;
    mul_blocked_m_request_count = 0;
    mul_blocked_m_request_cycles = 0;
    mul_blocked_mulw_request_count = 0;
    mul_blocked_other_request_count = 0;
    mul_blocked_current_run = 0;
    mul_blocked_max_run = 0;
    mul_issue_word_count = 0;
    mul_issue_low_one_partial_count = 0;
    mul_issue_low_two_partial_count = 0;
    mul_issue_low_two_lh_count = 0;
    mul_issue_low_two_hl_count = 0;
    mul_issue_low_three_partial_count = 0;
    mul_issue_low_both_signext32_count = 0;
    mul_issue_high_count = 0;
    mul_blocked_request_active = 1'b0;
    mul_blocked_request_seq = 8'd0;
    mul_blocked_request_epoch = 4'd0;
    timing_younger_load_visible_count = 0;
    timing_younger_load_eligible_count = 0;
    timing_younger_load_eligible_head1_count = 0;
    timing_younger_load_block_gpr_count = 0;
    timing_younger_load_block_dependency_count = 0;
    timing_younger_load_block_memory_order_count = 0;
    timing_younger_load_block_lsu_count = 0;
    timing_younger_load_block_retire_count = 0;
    timing_younger_load_block_other_count = 0;
    timing_no_retire_lsu_count = 0;
    timing_waw_complete_match_count = 0;
    timing_waw_complete_load_count = 0;
    timing_waw_complete_mul_count = 0;
    timing_waw_complete_fast0_count = 0;
    timing_waw_complete_fast1_count = 0;
    timing_waw_producer_alu_count = 0;
    timing_waw_producer_load_count = 0;
    timing_waw_producer_mul_count = 0;
    timing_waw_producer_other_count = 0;
    timing_waw_stall_run_count = 0;
    timing_waw_stall_max_run = 0;
    timing_waw_stall_current_run = 0;
    timing_lsu_head_store_capacity_count = 0;
    timing_lsu_head_load_capacity_count = 0;
    timing_lsu_head_pipe_count = 0;
    timing_lsu_response_backpressure_count = 0;
    timing_lsu_store_drain_backend_count = 0;
    timing_lsu_load_request_backend_count = 0;
    timing_lsu_mshr_count = 0;
    timing_lsu_loadq_wait_count = 0;
    timing_lsu_store_buffer_wait_count = 0;
    timing_lsu_other_count = 0;
    timing_no_retire_retire_full_count = 0;
    timing_no_retire_backend_resource_count = 0;
    timing_no_retire_other_count = 0;
    timing_redirect_count = 0;
    timing_redirect_to_req_sum = 0;
    timing_redirect_to_req_max = 0;
    timing_redirect_to_resp_sum = 0;
    timing_redirect_to_resp_max = 0;
    timing_redirect_to_packet_sum = 0;
    timing_redirect_to_packet_max = 0;
    timing_redirect_to_fifo_sum = 0;
    timing_redirect_to_fifo_max = 0;
    timing_redirect_to_token_sum = 0;
    timing_redirect_to_token_max = 0;
    timing_redirect_to_token_0_count = 0;
    timing_redirect_to_token_1_count = 0;
    timing_redirect_to_token_2_count = 0;
    timing_redirect_to_token_3_count = 0;
    timing_redirect_to_token_4_count = 0;
    timing_redirect_to_token_5plus_count = 0;
    timing_redirect_to_issue_sum = 0;
    timing_redirect_to_issue_max = 0;
    timing_redirect_to_issue_0_count = 0;
    timing_redirect_to_issue_1_count = 0;
    timing_redirect_to_issue_2_count = 0;
    timing_redirect_to_issue_3_count = 0;
    timing_redirect_to_issue_4_count = 0;
    timing_redirect_to_issue_5plus_count = 0;
    timing_control_branch_issue_count = 0;
    timing_control_jal_issue_count = 0;
    timing_control_jalr_issue_count = 0;
    timing_control_branch_taken_count = 0;
    timing_control_jal_taken_count = 0;
    timing_control_jalr_taken_count = 0;
    timing_early_redirect_req_launchable_count = 0;
    timing_early_redirect_req_block_outstanding_count = 0;
    timing_early_redirect_req_block_icache_count = 0;
    timing_early_redirect_target_outstanding_count = 0;
    timing_early_redirect_target_primary_count = 0;
    timing_early_redirect_target_skid_count = 0;
    timing_redirect_scalar32_empty_parcel_count = 0;
    timing_redirect_edge64_empty_parcel_count = 0;
    timing_redirect_scalar32_busy_parcel_count = 0;
    timing_redirect_edge64_busy_parcel_count = 0;
    setin_ready_target_stall_count = 0;
    tensor_command_accept_stall_count = 0;
    tensor_issue_stall_count = 0;
    tensor_issue_setin_stall_count = 0;
    tensor_issue_setout_stall_count = 0;
    tensor_issue_setpsum_stall_count = 0;
    tensor_issue_start_stall_count = 0;
    tensor_issue_sync_stall_count = 0;
    tensor_issue_wld_circular_stall_count = 0;
    tensor_issue_other_stall_count = 0;
    circular_wld_empty_stall_count = 0;
    circular_wld_pipe_stall_count = 0;
    circular_dma_busy_wait_count = 0;
    circular_dma_ring_full_wait_count = 0;
    circular_dma_inflight_count = 0;
    circular_dma_launch_count = 0;
    circular_dma_done_count = 0;
    circular_wld_consume_count = 0;
    circular_max_occupancy = 0;
    circular_occupancy = 0;
    expected_x31 = 64'hffff_ffff_ffff_ffff;
    expected_return = 64'hffff_ffff_ffff_ffff;
    report_return_value = 64'd1;
    matvec64_1token_tiled_output_ok = 1'b1;
    tile8x8_stream64tokens_output_ok = 1'b1;
    matmul64x64_64tokens_tiled_output_ok = 1'b1;
    matmul512x512_32tokens_transpose_output_ok = 1'b1;
    matmul64x64_128tokens_tiled_output_ok = 1'b1;
    report_path = "run_case.report";
    sim_console_path = "sim_console.log";
    sim_console_fd = 0;
    trace_path = "edge_debug_trace.log";
    trace_enable = 1'b0;
    trace_start_cycle = 0;
    trace_stop_cycle = 0;
    timing_window_enable = 1'b0;
    timing_window_active = 1'b0;
    timing_window_seen_start = 1'b0;
    timing_window_seen_stop = 1'b0;
    timing_start_configured = 1'b0;
    timing_stop_configured = 1'b0;
    timing_start_pc = {ADDR_WIDTH{1'b0}};
    timing_stop_pc = {ADDR_WIDTH{1'b0}};
    timing_redirect_wait_token = 1'b0;
    timing_redirect_wait_issue = 1'b0;
    timing_redirect_wait_req = 1'b0;
    timing_redirect_wait_resp = 1'b0;
    timing_redirect_wait_packet = 1'b0;
    timing_redirect_wait_fifo = 1'b0;
    timing_waw_stall_active = 1'b0;
    timing_redirect_req_latency = 0;
    timing_redirect_resp_latency = 0;
    timing_redirect_packet_latency = 0;
    timing_redirect_fifo_latency = 0;
    timing_redirect_token_latency = 0;
    timing_redirect_issue_latency = 0;
    for (timing_producer_i = 0; timing_producer_i < 32;
         timing_producer_i = timing_producer_i + 1) begin
      timing_gpr_producer_type[timing_producer_i] = TB_PRODUCER_OTHER;
      timing_gpr_producer_m_kind[timing_producer_i] = TB_M_KIND_OTHER;
      timing_gpr_producer_seq[timing_producer_i] = 8'd0;
    end
    fpu_vec_fd = 0;
    fpu_vec_count = 0;
    fpu_vec_seen = 0;
    fpu_vec_path = 0;

    if (!$value$plusargs("max_cycles=%d", max_cycles))
      max_cycles = 1000;
    if (!$value$plusargs("pass_retire_count=%d", pass_retire_count))
      pass_retire_count = 0;
    if (!$value$plusargs("min_dtcm_load_count=%d", min_dtcm_load_count))
      min_dtcm_load_count = 0;
    if (!$value$plusargs("min_dtcm_store_count=%d", min_dtcm_store_count))
      min_dtcm_store_count = 0;
    if (!$value$plusargs("min_dma_arlen=%d", min_dma_arlen))
      min_dma_arlen = 0;
    if ($test$plusargs("pass_on_ebreak"))
      pass_on_ebreak = 1;
    if ($test$plusargs("pass_on_csr_break"))
      pass_on_csr_break = 1;
    if (!$value$plusargs("expected_x31=%d", expected_x31))
      expected_x31 = 64'hffff_ffff_ffff_ffff;
    if (!$value$plusargs("expected_return=%d", expected_return))
      expected_return = 64'hffff_ffff_ffff_ffff;
    if (!$value$plusargs("run_case_report=%s", report_path))
      report_path = "run_case.report";
    if (!$value$plusargs("sim_console_file=%s", sim_console_path))
      sim_console_path = "sim_console.log";
    sim_console_fd = $fopen(sim_console_path, "w");
    if (sim_console_fd == 0) begin
      $display("EDGE_SOC_VVP unable to open software console: %0s",
               sim_console_path);
      finish_sim(1);
`ifdef VERILATOR_SIM
      disable edge_soc_vvp_main;
`endif
    end
    if (!$value$plusargs("dump_base=%h", dump_base))
      dump_base = 64'h0;
    if (!$value$plusargs("dump_len=%d", dump_len))
      dump_len = 0;
    if (!$value$plusargs("dump_file=%s", dump_path))
      dump_path = "output_dump.hex";
    if ($value$plusargs("timing_start_pc=%h", timing_start_pc))
      timing_start_configured = 1'b1;
    if ($value$plusargs("timing_stop_pc=%h", timing_stop_pc))
      timing_stop_configured = 1'b1;
    timing_window_enable = timing_start_configured && timing_stop_configured;
    if ($value$plusargs("edge_debug_trace_file=%s", trace_path))
      trace_enable = 1'b1;
    else if ($test$plusargs("edge_debug_trace"))
      trace_enable = 1'b1;
    if (!$value$plusargs("edge_debug_trace_start_cycle=%d", trace_start_cycle))
      trace_start_cycle = 0;
    if (!$value$plusargs("edge_debug_trace_stop_cycle=%d", trace_stop_cycle))
      trace_stop_cycle = 0;
    if ($value$plusargs("fpu_vec=%s", fpu_vec_path)) begin
      if (!$value$plusargs("fpu_vec_count=%d", fpu_vec_count))
        fpu_vec_count = 0;
      fpu_vec_fd = $fopen(fpu_vec_path, "r");
      if (fpu_vec_fd == 0) begin
        $display("EDGE_SOC_VVP unable to open FPU vector file: %0s", fpu_vec_path);
        finish_sim(1);
`ifdef VERILATOR_SIM
        disable edge_soc_vvp_main;
`endif
      end
    end
    if ($test$plusargs("expect_dtcm_scalar_lsu"))
      expect_dtcm_scalar_lsu = 1;
    if ($test$plusargs("expect_dma_start"))
      expect_dma_start = 1;
    if ($test$plusargs("expect_scalar_dma_start"))
      expect_scalar_dma_start = 1;
    if ($test$plusargs("expect_tensor_control"))
      expect_tensor_control = 1;
    if ($test$plusargs("expect_tensor_start"))
      expect_tensor_start = 1;
    if ($test$plusargs("expect_tensor_sync"))
      expect_tensor_sync = 1;
    if ($test$plusargs("expect_tensor_matvec64_1token_tiled_output"))
      expect_tensor_matvec64_1token_tiled_output = 1;
    if ($test$plusargs("expect_tensor_tile8x8_stream64tokens_output"))
      expect_tensor_tile8x8_stream64tokens_output = 1;
    if ($test$plusargs("expect_tensor_matmul64x64_64tokens_tiled_output"))
      expect_tensor_matmul64x64_64tokens_tiled_output = 1;
    if ($test$plusargs("expect_tensor_matmul64x64_64tokens_tiled_permuted_output"))
      expect_tensor_matmul64x64_64tokens_tiled_permuted_output = 1;
    if ($test$plusargs("expect_tensor_matmul64x64_128tokens_tiled_output"))
      expect_tensor_matmul64x64_128tokens_tiled_output = 1;
    if ($test$plusargs("expect_tensor_matmul512x512_32tokens_transpose_output"))
      expect_tensor_matmul512x512_32tokens_transpose_output = 1;
    if ($test$plusargs("expect_scalar_cache_ops"))
      expect_scalar_cache_ops = 1;
    if ($test$plusargs("expect_scalar_cache_clean"))
      expect_scalar_cache_clean = 1;

    if (trace_enable) begin
      trace_fd = $fopen(trace_path, "w");
      if (trace_fd == 0) begin
        $display("EDGE_SOC_VVP unable to open trace: %0s", trace_path);
        finish_sim(1);
`ifdef VERILATOR_SIM
        disable edge_soc_vvp_main;
`endif
      end
    end

    repeat (4) @(posedge clk);
    rst_b = 1'b1;
    @(negedge clk);
    core_start = 1'b1;
    @(negedge clk);
    core_start = 1'b0;

    for (cycle = 0; cycle < max_cycles; cycle = cycle + 1) begin
      @(posedge clk);
      #1;
      retired_this_cycle = 0;
      if (dut.core_top.base.tensor_command_accept)
        accel_lane_retire_count = accel_lane_retire_count + 1;
      if (dut.core_retire0_valid)
        retired_this_cycle = retired_this_cycle + 1;
      if (dut.core_top.base.retire1_valid)
        retired_this_cycle = retired_this_cycle + 1;
      retired_total = retired_total + retired_this_cycle;
      if (dut.core_retire0_valid)
        scalar_lane0_retire_count = scalar_lane0_retire_count + 1;
      if (dut.core_top.base.retire1_valid)
        scalar_lane1_retire_count = scalar_lane1_retire_count + 1;
      if (dut.core_top.base.scalar_pipe.issue_fire &&
          dut.core_top.base.scalar_pipe.issue_gpr_dst_candidate &&
          (dut.core_top.base.scalar_pipe.issue_inst[11:7] != 5'd0)) begin
        timing_gpr_producer_type[dut.core_top.base.scalar_pipe.issue_inst[11:7]] =
          tb_producer_type(dut.core_top.base.scalar_pipe.issue_inst);
        timing_gpr_producer_m_kind[dut.core_top.base.scalar_pipe.issue_inst[11:7]] =
          tb_m_kind(dut.core_top.base.scalar_pipe.issue_inst);
        timing_gpr_producer_seq[dut.core_top.base.scalar_pipe.issue_inst[11:7]] =
          dut.core_top.base.scalar_pipe.issue_seq_id;
      end
      if (dut.core_top.base.scalar_pipe.issue1_fire &&
          dut.core_top.base.scalar_pipe.issue1_gpr_dst_candidate &&
          (dut.core_top.base.scalar_pipe.issue1_inst[11:7] != 5'd0)) begin
        timing_gpr_producer_type[dut.core_top.base.scalar_pipe.issue1_inst[11:7]] =
          tb_producer_type(dut.core_top.base.scalar_pipe.issue1_inst);
        timing_gpr_producer_m_kind[dut.core_top.base.scalar_pipe.issue1_inst[11:7]] =
          tb_m_kind(dut.core_top.base.scalar_pipe.issue1_inst);
        timing_gpr_producer_seq[dut.core_top.base.scalar_pipe.issue1_inst[11:7]] =
          dut.core_top.base.scalar_pipe.issue1_seq_id;
      end
      if (timing_window_active &&
          !(timing_window_enable &&
            dut.core_top.base.scalar_pipe.issue_fire &&
            dut.core_top.base.scalar_pipe.is_cycle_csr_read &&
            (dut.core_top.base.scalar_pipe.issue_pc == timing_stop_pc))) begin
        timing_window_cycle_count = timing_window_cycle_count + 1;
        if (dut.core_top.base.scalar_pipe.issue_fire &&
            ((dut.core_top.base.scalar_pipe.issue_inst[6:0] == TB_OPCODE_BRANCH) ||
             (dut.core_top.base.scalar_pipe.issue_inst[6:0] == TB_OPCODE_JAL) ||
             (dut.core_top.base.scalar_pipe.issue_inst[6:0] == TB_OPCODE_JALR))) begin
          case (dut.core_top.base.scalar_pipe.issue_inst[6:0])
            TB_OPCODE_BRANCH:
              timing_control_branch_issue_count =
                timing_control_branch_issue_count + 1;
            TB_OPCODE_JAL:
              timing_control_jal_issue_count = timing_control_jal_issue_count + 1;
            default:
              timing_control_jalr_issue_count = timing_control_jalr_issue_count + 1;
          endcase
          if (dut.core_top.base.scalar_pipe.scalar_alu.fast_branch_taken) begin
            case (dut.core_top.base.scalar_pipe.issue_inst[6:0])
              TB_OPCODE_BRANCH:
                timing_control_branch_taken_count =
                  timing_control_branch_taken_count + 1;
              TB_OPCODE_JAL:
                timing_control_jal_taken_count = timing_control_jal_taken_count + 1;
              default:
                timing_control_jalr_taken_count = timing_control_jalr_taken_count + 1;
            endcase
            if (!dut.core_top.base.ifu_fetch.outstanding_valid_r ||
                dut.core_top.base.ifu_fetch.resp_fire) begin
              if (dut.core_top.base.ifu_cache_req_ready)
                timing_early_redirect_req_launchable_count =
                  timing_early_redirect_req_launchable_count + 1;
              else
                timing_early_redirect_req_block_icache_count =
                  timing_early_redirect_req_block_icache_count + 1;
            end else begin
              timing_early_redirect_req_block_outstanding_count =
                timing_early_redirect_req_block_outstanding_count + 1;
            end
            if (dut.core_top.base.ifu_fetch.outstanding_valid_r &&
                (dut.core_top.base.ifu_fetch.outstanding_block_pc_r ==
                 {dut.core_top.base.scalar_pipe.scalar_alu.fast_branch_target[ADDR_WIDTH-1:4],
                  4'b0000}))
              timing_early_redirect_target_outstanding_count =
                timing_early_redirect_target_outstanding_count + 1;
            if (dut.core_top.base.ifu_fetch.fetch_valid_r &&
                (dut.core_top.base.ifu_fetch.fetch_block_pc_r ==
                 {dut.core_top.base.scalar_pipe.scalar_alu.fast_branch_target[ADDR_WIDTH-1:4],
                  4'b0000}))
              timing_early_redirect_target_primary_count =
                timing_early_redirect_target_primary_count + 1;
            if (dut.core_top.base.ifu_fetch.skid_valid_r &&
                (dut.core_top.base.ifu_fetch.skid_block_pc_r ==
                 {dut.core_top.base.scalar_pipe.scalar_alu.fast_branch_target[ADDR_WIDTH-1:4],
                  4'b0000}))
              timing_early_redirect_target_skid_count =
                timing_early_redirect_target_skid_count + 1;
          end
        end
        if (dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.mul_busy_r)
          mul_busy_cycles = mul_busy_cycles + 1;
        if (timing_probe_mul_blocked) begin
          mul_blocked_m_request_cycles = mul_blocked_m_request_cycles + 1;
          if (!mul_blocked_request_active ||
              timing_probe_mul_blocked_seq != mul_blocked_request_seq ||
              timing_probe_mul_blocked_epoch != mul_blocked_request_epoch) begin
            mul_blocked_m_request_count = mul_blocked_m_request_count + 1;
            if (timing_probe_mul_blocked_is_word)
              mul_blocked_mulw_request_count =
                mul_blocked_mulw_request_count + 1;
            else
              mul_blocked_other_request_count =
                mul_blocked_other_request_count + 1;
            mul_blocked_request_active = 1'b1;
            mul_blocked_request_seq = timing_probe_mul_blocked_seq;
            mul_blocked_request_epoch = timing_probe_mul_blocked_epoch;
            mul_blocked_current_run = 1;
            if (mul_blocked_max_run < 1)
              mul_blocked_max_run = 1;
          end else begin
            mul_blocked_current_run = mul_blocked_current_run + 1;
            if (mul_blocked_current_run > mul_blocked_max_run)
              mul_blocked_max_run = mul_blocked_current_run;
          end
        end else begin
          mul_blocked_current_run = 0;
          if (timing_probe_mul_accept ||
              dut.core_top.base.scalar_pipe.redirect_kill_valid)
            mul_blocked_request_active = 1'b0;
        end
        if (timing_probe_mul_accept) begin
          if (timing_probe_mul_accept_word) begin
            mul_issue_word_count = mul_issue_word_count + 1;
          end else if (timing_probe_mul_accept_high) begin
            mul_issue_high_count = mul_issue_high_count + 1;
          end else begin
            if (timing_probe_mul_src0_upper_zero &&
                timing_probe_mul_src1_upper_zero)
              mul_issue_low_one_partial_count =
                mul_issue_low_one_partial_count + 1;
            else if (timing_probe_mul_src0_upper_zero ||
                     timing_probe_mul_src1_upper_zero) begin
              mul_issue_low_two_partial_count =
                mul_issue_low_two_partial_count + 1;
              if (timing_probe_mul_src0_upper_zero)
                mul_issue_low_two_lh_count = mul_issue_low_two_lh_count + 1;
              else
                mul_issue_low_two_hl_count = mul_issue_low_two_hl_count + 1;
            end
            else
              mul_issue_low_three_partial_count =
                mul_issue_low_three_partial_count + 1;
            if (timing_probe_mul_both_signext32)
              mul_issue_low_both_signext32_count =
                mul_issue_low_both_signext32_count + 1;
          end
        end
        if (dut.core_top.base.scalar_pipe.issue_fire &&
            (tb_producer_type(dut.core_top.base.scalar_pipe.issue_inst) ==
             TB_PRODUCER_MUL)) begin
          case (tb_m_kind(dut.core_top.base.scalar_pipe.issue_inst))
            TB_M_KIND_MUL64: timing_m_issue_mul64_count = timing_m_issue_mul64_count + 1;
            TB_M_KIND_MULH64: timing_m_issue_mulh64_count = timing_m_issue_mulh64_count + 1;
            TB_M_KIND_MULW: timing_m_issue_mulw_count = timing_m_issue_mulw_count + 1;
            TB_M_KIND_DIV64: timing_m_issue_div64_count = timing_m_issue_div64_count + 1;
            TB_M_KIND_REM64: timing_m_issue_rem64_count = timing_m_issue_rem64_count + 1;
            TB_M_KIND_DIVW: timing_m_issue_divw_count = timing_m_issue_divw_count + 1;
            TB_M_KIND_REMW: timing_m_issue_remw_count = timing_m_issue_remw_count + 1;
            default: begin end
          endcase
        end
        if (dut.core_top.base.scalar_pipe.issue1_fire &&
            (tb_producer_type(dut.core_top.base.scalar_pipe.issue1_inst) ==
             TB_PRODUCER_MUL)) begin
          case (tb_m_kind(dut.core_top.base.scalar_pipe.issue1_inst))
            TB_M_KIND_MUL64: timing_m_issue_mul64_count = timing_m_issue_mul64_count + 1;
            TB_M_KIND_MULH64: timing_m_issue_mulh64_count = timing_m_issue_mulh64_count + 1;
            TB_M_KIND_MULW: timing_m_issue_mulw_count = timing_m_issue_mulw_count + 1;
            TB_M_KIND_DIV64: timing_m_issue_div64_count = timing_m_issue_div64_count + 1;
            TB_M_KIND_REM64: timing_m_issue_rem64_count = timing_m_issue_rem64_count + 1;
            TB_M_KIND_DIVW: timing_m_issue_divw_count = timing_m_issue_divw_count + 1;
            TB_M_KIND_REMW: timing_m_issue_remw_count = timing_m_issue_remw_count + 1;
            default: begin end
          endcase
        end
        if (retired_this_cycle != 0) begin
          timing_window_productive_cycle_count =
            timing_window_productive_cycle_count + 1;
        end else begin
          timing_window_zero_retire_count = timing_window_zero_retire_count + 1;
          if (dut.core_top.base.scalar_pipe.redirect_kill_valid ||
              timing_redirect_wait_issue)
            timing_no_retire_redirect_frontend_refill_count =
              timing_no_retire_redirect_frontend_refill_count + 1;
          else if (dut.core_top.base.ifu_cache_debug_miss_pending)
            timing_no_retire_icache_refill_count =
              timing_no_retire_icache_refill_count + 1;
          else if (dut.core_top.base.frontend_scalar_valid &&
                   !dut.core_top.base.pipe_issue_ready &&
                   (!dut.core_top.base.scalar_pipe.producer_queue_issue_ready ||
                    (dut.core_top.base.scalar_pipe.issue_gpr_check_candidate &&
                     !dut.core_top.base.scalar_pipe.gpr_issue_ready)))
          begin
            timing_no_retire_head_gpr_count =
              timing_no_retire_head_gpr_count + 1;
            if (!dut.core_top.base.scalar_pipe.producer_queue_issue_ready)
              timing_head_gpr_producer_queue_count =
                timing_head_gpr_producer_queue_count + 1;
            else if (dut.core_top.base.scalar_pipe.gpr_wbt.src0_blocked) begin
              timing_head_gpr_raw_src0_count =
                timing_head_gpr_raw_src0_count + 1;
              case (timing_probe_src0_producer_type)
                TB_PRODUCER_ALU:
                  timing_raw_src0_producer_alu_count =
                    timing_raw_src0_producer_alu_count + 1;
                TB_PRODUCER_LOAD:
                  timing_raw_src0_producer_load_count =
                    timing_raw_src0_producer_load_count + 1;
                TB_PRODUCER_MUL: begin
                  timing_raw_src0_producer_mul_count =
                    timing_raw_src0_producer_mul_count + 1;
                  case (timing_probe_src0_m_kind)
                    TB_M_KIND_MUL64: timing_m_raw_mul64_count = timing_m_raw_mul64_count + 1;
                    TB_M_KIND_MULH64: timing_m_raw_mulh64_count = timing_m_raw_mulh64_count + 1;
                    TB_M_KIND_MULW: timing_m_raw_mulw_count = timing_m_raw_mulw_count + 1;
                    TB_M_KIND_DIV64: timing_m_raw_div64_count = timing_m_raw_div64_count + 1;
                    TB_M_KIND_REM64: timing_m_raw_rem64_count = timing_m_raw_rem64_count + 1;
                    TB_M_KIND_DIVW: timing_m_raw_divw_count = timing_m_raw_divw_count + 1;
                    TB_M_KIND_REMW: timing_m_raw_remw_count = timing_m_raw_remw_count + 1;
                    default: timing_m_raw_other_count = timing_m_raw_other_count + 1;
                  endcase
                  if (!timing_probe_m_state_match)
                    timing_m_raw_state_mismatch_count =
                      timing_m_raw_state_mismatch_count + 1;
                  else if (timing_probe_m_remaining == 6'd1)
                    timing_m_raw_remaining1_count = timing_m_raw_remaining1_count + 1;
                  else if (timing_probe_m_remaining == 6'd2)
                    timing_m_raw_remaining2_count = timing_m_raw_remaining2_count + 1;
                  else if (timing_probe_m_remaining == 6'd3)
                    timing_m_raw_remaining3_count = timing_m_raw_remaining3_count + 1;
                  else if (timing_probe_m_remaining == 6'd4)
                    timing_m_raw_remaining4_count = timing_m_raw_remaining4_count + 1;
                  else if (timing_probe_m_remaining == 6'd5)
                    timing_m_raw_remaining5_count = timing_m_raw_remaining5_count + 1;
                  else if (timing_probe_m_remaining == 6'd6)
                    timing_m_raw_remaining6_count = timing_m_raw_remaining6_count + 1;
                  else if (timing_probe_m_remaining == 6'd7)
                    timing_m_raw_remaining7_count = timing_m_raw_remaining7_count + 1;
                  else if (timing_probe_m_remaining == 6'd8)
                    timing_m_raw_remaining8_count = timing_m_raw_remaining8_count + 1;
                  else if (timing_probe_m_remaining <= 6'd16)
                    timing_m_raw_remaining9_16_count =
                      timing_m_raw_remaining9_16_count + 1;
                  else
                    timing_m_raw_remaining17_32_count =
                      timing_m_raw_remaining17_32_count + 1;
                end
                TB_PRODUCER_SYSTEM:
                  timing_raw_src0_producer_system_count =
                    timing_raw_src0_producer_system_count + 1;
                default:
                  timing_raw_src0_producer_other_count =
                    timing_raw_src0_producer_other_count + 1;
              endcase
              if (timing_probe_src0_producer_age == 0)
                timing_raw_src0_age0_count = timing_raw_src0_age0_count + 1;
              else if (timing_probe_src0_producer_age == 1)
                timing_raw_src0_age1_count = timing_raw_src0_age1_count + 1;
              else if (timing_probe_src0_producer_age == 2)
                timing_raw_src0_age2_count = timing_raw_src0_age2_count + 1;
              else
                timing_raw_src0_age3plus_count =
                  timing_raw_src0_age3plus_count + 1;
            end
            else if (dut.core_top.base.scalar_pipe.gpr_wbt.src1_blocked)
              timing_head_gpr_raw_src1_count =
                timing_head_gpr_raw_src1_count + 1;
            else if (dut.core_top.base.scalar_pipe.gpr_wbt.src2_blocked)
              timing_head_gpr_raw_src2_count =
                timing_head_gpr_raw_src2_count + 1;
            else if (dut.core_top.base.scalar_pipe.gpr_wbt.dst_blocked) begin
              timing_head_gpr_waw_dst_count =
                timing_head_gpr_waw_dst_count + 1;
              case (timing_gpr_producer_type[timing_probe_head_dst])
                TB_PRODUCER_ALU:
                  timing_waw_producer_alu_count =
                    timing_waw_producer_alu_count + 1;
                TB_PRODUCER_LOAD:
                  timing_waw_producer_load_count =
                    timing_waw_producer_load_count + 1;
                TB_PRODUCER_MUL:
                  timing_waw_producer_mul_count =
                    timing_waw_producer_mul_count + 1;
                default:
                  timing_waw_producer_other_count =
                    timing_waw_producer_other_count + 1;
              endcase
              if (timing_probe_waw_complete_match) begin
                timing_waw_complete_match_count =
                  timing_waw_complete_match_count + 1;
                if (timing_probe_waw_complete_load)
                  timing_waw_complete_load_count =
                    timing_waw_complete_load_count + 1;
                else if (timing_probe_waw_complete_mul)
                  timing_waw_complete_mul_count =
                    timing_waw_complete_mul_count + 1;
                else if (timing_probe_waw_complete_fast0)
                  timing_waw_complete_fast0_count =
                    timing_waw_complete_fast0_count + 1;
                else
                  timing_waw_complete_fast1_count =
                    timing_waw_complete_fast1_count + 1;
              end
            end
            else
              timing_head_gpr_other_count = timing_head_gpr_other_count + 1;
          end
          else if ((dut.core_top.base.scalar_pipe.lsu_debug_loadq_count != 0) ||
                   dut.core_top.base.dcache.mshr_active ||
                   (dut.core_top.base.frontend_scalar_valid &&
                    !dut.core_top.base.pipe_issue_ready &&
                    (dut.core_top.base.scalar_pipe.is_load_placeholder ||
                     dut.core_top.base.scalar_pipe.is_store_placeholder ||
                     dut.core_top.base.scalar_pipe.is_fp_load ||
                     dut.core_top.base.scalar_pipe.is_fp_store))) begin
            timing_no_retire_lsu_count = timing_no_retire_lsu_count + 1;
            if (dut.core_top.base.frontend_scalar_valid &&
                !dut.core_top.base.pipe_issue_ready &&
                (dut.core_top.base.scalar_pipe.is_store_placeholder ||
                 dut.core_top.base.scalar_pipe.is_fp_store) &&
                !dut.core_top.base.scalar_pipe.scalar_lsu.stb_enqueue_ready)
              timing_lsu_head_store_capacity_count =
                timing_lsu_head_store_capacity_count + 1;
            else if (dut.core_top.base.frontend_scalar_valid &&
                     !dut.core_top.base.pipe_issue_ready &&
                     (dut.core_top.base.scalar_pipe.is_load_placeholder ||
                      dut.core_top.base.scalar_pipe.is_fp_load) &&
                     !dut.core_top.base.scalar_pipe.scalar_lsu.loadq_enqueue_ready)
              timing_lsu_head_load_capacity_count =
                timing_lsu_head_load_capacity_count + 1;
            else if (dut.core_top.base.frontend_scalar_valid &&
                     !dut.core_top.base.pipe_issue_ready &&
                     (dut.core_top.base.scalar_pipe.is_load_placeholder ||
                      dut.core_top.base.scalar_pipe.is_store_placeholder ||
                      dut.core_top.base.scalar_pipe.is_fp_load ||
                      dut.core_top.base.scalar_pipe.is_fp_store))
              timing_lsu_head_pipe_count = timing_lsu_head_pipe_count + 1;
            else if (dut.core_top.base.scalar_pipe.lsu_load_resp_valid &&
                     !dut.core_top.base.scalar_pipe.scalar_lsu.loadq_complete_ready)
              timing_lsu_response_backpressure_count =
                timing_lsu_response_backpressure_count + 1;
            else if (dut.core_top.base.scalar_pipe.scalar_lsu.stb_drain_valid &&
                     !dut.core_top.base.scalar_pipe.lsu_store_req_ready)
              timing_lsu_store_drain_backend_count =
                timing_lsu_store_drain_backend_count + 1;
            else if (dut.core_top.base.scalar_pipe.scalar_lsu.lsu_load_req_valid &&
                     !dut.core_top.base.scalar_pipe.lsu_load_req_ready)
              timing_lsu_load_request_backend_count =
                timing_lsu_load_request_backend_count + 1;
            else if (dut.core_top.base.dcache.mshr_active)
              timing_lsu_mshr_count = timing_lsu_mshr_count + 1;
            else if (dut.core_top.base.scalar_pipe.lsu_debug_loadq_count != 0)
              timing_lsu_loadq_wait_count = timing_lsu_loadq_wait_count + 1;
            else if (dut.core_top.base.scalar_pipe.lsu_debug_stb_count != 0)
              timing_lsu_store_buffer_wait_count =
                timing_lsu_store_buffer_wait_count + 1;
            else
              timing_lsu_other_count = timing_lsu_other_count + 1;
          end
          else if (dut.core_top.base.retire_sync.count == 8 ||
                   (dut.core_top.base.frontend_scalar_valid &&
                    !dut.core_top.base.scalar_pipe.retire_alloc_ready))
            timing_no_retire_retire_full_count =
              timing_no_retire_retire_full_count + 1;
          else if (dut.core_top.base.frontend_scalar_valid ||
                   dut.core_top.base.debug_token0_valid)
            timing_no_retire_backend_resource_count =
              timing_no_retire_backend_resource_count + 1;
          else
            timing_no_retire_other_count = timing_no_retire_other_count + 1;
        end

        if ((retired_this_cycle == 0) && timing_probe_head_waw_stall) begin
          if (!timing_waw_stall_active) begin
            timing_waw_stall_active = 1'b1;
            timing_waw_stall_run_count = timing_waw_stall_run_count + 1;
            timing_waw_stall_current_run = 1;
          end else begin
            timing_waw_stall_current_run = timing_waw_stall_current_run + 1;
          end
          if (timing_waw_stall_current_run > timing_waw_stall_max_run)
            timing_waw_stall_max_run = timing_waw_stall_current_run;
        end else begin
          timing_waw_stall_active = 1'b0;
          timing_waw_stall_current_run = 0;
        end

        if ((retired_this_cycle == 0) && timing_probe_head_gpr_stall &&
            timing_probe_any_visible) begin
          timing_younger_load_visible_count =
            timing_younger_load_visible_count + 1;
          if (timing_probe_any_eligible) begin
            timing_younger_load_eligible_count =
              timing_younger_load_eligible_count + 1;
            if (timing_probe_head1_eligible)
              timing_younger_load_eligible_head1_count =
                timing_younger_load_eligible_head1_count + 1;
          end else if (!timing_probe_any_gpr_ready) begin
            timing_younger_load_block_gpr_count =
              timing_younger_load_block_gpr_count + 1;
          end else if (!timing_probe_any_dependency_safe) begin
            timing_younger_load_block_dependency_count =
              timing_younger_load_block_dependency_count + 1;
          end else if (!timing_probe_any_memory_safe) begin
            timing_younger_load_block_memory_order_count =
              timing_younger_load_block_memory_order_count + 1;
          end else if (!timing_probe_lsu_ready) begin
            timing_younger_load_block_lsu_count =
              timing_younger_load_block_lsu_count + 1;
          end else if (!timing_probe_retire_ready) begin
            timing_younger_load_block_retire_count =
              timing_younger_load_block_retire_count + 1;
          end else begin
            timing_younger_load_block_other_count =
              timing_younger_load_block_other_count + 1;
          end
        end

        if (dut.core_top.base.redirect_flush_valid) begin
          timing_redirect_count = timing_redirect_count + 1;
          timing_redirect_wait_req = 1'b1;
          timing_redirect_wait_resp = 1'b1;
          timing_redirect_wait_packet = 1'b1;
          timing_redirect_wait_fifo = 1'b1;
          timing_redirect_wait_token = 1'b1;
          timing_redirect_wait_issue = 1'b1;
          timing_redirect_req_latency = 0;
          timing_redirect_resp_latency = 0;
          timing_redirect_packet_latency = 0;
          timing_redirect_fifo_latency = 0;
          timing_redirect_token_latency = 0;
          timing_redirect_issue_latency = 0;

          // The redirect request path is combinational, so a ready I-cache can
          // accept the target block in the redirect cycle itself.
          if (dut.core_top.base.ifu_fetch.redirect_req_fire) begin
            timing_redirect_wait_req = 1'b0;
          end
        end else begin
          if (timing_redirect_wait_req) begin
            timing_redirect_req_latency = timing_redirect_req_latency + 1;
            if (dut.core_top.base.ifu_fetch.req_fire) begin
              timing_redirect_wait_req = 1'b0;
              timing_redirect_to_req_sum = timing_redirect_to_req_sum +
                                           timing_redirect_req_latency;
              if (timing_redirect_req_latency > timing_redirect_to_req_max)
                timing_redirect_to_req_max = timing_redirect_req_latency;
            end
          end
          if (timing_redirect_wait_resp) begin
            timing_redirect_resp_latency = timing_redirect_resp_latency + 1;
            if (dut.core_top.base.ifu_fetch.resp_fire &&
                !dut.core_top.base.ifu_fetch.response_is_stale) begin
              timing_redirect_wait_resp = 1'b0;
              timing_redirect_to_resp_sum = timing_redirect_to_resp_sum +
                                            timing_redirect_resp_latency;
              if (timing_redirect_resp_latency > timing_redirect_to_resp_max)
                timing_redirect_to_resp_max = timing_redirect_resp_latency;
            end
          end
          if (timing_redirect_wait_packet) begin
            timing_redirect_packet_latency = timing_redirect_packet_latency + 1;
            if (dut.core_top.base.ifu_fetch_valid &&
                dut.core_top.base.ifu_fetch_ready) begin
              timing_redirect_wait_packet = 1'b0;
              timing_redirect_to_packet_sum = timing_redirect_to_packet_sum +
                                              timing_redirect_packet_latency;
              if (timing_redirect_packet_latency > timing_redirect_to_packet_max)
                timing_redirect_to_packet_max = timing_redirect_packet_latency;
            end
          end
          if (timing_redirect_wait_fifo) begin
            timing_redirect_fifo_latency = timing_redirect_fifo_latency + 1;
            if (dut.core_top.base.fetch_valid && dut.core_top.base.fetch_ready) begin
              if (dut.core_top.base.fetch_first_word ?
                  (dut.core_top.base.fetch_bits[38:32] !=
                   TB_EDGE64_LENGTH_MARKER) :
                  (dut.core_top.base.fetch_bits[6:0] !=
                   TB_EDGE64_LENGTH_MARKER)) begin
                if (dut.core_top.base.ifu_predecode_frontend.parcel_count_q == 0)
                  timing_redirect_scalar32_empty_parcel_count =
                    timing_redirect_scalar32_empty_parcel_count + 1;
                else
                  timing_redirect_scalar32_busy_parcel_count =
                    timing_redirect_scalar32_busy_parcel_count + 1;
              end else begin
                if (dut.core_top.base.ifu_predecode_frontend.parcel_count_q == 0)
                  timing_redirect_edge64_empty_parcel_count =
                    timing_redirect_edge64_empty_parcel_count + 1;
                else
                  timing_redirect_edge64_busy_parcel_count =
                    timing_redirect_edge64_busy_parcel_count + 1;
              end
              timing_redirect_wait_fifo = 1'b0;
              timing_redirect_to_fifo_sum = timing_redirect_to_fifo_sum +
                                            timing_redirect_fifo_latency;
              if (timing_redirect_fifo_latency > timing_redirect_to_fifo_max)
                timing_redirect_to_fifo_max = timing_redirect_fifo_latency;
            end
          end
          if (timing_redirect_wait_token) begin
            timing_redirect_token_latency = timing_redirect_token_latency + 1;
            if (dut.core_top.base.debug_token0_valid) begin
              timing_redirect_wait_token = 1'b0;
              timing_redirect_to_token_sum = timing_redirect_to_token_sum +
                                             timing_redirect_token_latency;
              if (timing_redirect_token_latency > timing_redirect_to_token_max)
                timing_redirect_to_token_max = timing_redirect_token_latency;
              if (timing_redirect_token_latency == 0)
                timing_redirect_to_token_0_count = timing_redirect_to_token_0_count + 1;
              else if (timing_redirect_token_latency == 1)
                timing_redirect_to_token_1_count = timing_redirect_to_token_1_count + 1;
              else if (timing_redirect_token_latency == 2)
                timing_redirect_to_token_2_count = timing_redirect_to_token_2_count + 1;
              else if (timing_redirect_token_latency == 3)
                timing_redirect_to_token_3_count = timing_redirect_to_token_3_count + 1;
              else if (timing_redirect_token_latency == 4)
                timing_redirect_to_token_4_count = timing_redirect_to_token_4_count + 1;
              else
                timing_redirect_to_token_5plus_count = timing_redirect_to_token_5plus_count + 1;
            end
          end
          if (timing_redirect_wait_issue) begin
            timing_redirect_issue_latency = timing_redirect_issue_latency + 1;
            if (dut.core_top.base.scalar_pipe.issue_fire) begin
              timing_redirect_wait_issue = 1'b0;
              timing_redirect_to_issue_sum = timing_redirect_to_issue_sum +
                                             timing_redirect_issue_latency;
              if (timing_redirect_issue_latency > timing_redirect_to_issue_max)
                timing_redirect_to_issue_max = timing_redirect_issue_latency;
              if (timing_redirect_issue_latency == 0)
                timing_redirect_to_issue_0_count = timing_redirect_to_issue_0_count + 1;
              else if (timing_redirect_issue_latency == 1)
                timing_redirect_to_issue_1_count = timing_redirect_to_issue_1_count + 1;
              else if (timing_redirect_issue_latency == 2)
                timing_redirect_to_issue_2_count = timing_redirect_to_issue_2_count + 1;
              else if (timing_redirect_issue_latency == 3)
                timing_redirect_to_issue_3_count = timing_redirect_to_issue_3_count + 1;
              else if (timing_redirect_issue_latency == 4)
                timing_redirect_to_issue_4_count = timing_redirect_to_issue_4_count + 1;
              else
                timing_redirect_to_issue_5plus_count = timing_redirect_to_issue_5plus_count + 1;
            end
          end
        end
      end
      if (timing_window_enable &&
          dut.core_top.base.scalar_pipe.issue_fire &&
          dut.core_top.base.scalar_pipe.is_cycle_csr_read) begin
        if (!timing_window_active &&
            (dut.core_top.base.scalar_pipe.issue_pc == timing_start_pc)) begin
          timing_window_active = 1'b1;
          timing_window_seen_start = 1'b1;
        end else if (timing_window_active &&
                     (dut.core_top.base.scalar_pipe.issue_pc == timing_stop_pc)) begin
          timing_window_active = 1'b0;
          timing_window_seen_stop = 1'b1;
          timing_redirect_wait_req = 1'b0;
          timing_redirect_wait_resp = 1'b0;
          timing_redirect_wait_packet = 1'b0;
          timing_redirect_wait_fifo = 1'b0;
          timing_redirect_wait_token = 1'b0;
          timing_redirect_wait_issue = 1'b0;
        end
      end
      if ((dut.core_top.base.scalar_pipe.fpu_fmac_wb_vld ||
           dut.core_top.base.scalar_pipe.fpu_slow_complete_valid) &&
          fpu_vec_fd != 0) begin
        if (!$fgets(fpu_vec_line, fpu_vec_fd)) begin
          $display("EDGE_SOC_VVP TEST FAIL unexpected FPU completion index=%0d",
                   fpu_vec_seen);
          finish_sim(1);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
        fpu_vec_scan_count = $sscanf(fpu_vec_line, "%h %h %h %h %h %h",
                                     fpu_expected_rm, fpu_expected_fflags,
                                     fpu_expected_y, fpu_expected_x,
                                     fpu_expected_a, fpu_expected_b);
        if (dut.core_top.base.scalar_pipe.fpu_slow_complete_valid) begin
          fpu_actual_y = dut.core_top.base.scalar_pipe.fpu_slow_complete_value[31:0];
          fpu_actual_fflags = dut.core_top.base.scalar_pipe.fpu_slow_complete_fflags[4:0];
        end else begin
          fpu_actual_y = dut.core_top.base.scalar_pipe.fpu_fmac_wb_data[31:0];
          fpu_actual_fflags = dut.core_top.base.scalar_pipe.fpu_fmac_wb_fflags[4:0];
        end
        if ((fpu_actual_y != fpu_expected_y[31:0]) ||
            (fpu_actual_fflags != fpu_expected_fflags[4:0])) begin
          $display("EDGE_SOC_VVP TEST FAIL FPU vector=%0d scan=%0d got_y=%08h expected_y=%08h got_flags=%02h expected_flags=%02h",
                   fpu_vec_seen,
                   fpu_vec_scan_count,
                   fpu_actual_y,
                   fpu_expected_y,
                   fpu_actual_fflags,
                   fpu_expected_fflags);
          finish_sim(1);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
        fpu_vec_seen = fpu_vec_seen + 1;
      end
      if (dut.core_top.base.dtcm_scalar_lsu_req &&
          dut.core_top.base.dtcm_scalar_lsu_ready) begin
        if (dut.core_top.base.dtcm_scalar_lsu_we)
          dtcm_store_count = dtcm_store_count + 1;
        else
          dtcm_load_count = dtcm_load_count + 1;
      end
      if (dut.core_top.base.dtcm_scalar_lsu_rvalid) begin
        dtcm_load_resp_count = dtcm_load_resp_count + 1;
      end
      if (dut.core_top.base.scalar_dma_start_valid &&
          dut.core_top.base.scalar_dma_start_ready)
        scalar_dma_start_count = scalar_dma_start_count + 1;
      if (dut.core_top.base.tensor_dma_start_req)
        tensor_dma_start_count = tensor_dma_start_count + 1;
      if (dut.core_top.base.accel_pipe.cmd_setcsr_req ||
          dut.core_top.base.accel_pipe.cmd_wld_req ||
          dut.core_top.base.accel_pipe.cmd_wld_trans_req ||
          dut.core_top.base.accel_pipe.cmd_setin_req ||
          dut.core_top.base.accel_pipe.cmd_setout_req ||
          dut.core_top.base.accel_pipe.cmd_setpsum_req ||
          dut.core_top.base.accel_pipe.cmd_setn_req ||
          dut.core_top.base.accel_pipe.cmd_start_req ||
          dut.core_top.base.accel_pipe.cmd_start_tile_req ||
          dut.core_top.base.accel_pipe.cmd_sync_req)
        tensor_control_count = tensor_control_count + 1;
      if (dut.core_top.base.accel_pipe.cmd_start_req ||
          dut.core_top.base.accel_pipe.cmd_start_tile_req)
        tensor_start_count = tensor_start_count + 1;
      if (dut.core_top.base.accel_pipe.cmd_start_req)
        tensor_start_full_count = tensor_start_full_count + 1;
      if (dut.core_top.base.accel_pipe.cmd_start_tile_req)
        tensor_start_tile_count = tensor_start_tile_count + 1;
      if (dut.core_top.base.accel_pipe.cmd_sync_req)
        tensor_sync_count = tensor_sync_count + 1;
      if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_accept) begin
        tensor_start_accept_count = tensor_start_accept_count + 1;
        tensor_start_accept_run_sum = tensor_start_accept_run_sum
                                    + dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_data_run_count;
        if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_data_run_count
            > tensor_start_accept_run_max)
          tensor_start_accept_run_max =
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_data_run_count;
      end
      if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.stream_out_push)
        tensor_stream_out_push_count = tensor_stream_out_push_count + 1;
      if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.stream_i_prefetch_accept)
        tensor_next_i_prefetch_accept_count =
          tensor_next_i_prefetch_accept_count + 1;
      if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.stream_psum_prefetch_accept)
        tensor_next_psum_prefetch_accept_count =
          tensor_next_psum_prefetch_accept_count + 1;
      if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.x_bank16_engine.compute_valid_q)
        tensor_engine_compute_valid_count = tensor_engine_compute_valid_count + 1;
      if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.x_bank16_engine.compute_busy_q)
        tensor_engine_compute_busy_count = tensor_engine_compute_busy_count + 1;
      if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.x_bank16_engine.compute_busy_q &&
          !dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.x_bank16_engine.i_req_owned)
        tensor_engine_i_not_owned_count = tensor_engine_i_not_owned_count + 1;
      if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.x_bank16_engine.compute_busy_q &&
          !dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.x_bank16_engine.psum_req_owned)
        tensor_engine_psum_not_owned_count = tensor_engine_psum_not_owned_count + 1;
      if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.x_bank16_engine.output_pending &&
          !dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.x_bank16_engine.out_req_owned)
        tensor_engine_out_not_owned_count = tensor_engine_out_not_owned_count + 1;
      if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.x_bank16_engine.compute_busy_q &&
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.x_bank16_engine.read_conflicts_output)
        tensor_engine_i_output_conflict_count = tensor_engine_i_output_conflict_count + 1;
      if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.x_bank16_engine.compute_busy_q &&
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.x_bank16_engine.psum_read_conflicts_output)
        tensor_engine_psum_output_conflict_count = tensor_engine_psum_output_conflict_count + 1;
      if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.x_bank16_engine.output_write_fire)
        tensor_engine_output_write_count = tensor_engine_output_write_count + 1;
      if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_queue_launch)
        tensor_queued_handoff_count = tensor_queued_handoff_count + 1;
      if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.engine_start)
        tensor_engine_start_count = tensor_engine_start_count + 1;
      if (dut.core_top.base.dtcm_dma_start_req)
        dma_start_count = dma_start_count + 1;
      if (dut.core_top.base.dtcm_dma_arvalid &&
          dut.core_top.base.dtcm_dma_arready &&
          dut.core_top.base.dtcm_dma_arlen > dma_max_arlen)
        dma_max_arlen = dut.core_top.base.dtcm_dma_arlen;
      if (dut.core_top.base.debug_token0_valid &&
          !dut.core_top.base.ifu_predecode_frontend.token_ready) begin
        pre_token_stall_count = pre_token_stall_count + 1;
        if (dut.core_top.base.ifu_predecode_frontend.predecode.scalar_hold_valid_q)
          pre_token_stall_hold_count = pre_token_stall_hold_count + 1;
        else if (dut.core_top.base.ifu_predecode_frontend.predecode.vec_busy ||
                 dut.core_top.base.ifu_predecode_frontend.predecode.decoded_valid ||
                 dut.core_top.base.ifu_predecode_frontend.predecode.raw_valid)
          pre_token_stall_pipe_busy_count = pre_token_stall_pipe_busy_count + 1;
        else if (dut.core_top.base.ifu_predecode_frontend.predecode.token_scalar_only_path &&
                 !dut.core_top.base.ifu_predecode_frontend.predecode.scalar_iw_enqueue_ready)
          pre_token_stall_issue_window_count = pre_token_stall_issue_window_count + 1;
        else if (!dut.core_top.base.ifu_predecode_frontend.predecode.token_scalar_only_path &&
                 dut.core_top.base.ifu_predecode_frontend.predecode.scalar_iw_head0_valid)
          pre_token_stall_issue_window_count = pre_token_stall_issue_window_count + 1;
        else if (!dut.core_top.base.ifu_predecode_frontend.predecode.frontend_supported)
          pre_token_stall_unsupported_count = pre_token_stall_unsupported_count + 1;
        else if (!dut.core_top.base.ifu_predecode_frontend.predecode.window_capture_ready)
          pre_token_stall_capture_count = pre_token_stall_capture_count + 1;
        else if (!dut.core_top.base.ifu_predecode_frontend.predecode.frontend_scalar_ready)
          pre_token_stall_scalar_ready_count = pre_token_stall_scalar_ready_count + 1;
        else if (dut.core_top.base.ifu_predecode_frontend.predecode.window_has_vector &&
                 !dut.core_top.base.ifu_predecode_frontend.predecode.window_vector_uses_same_prior_scalar &&
                 !dut.core_top.base.ifu_predecode_frontend.predecode.window_vector_needs_base &&
                 !dut.core_top.base.ifu_predecode_frontend.predecode.accel_command_ready)
          pre_token_stall_accel_ready_count = pre_token_stall_accel_ready_count + 1;
        else
          pre_token_stall_other_count = pre_token_stall_other_count + 1;
      end
      if (dut.core_top.base.tensor_command_valid &&
          dut.core_top.base.tensor_command_is_tensor &&
          !dut.core_top.base.tensor_command_accept)
        tensor_command_accept_stall_count =
          tensor_command_accept_stall_count + 1;
      if (dut.core_top.base.tensor_issue_valid &&
          !dut.core_top.base.tensor_issue_ready) begin
        tensor_issue_stall_count = tensor_issue_stall_count + 1;
        if (dut.core_top.base.tensor_issue_inst64[38:32] == TB_TENSOR_SETIN) begin
          tensor_issue_setin_stall_count =
            tensor_issue_setin_stall_count + 1;
        end else if (dut.core_top.base.tensor_issue_inst64[38:32] ==
                     TB_TENSOR_SETOUT) begin
          tensor_issue_setout_stall_count =
            tensor_issue_setout_stall_count + 1;
        end else if (dut.core_top.base.tensor_issue_inst64[38:32] ==
                     TB_TENSOR_SETPSUM) begin
          tensor_issue_setpsum_stall_count =
            tensor_issue_setpsum_stall_count + 1;
        end else if (dut.core_top.base.tensor_issue_inst64[38:32] ==
                     TB_TENSOR_START) begin
          tensor_issue_start_stall_count =
            tensor_issue_start_stall_count + 1;
        end else if (dut.core_top.base.tensor_issue_inst64[38:32] ==
                     TB_TENSOR_SYNC) begin
          tensor_issue_sync_stall_count =
            tensor_issue_sync_stall_count + 1;
        end else if ((dut.core_top.base.tensor_issue_inst64[38:32] ==
                      TB_TENSOR_WLD_CIRCULAR) ||
                     (dut.core_top.base.tensor_issue_inst64[38:32] ==
                      TB_TENSOR_WLD_T_CIRCULAR)) begin
          tensor_issue_wld_circular_stall_count =
            tensor_issue_wld_circular_stall_count + 1;
          if (!dut.core_top.base.tensor_wld_circular_ready &&
              dut.core_top.base.tensor_circular_ring_empty)
            circular_wld_empty_stall_count =
              circular_wld_empty_stall_count + 1;
          else if (!dut.core_top.base.tensor_wld_circular_ready)
            circular_wld_pipe_stall_count =
              circular_wld_pipe_stall_count + 1;
        end else begin
          tensor_issue_other_stall_count =
            tensor_issue_other_stall_count + 1;
        end
      end
      if (dut.core_top.base.tensor_circular_dma_active_q &&
          dut.core_top.base.tensor_circular_config_valid &&
          !dut.core_top.base.tensor_circular_dma_inflight_q &&
          !dut.core_top.base.tensor_circular_ring_full &&
          (dut.core_top.base.tensor_circular_dma_issued_fragments_q <
           dut.core_top.base.tensor_circular_dma_total_fragments_q) &&
          dut.core_top.base.edge_dma_busy)
        circular_dma_busy_wait_count = circular_dma_busy_wait_count + 1;
      if (dut.core_top.base.tensor_circular_dma_active_q &&
          dut.core_top.base.tensor_circular_config_valid &&
          dut.core_top.base.tensor_circular_ring_full)
        circular_dma_ring_full_wait_count =
          circular_dma_ring_full_wait_count + 1;
      if (dut.core_top.base.tensor_circular_dma_inflight_q)
        circular_dma_inflight_count = circular_dma_inflight_count + 1;
      if (dut.core_top.base.tensor_circular_dma_launch)
        circular_dma_launch_count = circular_dma_launch_count + 1;
      if (dut.core_top.base.tensor_circular_dma_done_pulse)
        circular_dma_done_count = circular_dma_done_count + 1;
      if (dut.core_top.base.tensor_circular_wld_launch)
        circular_wld_consume_count = circular_wld_consume_count + 1;
      circular_occupancy = dut.core_top.base.tensor_circular_produced_entries_q -
                           dut.core_top.base.tensor_circular_consumed_entries_q;
      if (circular_occupancy > circular_max_occupancy)
        circular_max_occupancy = circular_occupancy;
      if (dut.core_top.base.debug_dcache_cache_op_fire) begin
        if (dut.core_top.base.debug_dcache_cache_op_kind[0])
          scalar_cache_clean_count = scalar_cache_clean_count + 1;
        if (dut.core_top.base.debug_dcache_cache_op_kind[1])
          scalar_cache_invalidate_count = scalar_cache_invalidate_count + 1;
      end
      if (dut.core_top.base.scalar_pipe.issue1_fire) begin
        if (dut.core_top.base.pre_scalar1_inst[6:0] == 7'b0000011)
          scalar_load_pair_count = scalar_load_pair_count + 1;
        if (dut.core_top.base.pre_scalar1_inst[6:0] == 7'b0100011)
          scalar_store_pair_count = scalar_store_pair_count + 1;
        if (dut.core_top.base.scalar_pipe.issue_dual_alu_pair) begin
          if (dut.core_top.base.scalar_pipe.issue0_is_pairable_m)
            scalar_m_fast_pair_count = scalar_m_fast_pair_count + 1;
          else if (dut.core_top.base.scalar_pipe.issue1_is_pairable_m)
            scalar_fast_m_pair_count = scalar_fast_m_pair_count + 1;
          else
            scalar_fast_fast_pair_count = scalar_fast_fast_pair_count + 1;
        end
      end
      if (dut.core_top.base.retire_sync.count > max_retire_queue_count)
        max_retire_queue_count = dut.core_top.base.retire_sync.count;
      if (dut.core_top.base.retire_sync.count == 8)
        retire_queue_full_count = retire_queue_full_count + 1;
      if (dut.core_top.base.scalar_pipe.issue_valid &&
          !dut.core_top.base.scalar_pipe.issue_ready) begin
        scalar_issue_block_count = scalar_issue_block_count + 1;
        if (dut.core_top.base.scalar_pipe.redirect_kill_valid)
          scalar_issue_block_redirect_count = scalar_issue_block_redirect_count + 1;
        else if (dut.core_top.base.scalar_pipe.cache_op_pending_q &&
                 !dut.core_top.base.scalar_pipe.cache_op_complete_valid)
          scalar_issue_block_cache_count = scalar_issue_block_cache_count + 1;
        else if (!dut.core_top.base.scalar_pipe.retire_alloc_ready &&
                 !dut.core_top.base.scalar_pipe.is_tensor_gpr_holder_pseudo)
          scalar_issue_block_retire_count = scalar_issue_block_retire_count + 1;
        else if (!dut.core_top.base.scalar_pipe.producer_queue_issue_ready)
          scalar_issue_block_producer_count = scalar_issue_block_producer_count + 1;
        else if (dut.core_top.base.scalar_pipe.issue_gpr_check_candidate &&
                 !dut.core_top.base.scalar_pipe.gpr_issue_ready)
          scalar_issue_block_gpr_count = scalar_issue_block_gpr_count + 1;
        else if (dut.core_top.base.scalar_pipe.issue_fpr_check_candidate &&
                 !dut.core_top.base.scalar_pipe.fpr_issue_ready)
          scalar_issue_block_fpr_count = scalar_issue_block_fpr_count + 1;
        else if ((dut.core_top.base.scalar_pipe.is_fpu_fmac ||
                  dut.core_top.base.scalar_pipe.is_fpu_aux ||
                  dut.core_top.base.scalar_pipe.legal_fpu_slow) &&
                 !dut.core_top.base.scalar_pipe.fpu_issue_ready)
          scalar_issue_block_fpu_count = scalar_issue_block_fpu_count + 1;
        else if ((dut.core_top.base.scalar_pipe.is_alu_gpr_placeholder ||
                  dut.core_top.base.scalar_pipe.is_branch) &&
                 !dut.core_top.base.scalar_pipe.alu_issue_ready)
          scalar_issue_block_alu_count = scalar_issue_block_alu_count + 1;
        else if ((dut.core_top.base.scalar_pipe.is_load_placeholder ||
                  dut.core_top.base.scalar_pipe.is_fp_load) &&
                 !dut.core_top.base.scalar_pipe.lsu_stores_drained)
          scalar_issue_block_store_order_count = scalar_issue_block_store_order_count + 1;
        else if ((dut.core_top.base.scalar_pipe.is_load_placeholder ||
                  dut.core_top.base.scalar_pipe.is_store_placeholder ||
                  dut.core_top.base.scalar_pipe.is_fp_load ||
                  dut.core_top.base.scalar_pipe.is_fp_store) &&
                 !dut.core_top.base.scalar_pipe.lsu_issue_ready)
          scalar_issue_block_lsu_count = scalar_issue_block_lsu_count + 1;
        else if ((dut.core_top.base.scalar_pipe.legal_system ||
                  dut.core_top.base.scalar_pipe.legal_fence ||
                  dut.core_top.base.scalar_pipe.legal_custom_control) &&
                 (!dut.core_top.base.scalar_pipe.sys_issue_ready ||
                  !dut.core_top.base.scalar_pipe.custom_control_ready ||
                  (dut.core_top.base.scalar_pipe.cycle_csr_writes_gpr &&
                   !dut.core_top.base.scalar_pipe.cycle_csr_gpr_slot_ready)))
          scalar_issue_block_system_count = scalar_issue_block_system_count + 1;
        else
          scalar_issue_block_other_count = scalar_issue_block_other_count + 1;
      end
      if (dut.core_top.base.frontend_scalar1_valid &&
          dut.core_top.base.shim_issue_valid &&
          dut.core_top.base.pre_scalar1_inst[6:0] == 7'b0000011 &&
          !dut.core_top.base.pipe_issue1_ready) begin
        scalar_load_pair_block_count = scalar_load_pair_block_count + 1;
        if (!dut.core_top.base.scalar_pipe.issue_ready)
          scalar_load_pair_block_issue0_count = scalar_load_pair_block_issue0_count + 1;
        else if (!dut.core_top.base.scalar_pipe.issue1_pair_allowed)
          scalar_load_pair_block_policy_count = scalar_load_pair_block_policy_count + 1;
        else if (!dut.core_top.base.scalar_pipe.retire_alloc_ready)
          scalar_load_pair_block_retire_count = scalar_load_pair_block_retire_count + 1;
        else if (!dut.core_top.base.scalar_pipe.gpr_issue1_ready)
          scalar_load_pair_block_gpr_count = scalar_load_pair_block_gpr_count + 1;
        else if (!dut.core_top.base.scalar_pipe.lsu_stores_drained)
          scalar_load_pair_block_store_order_count = scalar_load_pair_block_store_order_count + 1;
        else if (!dut.core_top.base.scalar_pipe.lsu_issue1_ready)
          scalar_load_pair_block_lsu_count = scalar_load_pair_block_lsu_count + 1;
        else
          scalar_load_pair_block_other_count = scalar_load_pair_block_other_count + 1;
      end
      if (dut.core_top.base.scalar_pipe.lsu_debug_stb_count > max_lsu_stb_count)
        max_lsu_stb_count = dut.core_top.base.scalar_pipe.lsu_debug_stb_count;
      if (dut.core_top.base.scalar_pipe.lsu_debug_loadq_count > max_lsu_loadq_count)
        max_lsu_loadq_count = dut.core_top.base.scalar_pipe.lsu_debug_loadq_count;
      if (dut.core_top.base.dcache.hit_under_miss_fire)
        dcache_hit_under_miss_accept_count =
          dcache_hit_under_miss_accept_count + 1 +
          dut.core_top.base.dcache.load1_fire;
      if (dut.core_top.base.dcache.hit_queue.complete_fire &&
          dut.core_top.base.dcache.mshr_active)
        dcache_hit_under_miss_complete_count =
          dcache_hit_under_miss_complete_count + 1;
      if (dut.core_top.base.dcache.mshr_active &&
          dut.core_top.base.dcache.lsu_load_req_valid &&
          dut.core_top.base.dcache.load_metadata_hit &&
          !dut.core_top.base.dcache.hit_queue_alloc_ready)
        dcache_hit_queue_full_count = dcache_hit_queue_full_count + 1;
      if (dut.core_top.base.dcache.hit_queue.count_q > max_dcache_hit_queue_count)
        max_dcache_hit_queue_count = dut.core_top.base.dcache.hit_queue.count_q;
      if (dut.core_top.base.dcache.lsu_load_req_valid &&
          dut.core_top.base.dcache.lsu_load_req_ready)
        dcache_lookup_accept_count = dcache_lookup_accept_count + 1;
      if (dut.core_top.base.dcache.load_fire)
        dcache_lookup_launch_count = dcache_lookup_launch_count + 1;
      if (dut.core_top.base.dcache.load1_fire)
        dcache_lookup_lane1_launch_count = dcache_lookup_lane1_launch_count + 1;
      if (dut.core_top.base.dcache.lookup_debug_bypass &&
          dut.core_top.base.dcache.load_fire)
        dcache_lookup_bypass_count = dcache_lookup_bypass_count + 1;
      if (dut.core_top.base.dcache.lookup_debug_push_fire &&
          !(dut.core_top.base.dcache.lookup_debug_bypass &&
            dut.core_top.base.dcache.lookup_pop))
        dcache_lookup_capture_count = dcache_lookup_capture_count + 1;
      if (dut.core_top.base.dcache.lookup_count == 2'd1)
        dcache_lookup_occupancy1_cycles = dcache_lookup_occupancy1_cycles + 1;
      if (dut.core_top.base.dcache.lookup_count == 2'd2)
        dcache_lookup_occupancy2_cycles = dcache_lookup_occupancy2_cycles + 1;
      if (dut.core_top.base.dcache.lookup_debug_phase_wait)
        dcache_lookup_phase_wait_cycles = dcache_lookup_phase_wait_cycles + 1;
      if (dut.core_top.base.dcache.lookup_valid &&
          dut.core_top.base.dcache.load_metadata_hit &&
          !dut.core_top.base.dcache.hit_queue_alloc_ready)
        dcache_lookup_hit_queue_wait_cycles =
          dcache_lookup_hit_queue_wait_cycles + 1;
      if (dut.core_top.base.dcache.lookup_park)
        dcache_lookup_mshr_park_count = dcache_lookup_mshr_park_count + 1;
      if (dut.core_top.base.dcache.lookup_debug_parked &&
          dut.core_top.base.dcache.mshr_miss_ready)
        dcache_lookup_parked_retry_cycles =
          dcache_lookup_parked_retry_cycles + 1;
      if (dut.core_top.base.dcache.lookup_valid &&
          dut.core_top.base.dcache.backend_load_pause)
        dcache_lookup_backend_pause_cycles =
          dcache_lookup_backend_pause_cycles + 1;
      if (dut.core_top.base.scalar_pipe.scalar_lsu.loadreq_fifo_count == 2'd2)
        lsu_loadreq_fifo_full_count = lsu_loadreq_fifo_full_count + 1;
      if (dut.core_top.base.scalar_pipe.scalar_lsu.loadreq_fifo_count >
          max_lsu_loadreq_fifo_count)
        max_lsu_loadreq_fifo_count =
          dut.core_top.base.scalar_pipe.scalar_lsu.loadreq_fifo_count;
      if (trace_enable && cycle >= trace_start_cycle &&
          (trace_stop_cycle == 0 || cycle <= trace_stop_cycle)) begin
        $fdisplay(trace_fd,
          "cycle=%0d issue_pc=%h/%h a0=%h t0=%h mvalid=%0d msrc=%h/%h imem_req=%0d/%0d addr=%h imem_resp=%0d/%0d token=%0d kind=%0d inst=%h pre_ready=%0d fe_ready=%0d fe_sup=%0d cap_ready=%0d vec_cmd_ready=%0d acc_cap=%0d same_prior=%0d vec_busy=%0d vec_state=%0d sel_tensor=%0d needs_base=%0d acc_count=%0d iw_head=%0d win_valid=%0d win_vec=%0d win_scalar=%0d scalar_ready=%0d issue=%0d pipe_ready=%0d retire_alloc=%0d alloc_ready=%0d complete0=%0d complete3=%0d retire0=%0d retire1=%0d retired_total=%0d queue_count=%0d tensorq_count=%0d tensorq_valid=%b tensorq_head=%0d tensorq_tail=%0d gpr_busy=%h tensor_sync_stall=%0d tensor_cmd=%0d capcnt=%0d ncap=%0d bcap=%0d cmdq_count=%0d nsrc=%0d bsrc=%0d tensor_issue=%0d/%0d inst=%h subop=%h n=%0d nval=%h base=%0d bval=%h set=%0d/%0d/%0d/%0d setptr=%h/%h/%h setn=%h start=%0d start_mode=%0d/%0d/%0d/%0d/%0d/%0d start_cfg=%h/%h/%h/%h cfgsel=%0d cfg0=%h/%h/%h/%h cfg1=%h/%h/%h/%h pipe_done=%0d tdma_start=%0d tdma_sync=%0d dtcm_dma_start=%0d len=%h edge_dma_busy=%0d dma_active=%0d clean_wb=%0d/%0d addr=%h data=%h last=%0d complete=%0d aw=%0d/%0d awaddr=%h w=%0d/%0d wdata=%h b=%0d/%0d dma_ar=%0d/%0d araddr=%h arlen=%h dma_r=%0d/%0d rdata=%h rlast=%0d dtcm_wr=%0d/%0d addr=%h data=%h strb=%h dtcm_ld=%0d addr=%h rvalid=%0d rdata=%h circ=%0d/%0d/%0d wld=%0d/%0d/%0d/%0d wld_evt=%0d/%0d/%0d q=%0d/%0d eng=%0d/%0d start_ready=%0d sp=%h lsu_q=%0d/%0d lsu_req=%0d/%0d/%h/%0d/%0d lsu_req1=%0d/%0d/%h/%0d/%0d lsu_resp=%0d/%0d/%0d dcache=%0d/%0d/%h lookup=%0d/%h/%0d/%0d hitq=%0d/%0d mshr=%0d/%h/%0d/%0d refill=%0d/%0d/%h/%0d/%0d pipe_load=%0d/%0d/%0d/%0d wbt27=%0d/%0d issue0=%0d/%0d/%0d/%0d issue1=%0d/%0d/%0d/%0d redirect=%0d/%0d/%0d lsu_flush=%0d/%0d/%0d",
          cycle,
          dut.core_top.base.scalar_pipe.issue_pc,
          dut.core_top.base.scalar_pipe.issue1_pc,
          dut.core_top.base.scalar_pipe.gpr[10],
          dut.core_top.base.scalar_pipe.gpr[5],
          dut.core_top.base.scalar_pipe.scalar_alu.m_issue_valid,
          dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.m_issue_src0_value,
          dut.core_top.base.scalar_pipe.scalar_alu.scalar_muldiv.m_issue_src1_value,
          dut.core_imem_req_valid,
          dut.core_imem_req_ready,
          dut.core_imem_req_addr,
          dut.core_imem_resp_valid,
          dut.core_imem_resp_ready,
          dut.core_top.base.debug_token0_valid,
          dut.core_top.base.debug_token0_kind,
          dut.core_top.base.token0_inst32,
          dut.core_top.base.ifu_predecode_frontend.token_ready,
          dut.core_top.base.ifu_predecode_frontend.predecode.frontend_ready,
          dut.core_top.base.ifu_predecode_frontend.predecode.frontend_supported,
          dut.core_top.base.ifu_predecode_frontend.predecode.window_capture_ready,
          dut.core_top.base.ifu_predecode_frontend.predecode.accel_command_ready,
          dut.core_top.base.ifu_predecode_frontend.predecode.window_accel_needs_capture,
          dut.core_top.base.ifu_predecode_frontend.predecode.window_vector_uses_same_prior_scalar,
          dut.core_top.base.ifu_predecode_frontend.predecode.vec_busy,
          dut.core_top.base.ifu_predecode_frontend.predecode.vec_state,
          dut.core_top.base.ifu_predecode_frontend.predecode.window_selected_vector_is_tensor,
          dut.core_top.base.ifu_predecode_frontend.predecode.window_vector_needs_base,
          dut.core_top.base.ifu_predecode_frontend.predecode.window_accel_capture_count,
          dut.core_top.base.ifu_predecode_frontend.predecode.scalar_iw_head0_valid,
          dut.core_top.base.ifu_predecode_frontend.predecode.window_valid,
          dut.core_top.base.ifu_predecode_frontend.predecode.window_has_vector,
          dut.core_top.base.ifu_predecode_frontend.predecode.window_has_scalar,
          dut.core_top.base.scalar_ready,
          dut.core_top.base.shim_issue_valid,
          dut.core_top.base.pipe_issue_ready,
          dut.core_top.base.retire_alloc_valid,
          dut.core_top.base.retire_alloc_ready,
          dut.core_top.base.retire_complete0_valid,
          dut.core_top.base.retire_complete3_valid,
          dut.core_top.base.retire0_valid,
          dut.core_top.base.retire1_valid,
          retired_total,
          dut.core_top.base.debug_retire_count,
          dut.core_top.base.tensor_cmd_queue.debug_count,
          dut.core_top.base.tensor_cmd_queue.debug_entry_valid,
          dut.core_top.base.tensor_cmd_queue.debug_head,
          dut.core_top.base.tensor_cmd_queue.debug_tail,
          dut.core_top.base.debug_gpr_busy,
          dut.core_top.base.tensor_sync_stall,
          dut.core_top.base.tensor_command_valid,
          dut.core_top.base.tensor_command_capture_count,
          dut.core_top.base.tensor_command_n_capture_valid,
          dut.core_top.base.tensor_command_base_capture_valid,
          dut.core_top.base.tensor_cmd_queue_count,
          dut.core_top.base.tensor_command_n_src_gpr,
          dut.core_top.base.tensor_command_base_src_gpr,
          dut.core_top.base.tensor_issue_valid,
          dut.core_top.base.tensor_issue_ready,
          dut.core_top.base.tensor_issue_inst64,
          dut.core_top.base.tensor_issue_inst64[38:32],
          dut.core_top.base.tensor_issue_n_valid,
          dut.core_top.base.tensor_issue_n_value,
          dut.core_top.base.tensor_issue_base_valid,
          dut.core_top.base.tensor_issue_base_value,
          dut.core_top.base.accel_pipe.cmd_setin_req,
          dut.core_top.base.accel_pipe.cmd_setout_req,
          dut.core_top.base.accel_pipe.cmd_setpsum_req,
          dut.core_top.base.accel_pipe.cmd_setn_req,
          dut.core_top.base.accel_pipe.cmd_setin_ptr,
          dut.core_top.base.accel_pipe.cmd_setout_ptr,
          dut.core_top.base.accel_pipe.cmd_setpsum_ptr,
          dut.core_top.base.accel_pipe.cmd_setn_value,
          dut.core_top.base.accel_pipe.cmd_start_req,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_direct_accept,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_queue_accept,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_wait_accept,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_queue_launch,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_pending_direct_launch,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_pending_queue_launch,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_data_in,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_data_out,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_data_psum,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.start_data_run_count,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.cfg_write_sel_q,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.cfg_in_ptr_q[0],
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.cfg_out_ptr_q[0],
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.cfg_psum_ptr_q[0],
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.cfg_run_count_q[0],
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.cfg_in_ptr_q[1],
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.cfg_out_ptr_q[1],
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.cfg_psum_ptr_q[1],
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.cfg_run_count_q[1],
          dut.core_top.base.accel_pipe_done_valid,
          dut.core_top.base.tensor_dma_start_req,
          dut.core_top.base.tensor_dma_sync_req,
          dut.core_top.base.dtcm_dma_start_req,
          dut.core_top.base.dtcm_dma_start_len,
          dut.core_top.base.edge_dma_busy,
          dut.core_top.base.edge_dma_active_q,
          dut.core_top.base.dcache_clean_wb_valid,
          dut.core_top.base.dcache_clean_wb_ready,
          dut.core_top.base.dcache_clean_wb_addr,
          dut.core_top.base.dcache_clean_wb_data,
          dut.core_top.base.dcache_clean_wb_last,
          dut.core_top.base.dcache_clean_wb_complete,
          dut.biu_pad_awvalid,
          dut.soc_pad_biu_awready,
          dut.biu_pad_awaddr,
          dut.biu_pad_wvalid,
          dut.soc_pad_biu_wready,
          dut.biu_pad_wdata,
          dut.soc_pad_biu_bvalid,
          dut.biu_pad_bready,
          dut.core_top.base.dtcm_dma_arvalid,
          dut.core_top.base.dtcm_dma_arready,
          dut.core_top.base.dtcm_dma_araddr,
          dut.core_top.base.dtcm_dma_arlen,
          dut.core_top.base.dtcm_dma_rvalid,
          dut.core_top.base.dtcm_dma_rready,
          dut.core_top.base.dtcm_dma_rdata,
          dut.core_top.base.dtcm_dma_rlast,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.dma_dtcm_req,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.dma_ready,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.dma_dtcm_addr,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.dma_dtcm_wdata,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.dma_dtcm_wstrb,
          dut.core_top.base.dtcm_scalar_lsu_req && !dut.core_top.base.dtcm_scalar_lsu_we,
          dut.core_top.base.dtcm_scalar_lsu_addr,
          dut.core_top.base.dtcm_scalar_lsu_rvalid,
          dut.core_top.base.dtcm_scalar_lsu_rdata,
          dut.core_top.base.tensor_circular_produced_entries_q,
          dut.core_top.base.tensor_circular_consumed_entries_q,
          dut.core_top.base.tensor_circular_consumer_entry_q,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.weight_loaded_q,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.wld_active_q,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.wld_cmd_pending_q,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.wld_cmd_pending_next_q,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.wld_cmd_launch,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.wld_read_fire,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.wld_fill_done,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.queued_start_valid_q,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.queued_start_preactivated_q,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.engine_busy,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.engine_handoff_ready,
          dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core.x_edge_tensor_unit_bank16.tensor_start_ready,
          dut.core_top.base.scalar_pipe.gpr[2],
          dut.core_top.base.scalar_pipe.lsu_debug_loadq_count,
          dut.core_top.base.scalar_pipe.scalar_lsu.loadreq_fifo_count,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_load_req_valid,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_load_req_ready,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_load_req_addr,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_load_req_seq_id,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_load_req_epoch,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_load_req1_valid,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_load_req1_ready,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_load_req1_addr,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_load_req1_seq_id,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_load_req1_epoch,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_load_resp_valid,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_load_resp_seq_id,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_load_resp_epoch,
          dut.core_top.base.dcache.lsu_load_req_valid,
          dut.core_top.base.dcache.lsu_load_req_ready,
          dut.core_top.base.dcache.lsu_load_req_addr,
          dut.core_top.base.dcache.lookup_valid,
          dut.core_top.base.dcache.lookup_addr,
          dut.core_top.base.dcache.load_metadata_hit,
          dut.core_top.base.dcache.load_fire,
          dut.core_top.base.dcache.hit_queue_count,
          dut.core_top.base.dcache.hit_queue_alloc_ready,
          dut.core_top.base.dcache.mshr_active,
          dut.core_top.base.dcache.mshr_active_addr,
          dut.core_top.base.dcache.mshr_complete,
          dut.core_top.base.dcache.mshr_complete_valid,
          dut.core_top.base.dcache.refill_req_valid,
          dut.core_top.base.dcache.refill_req_ready,
          dut.core_top.base.dcache.refill_req_addr,
          dut.core_top.base.dcache.refill_resp_valid,
          dut.core_top.base.dcache.refill_resp_ready,
          dut.core_top.base.scalar_pipe.gpr_load_complete_valid,
          dut.core_top.base.scalar_pipe.gpr_load_complete_reg,
          dut.core_top.base.scalar_pipe.gpr_load_complete_seq_id,
          dut.core_top.base.scalar_pipe.gpr_load_complete_epoch,
          dut.core_top.base.scalar_pipe.gpr_wbt.busy_seq_id[27],
          dut.core_top.base.scalar_pipe.gpr_wbt.busy_epoch[27],
          dut.core_top.base.scalar_pipe.gpr_wbt.issue_valid,
          dut.core_top.base.scalar_pipe.gpr_wbt.issue_dst,
          dut.core_top.base.scalar_pipe.gpr_wbt.issue_seq_id,
          dut.core_top.base.scalar_pipe.gpr_wbt.issue_epoch,
          dut.core_top.base.scalar_pipe.gpr_wbt.issue1_valid,
          dut.core_top.base.scalar_pipe.gpr_wbt.issue1_dst,
          dut.core_top.base.scalar_pipe.gpr_wbt.issue1_seq_id,
          dut.core_top.base.scalar_pipe.gpr_wbt.issue1_epoch,
          dut.core_top.base.scalar_pipe.redirect_kill_valid,
          dut.core_top.base.scalar_pipe.redirect_kill_seq_id,
          dut.core_top.base.scalar_pipe.redirect_kill_epoch,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_flush_valid,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_flush_seq_id,
          dut.core_top.base.scalar_pipe.scalar_lsu.lsu_flush_epoch);
        if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.engine_start) begin
          $fdisplay(trace_fd,
            "tensor_state cycle=%0d active=%0d pending=%0d active_sel=%0d pending_sel=%0d reuse_token=%0d weight_loaded=%0d scale_active=%0d scale_pending=%0d scale_sel=%0d/%0d use_scale=%0d scale=%h w0=%h/%h w1=%h/%h",
            cycle,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.tensor_weight_active_valid,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.tensor_weight_pending_valid,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.x_tensor8x8
                .weight_active_buf_q,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.x_tensor8x8
                .weight_pending_buf_q,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.weight_reuse_token_q,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.weight_loaded_q,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.scale_active_valid_q,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.scale_pending_valid_q,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.scale_active_sel_q,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.scale_pending_sel_q,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.engine_start_mode[0],
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.engine_start_scale,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.x_tensor8x8
                .weight_buf0[0],
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.x_tensor8x8
                .weight_buf0[1],
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.x_tensor8x8
                .weight_buf1[0],
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.x_tensor8x8
                .weight_buf1[1]);
        end
        if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.o_pair_req) begin
          $fdisplay(trace_fd,
            "tensor_out cycle=%0d addr=%h data=%h live_psum=%h d5_psum=%h",
            cycle,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.o_pair_addr,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.o_pair_wdata,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.aligned_psum_data,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.x_tensor8x8.psum_d5);
        end
        if (dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.compute_valid_q) begin
          $fdisplay(trace_fd,
            "tensor_compute cycle=%0d input=%h psum=%h scale=%h active_sel=%0d",
            cycle,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.input_compute_data,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.aligned_psum_data,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.scale_bf16_q,
            dut.core_top.base.dtcm_subsys.x_edge_dtcm_subsys_core
                .x_edge_tensor_unit_bank16.x_bank16_engine.x_tensor8x8
                .weight_active_buf_q);
        end
        $fflush(trace_fd);
      end
      if (core_csr_break_valid) begin
        if (pass_on_csr_break) begin
          report_return_value = core_csr_break_code;
          if (expected_return != 64'hffff_ffff_ffff_ffff &&
              core_csr_break_code != expected_return) begin
            report_return_value = core_csr_break_code;
            write_report(1'b0, "csr break return mismatch");
            $display("EDGE_SOC_VVP TEST FAIL csr_break return=%0d expected=%0d retire_count=%0d seq=%0d epoch=%0d",
                     core_csr_break_code,
                     expected_return,
                     retired_total,
                     core_csr_break_seq_id,
                     core_csr_break_epoch);
            finish_sim(1);
`ifdef VERILATOR_SIM
            disable edge_soc_vvp_main;
`endif
          end
          if (expect_tensor_matvec64_1token_tiled_output) begin
            check_tensor_matvec64_1token_tiled_output(matvec64_1token_tiled_output_ok);
            if (!matvec64_1token_tiled_output_ok) begin
              write_report(1'b0, "tensor matvec64_1token_tiled output mismatch");
              $display("EDGE_SOC_VVP TEST FAIL tensor matvec64_1token_tiled output mismatch retire_count=%0d",
                       retired_total);
              finish_sim(1);
`ifdef VERILATOR_SIM
              disable edge_soc_vvp_main;
`endif
            end
          end
          if (expect_tensor_tile8x8_stream64tokens_output) begin
            check_tensor_tile8x8_stream64tokens_output(tile8x8_stream64tokens_output_ok);
            if (!tile8x8_stream64tokens_output_ok) begin
              write_report(1'b0, "tensor tile8x8_stream64tokens output mismatch");
              $display("EDGE_SOC_VVP TEST FAIL tensor tile8x8_stream64tokens output mismatch retire_count=%0d",
                       retired_total);
              finish_sim(1);
`ifdef VERILATOR_SIM
              disable edge_soc_vvp_main;
`endif
            end
          end
          if (expect_tensor_matmul64x64_64tokens_tiled_output) begin
            check_tensor_matmul64x64_64tokens_tiled_output(
              matmul64x64_64tokens_tiled_output_ok,
              expect_tensor_matmul64x64_64tokens_tiled_permuted_output);
            if (!matmul64x64_64tokens_tiled_output_ok) begin
              write_report(1'b0, "tensor matmul64x64_64tokens_tiled output mismatch");
              $display("EDGE_SOC_VVP TEST FAIL tensor matmul64x64_64tokens_tiled output mismatch retire_count=%0d",
                       retired_total);
              finish_sim(1);
`ifdef VERILATOR_SIM
              disable edge_soc_vvp_main;
`endif
            end
          end
          if (expect_tensor_matmul64x64_128tokens_tiled_output) begin
            check_tensor_matmul64x64_128tokens_tiled_output(matmul64x64_128tokens_tiled_output_ok);
            if (!matmul64x64_128tokens_tiled_output_ok) begin
              write_report(1'b0, "tensor matmul64x64_128tokens_tiled output mismatch");
              $display("EDGE_SOC_VVP TEST FAIL tensor matmul64x64_128tokens_tiled output mismatch retire_count=%0d",
                       retired_total);
              finish_sim(1);
`ifdef VERILATOR_SIM
              disable edge_soc_vvp_main;
`endif
            end
          end
          if (expect_tensor_matmul512x512_32tokens_transpose_output) begin
            check_tensor_matmul512x512_32tokens_transpose_output(
              matmul512x512_32tokens_transpose_output_ok);
            if (!matmul512x512_32tokens_transpose_output_ok) begin
              write_report(1'b0, "tensor matmul512x512 transpose output mismatch");
              $display("EDGE_SOC_VVP TEST FAIL tensor matmul512x512 transpose output mismatch retire_count=%0d",
                       retired_total);
              finish_sim(1);
`ifdef VERILATOR_SIM
              disable edge_soc_vvp_main;
`endif
            end
          end
          dump_memory_range();
          write_report(1'b1, "csr break reached");
          $display("EDGE_SOC_VVP TEST PASS csr_break return=%0d retire_count=%0d seq=%0d epoch=%0d",
                   core_csr_break_code,
                   retired_total,
                   core_csr_break_seq_id,
                   core_csr_break_epoch);
          finish_sim(0);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
      end
      if (core_csr_putchar_valid) begin
        $fwrite(sim_console_fd, "%c", core_csr_putchar_char);
        $fflush(sim_console_fd);
      end
      if (core_ebreak_valid) begin
        if (pass_on_ebreak) begin
          if (fpu_vec_fd != 0 && fpu_vec_seen != fpu_vec_count) begin
            write_report(1'b0, "FPU vector completion count mismatch");
            $display("EDGE_SOC_VVP TEST FAIL FPU completions=%0d expected=%0d",
                     fpu_vec_seen, fpu_vec_count);
            finish_sim(1);
`ifdef VERILATOR_SIM
            disable edge_soc_vvp_main;
`endif
          end
          if (expected_x31 != 64'hffff_ffff_ffff_ffff &&
              dut.core_top.base.scalar_pipe.gpr[31] != expected_x31) begin
            report_return_value = 64'd1;
            write_report(1'b0, "ebreak x31 mismatch");
            $display("EDGE_SOC_VVP TEST FAIL ebreak x31=%0d expected=%0d retire_count=%0d seq=%0d epoch=%0d",
                     dut.core_top.base.scalar_pipe.gpr[31],
                     expected_x31,
                     retired_total,
                     core_ebreak_seq_id,
                     core_ebreak_epoch);
            finish_sim(1);
`ifdef VERILATOR_SIM
            disable edge_soc_vvp_main;
`endif
          end
          report_return_value = 64'd0;
          dump_memory_range();
          write_report(1'b1, "ebreak reached");
          $display("EDGE_SOC_VVP TEST PASS ebreak x31=%0d retire_count=%0d seq=%0d epoch=%0d",
                   dut.core_top.base.scalar_pipe.gpr[31],
                   retired_total,
                   core_ebreak_seq_id,
                   core_ebreak_epoch);
          finish_sim(0);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
      end
      if (dut.core_top.base.scalar_fatal_valid) begin
        write_report(1'b0, "scalar fatal");
        $display("EDGE_SOC_VVP TEST FAIL scalar fatal code=%0d inst=%h retire_count=%0d",
                 dut.core_top.base.scalar_fatal_code,
                 dut.core_top.base.scalar_fatal_inst,
                 retired_total);
        finish_sim(1);
`ifdef VERILATOR_SIM
        disable edge_soc_vvp_main;
`endif
      end
      if (pass_retire_count > 0
          && retired_total >= pass_retire_count) begin
        if (expect_dtcm_scalar_lsu &&
            (dtcm_store_count == 0 ||
             dtcm_load_count == 0 ||
             dtcm_load_resp_count == 0)) begin
          write_report(1'b0, "expected DTCM scalar LSU activity missing");
          $display("EDGE_SOC_VVP TEST FAIL missing DTCM scalar LSU activity store=%0d load=%0d load_resp=%0d retire_count=%0d",
                   dtcm_store_count,
                   dtcm_load_count,
                   dtcm_load_resp_count,
                   retired_total);
          finish_sim(1);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
        if (dtcm_load_count < min_dtcm_load_count) begin
          write_report(1'b0, "minimum DTCM load activity missing");
          $display("EDGE_SOC_VVP TEST FAIL DTCM load count %0d below minimum %0d retire_count=%0d",
                   dtcm_load_count,
                   min_dtcm_load_count,
                   retired_total);
          finish_sim(1);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
        if (dtcm_store_count < min_dtcm_store_count) begin
          write_report(1'b0, "minimum DTCM store activity missing");
          $display("EDGE_SOC_VVP TEST FAIL DTCM store count %0d below minimum %0d retire_count=%0d",
                   dtcm_store_count,
                   min_dtcm_store_count,
                   retired_total);
          finish_sim(1);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
        if (expect_dma_start && (dma_start_count == 0)) begin
          write_report(1'b0, "expected DMA start activity missing");
          $display("EDGE_SOC_VVP TEST FAIL missing DMA start activity retire_count=%0d",
                   retired_total);
          finish_sim(1);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
        if (expect_scalar_dma_start && (scalar_dma_start_count == 0)) begin
          write_report(1'b0, "expected scalar DMA start activity missing");
          $display("EDGE_SOC_VVP TEST FAIL missing scalar DMA start activity retire_count=%0d",
                   retired_total);
          finish_sim(1);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
        if (expect_tensor_control && (tensor_control_count == 0)) begin
          write_report(1'b0, "expected tensor control activity missing");
          $display("EDGE_SOC_VVP TEST FAIL missing tensor control activity retire_count=%0d",
                   retired_total);
          finish_sim(1);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
        if (expect_tensor_start && (tensor_start_count == 0)) begin
          write_report(1'b0, "expected tensor start activity missing");
          $display("EDGE_SOC_VVP TEST FAIL missing tensor start activity retire_count=%0d",
                   retired_total);
          finish_sim(1);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
        if (expect_tensor_sync && (tensor_sync_count == 0)) begin
          write_report(1'b0, "expected tensor sync activity missing");
          $display("EDGE_SOC_VVP TEST FAIL missing tensor sync activity retire_count=%0d",
                   retired_total);
          finish_sim(1);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
        if (dma_max_arlen < min_dma_arlen) begin
          write_report(1'b0, "minimum DMA ARLEN missing");
          $display("EDGE_SOC_VVP TEST FAIL DMA max arlen %0d below minimum %0d retire_count=%0d",
                   dma_max_arlen,
                   min_dma_arlen,
                   retired_total);
          finish_sim(1);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
        if (expect_scalar_cache_ops &&
            (scalar_cache_clean_count == 0 ||
             scalar_cache_invalidate_count == 0)) begin
          write_report(1'b0, "expected scalar cache maintenance activity missing");
          $display("EDGE_SOC_VVP TEST FAIL missing scalar cache activity clean=%0d invalidate=%0d retire_count=%0d",
                   scalar_cache_clean_count,
                   scalar_cache_invalidate_count,
                   retired_total);
          finish_sim(1);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
        if (expect_scalar_cache_clean &&
            (scalar_cache_clean_count == 0)) begin
          write_report(1'b0, "expected scalar cache clean activity missing");
          $display("EDGE_SOC_VVP TEST FAIL missing scalar cache clean activity retire_count=%0d",
                   retired_total);
          finish_sim(1);
`ifdef VERILATOR_SIM
          disable edge_soc_vvp_main;
`endif
        end
        report_return_value = 64'd0;
        dump_memory_range();
        write_report(1'b1, "pass retire count reached");
        $display("EDGE_SOC_VVP TEST PASS retire_count=%0d",
                 retired_total);
        finish_sim(0);
`ifdef VERILATOR_SIM
        disable edge_soc_vvp_main;
`endif
      end
    end

    write_report(1'b0, "timeout");
    $display("EDGE_SOC_VVP TEST FAIL timeout retire_count=%0d",
             retired_total);
    finish_sim(1);
`ifdef VERILATOR_SIM
    disable edge_soc_vvp_main;
`endif
  end
endmodule
