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

:: 3. 读取电脑本地时间 (PowerShell 提供与系统区域设置无关的稳定格式)
for /f "delims=" %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "PC_DATE=%%i"
for /f "delims=" %%i in ('powershell -NoProfile -Command "Get-Date -Format HH:mm:ss"') do set "PC_TIME=%%i"
for /f "delims=" %%i in ('powershell -NoProfile -Command "Get-Date -Format MMddHHmmyyyy.ss"') do set "SETSTR=%%i"

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

:: 7. 可选: 同步时区
if not "%timezone%"=="" (
    adb shell "setprop persist.sys.timezone %timezone%" >nul 2>&1
    echo [INFO] 设备时区已设置为: %timezone%
)

:: 8. 校验
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