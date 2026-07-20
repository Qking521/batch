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

:show_help
echo Available commands:
echo   usbip
echo.
exit /b

:usbip
call %SCRIPT_DIR%windows_usbipd.bat %2 %3
exit /b