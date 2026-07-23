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
- The existing `template/tools/bin2txt.py` was also invoked directly to generate `RTL/sim/programs/coremark.txt` from the same binary. It is a 4,042-word, `$readmemh`-compatible instruction text image.
- This verifies source replacement, RV32IM compilation, linking, and binary-to-hex conversion. It does not claim a CoreMark score: the current direct-IRAM architecture requires an explicit SRAM initialization/download mechanism for CoreMark's initialized/readonly data before an on-hardware benchmark result is valid.
- Version control milestone: the complete verified workspace snapshot is committed and pushed on branch `v2.5.0` as `491c0d1` (`v0.1.0: integrate Pango RAM RTL and CoreMark build flow`); the historical commit message is retained, but the release branch is `v2.5.0`.

## Pango FPGA RTL synchronization (2026-07-22)

- The Pango project file `FPGA/pango_cpu/pango_cpu.pds` was checked directly. It compiles the RTL below `FPGA/pango_cpu/source` plus its own generated PLL, IRAM, and SRAM IP sources.
- The Pango copies of `defines.v`, `exu_ls.v`, `Ifu.v`, `PC_control.v`, `AXI_Interconnect.v`, `soc_top.v`, `ram/sram.v`, `uart_axi_lite_wrapper.v`, and `timer.v` are synchronized with their corresponding verified `RTL` sources. This includes the two-entry BTB configuration, unaligned DTCM LSU path, IRAM address decode, and the default-disabled `ENABLE_EXT_IRAM_LOADER` parameter.
- The FPGA-only `ipcore/sys_pll` and generated `ipcore/{IRAM,SRAM}` files remain Pango project inputs; the ModelSim-only `RTL/peripheral/sys_pll_sim.v` and `GTP_DRM18K_model.v` are not used for FPGA synthesis. UART and timer retain their FPGA-directory-relative include path as the only textual difference from `RTL`.
- Verification after synchronization: a forced ModelSim recompilation of the complete `RTL/sim/tb_script/modelsim_filelist.f` completed with 0 errors and 0 warnings; `sim.bat` passed the unaligned-access regression; and `sim_soc.bat +PROGRAM=../programs/sim_smoke.hex +EXPECT_UART=50` passed the whole-SoC IRAM-load/UART check (`0x50`, `P`).

## CoreMark performance build (2026-07-23)

- The previous CoreMark build used `-O2` and fixed `ITERATIONS=1000`. The benchmark build now defaults to `-O3` for RV32IM, while non-benchmark applications retain `-O2`. `COREMARK_OPT_LEVEL` remains overridable from `make` for an explicitly disclosed comparison build.
- CoreMark's own `core_main.c` specifies that an iteration value of zero performs a calibration run and selects an execution length of approximately 10 seconds or more. `core_portme.h` now permits that configuration, and the Makefile supplies `ITERATIONS=0`. The timer is an increasing 32-bit counter and the Pango PLL configuration confirms that `clkout0` is 50 MHz, matching `EE_TICKS_PER_SEC=50000000`.
- `cmd.exe /c build_and_convert.bat coremark` was rebuilt with `riscv-none-elf-gcc` 15.2.0 using `-march=rv32im -mabi=ilp32 -O3`; the emitted compiler diagnostic records the full GCC flags. The generated `coremark.bin` is 21,712 bytes and the matching `RTL/sim/programs/coremark.hex` and `coremark.txt` are 5,428 words each, fitting the 64 KiB IRAM.
- `template/tools/build_and_convert.bat` now accepts a `PYTHON` environment variable, so a valid Python executable can be selected when `python` is not on PATH. The benchmark must be timed on the 50 MHz FPGA hardware after loading; an event-driven RTL simulation is not a valid replacement for the calibrated 10-second score run.

## CoreMark Harvard-memory image flow (2026-07-23)

- The CoreMark boot flow now follows the IRAM/SRAM separation: `.text` is linked at IRAM address `0x00000000`; `.rodata` and `.data` are linked directly at SRAM address `0x20000000`; `.bss` remains in SRAM and is cleared by startup code. The former `AT > IRAM` load image and the startup loop that read `.data` through the IRAM AXI port were removed.
- `template/tools/bin2txt.py` supports `--elf` and extracts `.text` plus `.data` with `riscv-none-elf-objcopy`. It emits Pango-compatible word-per-line initialization images. The SRAM file contains only initialized `.data/.rodata`; startup code clears `.bss`, so no full-SRAM zero padding is required.
- `build_and_convert.bat coremark` now emits `FPGA/pango_cpu/source/coremark_iram.dat` (4,789 words, 19,156 bytes) and `coremark_sram.dat` (627 words, 2,508 bytes). The previous single `RTL/sim/programs/coremark.hex/.txt` files were removed because they incorrectly mixed the IRAM and SRAM images.
- Pango IP configuration was intentionally not modified: select `coremark_iram.dat` as the IRAM initialization file and `coremark_sram.dat` as the SRAM initialization file, regenerate the two IPs, then rebuild the FPGA project. This is the remaining board-side action before hardware timing and UART score collection.
- `ls_ctrl` no longer routes data-side IRAM addresses to AXI; those accesses complete with a deterministic zero read value and ignored writes. The synchronized Pango source is `FPGA/pango_cpu/source/core/ls_ctrl.v`. The targeted ModelSim regression covers this isolation in addition to existing unaligned DTCM access tests.
- Verification: the CoreMark `-O3` ELF build and both image exports passed; ModelSim `sim.bat` passed the unaligned-DTCM and IRAM-data-isolation regression; `sim_soc.bat +PROGRAM=../programs/sim_smoke.hex +EXPECT_UART=50` passed the short full-SoC UART smoke test. CoreMark itself was not run in RTL simulation.

## CoreMark subword-store hardening (2026-07-23)

- FPGA run evidence: the calibrated 2K CoreMark run completed (1,100 iterations, matrix CRC `0x1fd7` correct), while list/state CRCs were incorrect. The failure pattern isolates the state-machine workload, which is dominated by `SB`/`LBU`, rather than the IRAM image, timer, or matrix algorithm.
- `ls_ctrl` now implements every partial DTCM write as a local read-modify-write transaction. Aligned full-word stores still write directly; `SB`, `SH`, and all cross-word stores first read the affected word, merge bytes in the controller, then perform a `dtcm_be_o=4'b1111` full-word write. This removes functional dependence on Pango SRAM primitive byte-enable encoding while preserving byte, half-word, and unaligned RV32 memory semantics. The same RTL is synchronized to `FPGA/pango_cpu/source/core/ls_ctrl.v`.
- TDD regression: `tb_ls_ctrl_unaligned.sv` was first extended to reject partial DTCM writes; the pre-change RTL failed exactly on that assertion. After the RMW implementation, `cmd.exe /c sim.bat` passes and verifies cross-word `SW`/`SH`, `SB`, signed/unsigned byte loads, adjacent-byte preservation, full-word DTCM writes only, and blocked CPU data-side IRAM reads.
- Board action: rebuild the Pango FPGA project with the synchronized source RTL. No Pango IP initialization setting was changed by this update; retain the existing CoreMark IRAM/SRAM initialization files when generating the bitstream, then rerun CoreMark and collect the four CRC values.

## DTCM byte-enable restoration (2026-07-23)

- The FPGA CoreMark CRCs were unchanged after the read-modify-write experiment, so byte-enable encoding is not the confirmed root cause. The experiment was removed at the user's request: `ls_ctrl` again emits the original direct DTCM byte strobes for `SB`, `SH`, and unaligned write beats.
- The Pango source copy is synchronized with the restored RTL. The targeted regression retains byte-store and signed/unsigned byte-load checks, but no longer requires full-word writes for subword stores.
- The remaining investigation target is the generated SRAM initialization content and its mapping to the state-machine pattern data; no additional functional fix was made in this restoration revision.

## CoreMark state-initialization diagnostic (2026-07-23)

- A reproducible board-side diagnostic was added without changing the default benchmark: `COREMARK_STATE_INIT_DIAG` defaults to `0`; `build_and_convert.bat coremark 1` builds a diagnostic image with it enabled. It prints the four `intpat`, `floatpat`, `scipat`, and `errpat` pointers plus the first 32-bit word at each pointer before CoreMark initialization.
- The current generated diagnostic images are `FPGA/pango_cpu/source/coremark_iram.dat` (19,564 bytes) and `coremark_sram.dat` (2,860 bytes). They are intentionally diagnostic images, not a valid score image. Regenerate the Pango IRAM/SRAM initialization IPs with these files before programming the FPGA.
- Expected diagnostic output values are:
  - `int_ptr 20000478 20000470 20000468 20000460`, `int_dat 32313035 34333231 3437382d 3232312b`
  - `float_ptr 200004fc 200004f0 200004e4 200004d8`, `float_dat 352e3533 3332312e 3031312d 362e302b`
  - `sci_ptr 20000584 20000578 2000056c 20000560`, `sci_dat 30352e35 32312e2d 6537382d 362e302b`
  - `err_ptr 2000060c 20000600 200005f4 200005e8`, `err_dat 332e3054 542e542d 2e335431 302e3433`
- Verification: `build_and_convert.bat coremark 1` passed with GCC 15.2.0 and `COREMARK_STATE_INIT_DIAG=1`; the rebuilt ELF contains all `[STATE_DIAG]` markers in its SRAM `.data` section.
