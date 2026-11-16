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
if /i "%cmd%"=="watch"  goto :thermal_watch
if /i "%cmd%"=="tz"     goto :thermal_zone
if /i "%cmd%"=="cat"    goto :thermal_cat
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
echo   watch [interval_sec] - Monitor Thermal Zone temperature changes (default 5s)
echo   tz [watch/dis/en/cat] - Query / Watch / Disable / Restore Thermal Zones
echo   cat [tz/cd/hm/all]   - Show thermal info (read-only)
echo   fake [zone] [temp_c] - Write emul_temp to simulate thermal zone temperature
echo   fake status [0-6]    - Set Thermal Service override status (reset to clear)
echo   wt [start/stop/pull] - WhatsTemp detection, recording and config
echo   config [push/pull]   - Thermal config operations
echo   -h / help            - Show help info
echo.
echo Examples:
echo   therm watch
echo   therm watch 2
echo   therm tz
echo   therm tz watch
echo   therm tz dis
echo   therm tz en
echo   therm tz cat
echo   therm cat cd
echo   therm cat all
echo   therm fake ap_ntc 30
echo   therm fake status 3
echo   therm fake status reset
echo   therm wt
echo.
exit /b 0

:thermal_watch
set "SH_SCRIPT=%SCRIPT_DIR%thermal_zone.sh"
if not exist "%SH_SCRIPT%" (
    echo [ERROR] Shell script not found: %SH_SCRIPT%
    exit /b 1
)
adb shell "sh -s watch %param1%" < "%SH_SCRIPT%"
exit /b %ERRORLEVEL%

:thermal_zone
set "SH_SCRIPT=%SCRIPT_DIR%thermal_zone.sh"
if not exist "%SH_SCRIPT%" (
    echo [ERROR] Shell script not found: %SH_SCRIPT%
    exit /b 1
)
adb shell "sh -s %param1% %param2% %param3%" < "%SH_SCRIPT%"
exit /b %ERRORLEVEL%

:thermal_cat
set "SH_SCRIPT=%SCRIPT_DIR%thermal_cat.sh"
if not exist "%SH_SCRIPT%" (
    echo [ERROR] Shell script not found: %SH_SCRIPT%
    exit /b 1
)
:: 规范化 help 参数：-h/--help 会被 sh 当作自身选项吞掉，统一映射为 help
set "CAT_ACTION=%param1%"
if /i "%CAT_ACTION%"=="-h"     set "CAT_ACTION=help"
if /i "%CAT_ACTION%"=="--help" set "CAT_ACTION=help"
adb shell "sh -s %CAT_ACTION%" < "%SH_SCRIPT%"
exit /b %ERRORLEVEL%

:thermal_fake
set "SH_SCRIPT=%SCRIPT_DIR%thermal_fake.sh"
if not exist "%SH_SCRIPT%" (
    echo [ERROR] Shell script not found: %SH_SCRIPT%
    exit /b 1
)
adb shell "sh -s %param1% %param2% %param3%" < "%SH_SCRIPT%"
exit /b %ERRORLEVEL%

:thermal_config
call "%SCRIPT_DIR%thermal_config.bat" %*
exit /b %ERRORLEVEL%

:whats_temp
call "%SCRIPT_DIR%thermal_whats_temp.bat" %param1%
exit /b %ERRORLEVEL%
