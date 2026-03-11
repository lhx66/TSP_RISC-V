`timescale 1ns / 1ps

module tb_soc_top();

    // ==========================================
    // 信号声明
    // ==========================================
    reg clk;
    reg rst_n;
    
    wire uart_tx;
    reg  uart_rx;

    // ==========================================
    // 时钟与复位生成 (100MHz)
    // ==========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    initial begin
        rst_n = 0;
        uart_rx = 1; // UART 空闲为高电平
        #100;
        rst_n = 1;
        
        // 运行 2000ns 后结束仿真 (根据需要调整时间)
        #2000;
        $display("Simulation Finished!");
        $finish;
    end

    // ==========================================
    // 顶层模块例化 (SoC_Top)
    // ==========================================
    SoC_Top u_SoC_Top (
        .clk     (clk),
        .rst_n   (rst_n),
        .uart_rx (uart_rx),
        .uart_tx (uart_tx),
        
        // 将预留的外部 AXI 下载口全部绑零 (Tie-off)
        // 假设你是通过在 IRAM 内部调用 $readmemh("boot.txt", mem) 来加载程序的
        .ext_axi_if_awaddr (32'b0), .ext_axi_if_awvalid(1'b0), .ext_axi_if_awready(),
        .ext_axi_if_wdata  (32'b0), .ext_axi_if_wstrb  (4'b0), .ext_axi_if_wvalid (1'b0), .ext_axi_if_wready (),
        .ext_axi_if_bresp  (),      .ext_axi_if_bvalid (),     .ext_axi_if_bready (1'b1),
        .ext_axi_if_araddr (32'b0), .ext_axi_if_arvalid(1'b0), .ext_axi_if_arready(),
        .ext_axi_if_rdata  (),      .ext_axi_if_rresp  (),     .ext_axi_if_rvalid (),     .ext_axi_if_rready (1'b1)
    );

    // ==========================================
    // 波形导出 (VCD)
    // ==========================================
    initial begin
        $dumpfile("soc_wave.vcd");
        $dumpvars(0, tb_soc_top);
    end

    // ==========================================
    // 自动监视器：抓取寄存器写回顺序
    // ==========================================
    // 注意：这里的层级路径需要根据你实际例化的名字调整。
    // 假设: u_SoC_Top -> u_TSP_Core -> u_TSP_Regfiles
    wire        wb_en   = u_SoC_Top.u_TSP_Core.wb_en;
    wire [4:0]  wb_rd   = u_SoC_Top.u_TSP_Core.wb_rd_idx;
    wire [31:0] wb_data = u_SoC_Top.u_TSP_Core.wb_data;

    always @(posedge clk) begin
        if (rst_n && wb_en && wb_rd != 5'd0) begin
            $display("[Time: %0t] WRITE-BACK: Register x%0d = %0d (0x%h)", 
                     $time, wb_rd, $signed(wb_data), wb_data);
        end
    end

endmodule