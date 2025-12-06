for /f "delims= " %%a in ('adb shell getprop ro.product.board') do echo 平台型号: %%a
for /f "tokens=2 delims=:" %%a in ('adb shell cat /proc/meminfo ^| find "MemTotal"') do set meminfo=%%a
for /f "tokens=1" %%b in ('echo %meminfo%') do set mem_kb=%%b
set /a mem_gb=(%mem_kb% + 1048576 - 1) / 1048576 
echo RAM大小: %mem_gb%G

set "line="
for /f "delims=" %%L in ('adb shell dumpsys diskstats') do (
    echo %%L | findstr /C:"Data-Free" >nul
    if !errorlevel! EQU 0 (
        set "line=%%L"
        goto found
    )
)
:found
for /f "tokens=2 delims=/ " %%a in ("!line!") do (
    set total_kb=%%a
)
:: 去掉末尾的 K（如果存在）
set "total_kb=!total_kb:K=!"
:: 转为 GB（十进制）
set /a total_gb=!total_kb! / 1000000
:: 向上匹配到厂商常见档位
set "sizes=16 32 64 128 256 512 1024 2048"
for %%s in (!sizes!) do (
    if !total_gb! LEQ %%s (
        set rom_size=%%s
        goto show
    )
)
:show
echo ROM大小: !rom_size!G
for /f "delims=" %%A in ('adb shell getprop ro.serialno') do echo SN号: %%A
for /f "delims=" %%A in ('adb shell getprop ro.boot.hardware.sku') do set "SKU=%%A"
	if "%SKU%"=="" ( echo SKU:UNKNOW ) else ( echo SKU:%SKU% )
for /f "tokens=2 delims=:" %%A in ('adb shell dumpsys SurfaceFlinger ^| grep refresh-rate') do echo 刷新率: %%A
for /f "tokens=3 delims=: " %%A in ('adb shell wm size') do echo 分辨率：%%A
for /f "delims=" %%A in ('adb shell settings get system screen_brightness') do echo 亮度: %%A
for /f "delims=" %%A in ('adb shell getprop ro.build.id') do echo 版本号: %%A
for /f "delims=" %%A in ('adb shell getprop ro.vendor.soc.model.external_name') do (
	if not %%A=="" ( echo 平台扩展名: %%A )
)