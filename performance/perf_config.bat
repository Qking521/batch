@echo off
setlocal enabledelayedexpansion
@REM **************************set record time*********************************
set record_time=%1
:: 标志变量，初始为未找到
set "found=0"
set "timelist=5 10 30"

for %%i in (%timelist%) do (
	if %record_time%==%%i (
		set "found=1"
	)
)
if "%found%"=="0" (
	set record_time=5
)
echo record_time = %record_time%

if "%record_time%"=="5" (
    set duration_ms=5000
    set file_write_period_ms=1000
    set flush_period_ms=1000
)

if "%record_time%"=="10" (
    set duration_ms=10000
    set file_write_period_ms=2000
    set flush_period_ms=2000
)

if "%record_time%"=="30" (
    set duration_ms=30000
    set file_write_period_ms=2000
    set flush_period_ms=2000
)
@REM **************************set record time*********************************

set config_name=config.pbtxt
for /f "delims= " %%a in ('adb shell getprop ro.product.board') do @set model=%%a

::获取脚本所在目录，自带反斜杠
set "scriptDir=%~dp0"
:: 去掉最后一个反斜杠（如果有）
set "currentDir=%scriptDir:~0,-1%"
:: 获取上一级目录路径
for %%i in ("%currentDir%") do set "parentDir=%%~dpi"
set OUT_DIR=%parentDir%OUT\performance\
set trace_file=%model%_%format_time%.perfetto
set configPath=/data/misc/perfetto-configs

if not exist %OUT_DIR% (
	mkdir %OUT_DIR%
)

REM 调用 generate_config 函数
call :generate_config
adb shell "rm -rf %configPath%/*"
adb shell "rm -rf /data/misc/perfetto-traces/*"
REM 本地生成的config文件push手机中供生成trace文件
adb push %cd%\%config_name% %configPath%/config.pbtxt > nul 2>&1
REM 本地生成的config文件push out目录中供验证
move %cd%\%config_name% %OUT_DIR%\%~n0_%record_time%_config.pbtxt > nul

echo **********************start capturing perfetto****************************
REM 第一个echo 0 是为了保证正常抓取
adb shell "echo 0 > /sys/kernel/tracing/tracing_on"
adb shell perfetto --txt -c %configPath%/config.pbtxt -o /data/misc/perfetto-traces/%trace_file% > nul 2>&1
REM 第二个echo 0是为了保证正常结束
adb shell "echo 0 > /sys/kernel/tracing/tracing_on"
adb pull /data/misc/perfetto-traces/%trace_file%   %OUT_DIR%\%trace_file% > nul 2>&1
echo trace_file: %OUT_DIR%\%trace_file%

REM 调用浏览器自动加载trace文件
call perf_open.bat %OUT_DIR%\%trace_file%
endlocal
goto :END

:generate_config
(
  echo buffers: {
  echo     size_kb: 634880
  echo     fill_policy: RING_BUFFER
  echo }
  echo buffers: {
  echo  size_kb: 204800
  echo  fill_policy: RING_BUFFER
  echo }
  echo duration_ms: %duration_ms%
  echo write_into_file: true
  echo file_write_period_ms: %file_write_period_ms%
  echo flush_period_ms: %flush_period_ms%
  echo.
  echo data_sources: {
  echo     config {
  echo         name: "android.log"
  echo         android_log_config {
  echo             log_ids: LID_CRASH
  echo             log_ids: LID_DEFAULT
  echo             log_ids: LID_EVENTS
  echo             log_ids: LID_KERNEL
  echo             log_ids: LID_STATS
  echo             log_ids: LID_SYSTEM
  echo         }
  echo     }
  echo }
  echo.
  echo data_sources: {
  echo      config {
  echo          name: "linux.system_info"
  echo          target_buffer: 1
  echo      }
  echo  }
  echo.
  echo  data_sources: {
  echo      config {
  echo          name: "linux.process_stats"
  echo          target_buffer: 1
  echo          process_stats_config {
  echo              scan_all_processes_on_start: true
  echo              proc_stats_poll_ms: 500
  echo          }
  echo      }
  echo  }
  echo.
  echo  data_sources: {
  echo      config {
  echo          name: "linux.sys_stats"
  echo          sys_stats_config {
  echo              meminfo_period_ms: 500
  echo          }
  echo      }
  echo  }
  echo  data_sources: {
  echo      config {
  echo          name: "android.java_hprof"
  echo          target_buffer: 0
  echo          java_hprof_config {
  echo              continuous_dump_config {
  echo                  dump_interval_ms: 1000
  echo              }
  echo          }
  echo      }
  echo  }
  echo  data_sources: {
  echo      config {
  echo          name: "linux.ftrace"
  echo          ftrace_config {
  echo              ftrace_events: "lowmemorykiller/lowmemory_kill"
  echo              ftrace_events: "oom/oom_score_adj_update"
  echo              ftrace_events: "ftrace/print"
  echo              atrace_apps: "lmkd"
  echo          }
  echo      }
  echo  }
  echo data_sources: {
  echo     config {
  echo         name: "linux.ftrace"
  echo         ftrace_config {
  echo             ftrace_events: "sched/sched_switch"
  echo             ftrace_events: "sched/sched_wakeup"
  echo             ftrace_events: "sched/sched_wakeup_new"
  echo             ftrace_events: "sched/sched_waking"
  echo             ftrace_events: "sched/sched_process_exit"
  echo             ftrace_events: "sched/sched_process_free"
  echo             ftrace_events: "power/cpu_frequency"
  echo             ftrace_events: "power/cpu_idle"
  echo             ftrace_events: "task/task_newtask"
  echo             ftrace_events: "task/task_rename"
  echo             ftrace_events: "lowmemorykiller/lowmemory_kill"
  echo             ftrace_events: "oom/oom_score_adj_update"
  echo             ftrace_events: "ftrace/print"
  echo             atrace_categories: "idle"
  echo             atrace_categories: "freq"
  echo             atrace_categories: "view"
  echo             atrace_categories: "wm"
  echo             atrace_categories: "memreclaim"
  echo             atrace_categories: "sched"
  echo             atrace_categories: "am"
  echo             atrace_categories: "aidl"
  echo             atrace_categories: "dalvik"
  echo             atrace_categories: "binder_lock"
  echo             atrace_categories: "binder_driver"
  echo             atrace_categories: "camera"
  echo             atrace_categories: "gfx"
  echo             atrace_categories: "input"
  echo             atrace_categories: "pm"
  echo             atrace_categories: "power"
  echo             atrace_categories: "rs"
  echo             atrace_categories: "res"
  echo             atrace_categories: "ss"
  echo         }
  echo     }
  echo }
  echo.

  exit /b
) > %config_name%

:END