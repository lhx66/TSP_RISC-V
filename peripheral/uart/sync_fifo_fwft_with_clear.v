// First-Word-Fall-Through (FWFT) Synchronous FIFO with Clear
// In FWFT mode, the first data word appears automatically on output when data is available
module sync_fifo_fwft_with_clear #(
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
  reg [DATA_WIDTH-1:0] fwft_data;
  reg                  fwft_valid;
  reg [ADDR_WIDTH:0]   rd_ptr_next;
  reg [ADDR_WIDTH:0]   wr_ptr_next;

  // Full and empty detection
  wire full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
               (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
  wire empty = (wr_ptr == rd_ptr) && !fwft_valid;

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

  // Read pointer and FWFT logic
  always @(posedge clk) begin
    if (!rst_n) begin
      rd_ptr     <= {(ADDR_WIDTH+1){1'b0}};
      fwft_data  <= {DATA_WIDTH{1'b0}};
      fwft_valid <= 1'b0;
    end else if (i_clr) begin
      rd_ptr     <= {(ADDR_WIDTH+1){1'b0}};
      fwft_data  <= {DATA_WIDTH{1'b0}};
      fwft_valid <= 1'b0;
    end else begin
      // Calculate next pointers
      rd_ptr_next = rd_ptr + 1'b1;
      wr_ptr_next = wr_ptr;

      // Default: keep current values
      fwft_valid <= 1'b0;

      // Handle read operation
      if (i_rd_en && !empty) begin
        if (rd_ptr_next != wr_ptr) begin
          // More data available, fetch next word
          rd_ptr     <= rd_ptr_next;
          fwft_data  <= mem[rd_ptr_next[ADDR_WIDTH-1:0]];
          fwft_valid <= 1'b1;
        end else begin
          // No more data
          rd_ptr     <= rd_ptr_next;
          fwft_data  <= {DATA_WIDTH{1'b0}};
          fwft_valid <= 1'b0;
        end
      end else if (!fwft_valid && (rd_ptr != wr_ptr)) begin
        // FWFT: automatically fetch first word when available
        fwft_data  <= mem[rd_ptr[ADDR_WIDTH-1:0]];
        fwft_valid <= 1'b1;
      end
    end
  end

  // Output assignments
  assign o_rd_data = fwft_valid ? fwft_data : {DATA_WIDTH{1'b0}};
  assign o_empty  = !fwft_valid;
  assign o_full   = full;

endmodule
