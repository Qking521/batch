#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-08-27
# Desc:   实时监听 Android settings 三库、getprop、audio 音量及系统状态变化
# Usage:  sh /data/local/tmp/android_watch.sh [interval]
# ============================================================

INTERVAL="${1:-2}"

# 帮助信息
if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
    echo "用法: ad watch [interval]"
    echo ""
    echo "参数说明:"
    echo "  interval : 轮询比对间隔时间(秒)，默认 2"
    echo ""
    echo "示例:"
    echo "  ad watch     - 默认每 2 秒监听一次，按 Ctrl+C 退出"
    echo "  ad watch 1   - 每 1 秒监听一次"
    exit 0
fi

# 确保 INTERVAL 为合法正整数
case "$INTERVAL" in
    ''|*[!0-9]*) INTERVAL=2 ;;
esac

TMP_DIR="/data/local/tmp"
PID_FILE="$TMP_DIR/.ad_watch.pid"
PREV_FILE="$TMP_DIR/.ad_watch_prev_$$.txt"
CURR_FILE="$TMP_DIR/.ad_watch_curr_$$.txt"

# 如果之前有遗留的 watch 实例，先杀掉
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && [ "$OLD_PID" != "$$" ]; then
        kill -9 "$OLD_PID" 2>/dev/null
    fi
fi
echo "$$" > "$PID_FILE"

# 退出清理函数
cleanup() {
    rm -f "$PREV_FILE" "$CURR_FILE" "$PID_FILE" 2>/dev/null
    exit 0
}

# 捕获退出信号
trap cleanup INT TERM HUP EXIT QUIT

# ANSI 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 全面采集系统状态：Settings 三库 + getprop + Audio 音量/静音 + Power 电源/屏幕
get_snapshot() {
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

echo "${CYAN}======================================================${NC}"
echo "${GREEN}🔍 正在初始化系统状态基准快照 (Settings + Prop + Audio + Power)...${NC}"
echo "${CYAN}======================================================${NC}"

# 生成初始快照并排序
get_snapshot | sort > "$PREV_FILE"

echo "${YELLOW}✅ 初始化完成！监听已启动 (检查间隔: ${INTERVAL}s)...${NC}"
echo "👉 请在手机上切换开关（Wi-Fi/蓝牙/深色模式等）或调节音量测试"
echo "👉 按 Ctrl + C 可安全退出监听\n"

CHANGE_COUNT=0
ORIG_PPID="$PPID"

while true; do
    sleep "$INTERVAL"

    # 守护检测：若父进程已死亡 (被 init 领养 PPID 变为 1 或丢失)，立即自动终止退出，防止后台死循环
    CURRENT_PPID="$PPID"
    if [ "$CURRENT_PPID" -eq 1 ] && [ "$ORIG_PPID" -ne 1 ]; then
        cleanup
    fi

    # 获取最新快照
    get_snapshot | sort > "$CURR_FILE"

    # 比对差异（Toybox diff 输出以 -/+ 开头，过滤掉 ---/+++ 头部以及高频跳动的运行时戳、跟踪日志等）
    DIFF_RESULT=$(diff -u "$PREV_FILE" "$CURR_FILE" 2>/dev/null | grep -E "^[+-][^-+]" | grep -vE "uptime|timestamp|sys.boot_completed|debug.tracing|mHoldingWakeLockSuspendBlocker")

    if [ -n "$DIFF_RESULT" ]; then
        CHANGE_COUNT=$((CHANGE_COUNT + 1))
        TIME_STR=$(date "+%H:%M:%S" 2>/dev/null || date)
        echo "${CYAN}[$TIME_STR] 🔔 检测到系统状态发生变化 (第 ${CHANGE_COUNT} 次变更):${NC}"
        
        echo "$DIFF_RESULT" | while IFS= read -r line; do
            tag=$(echo "$line" | cut -c 1)
            content=$(echo "$line" | cut -c 2-)
            if [ "$tag" = "-" ]; then
                echo "  ${RED}➖ [旧值] $content${NC}"
            elif [ "$tag" = "+" ]; then
                echo "  ${GREEN}➕ [新值] $content${NC}"
            fi
        done
        echo "${BLUE}------------------------------------------------------${NC}"

        # 更新基准快照
        cp "$CURR_FILE" "$PREV_FILE"
    fi
done
