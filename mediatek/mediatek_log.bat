@echo off
:: ============================================================
:: Author: WangQiang
:: Date: 2026-07-20
:: Description: Optimized script for mtklog.bat
:: ============================================================
chcp 65001 >nul
setlocal EnableDelayedExpansion

set "action=%~2"

if "%action%"=="" goto :usage
if /i "%action%"=="-h" goto :usage
if /i "%action%"=="help" goto :usage

if /i "%action%"=="ui" goto :open_ui
if /i "%action%"=="open" goto :open_log
if /i "%action%"=="start" goto :open_log
if /i "%action%"=="close" goto :close_log
if /i "%action%"=="stop" goto :close_log
if /i "%action%"=="clear" goto :clear_log
if /i "%action%"=="pull" goto :pull_log
if /i "%action%"=="new" goto :new_log

echo [ERROR] Unknown command: %action%
goto :usage

:usage
    echo.
    echo MTK Log Management Tool
    echo =======================
    echo.
    echo Usage: mtklog [command]
    echo.
    echo Available commands:
    echo   ui      - Open log UI interface
    echo   open    - Start log recording (alias: start)
    echo   close   - Stop log recording (alias: stop)
    echo   clear   - Clear all logs
    echo   pull    - Stop and pull log files to OUT directory
    echo   new     - Restart (stop-clear-start)
    echo   help    - Show help (alias: -h)
    echo.
    echo Examples:
    echo   mtk log ui
    echo   mtk log start
    echo   mtk log pull
    echo.
    exit /b 0

:open_ui
    echo Opening log UI interface...
    adb shell am start -n com.debug.loggerui/com.debug.loggerui.MainActivity
    echo Log UI opened
    exit /b 0

:open_log
    echo Starting log recording...
    adb shell am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name start --ei cmd_target -1 -n com.debug.loggerui/.framework.LogReceiver >nul
    for /l %%i in (1,1,6) do (
        for /f "tokens=*" %%p in ('adb shell "getprop vendor.MB.running" 2^>nul') do set "mb_running=%%p"
        for /f "tokens=*" %%p in ('adb shell "getprop vendor.mdlogger.Running" 2^>nul') do set "md_running=%%p"
        if "!mb_running!"=="1" if "!md_running!"=="1" (
            goto :log_started
        )
        timeout /t 1 /nobreak >nul
    )
:log_started
    echo Log recording started
    exit /b 0

:close_log
    echo Stopping log recording...
    adb shell am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name stop --ei cmd_target -1 -n com.debug.loggerui/.framework.LogReceiver
    echo Log recording stopped
    exit /b 0

:clear_log
    echo Clearing all logs...
    adb shell am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name clear_all_logs -n com.debug.loggerui/.framework.LogReceiver
    echo Logs cleared
    exit /b 0

:pull_log
    set "SNAPSHOT_TIME=%FORMAT_TIME%"
    for /f "delims= " %%a in ('adb shell getprop ro.product.board 2^>nul') do set "model=%%a"
    if "%model%"=="" set "model=device"

    set "TARGET_DIR=%MODULE_OUT_DIR%\%model%_mtklog_%SNAPSHOT_TIME%"
    if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%" 2>nul

    echo ============================================================
    echo [INFO] Stopping and pulling MTK log...
    echo ============================================================

    rem Step 1: Send stop broadcast
    echo [INFO] Step 1/4: Stop logging...
    adb shell am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name stop --ei cmd_target -1 -n com.debug.loggerui/.framework.LogReceiver >nul

    rem Step 2: Poll MTK properties until stopped (max 4s)
    echo [INFO] Step 2/4: Waiting for log daemon flush...
    for /l %%i in (1,1,4) do (
        for /f "tokens=*" %%p in ('adb shell "getprop vendor.MB.running" 2^>nul') do set "mb_running=%%p"
        for /f "tokens=*" %%p in ('adb shell "getprop vendor.mdlogger.Running" 2^>nul') do set "md_running=%%p"
        if "!mb_running!"=="0" if "!md_running!"=="0" (
            goto :log_stopped
        )
        timeout /t 1 /nobreak >nul
    )
:log_stopped
    adb shell sync
    echo [INFO] MTK log recording stopped and flushed.

    rem Step 3: Pull core mobilelog first and open directory immediately
    echo [INFO] Step 3/4: Pulling core mobilelog...
    adb pull /data/debuglogger/mobilelog "%TARGET_DIR%" >nul 2>&1

    echo [INFO] Core log pulled. Opening directory: %TARGET_DIR%
    start "" "%TARGET_DIR%"

    rem Step 4: Pull full logs (enumerate subdirs only, skip root-level files like file_tree.txt)
    echo [INFO] Step 4/4: Pulling full logs and creating archive...
    for /f "tokens=*" %%d in ('adb shell "find /data/debuglogger -maxdepth 1 -mindepth 1 -type d 2>/dev/null"') do (
        adb pull "%%d" "%TARGET_DIR%"
    )

    set "SEVEN_ZIP="
    where 7z >nul 2>&1
    if %errorlevel% equ 0 set "SEVEN_ZIP=7z"
    if not defined SEVEN_ZIP (
        if exist "C:\Program Files\7-Zip\7z.exe" set "SEVEN_ZIP=C:\Program Files\7-Zip\7z.exe"
    )

    if defined SEVEN_ZIP (
        echo [INFO] Compressing full logs on PC using 7-Zip...
        "%SEVEN_ZIP%" a -t7z "%MODULE_OUT_DIR%\%model%_mtklog_%SNAPSHOT_TIME%.7z" "%TARGET_DIR%" -mx=5 >nul 2>&1
        if !errorlevel! equ 0 (
            echo [OK] 7-Zip archive created: %MODULE_OUT_DIR%\%model%_mtklog_%SNAPSHOT_TIME%.7z
        )
    ) else (
        echo [INFO] PC 7-Zip not found, creating archive on device...
        adb shell "rm -f /data/debuglogger/*_debuglog.tar.gz /data/debuglogger/debuglog.tar.gz" >nul 2>&1
        adb shell "cd /data/debuglogger/ && tar -czf %model%_debuglog.tar.gz *" >nul 2>&1
        adb pull "/data/debuglogger/%model%_debuglog.tar.gz" "%MODULE_OUT_DIR%" >nul 2>&1
        adb shell "rm -f /data/debuglogger/%model%_debuglog.tar.gz" >nul 2>&1
        echo [OK] Tar archive created: %MODULE_OUT_DIR%\%model%_debuglog.tar.gz
    )

    echo [OK] All logs pull and backup completed: %TARGET_DIR%
    exit /b 0

:new_log
    echo Restarting log recording...
    echo Step 1: Stop logging
    adb shell am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name stop --ei cmd_target -1 -n com.debug.loggerui/.framework.LogReceiver
    echo Step 2: Clear logs
    adb shell am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name clear_all_logs -n com.debug.loggerui/.framework.LogReceiver
    adb shell "logcat -b all -c; dmesg -C"
    timeout /t 3 /nobreak >nul
    echo Step 3: Start new logging
    ::cmd_target的1/2/4/16，分别代表MobileLog/ModemLog/NetworkLog/GPSLog，如果要所有就改成它们的和23
    adb shell am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name start --ei cmd_target 1 -n com.debug.loggerui/.framework.LogReceiver
    echo New log recording started
    exit /b 0