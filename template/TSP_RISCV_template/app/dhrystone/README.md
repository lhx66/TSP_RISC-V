# Dhrystone for RISC-V RV32IM

## 📊 概述

Dhrystone是一个比CoreMark更简单的基准测试程序，适合验证CPU的基本功能：
- 整数运算
- 函数调用
- 字符串操作
- 指针操作
- 控制流

## 🚀 快速开始

### 编译

```bash
cd template/TSP_RISCV_template/app/dhrystone
make clean
make
```

### 运行

```bash
make run
```

这会：
1. 编译dhrystone
2. 生成dhrystone.bin
3. 自动转换为FPGA格式

### 预期输出

```
Dhrystone Benchmark for RISC-V RV32IM
Version 2.1 (Language: C)

Execution starts...

[输出Dhrystone统计信息]

Dhrystone completed!
```

## 📁 文件说明

- `dhry_1.c, dhry_2.c` - Dhrystone核心代码
- `strcmp.S` - 字符串比较（汇编优化）
- `dhry.h` - 类型定义和接口
- `dhrystone_portme.c` - 移植层（main函数，初始化）
- `stdio.h` - 简化的I/O接口
- `Makefile` - 构建配置

## ⚙️ 配置选项

在Makefile中可以修改：

```makefile
DDHRY_ITERS=1000  # 迭代次数（默认1000）
```

迭代次数建议：
- **快速验证**: 100-500
- **正式测试**: 1000-2000
- **长时间测试**: 10000+

## 🎯 与CoreMark对比

| 特性 | Dhrystone | CoreMark |
|------|-----------|----------|
| 复杂度 | 简单 | 复杂 |
| 测试重点 | CPU基本功能 | 综合性能（包括内存系统） |
| 代码大小 | ~5KB | ~17KB |
| 运行时间 | 短 | 长 |
| 调试难度 | 容易 | 困难 |

## 🔧 故障排除

### 编译错误

1. **找不到ee_printf**: 确保bsp/syscalls.c实现了ee_printf
2. **链接错误**: 检查Makefile中的路径是否正确
3. **优化问题**: 尝试降低优化级别（-O2或-O0）

### 运行时错误

1. **无输出**: 检查UART初始化和波特率
2. **程序hang**: 检查是否有无限循环或异常
3. **分数异常**: 验证timer频率设置

## 📈 结果解读

Dhrystone输出格式：
```
Dhrystones_Per_Second: XXXX
DMIPS: XXXX
```

- **Dhrystones_Per_Second**: 每秒执行的Dhrystone次数
- **DMIPS**: Dhrystones/Second / 1757 (标准化分数)

典型的DMIPS分数：
- 简单RISC-V: 100-500 DMIPS
- 高性能RISC-V: 500-2000+ DMIPS

## 🔄 构建工作流

```bash
# 1. 修改代码（如果需要）
nano dhrystone_portme.c

# 2. 编译
make

# 3. 转换（自动）
# bin2txt.py会自动运行

# 4. 在FPGA项目中综合
# 使用Pango Design工具

# 5. 下载到FPGA

# 6. 观察串口输出
```

## 📝 注意事项

1. **非对齐访问**: Dhrystone也使用指针，如果CPU不支持非对齐访问会有问题
2. **栈空间**: Dhrystone使用递归，确保栈足够大
3. **Timer精度**: Dhrystone需要准确的计时，建议使用硬件timer

## 🆘 切换到CoreMark

当Dhrystone成功运行后，可以尝试CoreMark：
1. 先验证Dhrystone分数正常
2. 确认CPU基本功能稳定
3. 然后解决CoreMark的复杂链表问题
