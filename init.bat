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
:: Extract year, month, day safely by replacing delimiters
set "TMP_DATE=%date%"
set "TMP_DATE=%TMP_DATE:/=-%"
set "TMP_DATE=%TMP_DATE:.=-%"
set "DATE_STR=%TMP_DATE:~0,10%"
set "TIME_STR=%time%"

:: handle leading space in time
if "%TIME_STR:~0,1%"==" " set "TIME_STR=0%TIME_STR:~1%"

:: extract MM, DD, HH, MN (assumes YYYY-MM-DD or MM/DD/YYYY formats handled)
set "MM=%DATE_STR:~5,2%"
set "DD=%DATE_STR:~8,2%"
set "HH=%TIME_STR:~0,2%"
set "MN=%TIME_STR:~3,2%"

set "FORMAT_TIME=%MM%%DD%-%HH%%MN%"
:: *******************Get current date and time, format: MMDD-HHMM**********************

:: *******************获取当前脚本所在目录**********************
:: --结尾有反斜杠
set "SCRIPT_DIR=%~dp0"
:: %1为空时代表初始化脚本init.bat调用
:: %1不为空时代表子脚本调用，用来重新设置当前脚本和输出目录
if "%~1"=="" (
	set "INIT_BAT=!SCRIPT_DIR!init.bat"
	set "ADB_CHECK_BAT=!SCRIPT_DIR!adb_check.bat"
	set "BASE_OUT_DIR=!SCRIPT_DIR!OUT\"
) else (
	set "SCRIPT_DIR=%~1"
	for %%a in ("!SCRIPT_DIR:~0,-1!") do set "LAST_DIR=%%~nxa"
	set "OUT_DIR=!BASE_OUT_DIR!!LAST_DIR!"
)
:: *******************获取当前脚本所在目录**********************

if "%DEBUG%"=="1" (
	echo [DEBUG] FORMAT_TIME=%FORMAT_TIME%
	echo [DEBUG] SCRIPT_DIR=%SCRIPT_DIR%
	echo [DEBUG] INIT_BAT=%INIT_BAT%
	echo [DEBUG] ADB_CHECK_BAT=%ADB_CHECK_BAT%
	echo [DEBUG] BASE_OUT_DIR=%BASE_OUT_DIR%
	echo [DEBUG] OUT_DIR=%OUT_DIR%

    for /f "tokens=1-4 delims=:.," %%a in ("%time%") do set /a "END_TIME=(((%%a*60)+1%%b-100)*60+1%%c-100)*100+1%%d-100"
    set /a "ELAPSED=END_TIME - START_TIME"
    echo [DEBUG] init.bat 执行耗时: !ELAPSED!0 ms (约 !ELAPSED!0 毫秒)
)

endlocal & (
	set "FORMAT_TIME=%FORMAT_TIME%"
	set "SCRIPT_DIR=%SCRIPT_DIR%"
	set "INIT_BAT=%INIT_BAT%"
	set "ADB_CHECK_BAT=%ADB_CHECK_BAT%"
	set "BASE_OUT_DIR=%BASE_OUT_DIR%"
	set "OUT_DIR=%OUT_DIR%"
)




