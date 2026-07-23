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
    output reg         m_axi_rready,

    // SRAM DTCM Port A: low-latency CPU data path
    output reg [31:0]  dtcm_addr_o,
    output wire        dtcm_we_o,
    output wire [3:0]  dtcm_be_o,
    output wire [31:0] dtcm_wdata_o,
    input  wire [31:0] dtcm_rdata_i
);

// ==========================================
// 状态机定义
// ==========================================
localparam IDLE     = 3'd0;
localparam AXI_AW_W = 3'd1;
localparam AXI_B    = 3'd2; 
localparam AXI_AR   = 3'd3;
localparam AXI_R    = 3'd4;
localparam WAIT_WB  = 4'd5;
localparam DTCM_WRITE = 4'd6;
localparam DTCM_READ_REQ = 4'd7;
localparam DTCM_READ_CAPTURE = 4'd8;
localparam DTCM_RMW_READ_REQ = 4'd9;
localparam DTCM_RMW_READ_CAPTURE = 4'd10;
localparam DTCM_RMW_WRITE = 4'd11;

reg [3:0] state;
reg [1:0]                    addr_align_r;
reg [2:0]                    load_type_r;
reg [`REGFILE_IDX_WIDTH-1:0] wb_rd_r;
reg [31:0]                   axi_read_data_r;

// ==========================================
// 【终极非对齐访存支持】：双拍拆分寄存器
// ==========================================
reg        cross_bound_r;  // 标记本次访存是否跨越了 4 字节物理边界
reg        second_beat_r;  // 标记当前正在执行第 2 拍 AXI 事务
reg [31:0] raw_wdata_r;    // 锁存原始写入数据
reg [3:0]  raw_wstrb_r;    // 锁存原始写入字节掩码
reg [31:0] rdata1_r;       // 锁存第一拍读回的数据
reg [31:0] rmw_wdata_r;

// 识别 AXI 合法内存与 MPU 保护
wire is_dtcm = (ls_addr_i[31:28] == `SRAM_ADDR);
wire is_axi_mem = (ls_addr_i[31:28] == `UART_ADDR) ||
                  (ls_addr_i[31:28] == `TIMER_ADDR);

// 非对齐访问检测信号（移到always块外部）
wire [3:0] wstrb_init =
    (ls_byte_en_i == 4'b1111) ? 4'b1111 :  // SW
    (ls_byte_en_i == 4'b0011 || ls_byte_en_i == 4'b1100) ? 4'b0011 : // SH
    4'b0001; // SB

wire is_word = (ls_we_i && wstrb_init == 4'b1111) || (!ls_we_i && ls_load_type == 3'd0);
wire is_half = (ls_we_i && wstrb_init == 4'b0011) || (!ls_we_i && (ls_load_type == 3'd1 || ls_load_type == 3'd2));
wire cross_bound = (is_word && ls_addr_i[1:0] != 2'b00) || (is_half && ls_addr_i[1:0] == 2'b11);

wire [31:0] dtcm_write_data_aligned = second_beat_r
    ? (raw_wdata_r >> ({3'd4 - {1'b0, addr_align_r}, 3'b000}))
    : (raw_wdata_r << ({addr_align_r, 3'b000}));
wire [3:0] dtcm_write_strb_aligned = second_beat_r
    ? (raw_wstrb_r >> (3'd4 - {1'b0, addr_align_r}))
    : (raw_wstrb_r << addr_align_r);
wire [31:0] dtcm_write_byte_mask = {
    {8{dtcm_write_strb_aligned[3]}},
    {8{dtcm_write_strb_aligned[2]}},
    {8{dtcm_write_strb_aligned[1]}},
    {8{dtcm_write_strb_aligned[0]}}
};

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        state           <= IDLE;
        addr_align_r    <= 2'b0;
        load_type_r     <= 3'b0;
        wb_rd_r         <= 0;
        axi_read_data_r <= 32'b0;
        
        cross_bound_r   <= 1'b0;
        second_beat_r   <= 1'b0;
        raw_wdata_r     <= 32'b0;
        raw_wstrb_r     <= 4'b0;
        rdata1_r        <= 32'b0;
        rmw_wdata_r     <= 32'b0;

        m_axi_awvalid   <= 1'b0;
        m_axi_wvalid    <= 1'b0;
        m_axi_bready    <= 1'b0;
        m_axi_arvalid   <= 1'b0;
        m_axi_rready    <= 1'b0;
        m_axi_awaddr    <= 32'b0;
        m_axi_wdata     <= 32'b0;
        m_axi_wstrb     <= 4'b0;
        m_axi_araddr    <= 32'b0;
        dtcm_addr_o     <= 32'b0;
    end else begin
        case (state)
            IDLE: begin
                if (ls_req_i) begin
                    addr_align_r  <= ls_addr_i[1:0];
                    load_type_r   <= ls_load_type;
                    wb_rd_r       <= ls_rd;

                    cross_bound_r <= cross_bound;
                    second_beat_r <= 1'b0;
                    raw_wdata_r   <= ls_wdata_i;
                    raw_wstrb_r   <= wstrb_init;

                    if (is_dtcm) begin
                        dtcm_addr_o <= {ls_addr_i[31:2], 2'b00};
                        state <= !ls_we_i ? DTCM_READ_REQ :
                                 (wstrb_init == 4'b1111 && !cross_bound) ? DTCM_WRITE : DTCM_RMW_READ_REQ;
                    end else if (is_axi_mem) begin
                        if (ls_we_i) begin
                            state         <= AXI_AW_W;
                            m_axi_awaddr  <= {ls_addr_i[31:2], 2'b00}; // 第 1 拍：对齐基地址
                            // 极速左移组合逻辑：自动推算非对齐写入时的数据和掩码分布！
                            m_axi_wdata   <= ls_wdata_i << ({ls_addr_i[1:0], 3'b000});
                            m_axi_wstrb   <= wstrb_init << ls_addr_i[1:0];
                            m_axi_awvalid <= 1'b1;
                            m_axi_wvalid  <= 1'b1;
                        end else begin
                            state         <= AXI_AR;
                            m_axi_araddr  <= {ls_addr_i[31:2], 2'b00};
                            m_axi_arvalid <= 1'b1;
                        end
                    end else begin
                        axi_read_data_r <= 32'b0;
                        state <= WAIT_WB;
                    end
                end
            end
            
            AXI_AW_W: begin
                if (m_axi_awvalid && m_axi_awready) m_axi_awvalid <= 1'b0;
                if (m_axi_wvalid  && m_axi_wready)  m_axi_wvalid  <= 1'b0;
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
                    // 如果发生了跨界，且当前才刚刚完成第 1 拍
                    if (cross_bound_r && !second_beat_r) begin
                        second_beat_r <= 1'b1;
                        state         <= AXI_AW_W;
                        m_axi_awaddr  <= m_axi_awaddr + 32'd4; // 第 2 拍：自动跳到下一个字！
                        // 极速右移组合逻辑：将剩下的数据拼接到下一个字的开头！
                        m_axi_wdata   <= raw_wdata_r >> ({3'd4 - {1'b0, addr_align_r}, 3'b000});
                        m_axi_wstrb   <= raw_wstrb_r >> (3'd4 - {1'b0, addr_align_r});
                        m_axi_awvalid <= 1'b1;
                        m_axi_wvalid  <= 1'b1;
                    end else begin
                        state <= WAIT_WB; // 两拍全完成，收工
                    end
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
                    // 如果跨界且完成的是第 1 拍，暂存数据并立刻发起第 2 拍请求！
                    if (cross_bound_r && !second_beat_r) begin
                        second_beat_r <= 1'b1;
                        rdata1_r      <= m_axi_rdata;
                        state         <= AXI_AR;
                        m_axi_araddr  <= m_axi_araddr + 32'd4;
                        m_axi_arvalid <= 1'b1;
                    end else begin
                        // 到了这里说明读完了。利用 64 位拼接移位大法，一次性抽出正确数据！
                        if (second_beat_r) begin
                            axi_read_data_r <= ({m_axi_rdata, rdata1_r} >> ({addr_align_r, 3'b000}));
                        end else begin
                            axi_read_data_r <= (m_axi_rdata >> ({addr_align_r, 3'b000}));
                        end
                        state <= WAIT_WB;
                    end
                end
            end

            DTCM_WRITE: begin
                if (cross_bound_r && !second_beat_r) begin
                    second_beat_r <= 1'b1;
                    dtcm_addr_o <= dtcm_addr_o + 32'd4;
                end else begin
                    state <= WAIT_WB;
                end
            end

            DTCM_READ_REQ: begin
                state <= DTCM_READ_CAPTURE;
            end

            DTCM_READ_CAPTURE: begin
                if (cross_bound_r && !second_beat_r) begin
                    second_beat_r <= 1'b1;
                    rdata1_r <= dtcm_rdata_i;
                    dtcm_addr_o <= dtcm_addr_o + 32'd4;
                    state <= DTCM_READ_REQ;
                end else begin
                    if (second_beat_r)
                        axi_read_data_r <= ({dtcm_rdata_i, rdata1_r} >> ({addr_align_r, 3'b000}));
                    else
                        axi_read_data_r <= (dtcm_rdata_i >> ({addr_align_r, 3'b000}));
                    state <= WAIT_WB;
                end
            end

            DTCM_RMW_READ_REQ: begin
                state <= DTCM_RMW_READ_CAPTURE;
            end

            DTCM_RMW_READ_CAPTURE: begin
                rmw_wdata_r <= (dtcm_rdata_i & ~dtcm_write_byte_mask) |
                               (dtcm_write_data_aligned & dtcm_write_byte_mask);
                state <= DTCM_RMW_WRITE;
            end

            DTCM_RMW_WRITE: begin
                if (cross_bound_r && !second_beat_r) begin
                    second_beat_r <= 1'b1;
                    dtcm_addr_o <= dtcm_addr_o + 32'd4;
                    state <= DTCM_RMW_READ_REQ;
                end else begin
                    state <= WAIT_WB;
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

assign ls_ctrl_ready_o = (state == IDLE);
assign dtcm_we_o = (state == DTCM_WRITE) || (state == DTCM_RMW_WRITE);
assign dtcm_wdata_o = (state == DTCM_RMW_WRITE) ? rmw_wdata_r : dtcm_write_data_aligned;
assign dtcm_be_o = (state == DTCM_RMW_WRITE) ? 4'b1111 : dtcm_write_strb_aligned;

// ==========================================
// 读数据符号扩展与最终写回 (此时数据已经是完美对齐的了)
// ==========================================
assign ls_ctrl_wb_en_o = (state == WAIT_WB);
assign ls_ctrl_wb_rd_o = wb_rd_r;

reg  [31:0] final_wb_data;
always @(*) begin
    case (load_type_r)
        3'd0: final_wb_data = axi_read_data_r; // LW
        3'd1: final_wb_data = {{16{axi_read_data_r[15]}}, axi_read_data_r[15:0]}; // LH
        3'd2: final_wb_data = {16'b0, axi_read_data_r[15:0]}; // LHU
        3'd3: final_wb_data = {{24{axi_read_data_r[7]}}, axi_read_data_r[7:0]}; // LB
        3'd4: final_wb_data = {24'b0, axi_read_data_r[7:0]}; // LBU
        default: final_wb_data = 32'b0;
    endcase
end
assign ls_ctrl_wb_data_o = final_wb_data;

endmodule
