@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for android_all.bat
:: Usage: ad [command] [args...]
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

call %INIT_BAT% %~dp0
:: 调用基础脚本检查ADB和设备（使用完整路径）
call "%ADB_CHECK_BAT%"
if %ERRORLEVEL% neq 0 (
    echo [错误]: 基础检测失败，退出操作。
    exit /b %ERRORLEVEL%
)

:: 创建Android的out目录
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

set "cmd=%1"
set "param1=%2"
set "param2=%3"

if "%cmd%"=="" goto show_help
if /i "%cmd%"=="-h" goto show_help
if /i "%cmd%"=="help" goto show_help
if /i "%cmd%"=="top" goto current_activity
if /i "%cmd%"=="ss" goto screen_shot
if /i "%cmd%"=="sr" goto screen_record
if /i "%cmd%"=="kill" goto kill_process
if /i "%cmd%"=="bugreport" goto bugreport
if /i "%cmd%"=="clear" goto clear_log
if /i "%cmd%"=="dev" goto developer
if /i "%cmd%"=="di" goto device_info
if /i "%cmd%"=="search" goto android_search
if /i "%cmd%"=="monkey" goto monkey
if /i "%cmd%"=="enable" goto package_toggle
if /i "%cmd%"=="disable" goto package_toggle
if /i "%cmd%"=="dump" goto dump
if /i "%cmd%"=="rr" goto refresh_rate
if /i "%cmd%"=="adbd" goto adb_helper

echo Unknown command: %cmd%
goto show_help

:show_help
echo.
echo Usage: ad [command] [args...]
echo.
echo Available commands:
echo   top                      - 显示当前运行的 Activity / 界面焦点信息.
echo   ss                       - 快速截图并保存/打开.
echo   sr                       - 录屏并提取到本地.
echo   kill [process_name]      - 杀掉指定进程名的进程.
echo   bugreport                - 抓取/提取 bugreport 日志.
echo   clear                    - 清除系统 logcat 和 dmesg 日志.
echo   dev [on/off]             - 开启/关闭开发者调试辅助开关（显示触摸点、指针位置等）.
echo   di                       - 获取设备基础信息并输出.
echo   search [keyword]         - 检索系统 Settings 和 Properties 属性项.
echo   monkey [pkg/kill/num]    - 运行或停止 Monkey 测试.
echo   enable/disable [pkg]     - 启禁用指定的 Package 应用包.
echo   dump [service] [params]  - Dump 指定系统服务状态到 OUT 目录.
echo   rr [on/off]              - 设置/查询屏幕刷新率 (SurfaceFlinger).
echo   adbd [restart/root...]   - ADB 工具/状态配置辅助.
echo   -h                       - 显示帮助信息 (别名: help).
echo.
echo Examples:
echo   ad top
echo   ad dev on
echo   ad rr 120
echo.
exit /b 0

:current_activity
adb shell dumpsys window | grep mCurrentFocus
exit /b 0

:bugreport
call "%SCRIPT_DIR%android_bugreport.bat" %~2
exit /b 0

:adb_helper
call "%SCRIPT_DIR%android_adb_helper.bat" %~2
exit /b 0

:clear_log
adb root
adb shell "logcat -b all -c; dmesg -C"
echo 系统 log 清理完成
exit /b 0

:screen_shot
set "shot_file=screenshot_%FORMAT_TIME%.png"
adb shell screencap -p /sdcard/%shot_file%
adb pull /sdcard/%shot_file% "%OUT_DIR%"
adb shell "rm -rf /sdcard/%shot_file%"
start "" "%OUT_DIR%\%shot_file%"
exit /b 0

:screen_record
call "%SCRIPT_DIR%android_screen_record.bat" %~2
exit /b %ERRORLEVEL%

:kill_process
if "%~2"=="" (
    echo [错误]: 请指定需要 kill 的进程关键字。
    exit /b 1
)
adb shell "ps -A | grep %~2"
adb shell "kill -9 $(ps -A | grep %~2 | grep -v grep | awk '{print $2}')"
adb shell "ps -A | grep %~2"
exit /b 0

:developer
if "%~2"=="" (
    echo 用法: ad dev [on/off]
    exit /b 1
)
if /i "%~2"=="on" (
    adb shell settings put system show_touches 1
    adb shell settings put system pointer_location 1
    adb shell settings put secure clock_seconds 1
    echo 开发者调试辅助（触摸点/指针/时钟秒数）已开启。
)
if /i "%~2"=="off" (
    adb shell settings put system show_touches 0
    adb shell settings put system pointer_location 0
    adb shell settings put secure clock_seconds 0
    echo 开发者调试辅助（触摸点/指针/时钟秒数）已关闭。
)
exit /b 0

:device_info
call "%SCRIPT_DIR%android_device_info.bat"
exit /b 0

:android_search
set "SH_SCRIPT=%SCRIPT_DIR%android_search.sh"
adb shell "sh -s %param1%" < "%SH_SCRIPT%"
exit /b 0

:monkey
if "%~2"=="" (
    adb shell monkey --throttle 200 --ignore-crashes --ignore-timeouts --ignore-security-exceptions --monitor-native-crashes -v -v -v 1000000
    exit /b 0
)
set "pkg_prefix=%~2"
if "%pkg_prefix:~0,3%"=="com" (
    adb shell monkey -p %~2 --throttle 200 --ignore-crashes --ignore-timeouts --ignore-security-exceptions --monitor-native-crashes -v -v -v 1000000
)
if /i "%~2"=="kill" (
    for /f "delims=" %%p in ('adb shell pidof com.android.commands.monkey') do (
        adb shell kill -9 %%p
    )
)
exit /b 0

:package_toggle
set "SH_SCRIPT=%SCRIPT_DIR%android_package_toggle.sh"
if not exist "%SH_SCRIPT%" (
    echo [错误]: 找不到 Shell 业务层脚本: %SH_SCRIPT%
    exit /b 1
)
adb shell "sh -s %cmd% %param1%" < "%SH_SCRIPT%"
exit /b %ERRORLEVEL%

:refresh_rate
set "SH_SCRIPT=%SCRIPT_DIR%android_refresh_rate.sh"
adb shell "sh -s %param1% %param2%" < "%SH_SCRIPT%"
exit /b 0

:dump
set "service=%~2"
set "service_param=%~3"
if "%service%"=="" (
    echo 用法: ad dump [service_name] [optional_params]
    exit /b 1
)
if "%service_param%"=="" (
    adb shell dumpsys %service% > "%OUT_DIR%\%service%.txt"
) else (
    adb shell dumpsys %service% %service_param% > "%OUT_DIR%\%service%.txt"
)
start "" "%OUT_DIR%\%service%.txt"
exit /b 0