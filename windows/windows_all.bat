@echo off
:: ============================================================
:: Author: WangQiang
:: Date: 2026-07-20
:: Description: Optimized script for windows_all.bat
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

call %INIT_BAT% %~dp0
if not exist %MODULE_OUT_DIR% mkdir %MODULE_OUT_DIR%

set "cmd=%~1"
set "param1=%~2"
set "param2=%~3"

if /i "%cmd%"=="" goto show_help
if /i "%cmd%"=="usbip" goto usbip
if /i "%cmd%"=="cli" goto command_line
if /i "%cmd%"=="de" goto decompile_apk

:show_help
echo Available commands:
echo   usbip                - list/attach/auto attach/detach/clear 
echo   unlock               - unlock screen, keep windows screen on 
echo   cli                  - start AI command client,such as Antigravity 
echo   de ^<apk file^>      - Decompile apk
echo.
exit /b

:usbip
    call %SCRIPT_DIR%windows_usbipd.bat %2 %3
    exit /b

:command_line
    call %SCRIPT_DIR%windows_cli.bat %*
    exit /b

:unlock
    call %SCRIPT_DIR%windows_unlock_screen.bat %*
    exit /b

:decompile_apk
    call %SCRIPT_DIR%windows_decompile.bat %*
    exit /b