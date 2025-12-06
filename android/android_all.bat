@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
:: 获取当前脚本所在目录
set "SCRIPT_DIR=%~dp0"
cd %SCRIPT_DIR%
:: 先调用基础脚本检查ADB和设备（使用完整路径）
call "..\adb_check.bat"
if %ERRORLEVEL% neq 0 (
    exit /b
)
:: 获取格式化的时间,返回全局变量ftime，格式：1113-1751
call "..\base_time.bat"

if "%1"=="" goto show_help
if /i "%1"=="-h" goto show_help
if /i "%1"=="help" goto show_help
if /i "%1"=="top" goto current_activity
if /i "%1"=="shot" goto screen_shot
if /i "%1"=="record" goto screen_record
if /i "%1"=="bugreport" goto bugreport
if /i "%1"=="clear" goto clear
if /i "%1"=="dev" goto developer
if /i "%1"=="di" goto device_info
if /i "%1"=="search" goto android_search
if /i "%1"=="monkey" goto monkey
if /i "%1"=="google" goto google

echo Unknown command: %1
goto show_help


:show_help
echo Available commands:
echo   top 	   		- show current activity
echo   bugreport 	- pull bugreport
echo   clear 	   	- clear all android log
echo   dev 	   		- developer
echo   search 	   	--search from settings and properities
echo   monkey 	   	- run monkey
echo   -h      		- Show help (alias: help^)
echo.
echo Examples:
echo   ad top
echo.
exit /b

:current_activity
adb shell dumpsys window | grep mCurrentFocus
exit /b

:bugreport
call android_bugreport.bat %~2
exit /b

:clear
adb root
adb shell "logcat -b all -c; dmesg -C"
echo "系统log清理完成"
exit /b

:screen_shot
set "out_dir=%userprofile%\batScript\OUT\android"
if not exist %out_dir% mkdir %out_dir%
set "shot_file=screenshot_%ftime%.png"
adb shell screencap -p /sdcard/%shot_file%
adb pull sdcard/%shot_file% %out_dir%
adb shell "rm -rf /sdcard/%shot_file%"
start %out_dir%\%shot_file%
exit /b

:screen_record
set "out_dir=%userprofile%\batScript\OUT\android"
if not exist %out_dir% mkdir %out_dir%
set "record_file=record_%ftime%.mp4"
echo record_file=%record_file%
adb shell screenrecord  --bugreport /sdcard/%record_file%
adb pull /sdcard/%record_file% %out_dir%
adb shell rm /sdcard/%record_file%
echo 111
start %out_dir%\%record_file%
exit /b

:developer
if %2==on (
	echo please input on or off
)
if %2==on (
	adb shell settings put system show_touches 1
	adb shell settings put system pointer_location 1
	adb shell settings put secure clock_seconds 1
)
if %2==off (
	adb shell settings put system show_touches 0
	adb shell settings put system pointer_location 0
	adb shell settings put secure clock_seconds 0
)
exit /b

:device_info
call android_device_info.bat
exit /b

:android_search
call "android_search.bat" %2
exit /b

:monkey
if %1=="" (
	adb shell monkey --throttle 200 --ignore-crashes --ignore-timeouts --ignore-security-exceptions --monitor-native-crashes -v -v -v 1000000
) else (
	adb shell monkey -p %1 --throttle 200 --ignore-crashes --ignore-timeouts --ignore-security-exceptions --monitor-native-crashes -v -v -v 1000000
)
exit /b

:google
set pkgs=%~dp0google_packages.txt
set cmd=%2
for /f "tokens=2 delims==" %%i in ('findstr "=" %pkgs%') do (
	adb shell pm %cmd% %%i > nul 2>&1
)
exit /b

:end
exit /b

endlocal