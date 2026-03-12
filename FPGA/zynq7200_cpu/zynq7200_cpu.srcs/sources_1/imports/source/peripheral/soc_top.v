`include "../core/defines.v"

module SoC_Top(
    input  wire clk,
    input  wire rst_n,

    // 物理世界接口
    input  wire uart_rx,   // 串口接收引脚 (接 FPGA 物理引脚)
    output wire uart_tx,   // 串口发送引脚 (接 FPGA 物理引脚)
    
    // ==========================================
    // 暴露给外部 Testbench/下载器的 IRAM AXI 下载口
    // ==========================================
    input  wire [31:0] ext_axi_if_awaddr, input  wire ext_axi_if_awvalid, output wire ext_axi_if_awready,
    input  wire [31:0] ext_axi_if_wdata,  input  wire [3:0] ext_axi_if_wstrb, input  wire ext_axi_if_wvalid, output wire ext_axi_if_wready,
    output wire [1:0]  ext_axi_if_bresp,  output wire ext_axi_if_bvalid,  input  wire ext_axi_if_bready,
    input  wire [31:0] ext_axi_if_araddr, input  wire ext_axi_if_arvalid, output wire ext_axi_if_arready,
    output wire [31:0] ext_axi_if_rdata,  output wire [1:0] ext_axi_if_rresp, output wire ext_axi_if_rvalid, input  wire ext_axi_if_rready
);

    // ====================================================================
    // AXI4-Lite 总线线网声明 (Bus Wires)
    // ====================================================================
    // 1. CPU LSU 发出的主控总线 (Master)
    wire [31:0] ls_axi_awaddr;  wire        ls_axi_awvalid; wire        ls_axi_awready;
    wire [31:0] ls_axi_wdata;   wire [3:0]  ls_axi_wstrb;   wire        ls_axi_wvalid;  wire        ls_axi_wready;
    wire [1:0]  ls_axi_bresp;   wire        ls_axi_bvalid;  wire        ls_axi_bready;
    wire [31:0] ls_axi_araddr;  wire        ls_axi_arvalid; wire        ls_axi_arready;
    wire [31:0] ls_axi_rdata;   wire [1:0]  ls_axi_rresp;   wire        ls_axi_rvalid;  wire        ls_axi_rready;

    // 2. 路由给 Slave 1: SRAM (用于数据读写, 0x2000_0000)
    wire [31:0] m1_axi_awaddr;  wire        m1_axi_awvalid; wire        m1_axi_awready;
    wire [31:0] m1_axi_wdata;   wire [3:0]  m1_axi_wstrb;   wire        m1_axi_wvalid;  wire        m1_axi_wready;
    wire [1:0]  m1_axi_bresp;   wire        m1_axi_bvalid;  wire        m1_axi_bready;
    wire [31:0] m1_axi_araddr;  wire        m1_axi_arvalid; wire        m1_axi_arready;
    wire [31:0] m1_axi_rdata;   wire [1:0]  m1_axi_rresp;   wire        m1_axi_rvalid;  wire        m1_axi_rready;

    // 3. 路由给 Slave 2: UART (用于串口通信, 0x4000_0000)
    wire [31:0] m2_axi_awaddr;  wire        m2_axi_awvalid; wire        m2_axi_awready;
    wire [31:0] m2_axi_wdata;   wire [3:0]  m2_axi_wstrb;   wire        m2_axi_wvalid;  wire        m2_axi_wready;
    wire [1:0]  m2_axi_bresp;   wire        m2_axi_bvalid;  wire        m2_axi_bready;
    wire [31:0] m2_axi_araddr;  wire        m2_axi_arvalid; wire        m2_axi_arready;
    wire [31:0] m2_axi_rdata;   wire [1:0]  m2_axi_rresp;   wire        m2_axi_rvalid;  wire        m2_axi_rready;

    // ====================================================================
    // 模块例化 (Instances)
    // ====================================================================

    // -------------------------------------------------------------
    // [1] CPU 核心 (TSP_Core)
    // -------------------------------------------------------------
    TSP_Core u_TSP_Core (
        .clk              (clk),
        .rst_n            (rst_n)
        
        // IFU 接口直接连到 SoC_Top 的外部端口
        ,.s_axi_if_awaddr (ext_axi_if_awaddr), .s_axi_if_awvalid(ext_axi_if_awvalid), .s_axi_if_awready(ext_axi_if_awready)
        ,.s_axi_if_wdata  (ext_axi_if_wdata),  .s_axi_if_wstrb  (ext_axi_if_wstrb),   .s_axi_if_wvalid (ext_axi_if_wvalid), .s_axi_if_wready (ext_axi_if_wready)
        ,.s_axi_if_bresp  (ext_axi_if_bresp),  .s_axi_if_bvalid (ext_axi_if_bvalid),  .s_axi_if_bready (ext_axi_if_bready)
        ,.s_axi_if_araddr (ext_axi_if_araddr), .s_axi_if_arvalid(ext_axi_if_arvalid), .s_axi_if_arready(ext_axi_if_arready)
        ,.s_axi_if_rdata  (ext_axi_if_rdata),  .s_axi_if_rresp  (ext_axi_if_rresp),   .s_axi_if_rvalid (ext_axi_if_rvalid), .s_axi_if_rready (ext_axi_if_rready)

        // LSU 作为 Master 发起寻址
        ,.m_axi_ls_awaddr (ls_axi_awaddr), .m_axi_ls_awvalid(ls_axi_awvalid), .m_axi_ls_awready(ls_axi_awready)
        ,.m_axi_ls_wdata  (ls_axi_wdata),  .m_axi_ls_wstrb  (ls_axi_wstrb),   .m_axi_ls_wvalid (ls_axi_wvalid), .m_axi_ls_wready (ls_axi_wready)
        ,.m_axi_ls_bresp  (ls_axi_bresp),  .m_axi_ls_bvalid (ls_axi_bvalid),  .m_axi_ls_bready (ls_axi_bready)
        ,.m_axi_ls_araddr (ls_axi_araddr), .m_axi_ls_arvalid(ls_axi_arvalid), .m_axi_ls_arready(ls_axi_arready)
        ,.m_axi_ls_rdata  (ls_axi_rdata),  .m_axi_ls_rresp  (ls_axi_rresp),   .m_axi_ls_rvalid (ls_axi_rvalid), .m_axi_ls_rready (ls_axi_rready)
    );

    // -------------------------------------------------------------
    // [2] 地址分发器 (AXI Interconnect) - 注意：你需要修改这个模块去掉 m0 端口
    // -------------------------------------------------------------
    TSP_AXI_Interconnect u_Interconnect (
        .clk(clk), .rst_n(rst_n),
        
        // Master 输入 (CPU LSU)
        .s_axi_awaddr(ls_axi_awaddr), .s_axi_awvalid(ls_axi_awvalid), .s_axi_awready(ls_axi_awready),
        .s_axi_wdata (ls_axi_wdata),  .s_axi_wstrb  (ls_axi_wstrb),   .s_axi_wvalid (ls_axi_wvalid),  .s_axi_wready (ls_axi_wready),
        .s_axi_bresp (ls_axi_bresp),  .s_axi_bvalid (ls_axi_bvalid),  .s_axi_bready (ls_axi_bready),
        .s_axi_araddr(ls_axi_araddr), .s_axi_arvalid(ls_axi_arvalid), .s_axi_arready(ls_axi_arready),
        .s_axi_rdata (ls_axi_rdata),  .s_axi_rresp  (ls_axi_rresp),   .s_axi_rvalid (ls_axi_rvalid),  .s_axi_rready (ls_axi_rready),

        // Slave 1 输出 (SRAM) - 接原先的 m1 端口
        .m1_axi_awaddr(m1_axi_awaddr), .m1_axi_awvalid(m1_axi_awvalid), .m1_axi_awready(m1_axi_awready),
        .m1_axi_wdata (m1_axi_wdata),  .m1_axi_wstrb  (m1_axi_wstrb),   .m1_axi_wvalid (m1_axi_wvalid), .m1_axi_wready (m1_axi_wready),
        .m1_axi_bresp (m1_axi_bresp),  .m1_axi_bvalid (m1_axi_bvalid),  .m1_axi_bready (m1_axi_bready),
        .m1_axi_araddr(m1_axi_araddr), .m1_axi_arvalid(m1_axi_arvalid), .m1_axi_arready(m1_axi_arready),
        .m1_axi_rdata (m1_axi_rdata),  .m1_axi_rresp  (m1_axi_rresp),   .m1_axi_rvalid (m1_axi_rvalid), .m1_axi_rready (m1_axi_rready),

        // Slave 2 输出 (UART) - 接原先的 m2 端口
        .m2_axi_awaddr(m2_axi_awaddr), .m2_axi_awvalid(m2_axi_awvalid), .m2_axi_awready(m2_axi_awready),
        .m2_axi_wdata (m2_axi_wdata),  .m2_axi_wstrb  (m2_axi_wstrb),   .m2_axi_wvalid (m2_axi_wvalid), .m2_axi_wready (m2_axi_wready),
        .m2_axi_bresp (m2_axi_bresp),  .m2_axi_bvalid (m2_axi_bvalid),  .m2_axi_bready (m2_axi_bready),
        .m2_axi_araddr(m2_axi_araddr), .m2_axi_arvalid(m2_axi_arvalid), .m2_axi_arready(m2_axi_arready),
        .m2_axi_rdata (m2_axi_rdata),  .m2_axi_rresp  (m2_axi_rresp),   .m2_axi_rvalid (m2_axi_rvalid), .m2_axi_rready (m2_axi_rready)
    );

    // -------------------------------------------------------------
    // [3] 数据内存 (TSP_Sram)
    // -------------------------------------------------------------
    TSP_Sram u_SRAM (
        .clk(clk), .rst_n(rst_n),
        .s_axi_awaddr (m1_axi_awaddr), .s_axi_awvalid(m1_axi_awvalid), .s_axi_awready(m1_axi_awready),
        .s_axi_wdata  (m1_axi_wdata),  .s_axi_wstrb  (m1_axi_wstrb),   .s_axi_wvalid (m1_axi_wvalid),  .s_axi_wready (m1_axi_wready),
        .s_axi_bresp  (m1_axi_bresp),  .s_axi_bvalid (m1_axi_bvalid),  .s_axi_bready (m1_axi_bready),
        .s_axi_araddr (m1_axi_araddr), .s_axi_arvalid(m1_axi_arvalid), .s_axi_arready(m1_axi_arready),
        .s_axi_rdata  (m1_axi_rdata),  .s_axi_rresp  (m1_axi_rresp),   .s_axi_rvalid (m1_axi_rvalid),  .s_axi_rready (m1_axi_rready)
    );

    // -------------------------------------------------------------
    // [4] UART 串口外设 (uart_top)
    // -------------------------------------------------------------
    // 注：此 IP 的地址位宽为 12 位，且不使用 wstrb (默认写全字)
    wire uart_irq; // 暂时悬空不处理中断

    uart_top #(
        .CLK_FREQ_p        (100_000_000), // 假设系统时钟为 100MHz (根据实际情况修改)
        .UART_FIFO_DEPTH_p (16),
        .AXI_ADDR_BW_p     (12)
    ) u_UART (
        .clk           (clk),
        .rst_n         (rst_n),
        
        // AXI 截断处理：只把 32 位地址的低 12 位传给外设
        .i_axi_awaddr  (m2_axi_awaddr[11:0]),
        .i_axi_awvalid (m2_axi_awvalid),
        .i_axi_wdata   (m2_axi_wdata),
        .i_axi_wvalid  (m2_axi_wvalid),
        .i_axi_bready  (m2_axi_bready),
        .i_axi_araddr  (m2_axi_araddr[11:0]),
        .i_axi_arvalid (m2_axi_arvalid),
        .i_axi_rready  (m2_axi_rready),
        
        .o_axi_awready (m2_axi_awready),
        .o_axi_wready  (m2_axi_wready),
        .o_axi_bresp   (m2_axi_bresp),
        .o_axi_bvalid  (m2_axi_bvalid),
        .o_axi_arready (m2_axi_arready),
        .o_axi_rdata   (m2_axi_rdata),
        .o_axi_rresp   (m2_axi_rresp),
        .o_axi_rvalid  (m2_axi_rvalid),
        
        // 物理引脚
        .i_uart_rx     (uart_rx),
        .o_uart_tx     (uart_tx),
        .o_irq         (uart_irq)
    );

endmodule