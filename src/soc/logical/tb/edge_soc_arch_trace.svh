// SPDX-License-Identifier: Apache-2.0
// Optional observation only. Values are sampled immediately before each rising
// edge, matching the monitor's cycle counter and handshake/commit decisions.
// Keep hierarchical references here, outside the synthesizable public cores.
`define EDGE_ARCH_DTCM dut.core_top.platform.dtcm.x_edge_dtcm_subsys_core
`define EDGE_ARCH_TENSOR `EDGE_ARCH_DTCM.x_edge_tensor_unit_bank16
`define EDGE_ARCH_ENGINE `EDGE_ARCH_TENSOR.x_tensor_engine
`define EDGE_ARCH_WEIGHT `EDGE_ARCH_ENGINE.x_tile8x8.GEN_PACKED.x_tile.x_packed_bank
`define EDGE_ARCH_CORE dut.core_top.core.cached_core.core
  integer arch_trace_fd = 0;
  integer arch_trace_rows = 0;
  integer arch_trace_limit = 200000;
  integer arch_trace_command = -1;
  reg arch_trace_active = 1'b0;
  reg [4095:0] arch_trace_path;
  initial begin
    if ($value$plusargs("arch_trace=%s", arch_trace_path)) begin
      arch_trace_fd = $fopen(arch_trace_path, "w");
      if (arch_trace_fd == 0) $fatal(1, "Cannot open architecture trace");
      if (!$value$plusargs("arch_trace_limit=%d", arch_trace_limit))
        arch_trace_limit = 200000;
      if (!$value$plusargs("arch_trace_command=%d", arch_trace_command))
        arch_trace_command = -1;
      arch_trace_active = arch_trace_command < 0;
      $fdisplay(arch_trace_fd,"cycle,if_valid,if_ready,if_pc,if_inst,id_valid,id_pc,id_inst,ex_valid,ex_pc,ex_inst,ex_release_ready,ex_done,wb_pending,wb_commit,actu_busy,actu_sync_stall,cmd_fire,cmd_inst,cmd_capture,accel_response,dma_busy,dma_write,wld_active,wld_read,wld_done,weight_transport,weight_activate,weight_valid,active_bank,fill_bank,weight_pending,start_accept,engine_start,queued_start,compute_busy,compute_issue,dot_output,output_write,write_tail,handoff,engine_done,tensor_busy,tensor_sync_stall");
    end
  end
  always @(posedge clk) begin
    if (rst_b && arch_trace_fd != 0) begin
      if (command_fire && dut.core_top.platform.dispatch.cmd_inst[31:25] == arch_trace_command[6:0])
        arch_trace_active = 1'b1;
      if (arch_trace_active) begin
        if (arch_trace_rows >= arch_trace_limit)
          $fatal(1,"Architecture trace limit reached; raise arch_trace_limit");
        $fdisplay(arch_trace_fd,"%0d,%0d,%0d,%08h,%08h,%0d,%08h,%08h,%0d,%08h,%08h,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%08h,%016h,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
          cycle,`EDGE_ARCH_CORE.if_valid,`EDGE_ARCH_CORE.if_ready,
          `EDGE_ARCH_CORE.if_pc,`EDGE_ARCH_CORE.if_inst,
          `EDGE_ARCH_CORE.id_valid,`EDGE_ARCH_CORE.id_pc,`EDGE_ARCH_CORE.id_inst,
          `EDGE_ARCH_CORE.ex_valid,`EDGE_ARCH_CORE.ex_stage.ex_pc,
          `EDGE_ARCH_CORE.ex_stage.ex_inst,`EDGE_ARCH_CORE.ex_release_ready,
          `EDGE_ARCH_CORE.ex_done,`EDGE_ARCH_CORE.wb_pending_q,
          `EDGE_ARCH_CORE.wb_commit,dut.core_top.platform.actu_busy,
          dut.core_top.platform.actu_sync_stall,command_fire,
          dut.core_top.platform.dispatch.cmd_inst,
          dut.core_top.platform.dispatch.cmd_capture_value,
          dut.core_top.accel_resp_valid,
          dut.core_top.platform.dma_busy,
          (`EDGE_ARCH_DTCM.dma_dtcm_req && `EDGE_ARCH_DTCM.dma_ready && `EDGE_ARCH_DTCM.dma_dtcm_we),
          `EDGE_ARCH_TENSOR.wld_active_q,
          `EDGE_ARCH_TENSOR.wld_read_fire,
          `EDGE_ARCH_TENSOR.wld_fill_done,
          `EDGE_ARCH_WEIGHT.x_packed.GEN_DOT_RELAY.x_weights.busy_o,
          `EDGE_ARCH_WEIGHT.activate_accept,
          `EDGE_ARCH_WEIGHT.active_valid_q,
          `EDGE_ARCH_WEIGHT.active_bank_q,
          `EDGE_ARCH_WEIGHT.fill_bank_q,
          `EDGE_ARCH_WEIGHT.pending_valid_q,
          `EDGE_ARCH_TENSOR.start_accept,
          `EDGE_ARCH_TENSOR.engine_start,
          `EDGE_ARCH_TENSOR.queued_start_valid_q,
          `EDGE_ARCH_ENGINE.compute_busy_q,
          `EDGE_ARCH_ENGINE.compute_valid_q,
          `EDGE_ARCH_ENGINE.tensor_output_valid,
          `EDGE_ARCH_ENGINE.output_write_fire,
          (|`EDGE_ARCH_ENGINE.write_pipe),
          `EDGE_ARCH_ENGINE.handoff_ready,
          `EDGE_ARCH_ENGINE.done,
          dut.core_top.platform.tensor_busy,
          dut.core_top.platform.tensor_sync_stall);
        arch_trace_rows = arch_trace_rows + 1;
      end
    end
  end
  final begin
    if (arch_trace_fd != 0) $fclose(arch_trace_fd);
  end
`undef EDGE_ARCH_CORE

`undef EDGE_ARCH_DTCM
`undef EDGE_ARCH_TENSOR
`undef EDGE_ARCH_ENGINE
`undef EDGE_ARCH_WEIGHT
