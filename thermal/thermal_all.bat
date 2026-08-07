@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "cmd=%~1"
set "param1=%~2"
set "param2=%~3"
set "param3=%~4"

if "%cmd%"=="" goto usage
if /i "%cmd%"=="-h" goto usage
if /i "%cmd%"=="help" goto usage

call %INIT_BAT% %~dp0
call "%ADB_CHECK_BAT%"
if %ERRORLEVEL% neq 0 (
    echo [ERROR]: ADB check failed.
    exit /b %ERRORLEVEL%
)

if /i "%cmd%"=="tz" goto thermal_infos
if /i "%cmd%"=="cd" goto thermal_infos
if /i "%cmd%"=="hm" goto thermal_infos
if /i "%cmd%"=="wt" goto whatsTemp
if /i "%cmd%"=="config" goto thermal_config

echo Unknown command: %cmd%
goto usage
exit /b 1

:usage
echo.
echo Usage: therm [command] [options]
echo.
echo Available commands:
echo   tz [dis/en]          - Query / Disable / Restore Thermal Zones
echo   cd                   - Show Cooling Devices status
echo   hm                   - Show Hardware Monitors (hwmon) status
echo   wt                   - WhatsTemp detection and config
echo   config [push/pull]   - Thermal config operations
echo   -h                   - Show help info (alias: help)
echo.
echo Examples:
echo   therm tz
echo   therm tz dis
echo   therm tz en
echo   therm cd
echo   therm hm
echo.
exit /b 0

:thermal_infos
set "SH_SCRIPT=%SCRIPT_DIR%thermal_infos.sh"
if not exist "%SH_SCRIPT%" (
    echo [ERROR] Script not found: %SH_SCRIPT%
    exit /b 1
)
adb shell "sh -s %cmd% %param1% %param2% %param3%" < "%SH_SCRIPT%"
exit /b %ERRORLEVEL%

:thermal_config
call "%SCRIPT_DIR%thermal_config.bat" %*
exit /b %ERRORLEVEL%

:whatsTemp
call "%SCRIPT_DIR%thermal_whats_temp.bat" %~2
exit /b %ERRORLEVEL%