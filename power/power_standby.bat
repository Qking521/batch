@echo off
chcp 65001 >nul
:: ============================================================
:: Author: WangQiang
:: Date:   2026-08-25
:: Desc:   基础待机电流配置与恢复
:: Usage:  power standby [apply|restore|archive|cmd]
:: ============================================================
setlocal EnableDelayedExpansion

set "ACTION=%~1"

:: 帮助信息拦截
if /i "%ACTION%"=="help" goto :usage
if /i "%ACTION%"=="-h"   goto :usage

if "%ACTION%"=="" set "ACTION=apply"

set "SCRIPT_DIR=%~dp0"
set "SH_SCRIPT=%SCRIPT_DIR%power_standby.sh"
set "ARCHIVE_DIR=%SCRIPT_DIR%power_archive"

if not exist "%SH_SCRIPT%" (
    echo [ERROR] 找不到 shell 脚本: %SH_SCRIPT%
    exit /b 1
)

if not exist "%ARCHIVE_DIR%" mkdir "%ARCHIVE_DIR%"

:: 1. 获取设备型号名称 ro.product.device
set "DEVICE_NAME="
for /f "tokens=1" %%d in ('adb shell "getprop ro.product.device" 2^>nul') do (
    set "DEVICE_NAME=%%d"
)
if "!DEVICE_NAME!"=="" set "DEVICE_NAME=unknown"

set "CONF_FILE=!DEVICE_NAME!_standby_default.conf"
set "LOCAL_CONF=!ARCHIVE_DIR!\!CONF_FILE!"
set "REMOTE_CONF=/data/local/tmp/power_archive/!CONF_FILE!"

if /i "%ACTION%"=="archive" goto :do_archive
if /i "%ACTION%"=="restore" goto :do_restore
if /i "%ACTION%"=="apply"   goto :do_apply
if /i "%ACTION%"=="cmd"     goto :do_cmd

echo [ERROR] 未知参数: %ACTION%
goto :usage

:usage
echo.
echo 用法: power standby [apply^|restore^|archive^|cmd]
echo.
echo 参数:
echo   (无参数)   应用待机功耗测试优化配置（等效 apply）
echo   apply      应用待机功耗测试优化配置
echo   restore    使用 power_archive 中的基准档恢复设备原始配置
echo   archive    从当前设备导出默认配置作为基准档存入 power_archive
echo   cmd        生成所有配置项的完整 adb 命令清单
echo   help / -h  显示此帮助信息
echo.
echo 示例:
echo   power standby
echo   power standby apply
echo   power standby archive
echo   power standby restore
echo   power standby cmd
echo.
exit /b 0

:do_archive
    echo [INFO] 正在采集设备默认待机配置 (Device: !DEVICE_NAME!)...
    adb shell "sh -s archive" < "%SH_SCRIPT%"
    if !ERRORLEVEL! neq 0 (
        echo [ERROR] 设备端生成默认配置失败
        exit /b 1
    )
    echo [INFO] 正在拉取默认配置文件至本地: !LOCAL_CONF!
    adb pull "!REMOTE_CONF!" "!LOCAL_CONF!" >nul 2>&1
    if exist "!LOCAL_CONF!" (
        echo [OK] 默认配置已同步至本地 power_archive
    ) else (
        echo [WARN] 默认配置文件拉取失败
    )
    exit /b 0

:do_apply
    if not exist "!LOCAL_CONF!" (
        echo [INFO] 本地未找到 !CONF_FILE!，正在从设备自动备份初始默认值...
        call :do_archive
    ) else (
        adb shell "mkdir -p /data/local/tmp/power_archive" >nul 2>&1
        adb push "!LOCAL_CONF!" "!REMOTE_CONF!" >nul 2>&1
    )

    echo [INFO] 正在应用待机优化配置...
    adb shell "sh -s apply" < "%SH_SCRIPT%"
    exit /b %ERRORLEVEL%

:do_restore
    if not exist "!LOCAL_CONF!" (
        echo [WARN] 未找到本地默认配置文件，无法恢复。请在恢复出厂后执行 'power standby archive' 生成基准档。
        exit /b 1
    )

    adb shell "mkdir -p /data/local/tmp/power_archive" >nul 2>&1
    adb push "!LOCAL_CONF!" "!REMOTE_CONF!" >nul 2>&1

echo [INFO] 正在恢复待机原始配置...
    adb shell "sh -s restore" < "%SH_SCRIPT%"
    :: 恢复后同时执行删除文件操作，下一次重新生成
    del /f /q !LOCAL_CONF!
    exit /b %ERRORLEVEL%

:do_cmd
    echo [INFO] 正在生成完整 adb 命令清单...
    adb shell "sh -s cmd" < "%SH_SCRIPT%"
    exit /b %ERRORLEVEL%
