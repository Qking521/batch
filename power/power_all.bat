@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for power_all.bat
:: ============================================================
chcp 65001 >nul
setlocal

call %INIT_BAT% %~dp0
:: 调用基础脚本检查ADB和设备（使用完整路径）
call "%ADB_CHECK_BAT%"
if %ERRORLEVEL% neq 0 (
    echo [错误]: 基础检测失败，退出操作。
    exit /b %ERRORLEVEL%
)
if not exist %OUT_DIR% mkdir %OUT_DIR%

set "cmd=%~1"
set "param1=%~2"
set "param2=%~3"

if "%cmd%"=="" goto show_help
if /i "%cmd%"=="-h" goto show_help
if /i "%cmd%"=="help" goto show_help
if /i "%cmd%"=="standby" goto standby
if /i "%cmd%"=="ps" goto power_supply
if /i "%cmd%"=="wallpaper" goto wallpaper
if /i "%cmd%"=="profile" goto power_profile
if /i "%cmd%"=="reset" goto reset
if /i "%cmd%"=="key" goto keyword
if /i "%cmd%"=="wakelock" goto wakelock
if /i "%cmd%"=="regu" goto regulator
if /i "%cmd%"=="info" goto power_info
if /i "%cmd%"=="eet" goto eet_test
if /i "%cmd%"=="spm" goto spm

echo Unknown command: %cmd%
goto show_help
exit /b

:show_help
echo.
echo Usage: power [command]
echo.
echo Available commands:
echo   standby              - Power base current settings.
echo   tz [en/dis]          - Thermal zones info/enable/disable.
echo   hm                   - Show hardware monitor info.
echo   ps                   - Show power supply info.
echo   cd                   - Show cooling devices info.
echo   wallpaper [color]    - Create/Set wallpaper for specific color.
echo   profile              - Display power profile data on terminal.
echo   reset                - Reset battery stats and clear logs.
echo   wt [cmd]             - WhatsTemp control tools.
echo   key                  - List common power log keywords.
echo   wakelock             - Show system wake lock status.
echo   cpu                  - Show CPU frequency and online status.
echo   regu                 - Show regulator information.
echo   info                 - Display device information related to power consumption
echo   config [push/pull]   - Thermal config operations.
echo   -h                   - Show help (alias: help).
echo.
echo Examples:
echo   power standby
echo.
exit /b

:standby
call "%SCRIPT_DIR%power_standby.bat" %param1%
exit /b


:power_info
call "%SCRIPT_DIR%power_info.bat"
exit /b

:power_supply
set "SH_SCRIPT=%SCRIPT_DIR%power_supply.sh"
adb shell "sh -s"  < "%SH_SCRIPT%"
exit /b

:wallpaper
call "%SCRIPT_DIR%power_wallpaper.bat" %~2 %~3
exit /b

:power_profile
adb shell dumpsys batterystats --power-profile
exit /b

:reset
adb root
adb shell "logcat -b all -c; dmesg -C"
adb shell dumpsys batterystats --reset
adb shell dumpsys batterystats --enable full-wake-history
adb shell dumpsys alarm log on > nul
exit /b

:wakelock
adb shell cat /sys/power/wake_lock
adb shell dumpsys power | grep -A 20 "Wake Locks"
adb shell dumpsys batterystats | grep -A 10 "Wake lock"
exit /b

:eet_test
call "%SCRIPT_DIR%power_eet.bat" %*
exit /b

:spm
for /f "delims= " %%a in ('adb shell getprop ro.product.board') do set model=%%a
set SPM_CONFIG=%SCRIPT_DIR%\power_spm_config\%model%_spm_config.xlsx
if not exist %SPM_CONFIG% (
    echo %SPM_CONFIG%文件不存在，请确认
    exit /b
)
echo param1=%param1%
if "%param1%"=="" (
    echo 数据文件不存在，请确认
    exit /b
)
python "%SCRIPT_DIR%power_spm.py" %SPM_CONFIG% %param1%
exit /b

:regulator
set "SH_SCRIPT=%SCRIPT_DIR%power_regulator.sh"
adb shell "sh -s"  < "%SH_SCRIPT%"
exit /b


:keyword
echo "查看唤醒锁和唤醒原因"
echo "All kernel wake locks|All partial wake locks|All wakeup reasons|All screen wake reasons"
echo "查看系统是否待机"
echo "suspend entry|suspend exit|26M_off_pct|blocked by"
echo "查看系统待机后唤醒原因"
echo "wakeup_reason|wakeup alarm|Resume caused by|suspend wake up by|Pending Wakeup Sources|active wakeup source|set alarm :"
echo "查看NTC温度"
echo adb shell "i=0 ; while [[ $i -lt 80 ]] ; do (type=`cat /sys/class/thermal/thermal_zone$i/type` ; temp=`cat /sys/class/thermal/thermal_zone$i/temp` ; echo "$i $type : $temp"); i=$((i+1));done"
echo "温升分析"
echo "DexOptimizer|ThermalInfo:|thermal_core|thermal IRQ|throttling|mmi_thermal_ratio|Apply thermal policy:|libPowerHal:"
echo "其它未分类"
echo "screen_toggled|sys.powerctl|AlarmManager: Adjust deliver|sensorservice"
exit /b