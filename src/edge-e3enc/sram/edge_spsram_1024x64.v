// &ModuleBeg; @22
module edge_spsram_1024x64(
  A,
  CEN,
  CLK,
  D,
  GWEN,
  Q,
  WEN
);

// &Ports; @23
input   [9 :0]  A;
input           CEN;
input           CLK;
input   [63:0]  D;
input           GWEN;
input   [63:0]  WEN;
output  [63:0]  Q;

// &Regs; @24

// &Wires; @25
wire    [9 :0]  A;
wire            CEN;
wire            CLK;
wire    [63:0]  D;
wire            GWEN;
wire    [63:0]  Q;
wire    [63:0]  WEN;


//**********************************************************
//                  Parameter Definition
//**********************************************************
parameter ADDR_WIDTH = 10;
parameter DATA_WIDTH = 64;
parameter WE_WIDTH   = 64;

// &Force("bus","Q",DATA_WIDTH-1,0); @34
// &Force("bus","WEN",WE_WIDTH-1,0); @35
// &Force("bus","A",ADDR_WIDTH-1,0); @36
// &Force("bus","D",DATA_WIDTH-1,0); @37

//  //********************************************************
//  //*                        FPGA memory                   *
//  //********************************************************
//   &Instance("edge_f_spsram_1024x64"); @43
edge_f_spsram_1024x64  x_edge_f_spsram_1024x64 (
  .A    (A   ),
  .CEN  (CEN ),
  .CLK  (CLK ),
  .D    (D   ),
  .GWEN (GWEN),
  .Q    (Q   ),
  .WEN  (WEN )
);

//   &Instance("edge_umc_spsram_1024x64"); @49
//   &Instance("edge_tsmc_spsram_1024x64"); @55
// &ModuleEnd; @58
endmodule



