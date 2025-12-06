@echo off
setlocal

:: Define variables
set NPP_PATH=C:\Program Files\Notepad++\notepad++.exe
set "out_dir"=""

adb root

adb shell setenforce 0

adb shell rm /data/SF_dump/*
adb shell setprop vendor.debug.bq.dump "@surface"

adb shell "dumpsys SurfaceFlinger" > SF_bqdump_all.log

adb shell setprop "vendor.debug.bq.dump ''"

rmdir /S /Q SF_bqdump_all
md SF_bqdump_all
move SF_bqdump_all.log SF_bqdump_all
adb pull /data/SF_dump SF_bqdump_all
adb shell rm /data/SF_dump/*

rem python translate.py

:: Open the log file in Notepad++
"%NPP_PATH%" "%USERPROFILE%\SF_bqdump_all\SF_bqdump_all.log"
endlocal