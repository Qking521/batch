@echo off
:: =========================README===================================
:: perfetto离线工具下载地址：https://github.com/google/perfetto/releases
:: google_perfetto_tools当前版本：v52
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

call %INIT_BAT% %~dp0
:: 调用基础脚本检查ADB和设备（使用完整路径）
call "%ABD_CHECK_BAT%"
if %ERRORLEVEL% neq 0 (
    echo [错误]: 基础检测失败，退出操作。
    exit /b %ERRORLEVEL%
)
:: 创建performance的OUT目录
if not exist %OUT_DIR% (
	mkdir %OUT_DIR%
)

set "cmd=%1"
set "param1=%2"
set "param2=%3"

if /i "%cmd%"=="" goto show_help
if /i "%cmd%"=="-h" goto show_help
if /i "%cmd%"=="help" goto show_help
if /i "%cmd%"=="sf" goto surface_flinger
if /i "%cmd%"=="trace" goto trace
if /i "%cmd%"=="cpu" goto cpu
if /i "%cmd%"=="gpu" goto trace
if /i "%cmd%"=="fire" goto fire
if /i "%cmd%"=="ds" goto dhrystone
if /i "%cmd%"=="install" goto install_apk

echo Unknown command: %cmd%
goto show_help
exit /b

:show_help
echo
echo Usage: Performance [command]
echo
echo Available commands:
echo   cpu    		- 显示CPU相关信息
echo   base    		- 研发性能分析, default 5s.
echo   more			- 更多性能信息
echo   full			- 全量性能抓取
echo   io			- 文件系统性能
echo   log			- 带日志性能抓取
echo   screen		- 带录屏性能抓取
echo   fire         - 火焰图抓取
echo   install      - 安装性能类apk工具
echo   -h      		- Show help (alias: help^)
echo.
echo Examples:
echo   perf base 5
echo  =======================
exit /b

:surface_flinger
call %SCRIPT_DIR%surface_flinger.bat %2
exit /b

:trace
call %SCRIPT_DIR%perf_traces.bat %*
exit /b

:cpu
call %SCRIPT_DIR%perf_cpu.bat %*
exit /b


:origin
rem "" 是窗口标题
start "" %USERPROFILE%\"batScript\performance\perfettoCaptureTools_original"
exit /b

:fire
call %SCRIPT_DIR%perf_simpleperf.bat %2
exit /b

:install_apk
call %SCRIPT_DIR%perf_installs.bat %2
exit /b

:dhrystone
call %SCRIPT_DIR%perf_dhrystone.bat %*
exit /b
