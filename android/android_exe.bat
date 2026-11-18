@echo off
:: ============================================================
:: Author: wangqiang
:: Date:   2026-11-18
:: Desc:   Android 设备执行动作集合, 由 android_all.bat exe 调用
:: Usage:  ad exe <action> [args...]
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

set "action=%~1"
set "param1=%~2"

if "%action%"==""        goto :usage
if /i "%action%"=="-h"   goto :usage
if /i "%action%"=="help" goto :usage

if /i "%action%"=="clear" goto :clear_log
if /i "%action%"=="st"    goto :sync_time
if /i "%action%"=="bind"  goto :bind
if /i "%action%"=="skip"  goto :skip_wizard

echo [ERROR] Unknown action: %action%
goto :usage

:usage
echo.
echo Usage: ad exe ^<action^>
echo.
echo Available actions:
echo   clear          - Clear logcat and dmesg logs
echo   st [timezone]  - Sync pc time to device via adb
echo   bind           - Bind connected device (set ANDROID_SERIAL ^& title)
echo   skip           - Skip setup wizard
echo.
exit /b 0

:clear_log
    adb root
    adb shell "logcat -b all -c; dmesg -C"
    echo [OK] Logcat and dmesg cleared.
    exit /b 0

:sync_time
    call "%~dp0android_sync_time.bat" %param1%
    exit /b %ERRORLEVEL%

:bind
    set "DEV_TMP=%TEMP%\ad_bind_devices.tmp"
    adb devices > "%DEV_TMP%" 2>nul
    set "SERIAL="
    set /a DEV_COUNT=0
    for /f "usebackq tokens=1,2" %%a in ("%DEV_TMP%") do (
        if /i "%%b"=="device" set /a DEV_COUNT+=1
    )

    if !DEV_COUNT!==0 (
        echo [ERROR] No device connected.
        type "%DEV_TMP%"
        del "%DEV_TMP%" >nul 2>&1
        exit /b 1
    )

    if !DEV_COUNT!==1 (
        for /f "usebackq tokens=1,2" %%a in ("%DEV_TMP%") do (
            if /i "%%b"=="device" if "!SERIAL!"=="" set "SERIAL=%%a"
        )
    ) else (
        echo.
        echo Multiple devices detected, please choose one to bind:
        set /a N=0
        for /f "usebackq tokens=1,2" %%a in ("%DEV_TMP%") do (
            if /i "%%b"=="device" (
                set /a N+=1
                echo     [!N!] %%a
            )
        )
        echo.
        set /p "SEL=Enter index to bind [1-!DEV_COUNT!]: "
        set /a N=0
        for /f "usebackq tokens=1,2" %%a in ("%DEV_TMP%") do (
            if /i "%%b"=="device" (
                set /a N+=1
                if !N!==!SEL! set "SERIAL=%%a"
            )
        )
    )

    del "%DEV_TMP%" >nul 2>&1

    if "%SERIAL%"=="" (
        echo [ERROR] Invalid selection or device not found.
        exit /b 1
    )

    title %SERIAL%
    echo [OK] ANDROID_SERIAL=%SERIAL%
    endlocal & set "ANDROID_SERIAL=%SERIAL%"
    exit /b 0

:skip_wizard
    adb shell settings put global device_provisioned 1
    adb shell settings put secure user_setup_complete 1
    echo [OK] Setup wizard skipped, device rebooting.
    adb reboot
    exit /b 0
