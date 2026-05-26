@echo off
:: 强制 UTF-8 编码，防止中文乱码引起的位移错误
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 脚本头部标准
:: Author: Linqun & Gemini
:: Description: Android Device Info Collector (Optimized for Power/Performance)

echo 收集信息中，请稍候...

:: 环境检查
adb wait-for-device

:: 初始化变量，防止计算时因空值崩溃
set "res_board=Unknown" & set "res_soc=Unknown" & set "res_id=Unknown" & set "res_sn=Unknown"
set "res_sku=Unknown" & set "res_wm=Unknown" & set "res_fps=Unknown" & set "res_bri=0"
set "res_batt_level=0" & set "res_batt_health=U" & set "res_batt_status=U"
set "res_batt_volt=0" & set "res_batt_temp=0" & set "res_batt_curr=0" & set "res_uptime=0"
set "res_batt_count=0" & set "res_mem=0" & set "res_disk=" & set "res_bri_mode=U"
set "res_wl=None" & set "res_cpu_abi=Unknown" & set "res_cpu_cores=0" & set "res_gpu=Unknown"

:: 构建单次执行的 ADB 命令
set "ADB_CMD=echo board:$(getprop ro.product.board);"
set "ADB_CMD=!ADB_CMD! echo mem:$(cat /proc/meminfo | grep MemTotal);"
set "ADB_CMD=!ADB_CMD! echo disk:$(dumpsys diskstats ^| grep Data-Free);"
set "ADB_CMD=!ADB_CMD! echo sn:$(getprop ro.serialno);"
set "ADB_CMD=!ADB_CMD! echo sku:$(getprop ro.boot.hardware.sku);"
set "ADB_CMD=!ADB_CMD! echo fps:$(dumpsys SurfaceFlinger ^| grep -oE "vsyncRate=[0-9.]+" ^| sed -n '1p' ^| cut -d= -f2);"
set "ADB_CMD=!ADB_CMD! echo wm:$(wm size ^| sed -n '1p' ^| cut -d' ' -f3);"
set "ADB_CMD=!ADB_CMD! echo bri:$(settings get system screen_brightness);"
set "ADB_CMD=!ADB_CMD! echo bri_mode:$(settings get system screen_brightness_mode);"
set "ADB_CMD=!ADB_CMD! echo id:$(getprop ro.build.id);"
set "ADB_CMD=!ADB_CMD! echo soc:$(getprop ro.vendor.soc.model.external_name);"
set "ADB_CMD=!ADB_CMD! echo cpu_abi:$(getprop ro.product.cpu.abi);"
set "ADB_CMD=!ADB_CMD! echo cpu_cores:$(grep -c ^^processor /proc/cpuinfo);"
set "ADB_CMD=!ADB_CMD! echo cpu_layout:$(ls -d /sys/devices/system/cpu/cpufreq/policy* 2^>/dev/null ^| while read p; do cat $p/related_cpus ^| wc -w; done ^| xargs ^| sed 's/ /+/g');"
set "ADB_CMD=!ADB_CMD! echo gpu_info:$(dumpsys SurfaceFlinger ^| grep "^GLES:" ^| sed -n '1p' ^| cut -d, -f2 ^| sed 's/^[ ]*//');"
set "ADB_CMD=!ADB_CMD! dumpsys battery ^| grep -Ei 'level|health|status|voltage|temp|now|counter' ^| sed 's/current now/currentnow/; s/charge counter/chargecounter/; s/^[ ]*//';"
set "ADB_CMD=!ADB_CMD! echo uptime:$(cat /proc/uptime ^| cut -d' ' -f1 ^| cut -d'.' -f1);"
set "ADB_CMD=!ADB_CMD! echo wakelock:$(dumpsys power 2^>/dev/null ^| grep "mWakeLockSummary=" ^| sed -n '1p' ^| cut -d= -f2);"

:: 执行并解析结果
for /f "tokens=1* delims=:" %%A in ('adb shell "!ADB_CMD!" 2^>nul') do (
    set "v=%%B"
    if not "!v!"=="" (
        if "!v:~0,1!"==" " set "v=!v:~1!"
        set "k=%%A" & set "k=!k: =!"
        if "!k!"=="board" set "res_board=!v!"
        if "!k!"=="mem" set "res_mem=!v!"
        if "!k!"=="disk" set "res_disk=!v!"
        if "!k!"=="sn" set "res_sn=!v!"
        if "!k!"=="sku" set "res_sku=!v!"
        if "!k!"=="fps" set "res_fps=!v!"
        if "!k!"=="wm" set "res_wm=!v!"
        if "!k!"=="bri" set "res_bri=!v!"
        if "!k!"=="bri_mode" set "res_bri_mode=!v!"
        if "!k!"=="id" set "res_id=!v!"
        if "!k!"=="soc" set "res_soc=!v!"
        if "!k!"=="cpu_abi" set "res_cpu_abi=!v!"
        if "!k!"=="cpu_cores" set "res_cpu_cores=!v!"
        if "!k!"=="cpu_layout" set "res_cpu_layout=!v!"
        if "!k!"=="gpu_info" set "res_gpu=!v!"
        if "!k!"=="level" set "res_batt_level=!v!"
        if "!k!"=="health" set "res_batt_health=!v!"
        if "!k!"=="status" set "res_batt_status=!v!"
        if "!k!"=="voltage" set "res_batt_volt=!v!"
        if "!k!"=="temperature" set "res_batt_temp=!v!"
        if "!k!"=="currentnow" set "res_batt_curr=!v!"
        if "!k!"=="chargecounter" set "res_batt_count=!v!"
        if "!k!"=="uptime" set "res_uptime=!v!"
        if "!k!"=="wakelock" set "res_wl=!v!"
    )
)

:: 后期计算逻辑
set /a mem_gb=0
for /f "tokens=2" %%a in ("!res_mem!") do set /a "mem_gb=(%%a / 1024 / 1024) + 1" 2>nul

set "rom_rs=Unknown"
if defined res_disk for /f "tokens=2 delims=/ " %%a in ("!res_disk!") do (
    set "tkb=%%a" & set "tkb=!tkb:K=!"
    set /a "tgb=!tkb! / 1000000" 2>nul
    for %%s in (32 64 128 256 512 1024) do (if !tgb! LEQ %%s if "!rom_rs!"=="Unknown" set rom_rs=%%s)
)

set /a "up_min=res_uptime / 60" 2>nul
set /a "curr_ma=!res_batt_curr! / 1000" 2>nul
set /a "batt_mah=!res_batt_count! / 1000" 2>nul

:: WakeLock 语义映射
for /f "tokens=1" %%i in ("!res_wl!") do set "res_wl=%%i"
if "!res_wl!"=="0x0" set "res_wl=0x0(None)"
if "!res_wl!"=="0x1" set "res_wl=0x1(PARTIAL)"
if "!res_wl!"=="0x2" set "res_wl=0x2(OTHER)"
if "!res_wl!"=="0x40" set "res_wl=0x40(DOZE)"

:: 实时功率计算 W = (V * mA) / 1,000,000
set /a "mw_val=(res_batt_volt * curr_ma) / 1000" 2>nul
set "p_sign=" & if !mw_val! LSS 0 set "p_sign=-"
set /a "mw_abs=mw_val" & if !mw_val! LSS 0 set /a "mw_abs=-mw_val"
set /a "p_main=mw_abs / 1000" & set /a "p_rem=mw_abs %% 1000"
set "p_dec=00!p_rem!" & set "p_dec=!p_dec:~-3,2!"

set "t_main=0" & set "t_dec=0"
if not "!res_batt_temp!"=="" (
    if !res_batt_temp! GTR 9 (
        set "t_main=!res_batt_temp:~0,-1!"
        set "t_dec=!res_batt_temp:~-1!"
    ) else if !res_batt_temp! GTR 0 (
        set "t_main=0" & set "t_dec=!res_batt_temp!"
    )
)

:: 最终输出
echo ============================================================
echo [设备] !res_board! (!res_soc!) ^| ID:!res_id!
echo [核心] CPU:!res_cpu_abi! (!res_cpu_cores!核: !res_cpu_layout!) ^| GPU:!res_gpu!
echo [规格] SN:!res_sn! ^| SKU:!res_sku!
echo [屏幕] Size:!res_wm! ^| FPS:!res_fps! ^| Bri:!res_bri! (Mode:!res_bri_mode!)
echo [存储] RAM:!mem_gb!G ^| ROM:!rom_rs!G
echo [电池] Level:!res_batt_level!%% ^| Cap:!batt_mah!mAh ^| Temp:!t_main!.!t_dec!C
echo [实时] Curr:!curr_ma!mA ^| Power:!p_sign!!p_main!.!p_dec!W ^| Volt:!res_batt_volt!mV
echo [状态] State:!res_batt_status!(1un/2chg/3dis/4not/5full) ^| Heal:!res_batt_health!(2good) ^| WL:!res_wl! ^| Up:!up_min!min
echo ============================================================
endlocal
