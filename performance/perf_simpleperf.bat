@echo off
setlocal enabledelayedexpansion

set app=%1
if "%app%"=="" (
    echo "请输入包名或进程名"
	exit
)
set record_time=%2
if "%record_time%"=="" (
	set record_time=5
)

set SIMPLEPERF_DIR=E:\Android\AndroidSDK\ndk\27.0.12077973\simpleperf
set SIMPLEPERF_PATH=%SIMPLEPERF_DIR%\bin\android\arm64\simpleperf



adb push %SIMPLEPERF_PATH% /data/local/tmp/
adb shell chmod 777 /data/local/tmp/simpleperf
adb shell rm /data/local/tmp/perf.data
adb shell rm /data/local/tmp/perf_report.txt

adb shell  /data/local/tmp/simpleperf record --app %app% --duration %record_time% -o /data/local/tmp/perf.data --call-graph fp
timeout /t 2
adb shell /data/local/tmp/simpleperf --log error report -g -i /data/local/tmp/perf.data -o /data/local/tmp/perf_report.txt


adb pull /data/local/tmp/perf.data %OUT_DIR%/
adb pull /data/local/tmp/perf_report.txt %OUT_DIR%/

python %SIMPLEPERF_DIR%\report_html.py -i %OUT_DIR%/perf.data -o %OUT_DIR%/perf.html

endlocal