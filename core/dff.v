`include "defines.v"

//开关控制+复位信号 With Load With Reset
    module REGs_WLWR # (
    parameter RW = 32,
    parameter RST_VAL = 0
    ) (
        input               lden,
        input      [RW-1:0] din,
        output reg[RW-1:0] qout,
        input               clk,
        input               rst_n
    );

    always @(posedge clk or negedge rst_n)  begin
    if (~rst_n)
        qout <= RST_VAL;
    else if (lden == `Enable)
        qout <= #1 din;
    end

    endmodule

//开关控制+无复位信号 With Load No Reset
module REGs_WLNR #(
    parameter RW = 32
) (
    input               lden,
    input      [RW-1:0] din,
    output reg [RW-1:0] qout,
    input               clk
);

always @(posedge clk) begin
    if (lden == `Enable)
        qout <= #1 din;
end

endmodule

//无开关控制+复位信号 No Load With Reset
module REGs_NLWR # (
parameter RW = 32,
parameter RST_VAL = 0
) (
    input      [RW-1:0] din,
    output reg [RW-1:0] qout,
    input               clk,
    input               rst_n
);

always @(posedge clk or negedge rst_n) begin
if (~rst_n)
    qout <= RST_VAL;
else
    qout <= #1 din;
end

endmodule

//无开关控制+无复位信号
module REGs_NLNR # (
parameter RW = 32
) (
    input      [RW-1:0] din,
    output reg [RW-1:0] qout,
    input               clk
);

always @(posedge clk) begin
    qout <= #1 din;
end

endmodule
