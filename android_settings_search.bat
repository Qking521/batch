@echo off
setlocal EnableDelayedExpansion

:: Set code page to GBK for Chinese support
chcp 65001  >nul

:: 获取当前脚本所在目录
set "SCRIPT_DIR=%~dp0"

:: 先调用基础脚本检查ADB和设备（使用完整路径）
call "%SCRIPT_DIR%adb_check.bat"
if %ERRORLEVEL% neq 0 (
    echo [错误]: 基础检测失败，退出操作。
    exit /b %ERRORLEVEL%
)

if "%~1"=="" (
    echo Usage: %0 ^<search_pattern^>
    exit /b 1
)

set "SEARCH_PATTERN=%1"

echo SEARCH_PATTERN = %SEARCH_PATTERN%

:: 查询三个数据库并进行模糊匹配
for %%d in (system secure global) do (
    adb shell settings list %%d 2>nul | findstr /i "%SEARCH_PATTERN%" >temp_%%d.txt 2>nul
    if exist temp_%%d.txt (
        for /f "usebackq delims=" %%i in ("temp_%%d.txt") do (
            echo %%d:%%i
        )
        del temp_%%d.txt
    )
)

endlocal