@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo 正在获取冷却设备信息 (Cooling Devices)...

:: 构造获取 Cooling Device 信息的 Shell 脚本字符串
set "SH_COOLING=printf '%%-3s %%-25s %%-12s %%-12s\n' 'ID' 'TYPE' 'CUR_STATE' 'MAX_STATE'; "
set "SH_COOLING=!SH_COOLING!for d in /sys/class/thermal/cooling_device[0-9]*; do "
set "SH_COOLING=!SH_COOLING!  id=${d##*device}; "
set "SH_COOLING=!SH_COOLING!  type=$(cat $d/type 2>/dev/null || echo 'N/A'); "
set "SH_COOLING=!SH_COOLING!  cur_state=$(cat $d/cur_state 2>/dev/null || echo 'N/A'); "
set "SH_COOLING=!SH_COOLING!  max_state=$(cat $d/max_state 2>/dev/null || echo 'N/A'); "
set "SH_COOLING=!SH_COOLING!  printf '%%-3s %%-25s %%-12s %%-12s\n' \"$id\" \"$type\" \"$cur_state\" \"$max_state\"; "
set "SH_COOLING=!SH_COOLING!done | sort -n"

adb shell "!SH_COOLING!"

endlocal