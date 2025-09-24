@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
:: 获取当前脚本所在目录
set "SCRIPT_DIR=%~dp0"
set PERF_PATH=%~dp0\perfettoCaptureTools\
cd %PERF_PATH%

if "%1"=="" goto show_help
if /i "%1"=="-h" goto show_help
if /i "%1"=="help" goto show_help
if /i "%1"=="pure" goto pure
if /i "%1"=="pureExt" goto pureExt
if /i "%1"=="record" goto screenRecord
if /i "%1"=="full" goto full


echo Unknown command: %1
echo Use "perf -h" for help
exit /b

:show_help
echo.
echo Android Perfermance Commands
echo =======================
echo.
echo Usage: Perfermance [command]
echo.
echo Available commands:
echo   pure    		- default trace capture, time for 5s, 10s, 30s, default 5s.
echo   pure_ext     - extend more info base on pure
echo   -h      		- Show help (alias: help^)
echo.
echo Examples:
echo   perf pure
echo.
exit /b

:pure
call Pure_capture.bat %2
exit /b

:pureExt
if %2==5(
	set record_time=5000
)else if %2 == 10 (
	set record_time=10000
)else(
	set record_time=10000
)
call PureExtend_capture.bat %record_time%
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

endlocal
