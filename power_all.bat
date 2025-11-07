@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
:: 获取当前脚本所在目录
set "SCRIPT_DIR=%~dp0"

:: 先调用基础脚本检查ADB和设备（使用完整路径）
call "%SCRIPT_DIR%adb_check.bat"
if %ERRORLEVEL% neq 0 (
    exit /b
)

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
if /i "%1"=="default" goto defalut_value
if /i "%1"=="hw" goto hardware_info

echo Unknown command: %1
goto show_help
exit /b

:show_help
echo.
echo Android Power Commands
echo =======================
echo.
echo Usage: power [command]
echo.
echo Available commands:
echo   standby		- power base current settings
echo   ntc			- show ntc infomation
echo   wallpaper	- create wallpaper for any color
echo   wt			- install whatstempeture apk
echo   profile		- display power profile data on terminal
echo   reset		- reset batterystats
echo   decrypt		- decrypt thermal config file
echo   key			- list log keyword
echo   -h			- Show help (alias: help^)
echo.
echo Examples:
echo   power standby
echo.
exit /b

:standby
call "%SCRIPT_DIR%power_standby.bat"
exit /b

:ntc
call "%SCRIPT_DIR%power_ntc_info.bat"
exit /b

:wallpaper
call "%SCRIPT_DIR%power_wallpaper.bat" %~2
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

:defalut_value
adb shell settings get system screen_brightness
exit /b

:hardware_info
for /f "tokens=2 delims=:" %%a in ('adb shell cat /proc/meminfo ^| find "MemTotal"') do set meminfo=%%a
for /f "tokens=1" %%b in ('echo %meminfo%') do set mem_kb=%%b
set /a mem_gb=(%mem_kb% + 1048576 - 1) / 1048576 
echo RAM大小: %mem_gb%G

set "line="
for /f "delims=" %%L in ('adb shell dumpsys diskstats') do (
    echo %%L | findstr /C:"Data-Free" >nul
    if !errorlevel! EQU 0 (
        set "line=%%L"
        goto found
    )
)
:found
for /f "tokens=2 delims=/ " %%a in ("!line!") do (
    set total_kb=%%a
)
:: 去掉末尾的 K（如果存在）
set "total_kb=!total_kb:K=!"
:: 转为 GB（十进制）
set /a total_gb=!total_kb! / 1000000
:: 向上匹配到厂商常见档位
set "sizes=16 32 64 128 256 512 1024 2048"
for %%s in (!sizes!) do (
    if !total_gb! LEQ %%s (
        set rom_size=%%s
        goto show
    )
)
:show
echo ROM大小: !rom_size!G
for /f "delims=" %%A in ('adb shell getprop ro.serialno') do echo SN号: %%A
for /f "delims=" %%A in ('adb shell getprop ro.boot.hardware.sku') do (
	if not %%A=="" ( echo SKU: %%A ) else ( echo SKU: Unknow )
)
for /f "tokens=2 delims=:" %%A in ('adb shell dumpsys SurfaceFlinger ^| grep refresh-rate') do echo 刷新率: %%A
for /f "tokens=3 delims=: " %%A in ('adb shell wm size') do echo 分辨率：%%A
for /f "delims=" %%A in ('adb shell settings get system screen_brightness') do echo 亮度: %%A
for /f "delims=" %%A in ('adb shell getprop ro.build.id') do echo 版本号: %%A
for /f "delims=" %%A in ('ro.vendor.soc.model.external_name') do (
	if not %%A=="" ( echo 平台扩展名: %%A )
)

exit /b

:keyword
echo "查看唤醒锁和唤醒原因"
echo "All kernel wake locks|All partial wake locks|All wakeup reasons|All screen wake reasons"
echo "查看系统是否待机"
echo "suspend entry|suspend exit|26M_off_pct"
echo "查看系统待机后唤醒原因"
echo "wakeup_reason|wakeup alarm|Resume caused by|suspend wake up by|Pending Wakeup Sources|active wakeup source"
echo "查看NTC温度"
echo adb shell "i=0 ; while [[ $i -lt 50 ]] ; do (type=`cat /sys/class/thermal/thermal_zone$i/type` ; temp=`cat /sys/class/thermal/thermal_zone$i/temp` ; echo "$i $type : $temp"); i=$((i+1));done"
echo "温升分析"
echo "DexOptimizer|ThermalInfo:|thermal_core|thermal IRQ|throttling|mmi_thermal_ratio|Apply thermal policy:|libPowerHal:"
echo "others"
echo "screen_toggled"
exit /b