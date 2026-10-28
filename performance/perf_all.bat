@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "cmd=%~1"
set "param1=%~2"
set "param2=%~3"
set "param3=%~4"
set "param4=%~5"

call %INIT_BAT% %~dp0
:: 调用基础脚本检查ADB和设备（使用完整路径，传入当前子命令）
call "%ADB_CHECK_BAT%" "%cmd%"
if %ERRORLEVEL% neq 0 (
    echo [错误]: 基础检测失败，退出操作。
    exit /b %ERRORLEVEL%
)
:: 创建performance的OUT目录
if not exist %MODULE_OUT_DIR% (
	mkdir %MODULE_OUT_DIR%
)

if /i "%cmd%"=="" goto :usage
if /i "%cmd%"=="-h" goto :usage
if /i "%cmd%"=="help" goto :usage
if /i "%cmd%"=="watch" goto watch
if /i "%cmd%"=="trace" goto trace
if /i "%cmd%"=="cat" goto cat
if /i "%cmd%"=="cpu" goto cpu
if /i "%cmd%"=="gpu" goto gpu
if /i "%cmd%"=="flame" goto flame
if /i "%cmd%"=="ds" goto dhrystone
if /i "%cmd%"=="sql" goto sql

echo [ERROR] 未知命令: %cmd%
goto :usage
exit /b

:usage
echo.
echo 用法: perf ^<命令^> [参数]
echo.
echo 命令:
echo   watch [cpu^|gpu^|all] [interval_sec] - 实时动态监听 CPU/GPU 状态变化 (默认 all 5s)
echo   trace [cmd/online/cfg/ui/sh]    - Perfetto 性能抓取及打开 Trace
echo   cat [gov]                       - 查看 CPU governor / 原始命令
echo   sql [tag/sql] [trace_path]       - 使用 SQL 查询性能 Trace
echo   cpu [info/freq/max/online/...]   - CPU 调控
echo   gpu [info/freq/fix-freq/...]     - GPU 调控
echo   ds                               - Dhrystone 操作
echo   flame [record/parse]             - 火焰图抓取与解析 (simpleperf)
echo   help / -h                        - 显示此帮助信息
echo.
echo 示例:
echo   perf watch
echo   perf watch 2
echo   perf watch cpu
echo   perf watch cpu 2
echo   perf watch gpu 3
echo   perf trace cmd 5
echo   perf trace ui
echo   perf sql cpu_usage
echo   perf sql "SELECT name, dur FROM slice LIMIT 10"
echo   perf cpu info
echo   perf cpu max
echo   perf gpu info
echo   perf flame record
echo   perf flame record com.android.settings
echo   perf flame parse
echo.
exit /b 0

:trace
    call %SCRIPT_DIR%perf_traces.bat %*
    exit /b

:cat
    set "SH_SCRIPT=%SCRIPT_DIR%perf_cat.sh"
    if not exist "%SH_SCRIPT%" (
        echo [ERROR] 找不到 shell 脚本: %SH_SCRIPT%
        exit /b 1
    )
    :: 规范化 help 参数：-h/--help 以 - 开头会被 sh 当作自身选项吞掉，统一映射为 help
    set "CAT_ACTION=%param1%"
    if /i "%CAT_ACTION%"=="-h"     set "CAT_ACTION=help"
    if /i "%CAT_ACTION%"=="--help" set "CAT_ACTION=help"
    adb shell "sh -s %CAT_ACTION%" < "%SH_SCRIPT%"
    exit /b %ERRORLEVEL%

:watch
    call %SCRIPT_DIR%perf_watch.bat %param1% %param2%
    exit /b

:cpu
    set "SH_SCRIPT=%SCRIPT_DIR%perf_cpu.sh"
    if not exist "%SH_SCRIPT%" (
        echo [ERROR] 找不到 shell 脚本: %SH_SCRIPT%
        exit /b 1
    )
    adb shell "sh -s %param1% %param2% %param3% %param4%" < "%SH_SCRIPT%"
    exit /b

:gpu
    set "SH_SCRIPT=%SCRIPT_DIR%perf_gpu.sh"
    if not exist "%SH_SCRIPT%" (
        echo [ERROR] 找不到 shell 脚本: %SH_SCRIPT%
        exit /b 1
    )
    adb shell "sh -s %param1% %param2% %param3% %param4%" < "%SH_SCRIPT%"
    exit /b

:flame
    call %SCRIPT_DIR%perf_simpleperf.bat %*
    exit /b

:dhrystone
    call %SCRIPT_DIR%perf_dhrystone.bat
    set "SH_SCRIPT=%SCRIPT_DIR%perf_dhrystone.sh"
    if not exist "%SH_SCRIPT%" (
        echo [ERROR] 找不到 shell 脚本: %SH_SCRIPT%
        exit /b 1
    )
    adb shell "sh -s %param1% %param2% %param3%" < "%SH_SCRIPT%"
    exit /b

:sql
    call "%SCRIPT_DIR%perf_sql.bat" %*
    exit /b
