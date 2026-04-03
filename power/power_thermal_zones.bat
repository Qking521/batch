@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo 正在获取温度传感器信息 (NTC)...

:: 构造获取 Thermal Zone 信息的 Shell 脚本字符串
set "SH=printf '%%-3s %%-25s %%-8s %%-10s %%-10s\n' 'ID' 'TYPE' 'TEMP(C)' 'POLICY' 'MODE'; "
set "SH=!SH!for d in /sys/class/thermal/thermal_zone[0-9]*; do "
set "SH=!SH!  id=${d##*zone}; "
set "SH=!SH!  type=$(cat $d/type 2>/dev/null || echo 'unknown'); "
set "SH=!SH!  raw_temp=$(cat $d/temp 2>/dev/null); "
set "SH=!SH!  [ -z \"$raw_temp\" ] && temp='N/A' || temp=$((raw_temp / 1000)); "
set "SH=!SH!  policy=$(cat $d/policy 2>/dev/null || echo 'N/A'); "
set "SH=!SH!  mode=$(cat $d/mode 2>/dev/null || echo 'N/A'); "
set "SH=!SH!  printf '%%-3s %%-25s %%-8s %%-10s %%-10s\n' \"$id\" \"$type\" \"$temp\" \"$policy\" \"$mode\"; "
set "SH=!SH!done | sort -n"

adb shell "!SH!"

endlocal