#!/system/bin/sh
# ============================================================
# Author: wangqiang
# Date:   2026-10-22
# Desc:   设备侧壁纸脚本 - root 直写 /data/system/users/0/wallpaper
#         全自动设置, 不弹相册/裁剪 UI (需 adb root)
# Usage:  adb shell "sh -s <action> <remote_path>" < power_wallpaper.sh
#         action      : set | view
#         remote_path : 设备上已推送的壁纸路径, 如 /data/local/tmp/white_wallpaper.png
# ============================================================

ACTION="$1"
REMOTE_PATH="$2"

if [ -z "$ACTION" ] || [ -z "$REMOTE_PATH" ]; then
    echo "[ERROR] 参数不足: 需要 <action> <remote_path>"
    echo "  用法: adb shell \"sh -s <set|view> <remote_path>\" < power_wallpaper.sh"
    exit 1
fi

if [ ! -f "$REMOTE_PATH" ]; then
    echo "[ERROR] 设备上找不到壁纸文件: $REMOTE_PATH"
    exit 1
fi

do_set() {
    echo ">>> 正在设置壁纸(全自动): $REMOTE_PATH"

    if [ "$(id -u)" -ne 0 ]; then
        echo "  [FAIL] 需要 root 权限, 请先执行 adb root" >&2
        exit 1
    fi

    # 直写系统壁纸文件 (ImageWallpaper 用 BitmapFactory 解码, PNG/JPEG 均可)
    cp "$REMOTE_PATH" /data/system/users/0/wallpaper
    chown system:system /data/system/users/0/wallpaper
    chmod 600 /data/system/users/0/wallpaper
    restorecon /data/system/users/0/wallpaper 2>/dev/null

    # 重启 SystemUI, 让其重新读取壁纸文件并刷新显示
    killall com.android.systemui
    echo "  [OK] 壁纸已写入系统并刷新"
}

do_view() {
    echo ">>> 正在打开壁纸预览: $REMOTE_PATH"
    am start -a android.intent.action.VIEW \
        -d "file://$REMOTE_PATH" \
        -t image/* >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "  [OK] 图片查看指令已发送"
    else
        echo "  [FAIL] 图片查看指令发送失败"
        exit 1
    fi
}

case "$ACTION" in
    set)  do_set ;;
    view) do_view ;;
    *)
        echo "[ERROR] 未知 action: $ACTION (支持: set | view)"
        exit 1
        ;;
esac