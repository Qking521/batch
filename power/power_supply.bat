@echo off
:: 强制 UTF-8 编码
chcp 65001 >nul
setlocal

echo 正在获取电源供应信息 (Power Supply)...

:: 检查基础路径是否存在
adb shell "ls -d /sys/class/power_supply/* >/dev/null 2>&1"
if %ERRORLEVEL% neq 0 (
    echo [错误] 未在设备上找到 /sys/class/power_supply 接口。
    exit /b 1
)
echo power supply path : /sys/class/power_supply/*

:: 构建 Shell 命令：遍历 power_supply 节点，列出详细属性
set "SH=for d in $(ls -d /sys/class/power_supply/* | sort -V); do "
set "SH=%SH%  type=$(cat $d/type 2>/dev/null || echo 'unknown'); "
set "SH=%SH%  printf '%%-15s [ Type: %%s ]\n' \"$(basename $d)\" \"$type\"; "
set "SH=%SH%  for f in $d/*; do "
set "SH=%SH%    [ -f \"$f\" ] || continue; "
set "SH=%SH%    prop=$(basename $f); "
set "SH=%SH%    case \"$prop\" in uevent|type|name|device|subsystem|power|wakeup|waiting_for_supplier) continue ;; esac; "
set "SH=%SH%    val=$(cat $f 2>/dev/null); "
set "SH=%SH%    [ -z \"$val\" ] && continue; "
set "SH=%SH%    d_val=\"$val\"; "
:: 单位转换逻辑：针对数值较大的电压/电流/容量项除以 1000，针对温度根据位数除以 10 或 1000
set "SH=%SH%    case \"$prop\" in voltage_*|current_*|charge_*|energy_*|capacity_now|capacity_full*) [ \"$val\" -ge 1000 -o \"$val\" -le -1000 ] 2>/dev/null && d_val=\"$((val / 1000)) (m)\" ;; "
set "SH=%SH%    temp*) [ \"$val\" -ge 1000 ] 2>/dev/null && d_val=$((val / 1000)) || { [ \"$val\" -ge 100 ] 2>/dev/null && d_val=$((val / 10)); } ;; esac; "
set "SH=%SH%    printf '  %%-25s : %%s\n' \"$prop\" \"$d_val\"; "
set "SH=%SH%  done; "
set "SH=%SH%done"

adb shell "%SH%"
exit /b