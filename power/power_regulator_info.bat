@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo 正在获取供电单元信息 (Regulators)...

:: 构造获取 Regulator 信息的 Shell 脚本字符串
set "SH_REGULATOR=printf '%%-3s %%-15s %%-30s %%-10s\n' 'ID' 'TYPE' 'NAME' 'USERS'; "
set "SH_REGULATOR=!SH_REGULATOR!for d in /sys/class/regulator/regulator.[0-9]*; do "
set "SH_REGULATOR=!SH_REGULATOR!  id=${d##*regulator.}; "
set "SH_REGULATOR=!SH_REGULATOR!  type=$(cat $d/type 2>/dev/null || echo 'N/A'); "
set "SH_REGULATOR=!SH_REGULATOR!  name=$(cat $d/name 2>/dev/null || echo 'N/A'); "
set "SH_REGULATOR=!SH_REGULATOR!  num_users=$(cat $d/num_users 2>/dev/null || echo 'N/A'); "
set "SH_REGULATOR=!SH_REGULATOR!  printf '%%-3s %%-15s %%-30s %%-10s\n' \"$id\" \"$type\" \"$name\" \"$num_users\"; "
set "SH_REGULATOR=!SH_REGULATOR!done | sort -n"

adb shell "!SH_REGULATOR!"

endlocal