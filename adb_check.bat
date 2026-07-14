@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

goto adb_exist_check

:: 检查 ADB 是否可用
:adb_exist_check
where adb >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo 错误: 未找到 ADB 命令。
    exit /b 1
)

:: 检查 adb 是否能执行
:adb_avaiable_check
adb version >nul 2>&1
if errorlevel 1 (
    echo adb 无法执行，请检查环境
    exit /b 1
)

:: 检查是否有设备连接
:device_exist_check
adb get-state >nul 2>&1
if errorlevel 1 (
    echo 没有设备连接
    exit /b 1
)

echo ADB检测成功：环境正常且设备已连接。

:: 检查设备是否有root权限
:adb_root
adb shell "id" 2>nul | findstr "uid=0" >nul 2>&1
if %errorlevel% neq 0 (
    adb root >nul 2>&1
)
