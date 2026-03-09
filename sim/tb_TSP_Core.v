`timescale 1ns / 1ps

module tb_TSP_Core;

    // 1. 信号声明
    reg clk;
    reg rst_n;

    // 2. 例化你的顶层 CPU 核心
    TSP_Core u_TSP_Core (
        .clk  (clk),
        .rst_n(rst_n)
    );

    // 3. 时钟生成 (100MHz, 周期 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 4. 初始化与指令载入
    initial begin
        // 初始化复位信号
        rst_n = 0;
        
        // ==============================================================
        // 【关键配置】：将 inst.txt 中的机器码加载到你的 Iram 内部数组中
        // 注意：你需要根据你实际 Iram 模块内 reg 数组的名字修改 "mem_array" 
        // 例如，如果你的 Iram 里定义的是 `reg [31:0] inst_ram [0:1023];`
        // 那么就把下面这句改为：...u_TSP_Ifu.u_Iram.inst_ram
        // ==============================================================
        $readmemh("inst.txt", u_TSP_Core.u_TSP_Ifu.u_Iram.IRAM); // 请核对 Iram 内部变量名！

        // 释放复位，启动 CPU
        #23 rst_n = 1;

        // 运行 5000 个时钟周期后自动结束仿真
        #50000 $finish;
    end

    // 5. 生成波形文件 (用于 ModelSim/Vivado/GTKWave 查看)
    initial begin
        $dumpfile("tsp_core.vcd");
        $dumpvars(0, tb_TSP_Core);
    end

    // 6. 核心监视器 (Auto-Monitor)
    // 监听全局通用寄存器堆的“写使能”端口，实时打印写回信息
    always @(posedge clk) begin
        if (rst_n && u_TSP_Core.u_TSP_Regfiles.wb_en) begin
            // 忽略对 x0 寄存器的无效写回
            if (u_TSP_Core.u_TSP_Regfiles.wb_reg_idx != 5'd0) begin
                $display("[Time: %0t ns] write back regfile x%0d = %0d (0x%08x)", 
                         $time, 
                         u_TSP_Core.u_TSP_Regfiles.wb_reg_idx, 
                         $signed(u_TSP_Core.u_TSP_Regfiles.wb_dat),
                         u_TSP_Core.u_TSP_Regfiles.wb_dat);
            end
        end
    end

endmodule