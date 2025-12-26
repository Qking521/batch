@echo off

:: Define variables
set param=%1
set NPP_PATH=C:\Program Files\Notepad++\notepad++.exe
set OUT_DIR=%userprofile%\batScript\OUT\surfaceflinger
if "%param%"=="" (
	adb shell dumpsys SurfaceFlinger > SurfaceFlinger.log
	"%NPP_PATH%" "%OUT_DIR%\SurfaceFlinger.log"
)
exit /b

if "%param%"=="more" (
	adb shell setenforce 0
	
	adb shell rm /data/SF_dump/*
	adb shell setprop vendor.debug.bq.dump "@surface"

	adb shell "dumpsys SurfaceFlinger" > SurfaceFlinger.log

	adb shell setprop "vendor.debug.bq.dump ''"

	rmdir /S /Q %OUT_DIR%
	md %OUT_DIR%
	move SurfaceFlinger.log %OUT_DIR%
	adb pull /data/SF_dump %OUT_DIR%
	adb shell rm /data/SF_dump/*

	rem python translate.py

	:: Open the log file in Notepad++
	"%NPP_PATH%" "%OUT_DIR%\SurfaceFlinger.log"
	start "" "%OUT_DIR%"
)