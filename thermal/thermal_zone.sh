#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-11-16
# Desc:   Thermal Zone 专用管理工具 (查询 / 监听 / 禁用 / 恢复)
# Usage:  adb shell "sh -s <action> [params]" < thermal_zone.sh
#
# Actions:
#   info|cat             - 查看所有 Thermal Zone 信息
#   watch [sec]          - 实时监听 Thermal Zone 温度变化 (默认 5s 刷新, Ctrl+C 退出)
#   dis|disable          - 禁用所有已开启的 Thermal Zone
#   en|enable            - 恢复被禁用的 Thermal Zone
#   single <zone_type>   - 查询单个指定 zone 的详细信息
#   无参数               - 显示 Usage 帮助信息
# ============================================================

LOG_FILE="/data/local/tmp/orig_enabled_tz.txt"

# ---- 将 type 名称转小写 ----
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# ---- 显示 Thermal Zone 的 Usage 帮助信息 ----
show_tz_usage() {
    cat <<EOF
Usage:
  therm tz cat         - 查看所有 Thermal Zone 信息
  therm tz watch [sec]      - 实时监听 Thermal Zone 温度变化 (默认 5s 刷新, Ctrl+C 退出)
  therm tz dis|disable      - 禁用所有已开启的 Thermal Zone
  therm tz en|enable        - 恢复被禁用的 Thermal Zone
  therm tz single <zone>    - 查询单个指定 zone 的详细信息 (如: therm tz single front_temp)
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

# ---- 输出所有 Thermal Zone 信息表 ----
tz_info() {
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

# ---- 禁用所有已开启的 Thermal Zone ----
do_disable() {
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
}

# ---- 恢复被禁用的 Thermal Zone ----
do_enable() {
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
}

# ---- 实时监听 Thermal Zone 温度 ----
do_watch() {
    interval="${1:-5}"
    trap 'echo ""; echo "[Thermal Watch 已退出]"; exit 0' INT TERM
    while true; do
        clear 2>/dev/null || printf '\033[2J\033[H'
        echo "更新时间: $(date '+%Y-%m-%d %H:%M:%S')  (按 Ctrl+C 停止监听, 刷新间隔: ${interval}s)"
        tz_info
        sleep "$interval"
    done
}

# 主入口路由分发
ACTION="$1"

case "$ACTION" in
    "")              show_tz_usage ;;
    "watch")         do_watch "$2" ;;
    "dis"|"disable") do_disable ;;
    "en"|"enable")   do_enable ;;
    "cat"|"info")    echo "正在获取温度传感器信息..."; tz_info ;;
    "single")
        zone_dir=$(find_zone_by_type "$2")
        if [ -n "$zone_dir" ]; then
            show_zone_detail "$zone_dir"
        else
            show_tz_usage
        fi
        ;;
    *)
        show_tz_usage
        ;;
esac

exit 0
