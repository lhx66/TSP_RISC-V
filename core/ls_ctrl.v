`include "defines.v"

module ls_ctrl( //修改一下反压信号处理
    input clk,
    input rst_n,

    // ==========================================
    // 1. 与 TSP_Exu_ls 交互接口
    // ==========================================
    input         ls_req_i,        // 访存请求
    input         ls_we_i,         // 1: Store写, 0: Load读
    input [31:0]  ls_addr_i,       // 访存物理地址
    input [3:0]   ls_byte_en_i,    // 字节写使能掩码 (Byte Enable)
    input [31:0]  ls_wdata_i,      // 对齐后的写入数据
    
    input [`REGFILE_IDX_WIDTH-1:0] ls_rd, // 目标寄存器
    input [2:0]   ls_load_type,    // 0:LW, 1:LH, 2:LHU, 3:LB, 4:LBU
    
    output        ls_ctrl_ready_o, // 访存就绪

    // ==========================================
    // 2. 与写回仲裁器交互接口
    // ==========================================
    output        ls_ctrl_wb_en_o,   // Load指令完成，请求写回
    input         wb_ls_ready_i,// 写回就绪
    output [`REGFILE_IDX_WIDTH-1:0] ls_ctrl_wb_rd_o, // 写回的寄存器索引
    output [31:0] ls_ctrl_wb_data_o  // 符号扩展后的最终写回数据
);

reg [31:0] sram_array [0:4095];
reg [31:0] sram_rdata;
wire [11:0] word_addr = ls_addr_i[13:2]; 

// Load 任务状态机
reg load_wb_pending_r; // 标记当前是否有一条 Load 指令正在等仲裁器

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        load_wb_pending_r <= 1'b0;
    end else begin
        // 当收到 Load 请求，且当前没有 pending 时，进入等待写回状态
        if (ls_req_i && ~ls_we_i && ~load_wb_pending_r) begin
            load_wb_pending_r <= 1'b1;
        end 
        // 当处于 pending 状态，且仲裁器同意写回时，任务完成
        else if (load_wb_pending_r && wb_ls_ready_i) begin
            load_wb_pending_r <= 1'b0;
        end
    end
end

// SRAM 同步读写
always @(posedge clk) begin
    // Store: 无需写回仲裁，立刻写入
    if (ls_req_i && ls_we_i) begin
        if (ls_byte_en_i[0]) sram_array[word_addr][7:0]   <= ls_wdata_i[7:0];
        if (ls_byte_en_i[1]) sram_array[word_addr][15:8]  <= ls_wdata_i[15:8];
        if (ls_byte_en_i[2]) sram_array[word_addr][23:16] <= ls_wdata_i[23:16];
        if (ls_byte_en_i[3]) sram_array[word_addr][31:24] <= ls_wdata_i[31:24];
    end
    
    // Load: 读入数据
    if (ls_req_i && ~ls_we_i && ~load_wb_pending_r) begin
        sram_rdata <= sram_array[word_addr];
    end
end

// 状态打拍 (用于截取数据)
reg [1:0] addr_align_r;
reg [2:0] load_type_r;
reg [`REGFILE_IDX_WIDTH-1:0] wb_rd_r;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        addr_align_r <= 2'b0;
        load_type_r  <= 3'b0;
        wb_rd_r      <= 5'b0;
    end else if (ls_req_i && ~load_wb_pending_r) begin
        addr_align_r <= ls_addr_i[1:0]; 
        load_type_r  <= ls_load_type;
        wb_rd_r      <= ls_rd;
    end
end

// 反馈给前端的 Ready 信号
// Store 当拍就绪，Load 则要等到写回仲裁器同意
assign ls_ctrl_ready_o = (ls_req_i & ls_we_i) | (load_wb_pending_r & wb_ls_ready_i);

// 第 1 步：将读回的 32 位数据，根据地址的偏移量，把有效数据移到最低位
// 例如：读地址 0x01，说明我们想要的数据在 sram_rdata[15:8]。
// addr_align_r = 2'b01，乘以 8 就是右移 8 位。
wire [31:0] shifted_data = sram_rdata >> ({addr_align_r, 3'b000});

reg [31:0] final_wb_data;

// 第 2 步：根据 Load 指令类型，截取并扩展
always @(*) begin
    case (load_type_r)
        3'd0: // LW (Load Word) - 全 32 位
            final_wb_data = shifted_data;
            
        3'd1: // LH (Load Halfword) - 截取低 16 位，有符号扩展
            final_wb_data = {{16{shifted_data[15]}}, shifted_data[15:0]};
            
        3'd2: // LHU (Load Halfword Unsigned) - 截取低 16 位，无符号扩展 (高位补 0)
            final_wb_data = {16'b0, shifted_data[15:0]};
            
        3'd3: // LB (Load Byte) - 截取低 8 位，有符号扩展
            final_wb_data = {{24{shifted_data[7]}}, shifted_data[7:0]};
            
        3'd4: // LBU (Load Byte Unsigned) - 截取低 8 位，无符号扩展 (高位补 0)
            final_wb_data = {24'b0, shifted_data[7:0]};
            
        default: 
            final_wb_data = 32'b0;
    endcase
end

assign ls_ctrl_wb_en_o   = load_wb_pending_r;
assign ls_ctrl_wb_rd_o   = wb_rd_r;
assign ls_ctrl_wb_data_o = final_wb_data;

endmodule

/*
module ls_ctrl(
    // ... 端口保持不变 ...
);

// -------------------------------------------------------------
// 1. SRAM 读写 (纯正的同步 SRAM 行为)
// -------------------------------------------------------------
reg [31:0] sram_array [0:4095];
reg [31:0] sram_rdata;
wire [11:0] word_addr = ls_addr_i[13:2]; 

always @(posedge clk) begin
    // 写 SRAM
    if (ls_req_i && ls_we_i && ls_ctrl_ready_o) begin
        if (ls_byte_en_i[0]) sram_array[word_addr][7:0]   <= ls_wdata_i[7:0];
        // ... (其他字节写使能)
    end
    
    // 读 SRAM (只要有 Load 请求，无脑读，数据下个周期自动出现在 sram_rdata)
    if (ls_req_i && ~ls_we_i && ls_ctrl_ready_o) begin
        sram_rdata <= sram_array[word_addr];
    end
end

// -------------------------------------------------------------
// 2. 流水线打拍寄存器 (Pipeline Registers)
// -------------------------------------------------------------
// 记录上一拍是不是一个有效的 Load 请求，以便在这一拍拿数据
reg ls_load_valid_q;
reg [1:0] addr_align_q;
reg [2:0] load_type_q;
reg [`REGFILE_IDX_WIDTH-1:0] wb_rd_q;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        ls_load_valid_q <= 1'b0;
        addr_align_q    <= 2'b0;
        load_type_q     <= 3'b0;
        wb_rd_q         <= 5'b0;
    end else begin
        // 【流水线反压核心】：只有当后端写回准备好时，流水线才流动！
        if (wb_ls_ready_i) begin
            // 把当拍的输入状态打入流水线，传给下一拍
            ls_load_valid_q <= ls_req_i & ~ls_we_i & ls_ctrl_ready_o;
            addr_align_q    <= ls_addr_i[1:0];
            load_type_q     <= ls_load_type;
            wb_rd_q         <= ls_rd;
        end
    end
end

// 【反压逻辑】：如果当前流水线寄存器里有一个 Load 还没写回成功，
// 且仲裁器也没准备好接收，我就必须告诉前端“我堵住了，不要再发新指令了！”
assign ls_ctrl_ready_o = ~(ls_load_valid_q & ~wb_ls_ready_i);

// -------------------------------------------------------------
// 3. 数据截取与输出 (组合逻辑)
// -------------------------------------------------------------
wire [31:0] shifted_data = sram_rdata >> ({addr_align_q, 3'b000});
reg [31:0] final_wb_data;
// ... (case 语句截取符号扩展逻辑，和之前一模一样) ...

// 写回仲裁器输出
assign ls_ctrl_wb_en_o   = ls_load_valid_q; 
assign ls_ctrl_wb_rd_o   = wb_rd_q;
assign ls_ctrl_wb_data_o = final_wb_data;

endmodule
*/