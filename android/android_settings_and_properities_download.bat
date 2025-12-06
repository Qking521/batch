@echo off
chcp 65001 >nul

:: 获取当前脚本所在目录
set "SCRIPT_DIR=%~dp0"
set "OUT=%SCRIPT_DIR%OUT\settings\"
echo %OUT%
if not exist %OUT% mkdir %OUT%

REM 检查ADB连接
:: 先调用基础脚本检查ADB和设备（使用完整路径）
call "%SCRIPT_DIR%adb_check.bat"
if %errorlevel% neq 0 (
    echo 错误：未检测到已连接的Android设备
    pause
    exit /b 1
)

REM 创建输出文件
set output_file=android_settings_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.txt
set output_file=%OUT%%output_file: =_%

echo [1/4] 获取System设置...
echo === SYSTEM SETTINGS === >> %output_file%
adb shell settings list system >> %output_file% 2>&1
echo. >> %output_file%

echo [2/4] 获取Secure设置...
echo === SECURE SETTINGS === >> %output_file%
adb shell settings list secure >> %output_file% 2>&1
echo. >> %output_file%

echo [3/4] 获取Global设置...
echo === GLOBAL SETTINGS === >> %output_file%
adb shell settings list global >> %output_file% 2>&1
echo. >> %output_file%

echo [4/4] 获取System Properties...
echo === SYSTEM PROPERTIES === >> %output_file%
adb shell getprop >> %output_file% 2>&1
echo. >> %output_file%

REM 额外获取一些高级设置信息
echo === ADDITIONAL INFO === >> %output_file%
echo. >> %output_file%

echo --- Device Info --- >> %output_file%
adb shell getprop ro.build.version.release >> %output_file%
adb shell getprop ro.build.version.sdk >> %output_file%
adb shell getprop ro.product.manufacturer >> %output_file%
adb shell getprop ro.product.model >> %output_file%
echo. >> %output_file%

echo --- Settings Database Count --- >> %output_file%
echo System settings count: >> %output_file%
adb shell "settings list system | wc -l" >> %output_file%
echo Secure settings count: >> %output_file%
adb shell "settings list secure | wc -l" >> %output_file%
echo Global settings count: >> %output_file%
adb shell "settings list global | wc -l" >> %output_file%
echo System properties count: >> %output_file%
adb shell "getprop | wc -l" >> %output_file%
echo. >> %output_file%


REM 显示统计信息
echo === 统计信息 ===
for /f %%i in ('adb shell "settings list system | wc -l"') do echo System设置数量：%%i
for /f %%i in ('adb shell "settings list secure | wc -l"') do echo Secure设置数量：%%i  
for /f %%i in ('adb shell "settings list global | wc -l"') do echo Global设置数量：%%i
for /f %%i in ('adb shell "getprop | wc -l"') do echo System Properties数量：%%i

start %output_file%