`timescale 1ns/1ps
`include "defines.v"

module tb_pc_control_2bit;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg ifu_ready = 1'b0;
    reg [`BTB_ENTRY_WIDTH-1:0] btb_update = '0;
    reg btb_update_valid = 1'b0;
    reg [31:0] pc_correct = 32'b0;
    reg pc_redirect = 1'b0;
    wire [31:0] global_pc;
    wire global_pc_valid;
    wire pre_pc_taken;
    wire flush;

    always #5 clk = ~clk;

    PC_control dut (
        .clk(clk), .rst_n(rst_n),
        .global_pc_o(global_pc), .global_pc_valid_o(global_pc_valid),
        .ifu_ready_i(ifu_ready), .pre_pc_taken(pre_pc_taken),
        .BTB_update(btb_update), .BTB_update_valid(btb_update_valid),
        .pc_correct_i(pc_correct), .pc_redirect_i(pc_redirect), .flush(flush)
    );

    task automatic update_branch(input taken);
        begin
            @(negedge clk);
            btb_update = {taken, 30'h0, 30'h00000010};
            btb_update_valid = 1'b1;
            @(negedge clk);
            btb_update_valid = 1'b0;
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        // Train to strongly taken, then inject one uncommon not-taken result.
        update_branch(1'b1);
        update_branch(1'b1);
        if (pre_pc_taken !== 1'b1)
            $fatal(1, "[TB_ERROR] trained taken branch was not predicted taken");

        update_branch(1'b0);
        if (pre_pc_taken !== 1'b1)
            $fatal(1, "[TB_ERROR] one not-taken outcome flipped a strongly-taken prediction");

        update_branch(1'b0);
        if (pre_pc_taken !== 1'b0)
            $fatal(1, "[TB_ERROR] two not-taken outcomes did not flip the prediction");

        // The second consecutive not-taken result must saturate at not-taken.
        update_branch(1'b0);
        if (pre_pc_taken !== 1'b0)
            $fatal(1, "[TB_ERROR] not-taken predictor did not saturate");

        ifu_ready = 1'b1;
        @(posedge clk);
        #1;
        if (global_pc !== 32'h0000_0004)
            $fatal(1, "[TB_ERROR] not-taken prediction PC got %08x expected 00000004", global_pc);

        $display("[TB_INFO] PC control 2-bit predictor hysteresis passed");
        $finish;
    end
endmodule
