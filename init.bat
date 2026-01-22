@echo off
setlocal enabledelayedexpansion
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
set format_time=%MM%%DD%-%HH%%MN%
echo formated time = %format_time%
:: *******************获取当前日期和时间，格式：MMDD-HHMM**********************

:: *******************获取当前脚本所在目录**********************
:: --结尾有反斜杠
set "SCRIPT_DIR=%~dp0"
echo SCRIPT_DIR=%SCRIPT_DIR%
if "%1"=="" (
	set INIT_BAT=!SCRIPT_DIR!init.bat
	echo basepath=!INIT_BAT!

	set ABD_CHECK_BAT=!SCRIPT_DIR!adb_check.bat
	echo adbpath=!ABD_CHECK_BAT!
	
	set BASE_OUT_DIR=!SCRIPT_DIR!OUT\
	echo base_Out=!BASE_OUT_DIR!
	
)else (
	set "SCRIPT_DIR=%1"
	echo script_dir = !SCRIPT_DIR!
	
	for %%a in ("!SCRIPT_DIR:~0,-1!") do set "LAST_DIR=%%~nxa"
	set OUT_DIR=!BASE_OUT_DIR!!LAST_DIR!
	echo out_dir=!OUT_DIR!
)
endlocal & (
	set format_time=%format_time%
	set SCRIPT_DIR=%SCRIPT_DIR%
	set INIT_BAT=%INIT_BAT%
	set ABD_CHECK_BAT=%ABD_CHECK_BAT%
	set BASE_OUT_DIR=%BASE_OUT_DIR%
	set OUT_DIR=%OUT_DIR%
)
:: *******************获取当前脚本所在目录**********************



