@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-08-26
:: Description: 检查设备端 /data/dhrystone.sh 是否存在，不存在时自动 push
:: ============================================================
chcp 65001 >nul
setlocal

:: 检查设备端 /data/dhrystone.sh 是否存在，不存在时自动 push 安装
set "FILE_CHECK="
for /f "usebackq delims=" %%r in (`adb shell "[ -f /data/dhrystone.sh ] && echo EXIST || echo NOTEXIST"`) do (
    set "FILE_CHECK=%%r"
)
if "%FILE_CHECK%"=="NOTEXIST" (
    echo [INFO] 检测到设备端缺少 Dhrystone 文件，正在执行安装...
    pushd "%SCRIPT_DIR%dhrystone"
    call install_dhrystone_64.bat
    popd
    echo [INFO] 安装完成
)
exit /b 0

