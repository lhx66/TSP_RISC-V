# LSU 非对齐访问检测方案

## 已完成的修改

### 1. exu_ls.v - 添加了非对齐访问检测
- 新增输出端口：`ls_misaligned_o`, `ls_misaligned_addr_o`, `ls_misaligned_type_o`
- 检测规则：
  - LW/SW: 地址必须4字节对齐 (addr[1:0] == 0)
  - LH/LHU/SH: 地址必须2字节对齐 (addr[0] == 0)
  - LB/LBU/SB: 总是对齐的

### 2. 需要继续修改的文件

为了让调试信号能够被观察到，需要修改以下文件：

#### 方案A：通过LED显示（推荐用于快速验证）
1. 修改 `RTL/core/core.v`：
   - 在 TSP_Exu_ls 实例化中连接新增的调试端口
   - 添加内部连线传递信号到顶层

2. 修改 `FPGA/pango_cpu/source/peripheral/soc_top.v`：
   - 添加LED输出端口
   - 将非对齐检测信号连接到LED

#### 方案B：通过UART打印（推荐用于详细调试）
1. 在检测到非对齐访问时，通过UART输出调试信息
2. 输出格式：
   ```
   [LSU ERROR] Misaligned access detected!
   [LSU ERROR] Type: LW/LH/SW/SH
   [LSU ERROR] Address: 0xXXXXXXXX
   ```

## 快速验证步骤

### 方法1：使用SignalTap/ChipScope等在线逻辑分析仪
1. 综合包含检测逻辑的RTL代码
2. 在LSU模块中添加探针观察：
   - `misaligned_flag_r` - 检测标志
   - `misaligned_addr_r` - 错误地址
   - `misaligned_type_r` - 访问类型
3. 运行CoreMark，观察是否触发检测

### 方法2：添加简单的LED指示
在 `soc_top.v` 中添加：
```verilog
output wire [3:0] debug_led  // 新增LED输出

// 在TSP_Core模块实例化后：
assign debug_led[0] = ls_misaligned;  // 检测到非对齐访问时点亮LED
```

### 方法3：通过UART输出（需要修改UART驱动）
1. 添加UART打印函数
2. 在检测到非对齐访问时调用
3. 通过串口调试助手观察输出

## 预期结果

如果确实是非对齐访问导致的问题：
- LED会点亮（方案1/2）
- UART会打印错误信息（方案3）
- 逻辑分析仪会捕获到检测信号（方案1）

## 下一步

一旦确认是非对齐访问导致的问题，就需要修复LSU硬件以支持非对齐访问：
1. 检测地址对齐状态
2. 如果非对齐，分解为多个字节访问
3. 重新组装结果

详见：LSU_UNALIGNED_FIX.md（待创建）
