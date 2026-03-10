`include "defines.v"

module TSP_Core(
    input clk,
    input rst_n
`ifndef PROG_FPGA
    ,output debug_port
`endif
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
        .ifu_ready_i       (ifu_ready),      
        
        .pre_pc_taken_rr   (pre_pc_taken_rr),
        
        .BTB_update        (btb_update),
        .BTB_update_valid  (btb_update_valid),
        .pc_correct_i      (pc_correct),
        .pc_redirect_i     (pc_redirect),    
        
        .flush             (flush_net)       
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
        .ifu_ready_o     (ifu_ready),        
        .flush_i         (flush_net),
        
        .inst_o          (inst_if),
        .inst_valid_o    (inst_valid_if),
        .inst_pc_o       (inst_pc_if),
        .inst_err_o      (inst_err_if),
        
        .idec_ready_i    (idec_ready)        
    );

    // ====================================================================
    // 3. 译码单元 (IDEC) 与 级间冲刷 (Squashing)
    // ====================================================================
    wire [`REGFILE_IDX_WIDTH-1:0] rs1_idx, rs2_idx, rd_idx;
    wire [`REGFILE_DAT_WIDTH-1:0] imm;
    wire idec_valid;
    
    // 指令压扁逻辑
    wire id_valid_in = inst_valid_if & (~flush_net);

    // ------------------- 指令解码线网全声明 -------------------
    wire INST_ADD, INST_SUB, INST_SLL, INST_SLT, INST_SLTU;
    wire INST_XOR, INST_SRL, INST_SRA, INST_OR,  INST_AND;
    wire INST_ADDI, INST_SLTI, INST_SLTIU, INST_XORI;
    wire INST_ORI,  INST_ANDI, INST_SLLI,  INST_SRLI, INST_SRAI;
    wire INST_LB, INST_LH, INST_LW, INST_LBU, INST_LHU;
    wire INST_JALR, INST_FENCE;
    wire INST_ECALL, INST_EBREAK;
    wire INST_CSRRW, INST_CSRRS, INST_CSRRC, INST_CSRRWI, INST_CSRRSI, INST_CSRRCI;
    wire INST_SB, INST_SH, INST_SW;
    wire INST_BEQ, INST_BNE, INST_BLT, INST_BGE, INST_BLTU, INST_BGEU;
    wire RV32I_Btype;
    wire INST_LUI, INST_AUIPC, INST_JAL;
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
        
        .INST_ADD(INST_ADD), .INST_SUB(INST_SUB), .INST_SLL(INST_SLL), .INST_SLT(INST_SLT), .INST_SLTU(INST_SLTU),
        .INST_XOR(INST_XOR), .INST_SRL(INST_SRL), .INST_SRA(INST_SRA), .INST_OR(INST_OR),   .INST_AND(INST_AND),
        .INST_ADDI(INST_ADDI), .INST_SLTI(INST_SLTI), .INST_SLTIU(INST_SLTIU), .INST_XORI(INST_XORI),
        .INST_ORI(INST_ORI),   .INST_ANDI(INST_ANDI), .INST_SLLI(INST_SLLI),   .INST_SRLI(INST_SRLI), .INST_SRAI(INST_SRAI),
        .INST_LB(INST_LB),     .INST_LH(INST_LH),     .INST_LW(INST_LW),       .INST_LBU(INST_LBU),   .INST_LHU(INST_LHU),
        .INST_JALR(INST_JALR), .INST_FENCE(INST_FENCE),
        .INST_ECALL(INST_ECALL), .INST_EBREAK(INST_EBREAK),
        .INST_CSRRW(INST_CSRRW), .INST_CSRRS(INST_CSRRS), .INST_CSRRC(INST_CSRRC),
        .INST_CSRRWI(INST_CSRRWI),.INST_CSRRSI(INST_CSRRSI),.INST_CSRRCI(INST_CSRRCI),
        .INST_SB(INST_SB), .INST_SH(INST_SH), .INST_SW(INST_SW),
        .INST_BEQ(INST_BEQ), .INST_BNE(INST_BNE),   .INST_BLT(INST_BLT),
        .INST_BGE(INST_BGE), .INST_BLTU(INST_BLTU), .INST_BGEU(INST_BGEU),
        .INST_LUI(INST_LUI), .INST_AUIPC(INST_AUIPC), .INST_JAL(INST_JAL),
        .RV32I_Btype(RV32I_Btype),
        .RV32M_type(RV32M_type)
`ifdef USE_RV32M
        ,
        .INST_MUL(INST_MUL),     .INST_MULH(INST_MULH), .INST_MULHSU(INST_MULHSU), .INST_MULHU(INST_MULHU),
        .INST_DIV(INST_DIV),     .INST_DIVU(INST_DIVU), .INST_REM(INST_REM),       .INST_REMU(INST_REMU)
`endif
    );

    // ====================================================================
    // 4. 通用寄存器堆 (RegFile)
    // ====================================================================
    wire [`REGFILE_DAT_WIDTH-1:0] rs1_data, rs2_data;
    `ifndef PROG_FPGA
        assign debug_port = rs1_data[6]; // FPGA调试时输出
    `endif
    
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
    // 5. 跨模块交互线网声明 (Disp_Exu, Ls_Ctrl, Wb_Arbiter)
    // ====================================================================
    // 5.1 仲裁器 -> 执行模块 (Ready反压信号)
    wire wb_common_ready;
    wire wb_muldiv_ready;
    wire wb_ls_ready;

    // 5.2 仲裁器 -> Disp_Exu (OITF 清除专用信号)
    wire oitf_wb_en;
    wire [`REGFILE_IDX_WIDTH-1:0] oitf_wb_rd;

    // 5.3 执行模块 -> 仲裁器 (写回请求与数据)
    wire                          common_wb_en;
    wire [`REGFILE_IDX_WIDTH-1:0] common_rd;
    wire [`REGFILE_DAT_WIDTH-1:0] common_rd_op;

`ifdef USE_RV32M
    wire                          muldiv_wb_en;
    wire [`REGFILE_IDX_WIDTH-1:0] muldiv_rd;
    wire [`REGFILE_DAT_WIDTH-1:0] muldiv_rd_op;
`endif

    // 5.4 访存控制模块 -> 仲裁器 (Load指令写回请求与数据)
    wire                          ls_ctrl_wb_en;
    wire [`REGFILE_IDX_WIDTH-1:0] ls_ctrl_wb_rd;
    wire [`REGFILE_DAT_WIDTH-1:0] ls_ctrl_wb_data;

    // 5.5 Disp_Exu (LSU) <-> 访存控制模块 (内存读写请求总线)
    wire                          ls_req;
    wire                          ls_we;
    wire [`REGFILE_DAT_WIDTH-1:0] ls_addr;
    wire [3:0]                    ls_byte_en;
    wire [31:0]                   ls_wdata;
    wire [`REGFILE_IDX_WIDTH-1:0] ls_rd;
    wire [2:0]                    ls_load_type;
    wire                          ls_ctrl_ready;

    // ====================================================================
    // 6. 派遣与执行单元 (Disp & EXU)
    // ====================================================================
    wire [`INST_ADDR_WIDTH-1:0] disp_inst_pc;

    TSP_Disp_Exu u_TSP_Disp_Exu(
        .clk               (clk), 
        .rst_n             (rst_n),
        
        .idec_valid_i      (idec_valid),
        .disp_exu_ready_o  (disp_ready),       
        
        .rs1_i             (rs1_idx), 
        .rs1_op            (rs1_data),
        .rs2_i             (rs2_idx), 
        .rs2_op            (rs2_data),
        .rd_i              (rd_idx),  
        .imm_i             (imm),
        .next_pc_i         (inst_pc_if),
        .inst_pc_o         (disp_inst_pc),     
        
        .BTB_update        (btb_update),
        .BTB_update_valid  (btb_update_valid),
        .pc_correct_o      (pc_correct),
        .pc_redirect_o     (pc_redirect),      
        .pre_pc_taken_i    (pre_pc_taken_rr),
        
        .INST_ADD(INST_ADD), .INST_SUB(INST_SUB), .INST_SLL(INST_SLL), .INST_SLT(INST_SLT), .INST_SLTU(INST_SLTU),
        .INST_XOR(INST_XOR), .INST_SRL(INST_SRL), .INST_SRA(INST_SRA), .INST_OR(INST_OR),   .INST_AND(INST_AND),
        .INST_ADDI(INST_ADDI), .INST_SLTI(INST_SLTI), .INST_SLTIU(INST_SLTIU), .INST_XORI(INST_XORI),
        .INST_ORI(INST_ORI),   .INST_ANDI(INST_ANDI), .INST_SLLI(INST_SLLI),   .INST_SRLI(INST_SRLI), .INST_SRAI(INST_SRAI),
        .INST_LB(INST_LB),     .INST_LH(INST_LH),     .INST_LW(INST_LW),       .INST_LBU(INST_LBU),   .INST_LHU(INST_LHU),
        .INST_JALR(INST_JALR), .INST_FENCE(INST_FENCE),
        .INST_ECALL(INST_ECALL), .INST_EBREAK(INST_EBREAK),
        .INST_CSRRW(INST_CSRRW), .INST_CSRRS(INST_CSRRS), .INST_CSRRC(INST_CSRRC),
        .INST_CSRRWI(INST_CSRRWI),.INST_CSRRSI(INST_CSRRSI),.INST_CSRRCI(INST_CSRRCI),
        .INST_SB(INST_SB),     .INST_SH(INST_SH),     .INST_SW(INST_SW),
        .INST_BEQ(INST_BEQ),   .INST_BNE(INST_BNE),   .INST_BLT(INST_BLT),
        .INST_BGE(INST_BGE),   .INST_BLTU(INST_BLTU), .INST_BGEU(INST_BGEU),
        .INST_LUI(INST_LUI),   .INST_AUIPC(INST_AUIPC), .INST_JAL(INST_JAL),
        .RV32I_Btype(RV32I_Btype),
        .RV32M_type(RV32M_type),
        
`ifdef USE_RV32M
        .INST_MUL(INST_MUL),   .INST_MULH(INST_MULH), .INST_MULHSU(INST_MULHSU), .INST_MULHU(INST_MULHU),
        .INST_DIV(INST_DIV),   .INST_DIVU(INST_DIVU), .INST_REM(INST_REM),       .INST_REMU(INST_REMU),
`endif

        // 与写回仲裁器交互 (反压与输出)
        .wb_common_ready_i (wb_common_ready),
        .wb_ls_ready_i     (wb_ls_ready),
        .wb_muldiv_ready_i (wb_muldiv_ready),
        
        .common_wb_en      (common_wb_en),
        .common_rd_op      (common_rd_op),
        .common_rd         (common_rd),
        
`ifdef USE_RV32M
        .muldiv_wb_en      (muldiv_wb_en),
        .muldiv_rd_op      (muldiv_rd_op),
        .muldiv_rd         (muldiv_rd),
`endif
        
        // 接收仲裁器发来的 OITF 清除信号
        .oitf_wb_en_i      (oitf_wb_en),
        .oitf_wb_rd_i      (oitf_wb_rd),

        // 接收仲裁器的最终写回信号，用于 Forwarding
        .wb_fw_en_i(wb_en),   // 仲裁器最终的写使能
        .wb_fw_rd_i(wb_rd_idx),   // 仲裁器最终要写的寄存器号
        .wb_fw_dat_i(wb_data),  // 仲裁器最终要写的数据

        // 与访存控制模块交互
        .ls_ctrl_ready_i   (ls_ctrl_ready),
        .ls_req_o          (ls_req),
        .ls_we_o           (ls_we),
        .ls_addr_o         (ls_addr),
        .ls_byte_en_o      (ls_byte_en),
        .ls_wdata_o        (ls_wdata),
        .ls_rd             (ls_rd),
        .ls_load_type      (ls_load_type)
    );

    // ====================================================================
    // 7. 访存控制模块 & 内部 SRAM 模型 (LSU_Ctrl)
    // ====================================================================
    ls_ctrl u_ls_ctrl(
        .clk               (clk),
        .rst_n             (rst_n),
        
        // 接收来自 Disp_Exu 的请求
        .ls_req_i          (ls_req),
        .ls_we_i           (ls_we),
        .ls_addr_i         (ls_addr),
        .ls_byte_en_i      (ls_byte_en),
        .ls_wdata_i        (ls_wdata),
        .ls_rd             (ls_rd),
        .ls_load_type      (ls_load_type),
        
        // 发送完成信号给 Disp_Exu
        .ls_ctrl_ready_o   (ls_ctrl_ready),
        
        // 接收写回反压，并去往写回仲裁器
        .wb_ls_ready_i     (wb_ls_ready),
        .ls_ctrl_wb_en_o   (ls_ctrl_wb_en),
        .ls_ctrl_wb_rd_o   (ls_ctrl_wb_rd),
        .ls_ctrl_wb_data_o (ls_ctrl_wb_data)
    );

    // ====================================================================
    // 8. 终极三路写回仲裁器 (WB Arbiter)
    // ====================================================================
    TSP_Wb_arbiter u_TSP_Wb_arbiter(
        .clk               (clk),
        .rst_n             (rst_n),
        
        // 向上游执行模块输出写回许可
        .wb_common_ready_o (wb_common_ready),
        .wb_muldiv_ready_o (wb_muldiv_ready),
        .wb_ls_ready_o     (wb_ls_ready),
        
        // 接收普通执行单元写回
        .common_wb_en      (common_wb_en),
        .common_rd         (common_rd),
        .common_rd_op      (common_rd_op),
        
`ifdef USE_RV32M
        // 接收乘除法执行单元写回
        .muldiv_wb_en      (muldiv_wb_en),
        .muldiv_rd         (muldiv_rd),
        .muldiv_rd_op      (muldiv_rd_op),
`endif
        
        // 接收访存控制单元写回
        .ls_ctrl_wb_en     (ls_ctrl_wb_en),
        .ls_ctrl_wb_rd     (ls_ctrl_wb_rd),
        .ls_ctrl_wb_data   (ls_ctrl_wb_data),
        
        // 输出用于清除 OITF 的信号 (连回 Disp_Exu)
        .oitf_wb_en_o      (oitf_wb_en),
        .oitf_wb_rd_o      (oitf_wb_rd),
        
        // 最终输出到通用寄存器堆 (RegFile) 的统一写回口
        .wb_arbiter_en_o   (wb_en),
        .wb_arbiter_rd_o   (wb_rd_idx),
        .wb_arbiter_dat    (wb_data)
    );

endmodule