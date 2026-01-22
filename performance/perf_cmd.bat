@echo off
setlocal enabledelayedexpansion
@REM **************************set record time*********************************
set record_time=%1
adb shell perfetto -o /data/misc/perfetto-traces/trace_file.perfetto-trace -t %record_time%s sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory thermal

for /f "delims= " %%a in ('adb shell getprop ro.product.board') do set model=%%a
set trace_file=%model%_%format_time%.perfetto

adb pull /data/misc/perfetto-traces/trace_file.perfetto-trace %OUT_DIR%\%trace_file% > nul 2>&1
REM 调用浏览器自动加载trace文件
call %SCRIPT_DIR%perf_open.bat %OUT_DIR%\%trace_file%