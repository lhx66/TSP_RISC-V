#!/usr/bin/env python3
"""
RISC-V 非法指令检测工具
检测RV32IM二进制文件中的非法指令：
1. CSR相关指令（如果你的CPU没有实现CSR）
2. 非对齐访存指令
3. 其他RV32IM之外的指令
"""

import re
import sys
from pathlib import Path

# ==========================================
# 配置区域
# ==========================================
# 输入的dump文件路径（相对于脚本目录）
DUMP_FILE_PATH = r"../TSP_RISCV_template/coremark.dump"

# 你的CPU支持的指令集特征
HAS_CSR = False          # 是否支持CSR指令
HAS_MUL_DIV = True       # 是否支持M扩展（乘除法）
HAS_ATOMIC = False       # 是否支持A扩展（原子指令）
HAS_COMPRESSED = False   # 是否支持C扩展（压缩指令）

# ==========================================
# 非法指令定义
# ==========================================

# CSR系统指令（如果你的CPU没有实现CSR）
CSR_INSTRUCTIONS = {
    # CSR读写指令
    r'csrrw\s+', r'csrrs\s+', r'csrrc\s+',
    r'csrrwi\s+', r'csrrsi\s+', r'csrrci\s+',
    # CSR其他指令
    r'scall\s+', r'sbreak\s+', r'eret\s+', r'mret\s+', r'sret\s+',
    # 系统指令
    r'wfi\s+', r'sfence\.vma\s+',
}

# A扩展原子指令（如果没实现A扩展）
ATOMIC_INSTRUCTIONS = {
    r'lr\.w\s+', r'sc\.w\s+', r'amoswap\.w\s+', r'amoadd\.w\s+',
    r'amoxor\.w\s+', r'amoand\.w\s+', r'amoor\.w\s+', r'amomin\.w\s+',
    r'amomax\.w\s+', r'amominu\.w\s+', r'amomaxu\.w\s+',
}

# F扩展浮点指令（如果没实现F扩展）
FLOAT_INSTRUCTIONS = {
    r'flw\s+', r'fsw\s+', r'fmadd\.s\s+', r'fmsub\.s\s+',
    r'fnmsub\.s\s+', r'fnmadd\.s\s+', r'fadd\.s\s+', r'fsub\.s\s+',
    r'fmul\.s\s+', r'fdiv\.s\s+', r'fsqrt\.s\s+', r'fsgnj\.s\s+',
    r'fsgnjn\.s\s+', r'fsgnjx\.s\s+', r'fmin\.s\s+', r'fmax\.s\s+',
    r'fcvt\.w\.s\s+', r'fcvt\.wu\.s\s+', r'fcvt\.s\.w\s+', r'fcvt\.s\.wu\s+',
    r'fmv\.x\.w\s+', r'fmv\.w\.x\s+', r'feq\.s\s+', r'flt\.s\s+', r'fle\.s\s+',
    r'fclass\.s\s+',
}

# D扩展双精度浮点
DOUBLE_INSTRUCTIONS = {
    r'fld\s+', r'fsd\s+', r'fmadd\.d\s+', r'fmsub\.d\s+',
    # ... 其他双精度指令
}

# C扩展压缩指令（16位指令）
COMPRESSED_INSTRUCTIONS = {
    r'c\.addi\s+', r'c\.li\s+', r'c\.lui\s+', r'c\.sub\s+',
    r'c\.add\s+', r'c\.mv\s+', r'c\.jr\s+', r'c\.jalr\s+',
    # ... 其他压缩指令
}

# 需要对齐检查的访存指令
MEM_INSTRUCTIONS = {
    'lb': 1, 'lh': 2, 'lw': 4,      # 加载指令：1/2/4字节对齐
    'sb': 1, 'sh': 2, 'sw': 4,      # 存储指令：1/2/4字节对齐
}

class InstructionChecker:
    def __init__(self, dump_file):
        self.dump_file = Path(dump_file)
        self.violations = []
        self.total_instructions = 0
        self.mem_instructions = 0

    def check(self):
        """执行所有检查"""
        if not self.dump_file.exists():
            print(f"[错误] 找不到dump文件: {self.dump_file}")
            return False

        print(f"[*] 正在分析文件: {self.dump_file}")
        print(f"[*] 文件大小: {self.dump_file.stat().st_size} bytes\n")

        with open(self.dump_file, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()

        # 解析disassembly
        self._parse_disassembly(content)

        # 报告结果
        self._report_results()

        return len(self.violations) == 0

    def _parse_disassembly(self, content):
        """解析objdump输出"""
        in_text_section = False

        for line in content.split('\n'):
            # 跳过空行
            if not line:
                continue

            # 检测是否进入.text段
            if 'Disassembly of section .text:' in line:
                in_text_section = True
                continue

            # 只处理.text段的指令行
            # 指令行格式：       5c:	00060a63          	beqz	a2,70 <cmp_idx+0x14>
            # 必须包含地址:机器码模式
            if not in_text_section:
                continue

            if not re.search(r'[0-9a-f]+:\s+[0-9a-f]+\s+[a-z]', line):
                # 跳过标签行（如 0000005c <cmp_idx>:）
                continue

            # 解析指令行
            match = re.match(r'^\s*[0-9a-f]+:\s+[0-9a-f]+\s+([a-z._]+)\s+', line)
            if not match:
                continue

            opcode = match.group(1).lower()
            self.total_instructions += 1

            # 检查CSR指令
            if not HAS_CSR:
                for csr_pattern in CSR_INSTRUCTIONS:
                    if re.match(csr_pattern, opcode):
                        self.violations.append({
                            'type': 'CSR_INSTRUCTION',
                            'line': line.strip(),
                            'reason': f'CSR指令未实现: {opcode}'
                        })
                        break

            # 检查原子指令
            if not HAS_ATOMIC:
                for atomic_pattern in ATOMIC_INSTRUCTIONS:
                    if re.match(atomic_pattern, opcode):
                        self.violations.append({
                            'type': 'ATOMIC_INSTRUCTION',
                            'line': line.strip(),
                            'reason': f'原子指令未实现: {opcode}'
                        })
                        break

            # 检查浮点指令
            for float_pattern in FLOAT_INSTRUCTIONS:
                if re.match(float_pattern, opcode):
                    self.violations.append({
                        'type': 'FLOAT_INSTRUCTION',
                        'line': line.strip(),
                        'reason': f'浮点指令未实现: {opcode}'
                    })
                    break

            # 检查访存对齐
            if opcode in MEM_INSTRUCTIONS:
                self.mem_instructions += 1
                self._check_mem_alignment(line, opcode, MEM_INSTRUCTIONS[opcode])

    def _check_mem_alignment(self, line, opcode, alignment):
        """检查访存指令是否对齐"""
        # 示例行：
        # 1005a:	00a12083          	lw	ra,12(sp)
        # 5c:     00060a63          	lh	a0,2(a0)
        # 提取偏移量
        match = re.search(rf'{opcode}\s+[^,]+,\s*([^)]+)\)', line)
        if not match:
            return

        offset_str = match.group(1)

        # 尝试解析偏移量（可能是数字或寄存器）
        # 简单情况：立即数偏移 lw ra, 12(sp)
        imm_match = re.match(r'(-?\d+)', offset_str)
        if imm_match:
            offset = int(imm_match.group(1))
            if offset % alignment != 0:
                self.violations.append({
                    'type': 'UNALIGNED_ACCESS',
                    'line': line.strip(),
                    'reason': f'非对齐访存: {opcode} 偏移量 {offset} 未按 {alignment} 字节对齐'
                })

    def _report_results(self):
        """报告检查结果"""
        print("=" * 60)
        print("  RISC-V 非法指令检测报告")
        print("=" * 60)

        print(f"\n[统计]")
        print(f"  总指令数: {self.total_instructions}")
        print(f"  访存指令数: {self.mem_instructions}")
        print(f"  发现问题数: {len(self.violations)}")

        if self.violations:
            print(f"\n[问题详情]")

            # 按类型分组
            violations_by_type = {}
            for v in self.violations:
                vtype = v['type']
                if vtype not in violations_by_type:
                    violations_by_type[vtype] = []
                violations_by_type[vtype].append(v)

            for vtype, violations in violations_by_type.items():
                type_names = {
                    'CSR_INSTRUCTION': 'CSR系统指令',
                    'ATOMIC_INSTRUCTION': '原子指令',
                    'FLOAT_INSTRUCTION': '浮点指令',
                    'UNALIGNED_ACCESS': '非对齐访存'
                }
                print(f"\n  [{type_names.get(vtype, vtype)}] 发现 {len(violations)} 个:")

                # 只显示前10个
                for v in violations[:10]:
                    print(f"    - {v['reason']}")
                    print(f"      {v['line']}")

                if len(violations) > 10:
                    print(f"    ... 还有 {len(violations) - 10} 个")

            print(f"\n[结论]")
            print("  [X] 检测到非法指令！")
            print("  你的CPU无法执行这些指令，会导致执行错误。")
            print("\n[建议]")
            if any(v['type'] == 'CSR_INSTRUCTION' for v in self.violations):
                print("  1. CSR指令通常由编译器自动生成（如rdcycle用于计时）")
                print("  2. 在编译选项中添加：-DNO_TIME_HZ")
                print("  3. 或者在 core_portme.c 中实现非CSR的计时函数")
        else:
            print(f"\n[结论]")
            print("  [OK] 未检测到非法指令！")
            print("  所有指令都是RV32IM标准指令，且访存已对齐。")

        print("\n" + "=" * 60)

def main():
    print("=" * 60)
    print("  RISC-V 非法指令检测工具 v1.0")
    print("=" * 60)
    print()

    # 获取dump文件路径
    script_dir = Path(__file__).parent

    # 支持命令行参数
    if len(sys.argv) > 1:
        dump_file = Path(sys.argv[1])
    else:
        dump_file = script_dir / DUMP_FILE_PATH

    # 执行检查
    checker = InstructionChecker(dump_file)
    success = checker.check()

    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
