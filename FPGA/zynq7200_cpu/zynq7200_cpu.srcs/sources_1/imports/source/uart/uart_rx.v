module uart_rx #(
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
  input  wire       i_fifo_clear,
  input  wire       i_fifo_rd_en,
  output wire [7:0] o_fifo_rd_data,
  output wire       o_fifo_full,
  output wire       o_fifo_empty,

  // Strobe generation
  input  wire       i_rx_strb,
  output reg        o_rx_strb_en,

  // UART RX
  input  wire       i_uart_rx,

  // Receive errors
  output reg        o_parity_error,
  output reg        o_frame_error,
  output reg        o_overflow_error,
  output reg        o_underflow_error
);

  // State definitions
  localparam [2:0] IDLE                = 3'd0;
  localparam [2:0] RECEIVE_START_BIT   = 3'd1;
  localparam [2:0] RECEIVE_DATA_BITS   = 3'd2;
  localparam [2:0] SHIFT_DATA_BITS     = 3'd3;
  localparam [2:0] RECEIVE_PARITY      = 3'd4;
  localparam [2:0] RECEIVE_STOP_BIT0   = 3'd5;
  localparam [2:0] RECEIVE_STOP_BIT1   = 3'd6;

  reg [2:0] state;

  // (* ASYNC_REG = "TRUE" *) - these are Xilinx specific attributes
  // Some synthesis tools support them in Verilog, others don't
  reg uart_2ff_sync_stage1;
  reg uart_2ff_sync_stage2;
  reg [1:0] uart_rx;
  reg       start_bit;

  wire       fifo_full;
  reg        fifo_wr_en;
  reg [7:0]  fifo_wr_data;

  assign o_fifo_full = fifo_full;

  reg [2:0] received_bits;
  reg [2:0] data_bits;
  reg       calc_parity;
  reg       parity;
  reg       stop_bits;
  reg [4:0] threshold_counter;
  reg [4:0] threshold_value;

  // == OVERFLOW AND UNDERFLOW HANDLING ==
  always @(posedge clk) begin
    if (!rst_n) begin
      o_overflow_error  <= 1'b0;
      o_underflow_error <= 1'b0;
    end else begin
      o_overflow_error  <= fifo_full & fifo_wr_en;
      o_underflow_error <= o_fifo_empty & i_fifo_rd_en;
    end
  end

  // == SAMPLE ASYNC INPUTS ==
  always @(posedge clk) begin
    if (!rst_n) begin
      uart_2ff_sync_stage1 <= 1'b1;
      uart_2ff_sync_stage2 <= 1'b1;
    end else begin
      uart_2ff_sync_stage1 <= i_uart_rx;
      uart_2ff_sync_stage2 <= uart_2ff_sync_stage1;
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      uart_rx   <= 2'b11;
      start_bit <= 1'b0;
    end else begin
      start_bit <= 1'b0;
      uart_rx   <= {uart_rx[0], uart_2ff_sync_stage2};
      if (uart_rx == 2'b10) begin
        start_bit <= 1'b1;
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
        3'b011  : threshold_value <= 5'd8;
        3'b100  : threshold_value <= 5'd10;
        3'b101  : threshold_value <= 5'd12;
        3'b110  : threshold_value <= 5'd14;
        3'b111  : threshold_value <= 5'd15;
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
        if (fifo_wr_en && !i_fifo_rd_en && !fifo_full) begin
          threshold_counter <= threshold_counter + 1'b1;
        end else if (i_fifo_rd_en && !fifo_wr_en && !o_fifo_empty) begin
          threshold_counter <= threshold_counter - 1'b1;
        end
      end
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      o_threshold <= 1'b0;
    end else begin
      o_threshold <= (threshold_counter >= threshold_value);
    end
  end

  // == RX FSM ==
  always @(posedge clk) begin
    if (!rst_n) begin
      state              <= IDLE;
      fifo_wr_data       <= 8'b0;
      o_rx_strb_en       <= 1'b0;
      received_bits      <= 3'b0;
      data_bits          <= 3'b0;
      parity             <= 1'b0;
      stop_bits          <= 1'b0;
      calc_parity        <= 1'b0;
      o_parity_error     <= 1'b0;
      o_frame_error      <= 1'b0;
    end else begin
      o_rx_strb_en   <= 1'b1;
      o_parity_error <= 1'b0;
      o_frame_error  <= 1'b0;
      fifo_wr_en     <= 1'b0;

      case (state)
        IDLE: begin
          state <= IDLE;

          if (start_bit) begin
            state              <= RECEIVE_START_BIT;
            received_bits      <= 3'b0;
            data_bits          <= 3'd4 + {1'b0, i_data_bits};
            parity             <= i_use_parity;
            stop_bits          <= i_stop_bits;
            calc_parity        <= i_parity;
            o_rx_strb_en       <= 1'b1;
            fifo_wr_data       <= 8'b0;
          end else begin
            o_rx_strb_en <= 1'b0;
          end
        end

        RECEIVE_START_BIT : begin
          state <= RECEIVE_START_BIT;
          if (i_rx_strb) begin
            state <= RECEIVE_DATA_BITS;
          end
        end

        RECEIVE_DATA_BITS: begin
          state <= RECEIVE_DATA_BITS;
          if (i_rx_strb && received_bits != data_bits) begin
            state           <= RECEIVE_DATA_BITS;
            fifo_wr_data    <= {uart_rx[1], fifo_wr_data[7:1]};
            received_bits   <= received_bits + 1'b1;
            calc_parity     <= calc_parity ^ uart_rx[1];
          end else if (i_rx_strb && received_bits == data_bits) begin
            fifo_wr_data    <= {uart_rx[1], fifo_wr_data[7:1]};
            calc_parity     <= calc_parity ^ uart_rx[1];
            state           <= SHIFT_DATA_BITS;
          end
        end

        SHIFT_DATA_BITS : begin
          state <= SHIFT_DATA_BITS;
          case (data_bits[1:0])
            2'b00 : fifo_wr_data <= {3'b000, fifo_wr_data[7:3]};
            2'b01 : fifo_wr_data <= {2'b00, fifo_wr_data[7:2]};
            2'b10 : fifo_wr_data <= {1'b0, fifo_wr_data[7:1]};
            2'b11 : fifo_wr_data <= fifo_wr_data;
          endcase

          if (parity) begin
            state <= RECEIVE_PARITY;
          end else begin
            state <= RECEIVE_STOP_BIT0;
          end
        end

        RECEIVE_PARITY : begin
          state <= RECEIVE_PARITY;
          if (i_rx_strb) begin
            if (uart_rx[1] != calc_parity) begin
              o_parity_error <= 1'b1;
              state          <= RECEIVE_STOP_BIT0;
            end
          end
        end

        RECEIVE_STOP_BIT0 : begin
          state <= RECEIVE_STOP_BIT0;
          if (i_rx_strb) begin
            if (uart_rx[1] != 1'b1) begin
              o_frame_error <= 1'b1;
            end else begin
              fifo_wr_en <= 1'b1;
            end

            if (stop_bits) begin
              state <= RECEIVE_STOP_BIT1;
            end else begin
              state <= IDLE;
            end
          end
        end

        RECEIVE_STOP_BIT1 : begin
          if (i_rx_strb) begin
            if (uart_rx[1] != 1'b1) begin
              o_frame_error <= 1'b1;
            end
            state <= IDLE;
          end else begin
            state <= RECEIVE_STOP_BIT1;
          end
        end

        default : begin
          state <= IDLE;
        end
      endcase
    end
  end

  sync_fifo_fwft_with_clear #(
    .DATA_WIDTH             (8           ),
    .DEPTH                  (FIFO_DEPTH  ),
    .EXTRA_OUTPUT_REGISTER  (1'b0        )
  ) fifo_tx_inst (
    .clk         (clk               ),
    .rst_n       (rst_n             ),
    .i_clr       (i_fifo_clear      ),
    .i_wr_en     (fifo_wr_en        ),
    .i_wr_data   (fifo_wr_data      ),
    .o_full      (fifo_full         ),
    .i_rd_en     (i_fifo_rd_en      ),
    .o_rd_data   (o_fifo_rd_data    ),
    .o_empty     (o_fifo_empty      )
  );

endmodule
