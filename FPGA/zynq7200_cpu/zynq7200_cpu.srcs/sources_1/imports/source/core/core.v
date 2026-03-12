`include "defines.v"

module TSP_Core(
    input clk,
    input rst_n

    // ==========================================
    // 1. IFU 取指单元的 AXI4-Lite Slave 接口 (用于下载程序)
    // ==========================================
    // 写通道
    ,input  wire [31:0] s_axi_if_awaddr
    ,input  wire        s_axi_if_awvalid
    ,output wire        s_axi_if_awready
    ,input  wire [31:0] s_axi_if_wdata
    ,input  wire [3:0]  s_axi_if_wstrb
    ,input  wire        s_axi_if_wvalid
    ,output wire        s_axi_if_wready
    ,output wire [1:0]  s_axi_if_bresp
    ,output wire        s_axi_if_bvalid
    ,input  wire        s_axi_if_bready
    // 读通道
    ,input  wire [31:0] s_axi_if_araddr
    ,input  wire        s_axi_if_arvalid
    ,output wire        s_axi_if_arready
    ,output wire [31:0] s_axi_if_rdata
    ,output wire [1:0]  s_axi_if_rresp
    ,output wire        s_axi_if_rvalid
    ,input  wire        s_axi_if_rready

    // ==========================================
    // 2. LSU 访存单元的 AXI4-Lite Master 接口 (用于读写数据/外设)
    // ==========================================
    // 写通道
    ,output wire [31:0] m_axi_ls_awaddr
    ,output wire        m_axi_ls_awvalid
    ,input  wire        m_axi_ls_awready
    ,output wire [31:0] m_axi_ls_wdata
    ,output wire [3:0]  m_axi_ls_wstrb
    ,output wire        m_axi_ls_wvalid
    ,input  wire        m_axi_ls_wready
    ,input  wire [1:0]  m_axi_ls_bresp
    ,input  wire        m_axi_ls_bvalid
    ,output wire        m_axi_ls_bready
    // 读通道
    ,output wire [31:0] m_axi_ls_araddr
    ,output wire        m_axi_ls_arvalid
    ,input  wire        m_axi_ls_arready
    ,input  wire [31:0] m_axi_ls_rdata
    ,input  wire [1:0]  m_axi_ls_rresp
    ,input  wire        m_axi_ls_rvalid
    ,output wire        m_axi_ls_rready
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
    // 2. 取指单元 (IFU) - 已接入 AXI-Lite Slave
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
        .idec_ready_i    (idec_ready),
        
        // AXI4-Lite Slave 接口连线
        .s_axi_awaddr    (s_axi_if_awaddr),
        .s_axi_awvalid   (s_axi_if_awvalid),
        .s_axi_awready   (s_axi_if_awready),
        .s_axi_wdata     (s_axi_if_wdata),
        .s_axi_wstrb     (s_axi_if_wstrb),
        .s_axi_wvalid    (s_axi_if_wvalid),
        .s_axi_wready    (s_axi_if_wready),
        .s_axi_bresp     (s_axi_if_bresp),
        .s_axi_bvalid    (s_axi_if_bvalid),
        .s_axi_bready    (s_axi_if_bready),
        .s_axi_araddr    (s_axi_if_araddr),
        .s_axi_arvalid   (s_axi_if_arvalid),
        .s_axi_arready   (s_axi_if_arready),
        .s_axi_rdata     (s_axi_if_rdata),
        .s_axi_rresp     (s_axi_if_rresp),
        .s_axi_rvalid    (s_axi_if_rvalid),
        .s_axi_rready    (s_axi_if_rready)
    );

    // ====================================================================
    // 3. 译码单元 (IDEC) 
    // ====================================================================
    wire [`REGFILE_IDX_WIDTH-1:0] rs1_idx, rs2_idx, rd_idx;
    wire [`REGFILE_DAT_WIDTH-1:0] imm;
    wire idec_valid;
    
    wire id_valid_in = inst_valid_if & (~flush_net);

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
    // 5. 跨模块交互线网声明
    // ====================================================================
    wire wb_common_ready;
    wire wb_muldiv_ready;
    wire wb_ls_ready;

    wire oitf_wb_en;
    wire [`REGFILE_IDX_WIDTH-1:0] oitf_wb_rd;

    wire                          common_wb_en;
    wire [`REGFILE_IDX_WIDTH-1:0] common_rd;
    wire [`REGFILE_DAT_WIDTH-1:0] common_rd_op;

`ifdef USE_RV32M
    wire                          muldiv_wb_en;
    wire [`REGFILE_IDX_WIDTH-1:0] muldiv_rd;
    wire [`REGFILE_DAT_WIDTH-1:0] muldiv_rd_op;
`endif

    wire                          ls_ctrl_wb_en;
    wire [`REGFILE_IDX_WIDTH-1:0] ls_ctrl_wb_rd;
    wire [`REGFILE_DAT_WIDTH-1:0] ls_ctrl_wb_data;

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
        
        .oitf_wb_en_i      (oitf_wb_en),
        .oitf_wb_rd_i      (oitf_wb_rd),

        .wb_fw_en_i(wb_en),   
        .wb_fw_rd_i(wb_rd_idx),   
        .wb_fw_dat_i(wb_data),  

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
    // 7. 访存控制模块 & AXI Master (LSU_Ctrl)
    // ====================================================================
    ls_ctrl u_ls_ctrl(
        .clk               (clk),
        .rst_n             (rst_n),
        
        .ls_req_i          (ls_req),
        .ls_we_i           (ls_we),
        .ls_addr_i         (ls_addr),
        .ls_byte_en_i      (ls_byte_en),
        .ls_wdata_i        (ls_wdata),
        .ls_rd             (ls_rd),
        .ls_load_type      (ls_load_type),
        
        .ls_ctrl_ready_o   (ls_ctrl_ready),
        
        .wb_ls_ready_i     (wb_ls_ready),
        .ls_ctrl_wb_en_o   (ls_ctrl_wb_en),
        .ls_ctrl_wb_rd_o   (ls_ctrl_wb_rd),
        .ls_ctrl_wb_data_o (ls_ctrl_wb_data),

        // AXI4-Lite Master 接口连线
        .m_axi_awaddr      (m_axi_ls_awaddr),
        .m_axi_awvalid     (m_axi_ls_awvalid),
        .m_axi_awready     (m_axi_ls_awready),
        .m_axi_wdata       (m_axi_ls_wdata),
        .m_axi_wstrb       (m_axi_ls_wstrb),
        .m_axi_wvalid      (m_axi_ls_wvalid),
        .m_axi_wready      (m_axi_ls_wready),
        .m_axi_bresp       (m_axi_ls_bresp),
        .m_axi_bvalid      (m_axi_ls_bvalid),
        .m_axi_bready      (m_axi_ls_bready),
        .m_axi_araddr      (m_axi_ls_araddr),
        .m_axi_arvalid     (m_axi_ls_arvalid),
        .m_axi_arready     (m_axi_ls_arready),
        .m_axi_rdata       (m_axi_ls_rdata),
        .m_axi_rresp       (m_axi_ls_rresp),
        .m_axi_rvalid      (m_axi_ls_rvalid),
        .m_axi_rready      (m_axi_ls_rready)
    );

    // ====================================================================
    // 8. 终极三路写回仲裁器 (WB Arbiter)
    // ====================================================================
    TSP_Wb_arbiter u_TSP_Wb_arbiter(
        .clk               (clk),
        .rst_n             (rst_n),
        
        .wb_common_ready_o (wb_common_ready),
        .wb_muldiv_ready_o (wb_muldiv_ready),
        .wb_ls_ready_o     (wb_ls_ready),
        
        .common_wb_en      (common_wb_en),
        .common_rd         (common_rd),
        .common_rd_op      (common_rd_op),
        
`ifdef USE_RV32M
        .muldiv_wb_en      (muldiv_wb_en),
        .muldiv_rd         (muldiv_rd),
        .muldiv_rd_op      (muldiv_rd_op),
`endif
        
        .ls_ctrl_wb_en     (ls_ctrl_wb_en),
        .ls_ctrl_wb_rd     (ls_ctrl_wb_rd),
        .ls_ctrl_wb_data   (ls_ctrl_wb_data),
        
        .oitf_wb_en_o      (oitf_wb_en),
        .oitf_wb_rd_o      (oitf_wb_rd),
        
        .wb_arbiter_en_o   (wb_en),
        .wb_arbiter_rd_o   (wb_rd_idx),
        .wb_arbiter_dat    (wb_data)
    );

endmodule