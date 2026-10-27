#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-10-23
# Desc:   Android 直显工具集（结果直接打印到屏幕，不落盘）
# Usage:  adb shell "sh -s <top>" < android_cat.sh
# ============================================================

ACTION="$1"

usage() {
    echo "Usage:"
    echo "  ad cat top   Show current focus"
}

# 查询当前焦点界面
do_top() {
    dumpsys window 2>/dev/null | grep mCurrentFocus
}

case "$ACTION" in
    top) do_top ;;
    -h|--help|help|usage|"")
        usage
        ;;
    *)
        echo "[ERROR] 未知参数: $ACTION" >&2
        usage
        exit 1
        ;;
esac