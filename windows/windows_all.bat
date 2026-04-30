@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

call %INIT_BAT% %~dp0

if "%1"=="" goto show_help
if /i "%1"=="attach" goto usbip
if /i "%1"=="aattach" goto usbip
if /i "%1"=="detach" goto usbip

:show_help
echo Available commands:
echo   attach busid
echo   aattach busid
echo   detach busid
echo.
exit /b

:usbip
call %SCRIPT_DIR%windows_usbipd.bat %1 %2
exit /b