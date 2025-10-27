@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
echo "adb shell ls /sys/class/thermal/"

:: 获取当前脚本所在目录
set "SCRIPT_DIR=%~dp0"

set "thermal_files_output="
for /f "delims=" %%i in ('adb shell ls /sys/class/thermal/') do (
    set "thermal_files_output=!thermal_files_output! %%i"
)
::echo 原始文件列表: "!thermal_files_output!"
set "thermal_file_count=0"
for %%f in (!thermal_files_output!) do (
     echo %%f | findstr /i "thermal_zone" >nul && (
        set /a "thermal_file_count+=1"
    )
)
echo 文件数量: !thermal_file_count!

rem get thermal zone name and temp
adb root >nul 2>&1

rem adb shell "i=0 ; while [[ $i -lt !thermal_file_count! ]] ; do (type=`cat /sys/class/thermal/thermal_zone$i/type` ; temp=`cat /sys/class/thermal/thermal_zone$i/temp` ; echo "$i $type : $temp"); i=$((i+1));done"
adb shell ^
"i=0 ; while [[ $i -lt !thermal_file_count! ]] ; do ^
(type=`cat /sys/class/thermal/thermal_zone$i/type` ; ^
temp=`cat /sys/class/thermal/thermal_zone$i/temp` ; ^
policy=`cat /sys/class/thermal/thermal_zone$i/policy` ; ^
echo "$i	$type	$temp	$policy"); ^
i=$((i+1)); done  | column -t"
pause
endlocal