#!/system/bin/sh

ACTION=$1
LOG_FILE="/data/local/tmp/orig_enabled_tz.txt"

case "$ACTION" in
    "disable")
        echo "正在记录并禁用当前开启的温度传感器 (Thermal Zones)..."
        rm -f "$LOG_FILE"
        # 使用 sort -V 进行自然排序 (zone1, zone2, zone10)
        for d in $(ls -d /sys/class/thermal/thermal_zone* | sort -V); do
            mode=$(cat $d/mode 2>/dev/null)
            if [ "$mode" = "enabled" ]; then
                echo $d >> "$LOG_FILE"
                echo "disabled" > $d/mode
                type=$(cat $d/type 2>/dev/null || echo 'unknown')
                echo "[已禁用] $d ($type)"
            fi
        done
        [ -f "$LOG_FILE" ] && echo "\n操作完成。记录在: $LOG_FILE" || echo "\n无需操作：没有发现处于开启状态的传感器。"
        ;;

    "enable")
        echo "正在恢复先前被禁用的温度传感器..."
        if [ ! -f "$LOG_FILE" ]; then
            echo "[警告] 未找到状态记录文件 $LOG_FILE，可能未执行过 tz-dis 或已恢复。"
            exit 1
        fi
        for d in $(cat "$LOG_FILE"); do
            if [ -d "$d" ]; then
                echo "enabled" > $d/mode
                type=$(cat $d/type 2>/dev/null || echo 'unknown')
                echo "[已恢复] $d ($type)"
            fi
        done
        rm -f "$LOG_FILE"
        echo "\n恢复完成。"
        ;;

    "info")
        echo "正在获取温度传感器信息 (NTC)..."
        printf '%-3s %-25s %-8s %-10s %-10s\n' 'ID' 'TYPE' 'TEMP(C)' 'POLICY' 'MODE'
        echo "--------------------------------------------------------------------------"
        for d in $(ls -d /sys/class/thermal/thermal_zone* | sort -V); do
            id=${d##*zone}
            type=$(cat $d/type 2>/dev/null || echo 'unknown')
            raw_temp=$(cat $d/temp 2>/dev/null)

            # 温度换算
            if [ -z "$raw_temp" ]; then
                temp='N/A'
            else
                temp=$((raw_temp / 1000))
            fi

            policy=$(cat $d/policy 2>/dev/null || echo 'N/A')
            mode=$(cat $d/mode 2>/dev/null || echo 'N/A')

            printf '%-3s %-25s %-8s %-10s %-10s\n' "$id" "$type" "$temp" "$policy" "$mode"
        done
        ;;
esac