module uart_baudgen #(
  parameter CLK_FREQ = 100000000
) (
  input  wire       clk,
  input  wire       rst_n,
  input  wire       i_rx_strb_en,
  input  wire       i_tx_strb_en,
  input  wire [2:0] i_baud_rate,
  output reg        o_tx_strb,
  output reg        o_rx_strb
);

  localparam DIVIDER_921600 = CLK_FREQ/921600;
  localparam DIVIDER_460800 = CLK_FREQ/460800;
  localparam DIVIDER_230400 = CLK_FREQ/230400;
  localparam DIVIDER_115200 = CLK_FREQ/115200;
  localparam DIVIDER_57600  = CLK_FREQ/57600;
  localparam DIVIDER_38400  = CLK_FREQ/38400;
  localparam DIVIDER_19200  = CLK_FREQ/19200;
  localparam DIVIDER_9600   = CLK_FREQ/9600;

  // Calculate bit width for DIVIDER_9600
  // For CLK_FREQ=100MHz, DIVIDER_9600=10417, clog2(10417)=14
  localparam CLOG2_DIVIDER = 14;

  reg [CLOG2_DIVIDER-1:0] rx_counter;
  reg [CLOG2_DIVIDER-1:0] tx_counter;
  reg [CLOG2_DIVIDER-1:0] target_value;

  always @(posedge clk) begin
    if (!rst_n) begin
      target_value <= DIVIDER_9600;
    end else begin
      case (i_baud_rate)
        3'b000 : target_value <= DIVIDER_9600;
        3'b001 : target_value <= DIVIDER_19200;
        3'b010 : target_value <= DIVIDER_38400;
        3'b011 : target_value <= DIVIDER_57600;
        3'b100 : target_value <= DIVIDER_115200;
        3'b101 : target_value <= DIVIDER_230400;
        3'b110 : target_value <= DIVIDER_460800;
        3'b111 : target_value <= DIVIDER_921600;
        default: target_value <= DIVIDER_9600;
      endcase
    end
  end

  // RX baud generator. We want to generate the strobe in the middle of the bit
  always @(posedge clk) begin
    if (!rst_n) begin
      rx_counter <= DIVIDER_9600;
      o_rx_strb   <= 1'b0;
    end else begin
      o_rx_strb <= 1'b0;
      if (!i_rx_strb_en) begin
        rx_counter <= target_value;
      end else begin
        if (rx_counter == 14'b0) begin
          rx_counter <= target_value;
        end else if (rx_counter == {1'b0, target_value[CLOG2_DIVIDER-1:1]}) begin
          rx_counter <= rx_counter - 1'b1;
          o_rx_strb   <= 1'b1;
        end else begin
          rx_counter <= rx_counter - 1'b1;
        end
      end
    end
  end

  // TX baud generator
  always @(posedge clk) begin
    if (!rst_n) begin
      tx_counter <= DIVIDER_9600;
      o_tx_strb   <= 1'b0;
    end else begin
      o_tx_strb <= 1'b0;
      if (!i_tx_strb_en) begin
        tx_counter <= target_value;
      end else begin
        if (tx_counter == 14'b0) begin
          tx_counter <= target_value;
          o_tx_strb   <= 1'b1;
        end else begin
          tx_counter <= tx_counter - 1'b1;
        end
      end
    end
  end

endmodule
