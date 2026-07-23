@echo off
setlocal

set "APP=%~1"
if "%APP%"=="" set "APP=coremark"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "PROJECT_DIR=%SCRIPT_DIR%\..\TSP_RISCV_template"
set "HEX_FILE=%SCRIPT_DIR%\..\..\RTL\sim\programs\%APP%.hex"
set "FPGA_SOURCE_DIR=%SCRIPT_DIR%\..\..\FPGA\pango_cpu\source"

where make >nul 2>&1 || (
    echo [ERROR] make was not found on PATH.
    exit /b 1
)
where riscv-none-elf-gcc >nul 2>&1 || (
    echo [ERROR] riscv-none-elf-gcc was not found on PATH.
    exit /b 1
)
where riscv-none-elf-objcopy >nul 2>&1 || (
    echo [ERROR] riscv-none-elf-objcopy was not found on PATH.
    exit /b 1
)
if not defined PYTHON (
    where python >nul 2>&1 || (
        echo [ERROR] python was not found on PATH. Set PYTHON to a Python executable.
        exit /b 1
    )
    set "PYTHON=python"
)

echo [BUILD] application: %APP%
cd /d "%PROJECT_DIR%" || exit /b 1
make clean APP=%APP%
make APP=%APP% || exit /b 1

if /I "%APP%"=="coremark" (
    if not exist "%PROJECT_DIR%\coremark.elf" (
        echo [ERROR] missing output: %PROJECT_DIR%\coremark.elf
        exit /b 1
    )
    "%PYTHON%" "%SCRIPT_DIR%\bin2txt.py" --elf "%PROJECT_DIR%\coremark.elf" --iram-out "%FPGA_SOURCE_DIR%\coremark_iram.dat" --sram-out "%FPGA_SOURCE_DIR%\coremark_sram.dat" || exit /b 1
    echo [DONE] Pango initialization images: %FPGA_SOURCE_DIR%\coremark_iram.dat and coremark_sram.dat
) else (
    if not exist "%PROJECT_DIR%\%APP%.bin" (
        echo [ERROR] missing output: %PROJECT_DIR%\%APP%.bin
        exit /b 1
    )
    "%PYTHON%" "%SCRIPT_DIR%\bin2txt.py" --bin "%PROJECT_DIR%\%APP%.bin" --iram-out "%HEX_FILE%" || exit /b 1
    echo [DONE] simulation image: %HEX_FILE%
)
