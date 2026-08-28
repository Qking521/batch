@echo off
chcp 65001 >nul
:: ============================================================
:: Author: WangQiang
:: Date:   2026-08-05
:: Desc:   Android 录屏入口脚本
:: Usage:  android_screen_record.bat [filename.mp4]
:: ============================================================
setlocal enabledelayedexpansion

if /i "%~1"=="-h"   goto :usage
if /i "%~1"=="help" goto :usage

set "SH_SCRIPT=%~dp0android_screen_record.sh"
if not exist "%SH_SCRIPT%" (
    echo [ERROR] Shell script not found: %SH_SCRIPT%
    exit /b 1
)

:: 设置文件名
set "RECORD_FILE=record_%FORMAT_TIME%.mp4"

echo screenrecording， Press any key to stop recording...

:: 调用 Shell 业务层启动录屏
adb shell "sh -s start %RECORD_FILE%" < "%SH_SCRIPT%"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Screenrecord start failed.
    exit /b 1
)

pause >nul

echo.
echo Stopping screenrecord...
adb shell "sh -s stop %RECORD_FILE%" < "%SH_SCRIPT%"

:: 等待设备端写盘完成
echo Waiting for record file write finish...
:wait_record_finish
timeout /t 1 /nobreak >nul
for /f "tokens=1" %%p in ('adb shell "pidof screenrecord" 2^>nul') do (
    if not "%%p"=="" goto :wait_record_finish
)

:: 拉取录屏文件
if not exist "%MODULE_OUT_DIR%" mkdir "%MODULE_OUT_DIR%"
set "OUT_RECORD_FILE=%MODULE_OUT_DIR%%RECORD_FILE%"
if exist "%OUT_RECORD_FILE%" del /f "%OUT_RECORD_FILE%"

echo Pulling record file to local: %OUT_RECORD_FILE%
adb pull "/sdcard/%RECORD_FILE%" "%OUT_RECORD_FILE%"
adb shell "rm -f /sdcard/%RECORD_FILE%"

if exist "%OUT_RECORD_FILE%" (
    echo [OK] Record file extracted successfully!
    start "" "%OUT_RECORD_FILE%"
) else (
    echo [ERROR] Failed to pull record file.
    exit /b 1
)
exit /b 0

:usage
echo.
echo 用法: ad sr [文件名.mp4]
echo.
echo 参数:
echo   -h / help      - 显示此帮助信息
echo.
echo 示例:
echo   ad sr
echo.
exit /b 0
