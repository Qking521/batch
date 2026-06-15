@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "PACKAGE_NAME=com.example.mtk10263.whatsTemp"
adb shell pm list packages %PACKAGE_NAME% | findstr "%PACKAGE_NAME%" >nul
if !errorlevel! equ 0 goto :check_args
echo [提示]: 未检测到 WhatsTemp 应用，正在为您执行安装程序... 
goto :do_install

:check_args
:: 参数跳转逻辑
if "%~1"=="" goto :show_help
if /i "%~1"=="help" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="install" goto :do_install
if /i "%~1"=="start" goto :do_start
if /i "%~1"=="stop" goto :do_stop
if /i "%~1"=="pull" goto :do_pull
if /i "%~1"=="config" goto :do_config
if /i "%~1"=="show" goto :do_show
if /i "%~1"=="guide" goto :do_guide

echo [错误]: 未知指令 "%1"
goto :show_help

:show_help
echo WhatsTemp 控制工具
echo =======================
echo 用法: power wt [command]
echo 可用命令: 
echo   install  - 安装 WhatsTemp 并配置权限.
echo   start    - 启动 WhatsTemp 服务并开启采集.
echo   stop     - 停止 WhatsTemp 采集服务.
echo   pull     - 停止服务并从设备拉取温度日志.
echo   config   - 从设备拉取 tool.config 配置文件.
echo   show     - 使用 Excel 查看最近拉取的 CSV 日志.
echo   guide    - 打开 WhatsTemp 用户使用指南 (PDF).
echo   help     - 显示此帮助信息.
echo.
exit /b

:do_install
:: 调用现有的安装脚本
call "%SCRIPT_DIR%power_installs.bat" wt
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
echo OUT_DIR = %OUT_DIR%
:: 先清理本地已存在的目录，防止 adb pull 产生嵌套
if exist "%OUT_DIR%\whatsTemp" rd /s /q "%OUT_DIR%\whatsTemp"
:: 确保父目录存在
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
:: 直接拉取文件夹。因为本地 whatsTemp 不存在，ADB 会将远程 log 文件夹的内容直接放入新建的 whatsTemp 中
adb pull /sdcard/WhatsTemp/log "%OUT_DIR%\whatsTemp"
adb shell rm /sdcard/WhatsTemp/log/*
if exist "%OUT_DIR%\whatsTemp" start "" "%OUT_DIR%\whatsTemp"
exit /b

:do_config
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
adb pull /sdcard/WhatsTemp/tool.config %OUT_DIR%\whatsTemp\tool.config
start "" "%OUT_DIR%\whatsTemp"
exit /b

:do_show
echo [信息]: 正在查找最近的 CSV 日志...
pushd "%OUT_DIR%\whatsTemp"
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
