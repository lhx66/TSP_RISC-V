`include "defines.v"

module TSP_Ifu(
    input clk,
    input rst_n,

    // ==========================================
    // 1. CPU 取指流控制
    // ==========================================
    input  [`INST_ADDR_WIDTH-1:0] next_pc_i,    
    input                         ifu_permission, 
    output                        ifu_ready_o,

    input                         flush_i, 

    output [`INST_MAX_WIDTH-1:0]  inst_o,
    output                        inst_valid_o,
    output [`INST_ADDR_WIDTH-1:0] inst_pc_o,  
    output                        inst_err_o,

    input idec_ready_i,

    input  pre_pc_taken_i,
    output pre_pc_taken_o,

    // ==========================================
    // 2. AXI4-Lite Slave 接口 (用于 IRAM 的访存与烧录)
    // ==========================================
    input  wire [31:0] s_axi_awaddr, input  wire s_axi_awvalid, output wire s_axi_awready,
    input  wire [31:0] s_axi_wdata,  input  wire [3:0] s_axi_wstrb, input  wire s_axi_wvalid, output wire s_axi_wready,
    output wire [1:0]  s_axi_bresp,  output wire s_axi_bvalid,  input  wire s_axi_bready,
    input  wire [31:0] s_axi_araddr, input  wire s_axi_arvalid, output wire s_axi_arready,
    output wire [31:0] s_axi_rdata,  output wire [1:0] s_axi_rresp, output wire s_axi_rvalid, input  wire s_axi_rready
);

// ====================================================================
// A. 防弹级 AXI4-Lite 状态机 (控制 IRAM Port B)
// ====================================================================
reg [1:0] r_state;
reg [31:0] raddr_r;
reg [31:0] rdata_latch;

reg [1:0] w_state;
reg [31:0] waddr_r;
reg [31:0] wdata_r;
reg [3:0]  wstrb_r;

wire write_busy = (w_state != 0);
wire read_busy  = (r_state != 0);

assign s_axi_arready = (r_state == 0) && !write_busy;
assign s_axi_rvalid  = (r_state == 3);
assign s_axi_rdata   = rdata_latch;
assign s_axi_rresp   = 2'b00;

assign s_axi_awready = (w_state == 0) && s_axi_wvalid && !read_busy;
assign s_axi_wready  = (w_state == 0) && s_axi_awvalid && !read_busy;
assign s_axi_bvalid  = (w_state == 2);
assign s_axi_bresp   = 2'b00;

// 读通道
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        r_state <= 0; raddr_r <= 0; rdata_latch <= 0;
    end else begin
        case (r_state)
            0: if (s_axi_arvalid && s_axi_arready) begin raddr_r <= s_axi_araddr; r_state <= 1; end
            1: r_state <= 2; 
            2: begin rdata_latch <= portB_rdata_out; r_state <= 3; end
            3: if (s_axi_rready) r_state <= 0;
        endcase
    end
end

// 写通道
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        w_state <= 0; waddr_r <= 0; wdata_r <= 0; wstrb_r <= 0;
    end else begin
        case (w_state)
            0: if (s_axi_awvalid && s_axi_wvalid && s_axi_awready) begin
                   waddr_r <= s_axi_awaddr; wdata_r <= s_axi_wdata; wstrb_r <= s_axi_wstrb;
                   w_state <= 1;
               end
            1: w_state <= 2;
            2: if (s_axi_bready) w_state <= 0;
        endcase
    end
end

// ====================================================================
// B. 例化双端口 FPGA IRAM IP
// ====================================================================
wire iram_ack_o;
wire [`INST_MAX_WIDTH-1:0] iram_rdata;
wire inst_req_i = ifu_permission;

// 手动生成 Port A (CPU取指) 的 1 拍延迟 ACK
reg iram_ack_r;
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) iram_ack_r <= 1'b0;
    else iram_ack_r <= inst_req_i;
end
assign iram_ack_o = iram_ack_r;
assign inst_err_o = 1'b0; 

// Port A 地址线连线 (取指只读)
wire [13:0] portA_addr_word = next_pc_i[15:2];

// Port B 地址线连线 (AXI 总线读写)
wire is_write_cycle = (w_state == 1);
wire [31:0] axi_b_addr_byte = is_write_cycle ? waddr_r : raddr_r;
wire [11:0] portB_addr_word = axi_b_addr_byte[13:2];
wire [31:0] portB_rdata_out;

IRAM u_Iram (
    // Port A：专门用于 CPU IFU 取指 (只读)
    .a_addr(portA_addr_word),                // input [11:0]
    .a_wr_data(32'b0),                       // input [31:0]
    .a_rd_data(iram_rdata),                  // output [31:0]
    .a_wr_en(1'b0),                          // input
    .a_wr_byte_en(4'b0000),                  // input [3:0]
    .a_clk(clk),                             // input
    .a_rst(~rst_n),                          // input
    
    // Port B：专门用于 AXI 下载和访存指令读取 (可读可写)
    .b_addr(portB_addr_word),                // input [11:0]
    .b_wr_data(wdata_r),                     // input [31:0]
    .b_rd_data(portB_rdata_out),             // output [31:0] 
    .b_wr_en(is_write_cycle),                // input
    .b_wr_byte_en(is_write_cycle ? wstrb_r : 4'b0000), // input [3:0]
    .b_clk(clk),                             // input
    .b_rst(~rst_n)                           // input
);

// ====================================================================
// C. 取指上下文对齐寄存器 (登机牌机制)
// ====================================================================
reg [`INST_ADDR_WIDTH-1:0] fetch_pc_delay_r;
reg                        fetch_taken_delay_r;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        fetch_pc_delay_r    <= `PC_RSTVAL;
        fetch_taken_delay_r <= 1'b0;
    end else if (ifu_permission) begin 
        fetch_pc_delay_r    <= next_pc_i;
        fetch_taken_delay_r <= pre_pc_taken_i;
    end
end

// ====================================================================
// D. IF Skid Buffer (取指滑板缓冲) + 幽灵气泡屏蔽
// ====================================================================
reg [`INST_MAX_WIDTH-1:0]  inst_buffer_r;
reg                        use_buffer_r;
reg                        flush_r;
reg                        pre_pc_taken_r;
reg [`INST_ADDR_WIDTH-1:0] pc_buffer_r;

wire [`INST_MAX_WIDTH-1:0] safe_iram_rdata = (iram_rdata == 32'h00000000) ? 32'h0000006f : iram_rdata;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) flush_r <= 1'b0;
    else        flush_r <= flush_i;
end

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        use_buffer_r   <= 1'b0;
        inst_buffer_r  <= 32'h00000013; 
        pc_buffer_r    <= `PC_RSTVAL;
        pre_pc_taken_r <= 1'b0;
    end else begin
        if (flush_i) begin
            use_buffer_r  <= 1'b0;
        end 
        else if (~idec_ready_i && ~use_buffer_r && iram_ack_o && ~flush_i && ~flush_r) begin
            use_buffer_r   <= 1'b1;
            inst_buffer_r  <= safe_iram_rdata;
            pc_buffer_r    <= fetch_pc_delay_r;
            pre_pc_taken_r <= fetch_taken_delay_r;
        end 
        else if (idec_ready_i) begin
            use_buffer_r  <= 1'b0;
        end
    end
end

// ====================================================================
// E. 最终输出与 PC 透传
// ====================================================================
assign inst_o         = use_buffer_r ? inst_buffer_r  : safe_iram_rdata;
assign inst_pc_o      = use_buffer_r ? pc_buffer_r    : fetch_pc_delay_r;
assign pre_pc_taken_o = use_buffer_r ? pre_pc_taken_r : fetch_taken_delay_r;

assign inst_valid_o   = (iram_ack_o | use_buffer_r) & ~flush_i & ~flush_r;
assign ifu_ready_o    = idec_ready_i;

endmodule