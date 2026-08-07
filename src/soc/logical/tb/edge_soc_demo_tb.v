`timescale 1ns/1ps

// Public encrypted-core testbench. Keep this on module ports and public SoC
// RAM; the hierarchy below edge_core_debug is intentionally obfuscated.
module edge_soc_demo_tb;
  localparam ADDR_WIDTH = 40;
  localparam DATA_WIDTH = 128;
  localparam ID_WIDTH = 8;
  localparam LEN_WIDTH = 8;
  localparam SOC_RAM_ADDR_BITS = 23;

  reg clk = 1'b0;
  reg rst_b = 1'b0;
  reg core_start = 1'b0;
  integer cycle = 0;
  integer max_cycles = 500000;
  integer report_fd;
  reg [4095:0] report_path = "run_case.report";
  wire core_csr_break_valid;
  wire [63:0] core_csr_break_code;
  wire [7:0] core_csr_break_seq_id;
  wire [3:0] core_csr_break_epoch;
  wire core_csr_putchar_valid;
  wire [7:0] core_csr_putchar_char;

  function [15:0] expected_bf16;
    input integer elem;
    begin
      case (elem % 13)
        0: expected_bf16 = 16'hc0c0;
        1: expected_bf16 = 16'hc0a0;
        2: expected_bf16 = 16'hc080;
        3: expected_bf16 = 16'hc040;
        4: expected_bf16 = 16'hc000;
        5: expected_bf16 = 16'hbf80;
        6: expected_bf16 = 16'h0000;
        7: expected_bf16 = 16'h3f80;
        8: expected_bf16 = 16'h4000;
        9: expected_bf16 = 16'h4040;
        10: expected_bf16 = 16'h4080;
        11: expected_bf16 = 16'h40a0;
        default: expected_bf16 = 16'h40c0;
      endcase
    end
  endfunction

  task write_report;
    input passed;
    input [1023:0] reason;
    begin
      report_fd = $fopen(report_path, "w");
      if (passed) $fdisplay(report_fd, "TEST PASS");
      else begin
        $fdisplay(report_fd, "TEST FAIL");
        $fdisplay(report_fd, "REASON=%0s", reason);
      end
      $fdisplay(report_fd, "RETURN_VALUE=%0d", core_csr_break_code);
      $fdisplay(report_fd, "CYCLE=%0d", cycle);
      $fclose(report_fd);
    end
  endtask

  task check_output;
    output ok;
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
          expected_word[lane_i * 16 +: 16] = expected_bf16(elem_i);
        end
        got_word = dut.soc_ram.mem[(40'h0010_0000 >> 4) + word_i];
        if (got_word !== expected_word) begin
          ok = 1'b0;
          $display("EDGE_DEMO output mismatch word=%0d got=%032h expected=%032h",
                   word_i, got_word, expected_word);
        end
      end
    end
  endtask

  edge_soc_top #(
    .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH), .LEN_WIDTH(LEN_WIDTH),
    .SOC_RAM_ADDR_BITS(SOC_RAM_ADDR_BITS)
  ) dut (
    .pll_core_cpuclk(clk), .pad_cpu_rst_b(rst_b),
    .core_boot_pc({ADDR_WIDTH{1'b0}}), .core_start(core_start),
    .core_force_stop(1'b0),
    .edge_dtcm_base(40'h0040_0000_00),
    .edge_dtcm_mask(40'hffff_fe00_00), .edge_dtcm_enable(1'b1),
    .edge_dma_start_addr_src(40'h0), .edge_dma_start_addr_dst(40'h0),
    .edge_dma_start_len(32'd0), .edge_dma_start_req(1'b0),
    .bringup_core_araddr({ADDR_WIDTH{1'b0}}), .bringup_core_arburst(2'b01),
    .bringup_core_arcache(4'h0), .bringup_core_arid({ID_WIDTH{1'b0}}),
    .bringup_core_arlen({LEN_WIDTH{1'b0}}), .bringup_core_arlock(1'b0),
    .bringup_core_arprot(3'b0), .bringup_core_arsize(3'b100),
    .bringup_core_arvalid(1'b0), .bringup_core_rready(1'b0),
    .bringup_core_awaddr({ADDR_WIDTH{1'b0}}), .bringup_core_awburst(2'b01),
    .bringup_core_awcache(4'h0), .bringup_core_awid({ID_WIDTH{1'b0}}),
    .bringup_core_awlen({LEN_WIDTH{1'b0}}), .bringup_core_awlock(1'b0),
    .bringup_core_awprot(3'b0), .bringup_core_awsize(3'b100),
    .bringup_core_awvalid(1'b0), .bringup_core_bready(1'b0),
    .bringup_core_wdata({DATA_WIDTH{1'b0}}), .bringup_core_wlast(1'b0),
    .bringup_core_wstrb({(DATA_WIDTH/8){1'b0}}), .bringup_core_wvalid(1'b0),
    .bringup_dma_araddr({ADDR_WIDTH{1'b0}}), .bringup_dma_arburst(2'b01),
    .bringup_dma_arcache(4'h0), .bringup_dma_arid({ID_WIDTH{1'b0}}),
    .bringup_dma_arlen({LEN_WIDTH{1'b0}}), .bringup_dma_arlock(1'b0),
    .bringup_dma_arprot(3'b0), .bringup_dma_arsize(3'b100),
    .bringup_dma_arvalid(1'b0), .bringup_dma_rready(1'b0),
    .bringup_dma_awaddr({ADDR_WIDTH{1'b0}}), .bringup_dma_awburst(2'b01),
    .bringup_dma_awcache(4'h0), .bringup_dma_awid({ID_WIDTH{1'b0}}),
    .bringup_dma_awlen({LEN_WIDTH{1'b0}}), .bringup_dma_awlock(1'b0),
    .bringup_dma_awprot(3'b0), .bringup_dma_awsize(3'b100),
    .bringup_dma_awvalid(1'b0), .bringup_dma_bready(1'b0),
    .bringup_dma_wdata({DATA_WIDTH{1'b0}}), .bringup_dma_wlast(1'b0),
    .bringup_dma_wstrb({(DATA_WIDTH/8){1'b0}}), .bringup_dma_wvalid(1'b0),
    .pad_biu_arready(1'b0), .pad_biu_rdata({DATA_WIDTH{1'b0}}),
    .pad_biu_rid({ID_WIDTH{1'b0}}), .pad_biu_rlast(1'b0),
    .pad_biu_rresp(2'b0), .pad_biu_rvalid(1'b0),
    .pad_biu_awready(1'b0), .pad_biu_bid({ID_WIDTH{1'b0}}),
    .pad_biu_bresp(2'b0), .pad_biu_bvalid(1'b0), .pad_biu_wready(1'b0),
    .core_csr_break_valid(core_csr_break_valid),
    .core_csr_break_code(core_csr_break_code),
    .core_csr_break_seq_id(core_csr_break_seq_id),
    .core_csr_break_epoch(core_csr_break_epoch),
    .core_csr_putchar_valid(core_csr_putchar_valid),
    .core_csr_putchar_char(core_csr_putchar_char)
  );

  always #5 clk = ~clk;

  initial begin
    if (!$value$plusargs("max_cycles=%d", max_cycles)) max_cycles = 500000;
    if (!$value$plusargs("run_case_report=%s", report_path))
      report_path = "run_case.report";
    repeat (4) @(posedge clk);
    rst_b = 1'b1;
    @(negedge clk); core_start = 1'b1;
    @(negedge clk); core_start = 1'b0;
  end

  always @(posedge clk) begin : monitor
    reg output_ok;
    if (rst_b) begin
      cycle <= cycle + 1;
      if (core_csr_putchar_valid) begin
        $write("%c", core_csr_putchar_char);
        $fflush();
      end
      if (core_csr_break_valid) begin
        if (core_csr_break_code != 0) begin
          write_report(1'b0, "non-zero return value");
          $fatal(1, "EDGE_DEMO return=%0d", core_csr_break_code);
        end
        check_output(output_ok);
        if (!output_ok) begin
          write_report(1'b0, "tensor output mismatch");
          $fatal(1, "EDGE_DEMO tensor output mismatch");
        end
        write_report(1'b1, "pass");
        $display("EDGE_DEMO TEST PASS cycle=%0d seq=%0d epoch=%0d",
                 cycle, core_csr_break_seq_id, core_csr_break_epoch);
        $finish;
      end
      if (cycle >= max_cycles) begin
        write_report(1'b0, "timeout");
        $fatal(1, "EDGE_DEMO timeout after %0d cycles", cycle);
      end
    end
  end
endmodule
