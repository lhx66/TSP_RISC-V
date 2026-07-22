`include "defines.v"

//PC计数器 包含BPU (支持参数化任意深度 BTB)
module PC_control(
    input clk,
    input rst_n,

    //IFU交互
    output reg [`INST_ADDR_WIDTH-1:0] global_pc_o, //全局PC（待取指PC）
    output                            global_pc_valid_o,
    input ifu_ready_i,

    output pre_pc_taken, //预测结果是跳转还是不跳转

    input [`BTB_ENTRY_WIDTH-1:0] BTB_update,       // 格式见 defines.v BTB字段布局
    input                        BTB_update_valid,  // 执行阶段写回BTB

    //预测错误重定向
    input [`INST_ADDR_WIDTH-1:0] pc_correct_i,  // 正确的下一条 PC
    input                        pc_redirect_i,  // 预测错误，强制重定向

    output flush
);

// =========================================
// BTB 存储单元
// =========================================
reg [`BTB_ENTRY_WIDTH-1:0] BTBuffer [0:`BTB_ENTRIES-1];

// =========================================
// 替换策略指针：Round-Robin (轮询FIFO)
// 根据 BTB_ENTRIES 自动计算指针位宽
// =========================================
localparam PTR_WIDTH = $clog2(`BTB_ENTRIES) > 0 ? $clog2(`BTB_ENTRIES) : 1;
reg [PTR_WIDTH-1:0] replace_ptr;

//─────────────────────────────────────────
// BTB 命中检测（用当前 PC 并行查表）
//─────────────────────────────────────────
reg [`BTB_ENTRIES-1:0] BTB_hit;
reg pre_pc_taken_comb;
reg [`INST_ADDR_WIDTH-1:0] pre_pc_comb;

integer i;
always @(*) begin
    // 默认值：不跳转，目标地址为0
    pre_pc_taken_comb = 1'b0;
    pre_pc_comb = 32'b0;
    BTB_hit = {`BTB_ENTRIES{1'b0}};

    // 展开为全相联的并行比较器
    for (i = 0; i < `BTB_ENTRIES; i = i + 1) begin
        BTB_hit[i] = (global_pc_o[`BTB_TAG_PC_HIGH:`BTB_TAG_PC_LOW]
                     == BTBuffer[i][`BTB_ENTRY_WIDTH-2:`BTB_TARGET_WIDTH]);
        
        // 如果命中，提取预测方向和目标地址
        if (BTB_hit[i]) begin
            pre_pc_taken_comb = BTBuffer[i][`BTB_ENTRY_WIDTH-1];
            pre_pc_comb = {BTBuffer[i][`BTB_TARGET_WIDTH-1:0], 2'b00};
        end
    end
end

wire [`INST_ADDR_WIDTH-1:0] pre_pc = pre_pc_comb;
assign pre_pc_taken = pre_pc_taken_comb;


//─────────────────────────────────────────
// PC 更新逻辑
//─────────────────────────────────────────
always @(posedge clk or negedge rst_n) begin
    if (~rst_n)
        global_pc_o <= `PC_RSTVAL;
    else if (pc_redirect_i)       // 最高优先级：纠正预测错误
        global_pc_o <= pc_correct_i;
    else if (ifu_ready_i) begin      // 次高优先级：如果不阻塞，才允许 PC 更新
        if (~pre_pc_taken)
            global_pc_o <= global_pc_o + 4;
        else
            global_pc_o <= pre_pc;
    end
end

assign global_pc_valid_o = rst_n;


//─────────────────────────────────────────
// BTB 更新（执行阶段反馈真实跳转结果）
//─────────────────────────────────────────
reg [`BTB_ENTRIES-1:0] btb_upd_hit;
reg upd_hit_any;

integer j;
always @(*) begin
    upd_hit_any = 1'b0;
    btb_upd_hit = {`BTB_ENTRIES{1'b0}};
    // 检查即将写入的 Tag 是否已经存在于 BTB 中
    for (j = 0; j < `BTB_ENTRIES; j = j + 1) begin
        btb_upd_hit[j] = (BTB_update[`BTB_ENTRY_WIDTH-2:`BTB_TARGET_WIDTH]
                         == BTBuffer[j][`BTB_ENTRY_WIDTH-2:`BTB_TARGET_WIDTH]);
        if (btb_upd_hit[j]) begin
            upd_hit_any = 1'b1;
        end
    end
end

integer k;
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        // 复位清空整个 BTB
        for (k = 0; k < `BTB_ENTRIES; k = k + 1) begin
            BTBuffer[k] <= {`BTB_ENTRY_WIDTH{1'b0}};
        end
        replace_ptr <= 0;
    end else if (BTB_update_valid) begin
        if (upd_hit_any) begin
            // 1. 如果命中，说明此分支指令以前来过，只需更新历史状态，不移动替换指针
            for (k = 0; k < `BTB_ENTRIES; k = k + 1) begin
                if (btb_upd_hit[k]) begin
                    BTBuffer[k] <= BTB_update;
                end
            end
        end else begin
            // 2. 如果未命中，说明是一个新的分支指令，覆盖当前指针位置的旧记录
            BTBuffer[replace_ptr] <= BTB_update;
            
            // 指针轮询递增
            if (replace_ptr == `BTB_ENTRIES - 1)
                replace_ptr <= 0;
            else
                replace_ptr <= replace_ptr + 1;
        end
    end
end

assign flush = pc_redirect_i;

endmodule