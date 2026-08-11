@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for windows_all.bat
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

call %INIT_BAT% %~dp0

if "%1"=="" goto show_help
if /i "%1"=="usbip" goto usbip
if /i "%1"=="cli" goto command_line

:show_help
echo Available commands:
echo   usbip         - list/attach/auto attach/detach/clear 
echo   unlock         - list/attach/auto attach/detach/clear 
echo   cli           - start AI command client,such as Antigravity 
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