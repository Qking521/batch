@echo off
:: ============================================================
:: Author: WangQiang
:: Date: 2026-07-20
:: Description: Optimized script for windows_all.bat
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

call %INIT_BAT% %~dp0
if not exist %MODULE_OUT_DIR% mkdir %MODULE_OUT_DIR%

set "cmd=%~1"
set "param1=%~2"
set "param2=%~3"

if /i "%cmd%"=="" goto show_help
if /i "%cmd%"=="usbip" goto usbip
if /i "%cmd%"=="cli" goto command_line
if /i "%cmd%"=="de" goto decompile_apk
if /i "%cmd%"=="open" goto open_program
if /i "%cmd%"=="clear" goto clear_cache

:show_help
echo Available commands:
echo   usbip                - list/attach/auto attach/detach/clear 
echo   unlock               - unlock screen, keep windows screen on 
echo   cli                  - start AI command client,such as Antigravity 
echo   de ^<apk file^>      - Decompile apk
echo   clear                 - clean system cache and junk files
echo.
exit /b

:usbip
    call %SCRIPT_DIR%windows_usbipd.bat %2 %3
    exit /b

:command_line
    call %SCRIPT_DIR%windows_cli.bat %*
    exit /b

:unlock
    call %SCRIPT_DIR%windows_unlock_screen.bat %*
    exit /b

:decompile_apk
    call %SCRIPT_DIR%windows_decompile.bat %*
    exit /b

:open_program
    call %SCRIPT_DIR%windows_open_program.bat %*
    exit /b

:clear_cache
    call :run_kts "%~dp0windows_clear.kt"
    exit /b %errorlevel%

:: ============================================================
:: 通用 Kotlin 脚本运行器
:: 用法: call :run_kts "<kotlin源文件绝对路径>" [运行参数...]
:: 自动按需编译为同名 .jar，再用 java -jar 运行
:: ============================================================
:run_kts
    set "KTS=%~1"
    set "KTS_NAME=%~n1"
    set "KTS_FILE=%~nx1"
    set "JAR=%~dpn1.jar"
    shift

    if not exist "%KTS%" (
        echo [错误] 未找到脚本: %KTS%
        exit /b 1
    )

    :: 判断是否需要编译：jar 不存在，或 .kt 比 .jar 新
    set "NEED_BUILD=1"
    if exist "%JAR%" (
        for %%A in ("%KTS%") do set "KTS_TS=%%~tA"
        for %%A in ("%JAR%") do set "JAR_TS=%%~tA"
        if not "!JAR_TS!" LSS "!KTS_TS!" set "NEED_BUILD=0"
    )

    if "!NEED_BUILD!"=="1" (
        where kotlinc >nul 2>&1
        if errorlevel 1 (
            echo [错误] 未找到 kotlinc，无法首次编译脚本！请先安装 Kotlin 并配置环境变量。
            exit /b 1
        )
        echo 正在编译 kotlin 脚本: %KTS_FILE% -^> %KTS_NAME%.jar
        call kotlinc "%KTS%" -include-runtime -d "%JAR%"
        if errorlevel 1 (
            echo [错误] 编译失败。
            exit /b 1
        )
    ) else (
        echo [信息] 脚本未变更，复用已编译的 %KTS_NAME%.jar
    )

    where java >nul 2>&1
    if errorlevel 1 (
        echo [错误] 未找到 java 命令，无法运行 jar！
        exit /b 1
    )

    echo --------------------------------------------------
    java -jar "%JAR%" %*
    echo --------------------------------------------------
    exit /b %errorlevel%