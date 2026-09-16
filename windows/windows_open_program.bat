@echo off
:: ============================================================
:: Author: WangQiang
:: Date: 2026-07-20
:: Description: Optimized script for windows_usbipd.bat
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion
set "action=%~1"
set "param1=%~2"

echo action: %action% %param1%
set "TOOLS_ROOT_PATH=D:\tools"

if /i "%param1%"=="" start "" %TOOLS_ROOT_PATH%
if /i "%param1%"=="" goto show_help
if /i "%param1%"=="-h" goto show_help
if /i "%param1%"=="help" goto show_help

if /i "%param1%"=="ltr" goto long_trace_record
if /i "%param1%"=="ltra" goto long_trace_record_advance
if /i "%param1%"=="ft6" goto flashtool
if /i "%param1%"=="odin" goto odin

:show_help
echo.
echo Usage: win command program
echo.
echo Available parmas:
echo   ltr              - mtk long trace record tool
echo   ltra             - mtk long trace record tool with lmode
echo   ft               - mtk flash tool
echo   odin             - samsung flash tool
echo   -h               - Show help (alias: help).
echo.
echo Examples:
echo   win open ltr
echo.
exit /b

:long_trace_record
    echo "不管是程序还是文件都不能包含任何中文字符"
    set "PROGRAM_PATH=D:\tools\LTR2_Lite\LTR2.exe"
    for %%P in ("!PROGRAM_PATH!") do start "" /D "%%~dpP" "!PROGRAM_PATH!"
    exit /b

:long_trace_record_advance
    echo "不管是程序还是文件都不能包含任何中文字符"
    set "PROGRAM_PATH=D:\tools\LTR2_Lite_advance\LTR2.exe"
    for %%P in ("!PROGRAM_PATH!") do start "" /D "%%~dpP" "!PROGRAM_PATH!"
    exit /b

:flashtool
    set "PROGRAM_PATH=D:\tools\SP_Flash_Tool_V6\SPFlashToolV6.exe"
    for %%P in ("!PROGRAM_PATH!") do start "" /D "%%~dpP" "!PROGRAM_PATH!"
    exit /b

:odin
    set "PROGRAM_PATH=D:\tools\odin4v_windows_2.6\odin4v.exe"
    for %%P in ("!PROGRAM_PATH!") do start "" /D "%%~dpP" "!PROGRAM_PATH!"
    exit /b


