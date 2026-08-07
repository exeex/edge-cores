`timescale 1ns/1ps

module edge_soc_top_imem_smoke_tb;
  localparam ADDR_WIDTH = 40;
  localparam DATA_WIDTH = 128;
  localparam ID_WIDTH = 8;
  localparam LEN_WIDTH = 8;

  reg clk;
  reg rst_b;
  reg core_start;
  wire core0_pad_halted;

  edge_soc_top #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .LEN_WIDTH(LEN_WIDTH)
  ) dut (
    .pll_core_cpuclk(clk),
    .pad_cpu_rst_b(rst_b),
    .core_boot_pc({ADDR_WIDTH{1'b0}}),
    .core_start(core_start),
    .core_force_stop(1'b0),
    .edge_dtcm_base(40'h0040_0000_00),
    .edge_dtcm_mask(40'hffff_fff0_00),
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
    .core0_pad_halted(core0_pad_halted)
  );

  always #5 clk = ~clk;

  task fail;
    input [1023:0] msg;
    begin
      $display("EDGE_SOC_TOP_IMEM_SMOKE TEST FAIL: %0s", msg);
      $display("icache_req_valid=%0d icache_req_ready=%0d icache_req_addr=%h icache_resp_valid=%0d token0_valid=%0d token0_inst=%h",
               dut.core_top.base.icache_refill_req_valid,
               dut.core_top.base.icache_refill_req_ready,
               dut.core_top.base.icache_refill_req_addr,
               dut.core_top.base.icache_refill_resp_valid,
               dut.core_top.base.debug_token0_valid, dut.core_top.base.token0_inst32);
      $finish;
    end
  endtask

  task tick;
    begin
      @(posedge clk);
      #1;
    end
  endtask

  integer cycle;
  reg saw_initial_req;
  reg saw_imem_response;
  reg saw_token;

  initial begin
    clk = 1'b0;
    rst_b = 1'b0;
    core_start = 1'b0;
    saw_initial_req = 1'b0;
    saw_imem_response = 1'b0;
    saw_token = 1'b0;

    repeat (2) tick();
    if (!core0_pad_halted)
      fail("halted output should assert during reset");
    rst_b = 1'b1;
    @(negedge clk);
    core_start = 1'b1;
    @(negedge clk);
    core_start = 1'b0;

    for (cycle = 0; cycle < 40; cycle = cycle + 1) begin
      tick();
      if (!saw_imem_response && !saw_initial_req
          && dut.core_top.base.icache_refill_req_valid
          && dut.core_top.base.icache_refill_req_ready) begin
        saw_initial_req = 1'b1;
        if (dut.core_top.base.icache_refill_req_addr !== 40'h0)
          fail("first I-cache refill should fetch boot block zero");
      end
      if (dut.core_top.base.icache_refill_resp_valid) begin
        saw_imem_response = 1'b1;
        if (dut.core_top.base.icache_refill_resp_bits !== 128'h00000013_00000013_00700093_00000013)
          fail("I-cache refill response did not match mem128 preload");
      end
      if (dut.core_top.base.debug_token0_valid
          && dut.core_top.base.debug_token0_kind == 2'b00
          && dut.core_top.base.token0_inst32 == 32'h00000013)
        saw_token = 1'b1;
      if (saw_imem_response && saw_token) begin
        $display("EDGE_SOC_TOP_IMEM_SMOKE TEST PASS");
        $finish;
      end
    end

    fail("core did not fetch and tokenize the mem128 boot block");
  end
endmodule
