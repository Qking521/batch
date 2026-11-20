#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-08-26
# Desc:   Dhrystone 压力测试控制工具 (单进程/多进程启动、停止、状态查询)
# Usage:  adb shell "sh -s <action> [count]" < perf_dhrystone.sh
# ============================================================

ACTION="$1"
COUNT="$2"

DHRY_ELF="/data/dhrystone.elf"
ITERATIONS=300000000
RESULT_PREFIX="/data/dhrystone_results"
# 导出常量, 供 nohup 后台循环子进程继承
export DHRY_ELF ITERATIONS RESULT_PREFIX

log() {
    echo "[INFO] $*"
}

err() {
    echo "[ERROR] $*" >&2
}

die() {
    err "$*"
    usage
    exit 1
}

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

do_status() {
    running=$(ps -ef 2>/dev/null | grep "dhrystone" | grep -v grep)
    if [ -n "$running" ]; then
        log "当前运行中的 dhrystone 进程:"
        echo "$running"
    else
        log "当前没有运行中的 dhrystone 进程"
    fi
}

# 后台启动单进程循环 (nohup 防 SIGHUP; 结果直接追加写入文件)
bg_single() {
    nohup sh -c '
        while true; do
            echo "$ITERATIONS" | "$DHRY_ELF" >> "${RESULT_PREFIX}.txt"
        done
    ' > /dev/null 2>&1 &
}

# 后台启动一个多进程循环 worker, 结果写入 <prefix>_<idx>.txt
bg_multi() {
    nohup sh -c '
        while true; do
            echo "$ITERATIONS" | "$DHRY_ELF" >> "${RESULT_PREFIX}_$1.txt"
        done
    ' worker "$1" > /dev/null 2>&1 &
}

do_start() {
    if [ ! -f "$DHRY_ELF" ]; then
        die "设备端缺少 Dhrystone 文件: $DHRY_ELF"
    fi

    # 授权兜底 (PC 端 push 时不做 chmod)
    chmod 777 "$DHRY_ELF" 2>/dev/null

    running=$(ps -ef 2>/dev/null | grep "dhrystone" | grep -v grep)
    if [ -n "$running" ]; then
        log "检测到 dhrystone 已在运行中"
        do_status
        return 0
    fi

    if [ -n "$COUNT" ] && [ "$COUNT" -gt 1 ] 2>/dev/null; then
        log "正在启动 dhrystone... 多进程模式: $COUNT 个进程"
        i=0
        while [ "$i" -lt "$COUNT" ]; do
            bg_multi "$i"
            i=$((i + 1))
        done
    else
        log "正在启动 dhrystone... 单进程模式"
        bg_single
    fi

    sleep 1
    log "启动完成"
    do_status
}

do_stop() {
    pids=$(ps -ef 2>/dev/null | grep "dhrystone" | grep -v grep | awk '{print $2}')
    if [ -z "$pids" ]; then
        log "未发现运行中的 dhrystone 进程"
    else
        for pid in $pids; do
            kill -9 "$pid" 2>/dev/null
        done
        log "dhrystone 进程清除完成"
    fi
    log "结果文件: /data/dhrystone_results*.txt (停止后由 PC 端自动 pull)"
    do_status
}

# 参数解析与校验
parse_args() {
    case "$ACTION" in
        -h|--help|help|usage|"") usage; exit 0 ;;
    esac
}

# 命令路由分发
route() {
    case "$ACTION" in
        start)  do_start; return ;;
        stop)   do_stop; return ;;
        status) do_status; return ;;
        *)      die "未知命令: $ACTION" ;;
    esac
}

main() {
    # 1. 参数解析与校验（含 usage/exit）
    parse_args "$@"

    # 2. 命令路由分发
    route
}

main "$@"
exit 0
