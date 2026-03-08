`include "defines.v"

module TSP_Core(
    input clk,
    input rst_n
);

    // ====================================================================
    // 全局网络连线
    // ====================================================================
    wire disp_ready;        // 反压网络：从派遣级一路传导至 PC
    wire flush_net;         // 冲刷网络：由 PC_control 发出，用于 Squashing
    
    wire [`INST_ADDR_WIDTH-1:0] global_pc;
    wire                        global_pc_valid;
    wire                        ifu_ready;
    
    wire [`BTB_ENTRY_WIDTH-1:0] btb_update;
    wire                        btb_update_valid;
    wire [`INST_ADDR_WIDTH-1:0] pc_correct;
    wire                        pc_redirect;
    wire                        pre_pc_taken_rr;

    // ====================================================================
    // 1. PC 控制器模块 (PC_control)
    // ====================================================================
    PC_control u_PC_control(
        .clk               (clk),
        .rst_n             (rst_n),
        
        .global_pc_o       (global_pc),
        .global_pc_valid_o (global_pc_valid),
        .ifu_ready_i       (ifu_ready),      // 接收下游的 ready 信号作为 PC 更新许可
        
        .pre_pc_taken_rr   (pre_pc_taken_rr),
        
        .BTB_update        (btb_update),
        .BTB_update_valid  (btb_update_valid),
        .pc_correct_i      (pc_correct),
        .pc_redirect_i     (pc_redirect),    // 接收执行级的预测错误重定向
        
        .flush             (flush_net)       // 输出冲刷信号
    );

    // ====================================================================
    // 2. 取指单元 (IFU)
    // ====================================================================
    wire [`INST_MAX_WIDTH-1:0]  inst_if;
    wire                        inst_valid_if;
    wire [`INST_ADDR_WIDTH-1:0] inst_pc_if;
    wire                        inst_err_if;
    wire                        idec_ready;

    TSP_Ifu u_TSP_Ifu(
        .clk             (clk),
        .rst_n           (rst_n),
        
        .next_pc_i       (global_pc),
        .ifu_permission  (global_pc_valid),
        .ifu_ready_o     (ifu_ready),        // 输出给 PC_control
        .flush_i         (flush_net),
        
        .inst_o          (inst_if),
        .inst_valid_o    (inst_valid_if),
        .inst_pc_o       (inst_pc_if),
        .inst_err_o      (inst_err_if),
        
        .idec_ready_i    (idec_ready)        // 接收译码级的 ready 信号
    );

    // ====================================================================
    // 3. 译码单元 (IDEC) 与 级间冲刷 (Squashing)
    // ====================================================================
    wire [`REGFILE_IDX_WIDTH-1:0] rs1_idx, rs2_idx, rd_idx;
    wire [`REGFILE_DAT_WIDTH-1:0] imm;
    wire idec_valid;

    // ------------------- 指令解码线网全声明 -------------------
    // R-type
    wire INST_ADD, INST_SUB, INST_SLL, INST_SLT, INST_SLTU;
    wire INST_XOR, INST_SRL, INST_SRA, INST_OR,  INST_AND;
    // I-type: OP-IMM
    wire INST_ADDI, INST_SLTI, INST_SLTIU, INST_XORI;
    wire INST_ORI,  INST_ANDI, INST_SLLI,  INST_SRLI, INST_SRAI;
    // I-type: LOAD
    wire INST_LB, INST_LH, INST_LW, INST_LBU, INST_LHU;
    // I-type: OTHER & SYSTEM
    wire INST_JALR, INST_FENCE;
    wire INST_ECALL, INST_EBREAK;
    wire INST_CSRRW, INST_CSRRS, INST_CSRRC, INST_CSRRWI, INST_CSRRSI, INST_CSRRCI;
    // S-type
    wire INST_SB, INST_SH, INST_SW;
    // B-type
    wire INST_BEQ, INST_BNE, INST_BLT, INST_BGE, INST_BLTU, INST_BGEU;
    wire RV32I_Btype;
    // U-type & J-type
    wire INST_LUI, INST_AUIPC, INST_JAL;
    // M-type
    wire RV32M_type;
`ifdef USE_RV32M
    wire INST_MUL, INST_MULH, INST_MULHSU, INST_MULHU;
    wire INST_DIV, INST_DIVU, INST_REM, INST_REMU;
`endif

    TSP_Idec u_TSP_Idec(
        .clk(clk), 
        .rst_n(rst_n),
        .inst_i(inst_if), 
        .inst_valid_i(id_valid_in), 
        .flush_i(flush_net),
        
        .idec_ready_o(idec_ready),
        .next_pc_i(inst_pc_if), 
        .inst_pc_o(), 
        
        .rs1_o(rs1_idx), 
        .rs2_o(rs2_idx), 
        .rd_o(rd_idx), 
        .imm_o(imm),
        
        .idec_valid_o(idec_valid), 
        .disp_ready_i(disp_ready),
        
        // R-type
        .INST_ADD(INST_ADD), .INST_SUB(INST_SUB), .INST_SLL(INST_SLL), .INST_SLT(INST_SLT), .INST_SLTU(INST_SLTU),
        .INST_XOR(INST_XOR), .INST_SRL(INST_SRL), .INST_SRA(INST_SRA), .INST_OR(INST_OR),   .INST_AND(INST_AND),
        // I-type
        .INST_ADDI(INST_ADDI), .INST_SLTI(INST_SLTI), .INST_SLTIU(INST_SLTIU), .INST_XORI(INST_XORI),
        .INST_ORI(INST_ORI),   .INST_ANDI(INST_ANDI), .INST_SLLI(INST_SLLI),   .INST_SRLI(INST_SRLI), .INST_SRAI(INST_SRAI),
        .INST_LB(INST_LB),     .INST_LH(INST_LH),     .INST_LW(INST_LW),       .INST_LBU(INST_LBU),   .INST_LHU(INST_LHU),
        .INST_JALR(INST_JALR), .INST_FENCE(INST_FENCE),
        .INST_ECALL(INST_ECALL), .INST_EBREAK(INST_EBREAK),
        .INST_CSRRW(INST_CSRRW), .INST_CSRRS(INST_CSRRS), .INST_CSRRC(INST_CSRRC),
        .INST_CSRRWI(INST_CSRRWI),.INST_CSRRSI(INST_CSRRSI),.INST_CSRRCI(INST_CSRRCI),
        // S-type
        .INST_SB(INST_SB), .INST_SH(INST_SH), .INST_SW(INST_SW),
        // B-type
        .INST_BEQ(INST_BEQ), .INST_BNE(INST_BNE),   .INST_BLT(INST_BLT),
        .INST_BGE(INST_BGE), .INST_BLTU(INST_BLTU), .INST_BGEU(INST_BGEU),
        // U-type & J-type
        .INST_LUI(INST_LUI), .INST_AUIPC(INST_AUIPC), .INST_JAL(INST_JAL),
        // Types
        .RV32I_Btype(RV32I_Btype),
        .RV32M_type(RV32M_type)
        
`ifdef USE_RV32M
        , // 注意这里的逗号
        .INST_MUL(INST_MUL),     .INST_MULH(INST_MULH), .INST_MULHSU(INST_MULHSU), .INST_MULHU(INST_MULHU),
        .INST_DIV(INST_DIV),     .INST_DIVU(INST_DIVU), .INST_REM(INST_REM),       .INST_REMU(INST_REMU)
`endif
    );

    // ====================================================================
    // 4. 通用寄存器堆 (RegFile)
    // ====================================================================
    wire [`REGFILE_DAT_WIDTH-1:0] rs1_data, rs2_data;
    
    // 留给写回仲裁器的统一写口
    wire                          wb_en;
    wire [`REGFILE_IDX_WIDTH-1:0] wb_rd_idx;
    wire [`REGFILE_DAT_WIDTH-1:0] wb_data;

    TSP_Regfiles u_TSP_Regfiles(
        .clk         (clk),
        .rst_n       (rst_n),
        
        .r_reg_idx1  (rs1_idx),      .r_dat1      (rs1_data),
        .r_reg_idx2  (rs2_idx),      .r_dat2      (rs2_data),
        
        .wb_en       (wb_en),
        .wb_reg_idx  (wb_rd_idx),
        .wb_dat      (wb_data)
    );

    // ====================================================================
    // 5. 派遣与执行单元 (Disp & EXU)
    // ====================================================================
    TSP_Disp_Exu u_TSP_Disp_Exu(
        .clk(clk), 
        .rst_n(rst_n),
        
        .idec_valid_i    (idec_valid),
        .disp_ready_o    (disp_ready),       
        
        .rs1_i(rs1_idx), .rs1_op(rs1_data),
        .rs2_i(rs2_idx), .rs2_op(rs2_data),
        .rd_i (rd_idx),  .imm_i (imm),
        .next_pc_i       (inst_pc_if),
        
        .inst_pc_o       (), 
        .BTB_update      (btb_update),
        .BTB_update_valid(btb_update_valid),
        .pre_pc_taken_i  (pre_pc_taken_rr),  // 已接上 BPU 的反馈
        .pc_correct_o    (pc_correct),
        .pc_redirect_o   (pc_redirect),      
        
        // R-type
        .INST_ADD(INST_ADD), .INST_SUB(INST_SUB), .INST_SLL(INST_SLL), .INST_SLT(INST_SLT), .INST_SLTU(INST_SLTU),
        .INST_XOR(INST_XOR), .INST_SRL(INST_SRL), .INST_SRA(INST_SRA), .INST_OR(INST_OR),   .INST_AND(INST_AND),
        // I-type
        .INST_ADDI(INST_ADDI), .INST_SLTI(INST_SLTI), .INST_SLTIU(INST_SLTIU), .INST_XORI(INST_XORI),
        .INST_ORI(INST_ORI),   .INST_ANDI(INST_ANDI), .INST_SLLI(INST_SLLI),   .INST_SRLI(INST_SRLI), .INST_SRAI(INST_SRAI),
        .INST_LB(INST_LB),     .INST_LH(INST_LH),     .INST_LW(INST_LW),       .INST_LBU(INST_LBU),   .INST_LHU(INST_LHU),
        .INST_JALR(INST_JALR), .INST_FENCE(INST_FENCE),
        .INST_ECALL(INST_ECALL), .INST_EBREAK(INST_EBREAK),
        .INST_CSRRW(INST_CSRRW), .INST_CSRRS(INST_CSRRS), .INST_CSRRC(INST_CSRRC),
        .INST_CSRRWI(INST_CSRRWI),.INST_CSRRSI(INST_CSRRSI),.INST_CSRRCI(INST_CSRRCI),
        // S-type
        .INST_SB(INST_SB), .INST_SH(INST_SH), .INST_SW(INST_SW),
        // B-type
        .INST_BEQ(INST_BEQ), .INST_BNE(INST_BNE),   .INST_BLT(INST_BLT),
        .INST_BGE(INST_BGE), .INST_BLTU(INST_BLTU), .INST_BGEU(INST_BGEU),
        // U-type & J-type
        .INST_LUI(INST_LUI), .INST_AUIPC(INST_AUIPC), .INST_JAL(INST_JAL),
        // Types
        .RV32I_Btype(RV32I_Btype),
        .RV32M_type(RV32M_type),
        
`ifdef USE_RV32M
        .INST_MUL(INST_MUL),     .INST_MULH(INST_MULH), .INST_MULHSU(INST_MULHSU), .INST_MULHU(INST_MULHU),
        .INST_DIV(INST_DIV),     .INST_DIVU(INST_DIVU), .INST_REM(INST_REM),       .INST_REMU(INST_REMU),
`endif

        // -----------------------------------------------------------
        // 写回接口 (等待你在 Disp_Exu 内部整合完成后，对接 RegFile)
        // 注意：要在 TSP_Disp_Exu 内部声明这些为 output
        // -----------------------------------------------------------
        /* .final_wb_en     (wb_en),
        .final_rd_idx    (wb_rd_idx),
        .final_rd_data   (wb_data),
        */
        
        .next_mo_ready   (1'b1), 
        .exu_valid_o     ()
    );

endmodule