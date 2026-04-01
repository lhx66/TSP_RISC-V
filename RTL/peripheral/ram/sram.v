`include "../../core/defines.v"

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

// 提前声明 BRAM 的读出数据线，供 FSM 采样
wire [31:0] ram_rdata_out;

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

// ====================================================================
// 读通道 FSM
// ====================================================================
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

// ====================================================================
// 写通道 FSM
// ====================================================================
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
// 例化仿真用 SRAM (完美对齐 FPGA BRAM 时序)
// ====================================================================
// 只有 w_state == 1 时才拉高写使能，其他时间一律作为读地址输入
wire is_write_cycle = (w_state == 1);
wire [31:0] axi_addr_byte  = is_write_cycle ? waddr_r : raddr_r;

// 【核心防 Z 态转换】：将提取出的 13 位字地址强制补齐到 32 位！
wire [31:0] sram_addr_word = {19'b0, axi_addr_byte[14:2]};

TSP_RAM #(
    .RAM_DEPTH(`SRAM_KB),       
    .INIT_FILE(`SRAM_BOOT_PATH) 
) u_Data_Ram (
    .clk        (clk), 
    .rst_n      (rst_n),
    
    // --- Port A (用于 AXI 访存) ---
    // 为了防止错过任何读取，在仿真中将其长开 (同 FPGA BRAM 默认行为)
    .portA_en   (1'b1),
    .portA_we   (is_write_cycle ? wstrb_r : 4'b0000),
    .portA_addr (sram_addr_word),       
    .portA_wdata(wdata_r),
    .portA_rdata(ram_rdata_out), 
    .portA_ack  (),                     
    .portA_err  (),                     
    
    // --- Port B (彻底禁用) ---
    .portB_en   (1'b0), 
    .portB_we   (4'b0000), 
    .portB_addr (32'b0), 
    .portB_wdata(32'b0),
    .portB_rdata(),                     
    .portB_ack  (),                     
    .portB_err  ()                      
);

endmodule