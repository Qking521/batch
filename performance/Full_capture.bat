@echo off
title Perfetto_Capture_Tools
@REM **************************set record time*********************************
set duration_ms=%1
echo duration_ms = %duration_ms%
if %duration_ms%==5000 (
	set file_write_period_ms=1000
	set flush_period_ms=1000
)else if %duration_ms%==10000 (
	set file_write_period_ms=2000
	set flush_period_ms=2000
)else(
	set file_write_period_ms=2000
	set flush_period_ms=2000
)
@REM **************************set record time*********************************

set config_name=config.pbtxt

for %%a in (adb.exe) do if not "%%~$PATH:a" == "" echo use %%~$PATH:a
for %%a in (adb.exe) do if "%%~$PATH:a" == "" set PATH=%cd%\envs\platform-tools;%PATH%

set hour=%time:~,2%
if "%time:~,1%"==" " set hour=0%time:~1,1%
for /f "delims= " %%a in ('adb shell getprop ro.product.name') do @set model=%%a
for /f "delims= " %%a in ('adb shell getprop ro.build.version.release') do @set android_version=%%a

set "CURR_TIME=%date:~,4%%date:~5,2%%date:~8,2%_%time:~,2%%time:~3,2%%time:~6,2%"
if %time:~,2% lss 10 set "CURR_TIME=%date:~,4%%date:~5,2%%date:~8,2%_0%time:~1,1%%time:~3,2%%time:~6,2%"

set devinfo=FullCapture.%model%-%android_version%__%CURR_TIME%
set traceFile=%model%-%android_version%__%CURR_TIME%.perfetto

mkdir %devinfo%
echo wait adb connect ...
adb wait-for-device
adb root

set infodir=%cd%\%devinfo%\
adb shell "rm -rf /data/local/tmp/*"
adb shell "logcat -b all -c; dmesg -C"


REM µ÷ÓÃ generate_config º¯Êý
call :generate_config
adb push %cd%\%config_name% /data/local/tmp/config.pbtxt
move %cd%\%config_name% %infodir%\config.pbtxt > NUL


setlocal EnableDelayedExpansion
echo **************************************************************************
echo Capturing meminfo BEFORE Capturing perfetto...please hold on..............
echo **************************************************************************

adb shell date > %infodir%starttime.txt

adb pull /proc/config.gz %infodir%config.gz
adb shell "cat /proc/meminfo" > %infodir%proc_meminfo_End.txt
echo 10%% percent.
adb shell "dumpsys -t 30 meminfo" > %infodir%dumpsys_meminfo_Start.txt


echo **************************************************************************
echo Capturing perfetto...please reproduce the issue
echo **************************************************************************
adb shell "echo 0 > /sys/kernel/tracing/tracing_on"
adb shell "setprop debug.traceur.weaken false"
adb shell "cat /data/local/tmp/config.pbtxt | perfetto --txt -c - -o /data/misc/perfetto-traces/%traceFile%"
echo .
adb shell "echo 0 > /sys/kernel/tracing/tracing_on"
echo .
adb pull /data/misc/perfetto-traces/%traceFile%   %devinfo%\%traceFile%
adb shell ps -AT > "%infodir%ps.txt"
echo **************************************************************************
echo Capturing meminfo and so on AFTER Capturing perfetto

adb shell "dumpsys activity | grep mFocusedApp | awk '{print $3}' | awk -F'/' '{print $1}'>/sdcard/curpkgName"
echo ================= cur process version info ================= > %infodir%cur_process_info.txt
adb shell "cat /sdcard/curpkgName" >> %infodir%cur_process_info.txt
adb shell "result=`cat /sdcard/curpkgName`; dumpsys package $result | grep version" >> %infodir%cur_process_info.txt
echo ================= cur process meminfo info ================= >> %infodir%cur_process_info.txt
adb shell "result=`cat /sdcard/curpkgName`; dumpsys meminfo $result; " >> %infodir%cur_process_info.txt
echo ================= cur process package info ================= >> %infodir%cur_process_info.txt
adb shell "result=`cat /sdcard/curpkgName`; dumpsys package $result; " >> %infodir%cur_process_info.txt

echo 30%% percent..
adb shell "dumpsys cpuinfo" > %infodir%cpuinfo.txt
adb shell "dumpsys package" > %infodir%pkgInfo.txt
adb shell "pm art dump" > %infodir%pkgArtDump.txt
adb shell "dumpsys pinner" > %infodir%pinner.txt
adb shell "dumpsys activity" > %infodir%activityinfo.txt
adb shell "dumpsys window" > %infodir%window.txt
adb shell "dumpsys SurfaceFlinger" > %infodir%SurfaceFlingerInfo.txt
adb shell "dumpsys dropbox --print" > %infodir%dropbox.txt
adb shell getprop > %infodir%prop.txt
adb shell df > %infodir%df.txt
adb shell mount > %infodir%mount.txt
echo 50%% percent...
rem capture device meminfo 
adb shell "dumpsys -t 30 meminfo" > %infodir%dumpsys_meminfo_End.txt
adb shell "cat /proc/meminfo" > %infodir%proc_meminfo_End.txt
adb shell lsof > %infodir%lsof.txt
adb shell "cat /proc/zoneinfo" > %infodir%zoneinfo.txt
adb shell "cat /proc/vmstat" > %infodir%vmstat.txt
rem capture logcat and dmesg lastly 
echo 70%% percent....
adb shell logcat -b all -d > %infodir%logcat.txt
adb wait-for-device
adb shell dmesg > %infodir%dmesg.txt
echo 90%% percent.....
adb shell "cd /proc/sys/vm/; for x in `ls `; do echo $x; cat $x ; done" > %infodir%proc_sys_vm.txt
adb shell "wm size " > %infodir%size_density.txt
adb shell "wm density " >> %infodir%size_density.txt
adb shell "cat /proc/version" > %infodir%kernel_version.txt
adb shell "cat /proc/cmdline" > %infodir%kernel_cmdline.txt
adb pull /data/vendor/thermal/thermal.dump %infodir%thermal.dump
adb shell "svc power stayon false"
echo linqun perfetto version.5.1 > %infodir%version.20250110
echo *************************  S U C C E S ***********************************
echo=
echo plese check the result at "%infodir%" 

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
  echo              meminfo_counters: MEMINFO_MEM_TOTAL
  echo              meminfo_counters: MEMINFO_MEM_FREE
  echo              meminfo_counters: MEMINFO_MEM_AVAILABLE
  echo              meminfo_counters: MEMINFO_BUFFERS
  echo              meminfo_counters: MEMINFO_CACHED
  echo              meminfo_counters: MEMINFO_SWAP_CACHED
  echo              meminfo_counters: MEMINFO_ACTIVE
  echo              meminfo_counters: MEMINFO_INACTIVE
  echo              meminfo_counters: MEMINFO_ACTIVE_ANON
  echo              meminfo_counters: MEMINFO_INACTIVE_ANON
  echo              meminfo_counters: MEMINFO_ACTIVE_FILE
  echo              meminfo_counters: MEMINFO_INACTIVE_FILE
  echo              meminfo_counters: MEMINFO_UNEVICTABLE
  echo              meminfo_counters: MEMINFO_MLOCKED
  echo              meminfo_counters: MEMINFO_SWAP_TOTAL
  echo              meminfo_counters: MEMINFO_SWAP_FREE
  echo              meminfo_counters: MEMINFO_DIRTY
  echo              meminfo_counters: MEMINFO_WRITEBACK
  echo              meminfo_counters: MEMINFO_ANON_PAGES
  echo              meminfo_counters: MEMINFO_MAPPED
  echo              meminfo_counters: MEMINFO_SHMEM
  echo              meminfo_counters: MEMINFO_SLAB
  echo              meminfo_counters: MEMINFO_SLAB_RECLAIMABLE
  echo              meminfo_counters: MEMINFO_SLAB_UNRECLAIMABLE
  echo              meminfo_counters: MEMINFO_KERNEL_STACK
  echo              meminfo_counters: MEMINFO_PAGE_TABLES
  echo              meminfo_counters: MEMINFO_COMMIT_LIMIT
  echo              meminfo_counters: MEMINFO_COMMITED_AS
  echo              meminfo_counters: MEMINFO_VMALLOC_TOTAL
  echo              meminfo_counters: MEMINFO_VMALLOC_USED
  echo              meminfo_counters: MEMINFO_VMALLOC_CHUNK
  echo              meminfo_counters: MEMINFO_CMA_TOTAL
  echo              meminfo_counters: MEMINFO_CMA_FREE
  echo              stat_period_ms: 250
  echo              stat_counters: STAT_CPU_TIMES
  echo              stat_counters: STAT_FORK_COUNT
  echo          }
  echo      }
  echo  }
  echo.
  echo  data_sources: {
  echo      config {
  echo          name: "linux.ftrace"
  echo          ftrace_config {
  echo             ftrace_events: "binder/*"
  echo             ftrace_events: "block/*"
  echo             ftrace_events: "i2c/*"
  echo             ftrace_events: "irq/*"
  echo             ftrace_events: "kmem/*"
  echo             ftrace_events: "oom/*"
  echo             ftrace_events: "sched/*"
  echo             ftrace_events: "sched/sched_switch"
  echo             ftrace_events: "power/suspend_resume"
  echo             ftrace_events: "sched/sched_blocked_reason"
  echo             ftrace_events: "sched/sched_wakeup"
  echo             ftrace_events: "sched/sched_wakeup_new"
  echo             ftrace_events: "sched/sched_waking"
  echo             ftrace_events: "sched/sched_process_exit"
  echo             ftrace_events: "sched/sched_process_free"
  echo             ftrace_events: "task/task_newtask"
  echo             ftrace_events: "task/task_rename"
  echo             ftrace_events: "power/cpu_frequency"
  echo             ftrace_events: "power/cpu_idle"
  echo             ftrace_events: "power/suspend_resume"
rem  echo             ftrace_events: "raw_syscalls/sys_enter"
rem  echo             ftrace_events: "raw_syscalls/raw_exit"
  echo             ftrace_events: "power/gpu_frequency"
  echo             ftrace_events: "gpu_mem/gpu_mem_total"
  echo             ftrace_events: "lowmemorykiller/lowmemory_kill"
  echo             ftrace_events: "oom/oom_score_adj_update"
  echo             atrace_apps: "lmkd"
  echo             atrace_categories: "gfx"
  echo             atrace_categories: "input"
  echo             atrace_categories: "view"
  echo             atrace_categories: "webview"
  echo             atrace_categories: "wm"
  echo             atrace_categories: "am"
  echo             atrace_categories: "sm"
  echo             atrace_categories: "audio"
  echo             atrace_categories: "video"
  echo             atrace_categories: "camera"
  echo             atrace_categories: "hal"
  echo             atrace_categories: "res"
  echo             atrace_categories: "dalvik"
  echo             atrace_categories: "rs"
  echo             atrace_categories: "bionic"
  echo             atrace_categories: "power"
  echo             atrace_categories: "pm"
  echo             atrace_categories: "ss"
  echo             atrace_categories: "database"
  echo             atrace_categories: "network"
  echo             atrace_categories: "adb"
  echo             atrace_categories: "vibrator"
  echo             atrace_categories: "aidl"
  echo             atrace_categories: "nnapi"
  echo             atrace_categories: "rro"
  echo             atrace_categories: "pdx"
  echo             atrace_categories: "sched"
  echo             atrace_categories: "irq"
  echo             atrace_categories: "i2c"
  echo             atrace_categories: "freq"
  echo             atrace_categories: "idle"
  echo             atrace_categories: "disk"
  echo             atrace_categories: "mmc"
  echo             atrace_categories: "sync"
  echo             atrace_categories: "workq"
  echo             atrace_categories: "memreclaim"
  echo             atrace_categories: "regulators"
  echo             atrace_categories: "binder_driver"
  echo             atrace_categories: "binder_lock"
  echo             atrace_categories: "pagecache"
  echo             atrace_categories: "memory"
  echo             atrace_categories: "thermal"
  echo             symbolize_ksyms: true
  echo          }
  echo      }
  echo  }
  echo.

  exit /b
) > %config_name%

:END
  pause
 