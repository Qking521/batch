@echo off
:: ============================================================
:: Author: WangQiang
:: Date: 2026-07-20
:: Description: Optimized script for thermal_installs.bat
:: ============================================================
chcp 65001 >nul
setlocal

set "cmd=%~1"
set "param1=%~2"

set "APKS_DIR=%SCRIPT_DIR%android_apks"
echo APKS_DIR=%APKS_DIR%

:: 检查参数
if "%cmd%"=="" goto :usage
if /i "%cmd%"=="help" goto :usage
if /i "%cmd%"=="-h" goto :usage
if /i "%cmd%"=="ds" goto dhrystone
if /i "%cmd%"=="gl" goto webGL
if /i "%cmd%"=="wt" goto whats_tempeture
if /i "%cmd%"=="wmp" goto wheres_my_power
if /i "%cmd%"=="fd" goto fast_discharge
if /i "%cmd%"=="moto" goto moto_tools
if /i "%cmd%"=="cell" goto cellular

echo [错误]: 未知工具指令: %cmd%
goto :usage
exit /b 0

:usage
echo.
echo apk工具安装脚本
echo =======================
echo 用法: ad install [toolname]
echo.
echo 可用工具:
echo   ds       - 安装并配置 dhrystone 测试CPU性能的工具.
echo   gl       - 安装并配置 webGL 测试GPU性能的工具.
echo   wt       - 安装并配置 WhatsTemp 温度监控工具.
echo   wmp      - 安装并配置 WheresMyPower 功耗分析工具.
echo   fd       - 安装并配置 fastDischarge 快速耗电工具.
echo   moto     - 安装并配置 和moto项目相关的自动化测试工具.
echo   moto     - 安装并配置 cellular 查看通讯网络信息工具.
echo.
echo 示例:
echo   ad install ds
exit /b 0

:dhrystone
    ::dhrystone verison:7.0
    set DHRYSTONE_FILE_PATH=%APKS_DIR%\dhrystone.apk
    adb install --bypass-low-target-sdk-block %DHRYSTONE_FILE_PATH%
exit /b 0

:webGL
    set WebGL_FILE_PATH=%APKS_DIR%\WebGLSamples_Aquarium.apk
    adb install --bypass-low-target-sdk-block %WebGL_FILE_PATH%
    exit /b 0

:whats_tempeture
    :: whatstempeture version:V1.9
    set "PACKAGE_NAME=com.example.mtk10263.whatsTemp"
    set "WT_CONFIG=%APKS_DIR%\wt_common_tool.config"

    for /f %%a in ('adb shell getprop ro.product.device') do set product=%%a
    echo product: %product%
    if  "%product%"=="mica" (
        set "WT_PATH=/mnt/user/10/emulated/10/WhatsTemp/"
        set "WT_CONFIG=%APKS_DIR%\wt_mica_tool.config"
    )
    echo WT_CONFIG=%WT_CONFIG%

    echo [信息]: 准备安装并配置 whatstempeture
    adb install -r "%APKS_DIR%\WhatsTemp.apk"

    set "WT_PATH=/sdcard/WhatsTemp/"
    adb shell "mkdir -p %WT_PATH%"
    adb push %WT_CONFIG% %WT_PATH%

    adb shell setenforce 0

    for /f "delims=" %%a in ('adb shell ls /sys/devices/system/cpu/') do (
        echo %%a | findstr /r "cpu[0-9]" > nul
        if not errorlevel == 1 (
            adb shell chmod 664 /sys/devices/system/cpu/%%a/online
        )
    )
    call :grant_permission %PACKAGE_NAME%
    echo WhatsTemp安装成功，具体操作执行therm wt -h查看
exit /b 0

:wheres_my_power
    set "WMP_PACKAGE=com.motorola.wheresmypower"
    echo [信息]: 准备安装并配置 wheresmypower
    adb install -r %APKS_DIR%\wheresmypower.apk
    
    adb shell "chmod +r /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq"
    adb shell "chmod +r /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq"
    adb shell "appops set %WMP_PACKAGE% SYSTEM_ALERT_WINDOW allow"
    adb shell "appops set %WMP_PACKAGE% READ_MEDIA_AUDIO allow

    adb shell "appops set %WMP_PACKAGE% READ_MEDIA_IMAGES allow
    adb shell "appops set %WMP_PACKAGE% READ_MEDIA_VIDEO allow
    adb shell "appops set %WMP_PACKAGE% ACCESS_RESTRICTED_SETTINGS allow"
    adb shell "am force-stop %WMP_PACKAGE%"
    adb shell "am start -a android.intent.action.VIEW -n %WMP_PACKAGE%/.SettingsActivity"
exit /b 0

:fast_discharge
    ::fastdischarge verison:1.2
    set FD_PACKAGE="jp.smartmobile.quickdischarge"
    set fastDischarge_FILE_PATH=%APKS_DIR%\fastDischarge.apk
    adb install --bypass-low-target-sdk-block %fastDischarge_FILE_PATH%
    call :grant_permission %FD_PACKAGE%
exit /b 0

:moto_tools
    adb install -r %APKS_DIR%\nonrootchina-debug.apk
    adb install -r %APKS_DIR%\nonrootchina-debug-androidTest.apk
exit /b 0

:cellular
    adb install -r %APKS_DIR%\cellular-Z.apk
exit /b 0

:grant_permission
    set "package_name=%~1"
    for /f %%i in ('adb shell am get-current-user') do set "user=%%i"
    echo user: %user%
    adb shell pm grant --user %user% %package_name% android.permission.POST_NOTIFICATIONS
    adb shell pm grant --user %user% %package_name% android.permission.WRITE_EXTERNAL_STORAGE
    adb shell dumpsys deviceidle whitelist +%package_name%
exit /b 0