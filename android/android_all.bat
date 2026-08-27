@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date:   2026-08-25
:: Desc:   Android universal command dispatcher
:: Usage:  ad <command> [args...]
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
if /i "%cmd%"=="top"       goto :top_activity
if /i "%cmd%"=="ss"        goto :screen_shot
if /i "%cmd%"=="sr"        goto :screen_record
if /i "%cmd%"=="kill"      goto :kill_process
if /i "%cmd%"=="bugreport" goto :bugreport
if /i "%cmd%"=="clear"     goto :clear_log
if /i "%cmd%"=="dev"       goto :developer
if /i "%cmd%"=="di"        goto :device_info
if /i "%cmd%"=="search"    goto :android_search
if /i "%cmd%"=="monkey"    goto :monkey
if /i "%cmd%"=="enable"    goto :package_toggle
if /i "%cmd%"=="disable"   goto :package_toggle
if /i "%cmd%"=="dump"      goto :dump
if /i "%cmd%"=="rr"        goto :refresh_rate
if /i "%cmd%"=="skip"      goto :skip_wizard
if /i "%cmd%"=="install"   goto :install_apk
if /i "%cmd%"=="shell"     goto :shells
if /i "%cmd%"=="adbd"      goto :adb_helper
if /i "%cmd%"=="key"       goto :keyword
if /i "%cmd%"=="watch"     goto :watch_changes

echo [ERROR] Unknown command: %cmd%
goto :usage

:usage
echo.
echo Usage: ad [command] [args...]
echo.
echo Available commands:
echo   top                      - Show current Activity / Focus
echo   ss                       - Take screenshot and save/open
echo   sr                       - Record screen and pull to local
echo   kill [process_name]      - Kill target process by name
echo   bugreport [tag]          - Capture/Extract bugreport log
echo   clear                    - Clear logcat and dmesg logs
echo   dev [on/off]             - Toggle developer touches / pointer location
echo   di                       - Show device hardware and system info
echo   search [keyword]         - Search Settings and Properties
echo   watch [interval]         - Watch Settings, getprop, audio volume & status
echo   monkey [pkg/kill/num]    - Run or stop Monkey test
echo   enable/disable [pkg]     - Enable or disable package
echo   dump [service] [params]  - Dump system service state to OUT dir
echo   rr [on/off]              - Set or query refresh rate
echo   skip                     - Skip setup wizard
echo   install [toolname]       - Install perf / thermal / power apk tools
echo   adbd [category/keyword]  - ADB helper command dictionary
echo   key                      - List common power/thermal log keywords
echo   -h / help                - Show help info
echo.
echo Examples:
echo   ad top
echo   ad dev on
echo   ad watch
echo   ad watch 1
echo   ad rr 120
echo   ad ss
echo.
exit /b 0

:top_activity
    adb shell dumpsys window | grep mCurrentFocus
    exit /b 0

:bugreport
    call "%SCRIPT_DIR%android_bugreport.bat" %param1%
    exit /b %ERRORLEVEL%

:adb_helper
    call "%SCRIPT_DIR%android_adb_helper.bat" %param1%
    exit /b %ERRORLEVEL%

:clear_log
    adb root
    adb shell "logcat -b all -c; dmesg -C"
    echo [OK] Logcat and dmesg cleared.
    exit /b 0

:screen_shot
    set "shot_file=screenshot_%FORMAT_TIME%.png"
    adb shell screencap -p "/sdcard/%shot_file%"
    adb pull "/sdcard/%shot_file%" "%MODULE_OUT_DIR%" >nul 2>&1
    adb shell "rm -f /sdcard/%shot_file%"
    if exist "%MODULE_OUT_DIR%\%shot_file%" (
        echo [OK] Screenshot saved: %MODULE_OUT_DIR%\%shot_file%
        start "" "%MODULE_OUT_DIR%\%shot_file%"
    ) else (
        echo [ERROR] Failed to save screenshot.
        exit /b 1
    )
    exit /b 0

:screen_record
    call "%SCRIPT_DIR%android_screen_record.bat" %param1%
    exit /b %ERRORLEVEL%

:kill_process
    if "%param1%"=="" (
        echo [ERROR] Please specify process name keyword.
        exit /b 1
    )
    adb shell "ps -A | grep %param1%"
    adb shell "kill -9 $(ps -A | grep %param1% | grep -v grep | awk '{print $2}')"
    adb shell "ps -A | grep %param1%"
    exit /b 0

:developer
    if "%param1%"=="" (
        echo Usage: ad dev [on/off]
        exit /b 1
    )
    if /i "%param1%"=="on" (
        adb shell settings put system show_touches 1
        adb shell settings put system pointer_location 1
        adb shell settings put secure clock_seconds 1
        echo [OK] Developer touches / pointer location / seconds enabled.
    )
    if /i "%param1%"=="off" (
        adb shell settings put system show_touches 0
        adb shell settings put system pointer_location 0
        adb shell settings put secure clock_seconds 0
        echo [OK] Developer touches / pointer location / seconds disabled.
    )
    exit /b 0

:device_info
    set "SH_SCRIPT=%SCRIPT_DIR%android_device_info.sh"
    if not exist "%SH_SCRIPT%" (
        echo [ERROR] Script not found: %SH_SCRIPT%
        exit /b 1
    )
    adb shell "sh -s" < "%SH_SCRIPT%"
    exit /b %ERRORLEVEL%

:android_search
    set "SH_SCRIPT=%SCRIPT_DIR%android_search.sh"
    if not exist "%SH_SCRIPT%" (
        echo [ERROR] Script not found: %SH_SCRIPT%
        exit /b 1
    )
    adb shell "sh -s %param1%" < "%SH_SCRIPT%"
    exit /b %ERRORLEVEL%

:monkey
if "%param1%"=="" (
    adb shell monkey --throttle 200 --ignore-crashes --ignore-timeouts --ignore-security-exceptions --monitor-native-crashes -v -v -v 1000000
    exit /b 0
)
if /i "%param1%"=="kill" (
    for /f "delims=" %%p in ('adb shell pidof com.android.commands.monkey 2^>nul') do (
        adb shell kill -9 %%p
    )
    echo [OK] Monkey stopped.
    exit /b 0
)
set "pkg_prefix=%param1%"
if "%pkg_prefix:~0,3%"=="com" (
    adb shell monkey -p %param1% --throttle 200 --ignore-crashes --ignore-timeouts --ignore-security-exceptions --monitor-native-crashes -v -v -v 1000000
) else (
    echo [ERROR] Invalid package name: %param1%
    exit /b 1
)
exit /b 0

:package_toggle
    set "SH_SCRIPT=%SCRIPT_DIR%android_package_toggle.sh"
    if not exist "%SH_SCRIPT%" (
        echo [ERROR] Script not found: %SH_SCRIPT%
        exit /b 1
    )
    adb shell "sh -s %cmd% %param1%" < "%SH_SCRIPT%"
    exit /b %ERRORLEVEL%

:refresh_rate
    set "SH_SCRIPT=%SCRIPT_DIR%android_refresh_rate.sh"
    if not exist "%SH_SCRIPT%" (
        echo [ERROR] Script not found: %SH_SCRIPT%
        exit /b 1
    )
    adb shell "sh -s %cmd% %param1%" < "%SH_SCRIPT%"
    exit /b %ERRORLEVEL%

:skip_wizard
    adb shell settings put global device_provisioned 1
    adb shell settings put secure user_setup_complete 1
    adb reboot
    echo [OK] Setup wizard skipped, device rebooting.
    exit /b 0

:install_apk
    call "%SCRIPT_DIR%android_install.bat" %param1%
    exit /b %ERRORLEVEL%

:shells
    set "DEVICE_SHELL_PATH=%SCRIPT_DIR%android_shells"
    adb push "%DEVICE_SHELL_PATH%\." /data/local/tmp/ >nul
    adb shell "chmod +x /data/local/tmp/*.sh"
    :: -t: 强制分配伪终端 (PTY)，支持交互式终端环境与 alias 环境变量
    adb shell -t "export ENV=/data/local/tmp/alias.sh; exec sh"
    exit /b 0

:dump
    if "%param1%"=="" (
        echo Usage: ad dump [service_name] [optional_params]
        exit /b 1
    )
    if "%param2%"=="" (
        adb shell dumpsys %param1% > "%MODULE_OUT_DIR%\%param1%.txt"
    ) else (
        adb shell dumpsys %param1% %param2% > "%MODULE_OUT_DIR%\%param1%.txt"
    )
    if exist "%MODULE_OUT_DIR%\%param1%.txt" (
        echo [OK] Dumpsys saved: %MODULE_OUT_DIR%\%param1%.txt
        start "" "%MODULE_OUT_DIR%\%param1%.txt"
    )
    exit /b 0

:keyword
echo "查看唤醒锁和唤醒原因"
echo "All kernel wake locks|All partial wake locks|All wakeup reasons|All screen wake reasons"
echo "系统无法suspend"
echo "Pending Wakeup Sources|Wake lock|blocked by|prevent_suspend_time|PM: suspend returned|aborting suspend|active wakeup source"
echo "查看系统待机及唤醒"
echo "suspend entry|suspend exit|suspend wake up by|Resume caused by|caused by IRQ|set alarm :"
echo "系统suspend但子系统仍在工作"
echo "26M_off_pct|AP suspend ratio"
echo "查看NTC温度"
echo adb shell "i=0 ; while [[ $i -lt 80 ]] ; do (type=`cat /sys/class/thermal/thermal_zone$i/type` ; temp=`cat /sys/class/thermal/thermal_zone$i/temp` ; echo \"$i $type : $temp\"); i=$((i+1));done"
echo "温升分析"
echo "DexOptimizer|ThermalInfo:|thermal_core|thermal IRQ|throttling|mmi_thermal_ratio|Apply thermal policy:|libPowerHal:"
echo "其它未分类"
echo "screen_toggled|sys.powerctl|AlarmManager: Adjust deliver|sensorservice"
exit /b 0

:watch_changes
    set "SH_SCRIPT=%SCRIPT_DIR%android_watch.sh"
    if not exist "%SH_SCRIPT%" (
        echo [ERROR] Script not found: %SH_SCRIPT%
        exit /b 1
    )
    adb push "%SH_SCRIPT%" /data/local/tmp/android_watch.sh >nul 2>&1
    adb shell "chmod +x /data/local/tmp/android_watch.sh" >nul 2>&1
    :: -t: 强制为远程命令分配伪终端 (PTY)。
    :: 作用:
    :: 1. 确保在 Windows 终端按 Ctrl+C 时，SIGINT/SIGHUP 中断信号能即时透传至手机端脚本，触发 trap 优雅清理并退出。
    :: 2. 保证终端支持 ANSI 彩色高亮输出。
    adb shell -t "sh /data/local/tmp/android_watch.sh %param1%"
    adb shell "if [ -f /data/local/tmp/.ad_watch.pid ]; then kill -9 $(cat /data/local/tmp/.ad_watch.pid 2>/dev/null) 2>/dev/null; rm -f /data/local/tmp/.ad_watch* 2>/dev/null; fi" >nul 2>&1
    exit /b 0