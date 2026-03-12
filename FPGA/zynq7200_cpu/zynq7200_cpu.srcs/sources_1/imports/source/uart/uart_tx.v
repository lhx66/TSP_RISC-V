module uart_tx #(
  parameter FIFO_DEPTH = 16
) (
  input  wire       clk,
  input  wire       rst_n,

  // UART configuration
  input  wire       i_parity,
  input  wire [1:0] i_data_bits,
  input  wire       i_stop_bits,
  input  wire       i_use_parity,
  input  wire [2:0] i_threshold_value,
  output reg        o_threshold,

  // Data
  input  wire       i_fifo_wr_en,
  input  wire [7:0] i_fifo_wr_data,
  input  wire       i_fifo_clear,
  output wire       o_fifo_full,
  output wire       o_fifo_empty,
  output reg        o_overflow_error,

  // Strobe generation
  input  wire       i_tx_strb,
  output reg        o_tx_strb_en,

  // UART TX
  output reg        o_uart_tx
);

  // State definitions
  localparam [2:0] IDLE             = 3'd0;
  localparam [2:0] SEND_START_BIT   = 3'd1;
  localparam [2:0] SEND_DATA_BITS   = 3'd2;
  localparam [2:0] SEND_PARITY      = 3'd3;
  localparam [2:0] SEND_STOP_BIT0   = 3'd4;
  localparam [2:0] SEND_STOP_BIT1   = 3'd5;

  reg [2:0] state;

  reg        fifo_rd_en;
  wire [7:0]  fifo_tx_data;
  reg [7:0]  uart_tx_data;
  wire       fifo_empty;
  reg [2:0]  sent_bits;
  reg [2:0]  data_bits;
  reg        calc_parity;
  reg        parity;
  reg        stop_bits;
  reg [4:0]  threshold_counter;
  reg [4:0]  threshold_value;

  assign o_fifo_empty = fifo_empty;

  always @(posedge clk) begin
    if (!rst_n) begin
      o_overflow_error <= 1'b0;
    end else begin
      if (i_fifo_wr_en && o_fifo_full) begin
        o_overflow_error <= 1'b1;
      end
    end
  end

  // == THRESHOLD HANDLING ==
  always @(posedge clk) begin
    if (!rst_n) begin
      threshold_value <= 5'b0;
    end else begin
      case (i_threshold_value)
        3'b000  : threshold_value <= 5'd1;
        3'b001  : threshold_value <= 5'd2;
        3'b010  : threshold_value <= 5'd4;
        3'b011  : threshold_value <= 5'd6;
        3'b100  : threshold_value <= 5'd8;
        3'b101  : threshold_value <= 5'd10;
        3'b110  : threshold_value <= 5'd12;
        3'b111  : threshold_value <= 5'd14;
        default : threshold_value <= 5'd1;
      endcase
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      threshold_counter <= 5'b0;
    end else begin
      if (i_fifo_clear) begin
        threshold_counter <= 5'b0;
      end else begin
        if (i_fifo_wr_en && !fifo_rd_en && !o_fifo_full) begin
          threshold_counter <= threshold_counter + 1'b1;
        end else if (fifo_rd_en && !i_fifo_wr_en && !fifo_empty) begin
          threshold_counter <= threshold_counter - 1'b1;
        end
      end
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      o_threshold <= 1'b0;
    end else begin
      o_threshold <= (threshold_counter <= threshold_value);
    end
  end

  // == TX FSM ==
  always @(posedge clk) begin
    if (!rst_n) begin
      state          <= IDLE;
      o_uart_tx      <= 1'b1;
      fifo_rd_en     <= 1'b0;
      o_tx_strb_en   <= 1'b0;
      data_bits      <= 3'b0;
      sent_bits      <= 3'b0;
      calc_parity    <= 1'b0;
      uart_tx_data   <= 8'b0;
    end else begin
      o_uart_tx    <= 1'b1;
      fifo_rd_en   <= 1'b0;
      o_tx_strb_en <= 1'b1;

      case (state)
        IDLE: begin
          state <= IDLE;

          if (!fifo_empty) begin
            parity        <= i_use_parity;
            data_bits     <= i_data_bits;
            stop_bits     <= i_stop_bits;
            fifo_rd_en    <= 1'b1;
            state         <= SEND_START_BIT;
            data_bits     <= 3'd4 + {1'b0, i_data_bits};
            sent_bits     <= 3'b0;
            calc_parity   <= i_parity;
          end else begin
            o_tx_strb_en <= 1'b0;
          end
        end

        SEND_START_BIT : begin
          state     <= SEND_START_BIT;
          o_uart_tx <= 1'b0;
          if (i_tx_strb) begin
            state        <= SEND_DATA_BITS;
            uart_tx_data <= fifo_tx_data;
          end
        end

        SEND_DATA_BITS: begin
          o_uart_tx <= uart_tx_data[0];
          state     <= SEND_DATA_BITS;
          if (i_tx_strb && sent_bits != data_bits) begin
            calc_parity  <= calc_parity ^ uart_tx_data[0];
            sent_bits    <= sent_bits + 1'b1;
            uart_tx_data <= {1'b0, uart_tx_data[7:1]};
            state        <= SEND_DATA_BITS;
          end else if (i_tx_strb && sent_bits == data_bits) begin
            if (parity) begin
              state <= SEND_PARITY;
            end else begin
              state <= SEND_STOP_BIT0;
            end
          end
        end

        SEND_PARITY : begin
          o_uart_tx <= calc_parity;
          if (i_tx_strb) begin
            state <= SEND_STOP_BIT0;
          end else begin
            state <= SEND_PARITY;
          end
        end

        SEND_STOP_BIT0 : begin
          o_uart_tx <= 1'b1;
          if (i_tx_strb) begin
            if (stop_bits) begin
              state <= SEND_STOP_BIT1;
            end else begin
              state <= IDLE;
            end
          end else begin
            state <= SEND_STOP_BIT0;
          end
        end

        SEND_STOP_BIT1 : begin
          o_uart_tx <= 1'b1;
          if (i_tx_strb) begin
            state <= IDLE;
          end else begin
            state <= SEND_STOP_BIT1;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  sync_fifo_with_clear #(
    .DATA_WIDTH             (8           ),
    .DEPTH                  (FIFO_DEPTH  ),
    .EXTRA_OUTPUT_REGISTER  (1'b1        )
  ) fifo_tx_inst (
    .clk         (clk               ),
    .rst_n       (rst_n             ),
    .i_clr       (i_fifo_clear      ),
    .i_wr_en     (i_fifo_wr_en      ),
    .i_wr_data   (i_fifo_wr_data    ),
    .o_full      (o_fifo_full       ),
    .i_rd_en     (fifo_rd_en        ),
    .o_rd_data   (fifo_tx_data      ),
    .o_empty     (fifo_empty        )
  );

endmodule
