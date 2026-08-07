// First Edge I-cache tag/valid array slice.
module edge_ifu_icache_tag_array #(
  parameter TAG_WIDTH = 24,
  parameter LINES = 1024
) (
  input  wire                     clk,
  input  wire                     rst_b,
  input  wire                     write_valid,
  input  wire [$clog2(LINES)-1:0] write_index,
  input  wire [TAG_WIDTH-1:0]     write_tag,
  input  wire                     write_valid_bit,
  input  wire                     clear_valid,
  input  wire [$clog2(LINES)-1:0] clear_index,
  input  wire [$clog2(LINES)-1:0] read_index,
  output wire [TAG_WIDTH-1:0]     read_tag,
  output wire                     read_valid_bit
);

  reg [TAG_WIDTH-1:0] tag_q [0:LINES-1];
  reg                 valid_q [0:LINES-1];

  assign read_tag[TAG_WIDTH-1:0] = tag_q[read_index];
  assign read_valid_bit = valid_q[read_index];

  integer valid_i;

  always @(posedge clk or negedge rst_b) begin
    if (!rst_b) begin
      for (valid_i = 0; valid_i < LINES; valid_i = valid_i + 1) begin
        valid_q[valid_i] = 1'b0;
      end
    end else if (clear_valid) begin
      tag_q[clear_index] <= {TAG_WIDTH{1'b0}};
      valid_q[clear_index] <= 1'b0;
    end else if (write_valid) begin
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
