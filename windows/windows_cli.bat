@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for windows_usbipd.bat
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion
set "action=%2"
set "param1=%3"

echo  action=%action%
echo  param1=%param1%

echo des_dir=%des_dir%

if "%action%"=="" goto show_help
if /i "%action%"=="agy" goto agy

echo Unknown command: %action%
goto show_help
exit /b

:show_help
echo Available commands:
echo   agy             -Antigravity cli
echo.
exit /b

:agy
set "default_dir=%USERPROFILE%\batScript"
if "%param1%"=="." (
    set "default_dir=%cd%"
)
::cd /d %default_dir% && agy
::需要把wt.exe添加到环境变量
wt.exe -w 0 -p "Antigravity CLI" -d %default_dir%
::如果执行windwos terminal没有配antigravity导致执行失败，可以使用默认的方式
if errorlevel 1 (
    cd /d %default_dir% && agy
)
exit /b