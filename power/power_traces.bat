@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

set "cmd=%~1"
set "param1=%~2"
set "param2=%~3"

call :trace_processor_check
if errorlevel 1 exit /b 1

if "%cmd%"=="" goto :usage
if /i "%cmd%"=="-h" goto :usage
if /i "%cmd%"=="help" goto :usage
if /i "%cmd%"=="ui" goto :do_ui
if /i "%cmd%"=="local" goto :do_local

echo [ERROR] 未知命令: %cmd%
goto :usage

:usage
echo.
echo 用法: power analyze ^<open^|sql^> [tag/sql_statement/file_path] [bugreport_path]
echo.
echo 命令:
echo   ui [bugreport_path]              - 使用perfetto打开指定的或 OUT\android 目录下最新的 bugreport zip 文件
echo   local [bugreport_path]           - 使用本地trace_processor_shell打开 指定的或OUT\android 目录下最新的 bugreport zip 文件
echo   help / -h                        - 显示此帮助信息
echo.
echo 示例:
echo   power trace ui
echo   power trace local
echo   power trace ui [bugreport路径]
echo.
exit /b 0

:trace_processor_check

exit /b 0

:find_target_bugreport
    :: %~1 为传入的自定义 bugreport 路径
    set "CUSTOM_PATH=%~1"
    set "TARGET_BUGREPORT="

    if not "%CUSTOM_PATH%"=="" (
        if exist "%CUSTOM_PATH%" (
            set "TARGET_BUGREPORT=%CUSTOM_PATH%"
            echo [INFO] 使用指定的 bugreport: %TARGET_BUGREPORT%
            exit /b 0
        ) else (
            echo [WARN] 指定的路径不存在: %CUSTOM_PATH%，准备自动查找最新文件...
        )
    )

    set "TARGET_DIR=%BASE_OUT_DIR%android"
    if not exist "%TARGET_DIR%" (
        echo [ERROR] 目标目录不存在: %TARGET_DIR%
        exit /b 1
    )

    for /f "delims=" %%F in ('dir /b /a-d /o-d "%TARGET_DIR%\bugreport_*.zip" 2^>nul') do (
        if not defined TARGET_BUGREPORT set "TARGET_BUGREPORT=%TARGET_DIR%\%%F"
    )

    if "%TARGET_BUGREPORT%"=="" (
        echo [ERROR] 未在 %TARGET_DIR% 目录下找到 bugreport_*.zip 文件
        exit /b 1
    )
    echo [INFO] 使用自动找到的最新的 bugreport: %TARGET_BUGREPORT%
exit /b 0

:do_ui
    call :find_target_bugreport "%param1%"
    if errorlevel 1 exit /b 1

    set GOOGLE_OPEN_TRACE_FILE=%OUT_DIR%\open_trace_in_ui
    echo GOOGLE_OPEN_TRACE_FILE=%GOOGLE_OPEN_TRACE_FILE%
    if not exist "%GOOGLE_OPEN_TRACE_FILE%" (
        curl -L -f -o %GOOGLE_OPEN_TRACE_FILE% https://raw.githubusercontent.com/google/perfetto/main/tools/open_trace_in_ui
        if %errorlevel% neq 0 (
            echo 下载失败！请检查网络/代理设置。
            pause
            exit /b 1
        )
        copy /Y "%GOOGLE_OPEN_TRACE_FILE%" .
    )
    echo [INFO] 正在启动 perfetto UI打开bugreport...
    python %GOOGLE_OPEN_TRACE_FILE% -i %TARGET_BUGREPORT%
exit /b 0

:do_local
    set "TRACE_PROCESSOR_SHELL=%SCRIPT_DIR%..\performance\google_perfetto_tools\trace_processor_shell.exe"
    if not exist "%TRACE_PROCESSOR_SHELL%" (
        echo [ERROR] 找不到 trace_processor_shell.exe
        exit /b 1
    )

    call :find_target_bugreport "%param1%"
    if errorlevel 1 exit /b 1

    echo [INFO] 正在启动 trace_processor_shell 交互式命令行...
    "%TRACE_PROCESSOR_SHELL%" "%TARGET_BUGREPORT%"
exit /b 0

