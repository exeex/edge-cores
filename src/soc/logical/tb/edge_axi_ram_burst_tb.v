`timescale 1ns/1ps

module edge_axi_ram_burst_tb;
  localparam ADDR_WIDTH = 40;
  localparam DATA_WIDTH = 128;
  localparam ID_WIDTH = 8;
  localparam LEN_WIDTH = 8;

  reg clk;
  reg rst_b;
  reg [ADDR_WIDTH-1:0] araddr;
  reg [ID_WIDTH-1:0] arid;
  reg [LEN_WIDTH-1:0] arlen;
  reg arvalid;
  wire arready;
  wire [DATA_WIDTH-1:0] rdata;
  wire rlast;
  reg rready;
  wire rvalid;
  reg [ADDR_WIDTH-1:0] awaddr;
  reg [ID_WIDTH-1:0] awid;
  reg [LEN_WIDTH-1:0] awlen;
  reg awvalid;
  wire awready;
  wire bvalid;
  reg bready;
  reg [DATA_WIDTH-1:0] wdata;
  reg wlast;
  wire wready;
  reg [(DATA_WIDTH/8)-1:0] wstrb;
  reg wvalid;

  integer wait_i;
  integer beat_i;

  edge_axi_ram #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .RAM_ADDR_BITS(8)
  ) dut (
    .aclk(clk),
    .aresetn(rst_b),
    .araddr(araddr),
    .arburst(2'b01),
    .arcache(4'h0),
    .arid(arid),
    .arlen(arlen),
    .arlock(1'b0),
    .arprot(3'b000),
    .arsize(3'b100),
    .arvalid(arvalid),
    .arready(arready),
    .rdata(rdata),
    .rid(),
    .rlast(rlast),
    .rready(rready),
    .rresp(),
    .rvalid(rvalid),
    .imem_req_valid(1'b0),
    .imem_req_ready(),
    .imem_req_addr({ADDR_WIDTH{1'b0}}),
    .imem_resp_valid(),
    .imem_resp_ready(1'b0),
    .imem_resp_bits(),
    .awaddr(awaddr),
    .awburst(2'b01),
    .awcache(4'h0),
    .awid(awid),
    .awlen(awlen),
    .awlock(1'b0),
    .awprot(3'b000),
    .awsize(3'b100),
    .awvalid(awvalid),
    .awready(awready),
    .bid(),
    .bready(bready),
    .bresp(),
    .bvalid(bvalid),
    .wdata(wdata),
    .wlast(wlast),
    .wready(wready),
    .wstrb(wstrb),
    .wvalid(wvalid)
  );

  always #5 clk = ~clk;

  task fail;
    input [1023:0] msg;
    begin
      $display("EDGE_AXI_RAM_BURST TEST FAIL: %0s", msg);
      $display("awvalid=%0d awready=%0d wvalid=%0d wready=%0d wlast=%0d bvalid=%0d arvalid=%0d arready=%0d rvalid=%0d rlast=%0d",
               awvalid, awready, wvalid, wready, wlast, bvalid,
               arvalid, arready, rvalid, rlast);
      $finish;
    end
  endtask

  task tick;
    begin
      @(posedge clk);
      #1;
    end
  endtask

  function [DATA_WIDTH-1:0] beat_data;
    input integer beat;
    begin
      case (beat)
        0: beat_data = 128'h1111_0000_0000_0000_aaaa_0000_0000_0000;
        1: beat_data = 128'h2222_0000_0000_0000_bbbb_0000_0000_0000;
        2: beat_data = 128'h3333_0000_0000_0000_cccc_0000_0000_0000;
        default: beat_data = 128'h4444_0000_0000_0000_dddd_0000_0000_0000;
      endcase
    end
  endfunction

  initial begin
    clk = 1'b0;
    rst_b = 1'b0;
    araddr = 40'h0;
    arid = 8'h0;
    arlen = 8'h0;
    arvalid = 1'b0;
    rready = 1'b0;
    awaddr = 40'h0;
    awid = 8'h0;
    awlen = 8'h0;
    awvalid = 1'b0;
    bready = 1'b0;
    wdata = 128'h0;
    wlast = 1'b0;
    wstrb = 16'h0;
    wvalid = 1'b0;

    repeat (3) tick();
    rst_b = 1'b1;
    tick();

    awaddr = 40'h0000_1000;
    awid = 8'h44;
    awlen = 8'h03;
    awvalid = 1'b1;
    bready = 1'b1;
    #1;
    wait_i = 0;
    while (!awready && wait_i < 40) begin
      tick();
      wait_i = wait_i + 1;
    end
    if (!awready)
      fail("write address burst was not accepted");
    tick();
    awvalid = 1'b0;

    for (beat_i = 0; beat_i < 4; beat_i = beat_i + 1) begin
      wdata = beat_data(beat_i);
      wstrb = 16'hffff;
      wlast = beat_i == 3;
      wvalid = 1'b1;
      #1;
      wait_i = 0;
      while (!wready && wait_i < 40) begin
        tick();
        wait_i = wait_i + 1;
      end
      if (!wready)
        fail("write data beat was not accepted");
      if (bvalid && beat_i != 3)
        fail("write response arrived before final burst beat");
      tick();
    end
    wvalid = 1'b0;
    wlast = 1'b0;
    wait_i = 0;
    while (!bvalid && wait_i < 40) begin
      tick();
      wait_i = wait_i + 1;
    end
    if (!bvalid)
      fail("write response did not arrive after final burst beat");
    tick();
    bready = 1'b0;

    araddr = 40'h0000_1000;
    arid = 8'h55;
    arlen = 8'h03;
    arvalid = 1'b1;
    rready = 1'b1;
    #1;
    wait_i = 0;
    while (!arready && wait_i < 40) begin
      tick();
      wait_i = wait_i + 1;
    end
    if (!arready)
      fail("read address burst was not accepted");
    tick();
    arvalid = 1'b0;

    for (beat_i = 0; beat_i < 4; beat_i = beat_i + 1) begin
      wait_i = 0;
      while (!rvalid && wait_i < 40) begin
        tick();
        wait_i = wait_i + 1;
      end
      if (!rvalid)
        fail("read data beat did not arrive");
      if (rdata !== beat_data(beat_i))
        fail("readback burst data mismatch");
      if (rlast !== (beat_i == 3))
        fail("readback burst last flag mismatch");
      tick();
    end

    $display("EDGE_AXI_RAM_BURST TEST PASS");
    $finish;
  end
endmodule
