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
if /i "%1"=="info" goto thermal_infos
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
echo   tz [en/dis]          - 查看当前所有温度传感器信息 (默认动作).
echo   hm                   - 查看当前所有硬件监控器的状态信息 (默认动作).
echo   cd                   - 查看当前所有冷却设备的状态信息 (默认动作).
echo   wt                   - whatstemp相关的操作
echo   install              - 安装温升辅助工具apk
echo   config [push/pull]   - Thermal config operations.
echo   info [tz/cd/hm]      - 查看温升tz/cd/hm等相关信息
echo   -h                   - Show help (alias: help).
echo.
echo Examples:
echo   therm tz
echo.
exit /b

:thermal_infos
call "%SCRIPT_DIR%thermal_infos.bat" %*
exit /b

:thermal_zones
if /i "%param1%"=="" set "ACTION=info"
if /i "%param1%"=="dis" set "ACTION=disable"
if /i "%param1%"=="en" set "ACTION=enable"
set "SH_SCRIPT=%SCRIPT_DIR%thermal_thermal_zones.sh"
adb shell "sh -s %ACTION%" < "%SH_SCRIPT%"
exit /b

:cooling_devices
set "SH_SCRIPT=%SCRIPT_DIR%thermal_cooling_devices.sh"
adb shell "sh -s" < "%SH_SCRIPT%"
exit /b

:hwmon
set "SH_SCRIPT=%SCRIPT_DIR%thermal_hwmon.sh"
adb shell "sh -s"  < "%SH_SCRIPT%"
exit /b

:thermal_config
call "%SCRIPT_DIR%thermal_config.bat" %*
exit /b

:install_apk
call "%SCRIPT_DIR%thermal_installs.bat" %2
exit /b

:whatsTemp
call "%SCRIPT_DIR%thermal_whats_temp.bat" %~2
exit /b