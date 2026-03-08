`include "defines.v"

module TSP_Exu_ls(
    input clk,
    input rst_n,

    // ==========================================
    // 1. 译码信息 (来自 Cycle 1 派遣级)
    // ==========================================
    input idec_valid_i,
    output exu_ls_ready_o,       // 输出反压：告诉 Dispatch 模块 LSU 是否空闲

    input INST_LB, INST_LH, INST_LW, INST_LBU, INST_LHU,
    input INST_SB, INST_SH, INST_SW,
    
    input  [`REGFILE_DAT_WIDTH-1:0] rs2_op, // Store 写入的数据
    input  [`REGFILE_IDX_WIDTH-1:0] rd_i,   // 【新增】Load 写入的目标寄存器索引

    // ==========================================
    // 2. 加法器地址输入 (来自 Cycle 2 Exu_common)
    // ==========================================
    input  [`REGFILE_DAT_WIDTH-1:0] ls_addr_i, 
    
    // ==========================================
    // 3. 访存控制模块接口 (去往 TSP_Lsu_Ctrl)
    // ==========================================
    output        ls_req_o,      // 访存请求有效 (读或写)
    output        ls_we_o,       // 1: Store写, 0: Load读
    output [`REGFILE_DAT_WIDTH-1:0] ls_addr_o,     // 输出物理地址给访存控制器
    output [3:0]  ls_byte_en_o,  // 字节写使能掩码 (Byte Enable)
    output [31:0] ls_wdata_o,    // 对齐后的写入数据
    
    output [2:0]  ls_load_type_o,// 0:LW, 1:LH, 2:LHU, 3:LB, 4:LBU
    output [`REGFILE_IDX_WIDTH-1:0] ls_rd_o,       // 【新增】传递 rd 给访存控制器
    
    input         wb_ls_ready_i  // 访存控制模块反压 (表示请求已被接收/完成)
);

// -------------------------------------------------------------
// 第 1 步：入口握手与状态机
// -------------------------------------------------------------
wire is_load  = INST_LB | INST_LH | INST_LW | INST_LBU | INST_LHU;
wire is_store = INST_SB | INST_SH | INST_SW;
wire is_ls    = is_load | is_store;

reg ls_busy_r;

assign exu_ls_ready_o = ~ls_busy_r;
wire ls_fire = idec_valid_i & is_ls & exu_ls_ready_o;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        ls_busy_r <= 1'b0;
    end else begin
        if (ls_busy_r && wb_ls_ready_i) begin
            ls_busy_r <= 1'b0;
        end 
        else if (ls_fire) begin
            ls_busy_r <= 1'b1;
        end
    end
end

// -------------------------------------------------------------
// 第 2 步：提取并锁存控制信息与 Store 数据
// -------------------------------------------------------------
reg [2:0]  store_type_r;
reg [2:0]  load_type_r;
reg [31:0] rs2_data_r;
reg [`REGFILE_IDX_WIDTH-1:0] rd_r; // 锁存目标寄存器
reg        is_store_r;
reg [`REGFILE_DAT_WIDTH-1:0] ls_addr_r;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        store_type_r <= 3'd0;
        load_type_r  <= 3'd0;
        rs2_data_r   <= 32'd0;
        rd_r         <= 5'd0;
        is_store_r   <= 1'b0;
        ls_addr_r <= 32'd0;
    end else if (ls_fire) begin
        rs2_data_r   <= rs2_op;
        rd_r         <= rd_i;      // 锁存 rd_i
        is_store_r   <= is_store;
        
        store_type_r <= (INST_SW) ? 3'd2 :
                        (INST_SH) ? 3'd1 : 3'd0; 
        
        load_type_r  <= (INST_LW)  ? 3'd0 :
                        (INST_LH)  ? 3'd1 :
                        (INST_LHU) ? 3'd2 :
                        (INST_LB)  ? 3'd3 : 3'd4; 
        ls_addr_r <= ls_addr_i;
    end
end

// -------------------------------------------------------------
// 第 3 步：向 Lsu_Ctrl 输出请求信号 (组合逻辑对齐 ls_addr_i)
// -------------------------------------------------------------
assign ls_req_o  = ls_busy_r;
assign ls_we_o   = is_store_r;
assign ls_addr_o = ls_addr_r; 
assign ls_rd_o   = rd_r;      // 透传目标寄存器
assign ls_load_type_o = load_type_r;

wire [1:0] addr_align = ls_addr_r[1:0];
reg [3:0]  byte_en;
reg [31:0] wdata;

always @(*) begin
    byte_en = 4'b0000;
    wdata   = 32'd0;

    if (ls_busy_r && is_store_r) begin
        case (store_type_r)
            3'd0: begin // SB
                byte_en = 4'b0001 << addr_align;
                wdata   = {4{rs2_data_r[7:0]}}; 
            end
            3'd1: begin // SH
                byte_en = (addr_align[1]) ? 4'b1100 : 4'b0011;
                wdata   = {2{rs2_data_r[15:0]}}; 
            end
            3'd2: begin // SW
                byte_en = 4'b1111;
                wdata   = rs2_data_r;
            end
            default: ;
        endcase
    end
end

assign ls_byte_en_o = byte_en;
assign ls_wdata_o   = wdata;

endmodule