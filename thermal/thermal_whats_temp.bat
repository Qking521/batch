@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "PACKAGE_NAME=com.example.mtk10263.whatsTemp"
set "WT_PATH=/sdcard/WhatsTemp/"
for /f %%a in ('adb shell getprop ro.product.device') do set product=%%a
echo product: %product%
if  "%product%"=="mica" (
    set "WT_PATH=/mnt/user/10/emulated/10/WhatsTemp/"
)
adb shell pm list packages %PACKAGE_NAME% | findstr "%PACKAGE_NAME%" >nul
if !errorlevel! equ 0 goto :check_args
echo [提示]: 未检测到 WhatsTemp 应用，正在为您执行安装程序... 
goto :do_install

:check_args
:: 参数跳转逻辑
if "%~1"=="" goto :usage
if /i "%~1"=="help" goto :usage
if /i "%~1"=="-h" goto :usage
if /i "%~1"=="install" goto :do_install
if /i "%~1"=="start" goto :do_start
if /i "%~1"=="stop" goto :do_stop
if /i "%~1"=="pull" goto :do_pull
if /i "%~1"=="config" goto :do_config
if /i "%~1"=="show" goto :do_show
if /i "%~1"=="guide" goto :do_guide

echo [ERROR] Unknown command: %~1
goto :usage

:usage
echo.
echo WhatsTemp Control Tool
echo =======================
echo Usage: therm wt [command]
echo.
echo Available commands:
echo   install  - Install WhatsTemp APK and grant permissions.
echo   start    - Start WhatsTemp service to begin collection.
echo   stop     - Stop WhatsTemp collection service.
echo   pull     - Stop service and pull thermal logs to OUT.
echo   config   - Pull tool.config from device.
echo   show     - Open latest CSV log in Excel.
echo   guide    - Open WhatsTemp User Guide PDF.
echo   help/-h  - Show this help info.
echo.
exit /b 0

:do_install
    :: 调用现有的安装脚本
    call "%SCRIPT_DIR%thermal_installs.bat" wt
exit /b

:do_start
    adb shell am force-stop %PACKAGE_NAME%
    :: Launch WhatsTemp tool
    adb shell am start -n %PACKAGE_NAME%/.MainActivity
    :: --ei t <timeout> timeout in minutes
    adb shell am startservice -n %PACKAGE_NAME%/.GetInfo_Service --ei t 0
exit /b

:do_stop
    adb shell am stopservice -n %PACKAGE_NAME%/.GetInfo_Service
exit /b

:do_pull
    echo [信息]: 正在停止whatstemp进程并拉取 WhatsTemp 日志...
    adb shell am stopservice -n %PACKAGE_NAME%/.GetInfo_Service
    echo MODULE_OUT_DIR = %MODULE_OUT_DIR%
    :: 先清理本地已存在的目录，防止 adb pull 产生嵌套
    :: if exist "%MODULE_OUT_DIR%\whatsTemp" rd /s /q "%MODULE_OUT_DIR%\whatsTemp"
    :: 确保父目录存在
    if not exist "%MODULE_OUT_DIR%" mkdir "%MODULE_OUT_DIR%"
    :: 直接拉取文件夹。因为本地 whatsTemp 不存在，ADB 会将远程 log 文件夹的内容直接放入新建的 whatsTemp 中
    adb pull %WT_PATH%log/ "%MODULE_OUT_DIR%\whatsTemp"
    adb shell rm  %WT_PATH%log/*
    if exist "%MODULE_OUT_DIR%\whatsTemp" start "" "%MODULE_OUT_DIR%\whatsTemp"
exit /b

:do_config
    if not exist "%MODULE_OUT_DIR%" mkdir "%MODULE_OUT_DIR%"
    adb pull  %WT_PATH%/tool.config %MODULE_OUT_DIR%\whatsTemp\tool.config
    start "" "%MODULE_OUT_DIR%\whatsTemp"
exit /b

:do_show
    echo [信息]: 正在查找最近的 CSV 日志...
    pushd "%MODULE_OUT_DIR%\whatsTemp"
    :: 按时间顺序寻找最新的 csv 文件
    for /f "delims=" %%i in ('dir /b /od *.csv 2^>nul') do set "LATEST_CSV=%%i"
    if not "!LATEST_CSV!" == "" (
        echo [操作]: 正在打开 !LATEST_CSV!
        start "" "!LATEST_CSV!"
    ) else (
        echo [错误]: 未发现 CSV 日志文件，请先执行 "power wt pull"
    )
    popd
exit /b

:do_guide
    set "GUIDE_PATH=%SCRIPT_DIR%WhatsTemp\WhatsTemp_User_Guide.pdf"
    if exist "!GUIDE_PATH!" (
        echo [操作]: 正在打开用户指南...
        start "" "!GUIDE_PATH!"
    ) else (
        echo [错误]: 未找到指南文件: !GUIDE_PATH!
    )
exit /b
