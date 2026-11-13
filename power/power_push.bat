@echo off
chcp 65001 >nul
:: ============================================================
:: Author: wangqiang
:: Date:   2026-09-11
:: Desc:   电源测试资源与配置设置
:: Usage:  power push <action>
:: ============================================================
setlocal

set "action=%~2"
set "param1=%~3"

if "%action%"==""        goto :usage
if /i "%action%"=="-h"   goto :usage
if /i "%action%"=="help" goto :usage

if /i "%action%"=="res"  goto :set_resources
if /i "%action%"=="scp"  goto :set_scp

echo [ERROR] 未知命令: %action%
goto :usage

:set_resources
    set "RES_DIR=%~dp0power_resource"
    if not exist "%RES_DIR%" set "RES_DIR=%~dp0power_resources"
    if not exist "%RES_DIR%" (
        echo [ERROR] 找不到媒体资源目录: %~dp0power_resource
        exit /b 1
    )

    echo [INFO] 正在创建设备目标目录 /sdcard/media ...
    adb shell "mkdir -p /sdcard/media"
    if errorlevel 1 (
        echo [ERROR] 创建设备目标目录 /sdcard/media 失败
        exit /b 1
    )

    echo [INFO] 正在推送媒体资源到 /sdcard/media/ ...
    adb push "%RES_DIR%\." /sdcard/media/
    if errorlevel 1 (
        echo [ERROR] 推送媒体资源失败
        exit /b 1
    )

    echo [OK] 媒体资源已成功推送到 /sdcard/media/
    exit /b 0

:set_scp
    :: 1. 依据设备 ro.build.product 拼接 scp 镜像名: <product>_scp.img
    set "RES_DIR=%~dp0power_resource"
    if not exist "%RES_DIR%" set "RES_DIR=%~dp0power_resources"
    if not exist "%RES_DIR%" (
        echo [ERROR] 找不到资源目录: %~dp0power_resource
        exit /b 1
    )

    set "PRODUCT="
    for /f "tokens=*" %%p in ('adb shell getprop ro.build.product 2^>nul') do set "PRODUCT=%%p"
    if "%PRODUCT%"=="" (
        echo [ERROR] 无法获取设备属性 ro.build.product
        exit /b 1
    )

    set "SCP_IMG=%RES_DIR%\%PRODUCT%_scp.img"
    if not exist "%SCP_IMG%" (
        echo [ERROR] 未找到对应的 scp 镜像: %SCP_IMG%
        exit /b 1
    )

    where fastboot >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] 未找到 fastboot，请确认 platform-tools 已加入 PATH
        exit /b 1
    )

    :: 2. 重启进入 bootloader
    echo INFO: 正在重启到 bootloader ...
    adb reboot bootloader

    :: 3. 轮询等待设备进入 fastboot（最长 30s）
    echo INFO: 等待设备进入 fastboot ...
    set "FB_SERIAL="
    for /l %%i in (1,1,30) do (
        if not defined FB_SERIAL (
            for /f "tokens=1" %%d in ('fastboot devices 2^>nul') do set "FB_SERIAL=%%d"
            if not defined FB_SERIAL timeout /t 1 >nul
        )
    )
    if not defined FB_SERIAL (
        echo [ERROR] 等待设备进入 fastboot 超时，请确认设备已进入 bootloader
        exit /b 1
    )
    echo INFO: 设备已连接 (fastboot): %FB_SERIAL%

    :: 4. 拷贝一份临时 scp.img 并烧录
    set "TMP_SCP=%TEMP%\scp.img"
    copy /y "%SCP_IMG%" "%TMP_SCP%" >nul
    echo INFO: 正在烧录 scp: %SCP_IMG%
    fastboot flash scp "%TMP_SCP%"
    if errorlevel 1 (
        echo [ERROR] fastboot flash scp 失败
        del /f /q "%TMP_SCP%" >nul 2>&1
        exit /b 1
    )
    del /f /q "%TMP_SCP%" >nul 2>&1

    :: 5. 重启设备
    echo INFO: 烧录完成，正在重启设备 ...
    fastboot reboot
    exit /b 0

:usage
    echo.
    echo 用法: power push ^<命令^>
    echo.
    echo 命令:
    echo   res    推送媒体资源文件到设备 /sdcard/media 目录
    echo   scp    烧录与设备匹配的 scp 镜像 (^<product^>_scp.img^)
    echo   help   显示此帮助信息
    echo.
    echo 示例:
    echo   power push res
    echo   power push scp
    echo.
    exit /b 0
