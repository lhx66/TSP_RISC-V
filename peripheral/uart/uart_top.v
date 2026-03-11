module uart_top #(
  parameter CLK_FREQ_p        = 100000000,
  parameter UART_FIFO_DEPTH_p = 16,
  parameter AXI_ADDR_BW_p     = 12
) (
  // Clock and reset
  input  wire                     clk,
  input  wire                     rst_n,
  // AXI4-Lite (Write strobes are not used, it's assumed they're all asserted)
  input  wire [AXI_ADDR_BW_p-1:0] i_axi_awaddr,
  input  wire                     i_axi_awvalid,
  input  wire [31:0]              i_axi_wdata,
  input  wire                     i_axi_wvalid,
  input  wire                     i_axi_bready,
  input  wire [AXI_ADDR_BW_p-1:0] i_axi_araddr,
  input  wire                     i_axi_arvalid,
  input  wire                     i_axi_rready,
  output wire                     o_axi_awready,
  output wire                     o_axi_wready,
  output wire [1:0]               o_axi_bresp,
  output wire                     o_axi_bvalid,
  output wire                     o_axi_arready,
  output wire [31:0]              o_axi_rdata,
  output wire [1:0]               o_axi_rresp,
  output wire                     o_axi_rvalid,
  // UART signals
  input  wire                     i_uart_rx,
  output wire                     o_uart_tx,
  // Interrupt
  output wire                     o_irq
);

  // Inputs/outputs from RX/TX
  wire        s_rx_parity_error;
  wire        s_rx_frame_error;
  wire        s_rx_overflow_error;
  wire        s_rx_underflow_error;
  wire        s_tx_overflow_error;
  wire        s_rx_fifo_empty;
  wire        s_rx_fifo_full;
  wire        s_tx_fifo_full;
  wire        s_tx_fifo_empty;
  wire [7:0]  s_rx_fifo_data;
  wire        s_rx_fifo_rd_en;
  wire        s_tx_fifo_wr_en;
  wire [7:0]  s_tx_fifo_data;
  // UART configuration
  wire        s_clr_tx_fifo;
  wire        s_clr_rx_fifo;
  wire [2:0]  s_baud_rate;
  wire [1:0]  s_data_bits;
  wire        s_parity;
  wire        s_use_parity;
  wire        s_stop_bits;
  wire [2:0]  s_rx_threshold_value;
  wire [2:0]  s_tx_threshold_value;
  wire        s_rx_threshold;
  wire        s_tx_threshold;
  // Baudgen signals
  wire        s_rx_strb_en;
  wire        s_tx_strb_en;
  wire        s_tx_strb;
  wire        s_rx_strb;

  uart_tx #(
    .FIFO_DEPTH(UART_FIFO_DEPTH_p)
  ) uart_tx_inst (
    .clk               (clk                  ),
    .rst_n             (rst_n                ),
    .i_use_parity      (s_use_parity         ),
    .i_parity          (s_parity             ),
    .i_data_bits       (s_data_bits          ),
    .i_stop_bits       (s_stop_bits          ),
    .i_fifo_wr_en      (s_tx_fifo_wr_en      ),
    .i_fifo_wr_data    (s_tx_fifo_data       ),
    .i_fifo_clear      (s_clr_tx_fifo        ),
    .i_threshold_value (s_tx_threshold_value ),
    .o_fifo_full       (s_tx_fifo_full       ),
    .o_fifo_empty      (s_tx_fifo_empty      ),
    .o_overflow_error  (s_tx_overflow_error  ),
    .o_threshold       (s_tx_threshold       ),
    .i_tx_strb         (s_tx_strb            ),
    .o_tx_strb_en      (s_tx_strb_en         ),
    .o_uart_tx         (o_uart_tx            )
  );

  uart_rx #(
    .FIFO_DEPTH(UART_FIFO_DEPTH_p)
  ) uart_rx_inst (
    .clk               (clk                  ),
    .rst_n             (rst_n                ),
    .i_use_parity      (s_use_parity         ),
    .i_parity          (s_parity             ),
    .i_data_bits       (s_data_bits          ),
    .i_stop_bits       (s_stop_bits          ),
    .i_fifo_clear      (s_clr_rx_fifo        ),
    .i_fifo_rd_en      (s_rx_fifo_rd_en      ),
    .i_threshold_value (s_rx_threshold_value ),
    .o_fifo_rd_data    (s_rx_fifo_data       ),
    .o_fifo_full       (s_rx_fifo_full       ),
    .o_fifo_empty      (s_rx_fifo_empty      ),
    .i_rx_strb         (s_rx_strb            ),
    .o_rx_strb_en      (s_rx_strb_en         ),
    .o_threshold       (s_rx_threshold       ),
    .i_uart_rx         (i_uart_rx            ),
    .o_parity_error    (s_rx_parity_error    ),
    .o_frame_error     (s_rx_frame_error     ),
    .o_overflow_error  (s_rx_overflow_error  ),
    .o_underflow_error (s_rx_underflow_error )
  );

  uart_baudgen #(
    .CLK_FREQ(CLK_FREQ_p)
  ) uart_baudgen_inst (
    .clk          (clk           ),
    .rst_n        (rst_n         ),
    .i_rx_strb_en (s_rx_strb_en  ),
    .i_tx_strb_en (s_tx_strb_en  ),
    .i_baud_rate  (s_baud_rate   ),
    .o_tx_strb    (s_tx_strb     ),
    .o_rx_strb    (s_rx_strb     )
  );

  uart_axi_lite #(
    .AXI_ADDR_BW_p(AXI_ADDR_BW_p)
  ) uart_axi_lite_inst (
    .clk                  (clk                   ),
    .rst_n                (rst_n                 ),
    .i_axi_awaddr         (i_axi_awaddr          ),
    .i_axi_awvalid        (i_axi_awvalid         ),
    .i_axi_wdata          (i_axi_wdata           ),
    .i_axi_wvalid         (i_axi_wvalid          ),
    .i_axi_bready         (i_axi_bready          ),
    .i_axi_araddr         (i_axi_araddr          ),
    .i_axi_arvalid        (i_axi_arvalid         ),
    .i_axi_rready         (i_axi_rready          ),
    .o_axi_awready        (o_axi_awready         ),
    .o_axi_wready         (o_axi_wready          ),
    .o_axi_bresp          (o_axi_bresp           ),
    .o_axi_bvalid         (o_axi_bvalid          ),
    .o_axi_arready        (o_axi_arready         ),
    .o_axi_rdata          (o_axi_rdata           ),
    .o_axi_rresp          (o_axi_rresp           ),
    .o_axi_rvalid         (o_axi_rvalid          ),
    .i_rx_parity_error    (s_rx_parity_error     ),
    .i_rx_frame_error     (s_rx_frame_error      ),
    .i_rx_overflow_error  (s_rx_overflow_error   ),
    .i_rx_underflow_error (s_rx_underflow_error  ),
    .i_rx_threshold       (s_rx_threshold        ),
    .i_tx_overflow_error  (s_tx_overflow_error   ),
    .i_rx_fifo_empty      (s_rx_fifo_empty       ),
    .i_rx_fifo_full       (s_rx_fifo_full        ),
    .i_tx_fifo_full       (s_tx_fifo_full        ),
    .i_tx_fifo_empty      (s_tx_fifo_empty       ),
    .i_tx_threshold       (s_tx_threshold        ),
    .i_rx_fifo_data       (s_rx_fifo_data        ),
    .o_rx_fifo_rd_en      (s_rx_fifo_rd_en       ),
    .o_tx_fifo_wr_en      (s_tx_fifo_wr_en       ),
    .o_tx_fifo_data       (s_tx_fifo_data        ),
    .o_clr_tx_fifo        (s_clr_tx_fifo         ),
    .o_clr_rx_fifo        (s_clr_rx_fifo         ),
    .o_baud_rate          (s_baud_rate           ),
    .o_data_bits          (s_data_bits           ),
    .o_parity             (s_parity              ),
    .o_use_parity         (s_use_parity          ),
    .o_stop_bits          (s_stop_bits           ),
    .o_tx_threshold_value (s_tx_threshold_value  ),
    .o_rx_threshold_value (s_rx_threshold_value  ),
    .o_irq                (o_irq                 )
  );

endmodule
