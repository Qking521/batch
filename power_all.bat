@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
:: 获取当前脚本所在目录
set "SCRIPT_DIR=%~dp0"

if "%1"=="" goto show_help
if /i "%1"=="-h" goto show_help
if /i "%1"=="help" goto show_help
if /i "%1"=="standby" goto standby
if /i "%1"=="ntc" goto ntc
if /i "%1"=="wallpaper" goto wallpaper
if /i "%1"=="profile" goto power_profile
if /i "%1"=="reset" goto reset
if /i "%1"=="decrypt" goto decrypt
if /i "%1"=="wt" goto whatstempeture
if /i "%1"=="key" goto keyword
if /i "%1"=="wakelock" goto wakelock

echo Unknown command: %1
echo Use "power -h" for help
exit /b

:show_help
echo.
echo Android Power Commands
echo =======================
echo.
echo Usage: power [command]
echo.
echo Available commands:
echo   standby - power base current settings
echo   ntc     - show ntc infomation
echo   ww      - create white wallpaper
echo   wt	   - install whatstempeture apk
echo   profile - display power profile data on terminal
echo   reset   - reset batterystats
echo   decrypt - decrypt thermal config file
echo   key     -- list log keyword
echo   -h      - Show help (alias: help^)
echo.
echo Examples:
echo   power standby
echo.
exit /b

:standby
call "%SCRIPT_DIR%power_standby.bat"
if %ERRORLEVEL% neq 0 (
    echo [错误]: 基础检测失败，退出操作。
    exit /b %ERRORLEVEL%
)
exit /b

:ntc
call "%SCRIPT_DIR%power_ntc_info.bat"
exit /b

:wallpaper
call "%SCRIPT_DIR%power_white_wallpaper.bat" %~2
if %ERRORLEVEL% neq 0 (
    echo [错误]: 基础检测失败，退出操作。
    exit /b %ERRORLEVEL%
)
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

:decrypt
call "%SCRIPT_DIR%power_mtk_thermal_decrypt.bat"
if %ERRORLEVEL% neq 0 (
    echo [错误]: 基础检测失败，退出操作。
    exit /b %ERRORLEVEL%
)
exit /b

:whatstempeture
cd %SCRIPT_DIR%WhatsTemp_exe_v1.9_2419
echo %SCRIPT_DIR%WhatsTemp_exe_v1.9_2419
call install_LogTool.bat
if %ERRORLEVEL% neq 0 (
    echo [错误]: 基础检测失败，退出操作。
    exit /b %ERRORLEVEL%
)
adb shell pm grant com.example.mtk10263.whatsTemp android.permission.POST_NOTIFICATIONS
adb shell pm grant com.example.mtk10263.whatsTemp android.permission.WRITE_EXTERNAL_STORAGE
adb shell dumpsys deviceidle whitelist +com.example.mtk10263.whatsTemp
exit /b

:wakelock
adb shell cat /sys/power/wake_lock
adb shell dumpsys power | grep -A 20 "Wake Locks"
adb shell dumpsys batterystats | grep -A 10 "Wake lock"
exit /b

:keyword
echo "查看温升相关信息"
echo "thermal_core|thermal IRQ|powerhal"
echo "查看唤醒锁和唤醒原因"
echo "All kernel wake locks|All partial wake locks|All wakeup reasons|All screen wake reasons"
echo "查看系统是否待机"
echo "suspend entry|suspend exit|26M_off_pct"
echo "查看系统待机后唤醒原因"
echo "wakeup_reason|wakeup alarm|Resume caused by|suspend wake up by|Pending Wakeup Sources|active wakeup source"
echo "查看NTC温度"
echo adb shell "i=0 ; while [[ $i -lt 50 ]] ; do (type=`cat /sys/class/thermal/thermal_zone$i/type` ; temp=`cat /sys/class/thermal/thermal_zone$i/temp` ; echo "$i $type : $temp"); i=$((i+1));done"
echo "温升分析"
echo "DexOptimizer|ThermalInfo:|thermal_core|throttling"
echo "others"
echo "screen_toggled"
exit /b