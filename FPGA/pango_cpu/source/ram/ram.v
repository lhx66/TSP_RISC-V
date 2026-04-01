`include "../core/defines.v"

module TSP_RAM #(
    parameter RAM_DEPTH = 16384, // 默认 16384 字 = 64KB
    parameter INIT_FILE = ""     // 默认无初始化文件
)(
    input clk,
    input rst_n,

    // ==========================================
    // Port A
    // ==========================================
    input                           portA_en,
    input  [3:0]                    portA_we,
    input  [`INST_ADDR_WIDTH-1:0]   portA_addr,
    input  [`INST_MAX_WIDTH-1:0]    portA_wdata,
    output  [`INST_MAX_WIDTH-1:0] portA_rdata,
    output reg                      portA_ack,
    output reg                      portA_err,

    // ==========================================
    // Port B
    // ==========================================
    input                           portB_en,
    input  [3:0]                    portB_we,
    input  [`INST_ADDR_WIDTH-1:0]   portB_addr,
    input  [`INST_MAX_WIDTH-1:0]    portB_wdata,
    output  [`INST_MAX_WIDTH-1:0] portB_rdata,
    output reg                      portB_ack,
    output reg                      portB_err
);

// ====================================================================
// RAM建模 - 单一32位宽数组
// ====================================================================
reg [`INST_MAX_WIDTH-1:0] RAM [0:RAM_DEPTH-1];

reg [`INST_MAX_WIDTH-1:0] portA_rdata_r;
wire [3:0] portA_webyte = {4{portA_en}} & portA_we;

reg [`INST_MAX_WIDTH-1:0] portB_rdata_r;
wire [3:0] portB_webyte = {4{portB_en}} & portB_we;

// 计算字对齐索引
wire [31:0] index_A = portA_addr >> 2;
wire [31:0] index_B = portB_addr >> 2;

// ====================================================================
// Port A/B 读写逻辑
// ====================================================================
always @(posedge clk) begin
    if (portA_en) begin
        portA_rdata_r <= RAM[index_A];

        if (portA_webyte[0]) RAM[index_A][7:0]   <= portA_wdata[7:0];
        if (portA_webyte[1]) RAM[index_A][15:8]  <= portA_wdata[15:8];
        if (portA_webyte[2]) RAM[index_A][23:16] <= portA_wdata[23:16];
        if (portA_webyte[3]) RAM[index_A][31:24] <= portA_wdata[31:24];
    end
/*
    if (portB_en) begin
        portB_rdata_r <= RAM[index_B];

        if (portB_webyte[0]) RAM[index_B][7:0]   <= portB_wdata[7:0];
        if (portB_webyte[1]) RAM[index_B][15:8]  <= portB_wdata[15:8];
        if (portB_webyte[2]) RAM[index_B][23:16] <= portB_wdata[23:16];
        if (portB_webyte[3]) RAM[index_B][31:24] <= portB_wdata[31:24];
    end*/
end

assign portA_rdata = portA_rdata_r;


// ====================================================================
// 内存初始化
// ====================================================================
generate
    if (INIT_FILE != "") begin
        initial begin
            $readmemh(INIT_FILE, RAM);
        end
    end
endgenerate

// ====================================================================
// 状态与错误信号生成
// ====================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        portA_ack <= 1'b0;
        portB_ack <= 1'b0;
        portA_err <= 1'b0;
        portB_err <= 1'b0;
    end else begin
        portA_ack <= portA_en;
        portB_ack <= portB_en;
        portA_err <= (index_A >= RAM_DEPTH);
        portB_err <= (index_B >= RAM_DEPTH);
    end
end

endmodule
