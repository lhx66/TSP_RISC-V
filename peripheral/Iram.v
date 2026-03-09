`include "../core/defines.v"

module Iram(
    input clk,
    input rst_n,

    input  inst_req_i,
    input  [`INST_ADDR_WIDTH-1:0]     inst_pc_i,
    output                       iram_ack_o,
    output                       iram_err_o,
    output reg [`INST_MAX_WIDTH-1:0] iram_inst_load
);

//ITCM 使用同步RAM模型，适配Block RAM
`ifdef USE_RAM_IPcore

`else
    reg [`INST_MAX_WIDTH-1:0] IRAM [`IRAM_DEPTH-1:0];
    `ifdef PROG_FPGA
        initial begin
            $readmemh (`PROG_BIN_PATH, RAM);//bin -> txt -> RTL
        end
    `endif
`endif


always @(posedge clk or negedge rst_n) begin
    if (~rst_n)
        iram_inst_load <= {`INST_MAX_WIDTH{1'b0}};
    else if (inst_req_i)
        iram_inst_load <= IRAM[inst_pc_i[`INST_ADDR_WIDTH-1:2]];
end

REGs_NLWR #(1) IRAM_ACK_REG(inst_req_i, iram_ack_o, clk, rst_n);

// 地址越界检测，打一拍与 ack/data 对齐
wire addr_oob;
assign addr_oob = (inst_pc_i[`INST_ADDR_WIDTH-1:2] >= `IRAM_DEPTH);
REGs_NLWR #(1) IRAM_ERR_REG(addr_oob, iram_err_o, clk, rst_n);

endmodule
