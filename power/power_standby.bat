@echo off
chcp 65001 >nul
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for power_standby.bat
:: Usage: power standby [restore|default]
:: ============================================================
setlocal EnableDelayedExpansion



set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=standby"

set "SCRIPT_DIR=%~dp0"
set "SH_SCRIPT=%SCRIPT_DIR%power_standby.sh"
set "ARCHIVE_DIR=%SCRIPT_DIR%power_archive"

if not exist "%ARCHIVE_DIR%" mkdir "%ARCHIVE_DIR%"

:: 1. 获取设备型号名称 ro.product.device
set "DEVICE_NAME="
for /f "tokens=1" %%d in ('adb shell "getprop ro.product.device" 2^>nul') do (
    set "DEVICE_NAME=%%d"
)
:: 滤除换行或空值
if "!DEVICE_NAME!"=="" set "DEVICE_NAME=unknown"
set "CONF_FILE=!DEVICE_NAME!_standby_default.conf"
set "LOCAL_CONF=!ARCHIVE_DIR!\!CONF_FILE!"
set "REMOTE_CONF=/data/local/tmp/power_archive/!CONF_FILE!"

if /i "%ACTION%"=="default"     goto :do_get_default
if /i "%ACTION%"=="restore"     goto :do_restore
if /i "%ACTION%"=="standby"     goto :do_standby

echo [ERROR] Unknown command: %ACTION%
echo Usage: power standby [restore^|default]
exit /b 1

:do_get_default
    echo [INFO] Saving standby default config (Device: !DEVICE_NAME!)...
    adb shell "sh -s default" < "%SH_SCRIPT%"
    if !ERRORLEVEL! neq 0 (
        echo [ERROR] Failed to generate default config on device.
        exit /b 1
    )
    :: pull 配置文件到本地 power_archive
    echo [INFO] Pulling default config file to PC local: !LOCAL_CONF!
    adb pull "!REMOTE_CONF!" "!LOCAL_CONF!" >nul 2>&1
    if exist "!LOCAL_CONF!" (
        echo [OK] Default config file synced to local power_archive
    ) else (
        echo [WARN] Failed to pull config file.
    )
    exit /b 0

:do_standby
    :: 检查本地是否存在默认配置文件
    if not exist "!LOCAL_CONF!" (
        echo [INFO] !CONF_FILE! not found in !ARCHIVE_DIR!, collecting from device...
        call :do_get_default
    ) else (
        :: 确保设备端也有该配置文件
        adb shell "mkdir -p /data/local/tmp/power_archive" >nul 2>&1
        adb push "!LOCAL_CONF!" "!REMOTE_CONF!" >nul 2>&1
    )

    echo [INFO] Applying standby environment settings...
    adb shell "sh -s standby" < "%SH_SCRIPT%"
    exit /b %ERRORLEVEL%

:do_restore
    :: 检查本地是否存在默认配置文件，若不存在则先做采集
    if not exist "!LOCAL_CONF!" (
        echo 没有默认值文件可用于恢复,请恢复出厂后生成默认文件，power standby default
        exit /b 0
    )

    :: 将本地档案推送至设备端供恢复函数读取
    adb shell "mkdir -p /data/local/tmp/power_archive" >nul 2>&1
    adb push "!LOCAL_CONF!" "!REMOTE_CONF!" >nul 2>&1

    echo [INFO] Restoring standby default settings...
    adb shell "sh -s restore" < "%SH_SCRIPT%"
    exit /b %ERRORLEVEL%
