@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 检查 ADB 是否可用
where adb >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo 错误: 未找到 ADB 命令。
    set ERR=1
    goto end
)

:: 检查设备连接
set "device_found=0"
for /f "tokens=*" %%a in ('adb devices ^| findstr /r /v "List"') do (
    set "device_line=%%a"
    if not "!device_line!"=="" (
        echo !device_line! | findstr /C:"device" >nul 2>nul
        if !ERRORLEVEL! equ 0 (
            set "device_found=1"
        )
    )
)

if "!device_found!"=="0" (
    echo 错误: ADB检测失败，设备未连接或设备未授权。
    set ERR=2
    goto end
)

echo ADB检测成功：环境正常且设备已连接。

:: 检查设备是否有root权限
adb shell "id" 2>nul | findstr "uid=0" >nul 2>&1
if %errorlevel% neq 0 (
    adb root >nul 2>&1
)
set ERR=0

:end
endlocal & exit /b %ERR%
