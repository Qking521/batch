#!/system/bin/sh
# 用法: print_files.sh <目录> [过滤, 默认 *]
# 示例: print_files.sh /data/local/tmp
#       print_files.sh /data/local/tmp "*.sh"
#       print_files.sh .

DIR="$1"
FILTER="$2"

if [ -z "$DIR" ]; then
    echo "用法: $(basename "$0") <目录> [过滤, 默认 *]"
    exit 1
fi
[ -z "$FILTER" ] && FILTER="*"

if [ ! -d "$DIR" ]; then
    echo "[ERROR] 目录不存在: $DIR"
    exit 1
fi

count=0
LIST_FILE="/data/local/tmp/.print_files_list.$$"
ls -1 "$DIR" 2>/dev/null | sort > "$LIST_FILE"

while IFS= read -r name; do
    [ -z "$name" ] && continue
    case "$name" in
        $FILTER) ;;
        *) continue ;;
    esac
    f="$DIR/$name"
    [ -f "$f" ] || continue
    count=$((count + 1))

    content=$(cat "$f" 2>&1)
    lines=$(printf '%s\n' "$content" | wc -l)

    if [ "$lines" -le 1 ]; then
        echo "$name: $content"
    else
        echo "$name:"
        printf '%s\n' "$content" | sed 's/^/  /'
    fi
done < "$LIST_FILE"

rm -f "$LIST_FILE"

if [ "$count" -eq 0 ]; then
    echo "未找到匹配的文件: $DIR (过滤: $FILTER)"
    exit 1
fi

exit 0