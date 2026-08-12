// Synthesis-only single-port RAM used by edge-rv's Yosys cache views.
module fpga_ram #(
  parameter DATAWIDTH = 2,
  parameter ADDRWIDTH = 2,
  parameter MEMDEPTH = 1 << ADDRWIDTH
) (
  input wire PortAClk,
  input wire [ADDRWIDTH-1:0] PortAAddr,
  input wire [DATAWIDTH-1:0] PortADataIn,
  input wire PortAWriteEnable,
  output reg [DATAWIDTH-1:0] PortADataOut
);
  reg [DATAWIDTH-1:0] mem [0:MEMDEPTH-1];
  always @(posedge PortAClk) begin
    if (PortAWriteEnable) begin mem[PortAAddr] <= PortADataIn; PortADataOut <= PortADataIn; end
    else PortADataOut <= mem[PortAAddr];
  end
endmodule
