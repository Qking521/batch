@echo off
chcp 65001 >nul
setlocal

set "action=%~2"
set "param1=%~3"

if "%action%"=="" goto :usage
if /i "%action%"=="-h" goto :usage
if /i "%action%"=="--help" goto :usage
if /i "%action%"=="help" goto :usage
if /i "%action%"=="?" goto :usage

if /i "%action%"=="parse" goto :do_parse
if /i "%action%"=="record" goto :do_record
if /i "%action:~-5%"==".data" (
    set "param1=%action%"
    goto :do_parse
)
if exist "%action%" (
    set "param1=%action%"
    goto :do_parse
)

echo [ERROR] 未知命令: %action%
goto :usage

:usage
echo.
echo 用法: perf flame ^<command^> [params...]
echo.
echo 命令:
echo   record [进程名]                  - 抓取 5 秒火焰图并自动解析打开 (默认当前前台应用)
echo   parse [文件路径]                 - 解析火焰图数据并打开 (默认 OUT 目录最新数据)
echo   help / -h                        - 显示此帮助信息
echo.
echo 示例:
echo   perf flame record
echo   perf flame record com.android.settings
echo   perf flame parse
echo   perf flame parse perf_0903-1200.data
echo   perf flame parse C:\path\to\perf.data
echo   perf flame E:\Temp\perf.data
echo.
exit /b 0

:init_env
    if not defined MODULE_OUT_DIR (
        set "MODULE_OUT_DIR=%~dp0..\OUT\performance"
    )
    if not exist "%MODULE_OUT_DIR%" mkdir "%MODULE_OUT_DIR%" 2>nul

    if not defined FORMAT_TIME (
        for /f "tokens=2-4 delims=/.- " %%a in ("%date%") do (
            set "MM=%%b"
            set "DD=%%c"
        )
        for /f "tokens=1-2 delims=:" %%a in ("%time%") do (
            set "HH=%%a"
            set "MN=%%b"
        )
        set "HH=%HH: =0%"
        set "FORMAT_TIME=%MM%%DD%-%HH%%MN%"
    )

    if not defined SIMPLEPERF_DIR (
        set "SIMPLEPERF_DIR=E:\Android\AndroidSDK\ndk\27.0.12077973\simpleperf"
    )
    if not exist "%SIMPLEPERF_DIR%" (
        if defined ANDROID_NDK_ROOT (
            if exist "%ANDROID_NDK_ROOT%\simpleperf" set "SIMPLEPERF_DIR=%ANDROID_NDK_ROOT%\simpleperf"
        )
        if defined NDK_ROOT (
            if exist "%NDK_ROOT%\simpleperf" set "SIMPLEPERF_DIR=%NDK_ROOT%\simpleperf"
        )
    )
    exit /b 0

:do_parse
    call :init_env
    call :find_target_data "%param1%"
    if errorlevel 1 exit /b 1
    call :parse_and_open_data "%TARGET_DATA%"
    exit /b 0

:do_record
    call :init_env
    setlocal EnableDelayedExpansion
    set "app=%param1%"
    if "%app%"=="" (
        echo [INFO] 未指定进程名，正在自动获取当前前台焦点应用...
        for /f "tokens=3 delims=/ " %%a in ('adb shell "dumpsys window 2>/dev/null | grep mCurrentFocus" 2^>nul') do (
            set "app=%%a"
        )
        if "!app!"=="" (
            for /f "tokens=4 delims=/ " %%a in ('adb shell "dumpsys activity activities 2>/dev/null | grep mResumedActivity" 2^>nul') do (
                set "app=%%a"
            )
        )
    )

    if "%app%"=="" (
        echo [ERROR] 未能获取到当前前台焦点应用，请手动指定进程名：perf flame record [进程名]
        exit /b 1
    )

    set "record_time=5"

    echo ============================================================
    echo [INFO] 目标进程: !app!
    echo [INFO] 抓取时长: %record_time%s
    echo ============================================================

    set "SIMPLEPERF_PATH=%SIMPLEPERF_DIR%\bin\android\arm64\simpleperf"
    if not exist "!SIMPLEPERF_PATH!" (
        echo [ERROR] 找不到 simpleperf 可执行文件: !SIMPLEPERF_PATH!
        exit /b 1
    )

    adb push "!SIMPLEPERF_PATH!" /data/local/tmp/ >nul
    adb shell chmod 777 /data/local/tmp/simpleperf >nul
    adb shell rm -f /data/local/tmp/perf.data /data/local/tmp/perf_report.txt >nul

    echo ************************** 开始抓取火焰图 %record_time%s **************************
    adb shell /data/local/tmp/simpleperf record --app !app! --duration %record_time% -o /data/local/tmp/perf.data --call-graph fp
    timeout /t 2 >nul
    adb shell /data/local/tmp/simpleperf --log error report -g -i /data/local/tmp/perf.data -o /data/local/tmp/perf_report.txt >nul

    set "OUT_DATA=%MODULE_OUT_DIR%\perf_%FORMAT_TIME%.data"
    set "OUT_TXT=%MODULE_OUT_DIR%\perf_report_%FORMAT_TIME%.txt"
    set "OUT_HTML=%MODULE_OUT_DIR%\perf_%FORMAT_TIME%.html"

    adb pull /data/local/tmp/perf.data "!OUT_DATA!" >nul
    copy /y "!OUT_DATA!" "%MODULE_OUT_DIR%\perf.data" >nul 2>nul
    adb pull /data/local/tmp/perf_report.txt "!OUT_TXT!" >nul

    echo [INFO] 数据已保存至: !OUT_DATA!
    echo [INFO] 文本报告已保存至: !OUT_TXT!

    call :parse_and_open_data "!OUT_DATA!" "!OUT_HTML!"
    exit /b 0

:find_target_data
    set "input_file=%~1"
    set "TARGET_DATA="

    if not "%input_file%"=="" (
        if exist "%input_file%" (
            set "TARGET_DATA=%input_file%"
        ) else if exist "%MODULE_OUT_DIR%\%input_file%" (
            set "TARGET_DATA=%MODULE_OUT_DIR%\%input_file%"
        ) else (
            echo [WARN] 未找到指定文件: %input_file%，尝试查找最新数据文件...
        )
    )

    if "%TARGET_DATA%"=="" (
        for /f "delims=" %%F in ('dir /b /a-d /o-d "%MODULE_OUT_DIR%\perf_*.data" "%MODULE_OUT_DIR%\*.data" "%MODULE_OUT_DIR%\perf.data" 2^>nul') do (
            if not defined TARGET_DATA set "TARGET_DATA=%MODULE_OUT_DIR%\%%F"
        )
    )

    if "%TARGET_DATA%"=="" (
        echo [ERROR] 未在 %MODULE_OUT_DIR% 目录下找到火焰图数据文件
        exit /b 1
    )

    echo [INFO] 使用火焰图数据: %TARGET_DATA%
    exit /b 0

:parse_and_open_data
    set "DATA_SRC=%~1"
    set "REPORT_HTML=%~2"
    if "%REPORT_HTML%"=="" (
        set "REPORT_HTML=%~dpn1.html"
    )

    where python >nul 2>nul
    if errorlevel 1 (
        echo [ERROR] 未检测到 Python，请先安装 Python 环境
        exit /b 1
    )

    if not exist "%SIMPLEPERF_DIR%\report_html.py" (
        echo [ERROR] 找不到 simpleperf report_html.py 脚本: %SIMPLEPERF_DIR%\report_html.py
        exit /b 1
    )

    echo [INFO] 正在解析火焰图生成 HTML 报告...
    python "%SIMPLEPERF_DIR%\report_html.py" -i "%DATA_SRC%" -o "%REPORT_HTML%" --no_browser
    if errorlevel 1 (
        echo [ERROR] 火焰图报告生成失败
        exit /b 1
    )

    echo [INFO] HTML 报告生成成功: %REPORT_HTML%
    echo [INFO] 正在打开火焰图...
    start "" "%REPORT_HTML%"
    exit /b 0