#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-07-30
# Desc:   设备侧壁纸操作脚本
#         通过 am start 设置或查看已推送到设备的壁纸文件
# Usage:  adb shell "sh -s <action> <remote_path>" < power_wallpaper.sh
#         action      : set | view
#         remote_path : 设备上的壁纸路径，如 /sdcard/black_wallpaper.png
# ============================================================

ACTION="$1"
REMOTE_PATH="$2"

# 参数校验
if [ -z "$ACTION" ] || [ -z "$REMOTE_PATH" ]; then
    echo "[ERROR] 参数不足: 需要 <action> <remote_path>"
    echo "  用法: adb shell \"sh -s <set|view> <remote_path>\" < power_wallpaper.sh"
    exit 1
fi

# 检查文件是否存在
if [ ! -f "$REMOTE_PATH" ]; then
    echo "[ERROR] 设备上找不到壁纸文件: $REMOTE_PATH"
    exit 1
fi

do_set() {
    echo ">>> 正在设置壁纸: $REMOTE_PATH"
    am start -a android.intent.action.ATTACH_DATA \
        -d "file://$REMOTE_PATH" \
        -t image/* \
        --ez set-wallpaper true > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "  [OK] 壁纸设置指令已发送"
    else
        echo "  [FAIL] 壁纸设置指令发送失败"
        exit 1
    fi
}

do_view() {
    echo ">>> 正在打开壁纸预览: $REMOTE_PATH"
    am start -a android.intent.action.VIEW \
        -d "file://$REMOTE_PATH" \
        -t image/* > /dev/null 2>&1
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
