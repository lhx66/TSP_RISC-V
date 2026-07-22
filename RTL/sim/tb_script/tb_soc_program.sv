`timescale 1ns/1ps
module tb_soc_program;
    reg sys_clk = 0, rst_n = 0, uart_rx = 1;
    always #5 sys_clk = ~sys_clk;
    wire uart_tx;
    reg [31:0] awaddr, wdata, araddr;
    reg awvalid, wvalid, bready, arvalid, rready;
    reg [3:0] wstrb;
    wire awready, wready, bvalid, arready, rvalid;
    wire [1:0] bresp, rresp;
    wire [31:0] rdata;
    reg [31:0] program_mem [0:16383];
    string program_file;
    integer i, words;
    integer expected_uart;
    reg check_uart, saw_expected_uart;
    reg [31:0] readback_word;

    SoC_Top #(.ENABLE_EXT_IRAM_LOADER(1'b1)) dut (
        .sys_clk(sys_clk), .rst_n(rst_n), .uart_rx(uart_rx), .uart_tx(uart_tx),
        .ext_axi_if_awaddr(awaddr), .ext_axi_if_awvalid(awvalid), .ext_axi_if_awready(awready),
        .ext_axi_if_wdata(wdata), .ext_axi_if_wstrb(wstrb), .ext_axi_if_wvalid(wvalid), .ext_axi_if_wready(wready),
        .ext_axi_if_bresp(bresp), .ext_axi_if_bvalid(bvalid), .ext_axi_if_bready(bready),
        .ext_axi_if_araddr(araddr), .ext_axi_if_arvalid(arvalid), .ext_axi_if_arready(arready),
        .ext_axi_if_rdata(rdata), .ext_axi_if_rresp(rresp), .ext_axi_if_rvalid(rvalid), .ext_axi_if_rready(rready)
    );

    task automatic write_iram(input [31:0] addr, input [31:0] data);
        begin
            @(negedge sys_clk); awaddr=addr; wdata=data; wstrb=4'hf; awvalid=1; wvalid=1;
            wait (awready && wready); @(negedge sys_clk); awvalid=0; wvalid=0;
            wait (bvalid); @(negedge sys_clk);
            if ((addr[11:2] < 4) || (addr[9:2] == 8'h00))
                $display("[TB_DATA] IRAM[%08x] <= %08x", addr, data);
        end
    endtask

    task automatic read_iram(input [31:0] addr, output [31:0] data);
        begin
            @(negedge sys_clk); araddr=addr; arvalid=1;
            wait (arready); @(negedge sys_clk); arvalid=0;
            wait (rvalid); data=rdata; @(negedge sys_clk);
        end
    endtask

    always @(posedge sys_clk) begin
        if (dut.m2_axi_awvalid && dut.m2_axi_awready) begin
            $display("[TB_MONITOR] UART AXI write accepted: %02x", dut.m2_axi_wdata[7:0]);
            if (check_uart && dut.m2_axi_wdata[7:0] == expected_uart[7:0])
                saw_expected_uart <= 1'b1;
        end
    end

    initial begin
        awaddr=0; wdata=0; wstrb=0; awvalid=0; wvalid=0; bready=1; araddr=0; arvalid=0; rready=1;
        check_uart=0; saw_expected_uart=0; expected_uart=0;
        if ($value$plusargs("EXPECT_UART=%h", expected_uart)) check_uart=1;
        for (i=0; i<16384; i=i+1) program_mem[i] = 32'hxxxx_xxxx;
        if (!$value$plusargs("PROGRAM=%s", program_file)) $fatal(1, "[TB_ERROR] Supply +PROGRAM=<bin2txt output>");
        $readmemh(program_file, program_mem);
        words=0; while (words<16384 && (^program_mem[words] !== 1'bx)) words=words+1;
        if (words==0) $fatal(1, "[TB_ERROR] Program image is empty: %s", program_file);
        repeat(3) @(posedge sys_clk); rst_n=1;
        for (i=0; i<words; i=i+1) write_iram(i*4, program_mem[i]);
        read_iram(32'h0000_0000, readback_word);
        if (readback_word !== program_mem[0])
            $fatal(1, "[TB_ERROR] IRAM readback mismatch: got %08x expected %08x", readback_word, program_mem[0]);
        $display("[TB_INFO] Loaded %0d words from %s", words, program_file);
        rst_n=0; repeat(3) @(posedge sys_clk); rst_n=1;
        $display("[TB_MONITOR] CPU reset released; executing loaded image");
        repeat(200000) @(posedge sys_clk);
        if (check_uart && !saw_expected_uart)
            $fatal(1, "[TB_ERROR] expected UART byte %02x was not observed", expected_uart[7:0]);
        $display("[TB_INFO] Simulation Finished!");
        $finish;
    end
endmodule
