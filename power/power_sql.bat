@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

set "action=%~1"
set "param1=%~2"
set "param2=%~3"

echo action=%action%
echo param1=%param1%
echo param2=%param2%

if /i "%param1%"=="" goto :show_usage
if /i "%param1%"=="?" goto :show_usage
if /i "%param1%"=="-h" goto :show_usage
if /i "%param1%"=="--help" goto :show_usage

:: 判断是否有第三个参数指定了 bugreport 路径，没有则自动找最新的
call :find_target_bugreport "%param2%"
if %ERRORLEVEL% neq 0 (
    exit /b 1
)

set "TRACE_PROCESSOR_SHELL=%SCRIPT_DIR%..\performance\perfetto_tools\trace_processor_shell.exe"
if not exist "%TRACE_PROCESSOR_SHELL%" (
    echo [ERROR] 找不到 trace_processor_shell.exe: %TRACE_PROCESSOR_SHELL%
    exit /b 1
)

set "SQL_DIR=%~dp0power_sqls"
set "SQL_FILE=%SQL_DIR%\%param1%.sql"
set "CSV_OUT_FILE=%MODULE_OUT_DIR%\query_result_%FORMAT_TIME%.csv"

echo SQL_FILE=%SQL_FILE%
echo CSV_OUT_FILE=%CSV_OUT_FILE%

:: 按标签名（文件名）在 sql\ 目录下查找对应 .sql 文件
if exist "%SQL_FILE%" (
    echo [INFO] 匹配到 SQL 预设标签: %param1%  ^(%SQL_FILE%^)
) else (
    echo 没有匹配到标签，将 param1 作为原始 SQL 语句执行
)

echo [INFO] 执行 SQL 分析中...
echo [INFO] 结果将导出至: %CSV_OUT_FILE%

"%TRACE_PROCESSOR_SHELL%" -q "%SQL_FILE%" "%TARGET_BUGREPORT%" > "%CSV_OUT_FILE%"

echo [OK] 导出完成！
type "%CSV_OUT_FILE%"
::start %CSV_OUT_FILE%
exit /b 0

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

  set "TARGET_DIR=%ROOT_OUT_DIR%android"
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

:: ============================================================
:show_usage
:: ============================================================
echo.
echo Usage:
echo   power sql ^<tag_or_sql^> [bugreport_path]
echo.
echo 参数说明:
echo  sql tag                   -- SQL 预设标签名，对应 power_sqls\battery.sql 文件或直接传入 SQL 语句字符串
echo  sql string                -- SQL 语句字符串
echo  bugreport                 -- bugreport log， 如果没有默认使用OUT目录下最新的bugreport
echo.
echo 示例:
echo   power sql dcr
echo   power sql battery
echo   power sql wakelock bugreport^.zip
echo   power sql "SELECT * FROM slice LIMIT 10"
echo.
echo 可用 SQL 标签 (power_sqls\*.sql):