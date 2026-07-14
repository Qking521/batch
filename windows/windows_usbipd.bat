@echo off
setlocal enabledelayedexpansion
set "action=%1"
set "portid=%2"

echo action: %action%
if /i "%action%"=="list" goto list
if /i "%action%"=="attach" goto attach
if /i "%action%"=="aattach" goto auto_attach
if /i "%action%"=="detach" goto detach
if /i "%action%"=="clear" goto clear
if "%action%"=="" goto show_help
if "%portid%"=="" goto show_help

:show_help
echo.
echo Usage: usbipd command [portid]
echo.
echo Available commands:
echo   list           - List USB devices.
echo   attach         - Attach a USB device to a client.
echo   aattach        - auto Attach a USB device to a client.
echo   detach         - Detach a USB device from a client.
echo   clear          - clear Persisted device info.
echo   -h             - Show help (alias: help).
echo.
echo Examples:
echo   Usage aattach 1-1
echo.
exit /b

REM ================================
REM 标签：list
REM ================================
:list
usbipd list
exit /b

REM ================================
REM 标签：普通 attach
REM ================================
:attach
set BUS=%portid%
if %BUS%=="" (
    goto show_help
)
echo [ATTACH] busid=%BUS%
usbipd bind --busid %BUS%
usbipd attach --wsl --busid %BUS%
echo %BUS% detached
usbipd list
exit /b

REM ================================
REM 标签：auto-attach
REM ================================
:auto_attach
set BUS=%portid%
if %BUS%=="" (
    goto show_help
)
echo [AUTO-ATTACH] busid=%BUS%
usbipd bind --busid %BUS%
usbipd attach --wsl --busid %BUS% --auto-attach
echo %BUS% detached
usbipd list
exit /b

REM ================================
REM 标签：detach
REM ================================
:detach
set BUS=%portid%
if %BUS%=="" (
    goto show_help
)
echo [DETACH] busid=%BUS%
usbipd detach --busid %BUS%
echo %BUS% detached
usbipd list
exit /b

REM ================================
REM clear
REM ================================
:clear
@echo off
for /f "tokens=1" %%i in ('usbipd list ^| findstr /i /r "^[0-9a-f][0-9a-f].*-"') do (
    echo 清除 Persisted: %%i
    usbipd unbind --guid %%i
)
echo Persisted guid清除完成
exit /b


