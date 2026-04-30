@echo off
setlocal enabledelayedexpansion
set "op=%1"

if "%1"=="" goto show_help
if "%2"=="" goto show_help
if /i "%1"=="attach" goto attach
if /i "%1"=="aattach" goto auto_attach
if /i "%1"=="detach" goto detach

:show_help
usbipd list
exit /b

REM ================================
REM 标签：普通 attach
REM ================================
:attach
set BUS=%2
echo [ATTACH] busid=%BUS%
usbipd list
usbipd bind --busid %BUS%
usbipd attach --wsl --busid %BUS%
echo.
exit /b

REM ================================
REM 标签：auto-attach
REM ================================
:auto_attach
set BUS=%2
echo [AUTO-ATTACH] busid=%BUS%
usbipd list
usbipd bind --busid %BUS%
usbipd attach --wsl --busid %BUS% --auto-attach
echo.
exit /b

REM ================================
REM 标签：detach
REM ================================
:detach
set BUS=%2
echo [DETACH] busid=%BUS%
usbipd detach --busid %BUS%
echo.
exit /b


