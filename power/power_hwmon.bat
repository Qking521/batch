@echo off
:: 强制 UTF-8 编码
chcp 65001 >nul
setlocal

echo 正在获取硬件监控器信息 (HWMON)...

:: 检查基础路径是否存在
adb shell "ls -d /sys/class/hwmon/hwmon* >/dev/null 2>&1"
if %ERRORLEVEL% neq 0 (
    echo [错误] 未在设备上找到 /sys/class/hwmon 接口。
    exit /b 1
)

:: 构建 Shell 命令：遍历 hwmon 节点，输出名称及传感器详细信息
set "SH=for d in $(ls -d /sys/class/hwmon/hwmon* | sort -V); do "
set "SH=%SH%  name=$(cat $d/name 2>/dev/null || echo 'unknown'); "
set "SH=%SH%  printf '%%-10s [ %%s ]\n' \"$(basename $d)\" \"$name\"; "
set "SH=%SH%  for f in $d/*_input; do "
set "SH=%SH%    [ -f \"$f\" ] || continue; "
set "SH=%SH%    prefix=$(basename $f | sed 's/_input//'); "
set "SH=%SH%    val=$(cat $f 2>/dev/null); "
set "SH=%SH%    l_file=\"$d/${prefix}_label\"; "
set "SH=%SH%    [ -f \"$l_file\" ] && l_val=\"($(cat $l_file))\" || l_val=\"\"; "
set "SH=%SH%    d_val=\"$val\"; "
set "SH=%SH%    case \"$prefix\" in temp*) [ ! -z \"$val\" ] && d_val=$((val / 1000)) ;; esac; "
set "SH=%SH%    printf '  %%-10s %%-20s : %%s\n' \"$prefix\" \"$l_val\" \"$d_val\"; "
set "SH=%SH%  done; "
set "SH=%SH%  for f in $d/pwm[0-9]*; do "
set "SH=%SH%    [ -f \"$f\" ] || continue; "
set "SH=%SH%    case \"$(basename $f)\" in *_enable) continue ;; esac; "
set "SH=%SH%    p_name=$(basename $f); "
set "SH=%SH%    p_val=$(cat $f 2>/dev/null); "
set "SH=%SH%    e_file=\"${f}_enable\"; "
set "SH=%SH%    [ -f \"$e_file\" ] && e_val=\"(en:$(cat $e_file))\" || e_val=\"\"; "
set "SH=%SH%    printf '  %%-10s %%-20s : %%s\n' \"$p_name\" \"$e_val\" \"$p_val\"; "
set "SH=%SH%  done; "
set "SH=%SH%done"

adb shell "%SH%"
exit /b