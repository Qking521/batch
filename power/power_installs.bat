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
set "WT_PATH=/sdcard/WhatsTemp/"
set "CFG_PATH=tool.config"

for /f %%a in ('adb shell getprop ro.product.device') do set product=%%a
echo product: %product%
if  "%product%"=="mica" (
    set "WT_PATH=/mnt/user/10/emulated/10/WhatsTemp/"
    set "CFG_PATH=tool_mica.config"
)
echo WT_PATH=%WT_PATH%
echo CFG_PATH=%CFG_PATH%

echo [信息]: 准备安装并配置 whatstempeture V1.9
cd /d "%SCRIPT_DIR%WhatsTemp"
adb install -r whatsTemp.apk

adb shell "mkdir -p %WT_PATH%"
adb push %CFG_PATH% %WT_PATH%


adb shell setenforce 0

for /f "delims=" %%a in ('adb shell ls /sys/devices/system/cpu/') do (
	echo %%a | findstr /r "cpu[0-9]" > nul
	if not errorlevel == 1 (
        adb shell chmod 664 /sys/devices/system/cpu/%%a/online
	)
)

for /f %%i in ('adb shell am get-current-user') do set "user=%%i"
echo user: %user%
adb shell pm grant --user %user% %PACKAGE_NAME% android.permission.POST_NOTIFICATIONS
adb shell pm grant --user %user% %PACKAGE_NAME% android.permission.WRITE_EXTERNAL_STORAGE
adb shell dumpsys deviceidle whitelist +%PACKAGE_NAME%
exit /b

:wheresmypower
echo [信息]: 准备安装并配置 wheresmypower
cd /d "%SCRIPT_DIR%wheresmypower"
adb install -r wheresmypower.apk
call wmp-setup.bat
exit /b
