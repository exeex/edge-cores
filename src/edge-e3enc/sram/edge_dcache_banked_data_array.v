// Experimental macro-friendly 4-bank D-cache data array slice.
module edge_dcache_banked_data_array #(
  parameter LINE_COUNT       = 256,
  parameter LINE_INDEX_WIDTH = (LINE_COUNT <= 2) ? 1 : $clog2(LINE_COUNT),
  parameter ROW_COUNT        = LINE_COUNT * 2,
  parameter ROW_INDEX_WIDTH  = (ROW_COUNT <= 2) ? 1 : $clog2(ROW_COUNT)
) (
  input  wire                         clk,
  input  wire                         reset_b,
  input  wire                         phase,

  input  wire                         lsu0_valid,
  output wire                         lsu0_ready,
  input  wire                         lsu0_write,
  input  wire [LINE_INDEX_WIDTH-1:0]  lsu0_line_index,
  input  wire [1:0]                   lsu0_beat_index,
  input  wire                         lsu0_word_hi,
  input  wire [63:0]                  lsu0_wdata,
  input  wire [7:0]                   lsu0_wstrb,
  output reg                          lsu0_rvalid,
  output reg  [63:0]                  lsu0_rdata,

  input  wire                         lsu1_valid,
  output wire                         lsu1_ready,
  input  wire                         lsu1_write,
  input  wire [LINE_INDEX_WIDTH-1:0]  lsu1_line_index,
  input  wire [1:0]                   lsu1_beat_index,
  input  wire                         lsu1_word_hi,
  input  wire [63:0]                  lsu1_wdata,
  input  wire [7:0]                   lsu1_wstrb,
  output reg                          lsu1_rvalid,
  output reg  [63:0]                  lsu1_rdata,

  input  wire                         mem_valid,
  output wire                         mem_ready,
  input  wire                         mem_write,
  input  wire [LINE_INDEX_WIDTH-1:0]  mem_line_index,
  input  wire [1:0]                   mem_beat_index,
  input  wire [127:0]                 mem_wdata,
  input  wire [15:0]                  mem_wstrb,
  output reg                          mem_rvalid,
  output reg  [127:0]                 mem_rdata
);

  reg [63:0] bank0_q [0:ROW_COUNT-1];
  reg [63:0] bank1_q [0:ROW_COUNT-1];
  reg [63:0] bank2_q [0:ROW_COUNT-1];
  reg [63:0] bank3_q [0:ROW_COUNT-1];

  wire lsu0_half;
  wire lsu1_half;
  wire lsu0_bank_hi;
  wire lsu1_bank_hi;
  wire lsu_bank_conflict;
  wire mem_half;
  wire lsu0_fire;
  wire lsu1_fire;
  wire mem_fire;
  wire [ROW_INDEX_WIDTH-1:0] lsu0_row_index;
  wire [ROW_INDEX_WIDTH-1:0] lsu1_row_index;
  wire [ROW_INDEX_WIDTH-1:0] mem_row_index;

  assign lsu0_half = lsu0_beat_index[0];
  assign lsu1_half = lsu1_beat_index[0];
  assign lsu0_bank_hi = lsu0_word_hi;
  assign lsu1_bank_hi = lsu1_word_hi;
  assign lsu_bank_conflict =
    lsu0_valid && lsu1_valid &&
    (lsu0_half == lsu1_half) &&
    (lsu0_bank_hi == lsu1_bank_hi);
  assign mem_half = mem_beat_index[0];
  assign lsu0_ready = !mem_valid || (lsu0_half == phase);
  assign lsu1_ready = (!mem_valid || (lsu1_half == phase)) &&
                      !lsu_bank_conflict;
  assign mem_ready = (mem_half != phase);
  assign lsu0_fire = lsu0_valid && lsu0_ready;
  assign lsu1_fire = lsu1_valid && lsu1_ready;
  assign mem_fire = mem_valid && mem_ready;
  assign lsu0_row_index = {lsu0_line_index, lsu0_beat_index[1]};
  assign lsu1_row_index = {lsu1_line_index, lsu1_beat_index[1]};
  assign mem_row_index = {mem_line_index, mem_beat_index[1]};

  integer byte_idx;
  integer init_i;

  always @(posedge clk or negedge reset_b) begin
    if (!reset_b) begin
      lsu0_rvalid <= 1'b0;
      lsu0_rdata <= 64'b0;
      lsu1_rvalid <= 1'b0;
      lsu1_rdata <= 64'b0;
      mem_rvalid <= 1'b0;
      mem_rdata <= 128'b0;
`ifdef IVERILOG_SIM
      for (init_i = 0; init_i < ROW_COUNT; init_i = init_i + 1) begin
        bank0_q[init_i] = 64'b0;
        bank1_q[init_i] = 64'b0;
        bank2_q[init_i] = 64'b0;
        bank3_q[init_i] = 64'b0;
      end
`endif
    end else begin
      lsu0_rvalid <= lsu0_fire && !lsu0_write;
      lsu1_rvalid <= lsu1_fire && !lsu1_write;
      mem_rvalid <= mem_fire && !mem_write;

      if (lsu0_fire && !lsu0_write) begin
        case ({lsu0_half, lsu0_bank_hi})
          2'b00: lsu0_rdata <= bank0_q[lsu0_row_index];
          2'b01: lsu0_rdata <= bank1_q[lsu0_row_index];
          2'b10: lsu0_rdata <= bank2_q[lsu0_row_index];
          default: lsu0_rdata <= bank3_q[lsu0_row_index];
        endcase
      end
      if (lsu1_fire && !lsu1_write) begin
        case ({lsu1_half, lsu1_bank_hi})
          2'b00: lsu1_rdata <= bank0_q[lsu1_row_index];
          2'b01: lsu1_rdata <= bank1_q[lsu1_row_index];
          2'b10: lsu1_rdata <= bank2_q[lsu1_row_index];
          default: lsu1_rdata <= bank3_q[lsu1_row_index];
        endcase
      end
      if (mem_fire && !mem_write) begin
        mem_rdata <= mem_half ?
          {bank3_q[mem_row_index], bank2_q[mem_row_index]} :
          {bank1_q[mem_row_index], bank0_q[mem_row_index]};
      end

      if (lsu0_fire && lsu0_write) begin
        if (lsu0_half) begin
          for (byte_idx = 0; byte_idx < 8; byte_idx = byte_idx + 1) begin
            if (lsu0_wstrb[byte_idx] && !lsu0_word_hi)
              bank2_q[lsu0_row_index][byte_idx*8 +: 8] <=
                lsu0_wdata[byte_idx*8 +: 8];
            if (lsu0_wstrb[byte_idx] && lsu0_word_hi)
              bank3_q[lsu0_row_index][byte_idx*8 +: 8] <=
                lsu0_wdata[byte_idx*8 +: 8];
          end
        end else begin
          for (byte_idx = 0; byte_idx < 8; byte_idx = byte_idx + 1) begin
            if (lsu0_wstrb[byte_idx] && !lsu0_word_hi)
              bank0_q[lsu0_row_index][byte_idx*8 +: 8] <=
                lsu0_wdata[byte_idx*8 +: 8];
            if (lsu0_wstrb[byte_idx] && lsu0_word_hi)
              bank1_q[lsu0_row_index][byte_idx*8 +: 8] <=
                lsu0_wdata[byte_idx*8 +: 8];
          end
        end
      end

      if (lsu1_fire && lsu1_write) begin
        if (lsu1_half) begin
          for (byte_idx = 0; byte_idx < 8; byte_idx = byte_idx + 1) begin
            if (lsu1_wstrb[byte_idx] && !lsu1_word_hi)
              bank2_q[lsu1_row_index][byte_idx*8 +: 8] <=
                lsu1_wdata[byte_idx*8 +: 8];
            if (lsu1_wstrb[byte_idx] && lsu1_word_hi)
              bank3_q[lsu1_row_index][byte_idx*8 +: 8] <=
                lsu1_wdata[byte_idx*8 +: 8];
          end
        end else begin
          for (byte_idx = 0; byte_idx < 8; byte_idx = byte_idx + 1) begin
            if (lsu1_wstrb[byte_idx] && !lsu1_word_hi)
              bank0_q[lsu1_row_index][byte_idx*8 +: 8] <=
                lsu1_wdata[byte_idx*8 +: 8];
            if (lsu1_wstrb[byte_idx] && lsu1_word_hi)
              bank1_q[lsu1_row_index][byte_idx*8 +: 8] <=
                lsu1_wdata[byte_idx*8 +: 8];
          end
        end
      end

      if (mem_fire && mem_write) begin
        if (mem_half) begin
          for (byte_idx = 0; byte_idx < 8; byte_idx = byte_idx + 1) begin
            if (mem_wstrb[byte_idx])
              bank2_q[mem_row_index][byte_idx*8 +: 8] <=
                mem_wdata[byte_idx*8 +: 8];
            if (mem_wstrb[byte_idx + 8])
              bank3_q[mem_row_index][byte_idx*8 +: 8] <=
                mem_wdata[(byte_idx + 8)*8 +: 8];
          end
        end else begin
          for (byte_idx = 0; byte_idx < 8; byte_idx = byte_idx + 1) begin
            if (mem_wstrb[byte_idx])
              bank0_q[mem_row_index][byte_idx*8 +: 8] <=
                mem_wdata[byte_idx*8 +: 8];
            if (mem_wstrb[byte_idx + 8])
              bank1_q[mem_row_index][byte_idx*8 +: 8] <=
                mem_wdata[(byte_idx + 8)*8 +: 8];
          end
        end
      end
    end
  end

endmodule
