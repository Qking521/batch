@echo off
call "%~dp0init.bat"
@REM open microsoft apps

doskey myalias=doskey /macros

doskey record=adb shell screenrecord  --bugreport /sdcard/record.mp4 ^
$T break on ^
$T adb pull /sdcard/record.mp4 . ^&^& start .\record.mp4

doskey pullrecord=adb pull /sdcard/record.mp4 . ^&^& start .\record.mp4

@REM  mtklog
doskey mtklog=%USERPROFILE%\batScript\mtk\mtklog.bat $*

@REM android
doskey ad=%USERPROFILE%\batScript\android\android_all.bat $*

@REM power
doskey power=%USERPROFILE%\batScript\power\power_all.bat $*

@REM performance
doskey perf=%USERPROFILE%\batScript\performance\perf_all.bat $*

@REM thermal
doskey therm=%USERPROFILE%\batScript\thermal\thermal_all.bat $*

@REM windows
doskey win=%USERPROFILE%\batScript\windows\windows_all.bat $*
@REM port forward for wsl
doskey usbip=%USERPROFILE%\batScript\windows\windows_all.bat usbip $*