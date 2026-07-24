`timescale 1ns/1ps

module tb_multiplier_radix4;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg ld = 1'b0;
    reg unsigned_m = 1'b0;
    reg unsigned_r = 1'b0;
    reg [31:0] m = 32'b0;
    reg [31:0] r = 32'b0;
    wire valid;
    wire [63:0] p;

    always #5 clk = ~clk;

    Simple_Multiplier_32 dut (
        .clk(clk), .rst_n(rst_n), .ld(ld),
        .unsigned_m(unsigned_m), .unsigned_r(unsigned_r),
        .m(m), .r(r), .valid(valid), .p(p)
    );

    task automatic run_case(
        input case_unsigned_m,
        input case_unsigned_r,
        input [31:0] case_m,
        input [31:0] case_r,
        input [63:0] expected,
        input [8*24-1:0] case_name
    );
        integer cycles;
        begin
            @(negedge clk);
            unsigned_m = case_unsigned_m;
            unsigned_r = case_unsigned_r;
            m = case_m;
            r = case_r;
            ld = 1'b1;
            @(posedge clk);
            #1;
            ld = 1'b0;
            cycles = 0;
            while (!valid) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
                if (cycles > 17)
                    $fatal(1, "[TB_ERROR] %0s completed in more than 17 cycles", case_name);
            end
            if (cycles != 17)
                $fatal(1, "[TB_ERROR] %0s latency=%0d expected=17", case_name, cycles);
            if (p !== expected)
                $fatal(1, "[TB_ERROR] %0s product=%016x expected=%016x", case_name, p, expected);
            $display("[TB_INFO] %0s product=%016x latency=%0d", case_name, p, cycles);
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        run_case(1'b1, 1'b1, 32'd3,         32'd7,         64'h0000000000000015, "unsigned_small");
        run_case(1'b0, 1'b0, -32'sd3,       32'd7,         64'hffffffffffffffeb, "signed_negative");
        run_case(1'b0, 1'b0, 32'h80000000,  32'd2,         64'hffffffff00000000, "signed_min_times_two");
        run_case(1'b0, 1'b1, -32'sd2,       32'hffffffff,  64'hfffffffe00000002, "mulhsu_operands");
        run_case(1'b1, 1'b1, 32'hffffffff,  32'hffffffff,  64'hfffffffe00000001, "mulhu_operands");

        $display("[TB_INFO] Radix-4 multiplier regression passed");
        $finish;
    end
endmodule
