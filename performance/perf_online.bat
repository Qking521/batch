@echo off
setlocal enabledelayedexpansion
set "SCRIPT_DIR=%~dp0"
set record_trace_file=%SCRIPT_DIR%record_android_trace

if not exist "%record_trace_file%" (
	curl -O https://raw.githubusercontent.com/google/perfetto/master/tools/record_android_trace
)
if errorlevel 1 (
	echo record_android_trace下载失败，请确保下载完成
	exit /b
)
:: 检查是否安装了 python
where python >nul 2>nul
if errorlevel 1 (
	echo 未检测到 Python，请先安装 Python 环境
	exit /b
)
@REM **************************set record time*********************************
set "record_time=%~1"
if "%~1"=="" (
    set "record_time=10"
)
echo ********************** start recording trace %record_time%s **********************
:: 查看支持的TAG, adb shell atrace --list_categories
python3 record_android_trace -o trace_file.perfetto-trace -t %record_time%s -b 64mb sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory thermal 
exit /b
endlocal