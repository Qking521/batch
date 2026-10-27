#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-10-27
# Desc:   Power 直显工具集（结果直接打印到屏幕，不落盘）
# Usage:  adb shell "sh -s <wl|gpio>" < power_cat.sh
# ============================================================

ACTION="$1"

usage() {
    echo "Usage:"
    echo "  power cat wl     Show wake locks"
    echo "  power cat gpio   Show GPIO status"
    echo "  power cat ws     Save wakeup sources to log"
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

# 查看 wakeup sources（kernel debugfs），输出为标准 CSV，落盘由 PC 端重定向完成
do_wakesource() {
    # 尝试挂载 debugfs（需 root），失败不中断后续逻辑
    mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null
    cat /sys/kernel/debug/wakeup_sources 2>/dev/null | awk '{printf "\""; for(i=1;i<=NF-9;i++){if(i>1)printf " ";printf "%s",$i}; printf "\""; for(i=NF-8;i<=NF;i++)printf ",%s",$i; printf "\n"}'
}

# 查看 GPIO 状态
do_gpio() {
    echo "===== [GPIO Status] ====="
    # 尝试挂载 debugfs（需 root），失败不中断后续逻辑
    mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null

    # 1) libgpiod 工具链（Android 较新版本自带）
    if command -v gpiodetect >/dev/null 2>&1; then
        echo "--- gpiodetect ---"
        gpiodetect
        echo "--- gpioinfo ---"
        gpioinfo
    # 2) 传统 debugfs gpio
    elif [ -r /sys/kernel/debug/gpio ]; then
        echo "--- /sys/kernel/debug/gpio ---"
        cat /sys/kernel/debug/gpio
    # 3) 传统 sysfs gpio 目录列表
    elif [ -d /sys/class/gpio ]; then
        echo "--- /sys/class/gpio ---"
        ls -1 /sys/class/gpio
    else
        echo "[WARN] 未找到可用的 GPIO 接口 (libgpiod / debugfs / sysfs)"
    fi
}

case "$ACTION" in
    wl)   do_wakelock ;;
    gpio) do_gpio ;;
    ws)   do_wakesource ;;
    -h|--help|help|usage|"")
        usage
        ;;
    *)
        echo "[ERROR] 未知参数: $ACTION" >&2
        usage
        exit 1
        ;;
esac