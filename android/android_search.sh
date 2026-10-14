#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-07-31
# Desc:   搜索 Android settings 三库及 getprop 属性（模糊匹配）
# Usage:  通过 stdin 注入: adb shell "sh -s <pattern>" < android_search.sh
# ============================================================

PATTERN="$1"

if [ -z "$PATTERN" ]; then
    echo "[ERROR] 缺少搜索关键字"
    exit 1
fi

# ---- 搜索 settings 三库 ----
for db in system secure global; do
    settings list "$db" 2>/dev/null | grep -i "$PATTERN" | while IFS= read -r line; do
        echo "[$db] $line"
    done
done

# ---- 搜索 getprop ----
getprop | grep -i "$PATTERN" | while IFS= read -r line; do
    echo "[prop] $line"
done

# ---- 搜索 moto扩展的settings 三库 ----
if [ "$(getprop ro.product.brand)" = "motorola" ]; then
    for db in secure global system; do
        content query --uri "content://com.motorola.android.providers.settings/$db" 2>/dev/null \
            | sed -n 's/.*name=\([^,]*\), value=\(.*\)$/\1=\2/p' \
            | grep -i "$PATTERN" \
            | while IFS= read -r line; do
                echo "[moto_$db] $line"
            done
    done
fi

# ---- 查找resource信息 ----
names=$(strings /system/framework/framework-res.apk 2>/dev/null \
    | grep -i "$PATTERN" \
    | grep -v '/' \
    | sed 's/^[^A-Za-z0-9_.]*//' \
    | grep -E '^[A-Za-z_][A-Za-z0-9_.]*$' \
    | sort -u)

if [ ! -z "$names" ]; then
    echo "$names" | while IFS= read -r name; do
        for type in string bool integer; do
            if val=$(cmd overlay lookup android "android:$type/$name" 2>/dev/null); then
                echo "[res_$type] $name = $val"
            fi
        done
    done
fi