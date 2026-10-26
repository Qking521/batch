@echo off
:: ============================================================
:: Author: wangqiang
:: Date:   2026-10-21
:: Desc:   通过 adb 将电脑本地时间同步到手机 (需 root)
:: Usage:  android_sync_time.bat [timezone]
::         timezone 可选, 例如 Asia/Shanghai, 传入则同时设置设备时区
:: ============================================================
chcp 65001 >nul
setlocal

set "timezone=%~1"

if /i "%~1"=="help" goto :usage
if /i "%~1"=="-h"   goto :usage

:: 3. 读取电脑本地时间 (纯 cmd 原生变量, 不依赖 PowerShell)
::    日期形如: 周一 2026/10/26 ; 时间形如: 14:05:42.94
for /f "tokens=2-4 delims=/ " %%a in ("%date%") do (
    set "PC_YYYY=%%a"
    set "PC_MM=%%b"
    set "PC_DD=%%c"
)

:: 小时可能带前导空格 (如 " 9:05:42.94"), 先替换为 0
set "T=%time: =0%"
for /f "tokens=1-4 delims=:." %%a in ("%T%") do (
    set "PC_HH=%%a"
    set "PC_MN=%%b"
    set "PC_SS=%%c"
    set "PC_MS=%%d"
)

set "PC_DATE=%PC_YYYY%-%PC_MM%-%PC_DD%"
set "PC_TIME=%PC_HH%:%PC_MN%:%PC_SS%"
:: toybox date 写入格式: MMDDhhmm[[CC]YY][.ss]
set "SETSTR=%PC_MM%%PC_DD%%PC_HH%%PC_MN%%PC_YYYY%.%PC_SS%"

:: 4. 读取手机当前时间
for /f "delims=" %%i in ('adb shell date') do set "DEV_BEFORE=%%i"

echo [INFO] PC   时间   : %PC_DATE% %PC_TIME%
echo [INFO] 手机 时间(前): %DEV_BEFORE%
echo [INFO] 待写入     : %SETSTR%

:: 5. 关闭网络自动对时, 避免写入后立即被 NTP 覆盖
adb shell settings put global auto_time 0 >nul 2>&1
adb shell settings put global auto_time_zone 0 >nul 2>&1

:: 5.1 设置手机时钟显示为 24 小时制 (time_12_24: 12=12小时制, 24=24小时制)
adb shell settings put system time_12_24 24 >nul 2>&1

:: 6. 写入系统时间 (toybox date 位置参数 SET 格式: MMDDhhmm[[CC]YY][.ss])
adb shell "date %SETSTR%"
if errorlevel 1 (
    echo [ERROR] 设置手机时间失败
    exit /b 1
)

:: 7. 将系统时间写回硬件时钟 RTC, 确保重启后时间依然生效
adb shell "hwclock -w"
if errorlevel 1 (
    echo [WARN] 写 RTC 硬件时钟失败, 重启后时间可能不保持
) else (
    echo [OK] 系统时间已写入 RTC 硬件时钟
)

:: 8. 可选: 同步时区
if not "%timezone%"=="" (
    adb shell "setprop persist.sys.timezone %timezone%" >nul 2>&1
    echo [INFO] 设备时区已设置为: %timezone%
)

:: 9. 校验
for /f "delims=" %%i in ('adb shell date') do set "DEV_AFTER=%%i"
echo [OK] 手机 时间(后): %DEV_AFTER%
exit /b 0

:usage
echo.
echo 用法: android_sync_time.bat [timezone]
echo.
echo 说明:
echo   将当前电脑本地时间同步到已连接的手机 (需 adb root)
echo   并设置手机时钟显示为 24 小时制
echo.
echo 参数:
echo   timezone   可选, 设备时区, 例如 Asia/Shanghai, Asia/Taipei
echo             不传则仅同步时间, 不改变设备时区
echo   help/-h    显示帮助
echo.
echo 示例:
echo   android_sync_time.bat
echo   android_sync_time.bat Asia/Shanghai
echo.
exit /b 0
