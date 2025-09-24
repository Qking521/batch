@echo off
setlocal
:: === 1. 获取当前日期和时间，格式：MMDD-HHMM ===
for /f "tokens=2-4 delims=/.- " %%a in ("%date%") do (
    set MM=%%b
    set DD=%%c
)
for /f "tokens=1-2 delims=: " %%a in ("%time%") do (
    set HH=%%a
    set MN=%%b
)

:: 去掉前导空格
if "%HH:~0,1%"==" " set HH=0%HH%

endlocal & set ftime=%MM%%DD%-%HH%%MN%
echo ftime 1 = %ftime%