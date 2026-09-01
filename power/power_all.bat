@echo off
:: ============================================================
:: Author: WangQiang
:: Date:   2026-08-25
:: Desc:   Power management command dispatcher
:: Usage:  power <command> [args...]
:: ============================================================
chcp 65001 >nul
setlocal

set "cmd=%~1"
set "param1=%~2"
set "param2=%~3"

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
if /i "%cmd%"=="standby"   goto :standby
if /i "%cmd%"=="ps"        goto :power_supply
if /i "%cmd%"=="wallpaper" goto :wallpaper
if /i "%cmd%"=="profile"   goto :power_profile
if /i "%cmd%"=="reset"     goto :reset
if /i "%cmd%"=="wakelock"  goto :wakelock
if /i "%cmd%"=="regu"      goto :regulator
if /i "%cmd%"=="info"      goto :power_info
if /i "%cmd%"=="eet"       goto :eet_test
if /i "%cmd%"=="spm"       goto :spm
if /i "%cmd%"=="trace"     goto :trace
if /i "%cmd%"=="sql"       goto :sql

echo [ERROR] Unknown command: %cmd%
goto :usage

:usage
echo.
echo Usage: power [command] [args...]
echo.
echo Available commands:
echo   standby                      - Power base current settings
echo   ps                           - Show power supply info
echo   wallpaper [color] [action]   - Create / Set / Preview wallpaper
echo   profile                      - Display power profile data
echo   reset                        - Reset battery stats and clear logs
echo   wakelock                     - Show system wake lock status
echo   regu                         - Show regulator information
echo   info                         - Display device info related to power
echo   eet [policy] [freq]          - EET CPU fixed frequency test
echo   spm [data_file]              - Parse MediaTek SPM state data
echo   trace [ui/ui-enhance/sh]     - Perfetto trace collection and analysis
echo   sql [tag/statement] [zip]    - Query power info via SQL from bugreport
echo   -h / help                    - Show help info
echo.
echo Examples:
echo   power standby
echo   power info
echo   power wallpaper black set
echo.
exit /b 0

:standby
call "%SCRIPT_DIR%power_standby.bat" %param1%
exit /b %ERRORLEVEL%

:power_info
set "SH_SCRIPT=%SCRIPT_DIR%power_info.sh"
if not exist "%SH_SCRIPT%" (
    echo [ERROR] Script not found: %SH_SCRIPT%
    exit /b 1
)
adb shell "sh -s" < "%SH_SCRIPT%"
exit /b %ERRORLEVEL%

:power_supply
set "SH_SCRIPT=%SCRIPT_DIR%power_supply.sh"
if not exist "%SH_SCRIPT%" (
    echo [ERROR] Script not found: %SH_SCRIPT%
    exit /b 1
)
adb shell "sh -s" < "%SH_SCRIPT%"
exit /b %ERRORLEVEL%

:wallpaper
call "%SCRIPT_DIR%power_wallpaper.bat" %param1% %param2%
exit /b %ERRORLEVEL%

:power_profile
adb shell dumpsys batterystats --power-profile
exit /b %ERRORLEVEL%

:reset
adb root
adb shell "logcat -b all -c; dmesg -C"
adb shell dumpsys batterystats --reset
adb shell dumpsys batterystats --enable full-wake-history
adb shell dumpsys alarm --reset >nul
adb shell dumpsys alarm log on >nul
echo [OK] Battery stats reset and logs cleared.
exit /b 0

:wakelock
echo [INFO] Kernel Wake Locks:
adb shell cat /sys/power/wake_lock 2>nul
echo.
echo [INFO] Framework Wake Locks (Dumpsys Power):
adb shell dumpsys power | grep -A 20 "Wake Locks"
echo.
echo [INFO] Battery History Wake Locks:
adb shell dumpsys batterystats | grep -A 10 "Wake lock"
exit /b 0

:eet_test
set "SH_SCRIPT=%SCRIPT_DIR%power_eet.sh"
if not exist "%SH_SCRIPT%" (
    echo [ERROR] Script not found: %SH_SCRIPT%
    exit /b 1
)
::param1传policy的值，param2传policy的频点值
adb shell "sh -s %param1% %param2%" < "%SH_SCRIPT%"
exit /b %ERRORLEVEL%

:spm
for /f "delims= " %%a in ('adb shell getprop ro.product.board 2^>nul') do set "model=%%a"
set "SPM_CONFIG=%SCRIPT_DIR%power_spm_config\%model%_spm_config.xlsx"
if not exist "%SPM_CONFIG%" (
    echo [ERROR] SPM config file not found: %SPM_CONFIG%
    exit /b 1
)
if "%param1%"=="" (
    echo [ERROR] Please specify data file path.
    exit /b 1
)
python "%SCRIPT_DIR%power_spm.py" "%SPM_CONFIG%" "%param1%"
exit /b %ERRORLEVEL%

:regulator
set "SH_SCRIPT=%SCRIPT_DIR%power_regulator.sh"
if not exist "%SH_SCRIPT%" (
    echo [ERROR] Script not found: %SH_SCRIPT%
    exit /b 1
)
adb shell "sh -s" < "%SH_SCRIPT%"
exit /b %ERRORLEVEL%

:trace
for /f "tokens=1* delims= " %%a in ("%*") do (
    call "%SCRIPT_DIR%power_traces.bat" %%b
)
exit /b %ERRORLEVEL%

:sql
call "%SCRIPT_DIR%power_sql.bat" %*
exit /b %ERRORLEVEL%
