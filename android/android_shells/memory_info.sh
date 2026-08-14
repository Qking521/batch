#!/system/bin/sh
# 用法: mem_info.sh

echo "== 系统内存 =="
awk '/^(MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree):/{
    printf "%s: %s kB\n", $1, $2
}' /proc/meminfo | sed 's/://'

echo
echo "== 进程内存 Top 10 (按 PSS) =="
dumpsys meminfo -a 2>/dev/null | awk '
/Total PSS by process/{flag=1; print; next}
flag && /^$/{exit}
flag{print; count++}
count>=10{exit}
'