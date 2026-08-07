`timescale 1ns/1ps

module edge_soc_top #(
  parameter ADDR_WIDTH = 40,
  parameter DATA_WIDTH = 128,
  parameter ID_WIDTH = 8,
  parameter LEN_WIDTH = 8,
  parameter SOC_RAM_ADDR_BITS = 10,
  parameter ENABLE_IMEM = 1,
  parameter ENABLE_EARLY_LOAD_RETIRE = 0
) (
  input                         pll_core_cpuclk,
  input                         pad_cpu_rst_b,
  input  [ADDR_WIDTH-1:0]       core_boot_pc,
  input                         core_start,
  input                         core_force_stop,

  input  [ADDR_WIDTH-1:0]       edge_dtcm_base,
  input  [ADDR_WIDTH-1:0]       edge_dtcm_mask,
  input                         edge_dtcm_enable,
  input  [ADDR_WIDTH-1:0]       edge_dma_start_addr_src,
  input  [ADDR_WIDTH-1:0]       edge_dma_start_addr_dst,
  input  [31:0]                 edge_dma_start_len,
  input                         edge_dma_start_req,
  output                        edge_dma_busy,

  input  [ADDR_WIDTH-1:0]       bringup_core_araddr,
  input  [1:0]                  bringup_core_arburst,
  input  [3:0]                  bringup_core_arcache,
  input  [ID_WIDTH-1:0]         bringup_core_arid,
  input  [LEN_WIDTH-1:0]        bringup_core_arlen,
  input                         bringup_core_arlock,
  input  [2:0]                  bringup_core_arprot,
  input  [2:0]                  bringup_core_arsize,
  input                         bringup_core_arvalid,
  output                        bringup_core_arready,
  output [DATA_WIDTH-1:0]       bringup_core_rdata,
  output [ID_WIDTH-1:0]         bringup_core_rid,
  output                        bringup_core_rlast,
  input                         bringup_core_rready,
  output [1:0]                  bringup_core_rresp,
  output                        bringup_core_rvalid,

  input  [ADDR_WIDTH-1:0]       bringup_core_awaddr,
  input  [1:0]                  bringup_core_awburst,
  input  [3:0]                  bringup_core_awcache,
  input  [ID_WIDTH-1:0]         bringup_core_awid,
  input  [LEN_WIDTH-1:0]        bringup_core_awlen,
  input                         bringup_core_awlock,
  input  [2:0]                  bringup_core_awprot,
  input  [2:0]                  bringup_core_awsize,
  input                         bringup_core_awvalid,
  output                        bringup_core_awready,
  output [ID_WIDTH-1:0]         bringup_core_bid,
  input                         bringup_core_bready,
  output [1:0]                  bringup_core_bresp,
  output                        bringup_core_bvalid,
  input  [DATA_WIDTH-1:0]       bringup_core_wdata,
  input                         bringup_core_wlast,
  output                        bringup_core_wready,
  input  [(DATA_WIDTH/8)-1:0]   bringup_core_wstrb,
  input                         bringup_core_wvalid,

  input  [ADDR_WIDTH-1:0]       bringup_dma_araddr,
  input  [1:0]                  bringup_dma_arburst,
  input  [3:0]                  bringup_dma_arcache,
  input  [ID_WIDTH-1:0]         bringup_dma_arid,
  input  [LEN_WIDTH-1:0]        bringup_dma_arlen,
  input                         bringup_dma_arlock,
  input  [2:0]                  bringup_dma_arprot,
  input  [2:0]                  bringup_dma_arsize,
  input                         bringup_dma_arvalid,
  output                        bringup_dma_arready,
  output [DATA_WIDTH-1:0]       bringup_dma_rdata,
  output [ID_WIDTH-1:0]         bringup_dma_rid,
  output                        bringup_dma_rlast,
  input                         bringup_dma_rready,
  output [1:0]                  bringup_dma_rresp,
  output                        bringup_dma_rvalid,

  input  [ADDR_WIDTH-1:0]       bringup_dma_awaddr,
  input  [1:0]                  bringup_dma_awburst,
  input  [3:0]                  bringup_dma_awcache,
  input  [ID_WIDTH-1:0]         bringup_dma_awid,
  input  [LEN_WIDTH-1:0]        bringup_dma_awlen,
  input                         bringup_dma_awlock,
  input  [2:0]                  bringup_dma_awprot,
  input  [2:0]                  bringup_dma_awsize,
  input                         bringup_dma_awvalid,
  output                        bringup_dma_awready,
  output [ID_WIDTH-1:0]         bringup_dma_bid,
  input                         bringup_dma_bready,
  output [1:0]                  bringup_dma_bresp,
  output                        bringup_dma_bvalid,
  input  [DATA_WIDTH-1:0]       bringup_dma_wdata,
  input                         bringup_dma_wlast,
  output                        bringup_dma_wready,
  input  [(DATA_WIDTH/8)-1:0]   bringup_dma_wstrb,
  input                         bringup_dma_wvalid,

  output [ADDR_WIDTH-1:0]       biu_pad_araddr,
  output [1:0]                  biu_pad_arburst,
  output [3:0]                  biu_pad_arcache,
  output [ID_WIDTH-1:0]         biu_pad_arid,
  output [LEN_WIDTH-1:0]        biu_pad_arlen,
  output                        biu_pad_arlock,
  output [2:0]                  biu_pad_arprot,
  output [2:0]                  biu_pad_arsize,
  output                        biu_pad_arvalid,
  input                         pad_biu_arready,
  input  [DATA_WIDTH-1:0]       pad_biu_rdata,
  input  [ID_WIDTH-1:0]         pad_biu_rid,
  input                         pad_biu_rlast,
  input  [1:0]                  pad_biu_rresp,
  input                         pad_biu_rvalid,
  output                        biu_pad_rready,

  output [ADDR_WIDTH-1:0]       biu_pad_awaddr,
  output [1:0]                  biu_pad_awburst,
  output [3:0]                  biu_pad_awcache,
  output [ID_WIDTH-1:0]         biu_pad_awid,
  output [LEN_WIDTH-1:0]        biu_pad_awlen,
  output                        biu_pad_awlock,
  output [2:0]                  biu_pad_awprot,
  output [2:0]                  biu_pad_awsize,
  output                        biu_pad_awvalid,
  input                         pad_biu_awready,
  input  [ID_WIDTH-1:0]         pad_biu_bid,
  input  [1:0]                  pad_biu_bresp,
  input                         pad_biu_bvalid,
  output                        biu_pad_bready,
  output [DATA_WIDTH-1:0]       biu_pad_wdata,
  output                        biu_pad_wlast,
  output [(DATA_WIDTH/8)-1:0]   biu_pad_wstrb,
  output                        biu_pad_wvalid,
  input                         pad_biu_wready,

  output                        core0_pad_halted,
  output [1:0]                  core0_pad_lpmd_b,
  output                        core0_pad_retire,
  output [ADDR_WIDTH-1:0]       core0_pad_retire_pc,
  output                        core_ebreak_valid,
  output [7:0]                  core_ebreak_seq_id,
  output [3:0]                  core_ebreak_epoch,
  output                        core_csr_break_valid,
  output [63:0]                 core_csr_break_code,
  output [7:0]                  core_csr_break_seq_id,
  output [3:0]                  core_csr_break_epoch
  ,output                       core_csr_putchar_valid
  ,output [7:0]                 core_csr_putchar_char
`ifdef EDGE_DEBUG
  ,
  output                        debug_biu_read_owner_valid,
  output                        debug_biu_read_owner_dma,
  output                        debug_biu_write_owner_valid,
  output                        debug_biu_write_owner_dma
`endif
);

`ifdef EDGE_DEBUG
  wire core_retire0_valid;
  wire [7:0] core_retire0_seq_id;
  wire [3:0] core_retire0_epoch;
`endif
  wire core_halted;
  wire core_scalar_ebreak_valid;
  wire [7:0] core_scalar_ebreak_seq_id;
  wire [3:0] core_scalar_ebreak_epoch;
  wire core_scalar_csr_break_valid;
  wire [63:0] core_scalar_csr_break_code;
  wire [7:0] core_scalar_csr_break_seq_id;
  wire [3:0] core_scalar_csr_break_epoch;
  wire core_imem_req_valid;
  wire core_imem_req_ready;
  wire [ADDR_WIDTH-1:0] core_imem_req_addr;
  wire core_imem_resp_valid;
  wire core_imem_resp_ready;
  wire [DATA_WIDTH-1:0] core_imem_resp_bits;
  wire soc_pad_biu_arready;
  wire [DATA_WIDTH-1:0] soc_pad_biu_rdata;
  wire [ID_WIDTH-1:0] soc_pad_biu_rid;
  wire soc_pad_biu_rlast;
  wire [1:0] soc_pad_biu_rresp;
  wire soc_pad_biu_rvalid;
  wire soc_pad_biu_awready;
  wire [ID_WIDTH-1:0] soc_pad_biu_bid;
  wire [1:0] soc_pad_biu_bresp;
  wire soc_pad_biu_bvalid;
  wire soc_pad_biu_wready;

  wire [ADDR_WIDTH-1:0] ram_araddr;
  wire [1:0] ram_arburst;
  wire [3:0] ram_arcache;
  wire [ID_WIDTH-1:0] ram_arid;
  wire [LEN_WIDTH-1:0] ram_arlen;
  wire ram_arlock;
  wire [2:0] ram_arprot;
  wire [2:0] ram_arsize;
  wire ram_arvalid;
  wire ram_arready;
  wire [DATA_WIDTH-1:0] ram_rdata;
  wire [ID_WIDTH-1:0] ram_rid;
  wire ram_rlast;
  wire ram_rready;
  wire [1:0] ram_rresp;
  wire ram_rvalid;
  wire [ADDR_WIDTH-1:0] ram_awaddr;
  wire [1:0] ram_awburst;
  wire [3:0] ram_awcache;
  wire [ID_WIDTH-1:0] ram_awid;
  wire [LEN_WIDTH-1:0] ram_awlen;
  wire ram_awlock;
  wire [2:0] ram_awprot;
  wire [2:0] ram_awsize;
  wire ram_awvalid;
  wire ram_awready;
  wire [ID_WIDTH-1:0] ram_bid;
  wire ram_bready;
  wire [1:0] ram_bresp;
  wire ram_bvalid;
  wire [DATA_WIDTH-1:0] ram_wdata;
  wire ram_wlast;
  wire ram_wready;
  wire [(DATA_WIDTH/8)-1:0] ram_wstrb;
  wire ram_wvalid;

  wire [ADDR_WIDTH-1:0] err_araddr;
  wire [1:0] err_arburst;
  wire [3:0] err_arcache;
  wire [ID_WIDTH-1:0] err_arid;
  wire [LEN_WIDTH-1:0] err_arlen;
  wire err_arlock;
  wire [2:0] err_arprot;
  wire [2:0] err_arsize;
  wire err_arvalid;
  wire err_arready;
  wire [DATA_WIDTH-1:0] err_rdata;
  wire [ID_WIDTH-1:0] err_rid;
  wire err_rlast;
  wire err_rready;
  wire [1:0] err_rresp;
  wire err_rvalid;
  wire [ADDR_WIDTH-1:0] err_awaddr;
  wire [1:0] err_awburst;
  wire [3:0] err_awcache;
  wire [ID_WIDTH-1:0] err_awid;
  wire [LEN_WIDTH-1:0] err_awlen;
  wire err_awlock;
  wire [2:0] err_awprot;
  wire [2:0] err_awsize;
  wire err_awvalid;
  wire err_awready;
  wire [ID_WIDTH-1:0] err_bid;
  wire err_bready;
  wire [1:0] err_bresp;
  wire err_bvalid;
  wire [DATA_WIDTH-1:0] err_wdata;
  wire err_wlast;
  wire err_wready;
  wire [(DATA_WIDTH/8)-1:0] err_wstrb;
  wire err_wvalid;

  assign core0_pad_halted = core_halted;
  assign core0_pad_lpmd_b[1:0] = 2'b11;
`ifdef EDGE_DEBUG
  assign core0_pad_retire = core_retire0_valid;
`else
  assign core0_pad_retire = 1'b0;
`endif
  assign core0_pad_retire_pc[ADDR_WIDTH-1:0] = {ADDR_WIDTH{1'b0}};
  assign core_ebreak_valid = core_scalar_ebreak_valid;
  assign core_ebreak_seq_id[7:0] = core_scalar_ebreak_seq_id[7:0];
  assign core_ebreak_epoch[3:0] = core_scalar_ebreak_epoch[3:0];
  assign core_csr_break_valid = core_scalar_csr_break_valid;
  assign core_csr_break_code[63:0] = core_scalar_csr_break_code[63:0];
  assign core_csr_break_seq_id[7:0] = core_scalar_csr_break_seq_id[7:0];
  assign core_csr_break_epoch[3:0] = core_scalar_csr_break_epoch[3:0];

  edge_core_debug #(
    .PC_WIDTH(ADDR_WIDTH),
    .AXI_DATA_WIDTH(DATA_WIDTH),
    .AXI_ID_WIDTH(ID_WIDTH),
    .AXI_LEN_WIDTH(LEN_WIDTH),
    .ENABLE_ICACHE_REFILL(ENABLE_IMEM),
    .ENABLE_EARLY_LOAD_RETIRE(ENABLE_EARLY_LOAD_RETIRE)
  ) core_top (
    .forever_cpuclk(pll_core_cpuclk),
    .cpurst_b(pad_cpu_rst_b),
    .core_start(core_start),
    .core_force_stop(core_force_stop),
    .core_running(),
    .core_done_irq(),
    .core_done_code(),
    .boot_pc(core_boot_pc),
    .imem_req_valid(core_imem_req_valid),
    .imem_req_ready(ENABLE_IMEM ? core_imem_req_ready : 1'b0),
    .imem_req_addr(core_imem_req_addr),
    .imem_resp_valid(ENABLE_IMEM ? core_imem_resp_valid : 1'b0),
    .imem_resp_ready(core_imem_resp_ready),
    .imem_resp_bits(ENABLE_IMEM ? core_imem_resp_bits : {DATA_WIDTH{1'b0}}),
    .edge_dtcm_base(edge_dtcm_base),
    .edge_dtcm_mask(edge_dtcm_mask),
    .edge_dtcm_enable(edge_dtcm_enable),
    .edge_dma_start_addr_src(edge_dma_start_addr_src),
    .edge_dma_start_addr_dst(edge_dma_start_addr_dst),
    .edge_dma_start_len(edge_dma_start_len),
    .edge_dma_start_req(edge_dma_start_req),
    .edge_dma_busy(edge_dma_busy),
    .bringup_core_araddr(bringup_core_araddr),
    .bringup_core_arburst(bringup_core_arburst),
    .bringup_core_arcache(bringup_core_arcache),
    .bringup_core_arid(bringup_core_arid),
    .bringup_core_arlen(bringup_core_arlen),
    .bringup_core_arlock(bringup_core_arlock),
    .bringup_core_arprot(bringup_core_arprot),
    .bringup_core_arsize(bringup_core_arsize),
    .bringup_core_arvalid(bringup_core_arvalid),
    .bringup_core_arready(bringup_core_arready),
    .bringup_core_rdata(bringup_core_rdata),
    .bringup_core_rid(bringup_core_rid),
    .bringup_core_rlast(bringup_core_rlast),
    .bringup_core_rready(bringup_core_rready),
    .bringup_core_rresp(bringup_core_rresp),
    .bringup_core_rvalid(bringup_core_rvalid),
    .bringup_core_awaddr(bringup_core_awaddr),
    .bringup_core_awburst(bringup_core_awburst),
    .bringup_core_awcache(bringup_core_awcache),
    .bringup_core_awid(bringup_core_awid),
    .bringup_core_awlen(bringup_core_awlen),
    .bringup_core_awlock(bringup_core_awlock),
    .bringup_core_awprot(bringup_core_awprot),
    .bringup_core_awsize(bringup_core_awsize),
    .bringup_core_awvalid(bringup_core_awvalid),
    .bringup_core_awready(bringup_core_awready),
    .bringup_core_bid(bringup_core_bid),
    .bringup_core_bready(bringup_core_bready),
    .bringup_core_bresp(bringup_core_bresp),
    .bringup_core_bvalid(bringup_core_bvalid),
    .bringup_core_wdata(bringup_core_wdata),
    .bringup_core_wlast(bringup_core_wlast),
    .bringup_core_wready(bringup_core_wready),
    .bringup_core_wstrb(bringup_core_wstrb),
    .bringup_core_wvalid(bringup_core_wvalid),
    .bringup_dma_araddr(bringup_dma_araddr),
    .bringup_dma_arburst(bringup_dma_arburst),
    .bringup_dma_arcache(bringup_dma_arcache),
    .bringup_dma_arid(bringup_dma_arid),
    .bringup_dma_arlen(bringup_dma_arlen),
    .bringup_dma_arlock(bringup_dma_arlock),
    .bringup_dma_arprot(bringup_dma_arprot),
    .bringup_dma_arsize(bringup_dma_arsize),
    .bringup_dma_arvalid(bringup_dma_arvalid),
    .bringup_dma_arready(bringup_dma_arready),
    .bringup_dma_rdata(bringup_dma_rdata),
    .bringup_dma_rid(bringup_dma_rid),
    .bringup_dma_rlast(bringup_dma_rlast),
    .bringup_dma_rready(bringup_dma_rready),
    .bringup_dma_rresp(bringup_dma_rresp),
    .bringup_dma_rvalid(bringup_dma_rvalid),
    .bringup_dma_awaddr(bringup_dma_awaddr),
    .bringup_dma_awburst(bringup_dma_awburst),
    .bringup_dma_awcache(bringup_dma_awcache),
    .bringup_dma_awid(bringup_dma_awid),
    .bringup_dma_awlen(bringup_dma_awlen),
    .bringup_dma_awlock(bringup_dma_awlock),
    .bringup_dma_awprot(bringup_dma_awprot),
    .bringup_dma_awsize(bringup_dma_awsize),
    .bringup_dma_awvalid(bringup_dma_awvalid),
    .bringup_dma_awready(bringup_dma_awready),
    .bringup_dma_bid(bringup_dma_bid),
    .bringup_dma_bready(bringup_dma_bready),
    .bringup_dma_bresp(bringup_dma_bresp),
    .bringup_dma_bvalid(bringup_dma_bvalid),
    .bringup_dma_wdata(bringup_dma_wdata),
    .bringup_dma_wlast(bringup_dma_wlast),
    .bringup_dma_wready(bringup_dma_wready),
    .bringup_dma_wstrb(bringup_dma_wstrb),
    .bringup_dma_wvalid(bringup_dma_wvalid),
    .biu_pad_araddr(biu_pad_araddr),
    .biu_pad_arburst(biu_pad_arburst),
    .biu_pad_arcache(biu_pad_arcache),
    .biu_pad_arid(biu_pad_arid),
    .biu_pad_arlen(biu_pad_arlen),
    .biu_pad_arlock(biu_pad_arlock),
    .biu_pad_arprot(biu_pad_arprot),
    .biu_pad_arsize(biu_pad_arsize),
    .biu_pad_arvalid(biu_pad_arvalid),
    .pad_biu_arready(soc_pad_biu_arready),
    .pad_biu_rdata(soc_pad_biu_rdata),
    .pad_biu_rid(soc_pad_biu_rid),
    .pad_biu_rlast(soc_pad_biu_rlast),
    .pad_biu_rresp(soc_pad_biu_rresp),
    .pad_biu_rvalid(soc_pad_biu_rvalid),
    .biu_pad_rready(biu_pad_rready),
    .biu_pad_awaddr(biu_pad_awaddr),
    .biu_pad_awburst(biu_pad_awburst),
    .biu_pad_awcache(biu_pad_awcache),
    .biu_pad_awid(biu_pad_awid),
    .biu_pad_awlen(biu_pad_awlen),
    .biu_pad_awlock(biu_pad_awlock),
    .biu_pad_awprot(biu_pad_awprot),
    .biu_pad_awsize(biu_pad_awsize),
    .biu_pad_awvalid(biu_pad_awvalid),
    .pad_biu_awready(soc_pad_biu_awready),
    .pad_biu_bid(soc_pad_biu_bid),
    .pad_biu_bresp(soc_pad_biu_bresp),
    .pad_biu_bvalid(soc_pad_biu_bvalid),
    .biu_pad_bready(biu_pad_bready),
    .biu_pad_wdata(biu_pad_wdata),
    .biu_pad_wlast(biu_pad_wlast),
    .biu_pad_wstrb(biu_pad_wstrb),
    .biu_pad_wvalid(biu_pad_wvalid),
    .pad_biu_wready(soc_pad_biu_wready),
    .dcache_backend_load_pause(1'b0),
    .dcache_backend_store_pause(1'b0),
    .core_halted(core_halted),
    .scalar_ebreak_valid(core_scalar_ebreak_valid),
    .scalar_ebreak_seq_id(core_scalar_ebreak_seq_id),
    .scalar_ebreak_epoch(core_scalar_ebreak_epoch),
    .scalar_csr_break_valid(core_scalar_csr_break_valid),
    .scalar_csr_break_code(core_scalar_csr_break_code),
    .scalar_csr_break_seq_id(core_scalar_csr_break_seq_id),
    .scalar_csr_break_epoch(core_scalar_csr_break_epoch)
    ,.scalar_csr_putchar_valid(core_csr_putchar_valid)
    ,.scalar_csr_putchar_char(core_csr_putchar_char)
`ifdef EDGE_DEBUG
    ,
    .retire0_valid(core_retire0_valid),
    .retire0_seq_id(core_retire0_seq_id),
    .retire0_epoch(core_retire0_epoch),
    .retire0_kind(),
    .retire1_valid(),
    .retire1_seq_id(),
    .retire1_epoch(),
    .retire1_kind(),
    .scalar_fatal_valid(),
    .scalar_fatal_code(),
    .scalar_fatal_inst(),
    .scalar_fatal_seq_id(),
    .scalar_fatal_epoch(),
    .debug_gpr_busy(),
    .debug_fpr_busy(),
    .debug_retire_count(),
    .debug_icache_bytes(),
    .debug_dcache_bytes(),
    .debug_token0_valid(),
    .debug_token0_kind(),
    .debug_dcache_load_pending(),
    .debug_dcache_store_fire(),
    .debug_dcache_cache_op_fire(),
    .debug_dcache_cache_op_kind(),
    .debug_dcache_cache_op_is_va(),
    .debug_biu_read_owner_valid(debug_biu_read_owner_valid),
    .debug_biu_read_owner_dma(debug_biu_read_owner_dma),
    .debug_biu_write_owner_valid(debug_biu_write_owner_valid),
    .debug_biu_write_owner_dma(debug_biu_write_owner_dma)
`endif
  );

  edge_axi_interconnect #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .RAM_ADDR_MSB(31)
  ) soc_axi (
    .aclk(pll_core_cpuclk),
    .aresetn(pad_cpu_rst_b),
    .m_araddr(biu_pad_araddr),
    .m_arburst(biu_pad_arburst),
    .m_arcache(biu_pad_arcache),
    .m_arid(biu_pad_arid),
    .m_arlen(biu_pad_arlen),
    .m_arlock(biu_pad_arlock),
    .m_arprot(biu_pad_arprot),
    .m_arsize(biu_pad_arsize),
    .m_arvalid(biu_pad_arvalid),
    .m_arready(soc_pad_biu_arready),
    .m_rdata(soc_pad_biu_rdata),
    .m_rid(soc_pad_biu_rid),
    .m_rlast(soc_pad_biu_rlast),
    .m_rready(biu_pad_rready),
    .m_rresp(soc_pad_biu_rresp),
    .m_rvalid(soc_pad_biu_rvalid),
    .m_awaddr(biu_pad_awaddr),
    .m_awburst(biu_pad_awburst),
    .m_awcache(biu_pad_awcache),
    .m_awid(biu_pad_awid),
    .m_awlen(biu_pad_awlen),
    .m_awlock(biu_pad_awlock),
    .m_awprot(biu_pad_awprot),
    .m_awsize(biu_pad_awsize),
    .m_awvalid(biu_pad_awvalid),
    .m_awready(soc_pad_biu_awready),
    .m_bid(soc_pad_biu_bid),
    .m_bready(biu_pad_bready),
    .m_bresp(soc_pad_biu_bresp),
    .m_bvalid(soc_pad_biu_bvalid),
    .m_wdata(biu_pad_wdata),
    .m_wlast(biu_pad_wlast),
    .m_wready(soc_pad_biu_wready),
    .m_wstrb(biu_pad_wstrb),
    .m_wvalid(biu_pad_wvalid),
    .ram_araddr(ram_araddr),
    .ram_arburst(ram_arburst),
    .ram_arcache(ram_arcache),
    .ram_arid(ram_arid),
    .ram_arlen(ram_arlen),
    .ram_arlock(ram_arlock),
    .ram_arprot(ram_arprot),
    .ram_arsize(ram_arsize),
    .ram_arvalid(ram_arvalid),
    .ram_arready(ram_arready),
    .ram_rdata(ram_rdata),
    .ram_rid(ram_rid),
    .ram_rlast(ram_rlast),
    .ram_rready(ram_rready),
    .ram_rresp(ram_rresp),
    .ram_rvalid(ram_rvalid),
    .ram_awaddr(ram_awaddr),
    .ram_awburst(ram_awburst),
    .ram_awcache(ram_awcache),
    .ram_awid(ram_awid),
    .ram_awlen(ram_awlen),
    .ram_awlock(ram_awlock),
    .ram_awprot(ram_awprot),
    .ram_awsize(ram_awsize),
    .ram_awvalid(ram_awvalid),
    .ram_awready(ram_awready),
    .ram_bid(ram_bid),
    .ram_bready(ram_bready),
    .ram_bresp(ram_bresp),
    .ram_bvalid(ram_bvalid),
    .ram_wdata(ram_wdata),
    .ram_wlast(ram_wlast),
    .ram_wready(ram_wready),
    .ram_wstrb(ram_wstrb),
    .ram_wvalid(ram_wvalid),
    .err_araddr(err_araddr),
    .err_arburst(err_arburst),
    .err_arcache(err_arcache),
    .err_arid(err_arid),
    .err_arlen(err_arlen),
    .err_arlock(err_arlock),
    .err_arprot(err_arprot),
    .err_arsize(err_arsize),
    .err_arvalid(err_arvalid),
    .err_arready(err_arready),
    .err_rdata(err_rdata),
    .err_rid(err_rid),
    .err_rlast(err_rlast),
    .err_rready(err_rready),
    .err_rresp(err_rresp),
    .err_rvalid(err_rvalid),
    .err_awaddr(err_awaddr),
    .err_awburst(err_awburst),
    .err_awcache(err_awcache),
    .err_awid(err_awid),
    .err_awlen(err_awlen),
    .err_awlock(err_awlock),
    .err_awprot(err_awprot),
    .err_awsize(err_awsize),
    .err_awvalid(err_awvalid),
    .err_awready(err_awready),
    .err_bid(err_bid),
    .err_bready(err_bready),
    .err_bresp(err_bresp),
    .err_bvalid(err_bvalid),
    .err_wdata(err_wdata),
    .err_wlast(err_wlast),
    .err_wready(err_wready),
    .err_wstrb(err_wstrb),
    .err_wvalid(err_wvalid)
  );

  edge_axi_ram #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .RAM_ADDR_BITS(SOC_RAM_ADDR_BITS)
  ) soc_ram (
    .aclk(pll_core_cpuclk),
    .aresetn(pad_cpu_rst_b),
    .araddr(ram_araddr),
    .arburst(ram_arburst),
    .arcache(ram_arcache),
    .arid(ram_arid),
    .arlen(ram_arlen),
    .arlock(ram_arlock),
    .arprot(ram_arprot),
    .arsize(ram_arsize),
    .arvalid(ram_arvalid),
    .arready(ram_arready),
    .rdata(ram_rdata),
    .rid(ram_rid),
    .rlast(ram_rlast),
    .rready(ram_rready),
    .rresp(ram_rresp),
    .rvalid(ram_rvalid),
    .imem_req_valid(ENABLE_IMEM ? core_imem_req_valid : 1'b0),
    .imem_req_ready(core_imem_req_ready),
    .imem_req_addr(ENABLE_IMEM ? core_imem_req_addr : {ADDR_WIDTH{1'b0}}),
    .imem_resp_valid(core_imem_resp_valid),
    .imem_resp_ready(ENABLE_IMEM ? core_imem_resp_ready : 1'b0),
    .imem_resp_bits(core_imem_resp_bits),
    .awaddr(ram_awaddr),
    .awburst(ram_awburst),
    .awcache(ram_awcache),
    .awid(ram_awid),
    .awlen(ram_awlen),
    .awlock(ram_awlock),
    .awprot(ram_awprot),
    .awsize(ram_awsize),
    .awvalid(ram_awvalid),
    .awready(ram_awready),
    .bid(ram_bid),
    .bready(ram_bready),
    .bresp(ram_bresp),
    .bvalid(ram_bvalid),
    .wdata(ram_wdata),
    .wlast(ram_wlast),
    .wready(ram_wready),
    .wstrb(ram_wstrb),
    .wvalid(ram_wvalid)
  );

  edge_axi_err #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .LEN_WIDTH(LEN_WIDTH)
  ) soc_err (
    .aclk(pll_core_cpuclk),
    .aresetn(pad_cpu_rst_b),
    .araddr(err_araddr),
    .arburst(err_arburst),
    .arcache(err_arcache),
    .arid(err_arid),
    .arlen(err_arlen),
    .arlock(err_arlock),
    .arprot(err_arprot),
    .arsize(err_arsize),
    .arvalid(err_arvalid),
    .arready(err_arready),
    .rdata(err_rdata),
    .rid(err_rid),
    .rlast(err_rlast),
    .rready(err_rready),
    .rresp(err_rresp),
    .rvalid(err_rvalid),
    .awaddr(err_awaddr),
    .awburst(err_awburst),
    .awcache(err_awcache),
    .awid(err_awid),
    .awlen(err_awlen),
    .awlock(err_awlock),
    .awprot(err_awprot),
    .awsize(err_awsize),
    .awvalid(err_awvalid),
    .awready(err_awready),
    .bid(err_bid),
    .bready(err_bready),
    .bresp(err_bresp),
    .bvalid(err_bvalid),
    .wdata(err_wdata),
    .wlast(err_wlast),
    .wready(err_wready),
    .wstrb(err_wstrb),
    .wvalid(err_wvalid)
  );

  wire unused_external_pad_inputs = |{
    pad_biu_arready, pad_biu_rdata, pad_biu_rid, pad_biu_rlast,
    pad_biu_rresp, pad_biu_rvalid, pad_biu_awready, pad_biu_bid,
    pad_biu_bresp, pad_biu_bvalid, pad_biu_wready
  };

endmodule
