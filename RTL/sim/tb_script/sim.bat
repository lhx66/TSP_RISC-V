@echo off
echo [AI Copilot] Starting background simulation inside tb_script...
vsim -c -do modelsim_sim.do
exit /b %ERRORLEVEL%
