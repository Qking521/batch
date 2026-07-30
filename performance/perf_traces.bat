@echo off
chcp 65001 >nul
setlocal 

set "cmd=%2"
set "param1=%3"
set "param2=%4"

call :evn_init

if /i "%cmd%"=="" goto show_help
if /i "%cmd%"=="-h" goto show_help
if /i "%cmd%"=="help" goto show_help
if /i "%cmd%"=="cmd" goto command
if /i "%cmd%"=="online" goto online
if /i "%cmd%"=="cfg" goto config

echo Unknown command: %cmd%
goto show_help
exit /b

:show_help
echo
echo Usage: Performance [command]
echo
echo Available commands:
echo   cmd    		- 使用命令抓取trace
echo   online		- 使用谷歌封装的trace脚本抓取trace
echo   cfg			- 使用trace配置文件抓取trace
echo.
echo Examples:
echo   perf trace cmd 5 [local]
echo  =======================
exit /b

:evn_init
    for /f "delims= " %%a in ('adb shell getprop ro.product.board') do set model=%%a
    set "TRACE_FILE=%model%_%format_time%.perfetto"
    set "OUT_TRACE_FILE=%OUT_DIR%\%TRACE_FILE%"

    @REM **************************set record time*********************************
    set "record_time=%param1%"
    if "%record_time%"=="" (
        set "record_time=5"
    )
    :: 如果第三个参数不是数字而是字符，默认record time
    set /a test=%param1% 2>nul
    if errorlevel 1 (
        set "record_time=5"
    )
    exit /b

:command
    set "default_cmd=sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory thermal"
    echo ********************** start recording trace %record_time%s **********************
    adb shell perfetto -o /data/misc/perfetto-traces/trace_file.perfetto-trace -t %record_time%s %default_cmd%
    echo OUT_TRACE_FILE=%OUT_TRACE_FILE%
    adb pull /data/misc/perfetto-traces/trace_file.perfetto-trace %OUT_TRACE_FILE% > nul 2>&1
    REM 调用浏览器自动加载trace文件
    call :open_trace
    exit /b

:online
    set GOOGLE_RECORD_TRACE_FILE=%OUT_DIR%\record_android_trace
    echo GOOGLE_RECORD_TRACE_FILE=%GOOGLE_RECORD_TRACE_FILE%
    if not exist "%GOOGLE_RECORD_TRACE_FILE%" (
        curl -L -f -o "%GOOGLE_RECORD_TRACE_FILE%" https://raw.githubusercontent.com/google/perfetto/master/tools/record_android_trace
        if %errorlevel% neq 0 (
            echo 下载失败！请检查网络/代理设置。
            pause
            exit /b 1
        )
        copy /Y "%GOOGLE_RECORD_TRACE_FILE%" .
    )
    if errorlevel 1 (
        echo record_android_trace下载失败，请确保下载完成
        exit /b
    )
    :: 检查是否安装了 python
    where python >nul 2>nul
    if errorlevel 1 (
        echo 未检测到 Python，请先安装 Python 环境
        exit /b
    )
    echo ********************** start recording trace %record_time%s **********************
    :: 查看支持的TAG, adb shell atrace --list_categories
    set "google_default_cmd=sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory thermal"
    python3 record_android_trace -o %OUT_TRACE_FILE% -t %record_time%s -b 64mb %google_default_cmd%
    exit /b

:config
    if %record_time% GEQ 5 (
        set duration_ms=5000
        set file_write_period_ms=1000
        set flush_period_ms=1000
    )
    if %record_time% GEQ 10 (
        set duration_ms=10000
        set file_write_period_ms=2000
        set flush_period_ms=2000
    )
    if %record_time% GEQ 30 (
        set duration_ms=30000
        set file_write_period_ms=2000
        set flush_period_ms=2000
    )
    echo duration_ms=%duration_ms%
    echo file_write_period_ms=%file_write_period_ms%
    echo flush_period_ms=%flush_period_ms%

    set "PERFETTO_CONFIG=%SCRIPT_DIR%\perf_perfetto_config.pbtxt
    set "TMP_PERFETTO_CONFIG=%OUT_DIR%\perf_perfetto_config.pbtxt
    (for /f "delims=" %%L in (%PERFETTO_CONFIG%) do (
        set "line=%%L"
        setlocal enabledelayedexpansion
        set "line=!line:__duration_ms__=%duration_ms%!"
        set "line=!line:__file_write_period_ms__=%file_write_period_ms%!"
        set "line=!line:__flush_period_ms__=%flush_period_ms%!"
        echo(!line!
        endlocal
    )) > %TMP_PERFETTO_CONFIG%

    echo ********************** start recording trace %record_time%s **********************
    ::adb shell "echo 0 > /sys/kernel/tracing/tracing_on"
    type %TMP_PERFETTO_CONFIG% | adb shell perfetto -c - --txt -o /data/misc/perfetto-traces/trace_file.perfetto-trace
    adb pull /data/misc/perfetto-traces/trace_file.perfetto-trace %OUT_TRACE_FILE% > nul 2>&1
    call :open_trace
    exit /b

:open_trace_shell
    ::不需要打开浏览器 UI,直接在命令行里用 SQL 对 trace 文件做数据分析的工具,尤其适合你需要写脚本自动化提取指标、批量处理多个 trace 文件的场景
    set TRACE_PROCESSOR_SHELL=%SCRIPT_DIR%\google_perfetto_tools\trace_processor_shell.exe
    echo TRACE_PROCESSOR_SHELL=%TRACE_PROCESSOR_SHELL%
    %TRACE_PROCESSOR_SHELL% --version
    %TRACE_PROCESSOR_SHELL% "%OUT_TRACE_FILE%"
    ::start /b trace_processor_shell.exe --httpd "%OUT_TRACE_FILE%"
    exit /b

:open_trace
    ::明确本地打开
    if "%param1%"=="sh" (
        call :open_trace_shell
        exit /b
    )
    if "%param2%"=="sh" (
        call :open_trace_shell
        exit /b
    )
    ::默认使用ui打开perfetto trace
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
    ::"C:\Program Files\Google\Chrome\Application\chrome.exe" "https://ui.perfetto.dev/"
    python3 %GOOGLE_OPEN_TRACE_FILE% -i %OUT_TRACE_FILE%
    exit /b
    