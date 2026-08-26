#!/system/bin/sh
# ============================================================
# Author: Antigravity Pair Program
# Date:   2026-08-26
# Desc:   Dhrystone 压力测试控制工具
# Usage:  adb shell "sh -s <action> [param1]" < perf_dhrystone.sh
#
# Actions:
#   start [count]     - 启动 dhrystone（单进程或多进程）
#   stop              - 停止所有 dhrystone 进程
#   status            - 查看 dhrystone 运行状态
# ============================================================

ACTION="$1"
PARAM1="$2"

DEVICE_DHRY_SH="/data/dhrystone.sh"
DEVICE_DHRY_ELF="/data/dhrystone.elf"

usage() {
    echo ""
    echo "用法: perf ds <command> [params...]"
    echo ""
    echo "可用命令:"
    echo "  start [count]     - 启动 dhrystone 进程 (默认单进程，传入数字则启动多进程)"
    echo "  stop              - 停止所有 dhrystone 进程"
    echo "  status            - 查看 dhrystone 运行状态"
    echo "  help / -h         - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  perf ds start"
    echo "  perf ds start 4"
    echo "  perf ds stop"
    echo "  perf ds status"
    echo ""
}

cmd_start() {
    count="$PARAM1"
    
    if [ ! -f "$DEVICE_DHRY_SH" ] || [ ! -f "$DEVICE_DHRY_ELF" ]; then
        echo "[ERROR] 设备端缺少 Dhrystone 文件 ($DEVICE_DHRY_SH 或 $DEVICE_DHRY_ELF)"
        return 1
    fi

    # 确保有执行权限
    chmod 777 /data/dhrystone.elf /data/dhrystone.sh /data/dhrystone_multi.sh /data/_dhrystone_multi.sh 2>/dev/null

    running=$(ps -ef 2>/dev/null | grep -E "dhrystone\.sh|dhrystone\.elf|_dhrystone_multi\.sh" | grep -v grep)
    if [ -n "$running" ]; then
        echo "[INFO] 检测到 dhrystone 已在运行中:"
        echo "$running"
        return 0
    fi

    echo "[INFO] 正在启动 dhrystone..."
    cd /data || exit 1

    if [ -n "$count" ] && [ "$count" -gt 1 ] 2>/dev/null; then
        if [ -f "/data/dhrystone_multi.sh" ]; then
            echo "[INFO] 启动多进程模式: $count 个进程"
            nohup ./dhrystone_multi.sh "$count" > /dev/null 2>&1 &
        else
            echo "[WARN] 未找到 /data/dhrystone_multi.sh，回退为单进程模式"
            nohup ./dhrystone.sh > /dev/null 2>&1 &
        fi
    else
        nohup ./dhrystone.sh > /dev/null 2>&1 &
    fi

    sleep 1
    echo "[INFO] 启动完成，当前进程状态:"
    ps -ef 2>/dev/null | grep -E "dhrystone" | grep -v grep
}

cmd_stop() {
    pids=$(ps -ef 2>/dev/null | grep -E "dhrystone" | grep -v grep | awk '{print $2}')
    if [ -z "$pids" ]; then
        echo "[INFO] 未发现运行中的 dhrystone 进程"
        return 0
    fi

    for pid in $pids; do
        kill -9 "$pid" 2>/dev/null
    done
    echo "[INFO] dhrystone 进程清除完成"
}

cmd_status() {
    running=$(ps -ef 2>/dev/null | grep -E "dhrystone" | grep -v grep)
    if [ -n "$running" ]; then
        echo "[INFO] 当前运行中的 dhrystone 进程:"
        echo "$running"
    else
        echo "[INFO] 当前没有运行中的 dhrystone 进程"
    fi
}

case "$ACTION" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    status)
        cmd_status
        ;;
    help|-h|"")
        usage
        ;;
    *)
        echo "[ERROR] 未知命令: $ACTION"
        usage
        exit 1
        ;;
esac

exit 0
