// Simulation replacement for the FPGA PLL.  Synthesis uses the Pango IP.
module sys_pll(
    input  wire clkin1,
    output wire pll_lock,
    output wire clkout0
);
    assign pll_lock = 1'b1;
    assign clkout0  = clkin1;
endmodule
