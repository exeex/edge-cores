// SPDX-License-Identifier: Apache-2.0
// Public synchronous, read-before-write model for the E3 SRAM macro boundary.
// Physical implementations bind their memory macros instead of this model.
module fakeram_512x8 (
  output reg [7:0] rd_out,
  input [8:0] addr_in,
  input we_in,
  input [7:0] wd_in,
  input clk,
  input ce_in
);
  reg [7:0] mem [0:511];
  always @(posedge clk) begin
    if (ce_in) begin
      rd_out <= mem[addr_in];
      if (we_in)
        mem[addr_in] <= wd_in;
    end else begin
      rd_out <= 8'bx;
    end
  end
endmodule
