@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

set "cmd=%~2"
set "param1=%~3"
set "param2=%~4"

call :evn_init
if errorlevel 1 exit /b 1

if "%cmd%"=="" goto show_help
if /i "%cmd%"=="-h" goto show_help
if /i "%cmd%"=="help" goto show_help
if /i "%cmd%"=="cmd" goto do_command
if /i "%cmd%"=="online" goto do_online
if /i "%cmd%"=="cfg" goto do_config
if /i "%cmd%"=="ui" goto do_ui
if /i "%cmd%"=="ui-enhance" goto do_ui_enhance
if /i "%cmd%"=="sh" goto do_shell
if /i "%cmd%"=="tool" goto do_tool

echo [ERROR] 未知命令: %cmd%
goto show_help

:show_help
echo.
echo 用法: perf trace ^<command^> [params...]
echo.
echo 抓取 Trace 命令:
echo   cmd [时长(s)]                    - 使用命令抓取 trace (默认 5 秒)
echo   online [时长(s)]                 - 使用谷歌封装的 record_android_trace 抓取 trace
echo   cfg [时长(s)]                    - 使用 trace 配置文件抓取 trace
echo.
echo 打开 Trace 命令:
echo   ui [trace_path]                  - 使用 perfetto 打开指定的或 OUT 目录下最新的 trace 文件
echo   ui-enhance [trace_path]          - 使用 perfetto 本地服务打开指定的或 OUT 目录下最新的 trace 文件
echo   sh [trace_path]                  - 使用本地 trace_processor_shell 打开指定的或 OUT 目录下最新的 trace 文件
echo.
echo 其他命令:
echo   tool                             - 下载更新 trace 相关工具
echo   help / -h                        - 显示此帮助信息
echo.
echo 示例:
echo   perf trace cmd 5
echo   perf trace ui
echo   perf trace ui-enhance trace_oaklan_0813-2027.perfetto
echo   perf trace sh
echo.
exit /b 0

:evn_init
    set "model=device"
    for /f "delims= " %%a in ('adb shell getprop ro.product.board 2^>nul') do set "model=%%a"
    set "TRACE_FILE=trace_%model%_%format_time%.perfetto"
    set "OUT_TRACE_FILE=%MODULE_OUT_DIR%\%TRACE_FILE%"

    set "GOOGLE_OPEN_TRACE_FILE=%SCRIPT_DIR%perfetto_tools\open_trace_in_ui"
    set "TRACE_PROCESSOR_SHELL=%SCRIPT_DIR%perfetto_tools\trace_processor_shell.exe"
    set "GOOGLE_RECORD_TRACE_FILE=%SCRIPT_DIR%perfetto_tools\record_android_trace"

    set "SQL_DIR=%SCRIPT_DIR%perf_sql"

    set "record_time=%param1%"
    if "%record_time%"=="" (
        set "record_time=5"
    )
    exit /b 0

:find_target_trace
    set "CUSTOM_PATH=%~1"
    set "TARGET_TRACE="

    if not "%CUSTOM_PATH%"=="" (
        if exist "%CUSTOM_PATH%" (
            set "TARGET_TRACE=%CUSTOM_PATH%"
            echo [INFO] 使用指定的 trace: %TARGET_TRACE%
            exit /b 0
        ) else (
            echo [WARN] 指定的路径不存在: %CUSTOM_PATH%，准备自动查找最新文件...
        )
    )

    set "TARGET_DIR=%MODULE_OUT_DIR%"
    if not exist "%TARGET_DIR%" (
        set "TARGET_DIR=%ROOT_OUT_DIR%android"
    )

    if not exist "%TARGET_DIR%" (
        echo [ERROR] 目标目录不存在: %TARGET_DIR%
        exit /b 1
    )

    :: 按修改时间倒序查找最新的 trace_* / *.perfetto / *.perfetto-trace / *.trace 文件
    for /f "delims=" %%F in ('dir /b /a-d /o-d "%TARGET_DIR%\trace_*.perfetto" "%TARGET_DIR%\*.perfetto" "%TARGET_DIR%\*.perfetto-trace" "%TARGET_DIR%\*.trace" 2^>nul') do (
        if not defined TARGET_TRACE set "TARGET_TRACE=%TARGET_DIR%\%%F"
    )

    if "%TARGET_TRACE%"=="" (
        echo [ERROR] 未在 %TARGET_DIR% 目录下找到 trace 文件
        exit /b 1
    )
    echo [INFO] 使用自动找到的最新的 trace: %TARGET_TRACE%
    exit /b 0

:do_command
    set "default_cmd=sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory thermal"
    echo ********************** start recording trace %record_time%s **********************
    adb shell perfetto -o /data/misc/perfetto-traces/trace_file.perfetto-trace -t %record_time%s %default_cmd%
    echo OUT_TRACE_FILE=%OUT_TRACE_FILE%
    adb pull /data/misc/perfetto-traces/trace_file.perfetto-trace "%OUT_TRACE_FILE%" > nul 2>&1
    call :open_trace
    exit /b 0

:do_online
    where python >nul 2>nul
    if errorlevel 1 (
        echo [ERROR] 未检测到 Python，请先安装 Python 环境
        exit /b 1
    )
    echo ********************** start recording trace %record_time%s **********************
    set "google_default_cmd=sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory thermal"
    python "%GOOGLE_RECORD_TRACE_FILE%" -o "%OUT_TRACE_FILE%" -t %record_time%s -b 64mb %google_default_cmd%
    exit /b 0

:do_config
    :: 去除可能的 s/S 后缀，确保 record_time 为纯数字
    if defined record_time (
        set "record_time=!record_time:s=!"
        set "record_time=!record_time:S=!"
    )
    if "!record_time!"=="" set "record_time=5"

    :: 动态计算毫秒时长，不再固化分档
    set /a duration_ms=record_time * 1000
    if !duration_ms! leq 0 (
        set "record_time=5"
        set "duration_ms=5000"
    )

    :: 时长 >= 10s 时适度增大写入周期，减少频繁 I/O
    set "file_write_period_ms=1000"
    if !record_time! geq 10 set "file_write_period_ms=2500"
    set "flush_period_ms=!file_write_period_ms!"

    echo [INFO] Trace 目标时长: !record_time!s (!duration_ms!ms), 写入周期: !file_write_period_ms!ms

    :: 定位配置文件：优先 perfetto_tools 目录，兼顾 archive 目录
    set "PERFETTO_CONFIG=%SCRIPT_DIR%perfetto_tools\perf_perfetto_config.pbtxt"
    if not exist "!PERFETTO_CONFIG!" (
        echo [ERROR] 找不到 perfetto 配置文件: %SCRIPT_DIR%perfetto_tools\perf_perfetto_config.pbtxt
        exit /b 1
    )

    :: 确保输出目录存在
    if not exist "%MODULE_OUT_DIR%" mkdir "%MODULE_OUT_DIR%"

    :: 替换占位符并生成临时配置文件
    set "TMP_PERFETTO_CONFIG=%MODULE_OUT_DIR%\perf_perfetto_config.pbtxt"
    (for /f "usebackq delims=" %%L in ("!PERFETTO_CONFIG!") do (
        set "line=%%L"
        setlocal enabledelayedexpansion
        set "line=!line:__duration_ms__=%duration_ms%!"
        set "line=!line:__file_write_period_ms__=%file_write_period_ms%!"
        set "line=!line:__flush_period_ms__=%flush_period_ms%!"
        echo(!line!
        endlocal
    )) > "!TMP_PERFETTO_CONFIG!"

    :: 校验临时配置文件非空
    for %%F in ("!TMP_PERFETTO_CONFIG!") do (
        if %%~zF equ 0 (
            echo [ERROR] 生成的临时配置文件为空: !TMP_PERFETTO_CONFIG!
            exit /b 1
        )
    )

    :: 清除设备端历史 trace，防止误拉旧数据
    set "REMOTE_TRACE=/data/misc/perfetto-traces/trace_file.perfetto-trace"
    adb shell "rm -f !REMOTE_TRACE!" >nul 2>&1

    echo ********************** start recording trace !record_time!s **********************
    type "!TMP_PERFETTO_CONFIG!" | adb shell perfetto -c - --txt -o "!REMOTE_TRACE!"
    if !errorlevel! neq 0 (
        echo [ERROR] Perfetto 录制执行失败
        exit /b 1
    )

    echo [INFO] 正在拉取 Trace 文件到: %OUT_TRACE_FILE%
    adb pull "!REMOTE_TRACE!" "%OUT_TRACE_FILE%" >nul 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] 拉取 Trace 文件失败
        exit /b 1
    )

    if not exist "%OUT_TRACE_FILE%" (
        echo [ERROR] 本地未找到拉取的 Trace 文件: %OUT_TRACE_FILE%
        exit /b 1
    )

    echo [OK] Trace 录制完成: %OUT_TRACE_FILE%
    call :open_trace "%OUT_TRACE_FILE%"
    exit /b %ERRORLEVEL%


:do_tool
    curl -L -f -o "%GOOGLE_OPEN_TRACE_FILE%" https://raw.githubusercontent.com/google/perfetto/main/tools/open_trace_in_ui
    if %errorlevel% neq 0 (
        echo [WARN] 下载 open_trace_in_ui 失败！请检查网络/代理设置。
    )
    curl -L -f -o "%GOOGLE_RECORD_TRACE_FILE%" https://raw.githubusercontent.com/google/perfetto/master/tools/record_android_trace
    if %errorlevel% neq 0 (
        echo [WARN] 下载 record_android_trace 失败！请检查网络/代理设置。
    )
    exit /b 0

:do_ui
    call :find_target_trace "%param1%"
    if errorlevel 1 exit /b 1

    echo [INFO] 正在启动 perfetto UI 打开 trace...
    python "%GOOGLE_OPEN_TRACE_FILE%" -i "%TARGET_TRACE%"
    exit /b 0

:do_ui_enhance
    call :find_target_trace "%param1%"
    if errorlevel 1 exit /b 1
    echo [INFO] 正在启动本地 Trace Processor 服务，加速 trace 解析...
    "%TRACE_PROCESSOR_SHELL%" --httpd "%TARGET_TRACE%"

    python "%GOOGLE_OPEN_TRACE_FILE%" -i "%TARGET_TRACE%"
    exit /b 0

:do_shell
    call :find_target_trace "%param1%"
    if errorlevel 1 exit /b 1

    if exist "%SQL_DIR%" (
        cd /d "%SQL_DIR%"
    )

    echo [INFO] 正在启动 trace_processor_shell 交互式命令行...
    "%TRACE_PROCESSOR_SHELL%" -i "%TARGET_TRACE%"
    exit /b 0

:open_trace
    set "TRACE_TARGET=%~1"
    if "!TRACE_TARGET!"=="" set "TRACE_TARGET=%OUT_TRACE_FILE%"

    if not exist "!TRACE_TARGET!" (
        echo [ERROR] Trace 文件不存在: !TRACE_TARGET!
        exit /b 1
    )

    if not exist "%GOOGLE_OPEN_TRACE_FILE%" (
        echo [ERROR] 找不到打开工具: %GOOGLE_OPEN_TRACE_FILE%
        echo [INFO] 请先执行 'perf trace tool' 下载工具
        exit /b 1
    )

    echo [INFO] 正在启动 Perfetto UI 打开: !TRACE_TARGET!
    python "%GOOGLE_OPEN_TRACE_FILE%" -i "!TRACE_TARGET!"
    exit /b 0
