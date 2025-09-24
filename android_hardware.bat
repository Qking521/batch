@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
:: 获取当前脚本所在目录
set "SCRIPT_DIR=%~dp0"

echo 正在获取硬件信息...

:: 获取平台信息
echo 平台信息：
for /f "tokens=2" %%i in ('adb shell getprop ro.board.platform') do set platform=%%i
echo %platform%
echo.

:: 获取 RAM 大小并转换为 GB
echo RAM 总大小：
for /f "tokens=2" %%i in ('adb shell cat /proc/meminfo ^| findstr MemTotal') do set ram=%%i
:: 将 KB 转换为 GB（除以 1048576，即 1024*1024）
set /a ram_gb=%ram% / 1048576
echo %ram_gb%GB
echo.

:: 获取 ROM 大小并转换为 GB
echo ROM 总大小：
for /f "tokens=2" %%i in ('adb shell df /data ^| findstr /v Filesystem') do set rom=%%i
:: 将 KB 转换为 GB
set /a rom_gb=%rom% / 1048576
echo %rom_gb%GB
echo.

echo 获取完成！
pause