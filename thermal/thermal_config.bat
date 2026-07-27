@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for thermal_config.bat
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

:: %1: config
:: %2: cmd (push, pull, etc.)
:: %3: file path

set "CMD=%~2"

:: CONFIG_FILE 是带路径带文件扩展名的config文件，比如C:\Users\king\thermal.conf
:: ~ 是扩展修饰符。它的核心作用是自动去掉参数两侧的引号（如果有的话）。建议在处理路径时始终加上。
set "CONFIG_FILE=%~3"

:: n (name)：提取文件名部分（不含后缀）。x (extension)：提取扩展名部分（含点号）。比如：thermal.conf
set "CONFIG_NAME=%~nx3"

:: 根据第二个参数跳转标签
if /i "!CMD!"=="-h" goto show_help
if /i "!CMD!"=="help" goto show_help
if /i "!CMD!"=="push" goto :config_push
if /i "!CMD!"=="pull" goto :config_pull
if /i "!CMD!"=="decrypt" goto :config_decrypt

:: 没有具体的cmd时，默认显示当前的温升策略
echo Error Unknown CMD: !CMD!
call :config_info
goto show_help
exit /b

:show_help
echo.
echo Usage: therm config [command] [configFile]
echo.
echo Available commands:
echo   push                 - push config file to device according to different platforms.
echo   pull                 - push config file to show according to different platforms.
echo   decrypt              - decrypt config file if need according to different platforms.
echo   -h                   - Show help (alias: help).
echo.
echo Examples:
echo   therm config push thermal.conf
echo   therm config pull
echo.
exit /b

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

:config_info
    echo 当前thermal policy信息:
    for /f "delims=" %%i in ('adb shell cat /data/vendor/thermal/.current_tp') do set "current_tp=%%i"
    if "!current_tp!"=="" ( echo current_tp:UNKNOW ) else ( echo current_tp:!current_tp! )

    for /f "delims=" %%i in ('adb shell cat /data/vendor/thermal/.permanent_tp') do set "permanent_tp=%%i"
    if "!permanent_tp!"=="" ( echo permanent_tp:UNKNOW ) else ( echo permanent_tp:!permanent_tp! )
    exit /b

:config_push
    echo cmd=!CMD!, target=!CONFIG_FILE!, config_name=!CONFIG_NAME!
    echo [操作]: 正在push^&apply %CONFIG_FILE% ...

    if "!thermalHalOwner!"=="mediatek" (
        if not "!CONFIG_FILE!"=="" (
            if not exist "!CONFIG_FILE!" (
                echo [错误]: 配置文件 "!CONFIG_FILE!" 不存在。
                exit /b 1
            )
            :: 导入策略
            adb root
            adb remount
            adb push "!CONFIG_FILE!" /vendor/etc/thermal/
            :: 应用策略
            adb shell "thermal_intf apply !CONFIG_NAME!"
            :: 显示应用后的策略
            call :config_info
        ) else (
            echo [错误]: MTK 平台推送需要指定文件路径。
        )
    )

    if "!thermalHalOwner!"=="pixel" (
        if not "!CONFIG_FILE!"=="" (
            if not exist "!CONFIG_FILE!" (
                echo [错误]: 配置文件 "!CONFIG_FILE!" 不存在。
                exit /b 1
            )
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
    set MTK_THERMAL_DECRYPT=%SCRIPT_DIR%thermal_decrypt_mtk.bat
    if "!thermalHalOwner!"=="mediatek" (
        if exist "%MTK_THERMAL_DECRYPT%" (
            call "%MTK_THERMAL_DECRYPT%"
        ) else (
            echo [错误]: 未找到解密脚本 "%MTK_THERMAL_DECRYPT%"
            exit /b 1
        )
    )
    exit /b