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