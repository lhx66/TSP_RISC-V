`include "../core/defines.v"

module uart_axi_lite_wrapper #(
    parameter CLK_FREQ_p  = 100_000_000,
    parameter BAUD_RATE_p = 115200
)(
    input clk,
    input rst_n,

    // ==========================================
    // AXI4-Lite Slave 接口 (接 Interconnect)
    // ==========================================
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // ==========================================
    // 物理引脚
    // ==========================================
    input  wire rxd,
    output wire txd
);

    // 新 IP 使用高电平复位
    wire rst = ~rst_n; 
    
    // AXI-Stream 信号
    wire [7:0] s_axis_tdata;
    wire       s_axis_tvalid;
    wire       s_axis_tready;
    
    wire [7:0] m_axis_tdata;
    wire       m_axis_tvalid;
    wire       m_axis_tready;
    
    wire tx_busy, rx_busy, rx_overrun_error, rx_frame_error;
    
    // 此 UART IP 的波特率分频计算公式：时钟频率 / (波特率 * 8)
    wire [15:0] prescale = CLK_FREQ_p / (BAUD_RATE_p * 8);

    // 例化新的 UART IP
    uart #(.DATA_WIDTH(8)) u_uart_core (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .rxd(rxd),
        .txd(txd),
        .tx_busy(tx_busy),
        .rx_busy(rx_busy),
        .rx_overrun_error(rx_overrun_error),
        .rx_frame_error(rx_frame_error),
        .prescale(prescale)
    );

    // =========================================================
    // AXI-Lite 转 AXI-Stream 发送 (TX) 逻辑
    // =========================================================
    reg bvalid_r;
    wire aw_w_valid = s_axi_awvalid && s_axi_wvalid;
    
    // 只有当 AXI 发起写请求，且 UART 流通道有空余时，才握手接收
    assign s_axi_awready = aw_w_valid && s_axis_tready && !bvalid_r;
    assign s_axi_wready  = aw_w_valid && s_axis_tready && !bvalid_r;
    
    // 直接把写数据推入流通道
    assign s_axis_tvalid = aw_w_valid && !bvalid_r;
    assign s_axis_tdata  = s_axi_wdata[7:0];
    
    assign s_axi_bvalid  = bvalid_r;
    assign s_axi_bresp   = 2'b00;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) bvalid_r <= 1'b0;
        else begin
            if (s_axi_awready && s_axi_wready) bvalid_r <= 1'b1;
            else if (s_axi_bready && bvalid_r) bvalid_r <= 1'b0;
        end
    end

    // =========================================================
    // AXI-Lite 转 AXI-Stream 接收 (RX) 逻辑
    // =========================================================
    reg arready_r, rvalid_r;
    reg [31:0] rdata_r;
    
    assign s_axi_arready = arready_r;
    assign s_axi_rvalid  = rvalid_r;
    assign s_axi_rdata   = rdata_r;
    assign s_axi_rresp   = 2'b00;
    
    // 读取触发条件
    wire do_read = s_axi_arvalid && !arready_r && !rvalid_r;
    
    // 当 CPU 确认读取地址的那一拍，消耗掉流通道里的一个字节
    assign m_axis_tready = do_read; 
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arready_r <= 1'b0;
            rvalid_r  <= 1'b0;
            rdata_r   <= 32'b0;
        end else begin
            if (do_read) begin
                arready_r <= 1'b1;
                // 【精妙设计】：最高位 bit[31] 存 valid 标志，低 8 位存真实数据。
                // C 语言可通过 `if(data & 0x80000000)` 来判断有没有读到有效字符。
                rdata_r   <= {m_axis_tvalid, 23'd0, m_axis_tdata};
            end else begin
                arready_r <= 1'b0;
            end
            
            if (arready_r) rvalid_r <= 1'b1;
            else if (s_axi_rready && rvalid_r) rvalid_r <= 1'b0;
        end
    end

endmodule
