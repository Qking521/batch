#!/system/bin/sh
# 用法: cpu_info.sh

for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    n=$(basename "$cpu")

    if [ -f "$cpu/online" ]; then
        online=$(cat "$cpu/online" 2>/dev/null)
    else
        online=1
    fi

    if [ "$online" = "0" ]; then
        echo "$n: offline"
        continue
    fi

    gov=$(cat "$cpu/cpufreq/scaling_governor" 2>/dev/null)
    cur=$(cat "$cpu/cpufreq/scaling_cur_freq" 2>/dev/null)
    minf=$(cat "$cpu/cpufreq/scaling_min_freq" 2>/dev/null)
    maxf=$(cat "$cpu/cpufreq/scaling_max_freq" 2>/dev/null)

    echo "$n: governor=$gov cur=${cur}kHz range=[${minf}-${maxf}]kHz"
done