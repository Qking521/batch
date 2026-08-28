#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-08-05
# Desc:   Android 设备端录屏业务逻辑脚本
# Usage:  adb shell "sh -s <start|stop> [file_name]" < android_screen_record.sh
# ============================================================

ACTION="$1"
RECORD_FILE="$2"
[ -z "$RECORD_FILE" ] && RECORD_FILE="record.mp4"

log() {
    echo "[INFO] $*"
}

err() {
    echo "[ERROR] $*" >&2
}

do_start() {
    # 检查设备是否支持 screenrecord
    if ! command -v screenrecord >/dev/null 2>&1; then
        err "设备不支持 screenrecord 命令"
        exit 1
    fi

    # 清理已有残余录屏进程
    pids=$(pidof screenrecord 2>/dev/null)
    if [ -n "$pids" ]; then
        for pid in $pids; do
            kill -2 "$pid" 2>/dev/null
        done
        sleep 1
    fi

    # 在设备后台拉起 screenrecord
    nohup screenrecord --bugreport "/sdcard/$RECORD_FILE" >/dev/null 2>&1 &
    sleep 1

    pid=$(pidof screenrecord 2>/dev/null)
    if [ -n "$pid" ]; then
        exit 0
    else
        err "录屏启动失败"
        exit 1
    fi
}

do_stop() {
    pid=$(pidof screenrecord 2>/dev/null)
    if [ -z "$pid" ]; then
        exit 0
    fi

    # 下发 SIGINT (2) 以刷新并保存 MP4 头部信息
    kill -2 $pid 2>/dev/null

    # 循环等待进程退出
    cnt=0
    while [ $cnt -lt 10 ]; do
        p=$(pidof screenrecord 2>/dev/null)
        [ -z "$p" ] && break
        sleep 1
        cnt=$((cnt + 1))
    done

    exit 0
}

case "$ACTION" in
    start)  do_start ;;
    stop)   do_stop ;;
    *)      err "未知动作: $ACTION"; exit 1 ;;
esac
