#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-11-18
# Desc:   按 PID / 包名 / 关键字 杀进程 (设备端执行, 由 android_all.bat kill 调用)
# Usage:  adb shell -t "sh /data/local/tmp/android_kill.sh <pid|pkg|keyword>"
# ============================================================

TARGET="$1"

usage() {
    echo "用法: ad kill <pid|pkg|keyword>"
    echo "  <pid>      - 纯数字, 作为 PID 杀掉"
    echo "  <pkg>      - 包名, 如 com.android.chrome"
    echo "  <keyword>  - 进程名关键字, 模糊匹配, 多命中时交互选择"
}

if [ -z "$TARGET" ]; then
    echo "[ERROR] Please specify PID, package name or keyword."
    usage
    exit 1
fi

# 1) 纯数字 -> 视为 PID, 校验存在性后 kill
case "$TARGET" in
    *[!0-9]*) ;;   # 含非数字, 进入关键字模式
    *)
        if [ ! -d "/proc/$TARGET" ]; then
            echo "[ERROR] PID not found: $TARGET"
            exit 1
        fi
        if kill -9 "$TARGET" 2>/dev/null; then
            echo "[OK] Killed by PID: $TARGET"
            exit 0
        fi
        echo "[ERROR] Failed to kill PID: $TARGET"
        exit 1
        ;;
esac

# 2) 关键字模式: 抓取进程列表, 按进程名模糊匹配并去重
NAMES=$(ps -A | awk -v kw="$TARGET" 'NR>1 {name=$NF; if (index(tolower(name), tolower(kw))>0) print name}' | sort -u)

if [ -z "$NAMES" ]; then
    echo "[ERROR] No process matched: $TARGET"
    exit 1
fi

COUNT=0
for n in $NAMES; do COUNT=$((COUNT + 1)); done

# 3) 唯一命中直接采用, 多命中弹菜单选择
TARGET_NAME=""
if [ "$COUNT" -eq 1 ]; then
    for n in $NAMES; do TARGET_NAME="$n"; done
else
    echo ""
    echo "Multiple processes matched \"$TARGET\", choose one to kill:"
    i=0
    for n in $NAMES; do
        i=$((i + 1))
        echo "    [$i] $n"
    done
    echo ""
    printf "Enter index to kill [1-%d]: " "$COUNT"
    read SEL
    i=0
    for n in $NAMES; do
        i=$((i + 1))
        [ "$i" = "$SEL" ] && TARGET_NAME="$n"
    done
fi

if [ -z "$TARGET_NAME" ]; then
    echo "[ERROR] Invalid selection or process not found."
    exit 1
fi

# 4) 杀掉选定进程名的全部 PID
echo "[INFO] Target process: $TARGET_NAME"
KILLED=0
for pid in $(ps -A | awk -v name="$TARGET_NAME" 'NR>1 && $NF==name {print $2}'); do
    if kill -9 "$pid" 2>/dev/null; then
        echo "[OK] Killed PID $pid ($TARGET_NAME)"
        KILLED=$((KILLED + 1))
    fi
done

if [ "$KILLED" -eq 0 ]; then
    echo "[WARN] No running pid found for $TARGET_NAME"
    exit 1
fi
echo "[OK] Killed $KILLED process(es): $TARGET_NAME"
exit 0
