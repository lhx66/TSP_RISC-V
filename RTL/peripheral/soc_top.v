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
    input  wire [31:0] ext_axi_if_wdata,  input  wire [3:0]  ext_axi_if_wstrb, input  wire ext_axi_if_wvalid, output wire ext_axi_if_wready,
    output wire [1:0]  ext_axi_if_bresp,  output wire ext_axi_if_bvalid,  input  wire ext_axi_if_bready,
    input  wire [31:0] ext_axi_if_araddr, input  wire ext_axi_if_arvalid, output wire ext_axi_if_arready,
    output wire [31:0] ext_axi_if_rdata,  output wire [1:0]  ext_axi_if_rresp, output wire ext_axi_if_rvalid, input  wire ext_axi_if_rready
);



    // ====================================================================
    // AXI4-Lite 总线线网声明 (Bus Wires)
    // ====================================================================
    // Master 1: LSU 到 Interconnect
    wire [31:0] ls_axi_awaddr;  wire        ls_axi_awvalid; wire        ls_axi_awready;
    wire [31:0] ls_axi_wdata;   wire [3:0]  ls_axi_wstrb;   wire        ls_axi_wvalid;  wire        ls_axi_wready;
    wire [1:0]  ls_axi_bresp;   wire        ls_axi_bvalid;  wire        ls_axi_bready;
    wire [31:0] ls_axi_araddr;  wire        ls_axi_arvalid; wire        ls_axi_arready;
    wire [31:0] ls_axi_rdata;   wire [1:0]  ls_axi_rresp;   wire        ls_axi_rvalid;  wire        ls_axi_rready;

    // Slave 1: Interconnect 到 SRAM
    wire [31:0] m1_axi_awaddr;  wire        m1_axi_awvalid; wire        m1_axi_awready;
    wire [31:0] m1_axi_wdata;   wire [3:0]  m1_axi_wstrb;   wire        m1_axi_wvalid;  wire        m1_axi_wready;
    wire [1:0]  m1_axi_bresp;   wire        m1_axi_bvalid;  wire        m1_axi_bready;
    wire [31:0] m1_axi_araddr;  wire        m1_axi_arvalid; wire        m1_axi_arready;
    wire [31:0] m1_axi_rdata;   wire [1:0]  m1_axi_rresp;   wire        m1_axi_rvalid;  wire        m1_axi_rready;

    // Slave 2: Interconnect 到 UART
    wire [31:0] m2_axi_awaddr;  wire        m2_axi_awvalid; wire        m2_axi_awready;
    wire [31:0] m2_axi_wdata;   wire [3:0]  m2_axi_wstrb;   wire        m2_axi_wvalid;  wire        m2_axi_wready;
    wire [1:0]  m2_axi_bresp;   wire        m2_axi_bvalid;  wire        m2_axi_bready;
    wire [31:0] m2_axi_araddr;  wire        m2_axi_arvalid; wire        m2_axi_arready;
    wire [31:0] m2_axi_rdata;   wire [1:0]  m2_axi_rresp;   wire        m2_axi_rvalid;  wire        m2_axi_rready;

    // Slave 3: Interconnect 到 IRAM (新增的访存通道)
    wire [31:0] m3_axi_awaddr;  wire        m3_axi_awvalid; wire        m3_axi_awready;
    wire [31:0] m3_axi_wdata;   wire [3:0]  m3_axi_wstrb;   wire        m3_axi_wvalid;  wire        m3_axi_wready;
    wire [1:0]  m3_axi_bresp;   wire        m3_axi_bvalid;  wire        m3_axi_bready;
    wire [31:0] m3_axi_araddr;  wire        m3_axi_arvalid; wire        m3_axi_arready;
    wire [31:0] m3_axi_rdata;   wire [1:0]  m3_axi_rresp;   wire        m3_axi_rvalid;  wire        m3_axi_rready;


    // 【调试修改】：强制设为 0，屏蔽悬空引脚的干扰，把总线 100% 交给内部 CPU
    wire sel_ext_w = 1'b0; 
    wire sel_ext_r = 1'b0;
    /*// ====================================================================
    // 新增简易 AXI 仲裁器 (MUX)，优先调度外部下载器 / LSU m3 通道
    // ====================================================================
    reg sel_ext_w, sel_ext_r;
    
    // 写通道优先级判断
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sel_ext_w <= 1'b0;
        else if (ext_axi_if_awvalid) sel_ext_w <= 1'b1;
        else if (m3_axi_awvalid) sel_ext_w <= 1'b0;
    end
    
    // 读通道优先级判断
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sel_ext_r <= 1'b0;
        else if (ext_axi_if_arvalid) sel_ext_r <= 1'b1;
        else if (m3_axi_arvalid) sel_ext_r <= 1'b0;
    end*/

    // 写地址通道多路选择
    wire [31:0] core_s_axi_awaddr  = sel_ext_w ? ext_axi_if_awaddr  : m3_axi_awaddr;
    wire        core_s_axi_awvalid = sel_ext_w ? ext_axi_if_awvalid : m3_axi_awvalid;
    wire        core_s_axi_awready;
    assign ext_axi_if_awready = sel_ext_w ? core_s_axi_awready : 1'b0;
    assign m3_axi_awready     = ~sel_ext_w ? core_s_axi_awready : 1'b0;

    // 写数据通道多路选择
    wire [31:0] core_s_axi_wdata   = sel_ext_w ? ext_axi_if_wdata   : m3_axi_wdata;
    wire [3:0]  core_s_axi_wstrb   = sel_ext_w ? ext_axi_if_wstrb   : m3_axi_wstrb;
    wire        core_s_axi_wvalid  = sel_ext_w ? ext_axi_if_wvalid  : m3_axi_wvalid;
    wire        core_s_axi_wready;
    assign ext_axi_if_wready  = sel_ext_w ? core_s_axi_wready  : 1'b0;
    assign m3_axi_wready      = ~sel_ext_w ? core_s_axi_wready  : 1'b0;

    // 写响应通道多路选择
    wire [1:0]  core_s_axi_bresp;
    wire        core_s_axi_bvalid;
    assign ext_axi_if_bresp   = core_s_axi_bresp; assign m3_axi_bresp = core_s_axi_bresp;
    assign ext_axi_if_bvalid  = sel_ext_w ? core_s_axi_bvalid : 1'b0;
    assign m3_axi_bvalid      = ~sel_ext_w ? core_s_axi_bvalid : 1'b0;
    wire        core_s_axi_bready  = sel_ext_w ? ext_axi_if_bready  : m3_axi_bready;

    // 读地址通道多路选择
    wire [31:0] core_s_axi_araddr  = sel_ext_r ? ext_axi_if_araddr  : m3_axi_araddr;
    wire        core_s_axi_arvalid = sel_ext_r ? ext_axi_if_arvalid : m3_axi_arvalid;
    wire        core_s_axi_arready;
    assign ext_axi_if_arready = sel_ext_r ? core_s_axi_arready : 1'b0;
    assign m3_axi_arready     = ~sel_ext_r ? core_s_axi_arready : 1'b0;

    // 读数据通道多路选择
    wire [31:0] core_s_axi_rdata;
    wire [1:0]  core_s_axi_rresp;
    wire        core_s_axi_rvalid;
    assign ext_axi_if_rdata   = core_s_axi_rdata; assign m3_axi_rdata = core_s_axi_rdata;
    assign ext_axi_if_rresp   = core_s_axi_rresp; assign m3_axi_rresp = core_s_axi_rresp;
    assign ext_axi_if_rvalid  = sel_ext_r ? core_s_axi_rvalid : 1'b0;
    assign m3_axi_rvalid      = ~sel_ext_r ? core_s_axi_rvalid : 1'b0;
    wire        core_s_axi_rready  = sel_ext_r ? ext_axi_if_rready  : m3_axi_rready;

    // -------------------------------------------------------------
    // [1] CPU 核心 (TSP_Core) 
    // 注意：这里的 s_axi_if 全部接入了上述的 core_s_axi_*
    // -------------------------------------------------------------
    TSP_Core u_TSP_Core (
        .clk              (clk),
        .rst_n            (rst_n)
        ,.s_axi_if_awaddr (core_s_axi_awaddr), .s_axi_if_awvalid(core_s_axi_awvalid), .s_axi_if_awready(core_s_axi_awready)
        ,.s_axi_if_wdata  (core_s_axi_wdata),  .s_axi_if_wstrb  (core_s_axi_wstrb),   .s_axi_if_wvalid (core_s_axi_wvalid), .s_axi_if_wready (core_s_axi_wready)
        ,.s_axi_if_bresp  (core_s_axi_bresp),  .s_axi_if_bvalid (core_s_axi_bvalid),  .s_axi_if_bready (core_s_axi_bready)
        ,.s_axi_if_araddr (core_s_axi_araddr), .s_axi_if_arvalid(core_s_axi_arvalid), .s_axi_if_arready(core_s_axi_arready)
        ,.s_axi_if_rdata  (core_s_axi_rdata),  .s_axi_if_rresp  (core_s_axi_rresp),   .s_axi_if_rvalid (core_s_axi_rvalid), .s_axi_if_rready (core_s_axi_rready)
        
        ,.m_axi_ls_awaddr (ls_axi_awaddr),     .m_axi_ls_awvalid(ls_axi_awvalid),     .m_axi_ls_awready(ls_axi_awready)
        ,.m_axi_ls_wdata  (ls_axi_wdata),      .m_axi_ls_wstrb  (ls_axi_wstrb),       .m_axi_ls_wvalid (ls_axi_wvalid),     .m_axi_ls_wready (ls_axi_wready)
        ,.m_axi_ls_bresp  (ls_axi_bresp),      .m_axi_ls_bvalid (ls_axi_bvalid),      .m_axi_ls_bready (ls_axi_bready)
        ,.m_axi_ls_araddr (ls_axi_araddr),     .m_axi_ls_arvalid(ls_axi_arvalid),     .m_axi_ls_arready(ls_axi_arready)
        ,.m_axi_ls_rdata  (ls_axi_rdata),      .m_axi_ls_rresp  (ls_axi_rresp),       .m_axi_ls_rvalid (ls_axi_rvalid),     .m_axi_ls_rready (ls_axi_rready)
    );

    // -------------------------------------------------------------
    // [2] 地址分发器 (AXI Interconnect)
    // 已经将 M3 IRAM 通道扩展了进来
    // -------------------------------------------------------------
    TSP_AXI_Interconnect u_Interconnect (
        .clk(clk), .rst_n(rst_n),
        .s_axi_awaddr(ls_axi_awaddr), .s_axi_awvalid(ls_axi_awvalid), .s_axi_awready(ls_axi_awready),
        .s_axi_wdata (ls_axi_wdata),  .s_axi_wstrb  (ls_axi_wstrb),   .s_axi_wvalid (ls_axi_wvalid),  .s_axi_wready (ls_axi_wready),
        .s_axi_bresp (ls_axi_bresp),  .s_axi_bvalid (ls_axi_bvalid),  .s_axi_bready (ls_axi_bready),
        .s_axi_araddr(ls_axi_araddr), .s_axi_arvalid(ls_axi_arvalid), .s_axi_arready(ls_axi_arready),
        .s_axi_rdata (ls_axi_rdata),  .s_axi_rresp  (ls_axi_rresp),   .s_axi_rvalid (ls_axi_rvalid),  .s_axi_rready (ls_axi_rready),
        
        // M1: SRAM
        .m1_axi_awaddr(m1_axi_awaddr), .m1_axi_awvalid(m1_axi_awvalid), .m1_axi_awready(m1_axi_awready),
        .m1_axi_wdata (m1_axi_wdata),  .m1_axi_wstrb  (m1_axi_wstrb),   .m1_axi_wvalid (m1_axi_wvalid), .m1_axi_wready (m1_axi_wready),
        .m1_axi_bresp (m1_axi_bresp),  .m1_axi_bvalid (m1_axi_bvalid),  .m1_axi_bready (m1_axi_bready),
        .m1_axi_araddr(m1_axi_araddr), .m1_axi_arvalid(m1_axi_arvalid), .m1_axi_arready(m1_axi_arready),
        .m1_axi_rdata (m1_axi_rdata),  .m1_axi_rresp  (m1_axi_rresp),   .m1_axi_rvalid (m1_axi_rvalid), .m1_axi_rready (m1_axi_rready),
        
        // M2: UART
        .m2_axi_awaddr(m2_axi_awaddr), .m2_axi_awvalid(m2_axi_awvalid), .m2_axi_awready(m2_axi_awready),
        .m2_axi_wdata (m2_axi_wdata),  .m2_axi_wstrb  (m2_axi_wstrb),   .m2_axi_wvalid (m2_axi_wvalid), .m2_axi_wready (m2_axi_wready),
        .m2_axi_bresp (m2_axi_bresp),  .m2_axi_bvalid (m2_axi_bvalid),  .m2_axi_bready (m2_axi_bready),
        .m2_axi_araddr(m2_axi_araddr), .m2_axi_arvalid(m2_axi_arvalid), .m2_axi_arready(m2_axi_arready),
        .m2_axi_rdata (m2_axi_rdata),  .m2_axi_rresp  (m2_axi_rresp),   .m2_axi_rvalid (m2_axi_rvalid), .m2_axi_rready (m2_axi_rready),
        
        // M3: IRAM (供访存指令读取)
        .m3_axi_awaddr(m3_axi_awaddr), .m3_axi_awvalid(m3_axi_awvalid), .m3_axi_awready(m3_axi_awready),
        .m3_axi_wdata (m3_axi_wdata),  .m3_axi_wstrb  (m3_axi_wstrb),   .m3_axi_wvalid (m3_axi_wvalid), .m3_axi_wready (m3_axi_wready),
        .m3_axi_bresp (m3_axi_bresp),  .m3_axi_bvalid (m3_axi_bvalid),  .m3_axi_bready (m3_axi_bready),
        .m3_axi_araddr(m3_axi_araddr), .m3_axi_arvalid(m3_axi_arvalid), .m3_axi_arready(m3_axi_arready),
        .m3_axi_rdata (m3_axi_rdata),  .m3_axi_rresp  (m3_axi_rresp),   .m3_axi_rvalid (m3_axi_rvalid), .m3_axi_rready (m3_axi_rready)
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
    // [4] UART 串口外设 
    // -------------------------------------------------------------
    uart_axi_lite_wrapper #(
        .CLK_FREQ_p  (100_000_000), // 这里写你 FPGA 板子的真实主频
        .BAUD_RATE_p (115200)       // 这里写你想要的波特率
    ) u_UART (
        .clk             (clk),
        .rst_n           (rst_n),
        
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
        
        .rxd             (uart_rx),
        .txd             (uart_tx)
    );

endmodule