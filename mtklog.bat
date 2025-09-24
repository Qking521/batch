@echo off
setlocal

cd %~dp0%
call base_time.bat
echo ftime = %ftime%

if "%1"=="" goto show_help
if /i "%1"=="-h" goto show_help
if /i "%1"=="help" goto show_help
if /i "%1"=="ui" goto open_ui
if /i "%1"=="open" goto open_log
if /i "%1"=="start" goto open_log
if /i "%1"=="close" goto close_log
if /i "%1"=="stop" goto close_log
if /i "%1"=="clear" goto clear_log
if /i "%1"=="pull" goto pull_log
if /i "%1"=="new" goto new_log

echo Unknown command: %1
echo Use "mtklog -h" for help
exit /b

:show_help
echo.
echo MTK Log Management Tool
echo =======================
echo.
echo Usage: mtklog [command]
echo.
echo Available commands:
echo   ui      - Open log UI interface
echo   open    - Start log recording (alias: start^)
echo   close   - Stop log recording (alias: stop^)
echo   clear   - Clear all logs
echo   pull    - Stop and pull log files to current directory
echo   new     - Restart (stop-clear-start^)
echo   -h      - Show help (alias: help^)
echo.
echo Examples:
echo   mtklog ui
echo   mtklog start
echo   mtklog pull
echo.
exit /b

:open_ui
echo Opening log UI interface...
adb shell am start -n com.debug.loggerui/com.debug.loggerui.MainActivity
echo Log UI opened
exit /b

:open_log
echo Starting log recording...
adb shell am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name start --ei cmd_target -1 -n com.debug.loggerui/.framework.LogReceiver
echo Log recording started
exit /b

:close_log
echo Stopping log recording...
adb shell am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name stop --ei cmd_target -1 -n com.debug.loggerui/.framework.LogReceiver
echo Log recording stopped
exit /b

:clear_log
echo Clearing all logs...
adb shell am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name clear_all_logs -n com.debug.loggerui/.framework.LogReceiver
echo Logs cleared
exit /b

:pull_log
echo Stopping and pulling log files...
echo Step 1: Stop logging
adb shell am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name stop --ei cmd_target -1 -n com.debug.loggerui/.framework.LogReceiver
echo Step 2: Create archive
adb shell "rm -rf /data/debuglogger/debuglog.tar.gz"
adb shell "cd /data/debuglogger/ && tar -cvzf debuglog.tar.gz *"
echo Step 3: Pull to local
adb pull /data/debuglogger/debuglog.tar.gz .
if not exist mtklog (
	mkdir  mtklog\mtklog_%ftime%
)
adb pull /data/debuglogger/ mtklog\mtklog_%ftime%
echo Step 4: Open directory
start "" mtklog\mtklog_%ftime%
echo Log files pulled to current directory
exit /b

:new_log
echo Restarting log recording...
echo Step 1: Stop logging
adb shell am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name stop --ei cmd_target -1 -n com.debug.loggerui/.framework.LogReceiver
echo Step 2: Clear logs
adb shell am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name clear_all_logs -n com.debug.loggerui/.framework.LogReceiver
adb shell "logcat -b all -c; dmesg -C"
timeout /t 3 /nobreak >nul
echo Step 3: Start new logging
adb shell am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name start --ei cmd_target -1 -n com.debug.loggerui/.framework.LogReceiver
echo New log recording started
exit /b