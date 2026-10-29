#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-08-27
# Desc:   实时监听 Android 状态变化 (diff 整体比对 / cpu / gpu)
# Usage:  sh /data/local/tmp/android_watch.sh <模块...> [interval]
# ============================================================

# ===================== 全局变量 =====================
MODULES=""
INTERVAL=""

TMP_DIR="/data/local/tmp"
PID_FILE="$TMP_DIR/.ad_watch.pid"
PREV_FILE="$TMP_DIR/.ad_watch_prev_$$.txt"
CURR_FILE="$TMP_DIR/.ad_watch_curr_$$.txt"

# ANSI 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ===================== 帮助信息 =====================
usage() {
    echo "用法: ad watch <模块...> [interval]"
    echo ""
    echo "参数说明:"
    echo "  diff     : 整体状态比对监听 (Settings + Prop + Audio + Power)"
    echo "  cpu      : CPU 频率/核心状态监听"
    echo "  gpu      : GPU 频率/占用率监听"
    echo "  interval : 轮询间隔时间(秒)，可放最后，默认 3"
    echo ""
    echo "示例:"
    echo "  ad watch diff       - 整体状态比对监听"
    echo "  ad watch cpu        - 仅监听 CPU"
    echo "  ad watch cpu gpu    - 同时监听 CPU 和 GPU"
    echo "  ad watch cpu gpu 1  - 同时监听 CPU 和 GPU，每 1 秒一次"
    echo "  ad watch cpu 1      - 监听 CPU，每 1 秒一次"
}

# ===================== 参数解析 =====================
# 支持多个模块参数 + 可选的末尾 interval（纯数字）
parse_args() {
    MODULES=""
    INTERVAL="3"

    for arg in "$@"; do
        # 跳过空参数（bat 层透传多余位置参数时产生的空串）
        [ -z "$arg" ] && continue

        case "$arg" in
            -h|--help|help) usage; exit 0 ;;
        esac

        case "$arg" in
            diff|cpu|gpu) MODULES="$MODULES $arg" ;;
            *[!0-9]*|'') echo "[ERROR] 未知参数: $arg"; usage; exit 1 ;;
            *) INTERVAL="$arg" ;;
        esac
    done

    # 未指定任何模块
    if [ -z "$(echo "$MODULES" | tr -d ' ')" ]; then
        usage
        exit 1
    fi

    # 确保 INTERVAL 为合法正整数
    case "$INTERVAL" in
        ''|*[!0-9]*) INTERVAL="3" ;;
    esac
}

# ===================== 进程锁 =====================
lock_instance() {
    # 如果之前有遗留的 watch 实例，先杀掉
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$OLD_PID" ] && [ "$OLD_PID" != "$$" ]; then
            kill -9 "$OLD_PID" 2>/dev/null
        fi
    fi
    echo "$$" > "$PID_FILE"
}

cleanup() {
    rm -f "$PREV_FILE" "$CURR_FILE" "$PID_FILE" 2>/dev/null
    exit 0
}

# ===================== 快照采集 =====================
# 全面采集系统状态：Settings 三库 + getprop + Audio 音量/静音 + Power 电源/屏幕
get_diff_snapshot() {
    # 1. Settings 三库 (包含 Wi-Fi、蓝牙、飞行模式、各音量、深色模式等)
    for db in global system secure; do
        settings list "$db" 2>/dev/null | sed "s/^/[$db] /"
    done

    # 2. 系统属性
    getprop 2>/dev/null | sed 's/^/[prop] /'

    # 3. Audio 各音频流实时音量与静音状态 (MUSIC / RING / ALARM / NOTIFICATION / VOICE 等)
    dumpsys audio 2>/dev/null | awk '
        /- STREAM_/ {
            stream=$2
            gsub(/:/, "", stream)
        }
        /streamVolume:/ {
            sub(/^[ \t]+/, "")
            if (stream != "") print "[audio] " stream " " $0
        }
        /Muted: (true|false)/ {
            sub(/^[ \t]+/, "")
            if (stream != "") print "[audio] " stream " " $0
        }
    '

    # 4. 电源/屏幕状态
    dumpsys power 2>/dev/null | grep -E "mWakefulness=|mHoldingWakeLockSuspendBlocker=|mIsPowered=|mPlugType=" | sed 's/^[ \t]*/[power] /'
}

# ===================== 差异输出 =====================
print_change() {
    echo "$DIFF_RESULT" | while IFS= read -r line; do
        tag=$(echo "$line" | cut -c 1)
        content=$(echo "$line" | cut -c 2-)
        if [ "$tag" = "-" ]; then
            echo "  ${RED}➖ [旧值] $content${NC}"
        elif [ "$tag" = "+" ]; then
            echo "  ${GREEN}➕ [新值] $content${NC}"
        fi
    done
}

print_banner() {
    echo "${CYAN}======================================================${NC}"
    echo "${GREEN}🔍 $1${NC}"
    echo "${CYAN}======================================================${NC}"
}

# ===================== diff 监听循环（快照比对） =====================
watch_diff() {
    print_banner "正在初始化系统状态基准快照 (Settings + Prop + Audio + Power)"

    CHANGE_COUNT=0
    ORIG_PPID="$PPID"

    get_diff_snapshot | sort > "$PREV_FILE"

    echo "${YELLOW}✅ 初始化完成！监听已启动 (检查间隔: ${INTERVAL}s)...${NC}"
    echo "👉 请在手机上切换开关（Wi-Fi/蓝牙/深色模式等）或调节音量测试"
    echo "👉 按 Ctrl + C 可安全退出监听\n"

    while true; do
        sleep "$INTERVAL"

        # 守护检测：若父进程已死亡 (被 init 领养 PPID 变为 1 或丢失)，立即自动终止退出
        CURRENT_PPID="$PPID"
        if [ "$CURRENT_PPID" -eq 1 ] && [ "$ORIG_PPID" -ne 1 ]; then
            cleanup
        fi

        get_diff_snapshot | sort > "$CURR_FILE"

        # 比对差异（过滤 ---/+++ 头部以及高频跳动的运行时戳、跟踪日志等）
        DIFF_RESULT=$(diff -u "$PREV_FILE" "$CURR_FILE" 2>/dev/null | grep -E "^[+-][^-+]" | grep -vE "uptime|timestamp|sys.boot_completed|debug.tracing|mHoldingWakeLockSuspendBlocker")

        if [ -n "$DIFF_RESULT" ]; then
            CHANGE_COUNT=$((CHANGE_COUNT + 1))
            TIME_STR=$(date "+%H:%M:%S" 2>/dev/null || date)
            echo "${CYAN}[$TIME_STR] 🔔 检测到系统状态发生变化 (第 ${CHANGE_COUNT} 次变更):${NC}"

            print_change
            echo "${BLUE}------------------------------------------------------${NC}"

            cp "$CURR_FILE" "$PREV_FILE"
        fi
    done
}

# ===================== CPU 状态显示 =====================
show_cpu() {
    echo "───────────────── CPU ─────────────────"

    printf '%-9s %-12s %-10s %-10s %-10s %s\n' POLICY CPUS 'CUR(KHz)' 'MIN(KHz)' 'MAX(KHz)' GOV
    for policy in /sys/devices/system/cpu/cpufreq/policy[0-9]*; do
        [ -d "$policy" ] || continue
        pname=${policy##*/}
        affected=$(cat "$policy/affected_cpus" 2>/dev/null)
        cur=$(cat   "$policy/scaling_cur_freq" 2>/dev/null)
        min=$(cat   "$policy/scaling_min_freq" 2>/dev/null)
        max=$(cat   "$policy/scaling_max_freq" 2>/dev/null)
        gov=$(cat   "$policy/scaling_governor" 2>/dev/null)
        [ -z "$affected" ] && affected="-"
        [ -z "$cur" ] && cur="-"
        [ -z "$min" ] && min="-"
        [ -z "$max" ] && max="-"
        [ -z "$gov" ] && gov="-"
        printf '%-9s %-12s %-10s %-10s %-10s %s\n' "$pname" "$affected" "$cur" "$min" "$max" "$gov"
    done

    echo ""
    printf '%-8s %-10s %s\n' CPU ONLINE 'CUR(KHz)'
    for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
        id=${cpu##*/}
        online=$(cat "$cpu/online" 2>/dev/null)
        cur=$(cat "$cpu/cpufreq/scaling_cur_freq" 2>/dev/null)
        if [ -z "$online" ]; then
            online="1(固定)"
        fi
        [ -z "$cur" ] && cur="-"
        printf '%-8s %-10s %s\n' "$id" "$online" "$cur"
    done
}

# ===================== GPU 状态显示 =====================
show_gpu() {
    echo "───────────────── GPU ─────────────────"

    if [ -d /sys/class/kgsl/kgsl-3d0 ]; then
        KGSL=/sys/class/kgsl/kgsl-3d0
        model=$(cat "$KGSL/gpu_model" 2>/dev/null)
        cur=$(cat "$KGSL/devfreq/cur_freq" 2>/dev/null)
        max=$(cat "$KGSL/devfreq/max_freq" 2>/dev/null)
        gov=$(cat "$KGSL/devfreq/governor" 2>/dev/null)
        busy=$(cat "$KGSL/gpu_busy_percentage" 2>/dev/null)

        [ -n "$model" ] && echo "型号:     $model"
        echo "当前频率: ${cur:-N/A} Hz"
        echo "最大频率: ${max:-N/A} Hz"
        echo "Governor: ${gov:-N/A}"
        [ -n "$busy" ] && echo "占用率:   ${busy}"
    elif [ -d /sys/kernel/ged/hal ]; then
        GED=/sys/kernel/ged/hal
        cur=$(cat "$GED/current_freqency" 2>/dev/null)
        levels=$(cat "$GED/total_gpu_freq_level_count" 2>/dev/null)
        idle=$(cat /sys/module/ged/parameters/gpu_idle 2>/dev/null)

        echo "当前频率: ${cur:-N/A}"
        echo "频点档位: ${levels:-N/A}"
        echo "GPU idle: ${idle:-N/A}"
    else
        echo "[WARN] 未找到 GPU 控制节点（当前平台不支持或内核无对应节点）"
    fi
}

# ===================== 多模块监听循环 =====================
watch_modules() {
    print_banner "实时监听:$(echo "$MODULES")"

    ORIG_PPID="$PPID"

    echo "${YELLOW}✅ 监听已启动 (检查间隔: ${INTERVAL}s)...${NC}"
    echo "👉 按 Ctrl + C 可安全退出监听\n"

    while true; do
        TIME_STR=$(date "+%H:%M:%S" 2>/dev/null || date)
        echo "${CYAN}[$TIME_STR]${NC}"

        for m in $MODULES; do
            case "$m" in
                cpu) show_cpu ;;
                gpu) show_gpu ;;
            esac
            echo ""
        done
        echo "${BLUE}======================================================${NC}"

        sleep "$INTERVAL"

        # 守护检测：若父进程已死亡 (被 init 领养 PPID 变为 1 或丢失)，立即自动终止退出
        CURRENT_PPID="$PPID"
        if [ "$CURRENT_PPID" -eq 1 ] && [ "$ORIG_PPID" -ne 1 ]; then
            cleanup
        fi
    done
}

# ===================== 入口 =====================
main() {
    parse_args "$@"
    lock_instance
    trap cleanup INT TERM HUP EXIT QUIT

    # diff 不与 cpu/gpu 混用：若指定 diff 则走快照比对，否则走多模块实时显示
    if echo "$MODULES" | grep -qw diff; then
        if [ "$(echo "$MODULES" | tr -d ' ')" != "diff" ]; then
            echo "[ERROR] diff 不支持与 cpu/gpu 混合使用"
            exit 1
        fi
        watch_diff
    else
        watch_modules
    fi
}

main "$@"