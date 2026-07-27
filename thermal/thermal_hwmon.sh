#!/system/bin/sh
BASE_DIR="/sys/class/hwmon"
if [ ! -d "$BASE_DIR" ]; then
    echo "[错误] 未找到 $BASE_DIR 接口"
    exit 1
fi

for d in $(ls -d $BASE_DIR/hwmon* | sort -V); do
    name=$(cat $d/name 2>/dev/null || echo 'unknown')
    printf '%-10s [ %s ]\n' "$(basename $d)" "$name"
  
    # 处理输入传感器
    for f in $d/*_input; do
        [ -f "$f" ] || continue
        prefix=$(basename $f | sed 's/_input//')
        val=$(cat $f 2>/dev/null)
        label_val=$(cat "$d/${prefix}_label" 2>/dev/null)
        [ -n "$label_val" ] && l_str="($label_val)" || l_str=""
    
    # 温度单位转换
    display_val="$val"
    case "$prefix" in temp*) [ -n "$val" ] && display_val=$((val / 1000)) ;; esac
    printf '  %-10s %-20s : %s\n' "$prefix" "$l_str" "$display_val"
    done

    # 处理 PWM
    for f in $(ls $d/pwm[0-9]* 2>/dev/null | grep -v "_enable"); do
        [ -f "$f" ] || continue
        en=$(cat "${f}_enable" 2>/dev/null)
        printf '  %-10s %-20s : %s\n' "$(basename $f)" "(en:$en)" "$(cat $f)"
    done
done