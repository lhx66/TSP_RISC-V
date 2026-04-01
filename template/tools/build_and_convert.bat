@echo off
REM ==========================================
REM   RISC-V CoreMark 一键编译和转换脚本 (Windows)
REM ==========================================

setlocal enabledelayedexpansion

echo ========================================
echo    RISC-V CoreMark 自动构建工具 v1.1
echo ========================================
echo.

REM 获取脚本所在目录
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "PROJECT_DIR=%SCRIPT_DIR%\..\TSP_RISCV_template"

echo [INFO] 脚本目录: %SCRIPT_DIR%
echo [INFO] 项目目录: %PROJECT_DIR%
echo.

REM 检查make命令
where make >nul 2>&1
if errorlevel 1 (
    echo [错误] 找不到 make 命令！
    echo 请确保已安装 RISC-V 交叉编译工具链并添加到 PATH 环境变量
    echo.
    echo 通常的路径类似: C:\RISC-V工具链\bin
    pause
    exit /b 1
)

REM 检查python命令
where python >nul 2>&1
if errorlevel 1 (
    where py >nul 2>&1
    if errorlevel 1 (
        echo [错误] 找不到 Python！
        echo 请安装 Python 或将 Python 添加到 PATH
        pause
        exit /b 1
    ) else (
        set "PYTHON_CMD=py"
    )
) else (
    set "PYTHON_CMD=python"
)

echo [OK] 找到构建工具
echo.

REM 步骤1: 清理旧的编译结果
echo [1/4] 清理旧的编译文件...
cd /d "%PROJECT_DIR%"
if exist Makefile (
    make clean
    echo     ✓ 清理完成
) else if exist makefile (
    make clean
    echo     ✓ 清理完成
) else (
    echo     ✗ 错误: 找不到 Makefile
    echo     请确认项目结构是否完整
    pause
    exit /b 1
)
echo.

REM 步骤2: 编译项目
echo [2/4] 开始编译 CoreMark...
echo     (这可能需要几十秒...)
make
if errorlevel 1 (
    echo     ✗ 编译失败
    echo     请检查编译器配置和源代码
    pause
    exit /b 1
) else (
    echo     ✓ 编译成功
)
echo.

REM 步骤3: 检查编译产物
echo [3/4] 检查编译产物...
set "BIN_FILE=%PROJECT_DIR%\coremark.bin"
if exist "%BIN_FILE%" (
    for %%A in ("%BIN_FILE%") do set SIZE=%%~zA
    echo     ✓ 找到 coremark.bin (大小: !SIZE! bytes)
) else (
    echo     ✗ 错误: 找不到 coremark.bin
    echo     编译可能未成功完成
    pause
    exit /b 1
)
echo.

REM 步骤4: 转换为FPGA格式
echo [4/4] 转换为 FPGA TXT 格式...
cd /d "%SCRIPT_DIR%"
if exist bin2txt.py (
    %PYTHON_CMD% bin2txt.py
    if errorlevel 1 (
        echo     ⚠ 转换脚本执行有问题，请检查
        pause
    ) else (
        echo     ✓ 转换成功
    )
) else (
    echo     ✗ 错误: 找不到 bin2txt.py
    pause
    exit /b 1
)
echo.

echo ========================================
echo  🎉 构建完成！
echo ========================================
echo.
echo 📂 生成的文件:
echo    - %PROJECT_DIR%\coremark.bin
echo    - 将在FPGA目录生成 boot.dat
echo.
echo 🔄 下一步操作:
echo    1. 在Pango FPGA项目中综合比特流
echo    2. 下载到FPGA开发板
echo    3. 打开串口调试工具观察输出
echo.
echo 💡 提示: 修改代码后重新运行此脚本即可
echo.
pause
