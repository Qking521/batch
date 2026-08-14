@echo off
chcp 65001 >nul
setlocal

set "action=%~1"
set "param1=%~2"
set "param2=%~3"

if "%param1%"=="" goto show_usage
if /i "%param1%"=="?" goto show_usage
if /i "%param1%"=="-h" goto show_usage
if /i "%param1%"=="--help" goto show_usage

echo action=%action%
echo param1=%param1%
echo param2=%param2%

:: -------- 查找 trace 文件 --------
set "TARGET_TRACE="
if not "%param2%"=="" (
    if exist "%param2%" (
        set "TARGET_TRACE=%param2%"
        echo [INFO] 使用指定的 trace: %param2%
    ) else (
        echo [WARN] 路径不存在: %param2%，自动查找最新文件...
    )
)

if "%TARGET_TRACE%"=="" (
    set "TARGET_DIR=%MODULE_OUT_DIR%"
    if not exist "%MODULE_OUT_DIR%" set "TARGET_DIR=%ROOT_OUT_DIR%android"
)

if "%TARGET_TRACE%"=="" (
    for /f "delims=" %%F in ('dir /b /a-d /o-d "%TARGET_DIR%\trace_*.perfetto" "%TARGET_DIR%\*.perfetto" "%TARGET_DIR%\*.perfetto-trace" "%TARGET_DIR%\*.trace" 2^>nul') do (
        if not defined TARGET_TRACE set "TARGET_TRACE=%TARGET_DIR%\%%F"
    )
)

if "%TARGET_TRACE%"=="" (
    echo [ERROR] 未在 %TARGET_DIR% 找到 trace 文件
    exit /b 1
)
echo [INFO] 使用最新 trace: %TARGET_TRACE%

:: -------- 检查工具 --------
set "TRACE_PROCESSOR_SHELL=%SCRIPT_DIR%perfetto_tools\trace_processor_shell.exe"
if not exist "%TRACE_PROCESSOR_SHELL%" (
    echo [ERROR] 找不到 trace_processor_shell.exe: %TRACE_PROCESSOR_SHELL%
    exit /b 1
)

:: -------- 准备 SQL --------
set "SQL_DIR=%~dp0perf_sql"
set "SQL_FILE=%SQL_DIR%\%param1%.sql"
set "TMP_SQL_FILE=%MODULE_OUT_DIR%\tmp_query.sql"
set "CSV_OUT_FILE=%MODULE_OUT_DIR%\query_result_%FORMAT_TIME%.csv"

echo SQL_FILE=%SQL_FILE%
echo TMP_SQL_FILE=%TMP_SQL_FILE%
echo CSV_OUT_FILE=%CSV_OUT_FILE%

if exist "%SQL_FILE%" (
    echo [INFO] 匹配到 SQL 预设标签: %param1%  ^(%SQL_FILE%^)
    copy /y "%SQL_FILE%" "%TMP_SQL_FILE%" >nul
) else (
    echo [INFO] 未匹配到标签，使用自定义 SQL 语句
    > "%TMP_SQL_FILE%" (echo %param1%)
)

:: -------- 执行 SQL --------
echo [INFO] 执行 SQL 分析中...
echo [INFO] 结果将导出至: %CSV_OUT_FILE%

"%TRACE_PROCESSOR_SHELL%" -q "%TMP_SQL_FILE%" "%TARGET_TRACE%" > "%CSV_OUT_FILE%"

if exist "%TMP_SQL_FILE%" del "%TMP_SQL_FILE%"

echo [OK] 导出完成！
type "%CSV_OUT_FILE%"
exit /b 0


:: ============================================================
:show_usage
:: ============================================================
echo.
echo 用法:
echo   perf sql ^<tag_or_sql^> [trace_path]
echo.
echo 参数说明:
echo  ^<tag_or_sql^>      -- SQL 预设标签名，对应 perf_sql\^<tag^>.sql 文件或直接传入 SQL 语句字符串
echo  trace_path          -- 可选参数，默认自动查找 OUT 目录下最新的 trace 文件
echo.
echo 示例:
echo   perf sql top_slices
echo   perf sql cpu_usage trace_oaklan_0813-2027.perfetto
echo   perf sql "SELECT * FROM slice LIMIT 10"
echo.
echo 可用 SQL 标签 (perf_sql\*.sql):
set "SQL_DIR=%~dp0perf_sql"
set "_found=0"
for %%F in ("%SQL_DIR%\*.sql") do (
    set "_found=1"
    echo   [tag] %%~nF   %%~dpnxF
)
if "%_found%"=="0" echo   (未找到任何 .sql 文件)
echo.
exit /b 0