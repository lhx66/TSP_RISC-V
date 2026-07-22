# RISC-V CoreMark 一键构建工具

## 📁 文件说明

本目录包含自动化构建脚本，用于编译CoreMark并转换为FPGA可用的格式。

### 脚本文件

- **build_and_convert.sh** - Linux/Mac/Git Bash 版本
- **build_and_convert.bat** - Windows CMD 版本
- **build_and_convert.py** - Python 通用版本（可选）
- **bin2txt.py** - Bin到Txt转换工具

## 🚀 使用方法

### 方法1: Git Bash / Linux / Mac

```bash
cd template/tools
./build_and_convert.sh
```

### 方法2: Windows CMD

```cmd
cd template\tools
build_and_convert.bat
```

### 方法3: 手动执行（调试用）

```bash
# 1. 进入项目目录
cd template/TSP_RISCV_template

# 2. 清理并编译
make clean
make

# 3. 转换为FPGA格式
cd ../tools
python bin2txt.py
```

## 📊 执行流程

脚本会自动执行以下步骤：

1. **清理** - `make clean` 清理旧的编译产物
2. **编译** - `make` 编译CoreMark程序
3. **检查** - 验证 `coremark.bin` 是否生成
4. **转换** - 运行 `bin2txt.py` 转换为FPGA TXT格式

## 📂 输出文件

编译成功后会生成以下文件：

- `template/TSP_RISCV_template/coremark.bin` - RISC-V二进制文件
- `FPGA/pango_cpu/source/boot.dat` - FPGA初始化文件（TXT格式）

## ⚙️ 配置修改

如果需要修改路径或参数，编辑以下文件：

- **bin2txt.py** - 修改输入输出路径
- **TSP_RISCV_template/Makefile** - 修改编译选项

## 🐛 常见问题

### Q: 提示"找不到Makefile"
**A:** 确保在正确的目录下执行脚本，或者检查项目结构是否完整。

### Q: 编译失败
**A:** 检查是否安装了RISC-V交叉编译工具链，并确保在PATH中。

### Q: 转换失败
**A:** 确保 Python 已安装，并检查 `bin2txt.py` 中的路径配置是否正确。

## 🔄 开发工作流

典型的CoreMark调试流程：

1. 修改源码（如 `core_portme.c`, `core_list_join.c` 等）
2. 运行 `build_and_convert.sh` (或 `.bat`)
3. 在FPGA项目中重新综合
4. 下载到FPGA测试
5. 观察串口输出
6. 重复步骤1-5

## 📝 版本历史

- **v1.0** (2024-03) - 初始版本，支持一键编译和转换
