@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for perf_simpleperf.bat
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

set app=%1
if "%app%"=="" (
    echo 请输入包名或进程名,当前进程
    adb shell dumpsys window | grep mCurrentFocus

	goto usage
	exit /b
)
set record_time=%2
if "%record_time%"=="" (
	set record_time=5
)

echo 进程：%app%
echo 时间：%record_time%s

set SIMPLEPERF_DIR=E:\Android\AndroidSDK\ndk\27.0.12077973\simpleperf
set SIMPLEPERF_PATH=%SIMPLEPERF_DIR%\bin\android\arm64\simpleperf

adb push %SIMPLEPERF_PATH% /data/local/tmp/
adb shell chmod 777 /data/local/tmp/simpleperf >nul
adb shell rm /data/local/tmp/perf.data >nul
adb shell rm /data/local/tmp/perf_report.txt >nul

echo **************************开始抓取火焰图 5s**************************

adb shell  /data/local/tmp/simpleperf record --app %app% --duration %record_time% -o /data/local/tmp/perf.data --call-graph fp >nul
timeout /t 2
adb shell /data/local/tmp/simpleperf --log error report -g -i /data/local/tmp/perf.data -o /data/local/tmp/perf_report.txt >nul


adb pull /data/local/tmp/perf.data %MODULE_OUT_DIR%/ >nul
adb pull /data/local/tmp/perf_report.txt %MODULE_OUT_DIR%/ >nul

where python >nul 2>nul
if errorlevel 1 (
	echo 未检测到 Python，请先安装 Python 环境
	exit /b
)
python %SIMPLEPERF_DIR%\report_html.py -i %MODULE_OUT_DIR%/perf.data -o %MODULE_OUT_DIR%/perf.html

:usage
echo.
echo 用法: perf ^<命令^> [参数]
echo.
echo 命令:
echo   flame                  - 需要添加进程名和可选的抓取时间
echo.
echo 示例:
echo   perf flame com.android.settings [5]
echo.
exit /b 0