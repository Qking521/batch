@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "CONFIG_FILE=%~1"
:: 获取文件名及后缀，如:thermal_config_info.json
set "CONFIG_NAME=%~nx1"
if not "!CONFIG_FILE!"=="" echo [信息]: 目标配置文件: !CONFIG_FILE!

:: 尝试获取 thermal service 进程名
:: Use ps -A for better compatibility, filtering android.hardware.thermal-service
for /f "tokens=*" %%i in ('adb shell "ps -A | grep -o \"android.hardware.thermal-service\.[^ ]*\""') do (
    set "thermal_service=%%i"
)

if "%thermal_service%"=="" (
    echo [错误]: 未能识别到符合 android.hardware.thermal-service.* 格式的服务。
    echo 尝试原始输出:
    adb shell "ps -A | grep thermal"
    exit /b 1
)

echo [信息]: 检测到温控服务: %thermal_service%

:: 提取后缀进行跳转
echo %thermal_service% | findstr /i "mediatek" >nul && goto :mediatek
echo %thermal_service% | findstr /i "pixel" >nul && goto :pixel
echo %thermal_service% | findstr /i "qcom" >nul && goto :qcom

echo [警告]: 识别到服务，但未匹配到预设厂商标签。
exit /b 0

:mediatek
echo [平台]: 进入 MediaTek 配置逻辑
if not "!CONFIG_FILE!"=="" (
    echo [操作]: 准备处理 MTK 配置文件: !CONFIG_FILE!
    :: TODO: 添加 push 文件或解析文件的 adb 命令
)
exit /b

:pixel
echo [平台]: 进入 Google Pixel 配置逻辑
if "!CONFIG_FILE!"=="" (
    echo [错误]: Pixel 平台需要提供配置文件路径。
    exit /b 1
)

echo [操作]: 正在推送并应用 Pixel 配置文件: "!CONFIG_FILE!"
    adb root
    adb remount
    adb push "!CONFIG_FILE!" /vendor/etc/
    adb shell setprop vendor.thermal.config "!CONFIG_NAME!"
    adb shell "stop vendor.thermal-hal && start vendor.thermal-hal"
    adb shell "ps -A | grep thermal"
exit /b

:qcom
echo [平台]: 进入 Qualcomm 配置逻辑
if not "!CONFIG_FILE!"=="" (
    echo [操作]: 准备处理 QCOM 配置文件: !CONFIG_FILE!
)
exit /b

:pixecl
:: 兼容拼写错误
goto :pixel