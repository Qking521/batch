#!/system/bin/sh
# ============================================================
# Author: Antigravity Pair Program
# Date:   2026-08-05
# Desc:   开启/禁用 Android 应用包（支持单应用包名或预设组 google/moto）
# Usage:  adb shell "sh -s <enable|disable> <pkg_name|google|moto>" < android_package_toggle.sh
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
    show_usage
    exit 1
}

show_usage() {
    echo ""
    echo "用法: ad [enable|disable] <package_name|google|moto>"
    echo ""
    echo "动作:"
    echo "  enable <target>   - 启用指定的应用包或预设分组"
    echo "  disable <target>  - 禁用指定的应用包或预设分组"
    echo ""
    echo "目标 (target):"
    echo "  <package_name>   - 具体应用包名，如 com.android.chrome"
    echo "  google           - 预设的 Google 相关应用包列表"
    echo "  moto             - 预设的 Moto 相关应用包列表"
    echo ""
    echo "示例:"
    echo "  ad enable com.android.chrome"
    echo "  ad disable google"
    echo "  ad enable moto"
    echo ""
}

# 参数校验
if [ -z "$ACTION" ] || [ "$ACTION" = "-h" ] || [ "$ACTION" = "help" ] || [ "$TARGET" = "-h" ] || [ "$TARGET" = "help" ]; then
    show_usage
    exit 0
fi

case "$ACTION" in
    enable|disable) ;;
    *) die "未知动作: '$ACTION'，仅支持 enable 或 disable" ;;
esac

if [ -z "$TARGET" ]; then
    die "错误: 未指定目标包名或分组"
fi

# 定义预设应用包列表
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
"

MOTO_PACKAGES="
com.motorola.tools.batterytracer
com.google.android.googlequicksearchbox
com.motorola.bug2go
com.motorola.moto_stats
"

case "$TARGET" in
    google) PKG_LIST="$GOOGLE_PACKAGES" ;;
    moto)   PKG_LIST="$MOTO_PACKAGES" ;;
    *)      PKG_LIST="$TARGET" ;;
esac

log "=== 执行 $ACTION 操作 -> 目标: $TARGET ==="

toggle_single_package() {
    pkg="$1"
    [ -z "$pkg" ] && return 0

    # 校验包名在系统中是否存在
    pm path "$pkg" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        err "[警告] 应用包不存在于当前系统: $pkg"
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

for pkg in $PKG_LIST; do
    toggle_single_package "$pkg"
done

log "=== 操作完成 ==="
exit 0
