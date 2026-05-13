@echo off
chcp 65001 >nul
setlocal

if /i "%~1"=="tz-dis" goto :disable_all
if /i "%~1"=="tz-en" goto :enable_all
goto :show_info

:disable_all
echo 正在记录并禁用当前开启的温度传感器 (Thermal Zones)...

:: 手动执行命令示例 (强制禁用所有传感器，不考虑原有状态):
:: adb shell "for d in /sys/class/thermal/thermal_zone*; do echo disabled > $d/mode; done"

set "DIS_SH=rm -f /data/local/tmp/orig_enabled_tz.txt; "
set "DIS_SH=%DIS_SH%for d in $(ls -d /sys/class/thermal/thermal_zone* | sort -V); do "
set "DIS_SH=%DIS_SH%  mode=$(cat $d/mode 2>/dev/null); "
set "DIS_SH=%DIS_SH%  if [ \"$mode\" = \"enabled\" ]; then "
set "DIS_SH=%DIS_SH%    echo $d >> /data/local/tmp/orig_enabled_tz.txt; "
set "DIS_SH=%DIS_SH%    echo disabled > $d/mode; "
set "DIS_SH=%DIS_SH%    echo \"[已禁用] $d ($(cat $d/type))\"; "
set "DIS_SH=%DIS_SH%  fi; "
set "DIS_SH=%DIS_SH%done"
adb shell "%DIS_SH%"
echo.
echo 操作完成。受影响的传感器已记录在: /data/local/tmp/orig_enabled_tz.txt
exit /b

:enable_all
echo 正在恢复先前被禁用的温度传感器...

:: 手动执行命令示例 (强制启用所有传感器，不考虑原有状态):
:: adb shell "for d in /sys/class/thermal/thermal_zone*; do echo enabled > $d/mode; done"

:: 检查记录文件是否存在，并根据结果执行
adb shell "test -f /data/local/tmp/orig_enabled_tz.txt"
if %ERRORLEVEL% equ 0 (
    echo 记录文件存在，正在恢复 Thermal Zones...
    set "EN_SH=for d in $(cat /data/local/tmp/orig_enabled_tz.txt); do "
    set "EN_SH=%EN_SH%    echo enabled > $d/mode; "
    set "EN_SH=%EN_SH%    echo \"[已恢复] $d ($(cat $d/type))\"; "
    set "EN_SH=%EN_SH%  done; "
    set "EN_SH=%EN_SH%  rm -f /data/local/tmp/orig_enabled_tz.txt"
    adb shell "%EN_SH%"
) else (
    echo [警告] 未找到状态记录文件 /data/local/tmp/orig_enabled_tz.txt，可能未执行过 tz-dis 或已恢复。
)
exit /b

:show_info
echo 正在获取温度传感器信息 (NTC)...

:: 手动执行命令示例 (Manual execution command example):
:: adb shell "i=0 ; while [[ $i -lt 64 ]] ; do if [ -d /sys/class/thermal/thermal_zone$i ]; then type=$(cat /sys/class/thermal/thermal_zone$i/type 2>/dev/null || echo 'unknown'); temp=$(cat /sys/class/thermal/thermal_zone$i/temp 2>/dev/null); [ -z \"$temp\" ] && temp='N/A' || temp=$((temp / 1000)); echo \"$i $type : $temp\"; fi; i=$((i+1));done"

set "SH=printf '%%-3s %%-25s %%-8s %%-10s %%-10s\n' 'ID' 'TYPE' 'TEMP(C)' 'POLICY' 'MODE'; "
set "SH=%SH%for d in $(ls -d /sys/class/thermal/thermal_zone* | sort -V); do "
set "SH=%SH%  id=${d##*zone}; "
set "SH=%SH%  type=$(cat $d/type 2>/dev/null || echo 'unknown'); "
set "SH=%SH%  raw_temp=$(cat $d/temp 2>/dev/null); "
set "SH=%SH%  [ -z \"$raw_temp\" ] && temp='N/A' || temp=$((raw_temp / 1000)); "
set "SH=%SH%  policy=$(cat $d/policy 2>/dev/null || echo 'N/A'); "
set "SH=%SH%  mode=$(cat $d/mode 2>/dev/null || echo 'N/A'); "
set "SH=%SH%  printf '%%-3s %%-25s %%-8s %%-10s %%-10s\n' \"$id\" \"$type\" \"$temp\" \"$policy\" \"$mode\"; "
set "SH=%SH%done"
adb shell "%SH%"
exit /b