#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-11-16
# Desc:   Thermal 模拟温度 / 过热状态注入工具
# Usage:  adb shell "sh -s <zone_type> <temp_c>" < thermal_fake.sh
#         adb shell "sh -s status <0-6|reset>" < thermal_fake.sh
#
# Commands:
#   fake <zone_type> <temp_c>  - 对指定 Thermal Zone 写入模拟温度 (emul_temp)
#   fake status <0-6>          - 设置 Thermal Service 过热等级 (override-status)
#   fake status reset          - 重置 Thermal Service 过热状态
# ============================================================

ZONE_TYPE="$1"
ZONE_VAL="$2"

# ---- 将 type 名称转小写 ----
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

# ---- 显示 fake 帮助信息 ----
show_fake_usage() {
    cat <<EOF
Usage:
  therm fake <zone_type> <temp_c>   - 对指定 Thermal Zone 写入模拟温度 (emul_temp)
  therm fake status <0-6>           - 设置 Thermal Service 过热等级
  therm fake status reset           - 重置 Thermal Service 过热状态

过热等级说明 (level 范围 0-6):
  0 = NONE       正常
  1 = LIGHT      轻微
  2 = MODERATE   中等
  3 = SEVERE     严重
  4 = CRITICAL   危急
  5 = EMERGENCY  紧急
  6 = SHUTDOWN   关机
EOF
}

# ---- 过热等级数值转名称 ----
status_level_name() {
    case "$1" in
        0) echo "NONE" ;;
        1) echo "LIGHT" ;;
        2) echo "MODERATE" ;;
        3) echo "SEVERE" ;;
        4) echo "CRITICAL" ;;
        5) echo "EMERGENCY" ;;
        6) echo "SHUTDOWN" ;;
        *) echo "UNKNOWN" ;;
    esac
}

# ---- status 子命令: 设置 / 重置 Thermal Service 过热等级 ----
do_status() {
    if [ -z "$ZONE_VAL" ]; then
        echo "[ERROR] 缺少 status 参数"
        echo ""
        show_fake_usage
        exit 1
    fi

    if [ "$ZONE_VAL" = "reset" ]; then
        cmd thermalservice reset
        echo "[OK] thermalservice reset"
        return
    fi

    case "$ZONE_VAL" in
        0|1|2|3|4|5|6)
            cmd thermalservice override-status "$ZONE_VAL"
            echo "[OK] thermalservice override-status = $ZONE_VAL ($(status_level_name "$ZONE_VAL"))"
            ;;
        *)
            echo "[ERROR] 无效的过热等级: '$ZONE_VAL' (范围 0-6)"
            echo ""
            show_fake_usage
            exit 1
            ;;
    esac
}

# ---- 写入指定 zone 的模拟温度 (emul_temp) ----
do_emul_temp() {
    if [ -z "$ZONE_TYPE" ] || [ -z "$ZONE_VAL" ]; then
        echo "[ERROR] 用法: therm fake <zone_type> <temp_c>"
        echo ""
        show_fake_usage
        exit 1
    fi

    if ! [ "$ZONE_VAL" -eq "$ZONE_VAL" ] 2>/dev/null; then
        echo "[ERROR] 无效的温度值: '$ZONE_VAL' (需为整数摄氏度)"
        exit 1
    fi

    if [ "$(id -u)" -ne 0 ]; then
        echo "[ERROR] 写入 emul_temp 需要 root 权限，请先运行 'adb root'" >&2
        exit 1
    fi

    local zone_dir
    zone_dir=$(find_zone_by_type "$ZONE_TYPE")
    if [ -z "$zone_dir" ]; then
        echo "[ERROR] 未找到 Thermal Zone: '$ZONE_TYPE'"
        exit 1
    fi

    local emul_path="$zone_dir/emul_temp"
    if [ ! -f "$emul_path" ]; then
        echo "[ERROR] 该 Zone 不支持 emul_temp: $emul_path"
        exit 1
    fi

    local emul_val=$(( ZONE_VAL * 1000 ))
    echo "$emul_val" > "$emul_path" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "[OK] $ZONE_TYPE ($zone_dir): emul_temp = ${ZONE_VAL}C (写入 ${emul_val})"
    else
        echo "[ERROR] 写入失败: $emul_path"
        exit 1
    fi
}

# 主入口路由分发
case "$ZONE_TYPE" in
    "status")       do_status ;;
    -h|--help|help|usage|"")
        show_fake_usage
        ;;
    *)              do_emul_temp ;;
esac

exit 0
