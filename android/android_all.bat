@echo off
:: ============================================================
:: Author: WangQiang
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
if /i "%cmd%"=="dump"      goto :dump
if /i "%cmd%"=="cat"       goto :cat
if /i "%cmd%"=="ss"        goto :screen_shot
if /i "%cmd%"=="sr"        goto :screen_record
if /i "%cmd%"=="kill"      goto :kill_process
if /i "%cmd%"=="bugreport" goto :bugreport
if /i "%cmd%"=="clear"     goto :clear_log
if /i "%cmd%"=="dev"       goto :developer
if /i "%cmd%"=="di"        goto :device_info
if /i "%cmd%"=="device"    goto :device_info
if /i "%cmd%"=="search"    goto :android_search
if /i "%cmd%"=="monkey"    goto :monkey
if /i "%cmd%"=="enable"    goto :package_toggle
if /i "%cmd%"=="disable"   goto :package_toggle
if /i "%cmd%"=="rr"        goto :refresh_rate
if /i "%cmd%"=="skip"      goto :skip_wizard
if /i "%cmd%"=="install"   goto :install_apk
if /i "%cmd%"=="shell"     goto :shells
if /i "%cmd%"=="adbd"      goto :adb_helper
if /i "%cmd%"=="qs"        goto :quick_info
if /i "%cmd%"=="watch"     goto :watch_changes
if /i "%cmd%"=="bind"      goto :bind
if /i "%cmd%"=="st"        goto :sync_time

echo [ERROR] Unknown command: %cmd%
goto :usage

:usage
echo.
echo Usage: ad [command] [args...]
echo.
echo Available commands:
echo   bind [serial]            - Bind device ro.serialno (set ANDROID_SERIAL ^& title)
echo   ss                       - Take screenshot and save/open
echo   sr                       - Record screen and pull to local
echo   kill [process_name]      - Kill target process by name
echo   bugreport [tag]          - Capture/Extract bugreport log
echo   clear                    - Clear logcat and dmesg logs
echo   dev [on/off]             - Toggle developer touches / pointer location
echo   di / device [category]   - Show device info (all/hw/soc/sys/ram/rom/display/battery/net)
echo   search [keyword]         - Search Settings and Properties
echo   watch [interval]         - Watch Settings, getprop, audio volume ^& status
echo   monkey [pkg/kill/num]    - Run or stop Monkey test
echo   enable/disable [pkg]     - Enable or disable package
echo   dump [service] [params]  - Dump system service to OUT dir
echo   cat [topic]              - Show info on screen (top/wl)
echo   rr [on/off]              - Set or query refresh rate
echo   skip                     - Skip setup wizard
echo   install [toolname]       - Install perf / thermal / power apk tools
echo   adbd [category/keyword]  - ADB helper command dictionary
echo   qs [category]            - Quick raw commands ^& log keywords (log/therm/perf/power/sys/all)
echo   st [timze zone]          - sync pc time to device via adb
echo   -h / help                - Show help info
echo.
echo Examples:
echo   ad dump sf
echo   ad cat top
echo   ad bind
echo   ad device
echo   ad device hw
echo   ad device soc
echo   ad dev on
echo   ad watch
echo   ad watch 1
echo   ad qs log
echo   ad qs therm
echo   ad rr 120
echo   ad ss
echo.
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
    adb shell "sh -s %param1%" < "%SH_SCRIPT%"
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
    echo [OK] Setup wizard skipped, device rebooting.
    adb reboot
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
    set "SH_SCRIPT=%SCRIPT_DIR%android_dump.sh"
    set "PARSE_SCRIPT=%SCRIPT_DIR%android_dump_parse.py"
    set "SERVICE=%param1%"

    :: 无 service 时透显 usage（由 android_dump.sh 处理）
    if "%SERVICE%"=="" (
        adb shell "sh -s help" < "%SH_SCRIPT%"
        exit /b %ERRORLEVEL%
    )

    set "DUMP_OUT_FILE=%MODULE_OUT_DIR%\%SERVICE%_%FORMAT_TIME%.txt"

    adb shell "sh -s %*" < "%SH_SCRIPT%" > "%DUMP_OUT_FILE%"
    if not "%ERRORLEVEL%"=="0" (
        echo [ERROR] dump failed: %SERVICE%
        if exist "%DUMP_OUT_FILE%" del /f /q "%DUMP_OUT_FILE%"
        exit /b 1
    )

    if exist "%DUMP_OUT_FILE%" (
        echo [OK] Dumpsys saved: %DUMP_OUT_FILE%
        start "" "%DUMP_OUT_FILE%"
        if exist "%PARSE_SCRIPT%" (
            where python >nul 2>&1 && python "%PARSE_SCRIPT%" "%SERVICE%" "%DUMP_OUT_FILE%"
        )
    )
    exit /b 0

:cat
    set "SH_SCRIPT=%SCRIPT_DIR%android_cat.sh"
    if not exist "%SH_SCRIPT%" (
        echo [ERROR] Script not found: %SH_SCRIPT%
        exit /b 1
    )
    adb shell "sh -s %param1%" < "%SH_SCRIPT%"
    exit /b %ERRORLEVEL%

:quick_info
    set "SH_SCRIPT=%SCRIPT_DIR%android_quick_info.sh"
    if not exist "%SH_SCRIPT%" (
        echo [ERROR] Script not found: %SH_SCRIPT%
        exit /b 1
    )
    where sh >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        sh "%SH_SCRIPT%" %param1% %param2%
    ) else (
        adb shell "sh -s %param1% %param2%" < "%SH_SCRIPT%"
    )
    exit /b %ERRORLEVEL%

:watch_changes
    set "SH_SCRIPT=%SCRIPT_DIR%android_watch.sh"
    if not exist "%SH_SCRIPT%" (
        echo [ERROR] Script not found: %SH_SCRIPT%
        exit /b 1
    )
    adb push "%SH_SCRIPT%" /data/local/tmp/android_watch.sh >nul 2>&1
    adb shell "chmod +x /data/local/tmp/android_watch.sh" >nul 2>&1

    rem 提取除第一个参数(watch)之外的所有模块/间隔参数
    for /f "tokens=1*" %%a in ("%*") do set "WATCH_ARGS=%%b"

    rem 未指定任何模块/间隔时，默认显示帮助
    if not defined WATCH_ARGS set "WATCH_ARGS=help"

    rem -t 强制分配伪终端 (PTY)：Ctrl+C 时 SIGINT 能即时透传到手机端，并保留 ANSI 彩色
    adb shell -t "sh /data/local/tmp/android_watch.sh %WATCH_ARGS%"

    rem 兜底清理：杀掉遗留实例并删除临时文件（正常情况下由手机端 trap 完成）
    adb shell "if [ -f /data/local/tmp/.ad_watch.pid ]; then kill -9 $(cat /data/local/tmp/.ad_watch.pid 2>/dev/null) 2>/dev/null; fi; rm -f /data/local/tmp/.ad_watch.pid /data/local/tmp/.ad_watch_prev_* /data/local/tmp/.ad_watch_curr_*" >nul 2>&1
    exit /b 0

:bind
    set "SERIAL="
    if not "%param1%"=="" (
        for /f "tokens=*" %%a in ('adb -s %param1% shell getprop ro.serialno 2^>nul') do set "SERIAL=%%a"
        if "%SERIAL%"=="" set "SERIAL=%param1%"
    ) else (
        for /f "tokens=*" %%a in ('adb shell getprop ro.serialno 2^>nul') do set "SERIAL=%%a"
    )
    if "%SERIAL%"=="" (
        echo [ERROR] Failed to get ro.serialno.
        adb devices
        exit /b 1
    )
    title %SERIAL%
    echo [OK] ANDROID_SERIAL=%SERIAL%
    endlocal & set "ANDROID_SERIAL=%SERIAL%"
    exit /b 0

:sync_time
    call "%SCRIPT_DIR%android_sync_time.bat" %param1%
    exit /b 0
