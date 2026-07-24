@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for perf_all.bat
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

set "cmd=%1"
set "param1=%2"
set "param2=%3"

if /i "%cmd%"=="" goto show_help
if /i "%cmd%"=="-h" goto show_help
if /i "%cmd%"=="help" goto show_help
if /i "%cmd%"=="sf" goto surface_flinger
if /i "%cmd%"=="cmd" goto command
if /i "%cmd%"=="cfg" goto config
if /i "%cmd%"=="online" goto online
if /i "%cmd%"=="origin" goto origin
if /i "%cmd%"=="fire" goto fire
if /i "%cmd%"=="reset" goto reset
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

:command
call %SCRIPT_DIR%perf_cmd.bat %2
exit /b

:config
call %SCRIPT_DIR%perf_config.bat %2
exit /b

:online
call %SCRIPT_DIR%perf_online.bat %2
exit /b


:origin
rem "" 是窗口标题
start "" %USERPROFILE%\"batScript\performance\perfettoCaptureTools_original"
exit /b

:fire
call %SCRIPT_DIR%perf_simpleperf.bat %2
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

:install_apk
call %SCRIPT_DIR%perf_installs.bat %2
exit /b

:cpu_info
adb shell ls /sys/devices/system/cpu/cpufreq/
for /f "delims=" %%a in ('adb shell ls /sys/devices/system/cpu/cpufreq/') do (
	echo %%a频率:
	adb shell cat /sys/devices/system/cpu/cpufreq/%%a/scaling_available_frequencies
)
for /f "delims=" %%a in ('adb shell ls /sys/devices/system/cpu/') do (
	echo %%a | findstr /r "cpu[0-9]" > nul
	if not errorlevel == 1 (
		for /f "delims=" %%b in ('adb shell cat /sys/devices/system/cpu/%%a/online') do (
			if "%%b"=="0" echo "cpu%%a offline"
		)
	)
)
exit /b

:dhrystone
call %SCRIPT_DIR%perf_dhrystone.bat %*
exit /b

endlocal
