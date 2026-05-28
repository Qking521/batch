@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: %1: config
:: %2: action (push, pull, etc.)
:: %3: file path

set "ACTION=%~2"
set "CONFIG_FILE=%~3"
:: ~：扩展修饰符。它的核心作用是自动去掉参数两侧的引号（如果有的话）。这是一个非常安全的操作，建议在处理路径时始终加上。,n (name)：提取文件名部分（不含后缀）。x (extension)：提取扩展名部分（含点号）。
set "CONFIG_NAME=%~nx3"

:: 预先提取 thermal service Owner信息，供全局共用
set "thermalHalOwner="
for /f "tokens=4 delims=." %%i in ('adb shell "ps -A | grep -oE \"android\.hardware\.thermal-service\.[a-z0-9]+\""') do (
    set "thermalHalOwner=%%i"
    echo ThermalHalOwner: !thermalHalOwner!
)

if "!thermalHalOwner!"=="" (
    echo [错误]: 未能识别到 Android Thermal HAL 服务。
    exit /b 1
)

:: 根据第二个参数跳转标签
if  /i "!ACTION!"=="push" goto :config_push
if  /i "!ACTION!"=="pull" goto :config_pull
if  /i "!ACTION!"=="decrypt" goto :config_decrypt

echo [错误]: 未知的配置操作: !ACTION!
exit /b 1

:config_push
    echo action=!ACTION!, target=!CONFIG_FILE!, config_name=!CONFIG_NAME!
    echo [操作]: 正在push^&apply %CONFIG_FILE% ...

    if "!thermalHalOwner!"=="mediatek" (
        if not "!CONFIG_FILE!"=="" (
            :: 导入策略
            adb root
            adb remount
            adb push "!CONFIG_FILE!" /vendor/etc/thermal/
            :: 应用策略
            adb shell "thermal_intf apply !CONFIG_NAME!"
            :: 显示应用后的策略
            adb shell cat /data/vendor/thermal/.current_tp
        ) else (
            echo [错误]: MTK 平台推送需要指定文件路径。
        )
    )

    if "!thermalHalOwner!"=="pixel" (
        if not "!CONFIG_FILE!"=="" (
            adb root
            adb remount
            adb push "!CONFIG_FILE!" /vendor/etc/
            adb shell setprop vendor.thermal.config "%CONFIG_NAME%"
            adb shell "stop vendor.thermal-hal && start vendor.thermal-hal"
            echo "adb shell ps -A | grep thermal"
            adb shell "ps -A | grep thermal"
        ) else (
            echo [错误]: pixel 平台推送需要指定文件路径。
        )
    )

    if "!thermalHalOwner!"=="qcom" (
        echo [操作]: QCOM 推送逻辑待实现
    )

    exit /b

:config_pull
    for /f "delims= " %%a in ('adb shell getprop ro.product.board') do set model=%%a
    set "OUT_DIR=!OUT_DIR!\thermal_config\%model%_%format_time%" 
    echo config out path=%OUT_DIR%
    if not exist %OUT_DIR% (
	    mkdir %OUT_DIR%
    )

    if "!thermalHalOwner!"=="mediatek" (
        adb pull vendor/etc/thermal/ %OUT_DIR%
        start %OUT_DIR%
    )

    if "!thermalHalOwner!"=="pixel" (
        adb pull vendor/etc/thermal_info_config.json %OUT_DIR%
        start %OUT_DIR%
    )
    exit /b

:config_decrypt
    echo SCRIPT_DIR=%SCRIPT_DIR%
    if "!thermalHalOwner!"=="mediatek" (
        call "%SCRIPT_DIR%power_mtk_thermal_decrypt.bat"
    )
    exit /b