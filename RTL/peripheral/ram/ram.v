`include "../../core/defines.v"

module TSP_RAM #(
    parameter RAM_DEPTH = 16384, // 默认 16384 字 = 64KB
    parameter INIT_FILE = ""     // 默认无初始化文件
)(
    input clk,
    input rst_n,

    // ==========================================
    // Port A
    // ==========================================
    input                               portA_en,
    input  [3:0]                        portA_we,
    input  [`INST_ADDR_WIDTH-1:0]       portA_addr, // 标准 32 位地址
    input  [`INST_MAX_WIDTH-1:0]        portA_wdata,
    output [`INST_MAX_WIDTH-1:0]        portA_rdata,
    output reg                          portA_ack,
    output reg                          portA_err,

    // ==========================================
    // Port B
    // ==========================================
    input                               portB_en,
    input  [3:0]                        portB_we,
    input  [`INST_ADDR_WIDTH-1:0]       portB_addr, // 标准 32 位地址
    input  [`INST_MAX_WIDTH-1:0]        portB_wdata,
    output [`INST_MAX_WIDTH-1:0]        portB_rdata,
    output reg                          portB_ack,
    output reg                          portB_err
);

reg [`INST_MAX_WIDTH-1:0] RAM [0:RAM_DEPTH-1];

reg [`INST_MAX_WIDTH-1:0] portA_rdata_r;
wire [3:0] portA_webyte = {4{portA_en}} & portA_we;

reg [`INST_MAX_WIDTH-1:0] portB_rdata_r;
wire [3:0] portB_webyte = {4{portB_en}} & portB_we;

// 外部传入的已经是字地址，绝不能右移！
wire [31:0] index_A = portA_addr;
wire [31:0] index_B = portB_addr;

always @(posedge clk) begin
    if (portA_en) begin
        portA_rdata_r <= RAM[index_A];
        if (portA_webyte[0]) RAM[index_A][7:0]   <= portA_wdata[7:0];
        if (portA_webyte[1]) RAM[index_A][15:8]  <= portA_wdata[15:8];
        if (portA_webyte[2]) RAM[index_A][23:16] <= portA_wdata[23:16];
        if (portA_webyte[3]) RAM[index_A][31:24] <= portA_wdata[31:24];
    end

    if (portB_en) begin
        portB_rdata_r <= RAM[index_B];
        if (portB_webyte[0]) RAM[index_B][7:0]   <= portB_wdata[7:0];
        if (portB_webyte[1]) RAM[index_B][15:8]  <= portB_wdata[15:8];
        if (portB_webyte[2]) RAM[index_B][23:16] <= portB_wdata[23:16];
        if (portB_webyte[3]) RAM[index_B][31:24] <= portB_wdata[31:24];
    end
end

assign portA_rdata = portA_rdata_r;
assign portB_rdata = portB_rdata_r;

// ====================================================================
// 内存初始化 (完美恢复 Generate)
// ====================================================================
generate
    if (INIT_FILE != "") begin
        initial begin
            integer i;
            for (i = 0; i < RAM_DEPTH; i = i + 1) begin 
                RAM[i] = 32'h00000000;
            end
            $readmemh(INIT_FILE, RAM);
        end
    end
    else begin
        initial begin
            integer i;
            for (i = 0; i < RAM_DEPTH; i = i + 1) begin 
                RAM[i] = 32'h00000000;
            end
        end
    end
endgenerate

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