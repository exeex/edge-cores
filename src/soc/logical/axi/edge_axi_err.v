`timescale 1ns/1ps

module edge_axi_err #(
  parameter ADDR_WIDTH = 40,
  parameter DATA_WIDTH = 128,
  parameter ID_WIDTH = 8,
  parameter LEN_WIDTH = 8
) (
  input                         aclk,
  input                         aresetn,

  input  [ADDR_WIDTH-1:0]       araddr,
  input  [1:0]                  arburst,
  input  [3:0]                  arcache,
  input  [ID_WIDTH-1:0]         arid,
  input  [LEN_WIDTH-1:0]        arlen,
  input                         arlock,
  input  [2:0]                  arprot,
  input  [2:0]                  arsize,
  input                         arvalid,
  output                        arready,
  output [DATA_WIDTH-1:0]       rdata,
  output [ID_WIDTH-1:0]         rid,
  output                        rlast,
  input                         rready,
  output [1:0]                  rresp,
  output                        rvalid,

  input  [ADDR_WIDTH-1:0]       awaddr,
  input  [1:0]                  awburst,
  input  [3:0]                  awcache,
  input  [ID_WIDTH-1:0]         awid,
  input  [LEN_WIDTH-1:0]        awlen,
  input                         awlock,
  input  [2:0]                  awprot,
  input  [2:0]                  awsize,
  input                         awvalid,
  output                        awready,
  output [ID_WIDTH-1:0]         bid,
  input                         bready,
  output [1:0]                  bresp,
  output                        bvalid,
  input  [DATA_WIDTH-1:0]       wdata,
  input                         wlast,
  output                        wready,
  input  [(DATA_WIDTH/8)-1:0]   wstrb,
  input                         wvalid
);

  reg [ID_WIDTH-1:0] rid_q;
  reg                rvalid_q;
  reg [ID_WIDTH-1:0] awid_q;
  reg                aw_pending_q;
  reg [ID_WIDTH-1:0] bid_q;
  reg                bvalid_q;

  wire ar_fire;
  wire aw_fire;
  wire w_fire;
  wire b_fire;

  assign arready = !rvalid_q;
  assign ar_fire = arvalid && arready;
  assign rid[ID_WIDTH-1:0] = rid_q[ID_WIDTH-1:0];
  assign rdata[DATA_WIDTH-1:0] = {DATA_WIDTH{1'b1}};
  assign rlast = rvalid_q;
  assign rresp[1:0] = 2'b10;
  assign rvalid = rvalid_q;

  assign awready = !aw_pending_q && !bvalid_q;
  assign aw_fire = awvalid && awready;
  assign wready = aw_pending_q && !bvalid_q;
  assign w_fire = wvalid && wready;
  assign bid[ID_WIDTH-1:0] = bid_q[ID_WIDTH-1:0];
  assign bresp[1:0] = 2'b10;
  assign bvalid = bvalid_q;
  assign b_fire = bvalid_q && bready;

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      rid_q <= {ID_WIDTH{1'b0}};
      rvalid_q <= 1'b0;
    end else begin
      if (ar_fire) begin
        rid_q <= arid[ID_WIDTH-1:0];
        rvalid_q <= 1'b1;
      end else if (rvalid_q && rready) begin
        rvalid_q <= 1'b0;
      end
    end
  end

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      awid_q <= {ID_WIDTH{1'b0}};
      aw_pending_q <= 1'b0;
      bid_q <= {ID_WIDTH{1'b0}};
      bvalid_q <= 1'b0;
    end else begin
      if (aw_fire) begin
        awid_q <= awid[ID_WIDTH-1:0];
        aw_pending_q <= 1'b1;
      end

      if (w_fire) begin
        bid_q <= awid_q;
        bvalid_q <= 1'b1;
        aw_pending_q <= 1'b0;
      end else if (b_fire) begin
        bvalid_q <= 1'b0;
      end
    end
  end

  wire unused_inputs = |{
    araddr, arburst, arcache, arlen, arlock, arprot, arsize,
    awaddr, awburst, awcache, awlen, awlock, awprot, awsize,
    wdata, wlast, wstrb
  };

endmodule
