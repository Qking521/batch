@echo off
:: 强制 UTF-8 编码
chcp 65001 >nul
setlocal

set "REMOTE_SH=/data/local/tmp/psy_query.sh"
set "LOCAL_SH=%TEMP%\psy_query.sh"

:: 提取脚本
set "SKIP="
for /f "tokens=1 delims=:" %%n in ('findstr /n "^:BEGIN_SHELL_SCRIPT" "%~f0"') do set /a SKIP=%%n
:: 修正：more +%SKIP% 会从标签行的下一行开始提取内容
more +%SKIP% "%~f0" > "%LOCAL_SH%"

echo 正在获取电源供应信息 (Power Supply)...
adb push "%LOCAL_SH%" %REMOTE_SH% >nul 2>&1
:: 清除 Windows 换行符导致的 \r 异常
adb shell "sed -i 's/\r//' %REMOTE_SH%"
adb shell "sh %REMOTE_SH%"
adb shell "rm %REMOTE_SH%"
del "%LOCAL_SH%"
exit /b

:BEGIN_SHELL_SCRIPT
#!/system/bin/sh
for d in /sys/class/power_supply/*; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  type=$(cat "$d/type" 2>/dev/null || echo 'unknown')
  printf '%-15s [ Type: %s ]\n' "$name" "$type"
  
  for f in "$d"/*; do
    [ -f "$f" ] || continue
    prop=$(basename "$f")
    
    # 过滤掉非数据节点
    case "$prop" in 
      uevent|type|name|device|subsystem|power|wakeup|waiting_for_supplier) continue ;; 
    esac
    
    val=$(cat "$f" 2>/dev/null)
    [ -z "$val" ] && continue
    
    d_val="$val"
    case "$prop" in
      voltage_*|current_*|charge_*|energy_*|capacity_now|capacity_full*)
        # 处理微单位到毫单位的转换
        if [ "$val" -ge 1000 ] || [ "$val" -le -1000 ] 2>/dev/null; then
          d_val="$((val / 1000)) (m)"
        fi
        ;;
      temp*)
        # 处理摄氏度转换 (毫度或 0.1 度)
        [ "$val" -ge 1000 ] 2>/dev/null && d_val=$((val / 1000)) || { [ "$val" -ge 100 ] 2>/dev/null && d_val=$((val / 10)); }
        ;;
    esac
    printf '  %-25s : %s\n' "$prop" "$d_val"
  done
done