#!/bin/bash

# ==========================================
#   RISC-V CoreMark 一键编译和转换脚本
# ==========================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   RISC-V CoreMark 自动构建工具 v1.0${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/../TSP_RISCV_template"

echo -e "${YELLOW}[INFO] 项目根目录: ${PROJECT_ROOT}${NC}"
echo -e "${YELLOW}[INFO] 项目目录: ${PROJECT_DIR}${NC}"
echo ""

# 步骤1: 清理旧的编译结果
echo -e "${GREEN}[1/4] 清理旧的编译文件...${NC}"
cd "${PROJECT_DIR}"
if [ -f Makefile ] || [ -f makefile ]; then
    make clean
    echo -e "${GREEN}    ✓ 清理完成${NC}"
else
    echo -e "${RED}    ✗ 错误: 找不到 Makefile${NC}"
    exit 1
fi
echo ""

# 步骤2: 编译项目
echo -e "${GREEN}[2/4] 开始编译 CoreMark...${NC}"
make
if [ $? -eq 0 ]; then
    echo -e "${GREEN}    ✓ 编译成功${NC}"
else
    echo -e "${RED}    ✗ 编译失败${NC}"
    exit 1
fi
echo ""

# 步骤3: 检查编译产物
echo -e "${GREEN}[3/4] 检查编译产物...${NC}"
BIN_FILE="${PROJECT_DIR}/coremark.bin"
if [ -f "$BIN_FILE" ]; then
    FILE_SIZE=$(stat -f%z "$BIN_FILE" 2>/dev/null || stat -c%s "$BIN_FILE" 2>/dev/null || echo "unknown")
    echo -e "${GREEN}    ✓ 找到 coremark.bin (大小: ${FILE_SIZE} bytes)${NC}"
else
    echo -e "${RED}    ✗ 错误: 找不到 coremark.bin${NC}"
    exit 1
fi
echo ""

# 步骤4: 转换为FPGA格式
echo -e "${GREEN}[4/4] 转换为 FPGA TXT 格式...${NC}"
cd "${SCRIPT_DIR}"
if [ -f "bin2txt.py" ]; then
    python3 bin2txt.py || python bin2txt.py
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}    ✓ 转换成功${NC}"
    else
        echo -e "${YELLOW}    ⚠ 转换脚本执行有问题，请检查${NC}"
    fi
else
    echo -e "${RED}    ✗ 错误: 找不到 bin2txt.py${NC}"
    exit 1
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}🎉 构建完成！${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}下一步操作:${NC}"
echo -e "  1. 查看生成的文件: ${GREEN}ls -lh ${PROJECT_ROOT}/FPGA/pango_cpu/source/boot.dat${NC}"
echo -e "  2. 在FPGA项目中综合比特流文件"
echo -e "  3. 下载到FPGA开发板测试"
echo ""
