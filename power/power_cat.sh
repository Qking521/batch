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
    echo "  power cat ps     Show power supply info"
    echo "  power cat regu   Show regulator information"
    echo "  power cat clk    Save clock summary to table"
    echo "  power cat cmd    Print adb raw commands of all subcommands"
}

# 查看 wakelock / wakeup 源
do_wakelock() {
    echo "===== [Kernel Wake Locks] ====="
    echo "wake_lock:   $(cat /sys/power/wake_lock 2>/dev/null)"
    echo "wake_unlock: $(cat /sys/power/wake_unlock 2>/dev/null)"
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

# 查看电源供应信息
do_power_supply() {
    for d in /sys/class/power_supply/*; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        type=$(cat "$d/type" 2>/dev/null || echo 'unknown')
        printf '%-15s [ Type: %s ]\n' "$name" "$type"

        for f in "$d"/*; do
            [ -f "$f" ] || continue
            prop=$(basename "$f")

            # 过滤掉非数据节点
            case "$prop" in
                uevent|type|name|device|subsystem|power|wakeup|waiting_for_supplier) continue ;;
            esac

            val=$(cat "$f" 2>/dev/null)
            [ -z "$val" ] && continue

            d_val="$val"
            case "$prop" in
                voltage_*|current_*|charge_*|energy_*|capacity_now|capacity_full*)
                    # 处理微单位到毫单位的转换
                    if [ "$val" -ge 1000 ] || [ "$val" -le -1000 ] 2>/dev/null; then
                        d_val="$((val / 1000)) (m)"
                    fi
                    ;;
                temp*)
                    # 处理摄氏度转换 (毫度或 0.1 度)
                    [ "$val" -ge 1000 ] 2>/dev/null && d_val=$((val / 1000)) || { [ "$val" -ge 100 ] 2>/dev/null && d_val=$((val / 10)); }
                    ;;
            esac
            printf '  %-25s : %s\n' "$prop" "$d_val"
        done
    done
}

# 查看 regulator 供电单元信息
do_regulator() {
    echo "正在获取供电单元信息 (Regulators)..."
    printf '%-3s %-15s %-30s %-10s\n' 'ID' 'TYPE' 'NAME' 'USERS'
    echo "----------------------------------------------------------------"
    for d in /sys/class/regulator/regulator.[0-9]*; do
        [ -d "$d" ] || continue
        id=${d##*regulator.}
        name=$(cat $d/name 2>/dev/null || echo 'N/A')
        type=$(cat $d/type 2>/dev/null || echo 'N/A')
        num_users=$(cat $d/num_users 2>/dev/null || echo 'N/A')
        printf '%-3s %-15s %-30s %-10s\n' "$id" "$type" "$name" "$num_users"
    done | sort -n
}

# 查看时钟树摘要 (clk_summary)，原样输出，落盘由 PC 端重定向完成
do_clk() {
    # 尝试挂载 debugfs（需 root），失败不中断后续逻辑
    mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null
    cat /sys/kernel/debug/clk/clk_summary 2>/dev/null
}

# 打印除 cmd 外其它子命令对应的 adb 原始命令
do_cmd() {
    cat <<'EOF'
===== [power cat 子命令对应的 adb 原始命令] =====

[wl] Show wake locks
adb shell cat /sys/power/wake_lock
adb shell cat /sys/power/wake_unlock
adb shell dumpsys power | grep -A 10 "Wake Locks:"

[gpio] Show GPIO status
adb shell mount -t debugfs debugfs /sys/kernel/debug
adb shell gpiodetect
adb shell gpioinfo
adb shell cat /sys/kernel/debug/gpio
adb shell ls -1 /sys/class/gpio

[ws] Save wakeup sources to CSV
adb shell mount -t debugfs debugfs /sys/kernel/debug
adb shell cat /sys/kernel/debug/wakeup_sources

[ps] Show power supply info
adb shell "cat /sys/class/power_supply/*/uevent"

[regu] Show regulator information
adb shell "grep -H '' /sys/class/regulator/regulator.*/name /sys/class/regulator/regulator.*/type /sys/class/regulator/regulator.*/num_users"

[clk] Save clock summary to CSV
adb shell mount -t debugfs debugfs /sys/kernel/debug
adb shell cat /sys/kernel/debug/clk/clk_summary

[irq] Save interrupts to xlsx
adb shell cat /proc/interrupts > interrupts.txt
python power_cat_parse.py irq interrupts.txt interrupts.xlsx
EOF
}

case "$ACTION" in
    wl)   do_wakelock ;;
    gpio) do_gpio ;;
    ws)   do_wakesource ;;
    ps)   do_power_supply ;;
    regu) do_regulator ;;
    clk)  do_clk ;;
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