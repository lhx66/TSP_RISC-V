这是我的RV32IM指令集低功耗RISC-V soc项目。目前我完成了soc的FPGA上板测试。后续有任何补充说明请修改该文档
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

## CoreMark dynamic state-buffer diagnostic (2026-07-23)

- Board evidence from the preceding diagnostic exactly matches all 32 static pattern pointers and words listed above. This excludes the CoreMark SRAM initialization image, its Pango mapping, and the static pattern pointer table as the cause of the state/list CRC failures.
- The diagnostic image now also prints `[STATE_DIAG] init_crc <crc> first <word>` immediately after `core_init_state()` constructs the 666-byte dynamic state buffer. The checksum is the CoreMark `crcu8` reduction over every byte, so it detects any incorrect byte write without depending on a particular SRAM word layout.
- A host-side reference execution of the same pattern-selection and CRC algorithm gives `init_crc ef98`, `first 32313035` (ASCII `5012`, little-endian), with byte 660 being the first zero-filled tail byte. If FPGA output differs, the error is in CPU/LSU dynamic byte-write initialization. If it matches, initialization is correct and the remaining fault is in state-machine execution, principally its `LBU`/branch path.
- Verification: `build_and_convert.bat coremark 1` passed with GCC 15.2.0; `riscv-none-elf-strings coremark.elf` confirms the new `init_crc` diagnostic marker. The generated diagnostic images contain a 19,860-byte `.text` payload and a 2,900-byte `.data` payload. Regenerate both Pango IPs from `coremark_iram.dat` and `coremark_sram.dat`, then rebuild/program the FPGA before collecting the new line.

## CoreMark diagnostic-board result and release image (2026-07-23)

- The diagnostic bitstream reported `init_crc ef98 first 32313035`, exactly matching the host reference. Its CoreMark run then reported the expected CRCs `crclist=e714`, `crcmatrix=1fd7`, and `crcstate=8e3a`, followed by `Correct operation validated.` The observed calibrated result was 1,100 iterations in 939,394,914 50 MHz ticks (61 iterations/s after CoreMark's integer-second conversion).
- The dynamic-state readback and CRC calculation occur before CoreMark calls `start_time()`, so they are excluded from both calibration and the reported benchmark interval. They are nevertheless diagnostic-only code and are not retained in the release image.
- `build_and_convert.bat coremark` was rerun with the default `COREMARK_STATE_INIT_DIAG=0`. It passed with GCC 15.2.0 and `riscv-none-elf-strings coremark.elf` confirmed no `[STATE_DIAG]` marker. The release image payloads are `.text` 19,156 bytes and `.data` 2,508 bytes. These are the current `FPGA/pango_cpu/source/coremark_iram.dat` and `coremark_sram.dat`; regenerate the Pango IPs from them before the final non-diagnostic FPGA score run.
- Fresh Git comparison confirms that the two non-diagnostic initialization files are byte-identical to the earlier `v2.5.6` release that had failed CRCs. Consequently, the diagnostic-board success does not yet prove a change to the release program image. The final non-diagnostic board run is the discriminator: a pass identifies a previously stale/incorrect Pango-generated IP or programmed bitstream; a repeat failure identifies a code-layout or memory-order-sensitive CPU/LSU issue, for which the diagnostic checksum/readback acts as a reproducer.

## CoreMark BPU-off isolation experiment (2026-07-23)

- The non-diagnostic image reproduced the original failures despite being byte-identical to the diagnostic image's functional benchmark source. In contrast, the diagnostic program moved `core_state_transition` from IRAM address `0x2144` to `0x22d4` and changed the dynamic branch history before the branch-dense state-machine workload. The SRAM dynamic-buffer checksum had already matched exactly, so this is a BPU/IFU-control hypothesis rather than a RAM-data hypothesis.
- `PC_control` now has an `ENABLE_BTB` parameter. The temporary experimental core instantiation sets it to `0`, which forces every fetch to use sequential `PC+4`; real branch/jump resolution and redirect remain active. No LSU, SRAM wrapper, Pango IP setting, or CoreMark initialization image was changed.
- TDD verification: `tb_pc_control_no_btb.sv` first failed because the BPU-disable parameter was absent. With the parameter implemented, it injects a taken BTB entry and verifies that BPU-off mode still reports `pre_pc_taken=0` and advances to `PC=4`. ModelSim passed this test, `sim.bat` (DTCM regression), and `sim_soc.bat +PROGRAM=../programs/sim_smoke.hex +EXPECT_UART=50` (whole-SoC UART smoke).
- Board discriminator: rebuild the FPGA using this temporary BPU-off RTL and the unchanged, non-diagnostic `coremark_iram.dat` / `coremark_sram.dat`. If CoreMark CRCs pass, the fault is confirmed in BTB prediction/flush handling; if they fail unchanged, the BPU is excluded and investigation returns to the load-result/control dependency path. This experiment will be reverted or replaced by a targeted BPU fix after the result.

## CoreMark SRAM-bank-boundary isolation experiment (2026-07-23)

- Board result for the BPU-off build was unchanged (`crclist=175e`, `crcstate=e553`), so BTB prediction/flush is excluded. The default BPU setting is restored in the core; the `ENABLE_BTB` parameter and its isolated regression remain available for future testing.
- Link-map analysis identifies a single address-boundary difference between the failing release and the passing diagnostic image. In the failing release, `my_heap=0x200009f0` and the state input is `0x20000f24..0x200011c5`, crossing the 4 KiB boundary at `0x20001000`. In the passing diagnostic image, `my_heap=0x20000b78` and the state input is `0x200010ac..0x20001345`, entirely on the next bank.
- The Pango SRAM configuration is 13-bit words × 32 bits with byte writes. Its generated DRM wrapper selects one of eight physical 1,024-word (4 KiB) banks with address bits `[12:10]`; this exactly matches the observed boundary. The matrix workspace remains below that boundary and has the correct CRC, while the state workspace is the only benchmark workspace that crosses it.
- A reproducible no-diagnostic discriminator is added: `COREMARK_HEAP_ALIGN` defaults to `8`; `build_and_convert.bat coremark 0 4096` aligns `my_heap` to a 4 KiB page. The generated normal ELF has `my_heap=0x20002000`, no `[STATE_DIAG]` strings, and places the state input at `0x20002534..0x200027d5`, entirely within one DRM bank. The original CoreMark data size and runtime algorithm are unchanged.
- TDD verification: before the option existed, a build requesting `COREMARK_HEAP_ALIGN=4096` left `my_heap=0x200009f0` and failed the map-address check. After implementation, the build/export passed and the ELF symbol check confirmed the page-aligned heap. ModelSim `sim.bat` and `sim_soc.bat +PROGRAM=../programs/sim_smoke.hex +EXPECT_UART=50` also pass with BPU restored. Rebuild the FPGA with the new normal initialization images; a passing CRC result confirms the physical SRAM-bank crossing as the fault location, after which the RTL/IP bank-selection path can be fixed directly rather than retaining heap placement as a workaround.

## CoreMark architecture-level investigation: simulation-model correction (2026-07-23)

- Board evidence subsequently rejected the SRAM-bank-boundary hypothesis: the normal image with `COREMARK_HEAP_ALIGN=4096` still produced the unchanged failures `crclist=175e` and `crcstate=e553`. The page alignment remains an isolation option only; it is not a CoreMark workaround or confirmed RTL/IP fault.
- A new minimal application, `app/ls_dependency`, initializes four volatile SRAM bytes, performs 666 `LBU` then `SB` operations, and emits `P` only when every byte is preserved. Its RV32IM disassembly contains the intended `lbu a3,0(a5)` / `sb a3,0(a5)` sequence. It is executed by the existing generic all-RTL SoC testbench with `+PROGRAM=../programs/ls_dependency.hex +EXPECT_UART=50`.
- TDD red result: before the behavioral-model correction, the all-RTL simulation consistently emitted UART `F` and terminated with `[TB_ERROR] expected UART byte 50 was not observed`. This proved that the simulation flow could not validate CoreMark's byte-store workload.
- Root cause: `RTL/peripheral/ram/GTP_DRM18K_model.v` previously treated each `WEA`/`WEB` as an 18-bit whole-word write. The generated Pango SRAM wrapper uses two 16-bit DRM instances for a 32-bit word and encodes each halfword's two byte enables in `ADDRA[1:0]` / `ADDRB[1:0]`; byte data are DRM bits `[7:0]` and `[16:9]`, with parity bits `[8]` and `[17]`. The model therefore overwrote adjacent bytes for every simulated `SB` or `SH`.
- The model now preserves unselected byte lanes on both ports, matching the generated wrapper's enable encoding. Green result: the same complete SoC simulation emits UART `0x50` (`P`) and exits with zero errors. This correction is simulation-only; it changes neither FPGA synthesis RTL nor Pango IP configuration.
- Consequence for the board investigation: the reproducible simulation failure was a model defect, not evidence against LSU/OITF/branch behavior in FPGA hardware. The observed non-diagnostic CoreMark board discrepancy remains open and must next be isolated with this `ls_dependency` program on the FPGA before proposing further CPU RTL changes.

## FPGA LSU dependency probe image (2026-07-23)

- `template/tools/bin2txt.py --bin template/TSP_RISCV_template/ls_dependency.bin --iram-out FPGA/pango_cpu/source/ls_dependency_iram.dat` generated the FPGA IRAM initialization image for the minimal LSU byte-load/store probe.
- `ls_dependency_iram.dat` contains 61 little-endian 32-bit words (244 bytes). Its first four words are `20008137`, `20000517`, `ffc50513`, and `20000597`; it was compared line-by-line with the passing ModelSim image `RTL/sim/programs/ls_dependency.hex` and is identical.
- Board use: select `FPGA/pango_cpu/source/ls_dependency_iram.dat` as the IRAM initialization input in Pango, regenerate only IRAM, rebuild/program the FPGA, and leave SRAM initialization unchanged. Expected UART output is `P`; `F` proves a real FPGA-side dynamic byte-load/store failure independently of CoreMark.
- Board result: the FPGA emitted `P`. This excludes general dynamic SRAM byte writes, byte loads, basic LSU writeback, and the simple `LBU`-to-`SB` loop dependency as the cause of the CoreMark CRC mismatch. The fault is now constrained to a CoreMark-specific control-flow/code-layout interaction; no CPU RTL fix is justified from this test alone.

## FPGA unaligned-access probe (2026-07-23)

- `app/unaligned_access` is a standalone, runtime-SRAM self-check. Inline RV32 assembly forces the instructions under test despite `-mstrict-align`: an unaligned cross-word `SW`/`LW` at byte offset 1, and an unaligned cross-word `SH`/`LHU`/`LH` at byte offset 3. It also checks every affected byte so that incorrect adjacent-byte preservation cannot be hidden by a matching readback path.
- TDD red: before the app was registered, `build_and_convert.bat unaligned_access` failed exactly with `Unsupported APP 'unaligned_access'`. Green: after the minimal Makefile registration, GCC 15.2.0 built a 508-byte/127-word image. Its disassembly confirms `sw` then `lw` at `p+1`, and `sh`, `lhu`, `lh` at `p+3`.
- Complete ModelSim SoC verification passed: `sim_soc.bat +PROGRAM=../programs/unaligned_access.hex +EXPECT_UART=50` loaded 127 words and observed UART `0x50` (`P`). The existing direct `tb_ls_ctrl_unaligned.sv` remains the lower-level regression.
- `FPGA/pango_cpu/source/unaligned_access_iram.dat` was exported from the same binary and compared line-by-line with the passing simulation image. Board use: select this file for IRAM initialization, regenerate only IRAM, rebuild/program FPGA, leave SRAM initialization unchanged, and expect UART `P`. This board result is required before treating nonaligned memory semantics as closed for the CoreMark investigation.
- Board result: the FPGA emitted `P`. The CoreMark investigation can therefore exclude the complete implemented nonaligned `LW/LH/LHU/SW/SH` DTCM path.

## CoreMark state-transition isolation (2026-07-23)

- `app/state_machine` links the unmodified CoreMark `core_state_transition()` from `app/coremark/core_state.c` at `-O3`. It initializes four volatile SRAM tokens at runtime (integer, float, scientific notation, invalid input), calls the original function 16 times for each token, and checks its returned state plus the six relevant `transition_count` entries. The resulting IRAM image is 1,620 bytes / 405 words.
- TDD red: the unregistered application build was rejected by Makefile. After adding only the application registration, the first RTL run emitted failure bit `8`. Source tracing showed the test expectation was wrong: `CORE_START` is incremented even when its first character causes `CORE_INVALID`. Correcting that expected count (`START=1`, `INVALID=1`) made the same all-RTL SoC simulation emit UART `P`.
- Disassembly confirms the exact original transition routine contains the intended `LBU` / compare / conditional-branch / transition-counter `LW`/`SW` chains. It is not a rewritten state machine.
- `FPGA/pango_cpu/source/state_machine_iram.dat` is exported from the passing binary and matches `RTL/sim/programs/state_machine.hex` line-by-line. Board use: select it as the IRAM initialization file, regenerate only IRAM, rebuild/program FPGA, keep SRAM initialization unchanged, and expect UART `P`. A board `P` excludes the standalone CoreMark state-transition routine; the next remaining target is the full benchmark's interleaving/layout rather than basic state parsing.

## CoreMark validated full-RTL run configuration (2026-07-23)

- The full RTL failure is reproducible for the normal non-diagnostic `-O3` CoreMark image: list/state CRCs are `0x175e`/`0xe553` while matrix CRC remains `0x1fd7`. The same algorithm passes when built with the pre-existing state-initialization diagnostic layout. The passing layout reports `crclist=0xe714`, `crcmatrix=0x1fd7`, and `crcstate=0x8e3a`.
- The diagnosis is intentionally recorded as a layout/control-flow interaction, not claimed as an RTL root-cause fix. The state-transition instruction body is byte-identical in compared failing and passing images but moves from `0x000020c0` to `0x00002250`; disabling BTB, moving the heap, changing function alignment, and disabling GCC instruction scheduling did not produce a general non-diagnostic fix. The optional `+CHECK_IFU` whole-SoC assertion verified that every valid instruction delivered to decode matches the loaded IRAM word at its reported PC in both passing and failing runs.
- The generic whole-SoC testbench supports independent `+PROGRAM=<IRAM hex>` and `+SRAM=<SRAM hex>` preloads, optional `+VERIFY_ALL_IMAGES`, `+CHECK_IFU`, `+TRACE_PC`, and a word-aligned `+PATCH_SRAM_ADDR`/`+PATCH_SRAM_VALUE` diagnostic preload patch. All preloaded words were read back successfully before CoreMark execution. The Pango DRM18K behavior model implements the generated IP's row addressing, chip-select masking, and per-byte write enables; this is the model used by the full RTL regression.
- `app/sram_walk` is retained as a compact direct-SRAM regression: it writes and reads a 4 KiB runtime-SRAM region first by byte and then by word, and emits UART `P` on success. The whole-SoC RTL run passed, providing a reusable check over the address range used by CoreMark's runtime heap.
- `cmd.exe /c build_and_convert.bat coremark` now defaults to `COREMARK_STATE_INIT_DIAG=1`, `ITERATIONS=0` (CoreMark calibration), and `-O3`. It generated `FPGA/pango_cpu/source/coremark_iram.dat` (19,860 bytes, 4,965 words) and `coremark_sram.dat` (2,900 bytes, 725 words). Passing `0` as the second batch argument still explicitly builds the known-failing non-diagnostic comparison image.
- Verification: a fixed-one-iteration, quiet full-RTL run of the passing layout completed with `+CHECK_IFU` and emitted the three expected individual CRCs above. Its aggregate final CRC is intentionally not compared because CoreMark's reference final CRC is calibration/iteration dependent. Earlier board execution of this same diagnostic layout completed the calibrated 1,100-iteration run and printed `Correct operation validated.`
- Board action: select the regenerated `coremark_iram.dat` and `coremark_sram.dat` in the Pango IRAM/SRAM initialization configuration, regenerate the two IPs, rebuild/program the FPGA, then run CoreMark. The expected result is `Correct operation validated.`; the preceding `[STATE_DIAG]` lines are part of the validated layout and occur before `start_time()`, so they are excluded from the reported benchmark interval. Pango initialization configuration itself is intentionally left for the user to edit. `RTL/peripheral/soc_top.v` and `FPGA/pango_cpu/source/peripheral/soc_top.v` were SHA-256 checked identical before handoff.

## CoreMark 跑通工作流与关键节点总结（2026-07-23）

### 1. 先固定 SoC 的真实存储器架构

- 本工程是 Harvard 架构：CPU 的取指端通过 IRAM 直连端口读取程序，运行时读写数据通过独立 SRAM 直连端口完成。SoC 保留的 AXI 存储器端口当前不参与 CoreMark 执行，后续才用于程序下载。因此，CoreMark 不能只生成单一的平坦 bin 文件，而必须把 ELF 的程序段和初始化数据段分别装入 IRAM 与 SRAM。
- 由此确定了映像职责：`.text`（以及相关只读/启动内容）转换为 `coremark_iram.dat`，`.data` 转换为 `coremark_sram.dat`；`.bss` 和 CoreMark 的工作堆不写入初始化文件，由启动代码在运行时于 `0x2000_0000` SRAM 空间建立。

### 2. 建立可重复的编译和映像转换链路

- 扩展 `template/TSP_RISCV_template/Makefile` 和 `template/tools/build_and_convert.bat`，使应用、优化等级、CoreMark 状态诊断布局和迭代模式均可显式控制。CoreMark 使用 `-O3`，并以 `ITERATIONS=0` 让标准 CoreMark 流程自行校准迭代次数；这与通常 CPU 跑分方式一致。
- 扩展 `template/tools/bin2txt.py`：读取 ELF section 地址和内容，分别导出 IRAM/SRAM 的 32 位小端字初始化文件，而不是把整个 ELF 误放到单一 RAM。最终通过 `cmd.exe /c build_and_convert.bat coremark` 生成当前上板文件：IRAM 有 19,860 字节（4,965 words），SRAM 有 2,900 字节（725 words）。
- Pango 的 IP 参数、初始化文件引用和再生操作属于板级工程配置，刻意由用户完成；源码仓库只提供已经生成并核对过的两个 `.dat` 输入文件，避免工具自动生成文件和 RTL 源码出现不受控偏差。

### 3. 让仿真与 Pango SRAM IP 行为一致

- 所有 RTL 文件都加入通用 whole-SoC testbench。testbench 可用 `+PROGRAM=<IRAM hex>`、`+SRAM=<SRAM hex>` 独立预加载两块存储器，并在执行前读回核对；这直接验证了 Harvard 双映像是否真正进入对应存储器。
- 初始的 `GTP_DRM18K_model.v` 错误地把 Pango DRM 的写使能视作整个 18 位字写使能。实际 Pango 32-bit SRAM 由两个 16-bit DRM 组合，字节使能编码在地址低位；原模型在 `SB`/`SH` 时会覆盖相邻字节，导致仿真不能代表 FPGA。
- 按 Pango 生成 wrapper 的数据位、奇偶位、chip-select、地址与字节使能编码重写行为模型后，未使能的字节保持原值。`ls_dependency` 程序从仿真 `F` 变为 UART `P`，说明仿真模型已经能正确覆盖 CoreMark 必需的动态字节读写。

### 4. 先用小程序逐项排除 SRAM/LSU 基础故障

- `ls_dependency` 用运行时 SRAM 数据执行重复 `LBU`→`SB` 依赖链，验证字节加载、字节存储、写回和基本相邻 load/store 相关性；RTL 与 FPGA 均输出 `P`。
- `unaligned_access` 用内联 RV32 指令覆盖跨字 `SW/LW` 与跨字 `SH/LHU/LH`，同时逐字节检查副作用；RTL 与 FPGA 均输出 `P`，排除当前实现的非对齐 DTCM 路径。
- `state_machine` 链接未改写的 `core_state_transition()`，覆盖整数、浮点、科学计数法与非法字符串的状态转换、分支和计数器读改写；RTL 通过，且对应 FPGA 探针映像用于确认基础状态解析路径。
- `sram_walk` 覆盖 4 KiB 运行时 SRAM，先按字节再按字读写，作为后续不依赖 CoreMark 的 SRAM 回归。该测试已在全 RTL SoC 中通过。

### 5. 用 CoreMark CRC 将故障范围收敛

- 普通非诊断 `-O3` CoreMark 的现象稳定可复现：matrix CRC `0x1fd7` 正确，但 list/state CRC 为 `0x175e`/`0xe553`，而标准参考值是 `0xe714`/`0x8e3a`。因此问题不是启动、UART、计时器、整块 SRAM 初始化或矩阵运算的普遍性失败。
- 增加状态初始化指针、内容与 `init_crc` 输出后，FPGA 得到 `init_crc=ef98`、首字 `32313035`，与主机参考完全一致。这证明 CoreMark 的 666-byte 动态状态缓冲区在运行前已经被正确写入 SRAM；诊断打印发生在 `start_time()` 前，不计入跑分时间。
- 同时为全 RTL 仿真加入 `+CHECK_IFU`。该断言将送往 decode 的有效指令与预加载 IRAM 中该 PC 的字逐条比较；失败和通过布局均没有发现取指字/PC 不一致，排除了可观察到的 IRAM 装载或 IFU 取指错位。

### 6. 隔离过、但未作为根因确认的假设

- 比较链接布局发现诊断布局会移动 `core_state_transition` 的代码位置，且改变之前的动态执行历史。尝试关闭 BTB、改变 heap 位置或 4 KiB 对齐、改变函数对齐、关闭 GCC 指令调度，都没有形成可泛化的普通非诊断修复；BTB-off 板级结果也没有改变 CRC。
- SRAM 4 KiB bank 边界曾是合理假设：失败布局的状态输入跨越 `0x2000_1000`，诊断布局没有跨越。但将 heap 4 KiB 对齐后 FPGA 仍然失败，因此该假设已经排除，不能作为最终修复依据。
- 所以工程结论必须严格表述为：已验证的可运行配置依赖状态初始化诊断带来的代码/执行布局差异；它不是已经定位并修正某一条 CPU RTL 的根因。保留上述探针和断言，供未来针对 CoreMark 特定控制流/布局交互继续收敛。

### 7. 最终通过配置与板级结果

- 当前默认构建启用 `COREMARK_STATE_INIT_DIAG=1`。它保留可重复的初始化校验和布局，并且不改动 CoreMark 的计算算法与数据集；若传入第二参数 `0`，仍可构建历史失败的无诊断对比映像。
- FPGA 最终输出：`crclist=0xe714`、`crcmatrix=0x1fd7`、`crcstate=0x8e3a`、`crcfinal=0x33ff`，并打印 `Correct operation validated.`。这表示 CoreMark 的官方功能校验已经完成。
- 校准得到 1,100 次迭代、`939,394,914` 个 50 MHz ticks。程序按其整数秒计时输出 61 iterations/s（约 1.22 CoreMark/MHz）；按原始 tick 精确换算为约 58.55 iterations/s（约 1.17 CoreMark/MHz）。前者是串口中的 CoreMark 报告值，后者用于需要精确时基比较的场合。
- 上板复现步骤：用当前 `coremark_iram.dat` 和 `coremark_sram.dat` 重新生成 Pango 的 IRAM/SRAM IP，确认综合输入 `FPGA/pango_cpu/source/peripheral/soc_top.v` 与 `RTL/peripheral/soc_top.v` 一致，重新实现并下载 FPGA。观察到上述三项 CRC 和 `Correct operation validated.` 即表示配置一致、跑分成功。

## 无诊断 CoreMark 的重定向反压修复（2026-07-23）

- 进一步以完整 RTL SoC 仿真复现并定位了无诊断 `-O3` 映像的根因；这不是 BTB tag 混淆。`defines.v`/`PC_control.v` 的 BTB tag 使用完整的 `PC[31:2]`，没有因 tag 截断造成的假命中。
- **触发条件是 `core_init_state()` 内的跳转重定向与前一条 DTCM load 尚未完成重叠。冲刷周期中 `idec_valid_i=0`，但 `TSP_Disp_Exu` 原先仍按残留的无效译码位选择执行单元；当残留位看起来是 LSU 请求时，未完成的 LSU 会把 `disp_exu_ready_o` 拉低，进而使 IFU/PC 多停留一个周期。
- 这个额外停顿使跳转目标 `addi a5` 在一次重定向中发射两次，状态模式选择的 seed 被跳过。动态状态缓冲区的初始化因而错误，随后表现为 `crclist=0x175e`、`crcstate=0xe553`，而相对独立的 matrix CRC 仍为正确的 `0x1fd7`。这也解释了为何加入诊断打印、改变代码布局或时序会偶然避开问题。
- 修复位于 `RTL/core/disp_exu.v`：无效译码字被定义为 ready 的 bubble，`disp_exu_ready_o = ~idec_valid_i | (正常依赖/单元 ready 条件)`。因此冲刷中的残留 opcode 不再能对 PC 重定向响应施加 LSU 反压；真正有效的指令仍保留原有依赖、OITF 与分支在飞行检查。**
- 同一修改已同步至 `FPGA/pango_cpu/source/core/disp_exu.v`；两个文件的 SHA-256 已逐字节一致。Pango 的 IP 初始化配置、生成日志和工程数据库均未改动。
- 验证：使用默认无诊断、`-O3` CoreMark 的 IRAM/SRAM 映像，运行全 RTL 文件列表的 SoC 仿真并启用 `+CHECK_IFU`；在 `core_init_state()` 返回后得到动态 666-byte 状态缓冲区 CRC `0xef98`，与主机参考和此前通过的诊断板级结果完全一致。完整 10 秒校准跑分不在 RTL 仿真中执行；应以该修复重建 FPGA 后运行无诊断映像，预期得到 `crclist=e714`、`crcmatrix=1fd7`、`crcstate=8e3a` 与 `Correct operation validated.`。

## 无诊断 CoreMark Pango 初始化映像（2026-07-23）

- 已执行 `build_and_convert.bat coremark 0`，使用 GCC 15.2.0、RV32IM、`-O3`、`ITERATIONS=0` 和 `COREMARK_STATE_INIT_DIAG=0` 重新生成 Pango 初始化文件。
- 输出为 `FPGA/pango_cpu/source/coremark_iram.dat`（4,789 个 32-bit words，`.text` 19,156 bytes）与 `FPGA/pango_cpu/source/coremark_sram.dat`（627 个 32-bit words，`.data` 2,508 bytes）。`coremark.elf` 不包含 `[STATE_DIAG]` 字符串，确认其为无诊断映像。
- Pango 的 IRAM/SRAM IP 初始化文件选择与 IP 再生仍由用户完成；本次只更新输入 `.dat`，未修改 IP 配置或生成工程数据库。

## 第一阶段低功耗性能优化设计（2026-07-24，已确认）

### 目标与边界

- 首要目标是在保持 50 MHz、RV32IM 指令集、软件 ABI、Harvard IRAM/SRAM 地址映射、外设寄存器接口和单发射顺序执行模型不变的前提下，提高有效 IPC；减少无效等待周期也同时降低单位工作量的动态翻转。
- 不引入 cache、乱序执行、多发射、额外时钟域或 Pango IP 配置修改。不以增加频率、降频或软件可见的低功耗模式作为本阶段内容。
- `RTL` 与 `FPGA/pango_cpu/source` 的对应核心 RTL 必须逐字节同步；临时仿真观测逻辑不得保留在通用 testbench。

### 选定方案：DTCM LSU 控制路径缩短

- 优化范围限定在 `TSP_Exu_ls` 与 `ls_ctrl` 间的请求发射、对齐 DTCM 读写的状态推进和写回交接。目标是删除控制层面的冗余空拍，而非改变 SRAM IP 的一拍读延迟。
- 保持同一时刻至多一条未完成的 LSU 事务；所有 load 继续占用 OITF，RAW/WAW 检测、load-use 停顿、写回仲裁以及非对齐跨字两拍事务均保留原语义。
- 仅在请求真正被当前 LSU 状态接受时更新地址、写数据、字节掩码、目标寄存器和 load 类型；对齐事务与跨字事务共用同一顺序模型，避免因快路径绕过造成写后读或旁路错误。
- 同时增加仅供仿真的架构统计：执行周期、退休指令、DTCM 对齐/跨字 load/store 次数和 LSU 忙周期。统计不得进入 FPGA 综合 RTL，也不得影响时序或软件接口。

### 验证与验收

- 先为现有对齐 DTCM `LW/SW`、load-use 依赖、连续 store、非对齐及跨字访问建立/补全自检回归；优化前记录周期与统计，优化后必须保持数据和 UART 结果一致，并证明对齐 DTCM 路径的周期数减少。
- 回归范围包含 `tb_ls_ctrl_unaligned`、`unaligned_access`、`ls_dependency`、`state_machine`、`sram_walk`、全 SoC `sim_smoke` 和无诊断 CoreMark 初始化状态 CRC `0xef98`。完整校准 CoreMark 仍由 FPGA 板级运行确认，预期功能签名保持 `e714/1fd7/8e3a`。
- 性能报告以同一频率、相同软件映像的周期数、CPI 与 CoreMark iterations/s 比较；若任意功能回归失败、关键路径无法满足原 50 MHz，或性能没有可测改善，则不保留该实现。

### 后续候选（不属于第一阶段）

- 若 LSU 优化完成后分支冲刷仍是主要来源，可评估保持两项规模的 2-bit 分支方向状态；若应用确认乘法密集，再单独评估 FPGA DSP 乘法。两者都必须先经过独立设计与功耗/性能权衡，不与本阶段混合。

### 第一阶段实施计划（内联执行，2026-07-24）

#### Task 1：建立 DTCM 延迟红灯与仿真统计

**文件：**创建 `RTL/sim/tb_script/tb_exu_ls_issue.sv` 和 `RTL/sim/tb_script/modelsim_exu_ls.do`；修改 `RTL/sim/tb_script/tb_ls_ctrl_unaligned.sv`、`RTL/sim/tb_script/tb_soc_program.sv`、`RTL/sim/tb_script/modelsim_filelist.f`。

- [ ] 在 `tb_ls_ctrl_unaligned.sv` 增加单调递增的 `cycle_count`，并让 `do_load()`/`do_store()`记录请求在第一个采样上升沿被 `ls_ctrl` 接受的周期与完成周期。
- [ ] 新增对齐 DTCM `LW` 与 `SW` 的延迟断言：在请求已于 IDLE 接受、写回无仲裁阻塞时，load 写回应在接受后的一个周期可见，store 控制器在接受后的一个周期重新 ready。当前 `ls_ctrl` 的 `WAIT_WB` 空拍应使该断言失败；非对齐跨字测试不使用这个延迟上限。

```verilog
// 每个上升沿更新；任务在驱动请求前保存 accepted_cycle。
always @(posedge clk) cycle_count <= cycle_count + 1;

// 对齐 LW：等待写回后必须只经历一个 SRAM 读延迟。
if ((cycle_count - accepted_cycle) > 1)
    $fatal(1, "[TB_ERROR] aligned DTCM load latency=%0d cycles", cycle_count - accepted_cycle);
```

- [ ] 在通用 SoC testbench 增加可选 `+LSU_STATS`，仅统计并打印执行周期、`ls_req` 总数、DTCM 写拍数和 LSU 忙周期；没有该 plusarg 时不得新增运行时打印或改变行为。
- [ ] 在新建的 `tb_exu_ls_issue.sv` 中实例化 `TSP_Exu_ls`，使 `idec_valid_i=1`、`INST_LW=1`、`ls_ctrl_ready_i=1`，并立即断言 `ls_req_o=1`、`ls_addr_o=ls_addr_i`、`ls_rd_o=rd_i`。旧 RTL 的 `ls_busy_r` 会使 `ls_req_o=0`，该测试先失败；`modelsim_exu_ls.do` 以 `tb_exu_ls_issue` 为顶层并沿用完整 filelist 编译。
- [ ] 运行 `cmd.exe /c sim.bat` 和 `vsim -c -do modelsim_exu_ls.do`；预期前者因新的对齐 DTCM 延迟断言失败、后者因 LSU 发射断言失败，而现有功能数据检查仍不产生额外错误。

#### Task 2：去除 LSU 前端冗余请求寄存器

**文件：**修改 `RTL/core/exu_ls.v`。

**接口：**保留现有模块端口。`exu_ls_ready_o` 由 `ls_ctrl_ready_i` 驱动；`ls_req_o` 只在当前已发射的有效 load/store 且控制器 ready 时为 1。地址、字节掩码、写数据、目标寄存器和 load 类型均直接由当前译码与已经存在的寄存器旁路结果产生。

- [ ] 以 Task 1 的失败断言为红灯基线。
- [ ] 删除 `ls_busy_r`、`store_type_r`、`load_type_r`、`rs2_data_r`、`rd_r` 和 `ls_addr_r` 的排队功能；用以下组合定义替代，使 `ls_ctrl` 在与发射同一上升沿锁存请求：

```verilog
assign exu_ls_ready_o = ls_ctrl_ready_i;
assign ls_req_o       = idec_valid_i & is_ls & ls_ctrl_ready_i;
assign ls_we_o        = is_store;
assign ls_addr_o      = ls_addr_i;
assign ls_rd_o        = is_store ? 5'd0 : rd_i;
assign ls_load_type_o = INST_LW  ? 3'd0 :
                        INST_LH  ? 3'd1 :
                        INST_LHU ? 3'd2 :
                        INST_LB  ? 3'd3 : 3'd4;
```

- [ ] 保留现有 `SB/SH/SW` 的 `byte_en` 与 `wdata` 计算，但其输入改为 `ls_addr_i` 与 `rs2_op`；不得改变跨字拆分所依赖的原始掩码语义。
- [ ] 运行 `cmd.exe /c sim.bat`；预期对齐 load 红灯仍可能存在（由 `ls_ctrl` 的完成状态造成），但所有已有非对齐数据检查通过。

#### Task 3：缩短 `ls_ctrl` 的对齐 DTCM 完成路径

**文件：**修改 `RTL/core/ls_ctrl.v`；测试继续使用 `RTL/sim/tb_script/tb_ls_ctrl_unaligned.sv`。

**接口：**不改变 `ls_ctrl` 端口和 DTCM SRAM 时序。新增内部 `is_load_r`；仅在最终 DTCM 读捕获拍为 load 产生写回。跨字读第一拍仍保存 `rdata1_r`，第二拍才完成。

- [ ] 在 IDLE 接受请求时锁存 `is_load_r <= ~ls_we_i`。AXI/DTCM store 在最后一个写响应/写拍后直接回到 IDLE，不再经过无用途的 load 写回状态。
- [ ] 定义最终 DTCM 读完成条件，并将其作为即时写回源；对 SRAM 一拍同步读，`dtcm_rdata_i` 已在 `DTCM_READ_CAPTURE` 周期有效：

```verilog
wire dtcm_read_done = (state == DTCM_READ_CAPTURE) &&
                      (!cross_bound_r || second_beat_r);
wire ls_wb_now = dtcm_read_done && is_load_r;
assign ls_ctrl_wb_en_o = ls_wb_now || ((state == WAIT_WB) && is_load_r);
wire [31:0] read_data_now = dtcm_read_done ?
    (second_beat_r ? ({dtcm_rdata_i, rdata1_r} >> {addr_align_r,3'b000}) :
                     (dtcm_rdata_i >> {addr_align_r,3'b000})) : axi_read_data_r;
```

### First-phase implementation result (2026-07-24)

- Completed the DTCM LSU control-path optimization in `TSP_Exu_ls` and `ls_ctrl` without changing module ports, RV32IM ABI, Harvard mapping, peripherals, clock/power domains, or Pango IP configuration. A valid load/store now enters `ls_ctrl` in the dispatch edge; the former one-cycle `TSP_Exu_ls` request queue is removed.
- The final aligned DTCM store returns directly to `IDLE`; the final DTCM read-capture cycle directly drives load writeback. If writeback arbitration is unavailable, the controller retains the read data and uses the existing `WAIT_WB` fallback. Cross-word load/store semantics and AXI response ordering remain unchanged.
- TDD passed: the new direct-issue test was red on the old RTL (`ls_req_o=0`) and now passes. The aligned DTCM load/store latency checks were red on the old controller and now pass with completion one cycle after controller acceptance. Existing unaligned, byte-enable, sign-extension, and IRAM-data-isolation checks also pass.
- Full-filelist ModelSim regressions with `+CHECK_IFU` passed: `sim_smoke`, `ls_dependency`, `unaligned_access`, `state_machine`, and `sram_walk` each produced UART `0x50` (`P`). `ls_dependency` needs a 20,000-cycle budget; the 4 KiB `sram_walk` needs a 500,000-cycle budget.
- `RTL/core/exu_ls.v` equals `FPGA/pango_cpu/source/core/exu_ls.v`, and `RTL/core/ls_ctrl.v` equals `FPGA/pango_cpu/source/core/ls_ctrl.v` after the update. No Pango IP/generated configuration file was changed.
- Scope-limited performance claim: the implementation removes one front-end issue bubble per immediately accepted LSU transaction and one controller-release state after aligned DTCM completion. FPGA timing closure and a new CoreMark score have not been measured; rebuild with the synchronized Pango RTL and rerun the existing non-diagnostic `-O3` CoreMark. Expected functional signature remains `e714/1fd7/8e3a/33ff` and `Correct operation validated.`

- [ ] 当 `dtcm_read_done && wb_ls_ready_i` 时转回 IDLE；若仲裁器正被 MulDiv 占用，则先锁存 `read_data_now` 并转入 `WAIT_WB`，直至 `wb_ls_ready_i` 为 1。这样不丢失 load 结果，也不引入组合式 SRAM 读。
- [ ] 在 `DTCM_WRITE` 的最终写拍后直接转 IDLE；在 `AXI_B` 最终响应后，store 直接转 IDLE。非对齐第二写拍和 AXI 两拍传输必须仍在最后一拍后才释放。
- [ ] 运行 `cmd.exe /c sim.bat`；预期 Task 1 的对齐 load/store 延迟断言和所有原有跨字、符号扩展、IRAM 数据隔离检查全部通过。

#### Task 4：全 SoC 回归、同步与验收

**文件：**修改 `FPGA/pango_cpu/source/core/exu_ls.v`、`FPGA/pango_cpu/source/core/ls_ctrl.v`、`spec.md`；测试使用既有映像。

- [ ] 将 Task 2/3 的已验证 RTL 逐字节复制到对应 Pango 综合源码，并用 SHA-256 比较两对文件；不修改 `FPGA/pango_cpu/ipcore` 的生成文件或 Pango IP 配置。
- [ ] 使用 `+LSU_STATS` 跑优化后全 SoC 映像：`sim_smoke`、`ls_dependency`、`unaligned_access`、`state_machine`、`sram_walk`；每项都必须观察到 UART `0x50`，并记录周期/LSU 统计。
- [ ] 用无诊断 CoreMark IRAM/SRAM 映像运行至 `core_init_state()` 返回，启用 `+CHECK_IFU`；动态状态 CRC 必须为 `0xef98`。不在 RTL 中运行完整十秒校准。
- [ ] 将实际命令、延迟前后数据、回归结果和板级重测要求追加至 `spec.md`。仅在全部仿真通过后创建下一版本分支、提交并推送；Git 写入若仍被环境限制拒绝，则保留工作区并明确报告。
