@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: 这里的dhrystone是文件形式不同于dhrystone apk
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

set "cmd=%2"
set "DEVICE_DHRY_PATH=/data/dhrystone.sh"

if /i "%cmd%"=="" goto show_help
if /i "%cmd%"=="-h" goto show_help
if /i "%cmd%"=="help" goto show_help
if /i "%cmd%"=="push" goto eet_push
if /i "%cmd%"=="start" goto eet_start
if /i "%cmd%"=="stop" goto eet_stop

echo Unknown command: %1
goto show_help
exit /b

:show_help
echo.
echo Usage: perf [command]
echo.
echo Available commands:
echo   push              - push dhrystone to device
echo   start             - start dhrystone process
echo   stop              - stop dhrystone process
echo   -h                - Show help (alias: help).
echo.
echo Examples:
echo   perf start
echo.
exit /b

:eet_push
    set "FILE_CHECK="
    for /f "usebackq delims=" %%r in (`adb shell "[ -f %DEVICE_DHRY_PATH% ] && echo EXIST || echo NOTEXIST"`) do (
        set "FILE_CHECK=%%r"
    )
    echo FILE_CHECK=!FILE_CHECK!
    
    if "!FILE_CHECK!"=="NOTEXIST" (
        echo [INFO] %DEVICE_DHRY_PATH% 不存在，正在安装...
        cd %SCRIPT_DIR%dhrystone
        call install_dhrystone_64.bat
        if errorlevel 1 (
            echo [ERROR] dhrystone安装失败
            exit /b 1
        )
        cd %SCRIPT_DIR%
        echo [INFO] 安装完成
    )
    exit /b

:eet_start 
    set "FILE_CHECK="
    for /f "usebackq delims=" %%r in (`adb shell "[ -f %DEVICE_DHRY_PATH% ] && echo EXIST || echo NOTEXIST"`) do (
        set "FILE_CHECK=%%r"
    )
    if "!FILE_CHECK!"=="NOTEXIST" (
        call eet_push
    )

    set "DHRY_PID="
    for /f "usebackq delims=" %%p in (`adb shell "ps -ef | grep dhrystone.sh | grep -v grep"`) do (
        set "DHRY_PID=%%p"
    )

    if "%DHRY_PID%"=="" (
        echo [INFO] 未检测到 dhrystone 进程，正在启动...
        rem cd到/data后台跑dhrystone.sh，stdout/stderr重定向到/dev/null，再手动exit，避免adb shell因为还占着输出fd而一直卡住不返回
        adb shell "cd /data; nohup ./dhrystone.sh > /dev/null 2>&1 & exit"
    )
    echo [INFO] 检测到 dhrystone 进程已启动...

    adb shell "ps -ef | grep dhrystone | grep -v grep"
    exit /b

:dhrystone_stop
    adb shell "for pid in $(ps -ef | grep dhrystone | grep -v grep | awk '{print $2}'); do kill -9 $pid; done"
    echo [INFO] dhrystone进程清除完成
    exit /b

