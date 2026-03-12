// Standard Synchronous FIFO with Clear
module sync_fifo_with_clear #(
  parameter DATA_WIDTH             = 8,
  parameter DEPTH                  = 16,
  parameter EXTRA_OUTPUT_REGISTER  = 0
) (
  input  wire                     clk,
  input  wire                     rst_n,
  input  wire                     i_clr,
  input  wire                     i_wr_en,
  input  wire [DATA_WIDTH-1:0]    i_wr_data,
  output wire                     o_full,
  input  wire                     i_rd_en,
  output wire [DATA_WIDTH-1:0]    o_rd_data,
  output wire                     o_empty
);

  // Calculate address width
  localparam ADDR_WIDTH = (DEPTH == 1) ? 1 :
                         (DEPTH == 2) ? 1 :
                         (DEPTH == 4) ? 2 :
                         (DEPTH == 8) ? 3 :
                         (DEPTH == 16) ? 4 :
                         (DEPTH == 32) ? 5 :
                         (DEPTH == 64) ? 6 :
                         (DEPTH == 128) ? 7 :
                         (DEPTH == 256) ? 8 :
                         (DEPTH == 512) ? 9 :
                         (DEPTH == 1024) ? 10 : 11;

  // Internal signals
  reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
  reg [ADDR_WIDTH:0]   wr_ptr;
  reg [ADDR_WIDTH:0]   rd_ptr;
  reg [DATA_WIDTH-1:0] rd_data_reg;
  reg                  rd_data_valid;

  // Full and empty detection
  wire full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
               (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
  wire empty = (wr_ptr == rd_ptr);

  // Write pointer and memory write
  always @(posedge clk) begin
    if (!rst_n) begin
      wr_ptr <= {(ADDR_WIDTH+1){1'b0}};
    end else if (i_clr) begin
      wr_ptr <= {(ADDR_WIDTH+1){1'b0}};
    end else if (i_wr_en && !full) begin
      mem[wr_ptr[ADDR_WIDTH-1:0]] <= i_wr_data;
      wr_ptr <= wr_ptr + 1'b1;
    end
  end

  // Read pointer
  always @(posedge clk) begin
    if (!rst_n) begin
      rd_ptr <= {(ADDR_WIDTH+1){1'b0}};
    end else if (i_clr) begin
      rd_ptr <= {(ADDR_WIDTH+1){1'b0}};
    end else if (i_rd_en && !empty) begin
      rd_ptr <= rd_ptr + 1'b1;
    end
  end

  // Output data handling with register
  always @(posedge clk) begin
    if (!rst_n) begin
      rd_data_reg    <= {DATA_WIDTH{1'b0}};
      rd_data_valid  <= 1'b0;
    end else if (i_clr) begin
      rd_data_reg    <= {DATA_WIDTH{1'b0}};
      rd_data_valid  <= 1'b0;
    end else if (EXTRA_OUTPUT_REGISTER == 1) begin
      if (i_rd_en && !empty) begin
        rd_data_reg    <= mem[rd_ptr[ADDR_WIDTH-1:0]];
        rd_data_valid  <= 1'b1;
      end else if (i_rd_en) begin
        rd_data_valid  <= 1'b0;
      end
    end
  end

  // Output multiplexing based on EXTRA_OUTPUT_REGISTER parameter
  assign o_rd_data = (EXTRA_OUTPUT_REGISTER == 1) ? rd_data_reg : mem[rd_ptr[ADDR_WIDTH-1:0]];
  assign o_empty  = (EXTRA_OUTPUT_REGISTER == 1) ? !rd_data_valid : empty;
  assign o_full   = full;

endmodule
