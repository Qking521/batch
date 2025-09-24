@echo off
echo **************************************************************
echo *                    Perfetto capture Batch Script
echo *
echo * Author: Linqun
echo * Date:   2025-01-10
echo *                                                                                    
echo * Description: This script is for capturing perfetto.
echo *      It captures perfetto and some more information
echo *      that important for performance
echo *      such as cpuinfo/meminfo/logcat/ps and so on  ...
echo **************************************************************
title Perfetto_Capture_Tools

set config_name=config.pbtxt
for %%a in (adb.exe) do if not "%%~$PATH:a" == "" echo use %%~$PATH:a
for %%a in (adb.exe) do if "%%~$PATH:a" == "" set PATH=%cd%\envs\platform-tools;%PATH%

set hour=%time:~,2%
if "%time:~,1%"==" " set hour=0%time:~1,1%
for /f "delims= " %%a in ('adb shell getprop ro.product.name') do @set model=%%a
for /f "delims= " %%a in ('adb shell getprop ro.build.version.release') do @set android_version=%%a

set "CURR_TIME=%date:~,4%%date:~5,2%%date:~8,2%_%time:~,2%%time:~3,2%%time:~6,2%"
if %time:~,2% lss 10 set "CURR_TIME=%date:~,4%%date:~5,2%%date:~8,2%_0%time:~1,1%%time:~3,2%%time:~6,2%"

set devinfo=PureCapture.%model%-%android_version%__%CURR_TIME%
set traceFile=%model%-%android_version%__%CURR_TIME%.perfetto

mkdir %devinfo%
echo wait adb connect ...
adb wait-for-device
adb root

set infodir=%cd%\%devinfo%\
adb shell "rm -rf /data/local/tmp/*"

REM 调用 generate_config 函数
call :generate_config
adb push %cd%\%config_name% /data/local/tmp/config.pbtxt
move %cd%\%config_name% %infodir%\config.pbtxt > NUL


setlocal EnableDelayedExpansion
echo **************************************************************************
echo Capturing perfetto...please reproduce the issue
echo **************************************************************************
adb shell "echo 0 > /sys/kernel/tracing/tracing_on"
adb shell "cat /data/local/tmp/config.pbtxt | perfetto --txt -c - -o /data/misc/perfetto-traces/%traceFile%"
adb shell "echo 0 > /sys/kernel/tracing/tracing_on"
echo .
adb pull /data/misc/perfetto-traces/%traceFile%   %devinfo%\%traceFile%
echo saving perfetto file to %devinfo%\%traceFile%
echo/
rem kill 掉 之前 trace_processor_shell 对 perfetto的加载
set process_name=trace_processor_shell.exe
tasklist | findstr /i "%process_name%" >nul && (
    echo Process is running, killing...
    taskkill /f /im "%process_name%"
) || (
    echo Process is not running
)

rem kill 掉 之前 抓取perfetto的窗口，避免后续要手动关闭
for /f "tokens=5" %%A in ('wmic process where "CommandLine like '%%startperfetto.bat%%'" get ProcessId^,Caption^,CommandLine ^| findstr "cmd.exe" ^| findstr /v "wmic"') do taskkill /PID %%A"

start "" /B %cd%\envs\trace_processor_shell.exe -D   %devinfo%\%traceFile%  &
start "" /B ".\startperfetto.bat"

echo please load "https://ui.perfetto.dev/#!/" and select "Yes, use loaded trace"
echo\


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
  echo duration_ms: 30000
  echo write_into_file: true
  echo file_write_period_ms: 2000
  echo flush_period_ms: 2000
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


  exit /b
) > %config_name%

:END