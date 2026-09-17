@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "param1=%~1"
set "param2=%~2"

if /i "%param1%"=="-h" goto :usage
if /i "%param1%"=="help" goto :usage

set "target=all"
set "interval=5"

rem 解析参数：支持 watch 2, watch cpu, watch gpu 3, watch all 5 等
if not "%param1%"=="" (
    set "is_num=1"
    for /f "delims=0123456789" %%i in ("%param1%") do set "is_num=0"
    if "!is_num!"=="1" (
        set "interval=%param1%"
    ) else (
        set "target=%param1%"
        if not "%param2%"=="" set "interval=%param2%"
    )
)

set "CPU_SH=%~dp0perf_cpu.sh"
set "GPU_SH=%~dp0perf_gpu.sh"

rem 1. 单独监听 CPU：复用 perf_cpu.sh 的 watch 内部方法
if /i "!target!"=="cpu" (
    if not exist "!CPU_SH!" ( echo [ERROR] 找不到 !CPU_SH! & exit /b 1 )
    adb shell "sh -s watch !interval!" < "!CPU_SH!"
    exit /b
)

rem 2. 单独监听 GPU：复用 perf_gpu.sh 的 watch 内部方法
if /i "!target!"=="gpu" (
    if not exist "!GPU_SH!" ( echo [ERROR] 找不到 !GPU_SH! & exit /b 1 )
    adb shell "sh -s watch !interval!" < "!GPU_SH!"
    exit /b
)

rem 3. 联合监听 CPU + GPU (all)：仅加载 GPU 函数库，直接复用 perf_cpu.sh 的 watch 监听循环联动输出
if not exist "!CPU_SH!" ( echo [ERROR] 找不到 !CPU_SH! & exit /b 1 )
if not exist "!GPU_SH!" ( echo [ERROR] 找不到 !GPU_SH! & exit /b 1 )

set "TMP_WATCH_SH=%TEMP%\perf_watch_tmp_%RANDOM%.sh"
(
    echo #!/system/bin/sh
    echo PERF_LIB_ONLY=1
    type "!GPU_SH!"
    echo.
    echo unset PERF_LIB_ONLY
    type "!CPU_SH!"
) > "!TMP_WATCH_SH!"

adb shell "sh -s watch !interval!" < "!TMP_WATCH_SH!"
del /f /q "!TMP_WATCH_SH!" 2>nul
exit /b

:usage
echo.
echo 用法: perf watch [cpu^|gpu^|all] [interval_sec]
echo.
echo 说明:
echo   实时动态监听 CPU/GPU 状态变化 (默认 all 5s 刷新，按 Ctrl+C 退出)
echo.
echo 示例:
echo   perf watch
echo   perf watch 2
echo   perf watch cpu
echo   perf watch cpu 2
echo   perf watch gpu 3
echo   perf watch all 5
echo.
exit /b 0
