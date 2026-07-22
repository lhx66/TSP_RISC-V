`include "../core/defines.v"

// TSP_Sram: 双端口SRAM，支持CPU单周期访问(TCM)和AXI下载
module TSP_Sram(
    input  wire clk,
    input  wire rst_n,

    // ==========================================
    // 端口A: CPU TCM接口 (单周期访问，高优先级)
    // ==========================================
    input  wire [31:0]                 cpu_addr_i, 
    input  wire                        cpu_we_i,
    input  wire [3:0]                  cpu_be_i,
    input  wire [31:0]                 cpu_wdata_i,
    output wire [31:0]                 cpu_rdata_o,

    // ==========================================
    // 端口B: AXI接口 (多周期访问，用于程序下载/调试)
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
    input  wire        s_axi_rready
);

    // ==========================================
    // AXI4-Lite 从机状态机 (稳健版)
    // ==========================================
    localparam IDLE       = 2'd0;
    localparam WRITE_RESP = 2'd1;
    localparam READ_WAIT  = 2'd2; // 关键新增：等待SRAM的一拍读取延迟！
    localparam READ_RESP  = 2'd3;

    reg [1:0] state;
    reg [12:0] b_addr_reg; // 13位字地址
    reg [31:0] axi_rdata_reg;
    wire [31:0] b_rd_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            b_addr_reg <= 0;
            axi_rdata_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    // 只有当 写地址 和 写数据 同时准备好时，才进入写状态，防乱码！
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        state <= WRITE_RESP;
                    end 
                    // 读操作
                    else if (s_axi_arvalid) begin
                        b_addr_reg <= s_axi_araddr[14:2]; // 锁存字地址
                        state <= READ_WAIT; 
                    end
                end

                WRITE_RESP: begin
                    if (s_axi_bready) state <= IDLE; // 握手完成，回到空闲
                end

                READ_WAIT: begin
                    // 【修正读时序】：SRAM 正在此刻输出数据，我们在下一拍边缘把它锁存
                    axi_rdata_reg <= b_rd_data;
                    state <= READ_RESP;
                end

                READ_RESP: begin
                    if (s_axi_rready) state <= IDLE; // 握手完成，回到空闲
                end
            endcase
        end
    end

    // ==========================================
    // 端口B AXI 握手信号连线
    // ==========================================
    // 仅在 IDLE 且条件满足时瞬间拉高 Ready，拒绝死锁
    assign s_axi_awready = (state == IDLE) && s_axi_awvalid && s_axi_wvalid;
    assign s_axi_wready  = (state == IDLE) && s_axi_awvalid && s_axi_wvalid;
    assign s_axi_arready = (state == IDLE) && s_axi_arvalid && !(s_axi_awvalid && s_axi_wvalid);

    assign s_axi_bvalid  = (state == WRITE_RESP);
    assign s_axi_bresp   = 2'b00; // OKAY

    assign s_axi_rvalid  = (state == READ_RESP);
    assign s_axi_rdata   = axi_rdata_reg;
    assign s_axi_rresp   = 2'b00; // OKAY

    // ==========================================
    // SRAM 端口B 数据路由控制
    // ==========================================
    // 触发写使能：仅在 IDLE 拍发生 AXI 写握手时，拉高一拍！
    wire b_wr_en_wire = (state == IDLE) && s_axi_awvalid && s_axi_wvalid;

    // 智能地址多路复用器
    wire [12:0] b_addr_wire = 
        b_wr_en_wire ? s_axi_awaddr[14:2] :                               // 写的瞬间用 AWADDR
        ((state == IDLE) && s_axi_arvalid) ? s_axi_araddr[14:2] :         // 读的瞬间用 ARADDR
        b_addr_reg;                                                       // 等待期间用锁存地址

    // ==========================================
    // 实例化 SRAM IP 核
    // ==========================================
    // 端口 A：直接将字节地址[14:2]截断为字地址
    wire [12:0] a_addr = cpu_addr_i[14:2]; 
    wire [31:0] a_rd_data;
    wire [12:0] b_addr = b_addr_wire;

    assign cpu_rdata_o = a_rd_data;

    SRAM u_SRAM_IP (
        // Port A (CPU TCM 单周期无情飙车接口)
        .a_addr      (a_addr),
        .a_wr_data   (cpu_wdata_i),
        .a_rd_data   (a_rd_data),
        .a_wr_en     (cpu_we_i),
        .a_wr_byte_en(cpu_be_i),
        .a_clk       (clk),
        .a_rst       (~rst_n), // IP核通常高有效复位

        // Port B (AXI 系统下载温和接口)
        .b_addr      (b_addr),
        .b_wr_data   (s_axi_wdata),
        .b_rd_data   (b_rd_data),
        .b_wr_en     (b_wr_en_wire),
        .b_wr_byte_en(s_axi_wstrb),
        .b_clk       (clk),
        .b_rst       (~rst_n)
    );

endmodule
