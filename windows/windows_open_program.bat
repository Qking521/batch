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

if /i "%param1%"=="" goto show_help
if /i "%param1%"=="-h" goto show_help
if /i "%param1%"=="help" goto show_help

if /i "%param1%"=="dir" goto tools_dir
if /i "%param1%"=="ltr" goto long_trace_record
if /i "%param1%"=="ltra" goto long_trace_record_advance
if /i "%param1%"=="ft6" goto flashtool
if /i "%param1%"=="qfile" goto qfile
if /i "%param1%"=="odin" goto odin
if /i "%param1%"=="agy" goto agy

:show_help
echo.
echo Usage: win command program
echo.
echo Available parmas:
echo   dir                      - open tools dir
echo   ltr                      - mtk long trace record tool
echo   ltra                     - mtk long trace record tool with lmode
echo   ft6                      - mtk flash tool for V6
echo   qfile                    - qcom flash tool
echo   odin                     - samsung flash tool
echo   agy [default_dir]        -start agy cli, Add workdir if have
echo   -h                       - Show help (alias: help).
echo.
echo Examples:
echo   win open ltr
echo.
exit /b

:tools_dir
    start "" %TOOLS_ROOT_PATH%
    exit /b0

:long_trace_record
    echo "不管是程序还是文件都不能包含任何中文和空格字符", convert mode解析的是trace开头.dat后缀的文件
    set "PROGRAM_PATH=%TOOLS_ROOT_PATH%\LTR2_Lite\LTR2.exe"
    goto launch

:long_trace_record_advance
    echo "不管是程序还是文件都不能包含任何中文和空格字符"
    set "PROGRAM_PATH=%TOOLS_ROOT_PATH%\LTR2_Lite_advance\LTR2.exe"
    goto launch

:flashtool
    set "PROGRAM_PATH=%TOOLS_ROOT_PATH%\SP_Flash_Tool_V6\SPFlashToolV6.exe"
    goto launch

:qfile
    set "PROGRAM_PATH=%TOOLS_ROOT_PATH%\QPST\bin\QFIL.exe"
    goto launch

:odin
    set "PROGRAM_PATH=%TOOLS_ROOT_PATH%\odin4v_windows_2.6\odin4v.exe"
    goto launch

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
    exit /b 0

:launch
    if not exist "!PROGRAM_PATH!" (
        echo [ERROR] 文件未找到: !PROGRAM_PATH!
        exit /b 1
    )
    for %%P in ("!PROGRAM_PATH!") do start "" /D "%%~dpP" "!PROGRAM_PATH!"
    exit /b 0



