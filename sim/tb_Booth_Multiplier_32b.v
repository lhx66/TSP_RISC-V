`timescale 1ns / 1ps

module tb_Booth_Multiplier_32b;

    parameter N = 32; // 测试位宽设为 16位

    reg Rst;
    reg Clk;
    reg Ld;
    reg Unsigned_M;
    reg Unsigned_R;
    reg [N-1:0] M;
    reg [N-1:0] R;

    wire Valid;
    wire [(2*N)-1:0] P;

    // 实例化模块
    Booth_Multiplier_4xB #(N) uut (
        .Rst(Rst),
        .Clk(Clk),
        .Ld(Ld),
        .Unsigned_M(Unsigned_M),
        .Unsigned_R(Unsigned_R),
        .M(M),
        .R(R),
        .Valid(Valid),
        .P(P)
    );

    initial begin
        Clk = 0;
        forever #5 Clk = ~Clk;
    end

    // 测试任务
    task test_mult;
        input [N-1:0] t_M;
        input [N-1:0] t_R;
        input t_Usign_M;
        input t_Usign_R;
        
        // 使用有符号 2N 位宽来计算预期值，完美适配混合乘法
        reg signed [(2*N)-1:0] ext_M;
        reg signed [(2*N)-1:0] ext_R;
        reg signed [(2*N)-1:0] expected_P;
        begin
            // 1. 根据各自的符号位进行正确的位宽扩展
            ext_M = t_Usign_M ? { {N{1'b0}}, t_M } : { {N{t_M[N-1]}}, t_M };
            ext_R = t_Usign_R ? { {N{1'b0}}, t_R } : { {N{t_R[N-1]}}, t_R };
            
            // 2. 计算预期结果
            expected_P = ext_M * ext_R;

            // 3. 驱动输入
            @(posedge Clk);
            M = t_M;
            R = t_R;
            Unsigned_M = t_Usign_M;
            Unsigned_R = t_Usign_R;
            Ld = 1;
            
            @(posedge Clk);
            Ld = 0;

            // 4. 等待结果
            wait(Valid == 1'b1);
            @(posedge Clk); 

            // 5. 十进制格式化打印
            $write("[%s] ", (P === expected_P) ? "PASS" : "FAIL");
            
            // 打印 M (带状态标记 U=无符号, S=有符号)
            if (t_Usign_M) $write("M(U): %6d | ", t_M);
            else           $write("M(S): %6d | ", $signed(t_M));

            // 打印 R
            if (t_Usign_R) $write("R(U): %6d || ", t_R);
            else           $write("R(S): %6d || ", $signed(t_R));

            // 打印 乘积 P
            if (t_Usign_M && t_Usign_R) begin
                // 双无符号，结果必为正
                if (P === expected_P) $display("P(U): %10d", P);
                else $display("Got(U): %10d, Exp: %10d", P, expected_P);
            end else begin
                // 只要有一个是有符号，结果就有负号的可能，作为有符号数打印
                if (P === expected_P) $display("P(S): %10d", $signed(P));
                else $display("Got(S): %10d, Exp: %10d", $signed(P), expected_P);
            end
        end
    endtask

    initial begin
        Rst = 1; Ld = 0; Unsigned_M = 0; Unsigned_R = 0; M = 0; R = 0;
        #35; @(posedge Clk); Rst = 0; #20;

        $display("=================== STARTING MIXED TESTS ===================");

        $display("\n--- 1. 纯有符号乘法 (Signed * Signed) ---");
        test_mult(16'sd120,   16'sd50,     0, 0); // 120 * 50
        test_mult(16'sd120,  -16'sd50,     0, 0); // 120 * -50
        test_mult(-16'sd200,  16'sd30,     0, 0); // -200 * 30
        test_mult(-16'sd100, -16'sd40,     0, 0); // -100 * -40

        $display("\n--- 2. 纯无符号乘法 (Unsigned * Unsigned) ---");
        test_mult(16'd40000,  16'd50000,   1, 1); // 40000 * 50000
        test_mult(16'd65535,  16'd2,       1, 1); // 最大无符号 * 2

        $display("\n--- 3. 混合乘法：M(无符号) * R(有符号) ---");
        test_mult(16'd40000, -16'sd10,     1, 0); // 40000 * -10
        test_mult(16'd65535, -16'sd2,      1, 0); // 65535 * -2
        test_mult(16'd50000,  16'sd100,    1, 0); // 50000 * 100 (有符号正)

        $display("\n--- 4. 混合乘法：M(有符号) * R(无符号) ---");
        test_mult(-16'sd1000, 16'd50000,   0, 1); // -1000 * 50000
        test_mult(-16'sd1,    16'd65535,   0, 1); // -1 * 65535
        test_mult(16'sd500,   16'd40000,   0, 1); // 500 * 40000

        $display("\n--- 5. 极端边界测试 ---");
        test_mult(16'h8000,   16'h8000,    0, 0); // -32768 * -32768
        test_mult(16'hFFFF,   16'hFFFF,    1, 1); // 65535 * 65535
        test_mult(16'h8000,   16'hFFFF,    0, 1); // -32768 * 65535
        test_mult(16'hFFFF,   16'h8000,    1, 0); // 65535 * -32768

        #50;
        $display("\n=================== TESTS COMPLETE ===================");
        $finish; 
    end
endmodule