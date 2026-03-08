`timescale 1ns / 1ps

module tb_divfunc;

    // 参数设置：32位宽
    parameter XLEN = 32;
    // 将 STAGE_LIST 设为全 1，表示每一级都插入触发器，开启全流水线模式
    // 此时除法器的潜伏期 (Latency) 为 32 个时钟周期，但吞吐率 (Throughput) 为 1
    parameter STAGE_LIST = 32'b0001_0001_0001_0001_0001_0001_0001_0001; 

    reg              clk;
    reg              rst;
    reg  [XLEN-1:0]  a;
    reg  [XLEN-1:0]  b;
    reg              vld;
    reg              is_unsigned;

    wire [XLEN-1:0]  quo;
    wire [XLEN-1:0]  rem;
    wire             ack;

    // 实例化待测设计
    divfunc #(
        .XLEN(XLEN),
        .STAGE_LIST(STAGE_LIST)
    ) uut (
        .clk(clk),
        .rst(rst),
        .a(a),
        .b(b),
        .vld(vld),
        .is_unsigned(is_unsigned),
        .quo(quo),
        .rem(rem),
        .ack(ack)
    );

    // ==========================================
    // 时钟生成 (100MHz)
    // ==========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ==========================================
    // 验证队列 (用于存储期望结果，实现流水线比对)
    // ==========================================
    reg [XLEN-1:0] exp_quo_q [0:63];  // 期望的商
    reg [XLEN-1:0] exp_rem_q [0:63];  // 期望的余数
    reg            exp_sig_q [0:63];  // 符号标志 (用于打印)
    reg [XLEN-1:0] orig_a_q  [0:63];  // 原始被除数 (用于打印)
    reg [XLEN-1:0] orig_b_q  [0:63];  // 原始除数 (用于打印)
    
    integer push_ptr = 0; // 输入端压入指针
    integer pop_ptr  = 0; // 输出端弹出指针

    // ==========================================
    // 任务：连续发送数据并计算期望值
    // ==========================================
    task feed_data;
        input [XLEN-1:0] ta;
        input [XLEN-1:0] tb;
        input            tus; // 1: unsigned, 0: signed
        begin
            // 1. 在下降沿送入数据，避免建立/保持时间违例
            a = ta;
            b = tb;
            is_unsigned = tus;
            vld = 1;

            // 2. 模拟系统预计算正确的期望结果
            if (tus) begin
                // 无符号除法
                exp_quo_q[push_ptr] = ta / tb;
                exp_rem_q[push_ptr] = ta % tb;
            end else begin
                // 有符号除法（使用 $signed 强制转换为补码计算）
                // Verilog 的 % 运算符结果的符号默认与被除数 (ta) 相同，与我们的硬件逻辑一致
                exp_quo_q[push_ptr] = $signed(ta) / $signed(tb);
                exp_rem_q[push_ptr] = $signed(ta) % $signed(tb);
            end
            
            // 保存环境信息用于打印报错
            exp_sig_q[push_ptr] = tus;
            orig_a_q[push_ptr]  = ta;
            orig_b_q[push_ptr]  = tb;
            
            push_ptr = push_ptr + 1;

            // 3. 等待下一个时钟下降沿，实现单周期吞吐 (Throughput = 1)
            @(posedge clk); 
        end
    endtask

    // ==========================================
    // 主测试激励发送序列
    // ==========================================
    initial begin
        // 初始化
        rst = 1;
        vld = 0;
        is_unsigned = 0;
        a = 0;
        b = 0;

        #35;
        @(posedge clk);
        rst = 0;
        #20;

        $display("=================== STARTING PIPELINED TESTS ===================");

        // --- 1. 连续灌入 有符号数 测试 ---
        // 注意：这里没有插入任何额外的延迟，每个时钟周期灌入一个新数据！
        feed_data( 32'sd100,   32'sd30,  0);  // 100 / 30  = 3 ... 10
        feed_data( 32'sd100,  -32'sd30,  0);  // 100 / -30 = -3 ... 10
        feed_data(-32'sd100,   32'sd30,  0);  // -100 / 30 = -3 ... -10
        feed_data(-32'sd100,  -32'sd30,  0);  // -100 / -30= 3 ... -10
        
        // --- 2. 连续灌入 无符号数 测试 ---
        feed_data( 32'd100,    32'd30,   1);
        feed_data( 32'd40000,  32'd7,    1);
        feed_data( 32'hFFFF_FFFF, 32'd2, 1);  // 最大无符号数 / 2
        
        // --- 3. 边界交叉测试 ---
        feed_data(32'h7FFF_FFFF, 32'h0000_0002, 0); // 最大正数 / 2
        feed_data(32'h8000_0000, 32'h0000_0002, 0); // 最小负数 / 2

        // 停止发送有效数据
        vld = 0;
        
        // 等待流水线全部排空 (至少需要 32 个时钟周期)
        wait (pop_ptr == push_ptr);
        #50;
        
        $display("=================== TESTS COMPLETE ===================");
        $finish;
    end

    // ==========================================
    // 独立监控器：在输出端抓取结果并比对 (流水线验证核心)
    // ==========================================
    always @(posedge clk) begin
        // 只要 ack 为高，就说明流水线吐出了一个有效结果
        if (ack) begin
            if (quo === exp_quo_q[pop_ptr] && rem === exp_rem_q[pop_ptr]) begin
                $display("[PASS] %s | a = %11d, b = %11d | quo = %11d, rem = %11d", 
                         exp_sig_q[pop_ptr] ? "Unsigned" : "Signed  ",
                         exp_sig_q[pop_ptr] ? orig_a_q[pop_ptr] : $signed(orig_a_q[pop_ptr]),
                         exp_sig_q[pop_ptr] ? orig_b_q[pop_ptr] : $signed(orig_b_q[pop_ptr]),
                         exp_sig_q[pop_ptr] ? quo : $signed(quo),
                         exp_sig_q[pop_ptr] ? rem : $signed(rem));
            end else begin
                $display("[FAIL] %s | a = %11d, b = %11d",
                         exp_sig_q[pop_ptr] ? "Unsigned" : "Signed  ",
                         exp_sig_q[pop_ptr] ? orig_a_q[pop_ptr] : $signed(orig_a_q[pop_ptr]),
                         exp_sig_q[pop_ptr] ? orig_b_q[pop_ptr] : $signed(orig_b_q[pop_ptr]));
                $display("       Expected : quo = %11d, rem = %11d", 
                         exp_sig_q[pop_ptr] ? exp_quo_q[pop_ptr] : $signed(exp_quo_q[pop_ptr]),
                         exp_sig_q[pop_ptr] ? exp_rem_q[pop_ptr] : $signed(exp_rem_q[pop_ptr]));
                $display("       Got      : quo = %11d, rem = %11d", 
                         exp_sig_q[pop_ptr] ? quo : $signed(quo),
                         exp_sig_q[pop_ptr] ? rem : $signed(rem));
            end
            
            // 弹出指针加 1，准备比对流水线输出的下一个数据
            pop_ptr = pop_ptr + 1;
        end
    end

    // 波形输出
    initial begin
        $dumpfile("tb_divfunc.vcd");
        $dumpvars(0, tb_divfunc);
    end

endmodule