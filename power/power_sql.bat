@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

set "action=%~1"
set "param1=%~2"
set "param2=%~3"

echo action=%action%
echo param1=%param1%
echo param2=%param2%

if "%param1%"=="" (
    echo [ERROR] sql 命令必须指定第二个参数 ^(SQL语句或标签^)
    echo 使用示例power sql dcr [bugreport]
    exit /b 1
)

:: 判断是否有第三个参数指定了 bugreport 路径，如果没有指定默认是OUT/android目录下的
call :find_target_bugreport "%param2%"
if errorlevel 1 exit /b 1

set "TRACE_PROCESSOR_SHELL=%SCRIPT_DIR%..\performance\google_perfetto_tools\trace_processor_shell.exe"
if not exist "%TRACE_PROCESSOR_SHELL%" (
    echo [ERROR] 找不到 trace_processor_shell.exe
    exit /b 1
)

set "TMP_SQL_FILE=%OUT_DIR%\tmp_query.sql"
set "CSV_OUT_FILE=%OUT_DIR%\query_result_%FORMAT_TIME%.csv"

echo TMP_SQL_FILE=%TMP_SQL_FILE%
echo CSV_OUT_FILE=%CSV_OUT_FILE%

:: 优先尝试按标签名去脚本末尾抠 @@SQL_<标签>_BEGIN/END 区块
call :extract_sql_block "@@SQL_%param1%_BEGIN" "@@SQL_%param1%_END" "%TMP_SQL_FILE%"

for %%S in ("%TMP_SQL_FILE%") do set "TAG_FILE_SIZE=%%~zS"

if not "%TAG_FILE_SIZE%"=="0" (
    echo [INFO] 匹配到 SQL 预设标签: %param1%
) else (
    echo [INFO] 未匹配到标签，使用自定义 SQL 语句
    (
        echo %param1%
    ) > "%TMP_SQL_FILE%"
)

echo [INFO] 执行 SQL 分析中...
echo [INFO] 结果将同步导出至: %CSV_OUT_FILE%


:: 执行 SQL 并重定向输出至 out 目录下的 CSV 文件中
"%TRACE_PROCESSOR_SHELL%" -q "%TMP_SQL_FILE%" "%TARGET_BUGREPORT%" > "%CSV_OUT_FILE%"

if exist "%TMP_SQL_FILE%" del "%TMP_SQL_FILE%"
echo [OK] 导出完成！
type "%CSV_OUT_FILE%"
start %CSV_OUT_FILE%
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

:: ============================================================
:: heredoc 核心：从脚本自身文件里，抠出两个标记之间的原始文本，写入目标文件
:: 用法: call :extract_sql_block "@@SQL_APP_BEGIN" "@@SQL_APP_END" "输出文件路径"
:: ============================================================
:extract_sql_block
set "begin_marker=%~1"
set "end_marker=%~2"
set "out_file=%~3"
set "printing=0"
> "%out_file%" (
    for /f "tokens=1* delims=]" %%A in ('find /n /v "" ^< "%~f0"') do (
        set "content=%%B"
        if "!printing!"=="1" (
            if "!content!"=="%end_marker%" (
                set "printing=0"
            ) else (
                echo(!content!
            )
        ) else if "!content!"=="%begin_marker%" (
            set "printing=1"
        )
    )
)
exit /b 0



:: ============================================================
:: 以下是数据区，正常执行流程永远不会跑到这里（上面所有分支都以 exit /b 结束）
:: 这里的内容只会被 :extract_sql_block 当纯文本读取，不会被当命令执行
:: 新增标签：照抄一段 @@SQL_<标签名>_BEGIN ... @@SQL_<标签名>_END 即可
:: ============================================================

@@SQL_battery_BEGIN
-- 标签: battery
-- 用途: 查看电量/电压/电荷完整时间线（官方 android.battery 模块拼好的视图）

INCLUDE PERFETTO MODULE android.battery;

SELECT
  ts,
  capacity_percent,
  voltage_uv,
  current_ua,
  charge_uah
FROM android_battery_charge
ORDER BY ts;
@@SQL_battery_END

:: -----------------------------------------------------------------------------------------
@@SQL_power_BEGIN
-- 标签: power
-- 用途: 查看 Power Rails / ODPM 分轨道能耗（仅部分机型有硬件功耗计数据）
-- 注意: 官方视图名是 android_power_rails_counters（带 _counters 后缀）

INCLUDE PERFETTO MODULE android.power_rails;

SELECT
  *,
  datetime(ts / 1e9, 'unixepoch') AS ts_utc
FROM android_power_rails_counters
ORDER BY ts;
@@SQL_power_END

:: -----------------------------------------------------------------------------------------
@@SQL_dcr_BEGIN
-- 标签: battery_rate
-- 用途: 基于 batt.charge_uah 统计电池电量消耗速率、每小时耗电量(mAh)及每小时掉电百分比(%/h)
-- 假设电池额定容量为 5200 mAh (如需修改可调下方 DESIGN_CAPACITY_MAH)

WITH pct AS (
  SELECT ts, value AS pct
  FROM counter c
  LEFT JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'batt.capacity_pct'
),
charge AS (
  SELECT ts, value AS charge_uah
  FROM counter c
  LEFT JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'batt.charge_uah'
),
charge_with_pct AS (
  SELECT
    c.ts,
    c.charge_uah,
    (SELECT p.pct FROM pct p WHERE p.ts <= c.ts ORDER BY p.ts DESC LIMIT 1) AS pct
  FROM charge c
),
rate AS (
  SELECT
    ts,
    pct,
    charge_uah,
    LEAD(charge_uah) OVER (ORDER BY ts) - charge_uah AS delta_uah,
    (LEAD(ts) OVER (ORDER BY ts) - ts) / 1e9 AS delta_s
  FROM charge_with_pct
)
SELECT
  datetime(ts / 1e9, 'unixepoch') AS time_utc,
  pct AS battery_pct,
  charge_uah AS charge_value_uah,
  delta_uah / NULLIF(delta_s, 0) AS raw_rate_uah_per_s,
  (delta_uah / NULLIF(delta_s, 0)) * 3600 / 1000 AS rate_mah_per_h,
  (delta_uah / NULLIF(delta_s, 0)) * 3600 / 1000 / 5200.0 * 100 AS rate_pct_per_h
FROM rate
ORDER BY ts;

:: -----------------------------------------------------------------------------------------
@@SQL_test_BEGIN
-- 标签: battery_rate
-- 用途: 基于 batt.charge_uah 统计电池电量消耗速率、每小时耗电量(mAh)及每小时掉电百分比(%/h)
-- 假设电池额定容量为 5200 mAh (如需修改可调下方 DESIGN_CAPACITY_MAH)

WITH cap AS (
  -- 电池标称容量（mAh），按你实际设备改这一个数字
  SELECT 5200 AS capacity_mah
),
pct AS (
  SELECT ts, value AS pct
  FROM counter c
  LEFT JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'batt.capacity_pct'
),
charge AS (
  SELECT ts, value AS charge_uah
  FROM counter c
  LEFT JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'batt.charge_uah'
),
charge_with_pct AS (
  SELECT
    c.ts,
    c.charge_uah,
    (SELECT p.pct FROM pct p WHERE p.ts <= c.ts ORDER BY p.ts DESC LIMIT 1) AS pct
  FROM charge c
),
rate AS (
  SELECT
    ts,
    pct,
    charge_uah,
    LEAD(charge_uah) OVER (ORDER BY ts) - charge_uah AS delta_uah,
    (LEAD(ts) OVER (ORDER BY ts) - ts) / 1e9 AS delta_s
  FROM charge_with_pct
)
SELECT
  datetime(ts / 1e9, 'unixepoch') AS time_utc,
  pct AS battery_pct,
  charge_uah AS charge_value_uah,
  delta_uah / NULLIF(delta_s, 0) AS raw_rate_uah_per_s,
  (delta_uah / NULLIF(delta_s, 0)) * 3600 / 1000 AS rate_mah_per_h,
  ((delta_uah / NULLIF(delta_s, 0)) * 3600 / 1000) / (SELECT capacity_mah FROM cap) * 100 AS rate_pct_per_h
FROM rate
ORDER BY ts;
@@SQL_test_END