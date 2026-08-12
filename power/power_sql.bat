@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

set "action=%~1"
set "param1=%~2"
set "param2=%~3"

if /i "%param1%"=="" goto :show_usage
if /i "%param1%"=="?" goto :show_usage
if /i "%param1%"=="-h" goto :show_usage
if /i "%param1%"=="--help" goto :show_usage

echo action=%action%
echo param1=%param1%
echo param2=%param2%

:: 获取电池额定容量（mAh），adb 读取失败时回落到默认值 5200
set "BATTERY_CAP=5200"
for /f "delims=" %%a in ('adb shell cat /sys/class/power_supply/battery/charge_full_design 2^>nul') do set "RAW_CAP=%%a"
if defined RAW_CAP (
    set /a BATTERY_CAP=!RAW_CAP! / 1000
    if "!BATTERY_CAP!"=="0" set "BATTERY_CAP=5200"
)
echo BATTERY_CAP=!BATTERY_CAP! mAh

:: 判断是否有第三个参数指定了 bugreport 路径，没有则自动找最新的
call :find_target_bugreport "%param2%"
if errorlevel 1 exit /b 1

set "TRACE_PROCESSOR_SHELL=%SCRIPT_DIR%..\performance\google_perfetto_tools\trace_processor_shell.exe"
if not exist "%TRACE_PROCESSOR_SHELL%" (
    echo [ERROR] 找不到 trace_processor_shell.exe: %TRACE_PROCESSOR_SHELL%
    exit /b 1
)

set "SQL_DIR=%~dp0power_sql"
set "SQL_FILE=%SQL_DIR%\%param1%.sql"
set "TMP_SQL_FILE=%OUT_DIR%\tmp_query.sql"
set "CSV_OUT_FILE=%OUT_DIR%\query_result_%FORMAT_TIME%.csv"

echo SQL_FILE=%SQL_FILE%
echo TMP_SQL_FILE=%TMP_SQL_FILE%
echo CSV_OUT_FILE=%CSV_OUT_FILE%

:: 按标签名（文件名）在 sql\ 目录下查找对应 .sql 文件
if exist "%SQL_FILE%" (
    echo [INFO] 匹配到 SQL 预设标签: %param1%  ^(%SQL_FILE%^)
    call :build_sql_with_vars "%SQL_FILE%" "%TMP_SQL_FILE%"
) else (
    :: 没有匹配到标签，将 param1 作为原始 SQL 语句执行
    echo [INFO] 未匹配到标签，使用自定义 SQL 语句
    > "%TMP_SQL_FILE%" (echo %param1%)
)

echo [INFO] 执行 SQL 分析中...
echo [INFO] 结果将导出至: %CSV_OUT_FILE%

"%TRACE_PROCESSOR_SHELL%" -q "%TMP_SQL_FILE%" "%TARGET_BUGREPORT%" > "%CSV_OUT_FILE%"

if exist "%TMP_SQL_FILE%" del "%TMP_SQL_FILE%"

echo [OK] 导出完成！
type "%CSV_OUT_FILE%"
::start %CSV_OUT_FILE%
exit /b 0


:: ============================================================
:show_usage
:: ============================================================
echo.
echo Usage:
echo   power sql ^<action^> ^<tag_or_sql^> [bugreport_path]
echo.
echo 参数说明:
echo   ^<action^>          固定值，如 dcr（由调用方传入）
echo   ^<tag_or_sql^>      SQL 预设标签名，对应 power_sql\^<tag^>.sql 文件
echo                     或直接传入 SQL 语句字符串
echo   [bugreport_path]  可选，指定 bugreport.zip 路径
echo                     不指定则自动在 OUT/android/ 下查找最新文件
echo.
echo 示例:
echo   power sql dcr dcr
echo   power sql dcr battery
echo   power sql dcr wakelock "C:\path\to\bugreport.zip"
echo   power sql dcr "SELECT * FROM slice LIMIT 10"
echo.
echo 可用 SQL 标签 (power_sql\*.sql):
set "SQL_DIR=%~dp0power_sql"
set "_found=0"
for %%F in ("%SQL_DIR%\*.sql") do (
    set "_found=1"
    echo   [tag] %%~nF   %%~dpnxF
)
if "!_found!"=="0" echo   (未找到任何 .sql 文件)
echo.
exit /b 0


:: ============================================================
:: 从 .sql 源文件生成临时 SQL，替换占位符后写入目标文件
:: 当前占位符:
::   __BATTERY_CAP__  ->  实际电池额定容量 (mAh)，默认 5200
:: 用法: call :build_sql_with_vars "源文件.sql" "输出文件.sql"
:: ============================================================
:build_sql_with_vars
set "_SRC=%~1"
set "_DST=%~2"
> "%_DST%" (
    for /f "usebackq delims=" %%L in ("%_SRC%") do (
        set "_line=%%L"
        set "_line=!_line:__BATTERY_CAP__=%BATTERY_CAP%!"
        echo(!_line!
    )
)
exit /b 0


:: ============================================================
:find_target_bugreport
:: %~1 为传入的自定义 bugreport 路径
:: ============================================================
set "CUSTOM_PATH=%~1"
set "TARGET_BUGREPORT="

if not "%CUSTOM_PATH%"=="" (
    if exist "%CUSTOM_PATH%" (
        set "TARGET_BUGREPORT=%CUSTOM_PATH%"
        echo [INFO] 使用指定的 bugreport: %CUSTOM_PATH%
        exit /b 0
    ) else (
        echo [WARN] 路径不存在: %CUSTOM_PATH%，自动查找最新文件...
    )
)

set "TARGET_DIR=%BASE_OUT_DIR%android"
if not exist "%TARGET_DIR%" (
    echo [ERROR] 目录不存在: %TARGET_DIR%
    exit /b 1
)

for /f "delims=" %%F in ('dir /b /a-d /o-d "%TARGET_DIR%\bugreport_*.zip" 2^>nul') do (
    if not defined TARGET_BUGREPORT set "TARGET_BUGREPORT=%TARGET_DIR%\%%F"
)

if "%TARGET_BUGREPORT%"=="" (
    echo [ERROR] 未在 %TARGET_DIR% 找到 bugreport_*.zip
    exit /b 1
)
echo [INFO] 使用最新 bugreport: %TARGET_BUGREPORT%
exit /b 0
