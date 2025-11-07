@echo off
rem kill 掉 之前 抓取perfetto的窗口，避免后续要手动关闭
for /f "tokens=5" %%A in ('wmic process where "CommandLine like '%%perf_open.bat%%'" get ProcessId^,Caption^,CommandLine ^| findstr "cmd.exe" ^| findstr /v "wmic"') do taskkill /PID %%A"
::/b 表示在当前窗口中后台运行，不弹出新窗口,但仍可能阻塞当前窗口
set traceFile=%~1%
:: 获取文件大小（单位：字节）
for %%A in ("%traceFile%") do set "sizeByte=%%~zA"
echo sizeByte = %sizeByte%
set /a sizeGB=sizeByte/1024/1024/1024
set /a threshold=1
:: 如果trace大小超过1G，就是用本地的trace_processor_shell解析
if %sizeGB% GEQ %threshold% (
	echo 111 sizeGB=%sizeGB%
	start /b trace_processor_shell.exe --httpd "%traceFile%"
)
:: 如果trace大小没有超过1G，就使用chrome 自带的解析器
"C:\Program Files\Google\Chrome\Application\chrome.exe" "https://ui.perfetto.dev/"
if %sizeGB% LSS %threshold% (
	::打开文件所在目录
	for %%A in ("%traceFile%") do (
		start "" %%~dpA
	)
)
