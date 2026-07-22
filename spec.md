这是我的RV32IM指令集RISC-V项目。目前我完成了soc的FPGA上板测试。后续有任何补充说明请修改该文档
当前任务目标：
1.FPGA文件夹中是我将该soc在FPGA上的测试文件。FPGA\pango_cpu\ipcore中有pango FPGA用于仿真的RAM测试程序。请在其中复制有用的代码文件到RTL\peripheral文件夹中替代iram和sram。然后根据/rtl-verify来补充仿真脚本，完成仿真测试。这样后续FPGA文件夹中的代码可以和RTL文件夹中的保持一致
2.为soc增加非对齐指令访存功能。然后在github上下载一个合适的coremark跑分程序替代本地的coremark程序。本地已有gcc工具链，可以用来编译程序。然后用template\tools\bin2txt.py转换程序为机器码文件。完成这些后告诉我，我自己去编译FPGA程序测试

项目架构：
/FPGA/pango_cpu----pango开发板工程文件夹
/RTL/core----cpu核心文件夹
/RTL/peripheral----soc外设文件夹
/sim----仿真文件夹(目前有testbench代码文件和filelist文件，根据本机安装的skill /rtl-verify来补充仿真脚本。后续可以根据需求修改tb代码)
/TSP_RISCV_template----测试程序文件夹。包含coremark和drystone程序和bsp文件

## Current implementation plan (2026-07-22)

Goal: reuse the Pango dual-port IRAM/SRAM simulation models in RTL, verify and correct unaligned accesses, then replace, build, and convert CoreMark.

1. Create a `v<major>.<minor>.<patch>` version branch linked to `git@github.com:lhx66/TSP_RISC-V.git`; commit every verified milestone.
2. Add a self-checking testbench under `RTL/sim`; run it against the current `ls_ctrl` first and record the expected failure. Cover aligned, unaligned, and cross-word `LB/LBU/LH/LHU/LW/SB/SH/SW` transactions.
3. Use the failing assertions and AXI transaction trace to correct `RTL/core/ls_ctrl.v` and any required LSU front-end logic. Re-run the targeted test after each correction, then run the full RTL simulation.
4. Copy the IRAM/SRAM wrappers, initialization parameters, and simulation RTL from `FPGA/pango_cpu/ipcore/{IRAM,SRAM}` into `RTL/peripheral/ram`; update `RTL/peripheral/soc_top.v` and `RTL/peripheral/ram/sram.v` for the dual-port DTCM topology.
5. Complete the ModelSim file list and runner in `RTL/sim`, compiling generated RAM RTL, RAM wrappers, core, peripherals, and testbench in that order. The runner must exit non-zero for compile or assertion failures.
6. Download official EEMBC CoreMark sources, retain the existing BSP/startup/linker integration, build with `riscv-none-elf-gcc -march=rv32im -mabi=ilp32`, and run `template/tools/bin2txt.py` to generate the loadable machine-code text image.
7. Record every change, test command, result, and limitation in this `spec.md`; do not add further standalone documentation files.
## Verification progress (2026-07-22)

- Installed verification flow located at `C:\Users\Administrator\.claude\commands\rtl-verify.md` is used. ModelSim scripts and self-checking tests are under `RTL/sim/tb_script`; the flow uses `[TB_MONITOR]`, `[TB_DATA]`, `[TB_ERROR]`, and no VCD output.
- `tb_ls_ctrl_unaligned.sv` passed on ModelSim 2020.4. It verifies cross-word `LW`, `LHU`, `SW`, and `SH` through the SRAM DTCM Port A, including returned data and byte strobes.
- The ModelSim-only `GTP_DRM18K_model.v` implements the generated Pango primitive interface sufficiently for the copied IRAM/SRAM wrappers, including dual-port program loading and instruction fetch in the full SoC simulation.

## Implemented architecture and regression status (2026-07-22)

- RAM source files are now under `RTL/peripheral/ram`: Pango-generated `IRAM`, `SRAM`, their parameter files and generated wrappers are under `ram/pango`; the simulation-only primitive replacement is `ram/GTP_DRM18K_model.v`. The obsolete behavioural `ram.v`, legacy SRAM-IP-only test runner, and unused `exu_ls_v2.v.bak` were removed.
- `TSP_Ifu` uses IRAM Port A as the CPU's direct, low-latency instruction-fetch path. IRAM Port B remains an AXI-Lite slave path for program download/debug; it is enabled only by `SoC_Top.ENABLE_EXT_IRAM_LOADER`, whose default remains disabled for FPGA builds.
- `ls_ctrl` sends SRAM accesses to the SRAM DTCM Port A and retains AXI-Lite for UART/timer/peripheral accesses. Unaligned SRAM accesses split into two DTCM beats when crossing a word boundary. `FPGA/pango_cpu/source/core/ls_ctrl.v` is synchronized from the verified RTL implementation.
- `RTL/sim/tb_script/tb_soc_program.sv` is the generic SoC testbench. It loads a word-per-line hex image through the reserved IRAM AXI download port, verifies IRAM readback, resets the CPU, and can self-check an observed UART AXI byte with `+EXPECT_UART=<hex>`.
- `template/tools/build_and_convert.bat <app>` builds `APP=<app>` and creates `RTL/sim/programs/<app>.hex`. `bin2txt.py` no longer contains machine-specific paths. `sim_smoke` is a minimal application under `template/TSP_RISCV_template/app`.
- Passing commands:
  - `cmd.exe /c sim.bat` in `RTL/sim/tb_script` — compiles all RTL and passes the DTCM unaligned-access regression.
  - `cmd.exe /c build_and_convert.bat sim_smoke` in `template/tools` — builds with `riscv-none-elf-gcc` and creates `RTL/sim/programs/sim_smoke.hex`.
  - `cmd.exe /c sim_soc.bat +PROGRAM=../programs/sim_smoke.hex +EXPECT_UART=50` in `RTL/sim/tb_script` — full SoC passes; the application emits UART byte `0x50` (`P`).
- Current CoreMark note: the test application intentionally has no initialized/readonly data, because the current architecture reserves IRAM Port B for downloading/debug rather than CPU data reads. CoreMark integration must either initialize its data in SRAM at runtime or introduce an explicit SRAM image-loader phase; this remains open before replacing/running CoreMark.

## Task 2 completion (2026-07-22)

- Non-aligned SRAM data accesses are implemented in `RTL/core/ls_ctrl.v` via the DTCM Port A. Cross-word `LW`, `LHU`, `SW`, and `SH` are covered by the passing ModelSim regression; the FPGA source copy is synchronized at `FPGA/pango_cpu/source/core/ls_ctrl.v`.
- The local CoreMark algorithm sources were replaced from the official EEMBC repository `https://github.com/eembc/coremark`, commit `1f483d5b8316753a742cbf5590caf5bd0a4e4777`. The project-specific `core_portme` timer/UART adapter is retained; official barebones `cvt.c` and `ee_printf.c` are used, with `uart_send_char()` bound to `uart_putc()`.
- `cmd.exe /c build_and_convert.bat coremark` passed using local `riscv-none-elf-gcc` with `-march=rv32im -mabi=ilp32`. It generated `template/TSP_RISCV_template/coremark.bin` (16,168 bytes) and `RTL/sim/programs/coremark.hex` (4,042 words), which fits the 64 KiB IRAM.
- This verifies source replacement, RV32IM compilation, linking, and binary-to-hex conversion. It does not claim a CoreMark score: the current direct-IRAM architecture requires an explicit SRAM initialization/download mechanism for CoreMark's initialized/readonly data before an on-hardware benchmark result is valid.
- Version control milestone: the complete verified workspace snapshot is committed and pushed on branch `v0.1.0` as `491c0d1` (`v0.1.0: integrate Pango RAM RTL and CoreMark build flow`).
