#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-11-16
# Desc:   Thermal 信息直显工具集（只读，结果直接打印到屏幕，不落盘）
# Usage:  adb shell "sh -s <tz|cd|hm|all>" < thermal_cat.sh
#
# Commands:
#   tz   - 查看所有 Thermal Zone 信息
#   cd   - 查看冷却设备 (Cooling Devices) 信息
#   hm   - 查看硬件监控器 (hwmon) 节点信息
#   all  - 查看以上全部信息
# ============================================================

ACTION="$1"

usage() {
    cat <<EOF
Usage:
  therm cat tz    - 查看所有 Thermal Zone 信息
  therm cat cd    - 查看冷却设备 (Cooling Devices) 信息
  therm cat hm    - 查看硬件监控器 (hwmon) 节点信息
  therm cat all   - 查看以上全部信息
EOF
}

# ---- 输出所有 Thermal Zone 信息表 ----
show_tz() {
    printf '%-3s %-25s %-10s %-12s %-8s\n' 'ID' 'TYPE' 'TEMP(C)' 'POLICY' 'MODE'
    echo "--------------------------------------------------------------------"
    for d in $(ls -d /sys/class/thermal/thermal_zone[0-9]* 2>/dev/null | sort -V); do
        id=${d##*zone}
        type="unknown"; read -r type < "$d/type" 2>/dev/null
        raw_temp=""; read -r raw_temp < "$d/temp" 2>/dev/null

        if [ -z "$raw_temp" ]; then
            temp='N/A'
        elif [ "$raw_temp" -gt 1000 ] 2>/dev/null || [ "$raw_temp" -lt -1000 ] 2>/dev/null; then
            temp="$(( raw_temp / 1000 )).$(( (raw_temp % 1000) / 100 ))"
        else
            temp="$raw_temp"
        fi

        policy="N/A"; read -r policy < "$d/policy" 2>/dev/null
        mode="N/A"; read -r mode < "$d/mode" 2>/dev/null

        printf '%-3s %-25s %-10s %-12s %-8s\n' "$id" "$type" "$temp" "$policy" "$mode"
    done
}

# ---- 冷却设备 (Cooling Devices) ----
show_cd() {
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
}

# ---- 硬件监控器 (hwmon) ----
show_hm() {
    BASE_DIR="/sys/class/hwmon"
    if [ ! -d "$BASE_DIR" ]; then
        echo "[错误] 未找到 $BASE_DIR 接口"
        return 1
    fi

    for d in $(ls -d $BASE_DIR/hwmon* 2>/dev/null | sort -V); do
        name=$(cat $d/name 2>/dev/null || echo 'unknown')
        printf '%-10s [ %s ]\n' "$(basename $d)" "$name"

        for f in $d/*_input; do
            [ -f "$f" ] || continue
            prefix=$(basename $f | sed 's/_input//')
            val=$(cat $f 2>/dev/null)
            label_val=$(cat "$d/${prefix}_label" 2>/dev/null)
            [ -n "$label_val" ] && l_str="($label_val)" || l_str=""

            display_val="$val"
            case "$prefix" in temp*) [ -n "$val" ] && display_val=$((val / 1000)) ;; esac
            printf '  %-10s %-20s : %s\n' "$prefix" "$l_str" "$display_val"
        done

        for f in $(ls $d/pwm[0-9]* 2>/dev/null | grep -v "_enable"); do
            [ -f "$f" ] || continue
            en=$(cat "${f}_enable" 2>/dev/null)
            printf '  %-10s %-20s : %s\n' "$(basename $f)" "(en:$en)" "$(cat $f)"
        done
    done
}

# 主入口路由分发
case "$ACTION" in
    "tz")
        echo "正在获取温度传感器信息..."
        show_tz
        ;;
    "cd")
        show_cd
        ;;
    "hm")
        show_hm
        ;;
    "all")
        echo "===== [Thermal Zone] ====="
        show_tz
        echo ""
        echo "===== [Cooling Devices] ====="
        show_cd
        echo ""
        echo "===== [Hardware Monitor (hwmon)] ====="
        show_hm
        ;;
    -h|--help|help|usage|"")
        usage
        ;;
    *)
        echo "[ERROR] 未知参数: $ACTION" >&2
        usage
        exit 1
        ;;
esac

exit 0
