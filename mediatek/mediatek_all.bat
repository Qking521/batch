@echo off
:: ============================================================
:: Author: WangQiang
:: Date:   2026-09-04
:: Desc:   mediatek operate
:: Usage:  mtk <command> [args...]
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
if /i "%cmd%"=="log"       goto :mediatek_log

echo [ERROR] Unknown command: %cmd%
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
    echo   mtklog ui
    echo   mtklog start
    echo   mtklog pull
    echo.
    exit /b 0

:mediatek_log
    call "%SCRIPT_DIR%mtklog.bat" %*
    exit /b %ERRORLEVEL%
