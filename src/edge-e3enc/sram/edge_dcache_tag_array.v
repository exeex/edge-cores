// First Edge D-cache tag/valid slice.
module edge_dcache_tag_array #(
  parameter TAG_WIDTH = 50,
  parameter LINES = 256
) (
  input  wire                     clk,
  input  wire                     write_valid,
  input  wire [$clog2(LINES)-1:0] write_index,
  input  wire [TAG_WIDTH-1:0]     write_tag,
  input  wire                     write_valid_bit,
  input  wire [$clog2(LINES)-1:0] read_index,
  output wire [TAG_WIDTH-1:0]     read_tag,
  output wire                     read_valid_bit
);

  reg [TAG_WIDTH-1:0] tag_q [0:LINES-1];
  reg                 valid_q [0:LINES-1];

  assign read_tag[TAG_WIDTH-1:0] = tag_q[read_index];
  assign read_valid_bit = valid_q[read_index];

  always @(posedge clk) begin
    if (write_valid) begin
      tag_q[write_index] <= write_tag[TAG_WIDTH-1:0];
      valid_q[write_index] <= write_valid_bit;
    end
  end

`ifdef IVERILOG_SIM
  integer init_i;
  initial begin
    for (init_i = 0; init_i < LINES; init_i = init_i + 1) begin
      tag_q[init_i] = {TAG_WIDTH{1'b0}};
      valid_q[init_i] = 1'b0;
    end
  end
`endif

endmodule
