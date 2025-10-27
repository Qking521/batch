@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
:: 获取当前脚本所在目录--结尾有反斜杠
set "SCRIPT_DIR=%~dp0"
cd %SCRIPT_DIR%
:: 调用基础脚本检查ADB和设备（使用完整路径）
call "..\adb_check.bat"
if %ERRORLEVEL% neq 0 (
    echo [错误]: 基础检测失败，退出操作。
    exit /b %ERRORLEVEL%
)

if "%1"=="" goto show_help
if /i "%1"=="-h" goto show_help
if /i "%1"=="help" goto show_help
if /i "%1"=="base" goto base
if /i "%1"=="more" goto more
if /i "%1"=="record" goto screenRecord
if /i "%1"=="full" goto full
if /i "%1"=="cmd" goto command
if /i "%1"=="online" goto online
if /i "%1"=="origin" goto origin


echo Unknown command: %1
goto show_help
exit /b

:show_help
echo =======================
echo Android Performance Commands
echo 根据具体分析需求选择合适的脚本类型：
echo 研发性能分析： perf_base.bat
echo 更多性能信息： perf_more.bat
echo 全量性能抓取： perf_full.bat
echo 文件系统性能： perf_ioblock.bat
echo 带日志性能抓取： perf_log.bat
echo 带录屏性能抓取： perf_record.bat

echo
echo Usage: Performance [command]
echo
echo Available commands:
echo   base    		- default trace capture, time for 5s, 10s, 30s, default 5s.
echo   more			- more info on base
echo   full			- full info
echo   io			- focus on IOBlock info
echo   screen		- focus on screen info
echo   -h      		- Show help (alias: help^)
echo.
echo Examples:
echo   perf base 5
echo  =======================
exit /b

:base
call perf_base.bat %2
exit /b

:more
if %2==5(
	set record_time=5000
)else if %2 == 10 (
	set record_time=10000
)else(
	set record_time=10000
)
call perf_more.bat %2
exit /b

:full
if %2==5 (
	set record_time=5000
)else if %2==10 (
	set record_time=10000
)else(
	set record_time=10000
)
call Full_capture.bat %record_time%
exit /b

:screenRecord
if %2==10 (
	set record_time=10000
)else if %2==20 (
	set record_time=20000
)else(
	set record_time=10000
)
call ScreenRecord.Capture.bat %record_time%
exit /b

:command
echo adb shell perfetto -o /data/misc/perfetto-traces/trace_file.perfetto-trace -t 10s sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory
exit /b

:online
echo record_android_trace path = %SCRIPT_DIR%record_android_trace
if not exist "%SCRIPT_DIR%record_android_trace" (
	curl -O https://raw.githubusercontent.com/google/perfetto/master/tools/record_android_trace
)
set "hasPython=0"
:: 检查是否安装了 python
where python >nul 2>nul && set "hasPython=1"
if %hasPython%=="0" (
	echo 未检测到 Python，请先安装 Python 环境
	exit /b
)
python3 record_android_trace -o trace_file.perfetto-trace -t 10s -b 64mb sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory

echo adb shell perfetto -o /data/misc/perfetto-traces/trace_file.perfetto-trace -t 10s sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory
exit /b

:origin
rem "" 是窗口标题
start "" %USERPROFILE%\"batScript\performance\perfettoCaptureTools_original"
exit /b

endlocal
