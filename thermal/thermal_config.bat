@echo off
:: ============================================================
:: Author: WangQiang
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
if /i "!CMD!"=="policy" goto :config_policy
if /i "!CMD!"=="push" goto :config_push
if /i "!CMD!"=="pull" goto :config_pull
if /i "!CMD!"=="decrypt" goto :config_decrypt

:: 没有具体的cmd时，默认显示当前的温升策略
goto show_help
exit /b

:show_help
echo.
echo Usage: therm config [command] [configFile]
echo.
echo Available commands:
echo   policy               - show thermal config info
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


:: 获取 thermal service Owner信息（qcom/mediatek/pixel），供各标签共用
:get_thermal_hal_owner
    set "thermalHalOwner=pixel"

    adb shell ps | findstr /i "thermal-engine" >nul && set "thermalHalOwner=qcom"
    adb shell ps | findstr /i "thermal_core"   >nul && set "thermalHalOwner=mediatek"

    echo thermalHalOwner=%thermalHalOwner%

    if "!thermalHalOwner!"=="" (
        echo [错误]: 未能识别到 Android Thermal HAL 服务。
        exit /b 1
    )
    exit /b 0

:config_policy
    echo 当前thermal policy信息:
    for /f "delims=" %%i in ('adb shell cat /data/vendor/thermal/.current_tp') do set "current_tp=%%i"
    if "!current_tp!"=="" ( echo current_tp:UNKNOW ) else ( echo current_tp:!current_tp! )

    for /f "delims=" %%i in ('adb shell cat /data/vendor/thermal/.permanent_tp') do set "permanent_tp=%%i"
    if "!permanent_tp!"=="" ( echo permanent_tp:UNKNOW ) else ( echo permanent_tp:!permanent_tp! )
    exit /b

:config_push
    call :get_thermal_hal_owner
    echo cmd=!CMD!, target=!CONFIG_FILE!, config_name=!CONFIG_NAME!
    echo [操作]: 正在push^&apply %CONFIG_FILE% ...

    if "!thermalHalOwner!"=="mediatek" (
        if not "!CONFIG_FILE!"=="" (
            if not exist "!CONFIG_FILE!" (
                echo [错误]: 配置文件 "!CONFIG_FILE!" 不存在。
                exit /b 1
            )
            :: 导入策略
            call :remount
            adb push "!CONFIG_FILE!" /vendor/etc/thermal/
            :: 应用策略
            adb shell "thermal_intf apply !CONFIG_NAME!"
            :: 显示应用后的策略
            call :config_policy
        ) else (
            echo [错误]: MTK 平台推送需要指定文件路径。
        )
    )

    if "!thermalHalOwner!"=="qcom" (
        if not "!CONFIG_FILE!"=="" (
            if not exist "!CONFIG_FILE!" (
                echo [错误]: 配置文件 "!CONFIG_FILE!" 不存在。
                exit /b 1
            )
            call :remount
            adb push "!CONFIG_FILE!" vendor/etc/
            adb shell stop thermal-engine-v2
            adb shell start thermal-engine-v2
            echo "adb shell ps -A | grep thermal"
            adb shell "ps -A | grep thermal"
        ) else (
            echo [错误]: qcom 平台推送需要指定文件路径。
        )
    )

    if "!thermalHalOwner!"=="pixel" (
        if not "!CONFIG_FILE!"=="" (
            if not exist "!CONFIG_FILE!" (
                echo [错误]: 配置文件 "!CONFIG_FILE!" 不存在。
                exit /b 1
            )
            call :remount
            adb push "!CONFIG_FILE!" /vendor/etc/
            adb shell setprop vendor.thermal.config "%CONFIG_NAME%"
            adb shell "stop vendor.thermal-hal && start vendor.thermal-hal"
            echo "adb shell ps -A | grep thermal"
            adb shell "ps -A | grep thermal"
        ) else (
            echo [错误]: pixel 平台推送需要指定文件路径。
        )
    )
    exit /b 0

:config_pull
    call :get_thermal_hal_owner
    for /f "delims= " %%a in ('adb shell getprop ro.product.board') do set model=%%a
    set "MODULE_OUT_DIR=!MODULE_OUT_DIR!\thermal_config_%model%_%format_time%"
    echo config out path=%MODULE_OUT_DIR%
    if not exist %MODULE_OUT_DIR% (
	    mkdir %MODULE_OUT_DIR%
    )

    if "!thermalHalOwner!"=="mediatek" (
        adb pull "vendor/etc/thermal/." %MODULE_OUT_DIR%
        start %MODULE_OUT_DIR%
    )

    if "!thermalHalOwner!"=="qcom" (
        adb pull vendor/etc/thermal-engine.conf %MODULE_OUT_DIR%
        start %MODULE_OUT_DIR%
    )
    if "!thermalHalOwner!"=="pixel" (
        adb pull vendor/etc/thermal_info_config.json %MODULE_OUT_DIR%
        start %MODULE_OUT_DIR%
    )
    exit /b

:config_decrypt
    call :get_thermal_hal_owner
    set "MTK_THERMAL_DECRYPT=%SCRIPT_DIR%thermal_decrypt_mtk.bat"
    if "!thermalHalOwner!"=="mediatek" (
        if exist "%MTK_THERMAL_DECRYPT%" (
            call "%MTK_THERMAL_DECRYPT%"
        ) else (
            echo [错误]: 未找到解密脚本 "%MTK_THERMAL_DECRYPT%"
            exit /b 1
        )
    )
    exit /b

:: remount 操作（静默执行，不显示中间结果）
:remount
(
    adb root
    adb remount -R
    adb wait-for-device
    adb root
    adb remount -R
    adb wait-for-device
) >nul 2>&1
    exit /b 0