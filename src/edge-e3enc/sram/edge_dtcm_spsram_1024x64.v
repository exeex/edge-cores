module edge_dtcm_spsram_1024x64(
  A,
  CEN,
  CLK,
  D,
  GWEN,
  Q,
  WEN
);

parameter ADDR_WIDTH = 10;
parameter DATA_WIDTH = 64;
parameter BYTE_WIDTH = DATA_WIDTH / 8;

input  [ADDR_WIDTH-1:0] A;
input                   CEN;
input                   CLK;
input  [DATA_WIDTH-1:0] D;
input                   GWEN;
input  [DATA_WIDTH-1:0] WEN;
output [DATA_WIDTH-1:0] Q;

reg [DATA_WIDTH-1:0] Q;

(* ram_style = "block" *)
reg [DATA_WIDTH-1:0] mem [0:(1 << ADDR_WIDTH)-1];

integer byte_idx;

always @(posedge CLK) begin
  if (!CEN) begin
    Q[DATA_WIDTH-1:0] <= mem[A[ADDR_WIDTH-1:0]];

    if (!GWEN) begin
      for (byte_idx = 0; byte_idx < BYTE_WIDTH; byte_idx = byte_idx + 1) begin
        if (WEN[byte_idx*8 +: 8] != 8'hff)
          mem[A[ADDR_WIDTH-1:0]][byte_idx*8 +: 8] <=
            D[byte_idx*8 +: 8];
      end
    end
  end
end

endmodule

