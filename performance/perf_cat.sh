#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-10-28
# Desc:   Performance 直显工具集（结果直接打印到屏幕，不落盘）
# Usage:  adb shell "sh -s <gov>" < perf_cat.sh
# ============================================================

ACTION="$1"

usage() {
    echo "Usage:"
    echo "  perf cat gov     Show CPU governor"
    echo "  perf cat cmd     Print adb raw commands of all subcommands"
}

# 查看 CPU governor
do_governor() {
    echo "===== [CPU Governor] ====="
    echo "current:    $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"
    echo "available:  $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null)"
}

# 打印除 cmd 外其它子命令对应的 adb 原始命令
do_cmd() {
    cat <<'EOF'
===== [perf cat 子命令对应的 adb 原始命令] =====

[gov] Show CPU governor
adb shell cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
adb shell cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
EOF
}

case "$ACTION" in
    gov)  do_governor ;;
    cmd)  do_cmd ;;
    -h|--help|help|usage|"")
        usage
        ;;
    *)
        echo "[ERROR] 未知参数: $ACTION" >&2
        usage
        exit 1
        ;;
esac