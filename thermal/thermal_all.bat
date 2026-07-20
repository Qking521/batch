@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for thermal_all.bat
:: ============================================================
chcp 65001 >nul
setlocal

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

if "%1"=="" goto show_help
if /i "%1"=="-h" goto show_help
if /i "%1"=="help" goto show_help
if /i "%1"=="tz" goto thermal_zones
if /i "%1"=="hm" goto hwmon
if /i "%1"=="cd" goto cooling_devices
if /i "%1"=="wt" goto whatsTemp
if /i "%1"=="install" goto install_apk
if /i "%1"=="config" goto thermal_config

echo Unknown command: %cmd%
goto show_help
exit /b

:show_help
echo.
echo Usage: therm [command]
echo.
echo Available commands:
echo   tz [en/dis]          - Thermal zones info/enable/disable.
echo   hm                   - Show hardware monitor info.
echo   cd                   - Show cooling devices info.
echo   wt                   - whatstemp相关的操作
echo   install              - 安装温升辅助工具apk
echo   config [push/pull]   - Thermal config operations.
echo   -h                   - Show help (alias: help).
echo.
echo Examples:
echo   therm tz
echo.
exit /b

:thermal_zones
call "%SCRIPT_DIR%thermal_thermal_zones.bat" %~2
exit /b

:thermal_config
call "%SCRIPT_DIR%thermal_config.bat" %*
exit /b

:cooling_devices
call "%SCRIPT_DIR%thermal_cooling_devices.bat"
exit /b

:hwmon
call "%SCRIPT_DIR%thermal_hwmon.bat"
exit /b

:install_apk
call "%SCRIPT_DIR%thermal_installs.bat" %2
exit /b

:whatsTemp
call "%SCRIPT_DIR%thermal_whats_temp.bat" %~2
exit /b