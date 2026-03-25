`include "defines.v"

module ls_ctrl(
    input clk,
    input rst_n,

    // ==========================================
    // 1. 与 TSP_Exu_ls (LSU前端) 交互接口
    // ==========================================
    input                               ls_req_i,        // 访存请求
    input                               ls_we_i,         // 1: Store写, 0: Load读
    input [31:0]                        ls_addr_i,       // 访存物理地址
    input [3:0]                         ls_byte_en_i,    // 字节写使能掩码
    input [31:0]                        ls_wdata_i,      // 对齐后的写入数据
    
    input [`REGFILE_IDX_WIDTH-1:0]      ls_rd,           // 目标寄存器
    input [2:0]                         ls_load_type,    // 0:LW, 1:LH, 2:LHU, 3:LB, 4:LBU
    
    output                              ls_ctrl_ready_o, // 访存就绪

    // ==========================================
    // 2. 与写回仲裁器交互接口
    // ==========================================
    output                              ls_ctrl_wb_en_o,   // Load指令完成，请求写回
    input                               wb_ls_ready_i,     // 写回就绪
    output [`REGFILE_IDX_WIDTH-1:0]     ls_ctrl_wb_rd_o,   // 写回的寄存器索引
    output [31:0]                       ls_ctrl_wb_data_o, // 符号扩展后的最终写回数据

    // ==========================================
    // 3. AXI4-Lite Master 接口 (对外访存)
    // ==========================================
    output reg [31:0] m_axi_awaddr,
    output reg        m_axi_awvalid,
    input  wire       m_axi_awready,

    output reg [31:0] m_axi_wdata,
    output reg [3:0]  m_axi_wstrb,
    output reg        m_axi_wvalid,
    input  wire       m_axi_wready,

    input  wire [1:0] m_axi_bresp,
    input  wire       m_axi_bvalid,
    output reg        m_axi_bready,

    output reg [31:0] m_axi_araddr,
    output reg        m_axi_arvalid,
    input  wire       m_axi_arready,

    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rvalid,
    output reg         m_axi_rready
);

// 状态机定义
localparam IDLE     = 3'd0;
localparam AXI_AW_W = 3'd1; // 等待写地址和写数据握手
localparam AXI_B    = 3'd2; // 等待写响应
localparam AXI_AR   = 3'd3; // 等待读地址握手
localparam AXI_R    = 3'd4; // 等待读数据响应
localparam WAIT_WB  = 3'd5; // 等待写回仲裁器同意 (Load 专用)

reg [2:0] state;

// 状态打拍 (用于截取数据)
reg [1:0]                    addr_align_r;
reg [2:0]                    load_type_r;
reg [`REGFILE_IDX_WIDTH-1:0] wb_rd_r;
reg [31:0]                   axi_read_data_r;

// 地址空间划分: >= 0x2000_0000 走 AXI 总线 (SRAM, UART等)
wire is_axi_mem = (ls_addr_i >= 32'h2000_0000);

                wire aw_done = m_axi_awready || !m_axi_awvalid;
                wire w_done  = m_axi_wready  || !m_axi_wvalid;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        state           <= IDLE;
        addr_align_r    <= 2'b0;
        load_type_r     <= 3'b0;
        wb_rd_r         <= 0;
        axi_read_data_r <= 32'b0;
        
        m_axi_awvalid   <= 1'b0;
        m_axi_wvalid    <= 1'b0;
        m_axi_bready    <= 1'b0;
        m_axi_arvalid   <= 1'b0;
        m_axi_rready    <= 1'b0;
        m_axi_awaddr    <= 32'b0;
        m_axi_wdata     <= 32'b0;
        m_axi_wstrb     <= 4'b0;
        m_axi_araddr    <= 32'b0;
    end else begin
        case (state)
            IDLE: begin
                if (ls_req_i) begin
                    addr_align_r <= ls_addr_i[1:0]; 
                    load_type_r  <= ls_load_type;
                    wb_rd_r      <= ls_rd;

                    if (is_axi_mem) begin
                        if (ls_we_i) begin 
                            state         <= AXI_AW_W;
                            m_axi_awaddr  <= ls_addr_i;
                            m_axi_wdata   <= ls_wdata_i;
                            m_axi_wstrb   <= ls_byte_en_i;
                            m_axi_awvalid <= 1'b1;
                            m_axi_wvalid  <= 1'b1;
                        end else begin     
                            state         <= AXI_AR;
                            m_axi_araddr  <= ls_addr_i;
                            m_axi_arvalid <= 1'b1;
                        end
                    end else begin
                        // 非 AXI 内存拦截，防死锁
                        if (ls_we_i) begin
                            state <= IDLE; 
                        end else begin
                            axi_read_data_r <= 32'b0;
                            state           <= WAIT_WB;
                        end
                    end
                end
            end
            
            // --- Write Flow ---
            AXI_AW_W: begin
                // 为了兼容不规范的外设(如自建 UART)，不要单独撤销 valid！
                // 只有当对方把 address 和 data 都吃进去(或即将吃进去)时，才统一放手。


                if (aw_done && w_done) begin
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    state         <= AXI_B;
                    m_axi_bready  <= 1'b1;
                end
            end
            
            AXI_B: begin
                if (m_axi_bvalid) begin
                    m_axi_bready <= 1'b0;
                    state        <= IDLE; 
                end
            end

            // --- Read Flow ---
            AXI_AR: begin
                if (m_axi_arready) begin
                    m_axi_arvalid <= 1'b0;
                    state         <= AXI_R;
                    m_axi_rready  <= 1'b1;
                end
            end
            
            AXI_R: begin
                if (m_axi_rvalid) begin
                    m_axi_rready    <= 1'b0;
                    axi_read_data_r <= m_axi_rdata; 
                    state           <= WAIT_WB;     
                end
            end
            
            WAIT_WB: begin
                if (wb_ls_ready_i) begin
                    state <= IDLE; 
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

assign ls_ctrl_ready_o = (state == AXI_B && m_axi_bvalid) | 
                         (state == WAIT_WB && wb_ls_ready_i) |
                         (state == IDLE && ls_req_i && ls_we_i && !is_axi_mem);

assign ls_ctrl_wb_en_o = (state == WAIT_WB);
assign ls_ctrl_wb_rd_o = wb_rd_r;

wire [31:0] shifted_data = axi_read_data_r >> ({addr_align_r, 3'b000});
reg  [31:0] final_wb_data;

always @(*) begin
    case (load_type_r)
        3'd0: final_wb_data = shifted_data;
        3'd1: final_wb_data = {{16{shifted_data[15]}}, shifted_data[15:0]};
        3'd2: final_wb_data = {16'b0, shifted_data[15:0]};
        3'd3: final_wb_data = {{24{shifted_data[7]}}, shifted_data[7:0]};
        3'd4: final_wb_data = {24'b0, shifted_data[7:0]};
        default: final_wb_data = 32'b0;
    endcase
end
assign ls_ctrl_wb_data_o = final_wb_data;

endmodule