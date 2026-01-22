@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
echo "adb shell ls /sys/class/regulator/"

:: 获取当前脚本所在目录
set "SCRIPT_DIR=%~dp0"

set "regulator_files_output="
for /f "delims=" %%i in ('adb shell ls /sys/class/regulator/') do (
    set "regulator_files_output=!regulator_files_output! %%i"
)
::echo 原始文件列表: "!regulator_files_output!"
set "regulator_file_count=0"
for %%f in (!regulator_files_output!) do (
     echo %%f | findstr /i "regulator" >nul && (
        set /a "regulator_file_count+=1"
    )
)
echo 文件数量: !regulator_file_count!

adb shell ^
"i=0 ; while [[ $i -lt !regulator_file_count! ]] ; do ^
(type=`cat /sys/class/regulator/regulator.$i/type` ; ^
name=`cat /sys/class/regulator/regulator.$i/name` ; ^
num_users=`cat /sys/class/regulator/regulator.$i/num_users` ; ^
echo "$i	$type	$name	$num_users"); ^
i=$((i+1)); done  | column -t"

endlocal