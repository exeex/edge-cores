// First Edge D-cache dirty-state slice.
module edge_dcache_dirty_array #(
  parameter LINES = 256
) (
  input  wire                     clk,
  input  wire                     write_valid,
  input  wire [$clog2(LINES)-1:0] write_index,
  input  wire                     write_dirty_bit,
  input  wire [$clog2(LINES)-1:0] read_index,
  output wire                     read_dirty_bit
);

  reg dirty_q [0:LINES-1];

  assign read_dirty_bit = dirty_q[read_index];

  always @(posedge clk) begin
    if (write_valid)
      dirty_q[write_index] <= write_dirty_bit;
  end

`ifdef IVERILOG_SIM
  integer init_i;
  initial begin
    for (init_i = 0; init_i < LINES; init_i = init_i + 1) begin
      dirty_q[init_i] = 1'b0;
    end
  end
`endif

endmodule
