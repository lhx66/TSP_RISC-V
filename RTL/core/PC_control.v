`include "defines.v"

//PC计数器 包含BPU
module PC_control #(
    parameter ENABLE_BTB = 1'b1
)(
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

// BTB 条目格式、字段位置由 defines.v 中宏定义确定
reg [`BTB_ENTRY_WIDTH-1:0] BTBuffer [0:`BTB_ENTRIES-1];
reg                         lru; // 0: entry0 为 LRU，1: entry1 为 LRU

//─────────────────────────────────────────
// BTB 命中检测（用当前 PC 查表）
//─────────────────────────────────────────
wire [`BTB_ENTRIES-1:0] BTB_hit;
assign BTB_hit[0] = (global_pc_o[`BTB_TAG_PC_HIGH:`BTB_TAG_PC_LOW]
                     == BTBuffer[0][`BTB_ENTRY_WIDTH-2:`BTB_TARGET_WIDTH]);
assign BTB_hit[1] = (global_pc_o[`BTB_TAG_PC_HIGH:`BTB_TAG_PC_LOW]
                     == BTBuffer[1][`BTB_ENTRY_WIDTH-2:`BTB_TARGET_WIDTH]);

//─────────────────────────────────────────
// 分支预测输出
//─────────────────────────────────────────
wire [`INST_ADDR_WIDTH-1:0] pre_pc;
assign pre_pc_taken = ENABLE_BTB &
                      ((BTB_hit[0] & BTBuffer[0][`BTB_ENTRY_WIDTH-1]) |
                       (BTB_hit[1] & BTBuffer[1][`BTB_ENTRY_WIDTH-1])); //1:跳转 0：不跳转

assign pre_pc       = BTB_hit[0] ? {BTBuffer[0][`BTB_TARGET_WIDTH-1:0], 2'b00} :
                                    {BTBuffer[1][`BTB_TARGET_WIDTH-1:0], 2'b00} ; // 未命中时值不使用


//─────────────────────────────────────────
// PC 更新
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

// 复位结束后 PC 立即有效（异步复位，rst_n 拉高时 PC 已持有 PC_RSTVAL）
assign global_pc_valid_o = rst_n;

//─────────────────────────────────────────
// BTB 更新（执行阶段反馈真实跳转结果）
// BTB_update 格式与 BTBuffer 条目相同
//─────────────────────────────────────────
wire btb_upd_hit0 = (BTB_update[`BTB_ENTRY_WIDTH-2:`BTB_TARGET_WIDTH]
                     == BTBuffer[0][`BTB_ENTRY_WIDTH-2:`BTB_TARGET_WIDTH]);
wire btb_upd_hit1 = (BTB_update[`BTB_ENTRY_WIDTH-2:`BTB_TARGET_WIDTH]
                     == BTBuffer[1][`BTB_ENTRY_WIDTH-2:`BTB_TARGET_WIDTH]);

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        BTBuffer[0] <= {`BTB_ENTRY_WIDTH{1'b0}};
        BTBuffer[1] <= {`BTB_ENTRY_WIDTH{1'b0}};
        lru         <= 1'b0;
    end else if (BTB_update_valid) begin
        if (btb_upd_hit0) begin
            BTBuffer[0] <= BTB_update;
            lru         <= 1'b1;
        end else if (btb_upd_hit1) begin
            BTBuffer[1] <= BTB_update;
            lru         <= 1'b0;
        end else begin
            if (~lru) begin
                BTBuffer[0] <= BTB_update;
                lru         <= 1'b1;
            end else begin
                BTBuffer[1] <= BTB_update;
                lru         <= 1'b0;
            end
        end
    end
end

assign flush = pc_redirect_i;

endmodule
