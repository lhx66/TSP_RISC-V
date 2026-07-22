@echo off
set "PROGRAM_ARGS=%*"
vsim -c -do modelsim_soc.do
exit /b %ERRORLEVEL%
