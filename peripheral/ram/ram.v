`include "../../core/defines.v"

module TSP_RAM #(
    // 参数化设计：例化时可任意修改深度和初始化文件
    parameter RAM_DEPTH = 16384, // 默认 16384 字 = 64KB
    parameter INIT_FILE = ""     // 默认无初始化文件
)(
    input clk,
    input rst_n,

    // ==========================================
    // Port A
    // ==========================================
    input                           portA_en,
    input  [3:0]                    portA_we,     // 字节写使能 (0000为纯读)
    input  [`INST_ADDR_WIDTH-1:0]   portA_addr,
    input  [`INST_MAX_WIDTH-1:0]    portA_wdata,
    output reg [`INST_MAX_WIDTH-1:0]portA_rdata,
    output reg                      portA_ack,
    output reg                      portA_err,

    // ==========================================
    // Port B
    // ==========================================
    input                           portB_en,
    input  [3:0]                    portB_we,
    input  [`INST_ADDR_WIDTH-1:0]   portB_addr,
    input  [`INST_MAX_WIDTH-1:0]    portB_wdata,
    output reg [`INST_MAX_WIDTH-1:0]portB_rdata,
    output reg                      portB_ack,
    output reg                      portB_err
);

// ====================================================================
// 将 32 位 RAM 分解为 4 个 8 位 RAM
// 每个 RAM 对应一个字节写使能，更容易被综合为 Block RAM
// ====================================================================

// 字节索引 (去掉最低2位，以字为单位)
wire [31:0] index_A = portA_addr >> 2;
wire [31:0] index_B = portB_addr >> 2;

// Port A 的 4 个字节 RAM
reg [7:0] ram_byte0_A [0:RAM_DEPTH-1];  // [7:0]
reg [7:0] ram_byte1_A [0:RAM_DEPTH-1];  // [15:8]
reg [7:0] ram_byte2_A [0:RAM_DEPTH-1];  // [23:16]
reg [7:0] ram_byte3_A [0:RAM_DEPTH-1];  // [31:24]

// Port B 的 4 个字节 RAM
reg [7:0] ram_byte0_B [0:RAM_DEPTH-1];
reg [7:0] ram_byte1_B [0:RAM_DEPTH-1];
reg [7:0] ram_byte2_B [0:RAM_DEPTH-1];
reg [7:0] ram_byte3_B [0:RAM_DEPTH-1];

// ====================================================================
// Port A 读写逻辑
// ====================================================================
always @(posedge clk) begin
    if (portA_en) begin
        // 写操作：根据字节写使能分别写入对应的 RAM
        if (portA_we[0]) ram_byte0_A[index_A] <= portA_wdata[7:0];
        if (portA_we[1]) ram_byte1_A[index_A] <= portA_wdata[15:8];
        if (portA_we[2]) ram_byte2_A[index_A] <= portA_wdata[23:16];
        if (portA_we[3]) ram_byte3_A[index_A] <= portA_wdata[31:24];

        // 读操作：从 4 个 RAM 中读取数据并组合
        portA_rdata[7:0]   <= ram_byte0_A[index_A];
        portA_rdata[15:8]  <= ram_byte1_A[index_A];
        portA_rdata[23:16] <= ram_byte2_A[index_A];
        portA_rdata[31:24] <= ram_byte3_A[index_A];
    end
end

// ====================================================================
// Port B 读写逻辑
// ====================================================================
always @(posedge clk) begin
    if (portB_en) begin
        // 写操作
        if (portB_we[0]) ram_byte0_B[index_B] <= portB_wdata[7:0];
        if (portB_we[1]) ram_byte1_B[index_B] <= portB_wdata[15:8];
        if (portB_we[2]) ram_byte2_B[index_B] <= portB_wdata[23:16];
        if (portB_we[3]) ram_byte3_B[index_B] <= portB_wdata[31:24];

        // 读操作
        portB_rdata[7:0]   <= ram_byte0_B[index_B];
        portB_rdata[15:8]  <= ram_byte1_B[index_B];
        portB_rdata[23:16] <= ram_byte2_B[index_B];
        portB_rdata[31:24] <= ram_byte3_B[index_B];
    end
end

// ====================================================================
// 状态与错误信号生成
// ====================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        portA_ack <= 1'b0;
    end else begin
        portA_ack <= portA_en;
    end
end

wire err_A = (index_A >= RAM_DEPTH);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        portA_err <= 1'b0;
    end else begin
        portA_err <= err_A;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        portB_ack <= 1'b0;
    end else begin
        portB_ack <= portB_en;
    end
end

wire err_B = (index_B >= RAM_DEPTH);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        portB_err <= 1'b0;
    end else begin
        portB_err <= err_B;
    end
end

endmodule
