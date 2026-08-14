@echo off
chcp 65001 >nul
setlocal

:: Define variables
set param=%1
set NPP_PATH=C:\Program Files\Notepad++\notepad++.exe
set SF_OUT_DIR=%MODULE_OUT_DIR%\SurfaceFlinger
for /f "delims= " %%a in ('adb shell getprop ro.product.device') do set model=%%a
if "%param%"=="" (
	adb shell dumpsys SurfaceFlinger > SurfaceFlinger.log
	"%NPP_PATH%" "%SF_OUT_DIR%\%model%_%format_time%_SurfaceFlinger.log"
	exit /b
)

if "%param%"=="more" (
	adb shell setenforce 0
	
	adb shell rm /data/SF_dump/*
	adb shell setprop vendor.debug.bq.dump "@surface"

	adb shell "dumpsys SurfaceFlinger" > SurfaceFlinger.log

	adb shell setprop "vendor.debug.bq.dump ''"

	rmdir /S /Q %SF_OUT_DIR%
	md %SF_OUT_DIR%
	move SurfaceFlinger.log %SF_OUT_DIR%
	adb pull /data/SF_dump %SF_OUT_DIR%
	adb shell rm /data/SF_dump/*

	rem python translate.py

	:: Open the log file in Notepad++
	"%NPP_PATH%" "%SF_OUT_DIR%\SurfaceFlinger.log"
	start "" "%SF_OUT_DIR%"
)