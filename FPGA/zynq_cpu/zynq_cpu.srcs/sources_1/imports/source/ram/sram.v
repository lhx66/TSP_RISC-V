`include "../core/defines.v"

module TSP_Sram(
    input clk,
    input rst_n,

    // ==========================================
    // AXI4-Lite Slave 接口
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

// ====================================================================
// 防弹级 AXI4-Lite 状态机 (严格互斥读写与时序对齐)
// ====================================================================
reg [1:0] r_state;
reg [31:0] raddr_r;
reg [31:0] rdata_latch;

reg [1:0] w_state;
reg [31:0] waddr_r;
reg [31:0] wdata_r;
reg [3:0]  wstrb_r;

// 互斥锁标志：防止读写同时访问单端口 SRAM
wire write_busy = (w_state != 0);
wire read_busy  = (r_state != 0);

// AXI 握手信号静态分配
assign s_axi_arready = (r_state == 0) && !write_busy;
assign s_axi_rvalid  = (r_state == 3);
assign s_axi_rdata   = rdata_latch;
assign s_axi_rresp   = 2'b00; // OKAY

assign s_axi_awready = (w_state == 0) && s_axi_wvalid && !read_busy;
assign s_axi_wready  = (w_state == 0) && s_axi_awvalid && !read_busy;
assign s_axi_bvalid  = (w_state == 2);
assign s_axi_bresp   = 2'b00; // OKAY

// 读通道 FSM
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        r_state <= 0; 
        raddr_r <= 0; 
        rdata_latch <= 0;
    end else begin
        case (r_state)
            0: begin // Idle
                if (s_axi_arvalid && s_axi_arready) begin
                    raddr_r <= s_axi_araddr;
                    r_state <= 1;
                end
            end
            1: begin // 喂入地址，等待 BRAM 采样
                r_state <= 2; 
            end
            2: begin // BRAM 数据已稳定输出，将其安全锁存
                rdata_latch <= ram_rdata_out; 
                r_state <= 3;
            end
            3: begin // 等待 Master 接收读出的数据
                if (s_axi_rready) r_state <= 0;
            end
        endcase
    end
end

// 写通道 FSM
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        w_state <= 0; 
        waddr_r <= 0; 
        wdata_r <= 0; 
        wstrb_r <= 0;
    end else begin
        case (w_state)
            0: begin // Idle
                if (s_axi_awvalid && s_axi_wvalid && s_axi_awready) begin
                    waddr_r <= s_axi_awaddr; 
                    wdata_r <= s_axi_wdata; 
                    wstrb_r <= s_axi_wstrb;
                    w_state <= 1;
                end
            end
            1: begin // 维持写使能 1 拍，等待 BRAM 吞入数据
                w_state <= 2; 
            end
            2: begin // 写入完成，等待 Master 接收响应
                if (s_axi_bready) w_state <= 0;
            end
            default: w_state <= 0;
        endcase
    end
end

// ====================================================================
// 例化 FPGA SRAM IP (单端口时分复用读写)
// ====================================================================
// 只有 w_state == 1 时才拉高写使能，其他时间一律作为读地址输入
wire is_write_cycle = (w_state == 1);
wire [31:0] axi_addr_byte  = is_write_cycle ? waddr_r : raddr_r;

// 字节地址转 10-bit 字地址 (SRAM 的深度要求)
wire [12:0] sram_addr_word = axi_addr_byte[14:2];
wire [31:0] ram_rdata_out;

SRAM u_Data_Ram (
    .a_addr(sram_addr_word),                // input [9:0]
    .a_wr_data(wdata_r),                    // input [31:0]
    .a_rd_data(ram_rdata_out),              // output [31:0]
    .a_wr_en(is_write_cycle),               // input
    .a_wr_byte_en(is_write_cycle ? wstrb_r : 4'b0000), // input [3:0]
    .a_clk(clk),                            // input
    .a_rst(~rst_n),                         // input
    
    // Port B 悬空彻底禁用
    .b_addr(10'b0),                         
    .b_wr_data(32'b0),                      
    .b_rd_data(),                           
    .b_wr_en(1'b0),                         
    .b_wr_byte_en(4'b0000),                 
    .b_clk(clk),                            
    .b_rst(~rst_n)                          
);

endmodule