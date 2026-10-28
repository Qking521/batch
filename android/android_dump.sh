#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-10-23
# Desc:   Android dump 透传（参数解析 + usage + 服务别名 + 合法性校验）
# Usage:  adb shell "sh -s <dump|help> <service> [params...]" < android_dump.sh
# ============================================================

ACTION="$1"
shift

# 获取当前可用服务列表（逐行输出）
list_services() {
    dumpsys -l 2>/dev/null | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# 校验服务是否存在于 dumpsys -l 结果中
service_exists() {
    list_services | grep -qx "$1"
}

usage() {
    echo "用法: ad dump <service> [params...]"
    echo ""
    echo "可用服务列表:"
    list_services | sed 's/^/  /'
    echo ""
    echo "别名: sf/surfaceflinger -> SurfaceFlinger, win/window -> window"
    echo "示例: ad dump SurfaceFlinger"
}

do_dump() {
    service="$1"
    shift
    if [ -z "$service" ]; then
        usage
        exit 1
    fi

    # 服务别名映射
    case "$service" in
        sf|surfaceflinger) service="SurfaceFlinger" ;;
        win|window)        service="window" ;;
    esac

    # 合法性校验：不在 dumpsys -l 列表中则提示不支持
    if ! service_exists "$service"; then
        echo "[ERROR] 不支持的服务: $service" >&2
        echo "提示: 使用 ad dump help 查看可用服务列表" >&2
        exit 1
    fi

    # SF 特殊处理：dump 前设置，dump 后恢复
    restore_enforce=0
    case "$service" in
        SurfaceFlinger)
            setprop vendor.debug.bq.dump "@surface"
            if [ "$(cat /sys/fs/selinux/enforce 2>/dev/null)" = "1" ]; then
                setenforce 0
                restore_enforce=1
            fi
            ;;
    esac

    dumpsys "$service" "$@"

    case "$service" in
        SurfaceFlinger)
            setprop vendor.debug.bq.dump ""
            if [ "$restore_enforce" = "1" ]; then
                setenforce 1
            fi
            ;;
    esac
}

case "$ACTION" in
    dump) do_dump "$@" ;;
    -h|--help|help) usage ;;
    *) usage; exit 1 ;;
esac