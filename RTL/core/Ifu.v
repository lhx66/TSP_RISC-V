`include "defines.v"

module TSP_Ifu(
    input clk,
    input rst_n,

    input  [`INST_ADDR_WIDTH-1:0] next_pc_i,    
    input                         ifu_permission, 
    output                        ifu_ready_o,

    input                         flush_i, 

    output [`INST_MAX_WIDTH-1:0]  inst_o,
    output                        inst_valid_o,
    output [`INST_ADDR_WIDTH-1:0] inst_pc_o,  
    output                        inst_err_o,

    input idec_ready_i,

    input  pre_pc_taken_i,
    output pre_pc_taken_o,

    // AXI4-Lite Slave
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready
);

reg awready_r, wready_r, bvalid_r;
reg arready_r, rvalid_r;

assign s_axi_awready = awready_r;
assign s_axi_wready  = wready_r;
assign s_axi_bvalid  = bvalid_r;
assign s_axi_bresp   = 2'b00; 

assign s_axi_arready = arready_r;
assign s_axi_rvalid  = rvalid_r;
assign s_axi_rresp   = 2'b00; 

wire axi_aw_ready_cond = s_axi_awvalid && s_axi_wvalid && !awready_r && !bvalid_r;
wire axi_ar_ready_cond = s_axi_arvalid && !arready_r && !rvalid_r;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        awready_r <= 1'b0; wready_r  <= 1'b0; bvalid_r  <= 1'b0;
        arready_r <= 1'b0; rvalid_r  <= 1'b0;
    end else begin
        if (axi_aw_ready_cond) begin
            awready_r <= 1'b1; wready_r  <= 1'b1;
        end else begin
            awready_r <= 1'b0; wready_r  <= 1'b0;
        end
        if (awready_r && wready_r) bvalid_r <= 1'b1; 
        else if (s_axi_bready && bvalid_r) bvalid_r <= 1'b0; 

        if (axi_ar_ready_cond) arready_r <= 1'b1;
        else arready_r <= 1'b0;
        if (arready_r) rvalid_r <= 1'b1; 
        else if (s_axi_rready && rvalid_r) rvalid_r <= 1'b0;
    end
end

reg [31:0] portB_raddr_r;
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) portB_raddr_r <= 32'b0;
    else if (axi_ar_ready_cond) portB_raddr_r <= s_axi_araddr;
end

wire [31:0] portB_rdata_out;
assign s_axi_rdata = portB_rdata_out;

wire iram_ack_o;
wire [`INST_MAX_WIDTH-1:0] iram_rdata; 
wire inst_req_i = ifu_permission;

// ====================================================================
// 【核心修复】：将提取出的字地址强行补齐到 32 位！防止仿真器产生 Z 态截断
// ====================================================================
wire [31:0] fetch_addr_word = {18'b0, next_pc_i[15:2]};

wire [31:0] axi_b_addr_byte = 
    axi_aw_ready_cond ? s_axi_awaddr : 
    axi_ar_ready_cond ? s_axi_araddr : // <-- 关键修复：直接穿透！
                        portB_raddr_r;
wire [31:0] portB_addr_word = {18'b0, axi_b_addr_byte[15:2]};

TSP_RAM #(
    .RAM_DEPTH(`IRAM_KB),   
    .INIT_FILE(`IRAM_BOOT_PATH) 
) u_Iram (
    .clk(clk), .rst_n(rst_n),
    
    .portA_en(inst_req_i),
    .portA_we(4'b0000),         
    .portA_addr(fetch_addr_word), // 完美输入 32 位地址
    .portA_wdata(32'b0),
    .portA_rdata(iram_rdata),
    .portA_ack(iram_ack_o),
    .portA_err(inst_err_o),

    .portB_en(axi_aw_ready_cond | axi_ar_ready_cond),
    .portB_we(axi_aw_ready_cond ? s_axi_wstrb : 4'b0000),
    .portB_addr(portB_addr_word), // 完美输入 32 位地址
    .portB_wdata(s_axi_wdata),
    .portB_rdata(portB_rdata_out) ,
    .portB_ack  (),
    .portB_err  ()
);

reg [`INST_ADDR_WIDTH-1:0] fetch_pc_delay_r;
reg                        fetch_taken_delay_r;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        fetch_pc_delay_r    <= `PC_RSTVAL;
        fetch_taken_delay_r <= 1'b0;
    end else if (ifu_permission) begin 
        fetch_pc_delay_r    <= next_pc_i;
        fetch_taken_delay_r <= pre_pc_taken_i;
    end
end

reg [`INST_MAX_WIDTH-1:0]  inst_buffer_r;
reg                        use_buffer_r; 
reg                        flush_r;
reg                        pre_pc_taken_r;
reg [`INST_ADDR_WIDTH-1:0] pc_buffer_r;

wire [`INST_MAX_WIDTH-1:0] safe_iram_rdata = (iram_rdata == 32'h00000000) ? 32'h0000006f : iram_rdata;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) flush_r <= 1'b0;
    else        flush_r <= flush_i;
end

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        use_buffer_r   <= 1'b0;
        inst_buffer_r  <= 32'h00000013; 
        pc_buffer_r    <= `PC_RSTVAL;
        pre_pc_taken_r <= 1'b0;
    end else begin
        if (flush_i) begin
            use_buffer_r  <= 1'b0;
        end 
        else if (~idec_ready_i && ~use_buffer_r && iram_ack_o && ~flush_i && ~flush_r) begin
            use_buffer_r   <= 1'b1;
            inst_buffer_r  <= safe_iram_rdata;
            pc_buffer_r    <= fetch_pc_delay_r;
            pre_pc_taken_r <= fetch_taken_delay_r;
        end 
        else if (idec_ready_i) begin
            use_buffer_r  <= 1'b0;
        end
    end
end

assign inst_o         = use_buffer_r ? inst_buffer_r  : safe_iram_rdata;
assign inst_pc_o      = use_buffer_r ? pc_buffer_r    : fetch_pc_delay_r;
assign pre_pc_taken_o = use_buffer_r ? pre_pc_taken_r : fetch_taken_delay_r;
assign inst_valid_o   = (iram_ack_o | use_buffer_r) & ~flush_i & ~flush_r;
assign ifu_ready_o    = idec_ready_i;

endmodule