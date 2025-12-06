@echo off
setlocal EnableDelayedExpansion

:: Set code page to GBK for Chinese support
chcp 65001  >nul
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
for /f "delims=" %%A in ('adb shell getprop ^| findstr %SEARCH_PATTERN%') do (
	echo prop: %%A
)
endlocal