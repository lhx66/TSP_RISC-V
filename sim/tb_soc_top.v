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
    // 时钟与复位生成 (假设系统时钟为 100MHz)
    // ==========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns 周期 -> 100MHz
    end

    initial begin
        rst_n = 0;
        uart_rx = 1; // UART 空闲为高电平
        #100;
        rst_n = 1;
        
        // 【注意】串口传输极慢！
        // 115200 波特率下，传一个字符约需 86.8us。13 个字符需要至少 1.2ms。
        // 所以这里仿真时间必须设得足够长 (2,000,000 ns = 2ms)
        #2000000; 
        $display("\n============================================");
        $display("Simulation Finished by Timeout!");
        $display("============================================");
        $finish;
    end

    // ==========================================
    // 顶层模块例化 (SoC_Top)
    // ==========================================
    SoC_Top u_SoC_Top (
        .clk     (clk),
        .rst_n   (rst_n),
        .uart_rx (uart_rx),
        .uart_tx (uart_tx)
        
        // 外部 AXI 下载口全部绑零
        ,.ext_axi_if_awaddr (32'b0), .ext_axi_if_awvalid(1'b0), .ext_axi_if_awready()
        ,.ext_axi_if_wdata  (32'b0), .ext_axi_if_wstrb  (4'b0), .ext_axi_if_wvalid (1'b0), .ext_axi_if_wready ()
        ,.ext_axi_if_bresp  (),      .ext_axi_if_bvalid (),     .ext_axi_if_bready (1'b1)
        ,.ext_axi_if_araddr (32'b0), .ext_axi_if_arvalid(1'b0), .ext_axi_if_arready()
        ,.ext_axi_if_rdata  (),      .ext_axi_if_rresp  (),     .ext_axi_if_rvalid (),     .ext_axi_if_rready (1'b1)
    );

    // ==========================================
    // 波形导出 (VCD) - 建议打开，方便排查 AXI 握手
    // ==========================================
    initial begin
        $dumpfile("soc_wave.vcd");
        $dumpvars(0, tb_soc_top);
    end

    // ==========================================
    // 自动监视器：行为级 UART RX 终端
    // ==========================================
    // 【修改这里】确保这里的波特率与你 uart_top IP 内部配置的一致！
    parameter BAUD_RATE = 115200; 
    parameter BIT_PERIOD = 1000000000 / BAUD_RATE; // 每个 bit 的持续时间 (单位: ns)

    reg [7:0] rx_byte;
    integer i;

    initial begin
        $display("============================================");
        $display("          UART Terminal Output              ");
        $display("============================================");
        
        forever begin
            // 1. 等待起始位 (下降沿)
            @(negedge uart_tx);
            
            // 2. 延迟半个 bit 周期，对齐到数据位的正中间进行安全采样
            #(BIT_PERIOD / 2);
            
            if (uart_tx == 1'b0) begin // 确认确实是起始位 (过滤毛刺)
                rx_byte = 8'b0;
                
                // 3. 接收 8 个数据位 (LSB First)
                for (i = 0; i < 8; i = i + 1) begin
                    #(BIT_PERIOD); // 等待一个完整的 bit 周期
                    rx_byte[i] = uart_tx;
                end
                
                // 4. 等待停止位
                #(BIT_PERIOD);
                
                // 5. 将字符打印到仿真控制台！(使用 $write 不会自动换行)
                $write("%c", rx_byte);
                
                // 如果你想看十六进制调试信息，可以取消注释下面这行：
                // $display("\n[DEBUG] Byte Sent: 0x%02h", rx_byte);
            end
        end
    end

endmodule