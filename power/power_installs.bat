@echo off
:: power_installs.bat - 安装功耗辅助工具apk
chcp 65001 >nul
setlocal

:: 检查参数
if "%~1"=="" goto :show_help
if /i "%~1"=="help" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%1"=="wt" goto whatstempeture
if /i "%1"=="wmp" goto wheresmypower

echo [错误]: 未知工具指令: %1
goto :show_help

:show_help
echo.
echo 电源管理工具安装器
echo =======================
echo 用法: power install [tool_name]
echo.
echo 可用工具:
echo   wt   - 安装并配置 WhatsTemp 温度监控工具.
echo   wmp  - 安装并配置 WheresMyPower 功耗分析工具.
echo.
echo 示例:
echo   power install wt
exit /b 1

:whatstempeture
set "PACKAGE_NAME=com.example.mtk10263.whatsTemp"
echo [信息]: 准备安装并配置 whatstempeture V1.9
cd /d "%SCRIPT_DIR%WhatsTemp"
adb install -r whatsTemp.apk

adb shell "mkdir -p /sdcard/WhatsTemp/"
adb push tool.config /sdcard/WhatsTemp/

adb shell setenforce 0

adb shell chmod 664 /sys/devices/system/cpu/cpu0/online
adb shell chmod 664 /sys/devices/system/cpu/cpu1/online
adb shell chmod 664 /sys/devices/system/cpu/cpu2/online
adb shell chmod 664 /sys/devices/system/cpu/cpu3/online
adb shell chmod 664 /sys/devices/system/cpu/cpu4/online
adb shell chmod 664 /sys/devices/system/cpu/cpu5/online
adb shell chmod 664 /sys/devices/system/cpu/cpu6/online
adb shell chmod 664 /sys/devices/system/cpu/cpu7/online

adb shell pm grant %PACKAGE_NAME% android.permission.POST_NOTIFICATIONS
adb shell pm grant %PACKAGE_NAME% android.permission.WRITE_EXTERNAL_STORAGE
adb shell dumpsys deviceidle whitelist +%PACKAGE_NAME%
exit /b

:wheresmypower
echo [信息]: 准备安装并配置 wheresmypower
cd /d "%SCRIPT_DIR%wheresmypower"
adb install -r wheresmypower.apk
call wmp-setup.bat
exit /b
