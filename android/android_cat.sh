#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-10-23
# Desc:   Android 直显工具集（结果直接打印到屏幕，不落盘）
# Usage:  adb shell "sh -s <top|wl>" < android_cat.sh
# ============================================================

ACTION="$1"

# 查询当前焦点界面
do_top() {
    dumpsys window 2>/dev/null | grep mCurrentFocus
}

# 查看 wakelock / wakeup 源
do_wakelock() {
    echo "===== [Kernel Wake Locks] ====="
    echo "wake_lock:   $(cat /sys/power/wake_lock 2>/dev/null)"
    echo "wake_unlock: $(cat /sys/power/wake_unlock 2>/dev/null)"
    echo ""
    echo "===== [Kernel Wakeup Sources] ====="
    cat /sys/kernel/wakeup_sources 2>/dev/null
    echo ""
    echo "===== [Framework Wake Locks (dumpsys power)] ====="
    dumpsys power 2>/dev/null | grep -A 10 "Wake Locks:"
}

case "$ACTION" in
    top) do_top ;;
    wl)  do_wakelock ;;
    -h|--help|help)
        echo "Usage:"
        echo "  ad cat top   Show current focus"
        echo "  ad cat wl    Show wake locks"
        ;;
    *)
        echo "[ERROR] 未知参数: $ACTION" >&2
        echo "Usage: ad cat <top|wl>"
        exit 1
        ;;
esac