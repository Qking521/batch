@echo off
chcp 65001 >nul
:: ============================================================
:: Author: wangqiang
:: Date:   2026-09-11
:: Desc:   电源测试资源与配置设置
:: Usage:  power set <action>
:: ============================================================
setlocal

set "action=%~2"
set "param1=%~3"

:: 兼容直接调用 power_set.bat <action> 的场景
if /i not "%~1"=="set" if not "%~1"=="" (
    set "action=%~1"
    set "param1=%~2"
)

if "%action%"==""        goto :usage
if /i "%action%"=="-h"   goto :usage
if /i "%action%"=="help" goto :usage

if /i "%action%"=="res"  goto :set_resources

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

:usage
    echo.
    echo 用法: power set ^<命令^>
    echo.
    echo 命令:
    echo   res    推送媒体资源文件到设备 /sdcard/media 目录
    echo   help   显示此帮助信息
    echo.
    echo 示例:
    echo   power set res
    echo.
    exit /b 0
