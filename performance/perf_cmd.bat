@echo off
:: 获取格式化的时间ftime
call %SCRIPT_DIR%base_time.bat
setlocal enabledelayedexpansion
@REM **************************set record time*********************************
set record_time=%2
adb shell perfetto -o /data/misc/perfetto-traces/trace_file.perfetto-trace -t %record_time%s sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory thermal

for /f "delims= " %%a in ('adb shell getprop ro.product.board') do set model=%%a

::获取脚本所在目录，自带反斜杠
set "scriptDir=%~dp0"
:: 去掉最后一个反斜杠（如果有）
set "currentDir=%scriptDir:~0,-1%"
:: 获取上一级目录路径
for %%i in ("%currentDir%") do set "parentDir=%%~dpi"
set OUT_DIR=%parentDir%OUT\performance\%~1
if not exist %OUT_DIR% (
	mkdir %OUT_DIR%
)
set trace_file=%model%_%ftime%.perfetto
adb pull /data/misc/perfetto-traces/trace_file.perfetto-trace %OUT_DIR%\%trace_file% > nul 2>&1
REM 调用浏览器自动加载trace文件
call perf_open.bat %OUT_DIR%\%trace_file%