@echo off
setlocal enabledelayedexpansion
@REM **************************set record time*********************************
set record_time=%2
:: 标志变量，初始为未找到
set "found=0"
set "timelist=5 10"

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

@REM **************************set record time*********************************

set config_name=config.pbtxt
for /f "delims= " %%a in ('adb shell getprop ro.product.board') do @set model=%%a

::获取脚本所在目录，自带反斜杠
set "scriptDir=%~dp0"
:: 去掉最后一个反斜杠（如果有）
set "currentDir=%scriptDir:~0,-1%"
:: 获取上一级目录路径
for %%i in ("%currentDir%") do set "parentDir=%%~dpi"
set OUT_DIR=%parentDir%OUT\performance\%~1
set trace_file=%model%_%ftime%.perfetto
set configPath=/data/misc/perfetto-configs

if not exist %OUT_DIR% (
	mkdir %OUT_DIR%
)

REM 调用 generate_config 函数
call :generate_config

adb shell "rm -rf %configPath%/*"
adb shell "rm -rf /data/misc/perfetto-traces/*"
adb shell "rm -rf /data/local/tmp/*"
adb shell "logcat -b all -c; dmesg -C"
REM 本地生成的config文件push手机中供生成trace文件
adb push %cd%\%config_name% %configPath%/config.pbtxt > nul 2>&1
REM 本地生成的config文件push out目录中供验证
move %cd%\%config_name% %OUT_DIR%\%~n0_%record_time%_config.pbtxt > nul

adb shell date > %infodir%starttime.txt

adb pull /proc/config.gz %infodir%config.gz
adb shell "cat /proc/meminfo" > %infodir%proc_meminfo_End.txt
adb shell "dumpsys -t 30 meminfo" > %infodir%dumpsys_meminfo_Start.txt
echo Capturing perfetto...please reproduce the issue
REM 第一个echo 0 是为了保证正常抓取
adb shell "echo 0 > /sys/kernel/tracing/tracing_on"
adb shell "setprop debug.traceur.weaken false"
adb shell perfetto --txt -c %configPath%/config.pbtxt -o /data/misc/perfetto-traces/%trace_file% > nul 2>&1
REM 第二个echo 0是为了保证正常结束
adb shell "echo 0 > /sys/kernel/tracing/tracing_on"
adb pull /data/misc/perfetto-traces/%trace_file%   %OUT_DIR%\%trace_file% > nul 2>&1
echo perfetto file path: %OUT_DIR%%trace_file%

REM 调用浏览器自动加载trace文件
rem start startperfetto.bat" %OUT_DIR%\%trace_file%

echo Capturing meminfo and so on AFTER Capturing perfetto
adb shell ps -AT > "%OUT_DIR%ps.txt"
echo 10%% percent..
adb shell "dumpsys activity | grep mFocusedApp | awk '{print $3}' | awk -F'/' '{print $1}'>/sdcard/curpkgName"
echo ================= cur process version info ================= > %OUT_DIR%cur_process_info.txt
adb shell "cat /sdcard/curpkgName" >> %OUT_DIR%cur_process_info.txt
adb shell "result=`cat /sdcard/curpkgName`; dumpsys package $result | grep version" >> %OUT_DIR%cur_process_info.txt
echo ================= cur process meminfo info ================= >> %OUT_DIR%cur_process_info.txt
adb shell "result=`cat /sdcard/curpkgName`; dumpsys meminfo $result; " >> %OUT_DIR%cur_process_info.txt
echo ================= cur process package info ================= >> %OUT_DIR%cur_process_info.txt
adb shell "result=`cat /sdcard/curpkgName`; dumpsys package $result; " >> %OUT_DIR%cur_process_info.txt

echo 30%% percent..
adb shell "dumpsys cpuinfo" > %OUT_DIR%cpuinfo.txt
adb shell "dumpsys package" > %OUT_DIR%pkgInfo.txt
adb shell "pm art dump" > %OUT_DIR%pkgArtDump.txt
adb shell "dumpsys pinner" > %OUT_DIR%pinner.txt
adb shell "dumpsys activity" > %OUT_DIR%activityinfo.txt
adb shell "dumpsys window" > %OUT_DIR%window.txt
adb shell "dumpsys SurfaceFlinger" > %OUT_DIR%SurfaceFlingerInfo.txt
adb shell "dumpsys dropbox --print" > %OUT_DIR%dropbox.txt
adb shell getprop > %OUT_DIR%prop.txt
adb shell df > %OUT_DIR%df.txt
adb shell mount > %OUT_DIR%mount.txt
echo 50%% percent...
rem capture device meminfo 
adb shell "dumpsys -t 30 meminfo" > %OUT_DIR%dumpsys_meminfo_End.txt
adb shell "cat /proc/meminfo" > %OUT_DIR%proc_meminfo_End.txt
adb shell lsof > %OUT_DIR%lsof.txt
adb shell "cat /proc/zoneinfo" > %OUT_DIR%zoneinfo.txt
adb shell "cat /proc/vmstat" > %OUT_DIR%vmstat.txt
rem capture logcat and dmesg lastly 
echo 70%% percent....
adb shell logcat -b all -d > %OUT_DIR%logcat.txt
adb wait-for-device
adb shell dmesg > %OUT_DIR%dmesg.txt
echo 90%% percent.....
adb shell "cd /proc/sys/vm/; for x in `ls `; do echo $x; cat $x ; done" > %OUT_DIR%proc_sys_vm.txt
adb shell "wm size " > %OUT_DIR%size_density.txt
adb shell "wm density " >> %OUT_DIR%size_density.txt
adb shell "cat /proc/version" > %OUT_DIR%kernel_version.txt
adb shell "cat /proc/cmdline" > %OUT_DIR%kernel_cmdline.txt
:: adb pull /data/vendor/thermal/thermal.dump %OUT_DIR%thermal.dump
adb shell "svc power stayon false"
echo *************************  S U C C E S ***********************************

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
 