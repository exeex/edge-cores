`timescale 1ns/1ps

module edge_axi_interconnect #(
  parameter ADDR_WIDTH = 40,
  parameter DATA_WIDTH = 128,
  parameter ID_WIDTH = 8,
  parameter LEN_WIDTH = 8,
  parameter RAM_ADDR_MSB = 31
) (
  input                         aclk,
  input                         aresetn,

  input  [ADDR_WIDTH-1:0]       m_araddr,
  input  [1:0]                  m_arburst,
  input  [3:0]                  m_arcache,
  input  [ID_WIDTH-1:0]         m_arid,
  input  [LEN_WIDTH-1:0]        m_arlen,
  input                         m_arlock,
  input  [2:0]                  m_arprot,
  input  [2:0]                  m_arsize,
  input                         m_arvalid,
  output                        m_arready,
  output [DATA_WIDTH-1:0]       m_rdata,
  output [ID_WIDTH-1:0]         m_rid,
  output                        m_rlast,
  input                         m_rready,
  output [1:0]                  m_rresp,
  output                        m_rvalid,

  input  [ADDR_WIDTH-1:0]       m_awaddr,
  input  [1:0]                  m_awburst,
  input  [3:0]                  m_awcache,
  input  [ID_WIDTH-1:0]         m_awid,
  input  [LEN_WIDTH-1:0]        m_awlen,
  input                         m_awlock,
  input  [2:0]                  m_awprot,
  input  [2:0]                  m_awsize,
  input                         m_awvalid,
  output                        m_awready,
  output [ID_WIDTH-1:0]         m_bid,
  input                         m_bready,
  output [1:0]                  m_bresp,
  output                        m_bvalid,
  input  [DATA_WIDTH-1:0]       m_wdata,
  input                         m_wlast,
  output                        m_wready,
  input  [(DATA_WIDTH/8)-1:0]   m_wstrb,
  input                         m_wvalid,

  output [ADDR_WIDTH-1:0]       ram_araddr,
  output [1:0]                  ram_arburst,
  output [3:0]                  ram_arcache,
  output [ID_WIDTH-1:0]         ram_arid,
  output [LEN_WIDTH-1:0]        ram_arlen,
  output                        ram_arlock,
  output [2:0]                  ram_arprot,
  output [2:0]                  ram_arsize,
  output                        ram_arvalid,
  input                         ram_arready,
  input  [DATA_WIDTH-1:0]       ram_rdata,
  input  [ID_WIDTH-1:0]         ram_rid,
  input                         ram_rlast,
  output                        ram_rready,
  input  [1:0]                  ram_rresp,
  input                         ram_rvalid,

  output [ADDR_WIDTH-1:0]       ram_awaddr,
  output [1:0]                  ram_awburst,
  output [3:0]                  ram_awcache,
  output [ID_WIDTH-1:0]         ram_awid,
  output [LEN_WIDTH-1:0]        ram_awlen,
  output                        ram_awlock,
  output [2:0]                  ram_awprot,
  output [2:0]                  ram_awsize,
  output                        ram_awvalid,
  input                         ram_awready,
  input  [ID_WIDTH-1:0]         ram_bid,
  output                        ram_bready,
  input  [1:0]                  ram_bresp,
  input                         ram_bvalid,
  output [DATA_WIDTH-1:0]       ram_wdata,
  output                        ram_wlast,
  input                         ram_wready,
  output [(DATA_WIDTH/8)-1:0]   ram_wstrb,
  output                        ram_wvalid,

  output [ADDR_WIDTH-1:0]       err_araddr,
  output [1:0]                  err_arburst,
  output [3:0]                  err_arcache,
  output [ID_WIDTH-1:0]         err_arid,
  output [LEN_WIDTH-1:0]        err_arlen,
  output                        err_arlock,
  output [2:0]                  err_arprot,
  output [2:0]                  err_arsize,
  output                        err_arvalid,
  input                         err_arready,
  input  [DATA_WIDTH-1:0]       err_rdata,
  input  [ID_WIDTH-1:0]         err_rid,
  input                         err_rlast,
  output                        err_rready,
  input  [1:0]                  err_rresp,
  input                         err_rvalid,

  output [ADDR_WIDTH-1:0]       err_awaddr,
  output [1:0]                  err_awburst,
  output [3:0]                  err_awcache,
  output [ID_WIDTH-1:0]         err_awid,
  output [LEN_WIDTH-1:0]        err_awlen,
  output                        err_awlock,
  output [2:0]                  err_awprot,
  output [2:0]                  err_awsize,
  output                        err_awvalid,
  input                         err_awready,
  input  [ID_WIDTH-1:0]         err_bid,
  output                        err_bready,
  input  [1:0]                  err_bresp,
  input                         err_bvalid,
  output [DATA_WIDTH-1:0]       err_wdata,
  output                        err_wlast,
  input                         err_wready,
  output [(DATA_WIDTH/8)-1:0]   err_wstrb,
  output                        err_wvalid
);

  reg read_pending_q;
  reg read_err_q;
  reg write_pending_q;
  reg write_err_q;

  wire ar_to_err;
  wire aw_to_err;
  wire ar_fire;
  wire aw_fire;
  wire r_fire;
  wire b_fire;

  assign ar_to_err = |m_araddr[ADDR_WIDTH-1:RAM_ADDR_MSB+1];
  assign aw_to_err = |m_awaddr[ADDR_WIDTH-1:RAM_ADDR_MSB+1];

  assign ram_araddr = m_araddr;
  assign ram_arburst = m_arburst;
  assign ram_arcache = m_arcache;
  assign ram_arid = m_arid;
  assign ram_arlen = m_arlen;
  assign ram_arlock = m_arlock;
  assign ram_arprot = m_arprot;
  assign ram_arsize = m_arsize;
  assign ram_arvalid = m_arvalid && !read_pending_q && !ar_to_err;

  assign err_araddr = m_araddr;
  assign err_arburst = m_arburst;
  assign err_arcache = m_arcache;
  assign err_arid = m_arid;
  assign err_arlen = m_arlen;
  assign err_arlock = m_arlock;
  assign err_arprot = m_arprot;
  assign err_arsize = m_arsize;
  assign err_arvalid = m_arvalid && !read_pending_q && ar_to_err;

  assign m_arready = !read_pending_q && (ar_to_err ? err_arready : ram_arready);
  assign ar_fire = m_arvalid && m_arready;

  assign m_rdata = read_err_q ? err_rdata : ram_rdata;
  assign m_rid = read_err_q ? err_rid : ram_rid;
  assign m_rlast = read_err_q ? err_rlast : ram_rlast;
  assign m_rresp = read_err_q ? err_rresp : ram_rresp;
  assign m_rvalid = read_pending_q && (read_err_q ? err_rvalid : ram_rvalid);
  assign ram_rready = read_pending_q && !read_err_q && m_rready;
  assign err_rready = read_pending_q && read_err_q && m_rready;
  assign r_fire = m_rvalid && m_rready && m_rlast;

  assign ram_awaddr = m_awaddr;
  assign ram_awburst = m_awburst;
  assign ram_awcache = m_awcache;
  assign ram_awid = m_awid;
  assign ram_awlen = m_awlen;
  assign ram_awlock = m_awlock;
  assign ram_awprot = m_awprot;
  assign ram_awsize = m_awsize;
  assign ram_awvalid = m_awvalid && !write_pending_q && !aw_to_err;

  assign err_awaddr = m_awaddr;
  assign err_awburst = m_awburst;
  assign err_awcache = m_awcache;
  assign err_awid = m_awid;
  assign err_awlen = m_awlen;
  assign err_awlock = m_awlock;
  assign err_awprot = m_awprot;
  assign err_awsize = m_awsize;
  assign err_awvalid = m_awvalid && !write_pending_q && aw_to_err;

  assign m_awready = !write_pending_q && (aw_to_err ? err_awready : ram_awready);
  assign aw_fire = m_awvalid && m_awready;

  assign ram_wdata = m_wdata;
  assign ram_wlast = m_wlast;
  assign ram_wstrb = m_wstrb;
  assign ram_wvalid = write_pending_q && !write_err_q && m_wvalid;
  assign err_wdata = m_wdata;
  assign err_wlast = m_wlast;
  assign err_wstrb = m_wstrb;
  assign err_wvalid = write_pending_q && write_err_q && m_wvalid;
  assign m_wready = write_pending_q && (write_err_q ? err_wready : ram_wready);

  assign m_bid = write_err_q ? err_bid : ram_bid;
  assign m_bresp = write_err_q ? err_bresp : ram_bresp;
  assign m_bvalid = write_pending_q && (write_err_q ? err_bvalid : ram_bvalid);
  assign ram_bready = write_pending_q && !write_err_q && m_bready;
  assign err_bready = write_pending_q && write_err_q && m_bready;
  assign b_fire = m_bvalid && m_bready;

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      read_pending_q <= 1'b0;
      read_err_q <= 1'b0;
    end else if (ar_fire) begin
      read_pending_q <= 1'b1;
      read_err_q <= ar_to_err;
    end else if (r_fire) begin
      read_pending_q <= 1'b0;
      read_err_q <= 1'b0;
    end
  end

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      write_pending_q <= 1'b0;
      write_err_q <= 1'b0;
    end else if (aw_fire) begin
      write_pending_q <= 1'b1;
      write_err_q <= aw_to_err;
    end else if (b_fire) begin
      write_pending_q <= 1'b0;
      write_err_q <= 1'b0;
    end
  end

endmodule
