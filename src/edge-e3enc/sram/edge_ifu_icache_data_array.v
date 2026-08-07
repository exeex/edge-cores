// First Edge I-cache data array slice.
module edge_ifu_icache_data_array #(
  parameter LINE_BITS = 128,
  parameter LINES = 1024
) (
  input  wire                     clk,
  input  wire                     write_valid,
  input  wire [$clog2(LINES)-1:0] write_index,
  input  wire [LINE_BITS-1:0]     write_data,
  input  wire [$clog2(LINES)-1:0] read_index,
  output wire [LINE_BITS-1:0]     read_data
);

  reg [LINE_BITS-1:0] mem_q [0:LINES-1];

  assign read_data[LINE_BITS-1:0] = mem_q[read_index];

  always @(posedge clk) begin
    if (write_valid) begin
      mem_q[write_index] <= write_data[LINE_BITS-1:0];
    end
  end

`ifdef IVERILOG_SIM
  integer init_i;
  initial begin
    for (init_i = 0; init_i < LINES; init_i = init_i + 1) begin
      mem_q[init_i] = {LINE_BITS{1'b0}};
    end
  end
`endif

endmodule
