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
if /i "%1"=="cmd" goto cmd
if /i "%1"=="base" goto base
if /i "%1"=="more" goto more
if /i "%1"=="io" goto input_output
if /i "%1"=="screen" goto screen
if /i "%1"=="full" goto full
if /i "%1"=="cmd" goto command
if /i "%1"=="online" goto online
if /i "%1"=="origin" goto origin
if /i "%1"=="reset" goto reset


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
echo 带录屏性能抓取： perf_screen.bat

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

:cmd
call perf_cmd.bat %1 %2
exit /b

:base
call perf_base.bat %1 %2
exit /b

:more
call perf_more.bat %1 %2
exit /b

:full
call perf_full.bat %1 %2
exit /b

:screen
call perf_screen.bat %1 %2
exit /b

:input_output
call perf_io.bat %1 %2
exit /b

:online_ready
set targetFile=%SCRIPT_DIR%record_android_trace
echo record_android_trace path = %targetFile%
set "maxDays=30"
if not exist "%targetFile%" (
	curl -O https://raw.githubusercontent.com/google/perfetto/master/tools/record_android_trace
)
:: 获取当前日期
for /f %%A in ('powershell -command "Get-Date -Format yyyy-MM-dd"') do set "today=%%A"
echo today=%today%
:: 获取文件最后修改日期
for /f %%A in ('powershell -command "(Get-Item '%targetFile%').LastWriteTime.ToString('yyyy-MM-dd')"') do set "fileDate=%%A"
echo fileDate = %fileDate%
:: 计算时间差(单位：天)
for /f %%A in ('powershell -command "(New-TimeSpan -Start '%fileDate%' -End '%today%').Days"') do set "diffDays=%%A"
if %diffDays% GEQ %maxDays% (
    echo 文件已过期，准备删除并重新下载...
    del "%targetFile%"
    :: 在这里添加你的下载命令，例如：
    curl -O https://raw.githubusercontent.com/google/perfetto/master/tools/record_android_trace
)
echo 工具已下载，请重新执行抓trace命令
exit /b

:online
set targetFile=%SCRIPT_DIR%record_android_trace
if not exist "%targetFile%" (
	goto online_ready
)
set "hasPython=0"
:: 检查是否安装了 python
where python >nul 2>nul && set "hasPython=1"
if %hasPython%=="0" (
	echo 未检测到 Python，请先安装 Python 环境
	exit /b
)
set "duration=%~2"
if "%~2"=="" (
    set "duration=10"
)
:: 查看支持的TAG, adb shell atrace --list_categories
python3 record_android_trace -o trace_file.perfetto-trace -t %duration%s -b 64mb sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory thermal 
exit /b

:origin
rem "" 是窗口标题
start "" %USERPROFILE%\"batScript\performance\perfettoCaptureTools_original"
exit /b

:reset
REM 自动查找并终止 trace_processor_shell.exe 进程

REM 1. 使用 tasklist 查找进程ID (PID)
REM /nh (无列头) /fi "imagename eq..." (按名称过滤)
REM tokens=2 提取 PID (第二列)
for /f "tokens=2" %%i in ('tasklist /nh /fi "imagename eq trace_processor_shell.exe"') do (
    taskkill /F /PID %%i
)
exit /b

endlocal
