@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for thermal_installs.bat
:: ============================================================
chcp 65001 >nul
setlocal

set "cmd=%1"
set "param1=%2"

:: 检查参数
if "%~1"=="" goto :show_help
if /i "%~1"=="help" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%1"=="wt" goto whats_tempeture

echo [错误]: 未知工具指令: %cmd%
goto :show_help

:show_help
echo.
echo 温升工具安装脚本
echo =======================
echo 用法: thml install [tool_name]
echo.
echo 可用工具:
echo   wt   - 安装并配置 WhatsTemp 温度监控工具.
echo.
echo 示例:
echo   thml install wt
exit /b 1

:whats_tempeture
set "PACKAGE_NAME=com.example.mtk10263.whatsTemp"
set "WT_PATH=/sdcard/WhatsTemp/"
set "WT_CFG_PATH=tool.config"

for /f %%a in ('adb shell getprop ro.product.device') do set product=%%a
echo product: %product%
if  "%product%"=="mica" (
    set "WT_PATH=/mnt/user/10/emulated/10/WhatsTemp/"
    set "WT_CFG_PATH=tool_mica.config"
)
echo WT_PATH=%WT_PATH%
echo WT_CFG_PATH=%WT_CFG_PATH%

echo [信息]: 准备安装并配置 whatstempeture V1.9
cd /d "%SCRIPT_DIR%WhatsTemp"
adb install -r whatsTemp.apk

adb shell "mkdir -p %WT_PATH%"
adb push %WT_CFG_PATH% %WT_PATH%


adb shell setenforce 0

for /f "delims=" %%a in ('adb shell ls /sys/devices/system/cpu/') do (
	echo %%a | findstr /r "cpu[0-9]" > nul
	if not errorlevel == 1 (
        adb shell chmod 664 /sys/devices/system/cpu/%%a/online
	)
)

for /f %%i in ('adb shell am get-current-user') do set "userid=%%i"
echo userid: %userid%
adb shell pm grant --user %userid% %PACKAGE_NAME% android.permission.POST_NOTIFICATIONS
adb shell pm grant --user %userid% %PACKAGE_NAME% android.permission.WRITE_EXTERNAL_STORAGE
adb shell dumpsys deviceidle whitelist +%PACKAGE_NAME%
exit /b
