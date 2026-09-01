@echo off
:: ============================================================
:: Author: WangQiang
:: Date:   2026-08-25
:: Desc:   Thermal management command dispatcher
:: Usage:  therm <command> [options]
:: ============================================================
chcp 65001 >nul
setlocal

set "cmd=%~1"
set "param1=%~2"
set "param2=%~3"
set "param3=%~4"

:: 1. Priority help check
if "%cmd%"==""        goto :usage
if /i "%cmd%"=="-h"   goto :usage
if /i "%cmd%"=="help" goto :usage

:: 2. Initialize environment
call %INIT_BAT% %~dp0

:: 3. Check ADB connection (whitelist skipped automatically)
call "%ADB_CHECK_BAT%" "%cmd%"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] ADB check failed.
    exit /b %ERRORLEVEL%
)

:: 4. Ensure OUT directory exists
if not exist "%MODULE_OUT_DIR%" mkdir "%MODULE_OUT_DIR%"

:: 5. Command dispatcher
if /i "%cmd%"=="tz"     goto :thermal_infos
if /i "%cmd%"=="cd"     goto :thermal_infos
if /i "%cmd%"=="hm"     goto :thermal_infos
if /i "%cmd%"=="fake"   goto :thermal_fake
if /i "%cmd%"=="wt"     goto :whats_temp
if /i "%cmd%"=="config" goto :thermal_config

echo [ERROR] Unknown command: %cmd%
goto :usage

:usage
echo.
echo Usage: therm [command] [options]
echo.
echo Available commands:
echo   tz [dis/en]          - Query / Disable / Restore Thermal Zones
echo   cd                   - Show Cooling Devices status
echo   hm                   - Show Hardware Monitors (hwmon) status
echo   fake [zone] [temp_c] - Write emul_temp to simulate thermal zone temperature
echo   wt [start/stop/pull] - WhatsTemp detection, recording and config
echo   config [push/pull]   - Thermal config operations
echo   -h / help            - Show help info
echo.
echo Examples:
echo   therm tz
echo   therm tz dis
echo   therm tz en
echo   therm cd
echo   therm hm
echo   therm wt
echo.
exit /b 0

:thermal_infos
set "SH_SCRIPT=%SCRIPT_DIR%thermal_infos.sh"
if not exist "%SH_SCRIPT%" (
    echo [ERROR] Shell script not found: %SH_SCRIPT%
    exit /b 1
)
adb shell "sh -s %cmd% %param1% %param2% %param3%" < "%SH_SCRIPT%"
exit /b %ERRORLEVEL%

:thermal_config
call "%SCRIPT_DIR%thermal_config.bat" %*
exit /b %ERRORLEVEL%

:whats_temp
call "%SCRIPT_DIR%thermal_whats_temp.bat" %param1%
exit /b %ERRORLEVEL%

:thermal_fake
set "SH_SCRIPT=%SCRIPT_DIR%thermal_infos.sh"
if not exist "%SH_SCRIPT%" (
    echo [ERROR] Shell script not found: %SH_SCRIPT%
    exit /b 1
)
adb shell "sh -s tz fake %param1% %param2%" < "%SH_SCRIPT%"
exit /b %ERRORLEVEL%