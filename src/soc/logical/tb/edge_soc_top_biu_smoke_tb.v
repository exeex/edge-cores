`timescale 1ns/1ps

module edge_soc_top_biu_smoke_tb;
  localparam ADDR_WIDTH = 40;
  localparam DATA_WIDTH = 128;
  localparam ID_WIDTH = 8;
  localparam LEN_WIDTH = 8;

  reg clk;
  reg rst_b;
  reg core_start;
  reg edge_dma_start_req;
  wire edge_dma_busy;
  reg [ADDR_WIDTH-1:0] core_araddr;
  reg [ID_WIDTH-1:0] core_arid;
  reg core_arvalid;
  wire core_arready;
  wire [DATA_WIDTH-1:0] core_rdata;
  wire core_rvalid;
  wire [1:0] core_rresp;
  reg core_rready;
  reg [ADDR_WIDTH-1:0] dma_araddr;
  reg [ID_WIDTH-1:0] dma_arid;
  reg dma_arvalid;
  wire dma_arready;
  wire [DATA_WIDTH-1:0] dma_rdata;
  wire dma_rvalid;
  wire [1:0] dma_rresp;
  reg dma_rready;
  reg [ADDR_WIDTH-1:0] core_awaddr;
  reg [ID_WIDTH-1:0] core_awid;
  reg core_awvalid;
  wire core_awready;
  reg core_bready;
  wire core_bvalid;
  wire [1:0] core_bresp;
  reg [DATA_WIDTH-1:0] core_wdata;
  reg core_wlast;
  wire core_wready;
  reg [(DATA_WIDTH/8)-1:0] core_wstrb;
  reg core_wvalid;
  wire [ADDR_WIDTH-1:0] biu_pad_araddr;
  wire [ID_WIDTH-1:0] biu_pad_arid;
  wire biu_pad_arvalid;
  wire biu_pad_rready;
  wire core0_pad_halted;
  wire debug_biu_read_owner_valid;
  wire debug_biu_read_owner_dma;
  wire debug_biu_write_owner_valid;
  wire debug_biu_write_owner_dma;

  edge_soc_top #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .ENABLE_IMEM(0)
  ) dut (
    .pll_core_cpuclk(clk),
    .pad_cpu_rst_b(rst_b),
    .core_boot_pc({ADDR_WIDTH{1'b0}}),
    .core_start(core_start),
    .core_force_stop(1'b0),
    .edge_dtcm_base(40'h0040_0000_00),
    .edge_dtcm_mask(40'hffff_fff0_00),
    .edge_dtcm_enable(1'b1),
    .edge_dma_start_addr_src(40'h0400_0000),
    .edge_dma_start_addr_dst(40'h0040_0000_00),
    .edge_dma_start_len(32'd16),
    .edge_dma_start_req(edge_dma_start_req),
    .edge_dma_busy(edge_dma_busy),
    .bringup_core_araddr(core_araddr),
    .bringup_core_arburst(2'b01),
    .bringup_core_arcache(4'h0),
    .bringup_core_arid(core_arid),
    .bringup_core_arlen(8'h0),
    .bringup_core_arlock(1'b0),
    .bringup_core_arprot(3'b000),
    .bringup_core_arsize(3'b100),
    .bringup_core_arvalid(core_arvalid),
    .bringup_core_arready(core_arready),
    .bringup_core_rdata(core_rdata),
    .bringup_core_rready(core_rready),
    .bringup_core_rresp(core_rresp),
    .bringup_core_rvalid(core_rvalid),
    .bringup_core_awaddr(core_awaddr),
    .bringup_core_awburst(2'b01),
    .bringup_core_awcache(4'h0),
    .bringup_core_awid(core_awid),
    .bringup_core_awlen({LEN_WIDTH{1'b0}}),
    .bringup_core_awlock(1'b0),
    .bringup_core_awprot(3'b000),
    .bringup_core_awsize(3'b100),
    .bringup_core_awvalid(core_awvalid),
    .bringup_core_awready(core_awready),
    .bringup_core_bready(core_bready),
    .bringup_core_bresp(core_bresp),
    .bringup_core_bvalid(core_bvalid),
    .bringup_core_wdata(core_wdata),
    .bringup_core_wlast(core_wlast),
    .bringup_core_wready(core_wready),
    .bringup_core_wstrb(core_wstrb),
    .bringup_core_wvalid(core_wvalid),
    .bringup_dma_araddr(dma_araddr),
    .bringup_dma_arburst(2'b01),
    .bringup_dma_arcache(4'h0),
    .bringup_dma_arid(dma_arid),
    .bringup_dma_arlen(8'h0),
    .bringup_dma_arlock(1'b0),
    .bringup_dma_arprot(3'b000),
    .bringup_dma_arsize(3'b100),
    .bringup_dma_arvalid(dma_arvalid),
    .bringup_dma_arready(dma_arready),
    .bringup_dma_rdata(dma_rdata),
    .bringup_dma_rready(dma_rready),
    .bringup_dma_rresp(dma_rresp),
    .bringup_dma_rvalid(dma_rvalid),
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
    .biu_pad_araddr(biu_pad_araddr),
    .biu_pad_arid(biu_pad_arid),
    .biu_pad_arvalid(biu_pad_arvalid),
    .pad_biu_arready(1'b0),
    .pad_biu_rdata({DATA_WIDTH{1'b0}}),
    .pad_biu_rid({ID_WIDTH{1'b0}}),
    .pad_biu_rlast(1'b0),
    .pad_biu_rresp(2'b00),
    .pad_biu_rvalid(1'b0),
    .biu_pad_rready(biu_pad_rready),
    .pad_biu_awready(1'b0),
    .pad_biu_bid({ID_WIDTH{1'b0}}),
    .pad_biu_bresp(2'b00),
    .pad_biu_bvalid(1'b0),
    .pad_biu_wready(1'b0),
    .core0_pad_halted(core0_pad_halted),
    .debug_biu_read_owner_valid(debug_biu_read_owner_valid),
    .debug_biu_read_owner_dma(debug_biu_read_owner_dma),
    .debug_biu_write_owner_valid(debug_biu_write_owner_valid),
    .debug_biu_write_owner_dma(debug_biu_write_owner_dma)
  );

  always #5 clk = ~clk;

  task fail;
    input [1023:0] msg;
    begin
      $display("EDGE_SOC_TOP_BIU_SMOKE TEST FAIL: %0s", msg);
      $display("biu_arvalid=%0d biu_araddr=%h biu_arid=%h dma_arready=%0d edge_dma_busy=%0d read_owner=%0d read_dma=%0d",
               biu_pad_arvalid, biu_pad_araddr, biu_pad_arid, dma_arready,
               edge_dma_busy, debug_biu_read_owner_valid, debug_biu_read_owner_dma);
      $display("soc_read_pending=%0d soc_ram_rvalid=%0d soc_ram_rready=%0d core_dtcm_rvalid=%0d core_dtcm_rready=%0d core_dtcm_rlast=%0d",
               dut.soc_axi.read_pending_q, dut.soc_ram.rvalid_q, dut.ram_rready,
               dut.core_top.base.dtcm_dma_rvalid, dut.core_top.base.dtcm_dma_rready,
               dut.core_top.base.dtcm_dma_rlast);
      $display("write_owner=%0d write_dma=%0d soc_write_pending=%0d soc_write_err=%0d ram_awready=%0d ram_awvalid=%0d ram_wready=%0d ram_wvalid=%0d ram_bvalid=%0d",
               debug_biu_write_owner_valid, debug_biu_write_owner_dma,
               dut.soc_axi.write_pending_q, dut.soc_axi.write_err_q,
               dut.ram_awready, dut.ram_awvalid, dut.ram_wready,
               dut.ram_wvalid, dut.ram_bvalid);
      $finish;
    end
  endtask

  task tick;
    begin
      @(posedge clk);
      #1;
    end
  endtask

  task core_write_beat;
    input [ADDR_WIDTH-1:0] addr;
    input [DATA_WIDTH-1:0] data;
    begin
      core_awaddr = addr;
      core_awid = 8'hc1;
      core_awvalid = 1'b1;
      core_wdata = data;
      core_wlast = 1'b1;
      core_wstrb = {DATA_WIDTH/8{1'b1}};
      core_wvalid = 1'b0;
      core_bready = 1'b1;
      #1;
      wait_i = 0;
      while (!core_awready && wait_i < 40) begin
        tick();
        wait_i = wait_i + 1;
      end
      if (!core_awready)
        fail("core write AW channel did not become ready");
      tick();
      core_awvalid = 1'b0;
      core_wvalid = 1'b1;
      #1;
      wait_i = 0;
      while (!core_wready && wait_i < 40) begin
        tick();
        wait_i = wait_i + 1;
      end
      if (!core_wready)
        fail("core write W channel did not become ready");
      tick();
      core_wvalid = 1'b0;
      wait_i = 0;
      while (!core_bvalid && wait_i < 40) begin
        tick();
        wait_i = wait_i + 1;
      end
      if (!core_bvalid)
        fail("core write B response did not become valid");
      if (core_bresp !== 2'b00)
        fail("core write returned non-OKAY response");
      tick();
      core_bready = 1'b0;
    end
  endtask

  task core_read_beat;
    input [ADDR_WIDTH-1:0] addr;
    input [DATA_WIDTH-1:0] expected;
    begin
      core_araddr = addr;
      core_arid = 8'h31;
      core_arvalid = 1'b1;
      core_rready = 1'b1;
      #1;
      wait_i = 0;
      while (!core_arready && wait_i < 40) begin
        tick();
        wait_i = wait_i + 1;
      end
      if (!core_arready)
        fail("core read AR channel did not become ready");
      tick();
      core_arvalid = 1'b0;
      wait_i = 0;
      while (!core_rvalid && wait_i < 40) begin
        tick();
        wait_i = wait_i + 1;
      end
      if (!core_rvalid)
        fail("core read R response did not become valid");
      if (core_rresp !== 2'b00 || core_rdata !== expected)
        fail("core write/readback data mismatch");
      tick();
      core_rready = 1'b0;
    end
  endtask

  integer cycle;
  integer wait_i;

  function [DATA_WIDTH-1:0] ram_default_data;
    input [ADDR_WIDTH-1:0] addr;
    reg [31:0] index;
    begin
      index = {22'b0, addr[13:4]};
      ram_default_data = {
        32'h4544_4745,
        index,
        index ^ 32'h5a5a_5a5a,
        32'h534f_4352
      };
    end
  endfunction

  initial begin
    clk = 1'b0;
    rst_b = 1'b0;
    core_start = 1'b0;
    edge_dma_start_req = 1'b0;
    core_araddr = 40'h0;
    core_arid = 8'h0;
    core_arvalid = 1'b0;
    core_rready = 1'b0;
    dma_araddr = 40'h0;
    dma_arid = 8'h0;
    dma_arvalid = 1'b0;
    dma_rready = 1'b0;
    core_awaddr = 40'h0;
    core_awid = 8'h0;
    core_awvalid = 1'b0;
    core_bready = 1'b0;
    core_wdata = 128'h0;
    core_wlast = 1'b0;
    core_wstrb = 16'h0;
    core_wvalid = 1'b0;

    repeat (2) tick();
    if (!core0_pad_halted)
      fail("halted output should assert during reset");
    rst_b = 1'b1;
    @(negedge clk);
    core_start = 1'b1;
    @(negedge clk);
    core_start = 1'b0;
    tick();
    if (core0_pad_halted)
      fail("halted output should clear after reset");

    core_araddr = 40'h0100_1000;
    core_arid = 8'h11;
    core_arvalid = 1'b1;
    core_rready = 1'b1;
    #1;
    if (!biu_pad_arvalid || !core_arready || biu_pad_araddr !== 40'h0100_1000)
      fail("core read did not reach SoC fabric");
    tick();
    core_arvalid = 1'b0;
    #1;
    if (!core_rvalid || dma_rvalid || !biu_pad_rready)
      fail("core read response did not return from SoC RAM");
    if (core_rdata !== ram_default_data(40'h0100_1000) || core_rresp !== 2'b00)
      fail("core read response from SoC RAM mismatch");
    tick();

    core_araddr = 40'h1_0000_1000;
    core_arid = 8'hee;
    core_arvalid = 1'b1;
    #1;
    if (!biu_pad_arvalid || !core_arready || biu_pad_araddr !== 40'h1_0000_1000)
      fail("core error read did not reach SoC fabric");
    tick();
    core_arvalid = 1'b0;
    #1;
    if (!core_rvalid || core_rresp !== 2'b10)
      fail("SoC error slave did not return SLVERR");
    tick();

    core_araddr = 40'h0200_0000;
    core_arid = 8'h22;
    core_arvalid = 1'b1;
    dma_araddr = 40'h0300_0000;
    dma_arid = 8'hd3;
    dma_arvalid = 1'b1;
    dma_rready = 1'b1;
    #1;
    if (!dma_arready || core_arready || biu_pad_araddr !== 40'h0300_0000)
      fail("DMA did not win core BIU priority before SoC fabric");
    tick();
    dma_arvalid = 1'b0;
    if (!debug_biu_read_owner_valid || !debug_biu_read_owner_dma)
      fail("SoC debug did not expose DMA read owner");
    #1;
    if (!dma_rvalid || core_rvalid || !biu_pad_rready)
      fail("DMA read response did not return from SoC RAM");
    if (dma_rdata !== ram_default_data(40'h0300_0000) || dma_rresp !== 2'b00)
      fail("DMA read response from SoC RAM mismatch");
    tick();
    core_arvalid = 1'b0;
    dma_rready = 1'b0;

    core_write_beat(40'h0007_ffc0,
                    128'h1111_0000_0000_0000_1111_0000_0000_0000);
    core_write_beat(40'h0007_ffd0,
                    128'h2222_0000_0000_0000_2222_0000_0000_0000);
    core_write_beat(40'h0007_ffe0,
                    128'h3333_0000_0000_0000_3333_0000_0000_0000);
    core_write_beat(40'h0007_fff0,
                    128'h0000_0000_0000_0038_0000_0000_0000_0000);
    core_read_beat(40'h0007_ffc0,
                   128'h1111_0000_0000_0000_1111_0000_0000_0000);
    core_read_beat(40'h0007_ffd0,
                   128'h2222_0000_0000_0000_2222_0000_0000_0000);
    core_read_beat(40'h0007_ffe0,
                   128'h3333_0000_0000_0000_3333_0000_0000_0000);
    core_read_beat(40'h0007_fff0,
                   128'h0000_0000_0000_0038_0000_0000_0000_0000);

    dma_araddr = 40'h0;
    dma_arid = 8'h0;
    dma_arvalid = 1'b0;
    edge_dma_start_req = 1'b1;
    tick();
    edge_dma_start_req = 1'b0;
    if (!edge_dma_busy)
      fail("internal DTCM DMA did not enter busy state");
    for (cycle = 0; cycle < 40; cycle = cycle + 1) begin
      tick();
      if (!edge_dma_busy) begin
        $display("EDGE_SOC_TOP_BIU_SMOKE TEST PASS");
        $finish;
      end
    end
    fail("internal DTCM DMA did not complete");

    $finish;
  end
endmodule
