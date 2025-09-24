@echo off
setlocal EnableDelayedExpansion

:: Set code page to GBK for Chinese support
chcp 65001  >nul

:: 获取当前脚本所在目录
set "SCRIPT_DIR=%~dp0"

:: 先调用基础脚本检查ADB和设备（使用完整路径）
call "%SCRIPT_DIR%adb_check.bat"
if %ERRORLEVEL% neq 0 (
    echo [错误]: 基础检测失败，退出操作。
    exit /b %ERRORLEVEL%
)

:: Enable Airplane Mode
call :execute_adb "adb shell settings put global airplane_mode_on 1"
call :execute_adb "adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true"

:: Close WI-FI
call :execute_adb "adb shell svc wifi disable"

:: Close BT
call :execute_adb "adb shell svc bluetooth disable"

:: Disable GPS
call :execute_adb "adb shell settings put secure location_mode 0"

:: Disable nfc
call :execute_adb "adb shell svc nfc disable"

:: Disable Auto-Rotate
call :execute_adb "adb shell settings put system accelerometer_rotation 0"

:: Disable Auto-Brightness
call :execute_adb "adb shell settings put system screen_brightness_mode 0"

:: screen time to 30 minutes
call :execute_adb "adb shell settings put system screen_off_timeout 1800000"

echo All commands executed.
echo 请确认modem log关闭
endlocal
goto :eof

:: Function to execute ADB command and print result
:execute_adb
set "cmd=%~1"
:: 检查 cmd 是否为空
if not defined cmd (
    echo ERROR: cmd 变量未定义!
    exit /b 1
)
if "%cmd%"=="" (
    echo ERROR: cmd 变量为空! 请检查参数传递。
    exit /b 1
)

echo Executing: %cmd%
%cmd% >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Result: Command failed with error code: %ERRORLEVEL%
    %cmd% 2>&1 | findstr . >nul && (
        for /f "delims=" %%i in ('%cmd% 2^>^&1') do echo Error output: %%i
    )
)
exit /b

