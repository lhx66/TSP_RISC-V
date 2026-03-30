`include "defines.v"

module ls_ctrl(
    input clk,
    input rst_n,

    // 1. 与 TSP_Exu_ls (LSU前端) 交互接口
    input                               ls_req_i,        
    input                               ls_we_i,         
    input [31:0]                        ls_addr_i,       
    input [3:0]                         ls_byte_en_i,    
    input [31:0]                        ls_wdata_i,      
    
    input [`REGFILE_IDX_WIDTH-1:0]      ls_rd,           
    input [2:0]                         ls_load_type,    
    output                              ls_ctrl_ready_o, 

    // 2. 与写回仲裁器交互接口
    output                              ls_ctrl_wb_en_o,   
    input                               wb_ls_ready_i,     
    output [`REGFILE_IDX_WIDTH-1:0]     ls_ctrl_wb_rd_o,   
    output [31:0]                       ls_ctrl_wb_data_o, 

    // 3. AXI4-Lite Master 接口 (对外访存)
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

// ==========================================
// 状态机定义
// ==========================================
localparam IDLE     = 3'd0;
localparam AXI_AW_W = 3'd1;
localparam AXI_B    = 3'd2; 
localparam AXI_AR   = 3'd3;
localparam AXI_R    = 3'd4; 
localparam WAIT_WB  = 3'd5; 

reg [2:0] state;
reg [1:0]                    addr_align_r;
reg [2:0]                    load_type_r;
reg [`REGFILE_IDX_WIDTH-1:0] wb_rd_r;
reg [31:0]                   axi_read_data_r;

// ====================================================================
// 【核心防线 1】：精准映射内存，并开启硬件级只读写保护（MPU）
// ====================================================================
// 识别 0x0000_xxxx 区域为 IRAM
wire is_iram = (ls_addr_i[31:28] == 4'h0);

// 合法 AXI 寻址空间：IRAM(0x0), SRAM(0x2), UART(0x4)
wire is_axi_mem = (ls_addr_i[31:28] == `SRAM_ADDR) || 
                  (ls_addr_i[31:28] == `UART_ADDR) || 
                  (ls_addr_i[31:28] == `TIMER_ADDR) ||  // <=== 加上这一行！
                  is_iram;

// 写保护：如果试图在 IRAM 区域执行 Store 写入操作，直接拦截！
wire write_protect = is_iram & ls_we_i;

// ====================================================================
// 【终极防线】：AXI WDATA 写数据通道对齐器
// AXI 协议严格要求：数据必须根据 wstrb 放置在对应的字节通道上！
// ====================================================================
wire [31:0] aligned_wdata;
assign aligned_wdata = 
    (ls_byte_en_i == 4'b0001) ? {24'b0, ls_wdata_i[7:0]} :
    (ls_byte_en_i == 4'b0010) ? {16'b0, ls_wdata_i[7:0], 8'b0} :
    (ls_byte_en_i == 4'b0100) ? {8'b0,  ls_wdata_i[7:0], 16'b0} :
    (ls_byte_en_i == 4'b1000) ? {ls_wdata_i[7:0], 24'b0} :
    (ls_byte_en_i == 4'b0011) ? {16'b0, ls_wdata_i[15:0]} :
    (ls_byte_en_i == 4'b1100) ? {ls_wdata_i[15:0], 16'b0} :
    ls_wdata_i; // 对于 4'b1111 (sw) 保留原样

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
                    
                    // 如果是有效 AXI 内存，且没有触发 MPU 写保护
                    if (is_axi_mem && !write_protect) begin
                        if (ls_we_i) begin 
                            state         <= AXI_AW_W;
                            m_axi_awaddr  <= {ls_addr_i[31:2], 2'b00};
                            m_axi_wdata   <= aligned_wdata;
                            m_axi_wstrb   <= ls_byte_en_i;
                            m_axi_awvalid <= 1'b1;
                            m_axi_wvalid  <= 1'b1;
                        end else begin     
                            state         <= AXI_AR;
                            m_axi_araddr  <= {ls_addr_i[31:2], 2'b00};
                            m_axi_arvalid <= 1'b1;
                        end
                    end else begin
                        /// 触发写保护，或者非法内存地址，必须假装执行一拍！
                        if (ls_we_i) begin
                            // 【修复】：强行跳过 AXI，直接去 WAIT_WB 清空流水线，防止死锁
                            state <= WAIT_WB; 
                        end else begin
                            axi_read_data_r <= 32'b0;
                            state           <= WAIT_WB;
                        end
                    end
                end
            end
            
            // ====================================================================
            // 【核心防线 2】：标准的、防死锁的 AXI 写握手逻辑
            // ====================================================================
            AXI_AW_W: begin
                // 一旦对应的通道收到 ready，立刻将 valid 拉低，绝不多占一拍！
                if (m_axi_awvalid && m_axi_awready) m_axi_awvalid <= 1'b0;
                if (m_axi_wvalid  && m_axi_wready)  m_axi_wvalid  <= 1'b0;
                
                // 当两个通道的 valid 都已经拉低，或者当前拍恰好全接收，进入等待响应
                if ((!m_axi_awvalid || m_axi_awready) && (!m_axi_wvalid || m_axi_wready)) begin
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
                // 写回仲裁器准备接收数据时，结束本轮访存
                if (wb_ls_ready_i) begin
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

// ====================================================================
// 【核心防线 3】：写保护拦截后的假装握手 (Fake Ready)
// ====================================================================
// 识别被丢弃的非法写入（防止 LSU 永远得不到响应而死锁）
wire write_dropped = (state == IDLE) && ls_req_i && ls_we_i && (!is_axi_mem || write_protect);

assign ls_ctrl_ready_o = (state == IDLE);//修改，等到访存就绪才发出 ready 信号

// ==========================================
// 读数据字节对齐与符号扩展
// ==========================================
assign ls_ctrl_wb_en_o = (state == WAIT_WB);
assign ls_ctrl_wb_rd_o = wb_rd_r;

wire [31:0] shifted_data = axi_read_data_r >> ({addr_align_r, 3'b000});
reg  [31:0] final_wb_data;
always @(*) begin
    case (load_type_r)
        3'd0: final_wb_data = shifted_data; // LW
        3'd1: final_wb_data = {{16{shifted_data[15]}}, shifted_data[15:0]}; // LH
        3'd2: final_wb_data = {16'b0, shifted_data[15:0]}; // LHU
        3'd3: final_wb_data = {{24{shifted_data[7]}}, shifted_data[7:0]}; // LB
        3'd4: final_wb_data = {24'b0, shifted_data[7:0]}; // LBU
        default: final_wb_data = 32'b0;
    endcase
end
assign ls_ctrl_wb_data_o = final_wb_data;

endmodule