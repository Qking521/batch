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

if /i "%cmd%"=="" goto :usage
if /i "%cmd%"=="-h" goto :usage
if /i "%cmd%"=="help" goto :usage
if /i "%cmd%"=="sf" goto surface_flinger
if /i "%cmd%"=="trace" goto trace
if /i "%cmd%"=="cpu" goto cpu
if /i "%cmd%"=="gpu" goto trace
if /i "%cmd%"=="flame" goto flame
if /i "%cmd%"=="ds" goto dhrystone
if /i "%cmd%"=="install" goto install_apk

echo [ERROR] 未知命令: %cmd%
goto :usage
exit /b

:usage
echo.
echo 用法: perf ^<命令^> [参数]
echo.
echo 命令:
echo   sf                    - SurfaceFlinger 性能信息
echo   trace [cmd/online/cfg] [时长(s)] - Perfetto 性能抓取
echo   cpu [info/freq/online/fix-freq/boost/affinity/...] - CPU 调控
echo   gpu                   - GPU 性能抓取 (等同 trace)
echo   ds                    - Dhrystone 跑分测试
echo   flame                  - 火焰图抓取 (simpleperf)
echo   install               - 安装性能类 apk 工具
echo   help / -h             - 显示此帮助信息
echo.
echo 示例:
echo   perf trace cmd 5
echo   perf cpu info
echo   perf cpu fix-freq policy0 1800000
echo.
exit /b 0

:surface_flinger
call %SCRIPT_DIR%surface_flinger.bat %2
exit /b

:trace
call %SCRIPT_DIR%perf_traces.bat %*
exit /b

:cpu
set "SH_SCRIPT=%SCRIPT_DIR%perf_cpu.sh"
if not exist "%SH_SCRIPT%" (
    echo [ERROR] 找不到 shell 脚本: %SH_SCRIPT%
    exit /b 1
)
adb shell "sh -s %param1% %param2% %3" < "%SH_SCRIPT%"
exit /b


:origin
rem "" 是窗口标题
start "" %USERPROFILE%\"batScript\performance\perfettoCaptureTools_original"
exit /b

:flame
call %SCRIPT_DIR%perf_simpleperf.bat %2
exit /b

:install_apk
call %SCRIPT_DIR%perf_installs.bat %2
exit /b

:dhrystone
call %SCRIPT_DIR%perf_dhrystone.bat %*
exit /b
