@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for init.bat
:: Usage: init.bat [script_dir]
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion
set "DEBUG=0"

:: 开启耗时统计逻辑（当 DEBUG=1 时输出详细步骤耗时）
if "%DEBUG%"=="1" (
    for /f "tokens=1-4 delims=:.," %%a in ("%time%") do set /a "START_TIME=(((%%a*60)+1%%b-100)*60+1%%c-100)*100+1%%d-100"
)

:: *******************Get current date and time, format: MMDD-HHMM**********************
rem 解析日期
for /f "tokens=2-4 delims=/.- " %%a in ("%date%") do (
    set MM=%%b
    set DD=%%c
)

rem 解析时间（不使用空格作为分隔符）
for /f "tokens=1-2 delims=:" %%a in ("%time%") do (
    set HH=%%a
    set MN=%%b
)

rem 补零（小时可能有前导空格）
set HH=%HH: =0%

set FORMAT_TIME=%MM%%DD%-%HH%%MN%
:: *******************Get current date and time, format: MMDD-HHMM**********************

:: *******************获取当前脚本所在目录**********************
:: --结尾有反斜杠
set "SCRIPT_DIR=%~dp0"
:: %1为空时代表初始化脚本init.bat调用
:: %1不为空时代表模块子脚本调用，用来重新设置当前脚本和输出目录
if "%~1"=="" (
	set "INIT_BAT=!SCRIPT_DIR!init.bat"
	set "ADB_CHECK_BAT=!SCRIPT_DIR!adb_check.bat"
	set "ROOT_OUT_DIR=!SCRIPT_DIR!OUT\"
) else (
	set "SCRIPT_DIR=%~1"
	for %%a in ("!SCRIPT_DIR:~0,-1!") do set "LAST_DIR=%%~nxa"
	set "MODULE_OUT_DIR=!ROOT_OUT_DIR!!LAST_DIR!"
)
:: *******************获取当前脚本所在目录**********************

if "%DEBUG%"=="1" (
	echo [DEBUG] FORMAT_TIME=%FORMAT_TIME%
	echo [DEBUG] SCRIPT_DIR=%SCRIPT_DIR%
	echo [DEBUG] INIT_BAT=%INIT_BAT%
	echo [DEBUG] ADB_CHECK_BAT=%ADB_CHECK_BAT%
	echo [DEBUG] ROOT_OUT_DIR=%ROOT_OUT_DIR%
	echo [DEBUG] MODULE_OUT_DIR=%MODULE_OUT_DIR%

    for /f "tokens=1-4 delims=:.," %%a in ("%time%") do set /a "END_TIME=(((%%a*60)+1%%b-100)*60+1%%c-100)*100+1%%d-100"
    set /a "ELAPSED=END_TIME - START_TIME"
    echo [DEBUG] init.bat 执行耗时: !ELAPSED!0 ms (约 !ELAPSED!0 毫秒)
)

endlocal & (
	set "FORMAT_TIME=%FORMAT_TIME%"
	set "SCRIPT_DIR=%SCRIPT_DIR%"
	set "INIT_BAT=%INIT_BAT%"
	set "ADB_CHECK_BAT=%ADB_CHECK_BAT%"
	set "ROOT_OUT_DIR=%ROOT_OUT_DIR%"
	set "MODULE_OUT_DIR=%MODULE_OUT_DIR%"
)




