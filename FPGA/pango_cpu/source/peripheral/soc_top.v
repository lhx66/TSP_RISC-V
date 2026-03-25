`include "../core/defines.v"

module SoC_Top(
    input  wire sys_clk,
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

sys_pll sys_pll_u0 (
  .clkin1(sys_clk),        // input
  .pll_lock(pll_lock),    // output
  .clkout0(clk)       // output
);

    // ====================================================================
    // AXI4-Lite 总线线网声明 (Bus Wires) ... 保持完全不变 ...
    // ====================================================================
    wire [31:0] ls_axi_awaddr;  wire        ls_axi_awvalid; wire        ls_axi_awready;
    wire [31:0] ls_axi_wdata;   wire [3:0]  ls_axi_wstrb;   wire        ls_axi_wvalid;  wire        ls_axi_wready;
    wire [1:0]  ls_axi_bresp;   wire        ls_axi_bvalid;  wire        ls_axi_bready;
    wire [31:0] ls_axi_araddr;  wire        ls_axi_arvalid; wire        ls_axi_arready;
    wire [31:0] ls_axi_rdata;   wire [1:0]  ls_axi_rresp;   wire        ls_axi_rvalid;  wire        ls_axi_rready;

    wire [31:0] m1_axi_awaddr;  wire        m1_axi_awvalid; wire        m1_axi_awready;
    wire [31:0] m1_axi_wdata;   wire [3:0]  m1_axi_wstrb;   wire        m1_axi_wvalid;  wire        m1_axi_wready;
    wire [1:0]  m1_axi_bresp;   wire        m1_axi_bvalid;  wire        m1_axi_bready;
    wire [31:0] m1_axi_araddr;  wire        m1_axi_arvalid; wire        m1_axi_arready;
    wire [31:0] m1_axi_rdata;   wire [1:0]  m1_axi_rresp;   wire        m1_axi_rvalid;  wire        m1_axi_rready;

    wire [31:0] m2_axi_awaddr;  wire        m2_axi_awvalid; wire        m2_axi_awready;
    wire [31:0] m2_axi_wdata;   wire [3:0]  m2_axi_wstrb;   wire        m2_axi_wvalid;  wire        m2_axi_wready;
    wire [1:0]  m2_axi_bresp;   wire        m2_axi_bvalid;  wire        m2_axi_bready;
    wire [31:0] m2_axi_araddr;  wire        m2_axi_arvalid; wire        m2_axi_arready;
    wire [31:0] m2_axi_rdata;   wire [1:0]  m2_axi_rresp;   wire        m2_axi_rvalid;  wire        m2_axi_rready;

    // -------------------------------------------------------------
    // [1] CPU 核心 (TSP_Core) ... 保持不变 ...
    // -------------------------------------------------------------
    TSP_Core u_TSP_Core (
        .clk              (clk),
        .rst_n            (rst_n)
        ,.s_axi_if_awaddr (ext_axi_if_awaddr), .s_axi_if_awvalid(ext_axi_if_awvalid), .s_axi_if_awready(ext_axi_if_awready)
        ,.s_axi_if_wdata  (ext_axi_if_wdata),  .s_axi_if_wstrb  (ext_axi_if_wstrb),   .s_axi_if_wvalid (ext_axi_if_wvalid), .s_axi_if_wready (ext_axi_if_wready)
        ,.s_axi_if_bresp  (ext_axi_if_bresp),  .s_axi_if_bvalid (ext_axi_if_bvalid),  .s_axi_if_bready (ext_axi_if_bready)
        ,.s_axi_if_araddr (ext_axi_if_araddr), .s_axi_if_arvalid(ext_axi_if_arvalid), .s_axi_if_arready(ext_axi_if_arready)
        ,.s_axi_if_rdata  (ext_axi_if_rdata),  .s_axi_if_rresp  (ext_axi_if_rresp),   .s_axi_if_rvalid (ext_axi_if_rvalid), .s_axi_if_rready (ext_axi_if_rready)
        ,.m_axi_ls_awaddr (ls_axi_awaddr), .m_axi_ls_awvalid(ls_axi_awvalid), .m_axi_ls_awready(ls_axi_awready)
        ,.m_axi_ls_wdata  (ls_axi_wdata),  .m_axi_ls_wstrb  (ls_axi_wstrb),   .m_axi_ls_wvalid (ls_axi_wvalid), .m_axi_ls_wready (ls_axi_wready)
        ,.m_axi_ls_bresp  (ls_axi_bresp),  .m_axi_ls_bvalid (ls_axi_bvalid),  .m_axi_ls_bready (ls_axi_bready)
        ,.m_axi_ls_araddr (ls_axi_araddr), .m_axi_ls_arvalid(ls_axi_arvalid), .m_axi_ls_arready(ls_axi_arready)
        ,.m_axi_ls_rdata  (ls_axi_rdata),  .m_axi_ls_rresp  (ls_axi_rresp),   .m_axi_ls_rvalid (ls_axi_rvalid), .m_axi_ls_rready (ls_axi_rready)
    );

    // -------------------------------------------------------------
    // [2] 地址分发器 (AXI Interconnect) ... 保持不变 ...
    // -------------------------------------------------------------
    TSP_AXI_Interconnect u_Interconnect (
        .clk(clk), .rst_n(rst_n),
        .s_axi_awaddr(ls_axi_awaddr), .s_axi_awvalid(ls_axi_awvalid), .s_axi_awready(ls_axi_awready),
        .s_axi_wdata (ls_axi_wdata),  .s_axi_wstrb  (ls_axi_wstrb),   .s_axi_wvalid (ls_axi_wvalid),  .s_axi_wready (ls_axi_wready),
        .s_axi_bresp (ls_axi_bresp),  .s_axi_bvalid (ls_axi_bvalid),  .s_axi_bready (ls_axi_bready),
        .s_axi_araddr(ls_axi_araddr), .s_axi_arvalid(ls_axi_arvalid), .s_axi_arready(ls_axi_arready),
        .s_axi_rdata (ls_axi_rdata),  .s_axi_rresp  (ls_axi_rresp),   .s_axi_rvalid (ls_axi_rvalid),  .s_axi_rready (ls_axi_rready),
        .m1_axi_awaddr(m1_axi_awaddr), .m1_axi_awvalid(m1_axi_awvalid), .m1_axi_awready(m1_axi_awready),
        .m1_axi_wdata (m1_axi_wdata),  .m1_axi_wstrb  (m1_axi_wstrb),   .m1_axi_wvalid (m1_axi_wvalid), .m1_axi_wready (m1_axi_wready),
        .m1_axi_bresp (m1_axi_bresp),  .m1_axi_bvalid (m1_axi_bvalid),  .m1_axi_bready (m1_axi_bready),
        .m1_axi_araddr(m1_axi_araddr), .m1_axi_arvalid(m1_axi_arvalid), .m1_axi_arready(m1_axi_arready),
        .m1_axi_rdata (m1_axi_rdata),  .m1_axi_rresp  (m1_axi_rresp),   .m1_axi_rvalid (m1_axi_rvalid), .m1_axi_rready (m1_axi_rready),
        .m2_axi_awaddr(m2_axi_awaddr), .m2_axi_awvalid(m2_axi_awvalid), .m2_axi_awready(m2_axi_awready),
        .m2_axi_wdata (m2_axi_wdata),  .m2_axi_wstrb  (m2_axi_wstrb),   .m2_axi_wvalid (m2_axi_wvalid), .m2_axi_wready (m2_axi_wready),
        .m2_axi_bresp (m2_axi_bresp),  .m2_axi_bvalid (m2_axi_bvalid),  .m2_axi_bready (m2_axi_bready),
        .m2_axi_araddr(m2_axi_araddr), .m2_axi_arvalid(m2_axi_arvalid), .m2_axi_arready(m2_axi_arready),
        .m2_axi_rdata (m2_axi_rdata),  .m2_axi_rresp  (m2_axi_rresp),   .m2_axi_rvalid (m2_axi_rvalid), .m2_axi_rready (m2_axi_rready)
    );

    // -------------------------------------------------------------
    // [3] 数据内存 (TSP_Sram) ... 保持不变 ...
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
    // [4] UART 串口外设 (替换为包装好的 AXI-Lite Wrapper)
    // -------------------------------------------------------------
    uart_axi_lite_wrapper #(
        .CLK_FREQ_p  (50_000_000), // 这里写你 FPGA 板子的真实主频
        .BAUD_RATE_p (115200)       // 这里写你想要的波特率
    ) u_UART (
        .clk             (clk),
        .rst_n           (rst_n),
        
        // AXI 完整接口对接
        .s_axi_awaddr    (m2_axi_awaddr),
        .s_axi_awvalid   (m2_axi_awvalid),
        .s_axi_awready   (m2_axi_awready),
        .s_axi_wdata     (m2_axi_wdata),
        .s_axi_wstrb     (m2_axi_wstrb),
        .s_axi_wvalid    (m2_axi_wvalid),
        .s_axi_wready    (m2_axi_wready),
        .s_axi_bresp     (m2_axi_bresp),
        .s_axi_bvalid    (m2_axi_bvalid),
        .s_axi_bready    (m2_axi_bready),
        .s_axi_araddr    (m2_axi_araddr),
        .s_axi_arvalid   (m2_axi_arvalid),
        .s_axi_arready   (m2_axi_arready),
        .s_axi_rdata     (m2_axi_rdata),
        .s_axi_rresp     (m2_axi_rresp),
        .s_axi_rvalid    (m2_axi_rvalid),
        .s_axi_rready    (m2_axi_rready),
        
        // 物理引脚
        .rxd             (uart_rx),
        .txd             (uart_tx)
    );

endmodule