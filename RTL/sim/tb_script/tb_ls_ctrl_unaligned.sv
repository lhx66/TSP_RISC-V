`timescale 1ns/1ps

module tb_ls_ctrl_unaligned;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #5 clk = ~clk;

    reg         ls_req_i;
    reg         ls_we_i;
    reg  [31:0] ls_addr_i;
    reg  [3:0]  ls_byte_en_i;
    reg  [31:0] ls_wdata_i;
    reg  [4:0]  ls_rd;
    reg  [2:0]  ls_load_type;
    wire        ls_ctrl_ready_o;
    wire        ls_ctrl_wb_en_o;
    reg         wb_ls_ready_i;
    wire [4:0]  ls_ctrl_wb_rd_o;
    wire [31:0] ls_ctrl_wb_data_o;

    wire [31:0] m_axi_awaddr;
    wire        m_axi_awvalid;
    reg         m_axi_awready;
    wire [31:0] m_axi_wdata;
    wire [3:0]  m_axi_wstrb;
    wire        m_axi_wvalid;
    reg         m_axi_wready;
    reg  [1:0]  m_axi_bresp;
    reg         m_axi_bvalid;
    wire        m_axi_bready;
    wire [31:0] m_axi_araddr;
    wire        m_axi_arvalid;
    reg         m_axi_arready;
    reg  [31:0] m_axi_rdata;
    reg  [1:0]  m_axi_rresp;
    reg         m_axi_rvalid;
    wire        m_axi_rready;
    wire [31:0] dtcm_addr;
    wire        dtcm_we;
    wire [3:0]  dtcm_be;
    wire [31:0] dtcm_wdata;
    reg  [31:0] dtcm_rdata;

    reg [31:0] mem [0:15];
    reg        pending_b;
    reg        pending_r;
    reg [31:0] pending_rdata;
    integer    errors;
    integer    i;

    ls_ctrl dut (
        .clk(clk), .rst_n(rst_n),
        .ls_req_i(ls_req_i), .ls_we_i(ls_we_i), .ls_addr_i(ls_addr_i),
        .ls_byte_en_i(ls_byte_en_i), .ls_wdata_i(ls_wdata_i),
        .ls_rd(ls_rd), .ls_load_type(ls_load_type), .ls_ctrl_ready_o(ls_ctrl_ready_o),
        .ls_ctrl_wb_en_o(ls_ctrl_wb_en_o), .wb_ls_ready_i(wb_ls_ready_i),
        .ls_ctrl_wb_rd_o(ls_ctrl_wb_rd_o), .ls_ctrl_wb_data_o(ls_ctrl_wb_data_o),
        .m_axi_awaddr(m_axi_awaddr), .m_axi_awvalid(m_axi_awvalid), .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(m_axi_wstrb), .m_axi_wvalid(m_axi_wvalid), .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp), .m_axi_bvalid(m_axi_bvalid), .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr), .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata), .m_axi_rresp(m_axi_rresp), .m_axi_rvalid(m_axi_rvalid), .m_axi_rready(m_axi_rready),
        .dtcm_addr_o(dtcm_addr), .dtcm_we_o(dtcm_we), .dtcm_be_o(dtcm_be),
        .dtcm_wdata_o(dtcm_wdata), .dtcm_rdata_i(dtcm_rdata)
    );

    always @(posedge clk) begin
        dtcm_rdata <= mem[dtcm_addr[5:2]];
        if (dtcm_we) begin
            if (dtcm_be[0]) mem[dtcm_addr[5:2]][7:0]   <= dtcm_wdata[7:0];
            if (dtcm_be[1]) mem[dtcm_addr[5:2]][15:8]  <= dtcm_wdata[15:8];
            if (dtcm_be[2]) mem[dtcm_addr[5:2]][23:16] <= dtcm_wdata[23:16];
            if (dtcm_be[3]) mem[dtcm_addr[5:2]][31:24] <= dtcm_wdata[31:24];
            $display("[TB_DATA] t=%0t DTCM WRITE addr=%08x strb=%b data=%08x", $time, dtcm_addr, dtcm_be, dtcm_wdata);
        end
        m_axi_bvalid <= 1'b0;
        m_axi_rvalid <= 1'b0;
        if (m_axi_awvalid && m_axi_awready && m_axi_wvalid && m_axi_wready) begin
            if (m_axi_wstrb[0]) mem[m_axi_awaddr[5:2]][7:0]   <= m_axi_wdata[7:0];
            if (m_axi_wstrb[1]) mem[m_axi_awaddr[5:2]][15:8]  <= m_axi_wdata[15:8];
            if (m_axi_wstrb[2]) mem[m_axi_awaddr[5:2]][23:16] <= m_axi_wdata[23:16];
            if (m_axi_wstrb[3]) mem[m_axi_awaddr[5:2]][31:24] <= m_axi_wdata[31:24];
            pending_b <= 1'b1;
            $display("[TB_DATA] t=%0t WRITE addr=%08x strb=%b data=%08x", $time, m_axi_awaddr, m_axi_wstrb, m_axi_wdata);
        end
        if (pending_b && m_axi_bready) begin
            m_axi_bvalid <= 1'b1;
            pending_b <= 1'b0;
        end
        if (m_axi_arvalid && m_axi_arready) begin
            pending_r <= 1'b1;
            pending_rdata <= mem[m_axi_araddr[5:2]];
            $display("[TB_DATA] t=%0t READ addr=%08x", $time, m_axi_araddr);
        end
        if (pending_r && m_axi_rready) begin
            m_axi_rvalid <= 1'b1;
            m_axi_rdata <= pending_rdata;
            pending_r <= 1'b0;
        end
        if (ls_ctrl_wb_en_o)
            $display("[TB_MONITOR] t=%0t WB rd=x%0d data=%08x", $time, ls_ctrl_wb_rd_o, ls_ctrl_wb_data_o);
    end

    task automatic fail_if_not_equal(input [31:0] actual, input [31:0] expected, input [8*48-1:0] name);
        begin
            if (actual !== expected) begin
                errors = errors + 1;
                $error("[TB_ERROR] %0s actual=%08x expected=%08x", name, actual, expected);
            end
        end
    endtask

    task automatic do_load(input [31:0] addr, input [2:0] load_type, input [4:0] rd, input [31:0] expected);
        begin
            @(negedge clk);
            ls_req_i = 1'b1; ls_we_i = 1'b0; ls_addr_i = addr; ls_load_type = load_type; ls_rd = rd;
            @(negedge clk);
            ls_req_i = 1'b0;
            wait (ls_ctrl_wb_en_o);
            #1 fail_if_not_equal(ls_ctrl_wb_data_o, expected, "load result");
            @(posedge clk);
            wait (ls_ctrl_ready_o);
        end
    endtask

    task automatic do_store(input [31:0] addr, input [3:0] byte_en, input [31:0] data);
        begin
            @(negedge clk);
            ls_req_i = 1'b1; ls_we_i = 1'b1; ls_addr_i = addr; ls_byte_en_i = byte_en; ls_wdata_i = data;
            @(negedge clk);
            ls_req_i = 1'b0;
            wait (ls_ctrl_ready_o);
        end
    endtask

    initial begin
        ls_req_i = 0; ls_we_i = 0; ls_addr_i = 0; ls_byte_en_i = 0; ls_wdata_i = 0; ls_rd = 0; ls_load_type = 0;
        wb_ls_ready_i = 1'b1;
        m_axi_awready = 1'b1; m_axi_wready = 1'b1; m_axi_arready = 1'b1;
        m_axi_bresp = 2'b00; m_axi_rresp = 2'b00; m_axi_bvalid = 0; m_axi_rvalid = 0; m_axi_rdata = 0; dtcm_rdata = 0;
        pending_b = 0; pending_r = 0; pending_rdata = 0; errors = 0;
        for (i = 0; i < 16; i = i + 1) mem[i] = 32'h00000000;
        mem[0] = 32'h44332211;
        mem[1] = 32'h88776655;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        do_load(32'h2000_0001, 3'd0, 5'd1, 32'h55443322);
        do_load(32'h2000_0003, 3'd2, 5'd2, 32'h00005544);
        do_store(32'h2000_0001, 4'b1111, 32'haabb_ccdd);
        #1 fail_if_not_equal(mem[0], 32'hbbcc_dd11, "cross-word SW first word");
        #1 fail_if_not_equal(mem[1], 32'h8877_66aa, "cross-word SW second word");
        do_store(32'h2000_0003, 4'b0011, 32'h00001234);
        #1 fail_if_not_equal(mem[0], 32'h34cc_dd11, "cross-word SH first word");
        #1 fail_if_not_equal(mem[1], 32'h8877_6612, "cross-word SH second word");

        if (errors != 0) $fatal(1, "[TB_ERROR] %0d checks failed", errors);
        $display("[TB_INFO] Simulation Finished!");
        $finish;
    end
endmodule
