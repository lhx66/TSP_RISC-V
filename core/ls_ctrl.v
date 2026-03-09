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

// -------------------------------------------------------------
// 1. 简易单端口 SRAM 模型 (Simulated Block RAM)
// -------------------------------------------------------------
// 定义一个 16KB 的内存用于仿真验证 (深度 4096，位宽 32)
reg [31:0] sram_array [0:4095];
reg [31:0] sram_rdata;

// 字地址：因为 SRAM 每一行是 32-bit (4 Bytes)，所以丢弃地址最低两位
wire [11:0] word_addr = ls_addr_i[13:2]; 

always @(posedge clk) begin
    // 同步写操作 (受 Mask 控制)
    if (ls_req_i && ls_we_i & wb_ls_ready_i) begin
        if (ls_byte_en_i[0]) sram_array[word_addr][7:0]   <= ls_wdata_i[7:0];
        if (ls_byte_en_i[1]) sram_array[word_addr][15:8]  <= ls_wdata_i[15:8];
        if (ls_byte_en_i[2]) sram_array[word_addr][23:16] <= ls_wdata_i[23:16];
        if (ls_byte_en_i[3]) sram_array[word_addr][31:24] <= ls_wdata_i[31:24];
    end
    
    // 同步读操作 (默认 1 周期延迟)
    if (ls_req_i & ~ls_we_i & wb_ls_ready_i) begin
        sram_rdata <= sram_array[word_addr];
    end
end

// -------------------------------------------------------------
// 2. 状态锁存与时序控制 (生成 Ready 脉冲)
// -------------------------------------------------------------
// 因为 SRAM 读写需要 1 个周期，我们需要把请求信息打一拍，留给下个周期处理数据
reg [1:0] addr_align_r;
reg [2:0] load_type_r;
reg [`REGFILE_IDX_WIDTH-1:0] wb_rd_r;
reg       we_r;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        addr_align_r <= 2'b0;
        load_type_r  <= 3'b0;
        wb_rd_r      <= 5'b0;
        we_r         <= 1'b0;
    end else if (ls_req_i & ls_ctrl_ready_o) begin
            addr_align_r <= ls_addr_i[1:0]; // 保存地址对齐偏移量
            load_type_r  <= ls_load_type;
            wb_rd_r      <= ls_rd;
            we_r         <= ls_we_i;
    end
end

assign ls_ctrl_ready_o = wb_ls_ready_i; // 反压信号传递

// -------------------------------------------------------------
// 3. Load 数据的对齐、截取与符号扩展 (组合逻辑)
// -------------------------------------------------------------
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

// -------------------------------------------------------------
// 4. 写回仲裁器输出
// -------------------------------------------------------------
REGs_NLWR #(1,0) ls_ctrl_wb_en_reg (ls_req_i & ~ls_we_i & wb_ls_ready_i, ls_ctrl_wb_en_o, clk, rst_n);
assign ls_ctrl_wb_rd_o   = wb_rd_r;
assign ls_ctrl_wb_data_o = final_wb_data;

endmodule