@echo off
setlocal enabledelayedexpansion
set "DEBUG=0"
:: *******************获取当前日期和时间，格式：MMDD-HHMM**********************
for /f "tokens=2-4 delims=/.- " %%a in ("%date%") do (
    set MM=%%b
    set DD=%%c
)
for /f "tokens=1-2 delims=: " %%a in ("%time%") do (
    set HH=%%a
    set MN=%%b
)

:: 去掉前导空格
if "%HH:~0,1%"==" " set HH=0%HH%
set FORMAT_TIME=%MM%%DD%-%HH%%MN%
:: *******************获取当前日期和时间，格式：MMDD-HHMM**********************

:: *******************获取当前脚本所在目录**********************
:: --结尾有反斜杠
set "SCRIPT_DIR=%~dp0"
if "%1"=="" (
	set INIT_BAT=!SCRIPT_DIR!init.bat
	set ABD_CHECK_BAT=!SCRIPT_DIR!adb_check.bat
	set BASE_OUT_DIR=!SCRIPT_DIR!OUT\
)else (
	set "SCRIPT_DIR=%1"
	for %%a in ("!SCRIPT_DIR:~0,-1!") do set "LAST_DIR=%%~nxa"
	set OUT_DIR=!BASE_OUT_DIR!!LAST_DIR!
)
if "%DEBUG%"=="1" (
	echo FORMAT_TIME=%FORMAT_TIME%
	echo SCRIPT_DIR=%SCRIPT_DIR%
	echo INIT_BAT=%INIT_BAT%
	echo ABD_CHECK_BAT=%ABD_CHECK_BAT%
	echo BASE_OUT_DIR=%BASE_OUT_DIR%
	echo OUT_DIR=%OUT_DIR%
)
endlocal & (
	set FORMAT_TIME=%FORMAT_TIME%
	set SCRIPT_DIR=%SCRIPT_DIR%
	set INIT_BAT=%INIT_BAT%
	set ABD_CHECK_BAT=%ABD_CHECK_BAT%
	set BASE_OUT_DIR=%BASE_OUT_DIR%
	set OUT_DIR=%OUT_DIR%
	
)
:: *******************获取当前脚本所在目录**********************



