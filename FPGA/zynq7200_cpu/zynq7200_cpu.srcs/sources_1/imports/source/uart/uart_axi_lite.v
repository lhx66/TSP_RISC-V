module uart_axi_lite #(
  parameter AXI_ADDR_BW_p = 12    // 4k boundary by default
) (
  // Clock and reset
  input  wire                 clk,
  input  wire                 rst_n,
  // AXI related signals
  input  wire [AXI_ADDR_BW_p-1:0] i_axi_awaddr,
  input  wire                 i_axi_awvalid,
  input  wire [31:0]          i_axi_wdata,
  input  wire                 i_axi_wvalid,
  input  wire                 i_axi_bready,
  input  wire [AXI_ADDR_BW_p-1:0] i_axi_araddr,
  input  wire                 i_axi_arvalid,
  input  wire                 i_axi_rready,
  output wire                 o_axi_awready,
  output wire                 o_axi_wready,
  output wire [1:0]           o_axi_bresp,
  output wire                 o_axi_bvalid,
  output wire                 o_axi_arready,
  output wire [31:0]          o_axi_rdata,
  output wire [1:0]           o_axi_rresp,
  output wire                 o_axi_rvalid,

  // Inputs/outputs from RX/TX
  input  wire                 i_rx_parity_error,
  input  wire                 i_rx_frame_error,
  input  wire                 i_tx_overflow_error,
  input  wire                 i_rx_overflow_error,
  input  wire                 i_rx_underflow_error,
  input  wire                 i_rx_threshold,
  input  wire                 i_rx_fifo_empty,
  input  wire                 i_rx_fifo_full,
  input  wire                 i_tx_threshold,
  input  wire                 i_tx_fifo_full,
  input  wire                 i_tx_fifo_empty,
  input  wire [7:0]           i_rx_fifo_data,
  output wire                 o_rx_fifo_rd_en,
  output wire                 o_tx_fifo_wr_en,
  output wire [7:0]           o_tx_fifo_data,

  // UART configuration
  output wire [2:0]           o_rx_threshold_value,
  output wire [2:0]           o_tx_threshold_value,
  output wire                 o_clr_tx_fifo,
  output wire                 o_clr_rx_fifo,
  output wire [2:0]           o_baud_rate,
  output wire [1:0]           o_data_bits,
  output wire                 o_parity,
  output wire                 o_use_parity,
  output wire                 o_stop_bits,

  // Interrupts
  output wire                 o_irq
);

  localparam [1:0] RESP_OKAY   = 2'b00;
  localparam [1:0] RESP_EXOKAY = 2'b01;
  localparam [1:0] RESP_SLVERR = 2'b10;
  localparam [1:0] RESP_DECERR = 2'b11;

  // --------------------------------------------------------------
  // Status register related logic
  // --------------------------------------------------------------
  reg [10:0] s_status_reg;
  reg        s_parity_error_clear;
  reg        s_frame_error_clear;
  reg        s_overflow_error_clear;
  reg        s_tx_overflow_error_clear;
  reg        s_underflow_error_clear;

  always @(posedge clk) begin
    if (!rst_n) begin
      s_status_reg <= 11'b0;
    end else begin
      s_status_reg[10] <= (s_status_reg[10] | i_rx_parity_error) & !s_parity_error_clear;
      s_status_reg[9]  <= (s_status_reg[9] | i_rx_frame_error) & !s_frame_error_clear;
      s_status_reg[8]  <= (s_status_reg[8] | i_tx_overflow_error) & !s_tx_overflow_error_clear;
      s_status_reg[7]  <= i_tx_fifo_full;
      s_status_reg[6]  <= i_tx_threshold;
      s_status_reg[5]  <= i_tx_fifo_empty;
      s_status_reg[4]  <= (s_status_reg[4] | i_rx_underflow_error) & !s_underflow_error_clear;
      s_status_reg[3]  <= (s_status_reg[3] | i_rx_overflow_error) & !s_overflow_error_clear;
      s_status_reg[2]  <= i_rx_fifo_full;
      s_status_reg[1]  <= i_rx_threshold;
      s_status_reg[0]  <= i_rx_fifo_empty;
    end
  end

  // --------------------------------------------------------------
  // Interrupt related logic
  // --------------------------------------------------------------
  reg           s_irq;
  reg [11:0]    s_interrupt_enable_reg;

  assign o_irq = s_irq;

  always @(posedge clk) begin
    if (!rst_n) begin
      s_irq <= 1'b0;
    end else begin
      s_irq <= (|(s_interrupt_enable_reg[10:0] & s_status_reg)) & s_interrupt_enable_reg[11];
    end
  end

  // --------------------------------------------------------------
  // FIFO clear
  // --------------------------------------------------------------
  reg s_clear_rx_fifo;
  reg s_clear_tx_fifo;

  assign o_clr_rx_fifo = s_clear_rx_fifo;
  assign o_clr_tx_fifo = s_clear_tx_fifo;

  // --------------------------------------------------------------
  // UART configuration
  // --------------------------------------------------------------
  reg [2:0] s_tx_threshold_value;
  reg [2:0] s_rx_threshold_value;
  reg [2:0] s_baud_rate;
  reg       s_stop_bits;
  reg       s_parity;
  reg       s_use_parity;
  reg [1:0] s_data_bits;

  assign o_rx_threshold_value = s_rx_threshold_value;
  assign o_tx_threshold_value = s_tx_threshold_value;
  assign o_baud_rate  = s_baud_rate;
  assign o_stop_bits  = s_stop_bits;
  assign o_use_parity = s_use_parity;
  assign o_parity     = s_parity;
  assign o_data_bits  = s_data_bits;

  // --------------------------------------------------------------
  // UART (FIFO) data
  // --------------------------------------------------------------
  reg        s_tx_fifo_wr_en;
  reg        s_rx_fifo_rd_en;
  reg [7:0]  s_tx_fifo_data;

  assign o_tx_fifo_wr_en = s_tx_fifo_wr_en;
  assign o_tx_fifo_data  = s_tx_fifo_data;
  assign o_rx_fifo_rd_en = s_rx_fifo_rd_en;

  // --------------------------------------------------------------
  // Write address, write data and write wresponse
  // --------------------------------------------------------------
  reg                        s_axi_bvalid;
  reg [1:0]                  s_axi_bresp;
  reg [AXI_ADDR_BW_p-1:0]    s_axi_awaddr_buf;
  reg                        s_axi_awaddr_buf_used;
  reg                        s_axi_awvalid;
  reg                        s_axi_wvalid;
  reg                        s_axi_wdata_buf_used;
  reg [31:0]                 s_axi_wdata_buf;
  wire [AXI_ADDR_BW_p-1:0]   c_axi_awaddr;
  wire [31:0]                 c_axi_wdata;
  wire                       write_response_stalled;
  wire                       valid_write_address;
  wire                       valid_write_data;
  reg                        s_axi_awready;
  reg                        s_axi_wready;

  // We want to stall the address write if either we received write request without write data
  // or if the write address buffer is full and master is stalling write response channel
  assign o_axi_awready = !s_axi_awaddr_buf_used & s_axi_awvalid;

  // We want to stall the data write if either we received write data without a write request
  // or if the write data buffer is full and master is stalling write response channel
  assign o_axi_wready  = !s_axi_wdata_buf_used & s_axi_wvalid;

  assign write_response_stalled = o_axi_bvalid & ~i_axi_bready;
  assign valid_write_address = s_axi_awaddr_buf_used | (i_axi_awvalid & o_axi_awready);
  assign valid_write_data = s_axi_wdata_buf_used | (i_axi_wvalid & o_axi_wready);

  always @(posedge clk) begin
    if (!rst_n) begin
      s_axi_awvalid <= 1'b0;
      s_axi_awaddr_buf_used <= 1'b0;
    end else begin
      s_axi_awvalid <= 1'b1;
      // When master is stalling on the response channel or if we didn't receive
      // write data, we need to buffer the address
      if (i_axi_awvalid && o_axi_awready && (write_response_stalled || !valid_write_data)) begin
        s_axi_awaddr_buf <= i_axi_awaddr;
        s_axi_awaddr_buf_used <= 1'b1;
      end else if (s_axi_awaddr_buf_used && valid_write_data && (!o_axi_bvalid || i_axi_bready)) begin
        s_axi_awaddr_buf_used <= 1'b0;
      end
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      s_axi_wdata_buf_used <= 1'b0;
      s_axi_wvalid <= 1'b0;
    end else begin
      s_axi_wvalid <= 1'b1;
      // We want to fill the buffer if either we're getting a response stall, or we
      // get a write data without a write address
      if (i_axi_wvalid && o_axi_wready && (write_response_stalled || !valid_write_address)) begin
        s_axi_wdata_buf <= i_axi_wdata;
        s_axi_wdata_buf_used <= 1'b1;
      end else if (s_axi_wdata_buf_used && valid_write_address && (!o_axi_bvalid || i_axi_bready)) begin
        s_axi_wdata_buf_used <= 1'b0;
      end
    end
  end

  // Muxes to select write address and write data either from the buffer or from the AXI bus
  assign c_axi_awaddr = s_axi_awaddr_buf_used ? s_axi_awaddr_buf : i_axi_awaddr;
  assign c_axi_wdata  = s_axi_wdata_buf_used  ? s_axi_wdata_buf  : i_axi_wdata;

  // Store write data to the correct register and generate a response
  always @(posedge clk) begin
    if (!rst_n) begin
      s_axi_bvalid <= 1'b0;
      s_interrupt_enable_reg <= 12'b0;
      s_clear_rx_fifo <= 1'b0;
      s_clear_tx_fifo <= 1'b0;
      s_tx_threshold_value <= 3'h0;
      s_rx_threshold_value <= 3'h7;
      s_baud_rate <= 3'h4;
      s_stop_bits <= 1'b0;
      s_parity <= 1'b0;
      s_data_bits <= 2'h3;
      s_tx_fifo_wr_en <= 1'b0;
      s_use_parity <= 1'b0;
    end else begin
      s_tx_fifo_wr_en <= 1'b0;
      s_clear_rx_fifo <= 1'b0;
      s_clear_tx_fifo <= 1'b0;
      // If there is write address and write data in the buffer
      if (valid_write_address && valid_write_data && (!o_axi_bvalid || i_axi_bready)) begin
        s_axi_bvalid <= 1'b1;
        s_axi_bresp <= RESP_SLVERR;

        case (c_axi_awaddr[4:2])
          3'd1 : begin // INTERRUPT_ENABLE register, RW
            s_interrupt_enable_reg <= c_axi_wdata[11:0];
            s_axi_bresp <= RESP_OKAY;
          end

          3'd2 : begin // CONFIG register, RW
            s_tx_threshold_value <= c_axi_wdata[14:12];
            s_rx_threshold_value <= c_axi_wdata[11:9];
            s_baud_rate <= c_axi_wdata[7:5];
            s_stop_bits <= c_axi_wdata[4];
            s_parity <= c_axi_wdata[3];
            s_use_parity <= c_axi_wdata[2];
            s_data_bits <= c_axi_wdata[1:0];
            s_axi_bresp <= RESP_OKAY;
          end

          3'd3 : begin // FIFO_CLEAR register, WO
            s_clear_rx_fifo <= c_axi_wdata[1];
            s_clear_tx_fifo <= c_axi_wdata[0];
            s_axi_bresp <= RESP_OKAY;
          end

          3'd5 : begin // TX_FIFO, WO
            s_tx_fifo_data <= c_axi_wdata[7:0];
            s_tx_fifo_wr_en <= 1'b1;
            s_axi_bresp <= RESP_OKAY;
          end

          default: begin
            s_axi_bresp <= RESP_SLVERR;
          end
        endcase
      end else if (o_axi_bvalid && i_axi_bready && !(valid_write_address && valid_write_data)) begin
        s_axi_bvalid <= 1'b0;
      end
    end
  end

  // Assign intermediate signals to outputs
  assign o_axi_bresp = s_axi_bresp;

  // --------------------------------------------------------------
  // Read address and read response
  // --------------------------------------------------------------
  reg                         s_axi_rvalid;
  reg [31:0]                  s_axi_rdata;
  reg [1:0]                   s_axi_rresp;
  reg                         s_axi_arready;
  reg [AXI_ADDR_BW_p-1:0]     s_araddr_buf;
  reg                         s_araddr_buf_used;
  wire [AXI_ADDR_BW_p-1:0]    c_axi_araddr;

  // Address buffer management
  always @(posedge clk) begin
    if (!rst_n) begin
      s_araddr_buf_used <= 1'b0;
      s_axi_arready <= 1'b0;
    end else begin
      s_axi_arready <= 1'b1;

      // Fill buffer when response is stalled
      if (i_axi_arvalid && o_axi_arready && o_axi_rvalid && !i_axi_rready) begin
        s_araddr_buf <= i_axi_araddr;
        s_araddr_buf_used <= 1'b1;
      end
      // Clear buffer when address is consumed
      else if (s_araddr_buf_used && (!o_axi_rvalid || i_axi_rready)) begin
        s_araddr_buf_used <= 1'b0;
      end
    end
  end

  // Mux to select address
  assign c_axi_araddr = s_araddr_buf_used ? s_araddr_buf : i_axi_araddr;

  // Ready signal blocks when buffer full
  assign o_axi_arready = !s_araddr_buf_used & s_axi_arready;

  // Response generation
  always @(posedge clk) begin
    if (!rst_n) begin
      s_axi_rvalid <= 1'b0;
      s_parity_error_clear <= 1'b0;
      s_frame_error_clear <= 1'b0;
      s_overflow_error_clear <= 1'b0;
      s_rx_fifo_rd_en <= 1'b0;
      s_tx_overflow_error_clear <= 1'b0;
      s_underflow_error_clear <= 1'b0;
    end else begin
      s_parity_error_clear <= 1'b0;
      s_frame_error_clear <= 1'b0;
      s_overflow_error_clear <= 1'b0;
      s_rx_fifo_rd_en <= 1'b0;
      s_tx_overflow_error_clear <= 1'b0;
      s_underflow_error_clear <= 1'b0;

      // Generate response when address is available (buffer or direct)
      if ((s_araddr_buf_used || (i_axi_arvalid && o_axi_arready)) && (!o_axi_rvalid || i_axi_rready)) begin
        s_axi_rresp <= RESP_SLVERR;
        s_axi_rvalid <= 1'b1;
        s_axi_rdata <= 32'b0;

        case (c_axi_araddr[5:2])
          3'd0 : begin
            s_axi_rdata <= 32'b0;
            s_axi_rresp <= RESP_OKAY;
            s_parity_error_clear <= 1'b1;
            s_frame_error_clear <= 1'b1;
            s_overflow_error_clear <= 1'b1;
            s_tx_overflow_error_clear <= 1'b1;
            s_underflow_error_clear <= 1'b1;
            s_axi_rdata[10:0] <= s_status_reg;
          end

          3'd1 : begin
            s_axi_rdata <= 32'b0;
            s_axi_rresp <= RESP_OKAY;
            s_axi_rdata[11:0] <= s_interrupt_enable_reg;
          end

          3'd2 : begin
            s_axi_rdata <= 32'b0;
            s_axi_rresp <= RESP_OKAY;
            s_axi_rdata[14:12] <= s_tx_threshold_value;
            s_axi_rdata[11:9] <= s_rx_threshold_value;
            s_axi_rdata[7:5] <= s_baud_rate;
            s_axi_rdata[4] <= s_stop_bits;
            s_axi_rdata[3] <= s_parity;
            s_axi_rdata[2] <= s_use_parity;
            s_axi_rdata[1:0] <= s_data_bits;
          end

          3'd4 : begin
            s_axi_rdata <= 32'b0;
            s_axi_rresp <= RESP_OKAY;
            // We can do this because we're using FWFT FIFO
            s_axi_rdata[7:0] <= i_rx_fifo_data;
            s_rx_fifo_rd_en <= 1'b1;
          end

          default: begin
            s_axi_rresp <= RESP_SLVERR;
          end
        endcase
      // Clear response when handshake completes and no new transaction
      end else if (o_axi_rvalid && i_axi_rready && !s_araddr_buf_used && !(i_axi_arvalid && o_axi_arready)) begin
        s_axi_rvalid <= 1'b0;
      end
    end
  end

  assign o_axi_rdata  = s_axi_rdata;
  assign o_axi_rresp  = s_axi_rresp;
  assign o_axi_rvalid = s_axi_rvalid;
  assign o_axi_bvalid = s_axi_bvalid;

endmodule
