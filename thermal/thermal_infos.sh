#!/system/bin/sh
# ============================================================
# Author: Antigravity Pair Program
# Date:   2026-08-07
# Desc:   Thermal 硬件监控、冷却设备与 Thermal Zone 整合管理工具
# Usage:  adb shell "sh -s <cmd> [sub_action|params]" < thermal_infos.sh
#
# Commands:
#   tz [dis|en|info|zone_type...] - Thermal Zone 查询、禁用/启用管理
#   cd                            - 冷却设备 (Cooling Devices) 信息
#   hm                            - 硬件监控器 (hwmon) 节点信息
# ============================================================

CMD="$1"
LOG_FILE="/data/local/tmp/orig_enabled_tz.txt"

# ---- 将 type 名称转小写 ----
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# ---- 显示 Thermal Zone 的 Usage 帮助信息 ----
show_tz_usage() {
    cat <<EOF
Usage:
  therm tz [info]           - 查看所有 Thermal Zone 信息 (默认)
  therm tz dis|disable      - 禁用所有已开启的 Thermal Zone
  therm tz en|enable        - 恢复被禁用的 Thermal Zone
  therm tz <zone_type>      - 按 type 名称查询指定 zone 详情
  therm tz <z1> <z2> ...    - 查询多个指定 zone (如: therm tz front_temp back_temp)
EOF
}

# ---- 按 type 名称查找对应 thermal zone 目录 ----
find_zone_by_type() {
    local target_lower
    target_lower=$(to_lower "$1")
    for d in $(ls -d /sys/class/thermal/thermal_zone* 2>/dev/null | sort -V); do
        type=$(cat "$d/type" 2>/dev/null)
        type_lower=$(to_lower "$type")
        if [ "$type_lower" = "$target_lower" ]; then
            echo "$d"
            return 0
        fi
    done
    return 1
}

# ---- 打印指定 zone 的详细信息 ----
show_zone_detail() {
    local d="$1"
    local id=${d##*zone}
    local type=$(cat "$d/type" 2>/dev/null || echo 'unknown')
    local raw_temp=$(cat "$d/temp" 2>/dev/null)
    local mode=$(cat "$d/mode" 2>/dev/null || echo 'N/A')
    local policy=$(cat "$d/policy" 2>/dev/null || echo 'N/A')
    local avail_policies=$(cat "$d/available_policies" 2>/dev/null || echo 'N/A')
    local slope=$(cat "$d/slope" 2>/dev/null || echo 'N/A')
    local offset=$(cat "$d/offset" 2>/dev/null || echo 'N/A')
    local sustainable_power=$(cat "$d/sustainable_power" 2>/dev/null || echo 'N/A')

    local temp_str
    if [ -z "$raw_temp" ]; then
        temp_str="N/A"
    elif [ "$raw_temp" -gt 1000 ] 2>/dev/null || [ "$raw_temp" -lt -1000 ] 2>/dev/null; then
        temp_str="$(( raw_temp / 1000 )).$(( (raw_temp % 1000) / 100 )) C"
    else
        temp_str="${raw_temp} C"
    fi

    echo "========================================"
    echo " Thermal Zone 详细信息"
    echo "========================================"
    printf '  %-22s: %s\n' "Zone ID"          "thermal_zone${id}"
    printf '  %-22s: %s\n' "Type"             "$type"
    printf '  %-22s: %s\n' "Temperature"      "$temp_str"
    printf '  %-22s: %s\n' "Mode"             "$mode"
    printf '  %-22s: %s\n' "Policy"           "$policy"
    printf '  %-22s: %s\n' "Avail Policies"    "$avail_policies"
    printf '  %-22s: %s\n' "Slope"            "$slope"
    printf '  %-22s: %s\n' "Offset"           "$offset"
    printf '  %-22s: %s\n' "Sustainable Pwr"  "$sustainable_power"
    printf '  %-22s: %s\n' "Sysfs Path"       "$d"

    if [ -d "$d/power" ]; then
        local cdev_list=$(ls "$d/" 2>/dev/null | grep '^cdev')
        if [ -n "$cdev_list" ]; then
            echo ""
            echo "  [关联 Cooling Devices]"
            for cdev in $cdev_list; do
                local cdev_path="$d/$cdev"
                local cdev_type=$(cat "$cdev_path/type" 2>/dev/null || echo 'unknown')
                local cur_state=$(cat "$cdev_path/cur_state" 2>/dev/null || echo 'N/A')
                local max_state=$(cat "$cdev_path/max_state" 2>/dev/null || echo 'N/A')
                printf '    %-20s type=%-25s cur_state=%-5s max_state=%s\n' \
                    "$cdev" "$cdev_type" "$cur_state" "$max_state"
            done
        fi
    fi
    echo "========================================"
}

# 1. Thermal Zone 模块处理
handle_tz() {
    shift 1 # 移除 'tz' 参数
    local action="$1"

    case "$action" in
        "dis"|"disable")
            if [ "$(id -u)" -ne 0 ]; then
                echo "[ERROR] 禁用 Thermal Zone 需要 root 权限，请先运行 'adb root'" >&2
                exit 1
            fi
            echo "正在记录并禁用当前开启的温度传感器 (Thermal Zones)..."
            rm -f "$LOG_FILE"
            for d in $(ls -d /sys/class/thermal/thermal_zone* 2>/dev/null | sort -V); do
                mode=$(cat "$d/mode" 2>/dev/null)
                if [ "$mode" = "enabled" ]; then
                    echo "$d" >> "$LOG_FILE"
                    echo "disabled" > "$d/mode" 2>/dev/null
                    type=$(cat "$d/type" 2>/dev/null || echo 'unknown')
                    echo "[已禁用] $d ($type)"
                fi
            done
            [ -f "$LOG_FILE" ] && echo -e "\n操作完成。记录在: $LOG_FILE" || echo -e "\n无需操作：没有发现处于开启状态的传感器。"
            ;;

        "en"|"enable")
            if [ "$(id -u)" -ne 0 ]; then
                echo "[ERROR] 恢复 Thermal Zone 需要 root 权限，请先运行 'adb root'" >&2
                exit 1
            fi
            echo "正在恢复先前被禁用的温度传感器..."
            if [ ! -f "$LOG_FILE" ]; then
                echo "[警告] 未找到状态记录文件 $LOG_FILE，可能未执行过 disable 或已恢复。"
                exit 1
            fi
            for d in $(cat "$LOG_FILE"); do
                if [ -d "$d" ]; then
                    echo "enabled" > "$d/mode" 2>/dev/null
                    type=$(cat "$d/type" 2>/dev/null || echo 'unknown')
                    echo "[已恢复] $d ($type)"
                fi
            done
            rm -f "$LOG_FILE"
            echo -e "\n恢复完成。"
            ;;

        "info"|"")
            echo "正在获取温度传感器信息..."
            printf '%-3s %-25s %-10s %-12s %-8s\n' 'ID' 'TYPE' 'TEMP(C)' 'POLICY' 'MODE'
            echo "--------------------------------------------------------------------"
            for d in $(ls -d /sys/class/thermal/thermal_zone* 2>/dev/null | sort -V); do
                id=${d##*zone}
                type=$(cat "$d/type" 2>/dev/null || echo 'unknown')
                raw_temp=$(cat "$d/temp" 2>/dev/null)

                if [ -z "$raw_temp" ]; then
                    temp='N/A'
                elif [ "$raw_temp" -gt 1000 ] 2>/dev/null || [ "$raw_temp" -lt -1000 ] 2>/dev/null; then
                    temp="$(( raw_temp / 1000 )).$(( (raw_temp % 1000) / 100 ))"
                else
                    temp="$raw_temp"
                fi

                policy=$(cat "$d/policy" 2>/dev/null || echo 'N/A')
                mode=$(cat "$d/mode" 2>/dev/null || echo 'N/A')

                printf '%-3s %-25s %-10s %-12s %-8s\n' "$id" "$type" "$temp" "$policy" "$mode"
            done
            ;;

        *)
            found_any=0
            for zone_name in "$@"; do
                zone_dir=$(find_zone_by_type "$zone_name")
                if [ -n "$zone_dir" ]; then
                    show_zone_detail "$zone_dir"
                    found_any=1
                fi
            done
            if [ "$found_any" -eq 0 ]; then
                echo "[ERROR] 未找到参数匹配的 Thermal Zone: '$*'"
                echo ""
                show_tz_usage
                exit 1
            fi
            ;;
    esac
}

# 2. Cooling Devices 模块处理
handle_cd() {
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

# 3. Hardware Monitor (hwmon) 模块处理
handle_hm() {
    BASE_DIR="/sys/class/hwmon"
    if [ ! -d "$BASE_DIR" ]; then
        echo "[错误] 未找到 $BASE_DIR 接口"
        exit 1
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
case "$CMD" in
    "tz") handle_tz "$@" ;;
    "cd") handle_cd "$@" ;;
    "hm") handle_hm "$@" ;;
    *)
        echo "[ERROR] 未知或缺省命令: '$CMD'"
        echo "用法: thermal_infos.sh <tz|cd|hm> [dis|en|params]"
        exit 1
        ;;
esac

exit 0