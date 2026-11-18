// Public RTL simulation composition. FPU and accelerator interfaces are disabled.
module jtag_tb(input wire clk,reset_n,srst_n,tck,trst_n,tms,tdi,output wire tdo);
 localparam PC_WIDTH=32, AXI_ADDR_WIDTH=64, AXI_DATA_WIDTH=128,
            AXI_ID_WIDTH=8, AXI_LEN_WIDTH=8, DTCM_ADDR_WIDTH=14;
wire  debug_req_valid;
wire  debug_req_write;
wire [2:0] debug_req_id;
wire [63:0] debug_req_data;
wire  debug_req_ready;
wire  debug_resp_valid;
wire  debug_resp_error;
wire [63:0] debug_resp_data;
wire  debug_resp_ready;
wire  debug_interrupt;
wire  forever_cpuclk;
wire  cpurst_b;
wire  core_start=0;
wire  core_force_stop=0;
wire [PC_WIDTH-1:0] boot_pc=0;
wire [AXI_ADDR_WIDTH-1:0] biu_pad_araddr;
wire [1:0] biu_pad_arburst;
wire [3:0] biu_pad_arcache;
wire [AXI_ID_WIDTH-1:0] biu_pad_arid;
wire [AXI_LEN_WIDTH-1:0] biu_pad_arlen;
wire  biu_pad_arlock;
wire [2:0] biu_pad_arprot;
wire [2:0] biu_pad_arsize;
wire  biu_pad_arvalid;
wire  pad_biu_arready;
wire [AXI_DATA_WIDTH-1:0] pad_biu_rdata;
wire [AXI_ID_WIDTH-1:0] pad_biu_rid;
wire  pad_biu_rlast;
wire [1:0] pad_biu_rresp;
wire  pad_biu_rvalid;
wire  biu_pad_rready;
wire [AXI_ADDR_WIDTH-1:0] biu_pad_awaddr;
wire [1:0] biu_pad_awburst;
wire [3:0] biu_pad_awcache;
wire [AXI_ID_WIDTH-1:0] biu_pad_awid;
wire [AXI_LEN_WIDTH-1:0] biu_pad_awlen;
wire  biu_pad_awlock;
wire [2:0] biu_pad_awprot;
wire [2:0] biu_pad_awsize;
wire  biu_pad_awvalid;
wire  pad_biu_awready;
wire [AXI_ID_WIDTH-1:0] pad_biu_bid;
wire [1:0] pad_biu_bresp;
wire  pad_biu_bvalid;
wire  biu_pad_bready;
wire [AXI_DATA_WIDTH-1:0] biu_pad_wdata;
wire  biu_pad_wlast;
wire [(AXI_DATA_WIDTH/8)-1:0] biu_pad_wstrb;
wire  biu_pad_wvalid;
wire  pad_biu_wready;
wire [63:0] dtcm_base=0;
wire [63:0] dtcm_mask=0;
wire  dtcm_enable=0;
wire  dtcm_lsu_req;
wire  dtcm_lsu_ready=0;
wire  dtcm_lsu_we;
wire [DTCM_ADDR_WIDTH-1:0] dtcm_lsu_addr;
wire [63:0] dtcm_lsu_wdata;
wire [7:0] dtcm_lsu_wstrb;
wire  dtcm_lsu_rvalid=0;
wire [63:0] dtcm_lsu_rdata=0;
wire  accel_req_valid;
wire  accel_req_ready=0;
wire [31:0] accel_req_inst;
wire [63:0] accel_req_src0;
wire [63:0] accel_req_src1;
wire  accel_resp_valid=0;
wire  accel_resp_error=0;
wire [63:0] accel_resp_value=0;
wire  halted;
wire  illegal;
wire [63:0] debug_x31;
wire [63:0] cycle_count;
wire [63:0] instret_count;
wire  putchar_valid;
wire [7:0] putchar_char;
 wire ndmreset;
 wire reset_request_n = reset_n && srst_n && !ndmreset;
 edge32_core_reset_bridge reset_bridge(.clk(clk),.reset_n(reset_request_n),.core_reset_n(cpurst_b));
 assign forever_cpuclk=clk;
 wire mem_req_valid,mem_req_write,mem_req_ready,mem_resp_valid,mem_resp_ready;
 wire[31:0] mem_req_addr,mem_req_wdata,mem_resp_rdata;
 wire[1:0] mem_req_size;
 wire[2:0] mem_resp_error;
 // MISA advertises RV32IM, without FPU registers or instructions.
 edge32_jtag_debug #(.MISA(32'h40001100)) transport(
 .clk(clk),.reset_n(reset_n),.core_reset_n(cpurst_b),
 .tck(tck),.trst_n(trst_n),.tms(tms),.tdi(tdi),.tdo(tdo),.ndmreset(ndmreset),
 .putchar_valid(putchar_valid),.putchar_char(putchar_char),
 .mem_req_valid(mem_req_valid),.mem_req_write(mem_req_write),.mem_req_addr(mem_req_addr),.mem_req_wdata(mem_req_wdata),
 .mem_req_size(mem_req_size),.mem_req_ready(mem_req_ready),.mem_resp_valid(mem_resp_valid),.mem_resp_ready(mem_resp_ready),
 .mem_resp_rdata(mem_resp_rdata),.mem_resp_error(mem_resp_error),
 .req_valid(debug_req_valid),.req_ready(debug_req_ready),.req_write(debug_req_write),.req_id(debug_req_id),.req_data(debug_req_data),
 .resp_valid(debug_resp_valid),.resp_ready(debug_resp_ready),.resp_error(debug_resp_error),.resp_data(debug_resp_data));
 edge32_axi_core #(.ENABLE_FPU(0)) dut(
 .debug_req_valid(debug_req_valid),
 .debug_req_write(debug_req_write),
 .debug_req_id(debug_req_id),
 .debug_req_data(debug_req_data),
 .debug_req_ready(debug_req_ready),
 .debug_resp_valid(debug_resp_valid),
 .debug_resp_error(debug_resp_error),
 .debug_resp_data(debug_resp_data),
 .debug_resp_ready(debug_resp_ready),
 .debug_interrupt(debug_interrupt),
 .forever_cpuclk(forever_cpuclk),
 .cpurst_b(cpurst_b),
 .core_start(core_start),
 .core_force_stop(core_force_stop),
 .boot_pc(boot_pc),
 .biu_pad_araddr(biu_pad_araddr),
 .biu_pad_arburst(biu_pad_arburst),
 .biu_pad_arcache(biu_pad_arcache),
 .biu_pad_arid(biu_pad_arid),
 .biu_pad_arlen(biu_pad_arlen),
 .biu_pad_arlock(biu_pad_arlock),
 .biu_pad_arprot(biu_pad_arprot),
 .biu_pad_arsize(biu_pad_arsize),
 .biu_pad_arvalid(biu_pad_arvalid),
 .pad_biu_arready(pad_biu_arready),
 .pad_biu_rdata(pad_biu_rdata),
 .pad_biu_rid(pad_biu_rid),
 .pad_biu_rlast(pad_biu_rlast),
 .pad_biu_rresp(pad_biu_rresp),
 .pad_biu_rvalid(pad_biu_rvalid),
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
 .pad_biu_awready(pad_biu_awready),
 .pad_biu_bid(pad_biu_bid),
 .pad_biu_bresp(pad_biu_bresp),
 .pad_biu_bvalid(pad_biu_bvalid),
 .biu_pad_bready(biu_pad_bready),
 .biu_pad_wdata(biu_pad_wdata),
 .biu_pad_wlast(biu_pad_wlast),
 .biu_pad_wstrb(biu_pad_wstrb),
 .biu_pad_wvalid(biu_pad_wvalid),
 .pad_biu_wready(pad_biu_wready),
 .dtcm_base(dtcm_base),
 .dtcm_mask(dtcm_mask),
 .dtcm_enable(dtcm_enable),
 .dtcm_lsu_req(dtcm_lsu_req),
 .dtcm_lsu_ready(dtcm_lsu_ready),
 .dtcm_lsu_we(dtcm_lsu_we),
 .dtcm_lsu_addr(dtcm_lsu_addr),
 .dtcm_lsu_wdata(dtcm_lsu_wdata),
 .dtcm_lsu_wstrb(dtcm_lsu_wstrb),
 .dtcm_lsu_rvalid(dtcm_lsu_rvalid),
 .dtcm_lsu_rdata(dtcm_lsu_rdata),
 .accel_req_valid(accel_req_valid),
 .accel_req_ready(accel_req_ready),
 .accel_req_inst(accel_req_inst),
 .accel_req_src0(accel_req_src0),
 .accel_req_src1(accel_req_src1),
 .accel_resp_valid(accel_resp_valid),
 .accel_resp_error(accel_resp_error),
 .accel_resp_value(accel_resp_value),
 .halted(halted),
 .illegal(illegal),
 .debug_x31(debug_x31),
 .cycle_count(cycle_count),
 .instret_count(instret_count),
 .putchar_valid(putchar_valid),
 .putchar_char(putchar_char));
 jtag_ram memory(.clk(clk),.reset_n(reset_n),.cpu_reset_n(reset_request_n),
 .mem_req_valid(mem_req_valid),.mem_req_write(mem_req_write),.mem_req_addr(mem_req_addr),.mem_req_wdata(mem_req_wdata),
 .mem_req_size(mem_req_size),.mem_req_ready(mem_req_ready),.mem_resp_valid(mem_resp_valid),.mem_resp_ready(mem_resp_ready),
 .mem_resp_rdata(mem_resp_rdata),.mem_resp_error(mem_resp_error),
 .araddr(biu_pad_araddr),.arlen(biu_pad_arlen),.arid(biu_pad_arid),.arsize(biu_pad_arsize),.arvalid(biu_pad_arvalid),.arready(pad_biu_arready),
 .rdata(pad_biu_rdata),.rid(pad_biu_rid),.rlast(pad_biu_rlast),.rresp(pad_biu_rresp),.rvalid(pad_biu_rvalid),.rready(biu_pad_rready),
 .awaddr(biu_pad_awaddr),.awlen(biu_pad_awlen),.awid(biu_pad_awid),.awsize(biu_pad_awsize),.awvalid(biu_pad_awvalid),.awready(pad_biu_awready),
 .wdata(biu_pad_wdata),.wstrb(biu_pad_wstrb),.wlast(biu_pad_wlast),.wvalid(biu_pad_wvalid),.wready(pad_biu_wready),
 .bid(pad_biu_bid),.bvalid(pad_biu_bvalid),.bresp(pad_biu_bresp),.bready(biu_pad_bready));
 endmodule
