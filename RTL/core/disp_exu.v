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
    output ls_we_o,       // 1: Store写, 0: Load读
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
// 【终极物理级修复】：嗅探 EX_COMMON 滞留结果！
wire rs1_common_match = common_wb_en && (common_rd != 5'd0) && (common_rd == rs1_i);
wire rs2_common_match = common_wb_en && (common_rd != 5'd0) && (common_rd == rs2_i);

wire rs1_wb_fw = wb_fw_en_i && (wb_fw_rd_i != 5'd0) && (wb_fw_rd_i == rs1_i);
wire rs2_wb_fw = wb_fw_en_i && (wb_fw_rd_i != 5'd0) && (wb_fw_rd_i == rs2_i);

// MUX 优先级：先看 ALU 滞留的最新结果，再看总线上的写回结果，最后看寄存器
wire [`REGFILE_DAT_WIDTH-1:0] rs1_op_dat = 
    rs1_common_match ? common_rd_op :
    rs1_wb_fw        ? wb_fw_dat_i  : rs1_op;

wire [`REGFILE_DAT_WIDTH-1:0] rs2_op_dat = 
    rs2_common_match ? common_rd_op :
    rs2_wb_fw        ? wb_fw_dat_i  : rs2_op;
    
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
// 跳转指令执行单元例化
//─────────────────────────────────────────
wire bjp_fire = global_fire & (RV32I_Btype | INST_JAL | INST_JALR);
Exu_bjp Exu_bjp_u0( 
    .clk(clk),
    .rst_n(rst_n),

    .bjp_pc(next_pc_i), 
    .INST_BJP(bjp_fire), 
    .INST_JALR(INST_JALR),

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
// Load-Store指令处理
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

// ====================================================================
// 完美的深度可调 OITF 计分板与反压系统 (Priority Allocation)
// ====================================================================
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

// OITF 核心存储器阵列 (基于 OITF_DEPTH 宏展开)
reg [`REGFILE_IDX_WIDTH-1:0] moitf [0:`OITF_DEPTH-1]; 
reg [`REGFILE_IDX_WIDTH-1:0] next_moitf [0:`OITF_DEPTH-1];

// OITF 探测雷达向量
reg [`OITF_DEPTH-1:0] slot_avail_vec;
reg [`OITF_DEPTH-1:0] rs1_hit_vec;
reg [`OITF_DEPTH-1:0] rs2_hit_vec;
reg [`OITF_DEPTH-1:0] rd_hit_vec;

// 遍历所有的槽位，进行依赖和空闲探测
integer j;
always @(*) begin
    for (j = 0; j < `OITF_DEPTH; j = j + 1) begin
        // 【终极物理安全气囊】：
        // 只有当前寄存器真正变为 0 时，该槽位才算空闲。绝不允许依赖 oitf_wb_en！
        // 彻底杜绝一条指令出去的瞬间，另一条指令钻进来产生的死锁冲突！
        slot_avail_vec[j] = (moitf[j] == 5'd0);
        
        rs1_hit_vec[j]    = (rs1_i == moitf[j]) && (moitf[j] != 5'd0);
        rs2_hit_vec[j]    = (rs2_i == moitf[j]) && (moitf[j] != 5'd0);
        rd_hit_vec[j]     = (rd_i  == moitf[j]) && (moitf[j] != 5'd0);
    end
end

// 满载与反压计算 (利用向量的按位或进行规约)
wire oitf_full = ~(|slot_avail_vec);
wire oitf_stall = INST_LONG & oitf_full;

// 依赖检测拦截 (RAW & WAW)
wire dep_hit_moitf = (|rs1_hit_vec) | (|rs2_hit_vec) | (|rd_hit_vec); 

wire target_unit_ready = 
    is_muldiv_inst ? exu_muldiv_ready :         
    is_ls_inst     ? exu_ls_ready :             
                     exu_common_ready;

// ==========================================
// 最终握手许可输出
// ==========================================
assign disp_exu_ready_o = target_unit_ready & (~dep_hit_moitf) & (~oitf_stall) & (~branch_in_flight);

// ====================================================================
// 深度的优先级编码分配逻辑 (Priority Allocation)
// ====================================================================
integer k;
reg allocated;
always @(*) begin
    // 默认保持原有数据
    for (k = 0; k < `OITF_DEPTH; k = k + 1) begin
        next_moitf[k] = moitf[k];
    end

    // 1. 先处理出队释放逻辑 (Clear)
    // 【修复】：移除 (oitf_wb_rd_i != 5'd0) 条件，防止写x0的指令无法出队导致OITF死锁
    if (oitf_wb_en_i) begin
        for (k = 0; k < `OITF_DEPTH; k = k + 1) begin
            if (moitf[k] == oitf_wb_rd_i) begin
                next_moitf[k] = 5'd0;
            end
        end
    end
    
    // 2. 再处理入队分配逻辑 (Allocate / Priority Encoder)
    allocated = 1'b0; // 防止一条指令分身占多个坑
    if (global_fire & INST_LONG & (rd_i != 5'd0)) begin
        for (k = 0; k < `OITF_DEPTH; k = k + 1) begin
            // 按从头到尾的顺序，自动寻找第一个物理空闲的坑位
            if (slot_avail_vec[k] && !allocated) begin
                next_moitf[k] = rd_i;
                allocated = 1'b1;
            end
        end
    end
end

integer idx;
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        for (idx = 0; idx < `OITF_DEPTH; idx = idx + 1) begin
            moitf[idx] <= 5'd0;
        end
    end else begin
        for (idx = 0; idx < `OITF_DEPTH; idx = idx + 1) begin
            moitf[idx] <= next_moitf[idx];
        end
    end
end

endmodule