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
    reg [31:0] sram_awaddr, sram_wdata, sram_araddr;
    reg sram_awvalid, sram_wvalid, sram_bready, sram_arvalid, sram_rready;
    reg [3:0] sram_wstrb;
    wire sram_awready, sram_wready, sram_bvalid, sram_arready, sram_rvalid;
    wire [1:0] sram_bresp, sram_rresp;
    wire [31:0] sram_rdata;
    reg [31:0] program_mem [0:16383];
    reg [31:0] sram_mem [0:8191];
    string program_file, sram_file;
    integer i, words, sram_words, max_cycles, exec_cycles, patch_sram_index;
    integer lsu_req_count, lsu_busy_cycles, dtcm_write_cycles;
    integer expected_uart;
    reg check_uart, saw_expected_uart, trace_pc, verify_images, patch_sram, check_ifu, executing_image, lsu_stats;
    reg [31:0] readback_word;
    reg [31:0] patch_sram_addr, patch_sram_value;

    SoC_Top #(.ENABLE_EXT_IRAM_LOADER(1'b1), .ENABLE_EXT_SRAM_LOADER(1'b1)) dut (
        .sys_clk(sys_clk), .rst_n(rst_n), .uart_rx(uart_rx), .uart_tx(uart_tx),
        .ext_axi_if_awaddr(awaddr), .ext_axi_if_awvalid(awvalid), .ext_axi_if_awready(awready),
        .ext_axi_if_wdata(wdata), .ext_axi_if_wstrb(wstrb), .ext_axi_if_wvalid(wvalid), .ext_axi_if_wready(wready),
        .ext_axi_if_bresp(bresp), .ext_axi_if_bvalid(bvalid), .ext_axi_if_bready(bready),
        .ext_axi_if_araddr(araddr), .ext_axi_if_arvalid(arvalid), .ext_axi_if_arready(arready),
        .ext_axi_if_rdata(rdata), .ext_axi_if_rresp(rresp), .ext_axi_if_rvalid(rvalid), .ext_axi_if_rready(rready),
        .ext_axi_sram_awaddr(sram_awaddr), .ext_axi_sram_awvalid(sram_awvalid), .ext_axi_sram_awready(sram_awready),
        .ext_axi_sram_wdata(sram_wdata), .ext_axi_sram_wstrb(sram_wstrb), .ext_axi_sram_wvalid(sram_wvalid), .ext_axi_sram_wready(sram_wready),
        .ext_axi_sram_bresp(sram_bresp), .ext_axi_sram_bvalid(sram_bvalid), .ext_axi_sram_bready(sram_bready),
        .ext_axi_sram_araddr(sram_araddr), .ext_axi_sram_arvalid(sram_arvalid), .ext_axi_sram_arready(sram_arready),
        .ext_axi_sram_rdata(sram_rdata), .ext_axi_sram_rresp(sram_rresp), .ext_axi_sram_rvalid(sram_rvalid), .ext_axi_sram_rready(sram_rready)
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

    task automatic write_sram(input [31:0] addr, input [31:0] data);
        begin
            @(negedge sys_clk); sram_awaddr=addr; sram_wdata=data; sram_wstrb=4'hf; sram_awvalid=1; sram_wvalid=1;
            wait (sram_awready && sram_wready); @(negedge sys_clk); sram_awvalid=0; sram_wvalid=0;
            wait (sram_bvalid); @(negedge sys_clk);
        end
    endtask

    task automatic read_sram(input [31:0] addr, output [31:0] data);
        begin
            @(negedge sys_clk); sram_araddr=addr; sram_arvalid=1;
            wait (sram_arready); @(negedge sys_clk); sram_arvalid=0;
            wait (sram_rvalid); data=sram_rdata; @(negedge sys_clk);
        end
    endtask

    always @(posedge sys_clk) begin
        if (dut.m2_axi_awvalid && dut.m2_axi_awready) begin
            $display("[TB_MONITOR] UART AXI write accepted: %02x", dut.m2_axi_wdata[7:0]);
            if (check_uart && dut.m2_axi_wdata[7:0] == expected_uart[7:0])
                saw_expected_uart <= 1'b1;
        end
        if (trace_pc && rst_n && ((exec_cycles % 1000000) == 0))
            $display("[TB_PC] cycle=%0d pc=%08x inst=%08x redirect=%b",
                     exec_cycles, dut.u_TSP_Core.global_pc,
                     dut.u_TSP_Core.u_TSP_Ifu.inst_o,
                      dut.u_TSP_Core.pc_redirect);
        if (check_ifu && executing_image && dut.u_TSP_Core.u_TSP_Ifu.inst_valid_o &&
            dut.u_TSP_Core.u_TSP_Ifu.inst_pc_o[31:16] == 16'h0000 &&
            dut.u_TSP_Core.u_TSP_Ifu.inst_o !== program_mem[dut.u_TSP_Core.u_TSP_Ifu.inst_pc_o[15:2]])
            $fatal(1, "[TB_ERROR] IFU instruction mismatch: pc=%08x got=%08x expected=%08x",
                   dut.u_TSP_Core.u_TSP_Ifu.inst_pc_o, dut.u_TSP_Core.u_TSP_Ifu.inst_o,
                   program_mem[dut.u_TSP_Core.u_TSP_Ifu.inst_pc_o[15:2]]);
        if (lsu_stats && executing_image) begin
            if (dut.u_TSP_Core.ls_req) lsu_req_count <= lsu_req_count + 1;
            if (!dut.u_TSP_Core.ls_ctrl_ready) lsu_busy_cycles <= lsu_busy_cycles + 1;
            if (dut.u_TSP_Core.dtcm_we_o) dtcm_write_cycles <= dtcm_write_cycles + 1;
        end
        if (rst_n)
            exec_cycles <= exec_cycles + 1;
        else
            exec_cycles <= 0;
    end

    initial begin
        awaddr=0; wdata=0; wstrb=0; awvalid=0; wvalid=0; bready=1; araddr=0; arvalid=0; rready=1;
        sram_awaddr=0; sram_wdata=0; sram_wstrb=0; sram_awvalid=0; sram_wvalid=0; sram_bready=1; sram_araddr=0; sram_arvalid=0; sram_rready=1;
        check_uart=0; saw_expected_uart=0; expected_uart=0; max_cycles=200000; exec_cycles=0; lsu_req_count=0; lsu_busy_cycles=0; dtcm_write_cycles=0; trace_pc=0; verify_images=0; patch_sram=0; check_ifu=0; executing_image=0; lsu_stats=0;
        if ($value$plusargs("EXPECT_UART=%h", expected_uart)) check_uart=1;
        if ($test$plusargs("TRACE_PC")) trace_pc=1;
        if ($test$plusargs("LSU_STATS")) lsu_stats=1;
        if ($test$plusargs("VERIFY_ALL_IMAGES")) verify_images=1;
        if ($test$plusargs("CHECK_IFU")) check_ifu=1;
        if ($value$plusargs("PATCH_SRAM_ADDR=%h", patch_sram_addr)) begin
            if (!$value$plusargs("PATCH_SRAM_VALUE=%h", patch_sram_value))
                $fatal(1, "[TB_ERROR] +PATCH_SRAM_ADDR requires +PATCH_SRAM_VALUE");
            if (patch_sram_addr[31:15] != 17'h4000 || patch_sram_addr[1:0] != 2'b00)
                $fatal(1, "[TB_ERROR] invalid word-aligned SRAM patch address: %08x", patch_sram_addr);
            patch_sram=1;
            patch_sram_index=patch_sram_addr[14:2];
        end
        void'($value$plusargs("MAX_CYCLES=%d", max_cycles));
        for (i=0; i<16384; i=i+1) program_mem[i] = 32'hxxxx_xxxx;
        for (i=0; i<8192; i=i+1) sram_mem[i] = 32'hxxxx_xxxx;
        if (!$value$plusargs("PROGRAM=%s", program_file)) $fatal(1, "[TB_ERROR] Supply +PROGRAM=<bin2txt output>");
        $readmemh(program_file, program_mem);
        words=0; while (words<16384 && (^program_mem[words] !== 1'bx)) words=words+1;
        if (words==0) $fatal(1, "[TB_ERROR] Program image is empty: %s", program_file);
        sram_words=0;
        if ($value$plusargs("SRAM=%s", sram_file)) begin
            $readmemh(sram_file, sram_mem);
            while (sram_words<8192 && (^sram_mem[sram_words] !== 1'bx)) sram_words=sram_words+1;
        end
        if (patch_sram) begin
            sram_mem[patch_sram_index] = patch_sram_value;
            if (sram_words <= patch_sram_index) sram_words = patch_sram_index + 1;
            $display("[TB_INFO] Patched SRAM[%08x] <= %08x", patch_sram_addr, patch_sram_value);
        end
        repeat(3) @(posedge sys_clk); rst_n=1;
        for (i=0; i<words; i=i+1) write_iram(i*4, program_mem[i]);
        read_iram(32'h0000_0000, readback_word);
        if (readback_word !== program_mem[0])
            $fatal(1, "[TB_ERROR] IRAM readback mismatch: got %08x expected %08x", readback_word, program_mem[0]);
        if (verify_images) begin
            for (i=0; i<words; i=i+1) begin
                read_iram(i*4, readback_word);
                if (readback_word !== program_mem[i])
                    $fatal(1, "[TB_ERROR] IRAM[%0d] mismatch: got %08x expected %08x", i, readback_word, program_mem[i]);
            end
        end
        for (i=0; i<sram_words; i=i+1) write_sram(32'h2000_0000 + i*4, sram_mem[i]);
        if (sram_words != 0) begin
            read_sram(32'h2000_0000, readback_word);
            if (readback_word !== sram_mem[0])
                $fatal(1, "[TB_ERROR] SRAM readback mismatch: got %08x expected %08x", readback_word, sram_mem[0]);
            if (verify_images) begin
                for (i=0; i<sram_words; i=i+1) begin
                    read_sram(32'h2000_0000 + i*4, readback_word);
                    if (readback_word !== sram_mem[i])
                        $fatal(1, "[TB_ERROR] SRAM[%0d] mismatch: got %08x expected %08x", i, readback_word, sram_mem[i]);
                end
            end
            $display("[TB_INFO] Loaded %0d SRAM words from %s", sram_words, sram_file);
        end
        $display("[TB_INFO] Loaded %0d words from %s", words, program_file);
        rst_n=0; repeat(3) @(posedge sys_clk); rst_n=1; executing_image=1;
        lsu_req_count=0; lsu_busy_cycles=0; dtcm_write_cycles=0;
        $display("[TB_MONITOR] CPU reset released; executing loaded image");
        repeat(max_cycles) @(posedge sys_clk);
        if (check_uart && !saw_expected_uart)
            $fatal(1, "[TB_ERROR] expected UART byte %02x was not observed", expected_uart[7:0]);
        if (lsu_stats)
            $display("[TB_LSU_STATS] cycles=%0d requests=%0d busy_cycles=%0d dtcm_write_cycles=%0d",
                     exec_cycles, lsu_req_count, lsu_busy_cycles, dtcm_write_cycles);
        $display("[TB_INFO] Simulation Finished!");
        $finish;
    end
endmodule
