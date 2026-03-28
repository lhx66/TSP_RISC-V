`include "defines.v"

module TSP_Disp_Exu( //dispatch 发射\派遣\执行
    input clk,
    input rst_n,

    //译码模块交互
    input idec_valid_i,
    output disp_exu_ready_o,
    
    //译码结果
    input [`REGFILE_IDX_WIDTH-1:0] rs1_i,      //源寄存器1索引
    input [`REGFILE_DAT_WIDTH-1:0] rs1_op, 
    input [`REGFILE_IDX_WIDTH-1:0] rs2_i,      //源寄存器2索引
    input [`REGFILE_DAT_WIDTH-1:0] rs2_op,
    input [`REGFILE_IDX_WIDTH-1:0] rd_i,       //目标寄存器索引
    input [`REGFILE_DAT_WIDTH-1:0] imm_i,      //符号扩展后的立即数
    input [`INST_ADDR_WIDTH-1:0] next_pc_i,    //指示待派遣的指令PC
    output [`INST_ADDR_WIDTH-1:0] inst_pc_o,   //指示本级流水后的指令PC  
    
    //程序计数器交互
    output [`BTB_ENTRY_WIDTH-1:0] BTB_update,       // 格式见 defines.v BTB字段布局
    output                        BTB_update_valid,  // 执行阶段写回BTB
    output [`INST_ADDR_WIDTH-1:0] pc_correct_o,  // 正确的下一条 PC
    output                        pc_redirect_o,   // 预测错误，强制重定向
    input                         pre_pc_taken_i,  // 连接pre_pc_taken_rr
    
    // R-type
    input INST_ADD, INST_SUB, INST_SLL, INST_SLT, INST_SLTU,
    input INST_XOR, INST_SRL, INST_SRA, INST_OR,  INST_AND,
    // I-type：OP-IMM
    input INST_ADDI, INST_SLTI, INST_SLTIU, INST_XORI,
    input INST_ORI,  INST_ANDI, INST_SLLI,  INST_SRLI, INST_SRAI,
    // I-type：LOAD
    input INST_LB, INST_LH, INST_LW, INST_LBU, INST_LHU,
    // I-type：其他
    input INST_JALR, INST_FENCE,
    // I-type：SYSTEM
    input INST_ECALL, INST_EBREAK,
    input INST_CSRRW, INST_CSRRS, INST_CSRRC,
    input INST_CSRRWI,INST_CSRRSI,INST_CSRRCI,
    // S-type
    input INST_SB, INST_SH, INST_SW,
    // B-type
    input INST_BEQ, INST_BNE, INST_BLT,
    input INST_BGE, INST_BLTU,INST_BGEU,
    // U-type
    input INST_LUI, INST_AUIPC,
    // J-type
    input INST_JAL,
`ifdef USE_RV32M
    // M-type
    input INST_MUL,  INST_MULH, INST_MULHSU, INST_MULHU,
    input INST_DIV,  INST_DIVU, INST_REM,    INST_REMU,
`endif
    input RV32I_Btype, //供BPU使用
    input RV32M_type,

    //与写回仲裁器交互
    input wb_common_ready_i,
    input wb_ls_ready_i,
    input wb_muldiv_ready_i, //多周期指令写回许可
    output common_wb_en,
    output [`REGFILE_DAT_WIDTH-1:0] common_rd_op,
    output [`REGFILE_IDX_WIDTH-1:0] common_rd,
`ifdef USE_RV32M
    output muldiv_wb_en,
    output [`REGFILE_DAT_WIDTH-1:0] muldiv_rd_op,
    output [`REGFILE_IDX_WIDTH-1:0] muldiv_rd,
`endif
    input oitf_wb_en_i,
    input [`REGFILE_IDX_WIDTH-1:0] oitf_wb_rd_i,
    
    // 接收写回仲裁器的最终写回信号，用于 Forwarding
    input                           wb_fw_en_i,   // 仲裁器最终的写使能
    input  [`REGFILE_IDX_WIDTH-1:0] wb_fw_rd_i,   // 仲裁器最终要写的寄存器号
    input  [`REGFILE_DAT_WIDTH-1:0] wb_fw_dat_i,  // 仲裁器最终要写的数据
    
    //与访存控制模块交互
    input ls_ctrl_ready_i, //访存就绪
    output ls_req_o, 
    output         ls_we_o,       // 1: Store写, 0: Load读
    output [`REGFILE_DAT_WIDTH-1:0] ls_addr_o,
    output [3:0]  ls_byte_en_o,  // 字节写使能掩码 (Byte Enable)
    output [31:0] ls_wdata_o,    // 对齐后的写入数据
    output [`REGFILE_IDX_WIDTH-1:0] ls_rd,
    output [2:0]  ls_load_type   // 0:LW, 1:LH, 2:LHU, 3:LB, 4:LBU
);

// 派遣-执行模块全局执行许可
wire global_fire = idec_valid_i & disp_exu_ready_o;

// 打拍当前PC
REGs_WLWR #(`INST_ADDR_WIDTH, 0) DECODE_PC_REG1(global_fire, next_pc_i, inst_pc_o, clk, rst_n);

wire branch_taken;
wire [`REGFILE_DAT_WIDTH-1:0] bjp_cal_pre_pc;

// ==========================================
// 数据旁路前推网络 (Data Forwarding)
// ==========================================
// 旁路拦截条件：写使能有效 && 目标不是 x0 && 目标刚好是我需要的源寄存器
wire rs1_forward_match = wb_fw_en_i && (wb_fw_rd_i != 5'd0) && (wb_fw_rd_i == rs1_i);
wire rs2_forward_match = wb_fw_en_i && (wb_fw_rd_i != 5'd0) && (wb_fw_rd_i == rs2_i);

// MUX 选择：如果命中旁路，用仲裁器总线上的热乎数据；否则老老实实用寄存器读出的数据
wire [`REGFILE_DAT_WIDTH-1:0] rs1_op_dat = rs1_forward_match ? wb_fw_dat_i : rs1_op;
wire [`REGFILE_DAT_WIDTH-1:0] rs2_op_dat = rs2_forward_match ? wb_fw_dat_i : rs2_op;

//─────────────────────────────────────────
// I-common 执行单元例化
//─────────────────────────────────────────
wire exu_common_ready;
wire [`REGFILE_DAT_WIDTH-1:0] ls_addr_adder_result;
TSP_Exu_common Exu_common_u0( //通用加法器及其他基础指令
    .clk(clk),
    .rst_n(rst_n),

    .idec_valid_i(global_fire), 
    .exu_common_ready_o(exu_common_ready),
    .rs1_op(rs1_op_dat),         
    .rs2_op(rs2_op_dat),         
    .rd_i(rd_i),            
    .imm_i(imm_i),          
    .bjp_pc(next_pc_i),         

    .rd_op(common_rd_op),      
    .rd_o(common_rd),          
    .common_wb_en(common_wb_en),      
    .wb_common_ready_i(wb_common_ready_i),
    .branch_taken(branch_taken), 
    .bjp_cal_pre_pc(bjp_cal_pre_pc),
    .ls_addr_adder_result(ls_addr_adder_result),

    //指令类型
    .INST_ADD(INST_ADD), .INST_SUB(INST_SUB), .INST_XOR(INST_XOR), .INST_OR(INST_OR), .INST_AND(INST_AND),
    .INST_SLL(INST_SLL), .INST_SRL(INST_SRL), .INST_SRA(INST_SRA), .INST_SLT(INST_SLT), .INST_SLTU(INST_SLTU),
    .INST_ADDI(INST_ADDI), .INST_XORI(INST_XORI), .INST_ORI(INST_ORI), .INST_ANDI(INST_ANDI),
    .INST_SLLI(INST_SLLI), .INST_SRLI(INST_SRLI), .INST_SRAI(INST_SRAI), .INST_SLTI(INST_SLTI), .INST_SLTIU(INST_SLTIU),
    .INST_LUI(INST_LUI), .INST_AUIPC(INST_AUIPC),
    .INST_JAL(INST_JAL), .INST_JALR(INST_JALR),
    .RV32I_Btype(RV32I_Btype),
    .INST_BEQ(INST_BEQ), .INST_BNE(INST_BNE), .INST_BLT(INST_BLT), .INST_BGE(INST_BGE), .INST_BLTU(INST_BLTU), .INST_BGEU(INST_BGEU),
    .INST_LB(INST_LB), .INST_LH(INST_LH), .INST_LW(INST_LW), .INST_LBU(INST_LBU), .INST_LHU(INST_LHU),
    .INST_SB(INST_SB), .INST_SH(INST_SH), .INST_SW(INST_SW)
);

//─────────────────────────────────────────
// 跳转指令执行单元例化（复用加法器）
//─────────────────────────────────────────
wire bjp_fire = global_fire & (RV32I_Btype | INST_JAL | INST_JALR);

Exu_bjp Exu_bjp_u0( //级联在Exu_common后
    .clk(clk),
    .rst_n(rst_n),

    .bjp_pc(next_pc_i), 
    .INST_BJP(bjp_fire), 
    .INST_JALR(INST_JALR), // 将JALR识别传入，用于纠正幽灵跳

    .branch_taken(branch_taken), 
    .bjp_cal_pre_pc(bjp_cal_pre_pc), 

    .global_pc_i(inst_pc_o),  
    .BTB_update(BTB_update),       
    .BTB_update_valid(BTB_update_valid),  
    .pre_pc_taken_i(pre_pc_taken_i),

    .pc_correct_o(pc_correct_o),  
    .pc_redirect_o(pc_redirect_o)   
);

//─────────────────────────────────────────
// M-type 乘除法执行单元例化
//─────────────────────────────────────────
`ifdef USE_RV32M
wire exu_muldiv_ready;
TSP_Exu_muldiv Exu_muldiv_u0(
    .clk(clk),
    .rst_n(rst_n),

    .inst_dec_valid_i(global_fire),
    .exu_ready_o(exu_muldiv_ready),

    .rs1_op(rs1_op_dat),
    .rs2_op(rs2_op_dat),
    .rd_i(rd_i),

    .rd_op(muldiv_rd_op),
    .rd_o(muldiv_rd),
    .wb_en(muldiv_wb_en),
    .wb_muldiv_ready_i(wb_muldiv_ready_i),

    .INST_MUL(INST_MUL), .INST_MULH(INST_MULH), .INST_MULHSU(INST_MULHSU), .INST_MULHU(INST_MULHU),
    .INST_DIV(INST_DIV), .INST_DIVU(INST_DIVU), .INST_REM(INST_REM), .INST_REMU(INST_REMU)
);
`else
wire exu_muldiv_ready = 1'b1; 
`endif

//─────────────────────────────────────────
// Load-Store指令处理（复用common中加法器）
//─────────────────────────────────────────
wire exu_ls_ready;
TSP_Exu_ls Exu_ls_u0(
    .clk(clk),
    .rst_n(rst_n),

    .idec_valid_i(global_fire),
    .exu_ls_ready_o(exu_ls_ready),       

    .INST_LB(INST_LB), .INST_LH(INST_LH), .INST_LW(INST_LW), .INST_LBU(INST_LBU), .INST_LHU(INST_LHU),
    .INST_SB(INST_SB), .INST_SH(INST_SH), .INST_SW(INST_SW),
    
    .rs2_op(rs2_op_dat), 
    .rd_i(rd_i),

    .ls_addr_i(ls_addr_adder_result), 

    .ls_req_o(ls_req_o),      
    .ls_we_o(ls_we_o),       
    .ls_addr_o(ls_addr_o),
    .ls_byte_en_o(ls_byte_en_o),  
    .ls_wdata_o(ls_wdata_o),    
    
    .ls_ctrl_ready_i(ls_ctrl_ready_i),   
    
    .ls_load_type_o(ls_load_type), 
    .ls_rd_o(ls_rd)      
);

//─────────────────────────────────────────
// 完美的 OITF 计分板与反压系统 (无组合环路版)
//─────────────────────────────────────────
// 1. 精确的指令分类判定
wire is_load_inst   = INST_LB | INST_LH | INST_LW | INST_LBU | INST_LHU;
wire is_store_inst  = INST_SB | INST_SH | INST_SW;
wire is_ls_inst     = is_load_inst | is_store_inst;

`ifdef USE_RV32M
    wire is_muldiv_inst = INST_MUL | INST_MULH | INST_MULHSU | INST_MULHU | 
                          INST_DIV | INST_DIVU | INST_REM | INST_REMU;
`else
    wire is_muldiv_inst = 1'b0;
`endif

wire INST_LONG = is_muldiv_inst | is_load_inst;
wire is_branch_inst = RV32I_Btype | INST_JAL | INST_JALR;

reg branch_in_flight;
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) branch_in_flight <= 1'b0;
    else if (global_fire && is_branch_inst) branch_in_flight <= 1'b1;
    else branch_in_flight <= 1'b0;
end

reg [`REGFILE_IDX_WIDTH-1:0] moitf0, moitf1; 
reg [`REGFILE_IDX_WIDTH-1:0] next_moitf0, next_moitf1;

// ====================================================================
// 【终极修复 1】：彻底剪断组合逻辑环路！
// 提前计算槽位是否可用，完全不依赖 global_fire，防止产生死锁振荡！
// ====================================================================
wire slot0_avail = (moitf0 == 5'd0) || (oitf_wb_en_i && (moitf0 == oitf_wb_rd_i));
wire slot1_avail = (moitf1 == 5'd0) || (oitf_wb_en_i && (moitf1 == oitf_wb_rd_i));

// 判断满载，必须只用“当前是否可用”进行判断
wire oitf_full = !(slot0_avail || slot1_avail);
wire oitf_stall = INST_LONG & oitf_full;

// 依赖检测 (RAW & WAW)
wire rs1_hit_moitf0 = (rs1_i == moitf0) && (moitf0 != 5'd0);
wire rs1_hit_moitf1 = (rs1_i == moitf1) && (moitf1 != 5'd0);
wire rs2_hit_moitf0 = (rs2_i == moitf0) && (moitf0 != 5'd0);
wire rs2_hit_moitf1 = (rs2_i == moitf1) && (moitf1 != 5'd0);
wire rd_hit_moitf0  = (rd_i  == moitf0) && (moitf0 != 5'd0);
wire rd_hit_moitf1  = (rd_i  == moitf1) && (moitf1 != 5'd0);

wire dep_hit_moitf = rs1_hit_moitf0 | rs1_hit_moitf1 | 
                     rs2_hit_moitf0 | rs2_hit_moitf1 |
                     rd_hit_moitf0  | rd_hit_moitf1; 

wire target_unit_ready = 
    is_muldiv_inst ? exu_muldiv_ready :         
    is_ls_inst     ? exu_ls_ready :             
                     exu_common_ready;          

// ==========================================
// 最终握手许可输出 (提前计算，绝不振荡)
// ==========================================
assign disp_exu_ready_o = target_unit_ready & (~dep_hit_moitf) & (~oitf_stall) & (~branch_in_flight);

// ====================================================================
// 【终极修复 2】：安全的 OITF 状态更新逻辑
// ====================================================================
always @(*) begin
    next_moitf0 = moitf0;
    next_moitf1 = moitf1;
    
    // 1. 先处理出队释放逻辑 (Clear)
    if (oitf_wb_en_i) begin
        if (moitf0 == oitf_wb_rd_i) next_moitf0 = 5'd0;
        if (moitf1 == oitf_wb_rd_i) next_moitf1 = 5'd0;
    end
    
    // 2. 再处理入队分配逻辑 (Allocate)
    // 此时 global_fire 的判断已经绝对稳定，不会再回头改变 disp_exu_ready_o
    if (global_fire & INST_LONG & (rd_i != 5'd0)) begin
        if (slot0_avail)      next_moitf0 = rd_i;
        else if (slot1_avail) next_moitf1 = rd_i;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        moitf0 <= 5'd0; 
        moitf1 <= 5'd0;
    end else begin
        moitf0 <= next_moitf0;
        moitf1 <= next_moitf1;
    end
end

endmodule