@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for android_all.bat
:: Usage: ad [command] [args...]
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

set "cmd=%~1"
set "param1=%~2"
set "param2=%~3"

if "%cmd%"=="" goto show_help
if /i "%cmd%"=="-h" goto show_help
if /i "%cmd%"=="help" goto show_help

call %INIT_BAT% %~dp0
:: 调用基础脚本检查ADB和设备（使用完整路径，传入当前子命令）
call "%ADB_CHECK_BAT%" "%cmd%"
if %ERRORLEVEL% neq 0 (
    echo [错误]: 基础检测失败，退出操作。
    exit /b %ERRORLEVEL%
)

:: 创建Android的out目录
if not exist "%MODULE_OUT_DIR%" mkdir "%MODULE_OUT_DIR%"
if /i "%cmd%"=="top" goto top_activity
if /i "%cmd%"=="ss" goto screen_shot
if /i "%cmd%"=="sr" goto screen_record
if /i "%cmd%"=="kill" goto kill_process
if /i "%cmd%"=="bugreport" goto bugreport
if /i "%cmd%"=="clear" goto clear_log
if /i "%cmd%"=="dev" goto developer
if /i "%cmd%"=="di" goto device_info
if /i "%cmd%"=="search" goto android_search
if /i "%cmd%"=="monkey" goto monkey
if /i "%cmd%"=="enable" goto package_toggle
if /i "%cmd%"=="disable" goto package_toggle
if /i "%cmd%"=="dump" goto dump
if /i "%cmd%"=="rr" goto refresh_rate
if /i "%cmd%"=="skip" goto skip_wizard
if /i "%cmd%"=="install" goto install_apk
if /i "%cmd%"=="shell" goto shells
if /i "%cmd%"=="adbd" goto adb_helper

echo Unknown command: %cmd%
goto show_help

:show_help
echo.
echo Usage: ad [command] [args...]
echo.
echo Available commands:
echo   top                      - Show current Activity / Focus
echo   ss                       - Take screenshot and save/open
echo   sr                       - Record screen and pull to local
echo   kill [process_name]      - Kill target process by name
echo   bugreport                - Capture/Extract bugreport log
echo   clear                    - Clear logcat and dmesg logs
echo   dev [on/off]             - Toggle developer touches / pointer location
echo   di                       - Show device hardware and system info
echo   search [keyword]         - Search Settings and Properties
echo   monkey [pkg/kill/num]    - Run or stop Monkey test
echo   enable/disable [pkg]     - Enable or disable package
echo   dump [service] [params]  - Dump system service state to OUT dir
echo   rr [on/off]              - Set or query refresh rate
echo   skip                     - Skip setup wizard
echo   install                  - Install perf / thermal / power apk tools
echo   adbd [restart/root...]   - ADB helper / status configuration
echo   -h                       - Show help info (alias: help)
echo.
echo Examples:
echo   ad top
echo   ad dev on
echo   ad rr 120
echo.
exit /b 0

:top_activity
    adb shell dumpsys window | grep mCurrentFocus
    exit /b 0

:bugreport
    call "%SCRIPT_DIR%android_bugreport.bat" %~2
    exit /b 0

:adb_helper
    call "%SCRIPT_DIR%android_adb_helper.bat" %~2
    exit /b 0

:clear_log
    adb root
    adb shell "logcat -b all -c; dmesg -C"
    echo 系统 log 清理完成
    exit /b 0

:screen_shot
    set "shot_file=screenshot_%FORMAT_TIME%.png"
    adb shell screencap -p /sdcard/%shot_file%
    adb pull /sdcard/%shot_file% "%MODULE_OUT_DIR%"
    adb shell "rm -rf /sdcard/%shot_file%"
    start "" "%MODULE_OUT_DIR%\%shot_file%"
    exit /b 0

:screen_record
    call "%SCRIPT_DIR%android_screen_record.bat" %~2
    exit /b %ERRORLEVEL%

:kill_process
    if "%~2"=="" (
        echo [错误]: 请指定需要 kill 的进程关键字。
        exit /b 1
    )
    adb shell "ps -A | grep %~2"
    adb shell "kill -9 $(ps -A | grep %~2 | grep -v grep | awk '{print $2}')"
    adb shell "ps -A | grep %~2"
    exit /b 0

:developer
    if "%~2"=="" (
        echo 用法: ad dev [on/off]
        exit /b 1
    )
    if /i "%~2"=="on" (
        adb shell settings put system show_touches 1
        adb shell settings put system pointer_location 1
        adb shell settings put secure clock_seconds 1
        echo 开发者调试辅助（触摸点/指针/时钟秒数）已开启。
    )
    if /i "%~2"=="off" (
        adb shell settings put system show_touches 0
        adb shell settings put system pointer_location 0
        adb shell settings put secure clock_seconds 0
        echo 开发者调试辅助（触摸点/指针/时钟秒数）已关闭。
    )
    exit /b 0

:device_info
    set "SH_SCRIPT=%SCRIPT_DIR%android_device_info.sh"
    adb shell "sh -s" < "%SH_SCRIPT%"
    exit /b 0

:android_search
    set "SH_SCRIPT=%SCRIPT_DIR%android_search.sh"
    adb shell "sh -s %param1%" < "%SH_SCRIPT%"
    exit /b 0

:monkey
if "%~2"=="" (
    adb shell monkey --throttle 200 --ignore-crashes --ignore-timeouts --ignore-security-exceptions --monitor-native-crashes -v -v -v 1000000
    exit /b 0
)
set "pkg_prefix=%~2"
if "%pkg_prefix:~0,3%"=="com" (
    adb shell monkey -p %~2 --throttle 200 --ignore-crashes --ignore-timeouts --ignore-security-exceptions --monitor-native-crashes -v -v -v 1000000
)
if /i "%~2"=="kill" (
    for /f "delims=" %%p in ('adb shell pidof com.android.commands.monkey') do (
        adb shell kill -9 %%p
    )
)
exit /b 0

:package_toggle
    set "SH_SCRIPT=%SCRIPT_DIR%android_package_toggle.sh"
    adb shell "sh -s %cmd% %param1%" < "%SH_SCRIPT%"
    exit /b 0

:refresh_rate
    set "SH_SCRIPT=%SCRIPT_DIR%android_refresh_rate.sh"
    adb shell "sh -s %cmd% %param1%" < "%SH_SCRIPT%"
    exit /b 0

:skip_wizard
    adb shell settings put global device_provisioned 1
    adb shell settings put secure user_setup_complete 1
    adb reboot
    echo 如果开机向导没有跳过，可从左上角开始顺时针点击屏幕四个角
    exit /b 0

:install_apk
    call "%SCRIPT_DIR%android_install.bat" %param1%
    exit /b 0

:shells
    set "DEVICE_SHELL_PATH=%SCRIPT_DIR%android_shells"
    echo DEVICE_SHELL_PATH=%DEVICE_SHELL_PATH%
    adb push "%DEVICE_SHELL_PATH%\." /data/local/tmp/ >nul
    adb shell "chmod +x /data/local/tmp/*.sh"
    adb shell -t "export ENV=/data/local/tmp/alias.sh; exec sh"
    exit /b 0

:dump
    set "service=%~2"
    set "service_param=%~3"
    if "%service%"=="" (
        echo 用法: ad dump [service_name] [optional_params]
        exit /b 1
    )
    if "%service_param%"=="" (
        adb shell dumpsys %service% > "%MODULE_OUT_DIR%\%service%.txt"
    ) else (
        adb shell dumpsys %service% %service_param% > "%MODULE_OUT_DIR%\%service%.txt"
    )
    start "" "%MODULE_OUT_DIR%\%service%.txt"
    exit /b 0