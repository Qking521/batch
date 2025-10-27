@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
:: 获取当前脚本所在目录
set "SCRIPT_DIR=%~dp0"

:: 获取格式化的时间ftime
call %SCRIPT_DIR%base_time.bat

if "%1"=="" goto show_help
if /i "%1"=="-h" goto show_help
if /i "%1"=="help" goto show_help
if /i "%1"=="top" goto current_activity
if /i "%1"=="shot" goto screen_shot
if /i "%1"=="record" goto screen_record
if /i "%1"=="bugreport" goto bugreport
if /i "%1"=="clear" goto clear
if /i "%1"=="dev" goto developer
if /i "%1"=="ss" goto setting_search
if /i "%1"=="hwinfo" goto hardware_info
if /i "%1"=="asp" goto all_settings_and_properities
if /i "%1"=="monkey" goto monkey

echo Unknown command: %1
goto show_help


:show_help
echo.
echo Android Commands
echo =======================
echo.
echo Usage: android [command]
echo.
echo Available commands:
echo   top 	   		- show current activity
echo   bugreport 	- pull bugreport
echo   clear 	   	- clear all android log
echo   ss 	   		- search settings
echo   dev 	   		- developer
echo   asp 	   		- all_settings_and_properities
echo   monkey 	   	- run monkey
echo   -h      		- Show help (alias: help^)
echo.
echo Examples:
echo   android top
echo.
exit /b

:current_activity
adb shell dumpsys window | grep mCurrentFocus
exit /b

:bugreport
:: === 1. 获取当前日期和时间，格式：MMDD-HH-MM ===
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

set TS=%MM%%DD%-%HH%%MN%
set "EXT="
if not "%~2"=="" (
	set "EXT=_%~2"
)

:: === 2. 创建 bugreport 文件夹 ===
::获取脚本所在目录，自带反斜杠
set "scriptDir=%~dp0"
set OUT_DIR=%scriptDir%OUT\bugreport
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

:: === 3. 生成 bugreport zip 文件 ===
set ZIPFILE=%OUT_DIR%\bugreport%EXT%_%TS%.zip
echo Generating bugreport: %ZIPFILE%
adb bugreport "%ZIPFILE%" > nul

:: === 4. 解压 zip 文件（使用 PowerShell） ===
set UNZIPDIR=%OUT_DIR%\bugreport%EXT%_%TS%
echo Extracting bugreport...
:: 优先用 7z 解压
where 7z >nul 2>&1
if %errorlevel%==0 (
    7z x "%ZIPFILE%" -o"%UNZIPDIR%" -y
) else (
    :: 尝试用 unzip（cmder 自带的 msys 通常有）
    unzip -o "%ZIPFILE%" -d "%UNZIPDIR%"
)

:: === 5. 打开 bugreport*.txt 文件 ===
for %%f in ("%UNZIPDIR%\bugreport*.txt") do (
    start "" "%%f"
    goto :done
)

:done
exit /b

:clear
adb root
adb shell "logcat -b all -c; dmesg -C"
exit /b

:screen_shot
set "shot_out=%SCRIPT_DIR%OUT\shot\
if not exist %shot_out% mkdir %shot_out%
set "shot_file=screenshot_%ftime%.png"
adb shell screencap -p /sdcard/%shot_file%
adb pull sdcard/%shot_file% %shot_out%
start %shot_file%
exit /b

:screen_record
set "record_out=%SCRIPT_DIR%OUT\record\
if not exist %record_out% mkdir %record_out%
set "record_file=record_%ftime%.mp4"
echo record_file=%record_file%
start /wait cmd /c  "adb shell screenrecord  --bugreport /sdcard/%record_file%"
adb pull /sdcard/%record_file% %record_out%
adb shell rm /sdcard/%record_file%
echo 111
::start %record_out%%record_file%
exit /b

:developer
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

:setting_search
call "%SCRIPT_DIR%android_settings_search.bat" %2
exit /b

:hardware_info
call "%SCRIPT_DIR%android_hardware_info.bat"
exit /b

:all_settings_and_properities
call "%SCRIPT_DIR%android_all_settings_and_properities.bat"
exit /b

:monkey
if not %1=="" (
	adb shell monkey -p %1 --throttle 200 --ignore-crashes --ignore-timeouts --ignore-security-exceptions --monitor-native-crashes -v -v -v 1000000
) else (
	adb shell monkey --throttle 200 --ignore-crashes --ignore-timeouts --ignore-security-exceptions --monitor-native-crashes -v -v -v 1000000
)
exit /b

endlocal