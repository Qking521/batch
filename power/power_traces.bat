@echo off
chcp 65001 >nul
:: ============================================================
:: Author: Antigravity Pair Program
:: Date:   2026-08-25
:: Desc:   Perfetto Trace 追踪与 Bugreport 分析辅助
:: Usage:  power trace <ui|ui-enhance|sh> [bugreport_path]
:: ============================================================
setlocal EnableDelayedExpansion

set "cmd=%~1"
set "param1=%~2"
set "param2=%~3"

:: 1. 优先判断帮助
if "%cmd%"==""        goto :usage
if /i "%cmd%"=="-h"   goto :usage
if /i "%cmd%"=="help" goto :usage

:: 2. 初始化环境
call :evn_init
if errorlevel 1 exit /b 1

if /i "%cmd%"=="ui"         goto :do_ui
if /i "%cmd%"=="ui-enhance" goto :do_ui_enhance
if /i "%cmd%"=="sh"         goto :do_shell

echo [ERROR] Unknown command: %cmd%
goto :usage

:usage
echo.
echo Usage: power trace ^<ui^|ui-enhance^|sh^> [bugreport_path]
echo.
echo Commands:
echo   ui [bugreport_path]          - Open target / latest bugreport zip via Perfetto Web UI
echo   ui-enhance [bugreport_path]  - Launch local trace_processor_shell acceleration and open in UI
echo   sh [bugreport_path]          - Launch trace_processor_shell interactive SQL CLI
echo   help / -h                    - Show this help info
echo.
echo Examples:
echo   power trace ui
echo   power trace ui-enhance
echo   power trace sh "OUT\android\bugreport_0825-1000.zip"
echo.
exit /b 0

:evn_init
    for /f "delims= " %%a in ('adb shell getprop ro.product.board 2^>nul') do set "model=%%a"
    if "!model!"=="" set "model=device"
    set "TRACE_FILE=!model!_%format_time%.perfetto"
    set "OUT_TRACE_FILE=%MODULE_OUT_DIR%\!TRACE_FILE!"

    set "GOOGLE_OPEN_TRACE_FILE=%SCRIPT_DIR%..\performance\perfetto_tools\open_trace_in_ui"
    set "TRACE_PROCESSOR_SHELL=%SCRIPT_DIR%..\performance\perfetto_tools\trace_processor_shell.exe"
    set "GOOGLE_RECORD_TRACE_FILE=%SCRIPT_DIR%..\performance\perfetto_tools\record_android_trace"
    set "SQL_DIR=%SCRIPT_DIR%power_sql"

    if not exist "%TRACE_PROCESSOR_SHELL%" (
        echo [WARN] trace_processor_shell.exe not found: %TRACE_PROCESSOR_SHELL%
    )
    exit /b 0

:find_target_bugreport
    set "CUSTOM_PATH=%~1"
    set "TARGET_BUGREPORT="

    if not "%CUSTOM_PATH%"=="" (
        if exist "%CUSTOM_PATH%" (
            set "TARGET_BUGREPORT=%CUSTOM_PATH%"
            echo [INFO] Using custom Bugreport: %TARGET_BUGREPORT%
            exit /b 0
        ) else (
            echo [WARN] Path does not exist: %CUSTOM_PATH%, searching latest file...
        )
    )

    set "TARGET_DIR=%ROOT_OUT_DIR%android"
    if not exist "%TARGET_DIR%" (
        echo [ERROR] Target directory not found: %TARGET_DIR%
        exit /b 1
    )

    for /f "delims=" %%F in ('dir /b /a-d /o-d "%TARGET_DIR%\bugreport_*.zip" 2^>nul') do (
        if not defined TARGET_BUGREPORT set "TARGET_BUGREPORT=%TARGET_DIR%\%%F"
    )

    if "%TARGET_BUGREPORT%"=="" (
        echo [ERROR] No bugreport_*.zip found in %TARGET_DIR%
        exit /b 1
    )
    echo [INFO] Using latest Bugreport: %TARGET_BUGREPORT%
    exit /b 0

:do_ui
    call :find_target_bugreport "%param1%"
    if errorlevel 1 exit /b 1

    echo [INFO] Starting Perfetto UI...
    python "%GOOGLE_OPEN_TRACE_FILE%" -i "%TARGET_BUGREPORT%"
    exit /b %ERRORLEVEL%

:do_ui_enhance
    call :find_target_bugreport "%param1%"
    if errorlevel 1 exit /b 1

    echo [INFO] Starting local Trace Processor Server...
    start "Trace Processor Server" "%TRACE_PROCESSOR_SHELL%" --httpd "%TARGET_BUGREPORT%"
    timeout /t 2 /nobreak >nul
    python "%GOOGLE_OPEN_TRACE_FILE%" -i "%TARGET_BUGREPORT%"
    exit /b %ERRORLEVEL%

:do_shell
    call :find_target_bugreport "%param1%"
    if errorlevel 1 exit /b 1

    echo [INFO] Starting trace_processor_shell interactive shell...
    pushd "%SQL_DIR%"
    "%TRACE_PROCESSOR_SHELL%" -i "%TARGET_BUGREPORT%"
    popd
    exit /b 0
