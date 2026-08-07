#!/system/bin/sh
# ============================================================
# Author: Antigravity Pair Program
# Date:   2026-08-07
# Desc:   Thermal Zone 查询、禁用/恢复管理工具
# Usage:  adb shell "sh -s <action|zone_name>" < thermal_thermal_zones.sh
#
# Actions:
#   info                  - 列出所有 Thermal Zone 的基础信息
#   disable               - 禁用所有当前 enabled 的 Thermal Zone
#   enable                - 恢复之前被禁用的 Thermal Zone
#   <zone_type_name>      - 按 type 名称（大小写不敏感）查询指定 zone 详情
#                           例: front_temp / FRONT_TEMP / cpu-big-core0-0
# ============================================================

ACTION="$1"
LOG_FILE="/data/local/tmp/orig_enabled_tz.txt"

# ---- 将 type 名称转小写（兼容 Android sh 无 ${var,,} 语法）----
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
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
    local id
    id=${d##*zone}
    local type
    type=$(cat "$d/type" 2>/dev/null || echo 'unknown')
    local raw_temp
    raw_temp=$(cat "$d/temp" 2>/dev/null)
    local mode
    mode=$(cat "$d/mode" 2>/dev/null || echo 'N/A')
    local policy
    policy=$(cat "$d/policy" 2>/dev/null || echo 'N/A')
    local avail_policies
    avail_policies=$(cat "$d/available_policies" 2>/dev/null || echo 'N/A')
    local slope
    slope=$(cat "$d/slope" 2>/dev/null || echo 'N/A')
    local offset
    offset=$(cat "$d/offset" 2>/dev/null || echo 'N/A')
    local sustainable_power
    sustainable_power=$(cat "$d/sustainable_power" 2>/dev/null || echo 'N/A')

    # 温度换算（mC -> C，带小数）
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
    printf '  %-22s: %s\n' "Zone ID"       "thermal_zone${id}"
    printf '  %-22s: %s\n' "Type"          "$type"
    printf '  %-22s: %s\n' "Temperature"   "$temp_str"
    printf '  %-22s: %s\n' "Mode"          "$mode"
    printf '  %-22s: %s\n' "Policy"        "$policy"
    printf '  %-22s: %s\n' "Avail Policies" "$avail_policies"
    printf '  %-22s: %s\n' "Slope"         "$slope"
    printf '  %-22s: %s\n' "Offset"        "$offset"
    printf '  %-22s: %s\n' "Sustainable Pwr" "$sustainable_power"
    printf '  %-22s: %s\n' "Sysfs Path"    "$d"

    # 如果存在 power 子目录（cooling device binding），列出关联的 cooling device
    if [ -d "$d/power" ]; then
        local cdev_list
        cdev_list=$(ls "$d/" 2>/dev/null | grep '^cdev')
        if [ -n "$cdev_list" ]; then
            echo ""
            echo "  [关联 Cooling Devices]"
            for cdev in $cdev_list; do
                local cdev_path="$d/$cdev"
                local cdev_type
                cdev_type=$(cat "$cdev_path/type" 2>/dev/null || echo 'unknown')
                local cur_state
                cur_state=$(cat "$cdev_path/cur_state" 2>/dev/null || echo 'N/A')
                local max_state
                max_state=$(cat "$cdev_path/max_state" 2>/dev/null || echo 'N/A')
                printf '    %-20s type=%-25s cur_state=%-5s max_state=%s\n' \
                    "$cdev" "$cdev_type" "$cur_state" "$max_state"
            done
        fi
    fi
    echo "========================================"
}

# ============================================================
# ACTION 分发
# ============================================================

case "$ACTION" in

    "disable")
        echo "正在记录并禁用当前开启的温度传感器 (Thermal Zones)..."
        rm -f "$LOG_FILE"
        for d in $(ls -d /sys/class/thermal/thermal_zone* 2>/dev/null | sort -V); do
            mode=$(cat "$d/mode" 2>/dev/null)
            if [ "$mode" = "enabled" ]; then
                echo "$d" >> "$LOG_FILE"
                echo "disabled" > "$d/mode"
                type=$(cat "$d/type" 2>/dev/null || echo 'unknown')
                echo "[已禁用] $d ($type)"
            fi
        done
        [ -f "$LOG_FILE" ] && echo "\n操作完成。记录在: $LOG_FILE" || echo "\n无需操作：没有发现处于开启状态的传感器。"
        ;;

    "enable")
        echo "正在恢复先前被禁用的温度传感器..."
        if [ ! -f "$LOG_FILE" ]; then
            echo "[警告] 未找到状态记录文件 $LOG_FILE，可能未执行过 disable 或已恢复。"
            exit 1
        fi
        for d in $(cat "$LOG_FILE"); do
            if [ -d "$d" ]; then
                echo "enabled" > "$d/mode"
                type=$(cat "$d/type" 2>/dev/null || echo 'unknown')
                echo "[已恢复] $d ($type)"
            fi
        done
        rm -f "$LOG_FILE"
        echo "\n恢复完成。"
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
        # 将所有参数逐个作为 zone type 名称查找（大小写不敏感，支持同时查询多个）
        found_any=0
        for zone_name in "$@"; do
            zone_dir=$(find_zone_by_type "$zone_name")
            if [ -n "$zone_dir" ]; then
                show_zone_detail "$zone_dir"
                found_any=1
            else
                echo "[WARN] 未找到 Thermal Zone: '$zone_name'"
            fi
        done
        if [ "$found_any" -eq 0 ]; then
            echo "[ERROR] 所有指定的 Thermal Zone 均未找到"
            echo ""
            echo "用法:"
            echo "  info            - 列出所有 Thermal Zone 基础信息"
            echo "  disable         - 禁用所有当前 enabled 的 Thermal Zone"
            echo "  enable          - 恢复之前被禁用的 Thermal Zone"
            echo "  <zone_type>     - 按 type 名称查询指定 zone 详情（大小写不敏感）"
            echo "  <z1> <z2> ...   - 同时查询多个 zone（用空格分隔）"
            echo "                    例: front_temp back_temp"
            exit 1
        fi
        ;;
esac

exit 0