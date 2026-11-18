#!/system/bin/sh
# ============================================================
# Author: wangqiang
# Date:   2026-08-05
# Desc:   开启/禁用 Android 应用包（支持单应用包名或预设组 google/moto）；selinux 开关；开发者选项开关；powersd 服务开关；debugfs 挂载开关
# Usage:  adb shell "sh -s <enable|disable> <pkg_name|google|moto|selinux|dev|powers|debugfs>" < android_toggle.sh
# ============================================================

ACTION="$1"
TARGET="$2"

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
    echo "用法: ad [enable|disable] <package_name|google|moto|selinux|dev|powers|debugfs>"
    echo ""
    echo "动作:"
    echo "  enable <target>   - 启用指定的action"
    echo "  disable <target>  - 禁用指定的action"
    echo ""
    echo "目标 (target):"
    echo "  <package_name>   - 具体应用包名，如 com.android.chrome"
    echo "  google           - 预设的 Google 相关应用包列表"
    echo "  moto             - 预设的 Moto 相关应用包列表"
    echo "  selinux          - 切换 selinux 状态 (enable=on, disable=off)"
    echo "  dev              - 切换开发者选项 (enable=显示触摸/指针位置/秒, disable=关闭)"
    echo "  powers           - 切换 powersd 服务 (enable=start, disable=stop)"
    echo "  debugfs          - 挂载/卸载 debugfs (enable=mount /sys/kernel/debug, disable=umount)"
    echo ""
    echo "示例:"
    echo "  ad enable/disable google/moto/com.android.chrome"
    echo "  ad enable/disable selinux"
    echo "  ad enable/disable dev"
    echo "  ad enable/disable powers"
    echo "  ad enable/disable debugfs"
    echo ""
}

# 预设应用包列表
GOOGLE_PACKAGES="
com.google.android.apps.googleassistant
com.google.android.calendar
com.android.chrome
com.google.android.apps.wellbeing
com.google.android.apps.docs
com.google.android.apps.tachyon
com.google.android.inputmethod.latin
com.google.android.gm
com.google.android.googlequicksearchbox
com.google.android.videos
com.google.android.gms
com.android.vending
com.google.android.apps.maps
com.google.android.apps.photos
com.google.android.youtube
com.google.android.apps.youtube.music
com.google.android.apps.subscriptions.red
com.google.android.apps.kids.home
com.google.android.contacts
com.google.android.apps.books
com.google.android.projection.gearhead
com.google.android.keep
com.google.android.tts
com.google.android.apps.walletnfcrel
com.google.android.partnersetup
com.google.android.ims
com.roger.test
com.google.android.apps.bard
com.google.android.apps.messaging
com.google.android.dialer
com.google.android.apps.nbu.files
com.google.android.apps.wallpaper
com.google.android.calculator
com.google.android.deskclock
com.google.android.apps.chromecast.app
com.google.android.marvin.talkback
com.google.android.apps.safetyhub
com.google.android.apps.restore
com.google.android.apps.turbo
com.google.android.apps.adm
com.google.android.apps.scone
com.google.android.apps.tycho
com.google.ar.core
"

MOTO_PACKAGES="
com.motorola.tools.batterytracer
com.google.android.googlequicksearchbox
com.motorola.bug2go
com.motorola.moto_stats
"

# selinux 开关处理（作为目标处理）
do_selinux() {
    if [ "$ACTION" = "enable" ]; then
        setenforce 1
        log "selinux 已开启 (setenforce 1)"
    else
        setenforce 0
        log "selinux 已关闭 (setenforce 0)"
    fi
    echo "selinux is $(getenforce) mode"
}

# 开发者选项开关（显示触摸/指针位置/秒表）
do_developer() {
    if [ "$ACTION" = "enable" ]; then
        settings put system show_touches 1
        settings put system pointer_location 1
        settings put secure clock_seconds 1
        log "开发者选项已开启 (显示触摸/指针位置/秒)"
    else
        settings put system show_touches 0
        settings put system pointer_location 0
        settings put secure clock_seconds 0
        log "开发者选项已关闭 (显示触摸/指针位置/秒)"
    fi
}

# powersd 服务开关
do_powers() {
    if [ "$ACTION" = "enable" ]; then
        start powersd
        log "powersd 已启动 (start powersd)"
    else
        stop powersd
        log "powersd 已停止 (stop powersd)"
    fi
    echo "init.svc.powersd = $(getprop init.svc.powersd)"
}

# debugfs 挂载开关
do_debugfs() {
    if [ "$ACTION" = "enable" ]; then
        mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null
        log "debugfs 已挂载 (/sys/kernel/debug)"
    else
        umount /sys/kernel/debug
        log "debugfs 已卸载 (/sys/kernel/debug)"
    fi
    mount | grep debugfs
}

# 切换单个应用包
toggle_single_package() {
    pkg="$1"
    [ -z "$pkg" ] && return 0

    # 校验包名在系统中是否存在
    pm path "$pkg" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        err "[WARN] 应用包不存在于当前系统: $pkg"
        return 1
    fi

    if [ "$ACTION" = "disable" ]; then
        log "禁用包: $pkg"
        pm disable-user "$pkg"
    else
        log "启用包: $pkg"
        pm enable "$pkg"
    fi
}

# 参数解析与校验
parse_args() {
    case "$ACTION" in
        -h|--help|help|usage|"") usage; exit 0 ;;
    esac
    case "$TARGET" in
        -h|--help|help|usage|"") usage; exit 0 ;;
    esac
    if [ -z "$TARGET" ]; then
        die "未指定目标或包名"
    fi
}

# 命令路由分发（selinux/dev 与应用包切换 并列）
route() {
    case "$TARGET" in
        selinux) do_selinux; return ;;
        dev)     do_developer; return ;;
        powers)  do_powers; return ;;
        debugfs) do_debugfs; return ;;
        google)  PKG_LIST="$GOOGLE_PACKAGES" ;;
        moto)    PKG_LIST="$MOTO_PACKAGES" ;;
        *)       PKG_LIST="$TARGET" ;;
    esac

    log "=== 执行 $ACTION 操作 -> 目标: $TARGET ==="
    for pkg in $PKG_LIST; do
        toggle_single_package "$pkg"
    done
    log "=== 操作完成 ==="
}

main() {
    # 1. 参数解析与校验（含 usage()/exit）
    parse_args "$@"

    # 2. 命令路由分发
    route
}

main "$@"
exit 0
