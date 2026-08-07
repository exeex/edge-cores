`timescale 1ns/1ps

`ifdef EDGE_YOSYS_SYNTH
(* blackbox *)
module edge_axi_ram #(
  parameter ADDR_WIDTH = 40,
  parameter DATA_WIDTH = 128,
  parameter ID_WIDTH = 8,
  parameter LEN_WIDTH = 8,
  parameter RAM_ADDR_BITS = 10
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

  input                         imem_req_valid,
  output                        imem_req_ready,
  input  [ADDR_WIDTH-1:0]       imem_req_addr,
  output                        imem_resp_valid,
  input                         imem_resp_ready,
  output [DATA_WIDTH-1:0]       imem_resp_bits,

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
endmodule
`else
module edge_axi_ram #(
  parameter ADDR_WIDTH = 40,
  parameter DATA_WIDTH = 128,
  parameter ID_WIDTH = 8,
  parameter LEN_WIDTH = 8,
  parameter RAM_ADDR_BITS = 10
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

  input                         imem_req_valid,
  output                        imem_req_ready,
  input  [ADDR_WIDTH-1:0]       imem_req_addr,
  output                        imem_resp_valid,
  input                         imem_resp_ready,
  output [DATA_WIDTH-1:0]       imem_resp_bits,

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

  localparam STRB_WIDTH = DATA_WIDTH / 8;
  localparam ADDR_LSB = 4;
  localparam RAM_DEPTH = 1 << RAM_ADDR_BITS;
  localparam [ADDR_WIDTH-1:0] ADDR_INCR = STRB_WIDTH;

  reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];
  reg [DATA_WIDTH-1:0] rdata_q;
  reg [ADDR_WIDTH-1:0] raddr_q;
  reg [LEN_WIDTH-1:0]  rbeats_left_q;
  reg [ID_WIDTH-1:0]   rid_q;
  reg                  rlast_q;
  reg                  rvalid_q;
  reg [31:0]           read_delay_q;
  reg [DATA_WIDTH-1:0] imem_resp_bits_q;
  reg                  imem_resp_valid_q;

  reg [ADDR_WIDTH-1:0] awaddr_q;
  reg [LEN_WIDTH-1:0]  awbeats_left_q;
  reg [ID_WIDTH-1:0]   awid_q;
  reg                  aw_pending_q;
  reg [ID_WIDTH-1:0]   bid_q;
  reg                  bvalid_q;

  wire [RAM_ADDR_BITS-1:0] ar_index;
  wire [RAM_ADDR_BITS-1:0] raddr_index;
  wire [RAM_ADDR_BITS-1:0] aw_index;
  wire ar_fire;
  wire aw_fire;
  wire w_fire;
  wire b_fire;
  wire imem_fire;
  wire [RAM_ADDR_BITS-1:0] imem_index;

  integer byte_idx;
  integer init_idx;
  integer mem128_words;
  integer axi_read_latency;
  reg [4095:0] mem128_path;

  initial begin
    for (init_idx = 0; init_idx < RAM_DEPTH; init_idx = init_idx + 1) begin
      mem[init_idx] = {
        32'h4544_4745,
        init_idx[31:0],
        init_idx[31:0] ^ 32'h5a5a_5a5a,
        32'h534f_4352
      };
    end
    mem128_words = RAM_DEPTH;
    axi_read_latency = 0;
    if ($value$plusargs("axi_read_latency=%d", axi_read_latency)) begin
      if (axi_read_latency < 0)
        axi_read_latency = 0;
    end
    if ($value$plusargs("mem128=%s", mem128_path)) begin
      if ($value$plusargs("mem128_words=%d", mem128_words)) begin
        if (mem128_words <= 0 || mem128_words > RAM_DEPTH)
          mem128_words = RAM_DEPTH;
      end
      $readmemh(mem128_path, mem, 0, mem128_words - 1);
    end
  end

  assign ar_index[RAM_ADDR_BITS-1:0] = araddr[ADDR_LSB +: RAM_ADDR_BITS];
  assign raddr_index[RAM_ADDR_BITS-1:0] = raddr_q[ADDR_LSB +: RAM_ADDR_BITS];
  assign aw_index[RAM_ADDR_BITS-1:0] = awaddr_q[ADDR_LSB +: RAM_ADDR_BITS];
  assign imem_index[RAM_ADDR_BITS-1:0] = imem_req_addr[ADDR_LSB +: RAM_ADDR_BITS];

  assign arready = !rvalid_q && (read_delay_q == 32'd0) &&
                   (rbeats_left_q == {LEN_WIDTH{1'b0}});
  assign ar_fire = arvalid && arready;
  assign rdata[DATA_WIDTH-1:0] = rdata_q[DATA_WIDTH-1:0];
  assign rid[ID_WIDTH-1:0] = rid_q[ID_WIDTH-1:0];
  assign rlast = rlast_q;
  assign rresp[1:0] = 2'b00;
  assign rvalid = rvalid_q;
  assign imem_req_ready = !imem_resp_valid_q || imem_resp_ready;
  assign imem_fire = imem_req_valid && imem_req_ready;
  assign imem_resp_valid = imem_resp_valid_q;
  assign imem_resp_bits[DATA_WIDTH-1:0] = imem_resp_bits_q[DATA_WIDTH-1:0];

  assign awready = !aw_pending_q && !bvalid_q;
  assign aw_fire = awvalid && awready;
  assign wready = aw_pending_q && !bvalid_q;
  assign w_fire = wvalid && wready;
  assign bid[ID_WIDTH-1:0] = bid_q[ID_WIDTH-1:0];
  assign bresp[1:0] = 2'b00;
  assign bvalid = bvalid_q;
  assign b_fire = bvalid_q && bready;

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      rvalid_q <= 1'b0;
      rid_q <= {ID_WIDTH{1'b0}};
      rdata_q <= {DATA_WIDTH{1'b0}};
      raddr_q <= {ADDR_WIDTH{1'b0}};
      rbeats_left_q <= {LEN_WIDTH{1'b0}};
      rlast_q <= 1'b0;
      read_delay_q <= 32'd0;
      imem_resp_valid_q <= 1'b0;
      imem_resp_bits_q <= {DATA_WIDTH{1'b0}};
    end else begin
      if (ar_fire) begin
        rid_q <= arid[ID_WIDTH-1:0];
        rdata_q <= mem[ar_index];
        raddr_q <= araddr[ADDR_WIDTH-1:0] + ADDR_INCR;
        rbeats_left_q <= arlen[LEN_WIDTH-1:0];
        rlast_q <= arlen[LEN_WIDTH-1:0] == {LEN_WIDTH{1'b0}};
        if (axi_read_latency == 0) begin
          rvalid_q <= 1'b1;
          read_delay_q <= 32'd0;
        end else begin
          rvalid_q <= 1'b0;
          read_delay_q <= axi_read_latency[31:0];
        end
      end else if (!rvalid_q && (read_delay_q != 32'd0)) begin
        read_delay_q <= read_delay_q - 32'd1;
        if (read_delay_q == 32'd1)
          rvalid_q <= 1'b1;
      end else if (rvalid_q && rready) begin
        if (rbeats_left_q != {LEN_WIDTH{1'b0}}) begin
          rdata_q <= mem[raddr_index];
          raddr_q <= raddr_q + ADDR_INCR;
          rbeats_left_q <= rbeats_left_q - {{LEN_WIDTH-1{1'b0}}, 1'b1};
          rlast_q <= rbeats_left_q == {{LEN_WIDTH-1{1'b0}}, 1'b1};
        end else begin
          rvalid_q <= 1'b0;
          rlast_q <= 1'b0;
        end
      end

      if (imem_fire) begin
        imem_resp_bits_q <= mem[imem_index];
        imem_resp_valid_q <= 1'b1;
      end else if (imem_resp_valid_q && imem_resp_ready) begin
        imem_resp_valid_q <= 1'b0;
      end
    end
  end

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      aw_pending_q <= 1'b0;
      awaddr_q <= {ADDR_WIDTH{1'b0}};
      awbeats_left_q <= {LEN_WIDTH{1'b0}};
      awid_q <= {ID_WIDTH{1'b0}};
      bid_q <= {ID_WIDTH{1'b0}};
      bvalid_q <= 1'b0;
    end else begin
      if (aw_fire) begin
        aw_pending_q <= 1'b1;
        awaddr_q <= awaddr[ADDR_WIDTH-1:0];
        awbeats_left_q <= awlen[LEN_WIDTH-1:0];
        awid_q <= awid[ID_WIDTH-1:0];
      end

      if (w_fire) begin
        for (byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx = byte_idx + 1) begin
          if (wstrb[byte_idx])
            mem[aw_index][byte_idx*8 +: 8] <= wdata[byte_idx*8 +: 8];
        end
        if (wlast || awbeats_left_q == {LEN_WIDTH{1'b0}}) begin
          bid_q <= awid_q;
          bvalid_q <= 1'b1;
          aw_pending_q <= 1'b0;
          awbeats_left_q <= {LEN_WIDTH{1'b0}};
        end else begin
          awaddr_q <= awaddr_q + ADDR_INCR;
          awbeats_left_q <=
              awbeats_left_q - {{LEN_WIDTH-1{1'b0}}, 1'b1};
        end
      end else if (b_fire) begin
        bvalid_q <= 1'b0;
      end
    end
  end

  wire unused_inputs = |{
    arburst, arcache, arlock, arprot, arsize,
    awburst, awcache, awlock, awprot, awsize
  };

endmodule
`endif
