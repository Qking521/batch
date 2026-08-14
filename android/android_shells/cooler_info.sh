    echo "正在获取冷却设备信息 (Cooling Devices)..."
    printf '%-3s %-25s %-12s %-12s\n' 'ID' 'TYPE' 'CUR_STATE' 'MAX_STATE'
    echo "------------------------------------------------------------"
    for d in /sys/class/thermal/cooling_device[0-9]*; do
        [ -d "$d" ] || continue
        id=${d##*device}
        type=$(cat $d/type 2>/dev/null || echo 'N/A')
        cur_state=$(cat $d/cur_state 2>/dev/null || echo 'N/A')
        max_state=$(cat $d/max_state 2>/dev/null || echo 'N/A')
        printf '%-3s %-25s %-12s %-12s\n' "$id" "$type" "$cur_state" "$max_state"
    done | sort -n