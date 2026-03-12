import struct
import os

# ==========================================
# 用户自由配置区
# ==========================================
# 1. 输入的 bin 文件路径 (可以是相对或绝对路径)
BIN_FILE_PATH = r"E:\FPGA\TSP_RVmaster\template\TSP_RISCV_template\obj\TSP_RISCV_template.bin"

# 2. 输出的 txt 文件路径
IRAM_TXT_PATH = r"E:\FPGA\TSP_RVmaster\FPGA\pango_cpu\source\boot.txt"
SRAM_TXT_PATH = r"E:\FPGA\TSP_RVmaster\FPGA\pango_cpu\source\sram_init.txt"

# 3. 架构内存映射 (严格对应你的 CPU 物理地址)
IRAM_BASE = 0x00000000
IRAM_SIZE = 64 * 1024       # 64KB IRAM

SRAM_BASE = 0x20000000
SRAM_SIZE = 32 * 1024       # 32KB SRAM
# ==========================================

def bin_to_hex_txt(bin_data, txt_path):
    """将二进制字节流转换为 32-bit 十六进制字符串文本"""
    with open(txt_path, 'w') as f_out:
        # 每次读取 4 个字节 (一个字)
        for i in range(0, len(bin_data), 4):
            chunk = bin_data[i:i+4]
            # 补齐不足 4 字节的末尾
            if len(chunk) < 4:
                chunk += b'\x00' * (4 - len(chunk))
                
            # '<I' 表示以小端模式(Little-Endian)解包 32 位无符号整数
            word = struct.unpack('<I', chunk)[0]
            f_out.write(f'{word:08x}\n')
            
    print(f"  [+] 成功生成: {txt_path} (占用空间: {len(bin_data)} Bytes)")

def main():
    print("==================================================")
    print("      RISC-V Bin to Txt Converter (Auto-Split)    ")
    print("==================================================")
    
    if not os.path.exists(BIN_FILE_PATH):
        print(f"[!] 错误: 找不到文件 {BIN_FILE_PATH}！")
        print("    请检查 MounRiver Studio 是否编译成功，或者路径是否配置正确。")
        return

    file_size = os.path.getsize(BIN_FILE_PATH)
    print(f"[*] 读取到 .bin 文件，总大小: {file_size} Bytes")

    with open(BIN_FILE_PATH, 'rb') as f_in:
        # 1. 提取 IRAM 数据 (最多读取 IRAM_SIZE)
        iram_data = f_in.read(IRAM_SIZE)
        print("\n[*] 正在提取 IRAM 代码段...")
        bin_to_hex_txt(iram_data, IRAM_TXT_PATH)

        # 2. 智能探测 SRAM 区域
        # 如果文件大小跨越了 0x20000000，说明编译器生成了绝对地址的巨型 bin
        if file_size > SRAM_BASE:
            print(f"\n[*] 探测到独立的 SRAM 数据区 (偏移 {hex(SRAM_BASE)})...")
            f_in.seek(SRAM_BASE)
            sram_data = f_in.read(SRAM_SIZE)
            bin_to_hex_txt(sram_data, SRAM_TXT_PATH)
        else:
            print("\n[*] 未检测到独立的 SRAM 数据区。")
            print("    (提示: 因为使用了 AT > IRAM，数据区已被压缩在 IRAM 中，")
            print("     CPU 将在 startup.S 中自动将其搬运至 SRAM。非常完美！)")

    print("\n==================================================")
    print("转换完成！你可以将生成的 txt 喂给 FPGA 的 $readmemh 了！")

if __name__ == "__main__":
    main()