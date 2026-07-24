`timescale 1ns/1ps

module tb_exu_ls_issue;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #5 clk = ~clk;

    reg idec_valid_i;
    wire exu_ls_ready_o;
    reg INST_LB, INST_LH, INST_LW, INST_LBU, INST_LHU;
    reg INST_SB, INST_SH, INST_SW;
    reg [31:0] rs2_op;
    reg [4:0] rd_i;
    reg [31:0] ls_addr_i;
    wire ls_req_o, ls_we_o;
    wire [31:0] ls_addr_o;
    wire [3:0] ls_byte_en_o;
    wire [31:0] ls_wdata_o;
    wire [2:0] ls_load_type_o;
    wire [4:0] ls_rd_o;
    reg ls_ctrl_ready_i;

    TSP_Exu_ls dut (
        .clk(clk), .rst_n(rst_n),
        .idec_valid_i(idec_valid_i), .exu_ls_ready_o(exu_ls_ready_o),
        .INST_LB(INST_LB), .INST_LH(INST_LH), .INST_LW(INST_LW),
        .INST_LBU(INST_LBU), .INST_LHU(INST_LHU),
        .INST_SB(INST_SB), .INST_SH(INST_SH), .INST_SW(INST_SW),
        .rs2_op(rs2_op), .rd_i(rd_i), .ls_addr_i(ls_addr_i),
        .ls_req_o(ls_req_o), .ls_we_o(ls_we_o), .ls_addr_o(ls_addr_o),
        .ls_byte_en_o(ls_byte_en_o), .ls_wdata_o(ls_wdata_o),
        .ls_load_type_o(ls_load_type_o), .ls_rd_o(ls_rd_o),
        .ls_ctrl_ready_i(ls_ctrl_ready_i)
    );

    task automatic expect_equal(input actual, input expected, input [8*48-1:0] name);
        begin
            if (actual !== expected)
                $fatal(1, "[TB_ERROR] %0s actual=%b expected=%b", name, actual, expected);
        end
    endtask

    initial begin
        idec_valid_i = 0;
        INST_LB = 0; INST_LH = 0; INST_LW = 0; INST_LBU = 0; INST_LHU = 0;
        INST_SB = 0; INST_SH = 0; INST_SW = 0;
        rs2_op = 0; rd_i = 0; ls_addr_i = 0; ls_ctrl_ready_i = 0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        // A ready DTCM controller must accept an issued load in this cycle.
        idec_valid_i = 1'b1;
        INST_LW = 1'b1;
        rd_i = 5'd7;
        ls_addr_i = 32'h2000_0040;
        ls_ctrl_ready_i = 1'b1;
        #1;
        expect_equal(exu_ls_ready_o, 1'b1, "LSU ready mirrors controller");
        expect_equal(ls_req_o, 1'b1, "load is issued without front-end bubble");
        expect_equal(ls_we_o, 1'b0, "load write-enable");
        expect_equal(ls_addr_o == 32'h2000_0040, 1'b1, "load address");
        expect_equal(ls_rd_o == 5'd7, 1'b1, "load destination");
        expect_equal(ls_load_type_o == 3'd0, 1'b1, "LW load type");

        $display("[TB_INFO] TSP_Exu_ls direct issue passed");
        $finish;
    end
endmodule
