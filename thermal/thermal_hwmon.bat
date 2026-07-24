@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for thermal_hwmon.bat
:: ============================================================
:: 强制 UTF-8 编码
chcp 65001 >nul
setlocal

if /i "%~1"=="help" goto :show_help
if /i "%~1"=="-h" goto :show_help

goto :process

:show_help
echo HWMON 硬件监控器信息工具
echo =======================
echo 用法: therm hm [help] (或 power hm [help])
echo.
echo 可用命令:
echo   (空)     - 查看当前所有硬件监控器的状态信息 (默认动作).
echo   help     - 显示此帮助信息.
echo.
exit /b

:process
set "REMOTE_SH=/data/local/tmp/hwmon_query.sh"
set "LOCAL_SH=%TEMP%\hwmon_query.sh"

:: 提取脚本逻辑：找到 :BEGIN_SHELL_SCRIPT 标记并跳过前面的 Batch 部分
set "SKIP="
for /f "tokens=1 delims=:" %%n in ('findstr /n "^:BEGIN_SHELL_SCRIPT" "%~f0"') do set /a SKIP=%%n
:: more +n 是从第 n 行开始显示。为了排除标签行本身，直接使用 findstr 查到的行号即可（Batch 行号从 1 开始）
more +%SKIP% "%~f0" > "%LOCAL_SH%"

echo 正在获取硬件监控器信息 (HWMON)...
adb push "%LOCAL_SH%" %REMOTE_SH% >nul 2>&1
:: 清除 Windows 换行符导致的 \r 异常
adb shell "sed -i 's/\r//' %REMOTE_SH%"
adb shell "sh %REMOTE_SH%"
adb shell "rm %REMOTE_SH%"
del "%LOCAL_SH%"
exit /b

:BEGIN_SHELL_SCRIPT
#!/system/bin/sh
# 这里的代码是纯正的 Shell，无需在 Batch 环境下转义
BASE_DIR="/sys/class/hwmon"
if [ ! -d "$BASE_DIR" ]; then
  echo "[错误] 未找到 $BASE_DIR 接口"
  exit 1
fi

for d in $(ls -d $BASE_DIR/hwmon* | sort -V); do
  name=$(cat $d/name 2>/dev/null || echo 'unknown')
  printf '%-10s [ %s ]\n' "$(basename $d)" "$name"
  
  # 处理输入传感器
  for f in $d/*_input; do
    [ -f "$f" ] || continue
    prefix=$(basename $f | sed 's/_input//')
    val=$(cat $f 2>/dev/null)
    label_val=$(cat "$d/${prefix}_label" 2>/dev/null)
    [ -n "$label_val" ] && l_str="($label_val)" || l_str=""
    
    # 温度单位转换
    display_val="$val"
    case "$prefix" in temp*) [ -n "$val" ] && display_val=$((val / 1000)) ;; esac
    printf '  %-10s %-20s : %s\n' "$prefix" "$l_str" "$display_val"
  done

  # 处理 PWM
  for f in $(ls $d/pwm[0-9]* 2>/dev/null | grep -v "_enable"); do
    [ -f "$f" ] || continue
    en=$(cat "${f}_enable" 2>/dev/null)
    printf '  %-10s %-20s : %s\n' "$(basename $f)" "(en:$en)" "$(cat $f)"
  done
done