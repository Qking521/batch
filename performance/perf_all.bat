@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
:: 获取当前脚本所在目录--结尾有反斜杠
set "SCRIPT_DIR=%~dp0"
cd %SCRIPT_DIR%
:: 调用基础脚本检查ADB和设备（使用完整路径）
call "..\adb_check.bat"
if %ERRORLEVEL% neq 0 (
    echo [错误]: 基础检测失败，退出操作。
    exit /b %ERRORLEVEL%
)

if "%1"=="" goto show_help
if /i "%1"=="-h" goto show_help
if /i "%1"=="help" goto show_help
if /i "%1"=="sf" goto surface_flinger
if /i "%1"=="cmd" goto command
if /i "%1"=="cfg" goto config
if /i "%1"=="online" goto online
if /i "%1"=="origin" goto origin
if /i "%1"=="reset" goto reset


echo Unknown command: %1
goto show_help
exit /b

:show_help
echo =======================
echo Android Performance Commands
echo 根据具体分析需求选择合适的脚本类型：
echo 研发性能分析： perf_base.bat
echo 更多性能信息： perf_more.bat
echo 全量性能抓取： perf_full.bat
echo 文件系统性能： perf_ioblock.bat
echo 带日志性能抓取： perf_log.bat
echo 带录屏性能抓取： perf_screen.bat

echo
echo Usage: Performance [command]
echo
echo Available commands:
echo   base    		- default trace capture, time for 5s, 10s, 30s, default 5s.
echo   more			- more info on base
echo   full			- full info
echo   io			- focus on IOBlock info
echo   screen		- focus on screen info
echo   -h      		- Show help (alias: help^)
echo.
echo Examples:
echo   perf base 5
echo  =======================
exit /b

:surface_flinger
call surface_flinger.bat %2
exit /b

:command
call perf_cmd.bat %2
exit /b

:config
call perf_config.bat %2
exit /b

:online
call perf_online.bat %2
exit /b


:origin
rem "" 是窗口标题
start "" %USERPROFILE%\"batScript\performance\perfettoCaptureTools_original"
exit /b

:reset
REM 自动查找并终止 trace_processor_shell.exe 进程

REM 1. 使用 tasklist 查找进程ID (PID)
REM /nh (无列头) /fi "imagename eq..." (按名称过滤)
REM tokens=2 提取 PID (第二列)
for /f "tokens=2" %%i in ('tasklist /nh /fi "imagename eq trace_processor_shell.exe"') do (
    taskkill /F /PID %%i
)
exit /b

endlocal
