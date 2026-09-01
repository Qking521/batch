#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-07-31
# Desc:   CPU 信息查询与调控工具
# Usage:  adb shell "sh -s <action> [param1] [param2]" < perf_cpu.sh
#
# Actions:
#   info              - 查看 CPU 大小核、频点、当前频率、online 状态
#   freq              - 查看各簇可用频率列表
#   online            - 查看各核 online 状态
#   set-online   <cpu_id> <0|1>  - 上下线指定核（cpu0 不可下线）
#   fix-freq     <policy> <khz>  - 定频指定 policy (支持 0, 4, policy0, cpu4 等，单位 KHz)
#   unfix-freq   <policy>        - 解除定频（恢复默认调度）
#   fix-freq-all <khz>           - 所有 policy 统一定频
#   unfix-all                    - 解除所有 policy 定频
#   boost        <0|1>           - 开关 CPU boost（平台自适应）
#   affinity     <pid> <mask>    - 设置进程绑核（taskset 十六进制 mask）
#   gov          <policy> <gov>  - 切换 governor（schedutil/performance/powersave）
#   gov-all      <gov>           - 所有 policy 统一切换 governor
#   cap          <policy> <khz>  - 限制最大频率（单位 KHz）
#   uncap        <policy>        - 解除最大频率限制
#   platform                     - 检测当前平台（MTK/Qualcomm/UNISOC/Other）
# ============================================================

ACTION="$1"
PARAM1="$2"
PARAM2="$3"

# ---- 工具函数 ----

# 检测芯片平台
detect_platform() {
    board=$(getprop ro.product.board 2>/dev/null | tr '[:upper:]' '[:lower:]')
    soc=$(getprop ro.board.platform 2>/dev/null | tr '[:upper:]' '[:lower:]')
    hardware=$(getprop ro.hardware 2>/dev/null | tr '[:upper:]' '[:lower:]')
    combined="$board $soc $hardware"

    case "$combined" in
        *mt[0-9]*|*mediatek*|*mtk*)
            echo "MTK" ;;
        *sm[0-9]*|*msm*|*qcom*|*snapdragon*)
            echo "Qualcomm" ;;
        *ums*|*sc[0-9]*|*spreadtrum*|*unisoc*)
            echo "UNISOC" ;;
        *)
            echo "Other" ;;
    esac
}

# 列出所有 cpufreq policy 目录
list_policies() {
    ls /sys/devices/system/cpu/cpufreq/ 2>/dev/null | grep '^policy'
}

# 智能解析 policy 输入 (支持 0, 4, policy0, policy4, cpu0, cpu4 等格式)
resolve_policy() {
    input="$1"
    [ -z "$input" ] && return 1

    # 1. 直接匹配现有 policy 目录名 (例如 policy0, policy4)
    if [ -d "/sys/devices/system/cpu/cpufreq/$input" ]; then
        echo "$input"
        return 0
    fi

    # 2. 如果输入的是数字 N，优先匹配 policyN (例如输入 0 匹配 policy0, 输入 4 匹配 policy4)
    if [ -d "/sys/devices/system/cpu/cpufreq/policy$input" ]; then
        echo "policy$input"
        return 0
    fi

    # 3. 如果输入的是 cpu 编号 (例如输入 1, cpu1, 5, cpu5)，通过 cpuX/cpufreq 软链接解析所属 policy
    cpuname="$input"
    case "$cpuname" in
        cpu[0-9]*) ;;
        [0-9]*) cpuname="cpu$input" ;;
    esac

    if [ -e "/sys/devices/system/cpu/$cpuname/cpufreq" ]; then
        target=$(readlink "/sys/devices/system/cpu/$cpuname/cpufreq" 2>/dev/null)
        if [ -n "$target" ]; then
            echo "${target##*/}"
            return 0
        fi
    fi

    return 1
}

# 读节点，失败返回 N/A
read_node() {
    cat "$1" 2>/dev/null || echo "N/A"
}

# 写节点，带权限提示
write_node() {
    node="$1"
    val="$2"
    if [ ! -w "$node" ]; then
        echo "[ERROR] 无写权限: $node （请确保 adb root 已开启）"
        return 1
    fi
    echo "$val" > "$node" && echo "[OK] $node = $val" || echo "[ERROR] 写入失败: $node"
}

# ---- MTK 平台特有 boost 节点 ----
mtk_boost() {
    val="$1"
    node="/proc/ppm/enabled"
    if [ -f "$node" ]; then
        write_node "$node" "$val"
    else
        echo "[WARN] MTK PPM 节点不存在: $node"
    fi
}

# ---- 高通平台特有 boost 节点 ----
qcom_boost() {
    val="$1"
    # 高通 schedboost / schedutil boost
    for node in \
        /sys/devices/system/cpu/cpu_boost/enabled \
        /dev/cpu_dma_latency \
        /sys/module/msm_performance/parameters/cpu_max_freq; do
        [ -f "$node" ] && write_node "$node" "$val" && return
    done
    echo "[WARN] 未找到高通 boost 节点，尝试写 schedutil boost_perf..."
    for policy in $(list_policies); do
        node="/sys/devices/system/cpu/cpufreq/$policy/schedutil/boost"
        [ -f "$node" ] && write_node "$node" "$val"
    done
}

# ---- UNISOC 平台特有 boost ----
unisoc_boost() {
    val="$1"
    node="/sys/module/sprd_cpu_debug/parameters/debug_enable"
    [ -f "$node" ] && write_node "$node" "$val" || echo "[WARN] 未找到 UNISOC boost 节点"
}

# ============================================================
# ACTION 分发
# ============================================================

case "$ACTION" in

# ---- 平台检测 ----
platform)
    plat=$(detect_platform)
    board=$(getprop ro.product.board 2>/dev/null)
    soc=$(getprop ro.board.platform 2>/dev/null)
    echo "平台:   $plat"
    echo "Board:  $board"
    echo "SoC:    $soc"
    ;;

# ---- CPU 总览 ----
info)
    plat=$(detect_platform)
    echo "=========================================================="
    echo " CPU 信息总览  [平台: $plat]"
    echo "=========================================================="
    # Policy 表：含硬件最大频点与限频状态
    printf '%-9s %-12s %-10s %-10s %-14s %-14s %-10s %s\n' \
        'POLICY' 'CPUS' 'MIN(KHz)' 'CUR(KHz)' 'MAX(KHz)' 'HW_MAX(KHz)' 'GOV' 'THROTTLE?'
    echo "-----------------------------------------------------------------------------------------"
    for policy in $(list_policies); do
        pdir="/sys/devices/system/cpu/cpufreq/$policy"
        affected=$(read_node "$pdir/affected_cpus")
        min=$(read_node     "$pdir/scaling_min_freq")
        cur=$(read_node     "$pdir/scaling_cur_freq")
        max=$(read_node     "$pdir/scaling_max_freq")
        hw_max=$(read_node  "$pdir/cpuinfo_max_freq")
        gov=$(read_node     "$pdir/scaling_governor")

        # 限频判断：scaling_max < cpuinfo_max
        throttle="no"
        if [ "$max" != "N/A" ] && [ "$hw_max" != "N/A" ]; then
            [ "$max" -lt "$hw_max" ] 2>/dev/null && throttle="[YES] ${max} < ${hw_max}"
        fi

        printf '%-9s %-12s %-10s %-10s %-14s %-14s %-10s %s\n' \
            "$policy" "$affected" "$min" "$cur" "$max" "$hw_max" "$gov" "$throttle"

        # 可用频率列表
        avail=$(read_node "$pdir/scaling_available_frequencies")
        if [ "$avail" != "N/A" ] && [ -n "$avail" ]; then
            echo "  └─ 可用频率: $avail"
        fi
    done
    echo ""
    echo "--- CPU 核心信息状态 ---"
    printf '%-8s %-12s %-16s %-10s\n' 'CPU' 'STATUS' 'CUR_FREQ(KHz)' 'TEMP'
    echo "----------------------------------------------------"
    for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
        cpuid=${cpu_dir##*/}
        
        # 1. 在线状态
        node="$cpu_dir/online"
        if [ -f "$node" ]; then
            state=$(read_node "$node")
            [ "$state" = "1" ] && status="online" || status="offline"
        else
            status="online(固定)"
        fi

        # 2. 当前 CPU 频率
        cur_freq=$(read_node "$cpu_dir/cpufreq/scaling_cur_freq")

        # 3. CPU 核心温度 (针对大核等有多个传感器节点的场景，提取属于该 CPU 的传感器最大值)
        max_temp_mC=-999000
        cpu_num=${cpuid#cpu}
        
        # 确定匹配模式：小核通常为 little/cpuX，大核通常为 big-coreX / coreX
        for tz in /sys/class/thermal/thermal_zone*; do
            [ -d "$tz" ] || continue
            type=$(cat "$tz/type" 2>/dev/null)
            matched=0
            case "$type" in
                *cpu*little*${cpu_num}*|*cpu-${cpu_num}*|*little-core${cpu_num}*)
                    matched=1 ;;
                *cpu*big*core${cpu_num}*|*big-core${cpu_num}*|*core${cpu_num}*)
                    # 针对大核编号映射（例如 8 核设备中 cpu4->big-core0, cpu5->big-core1 等，或直连数字）
                    matched=1 ;;
            esac

            # 兼容 8 核中大核编号的物理序号换算 (例如 4~7 对应 big-core0~3)
            if [ "$matched" -eq 0 ] && [ "$cpu_num" -ge 4 ] 2>/dev/null; then
                big_idx=$(( cpu_num - 4 ))
                case "$type" in
                    *big-core${big_idx}*|*big_core${big_idx}*)
                        matched=1 ;;
                esac
            fi

            if [ "$matched" -eq 1 ]; then
                temp_raw=$(cat "$tz/temp" 2>/dev/null)
                if [ -n "$temp_raw" ] && [ "$temp_raw" -gt "$max_temp_mC" ] 2>/dev/null; then
                    max_temp_mC=$temp_raw
                fi
            fi
        done

        if [ "$max_temp_mC" -gt -999000 ] 2>/dev/null; then
            if [ "$max_temp_mC" -gt 1000 ] 2>/dev/null || [ "$max_temp_mC" -lt -1000 ] 2>/dev/null; then
                temp_str="$(( max_temp_mC / 1000 )).$(( (max_temp_mC % 1000) / 100 )) C"
            else
                temp_str="${max_temp_mC} C"
            fi
        else
            temp_str="N/A"
        fi

        printf '%-8s %-12s %-16s %-10s\n' "$cpuid" "$status" "$cur_freq" "$temp_str"
    done
    ;;

# ---- 频率列表 ----
freq)
    echo "=========================================="
    echo " 各 Policy 可用频率列表"
    echo "=========================================="
    for policy in $(list_policies); do
        pdir="/sys/devices/system/cpu/cpufreq/$policy"
        affected=$(read_node "$pdir/affected_cpus")
        echo ""
        echo "[$policy] (绑定核心: cpu $affected)"
        avail=$(read_node "$pdir/scaling_available_frequencies")
        for f in $avail; do
            mhz=$((f / 1000))
            echo "    ${f} KHz  (${mhz} MHz)"
        done
    done
    ;;

# ---- online 状态查看 ----
online)
    echo "CPU online 状态:"
    for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
        id=${cpu##*/}
        node="$cpu/online"
        if [ -f "$node" ]; then
            state=$(read_node "$node")
            [ "$state" = "1" ] && status="[online ]" || status="[offline]"
        else
            status="[online ](固定)"
        fi
        echo "  $id $status"
    done
    ;;

# ---- 上下线指定核 ----
set-online)
    cpu_id="$PARAM1"
    val="$PARAM2"
    if [ -z "$cpu_id" ] || [ -z "$val" ]; then
        echo "[ERROR] 用法: set-online <cpu_id> <0|1>  例如: set-online cpu3 0"
        exit 1
    fi
    node="/sys/devices/system/cpu/$cpu_id/online"
    if [ ! -f "$node" ]; then
        echo "[ERROR] 节点不存在: $node（cpu0 不支持下线，或 cpu_id 有误）"
        exit 1
    fi
    write_node "$node" "$val"
    ;;

# ---- 定频指定 policy ----
fix-freq)
    # 单参数直接定频所有 policy (如 fix-freq 1800000)
    is_num=0
    case "$PARAM1" in
        *[!0-9]*) is_num=0 ;;
        "")       is_num=0 ;;
        *)        is_num=1 ;;
    esac

    if [ "$is_num" -eq 1 ] && [ -z "$PARAM2" ]; then
        freq="$PARAM1"
        for policy in $(list_policies); do
            pdir="/sys/devices/system/cpu/cpufreq/$policy"
            cur_min=$(read_node "$pdir/scaling_min_freq")
            if [ "$freq" -ge "$cur_min" ] 2>/dev/null; then
                write_node "$pdir/scaling_max_freq" "$freq"
                write_node "$pdir/scaling_min_freq" "$freq"
            else
                write_node "$pdir/scaling_min_freq" "$freq"
                write_node "$pdir/scaling_max_freq" "$freq"
            fi
        done
        exit 0
    fi

    raw_policy="$PARAM1"
    freq="$PARAM2"
    if [ -z "$raw_policy" ] || [ -z "$freq" ]; then
        echo "[ERROR] 用法: fix-freq [policy|cpu_id] <freq_khz>"
        echo "  例如: fix-freq 1800000 (所有 policy) 或 fix-freq 4 2400000 (指定 policy4)"
        echo "  可用 policy: $(list_policies | tr '\n' ' ')"
        exit 1
    fi
    policy=$(resolve_policy "$raw_policy")
    if [ -z "$policy" ]; then
        echo "[ERROR] 找不到对应的 policy: $raw_policy"
        echo "  当前设备可用 policy: $(list_policies | tr '\n' ' ')"
        exit 1
    fi
    pdir="/sys/devices/system/cpu/cpufreq/$policy"

    cur_min=$(read_node "$pdir/scaling_min_freq")
    if [ "$freq" -ge "$cur_min" ] 2>/dev/null; then
        write_node "$pdir/scaling_max_freq" "$freq"
        write_node "$pdir/scaling_min_freq" "$freq"
    else
        write_node "$pdir/scaling_min_freq" "$freq"
        write_node "$pdir/scaling_max_freq" "$freq"
    fi
    ;;

# ---- 解除定频 ----
unfix-freq)
    raw_policy="$PARAM1"
    # 无参数或传 all 时解除所有 policy 定频
    if [ -z "$raw_policy" ] || [ "$raw_policy" = "all" ]; then
        for policy in $(list_policies); do
            pdir="/sys/devices/system/cpu/cpufreq/$policy"
            min=$(read_node "$pdir/cpuinfo_min_freq")
            max=$(read_node "$pdir/cpuinfo_max_freq")
            write_node "$pdir/scaling_min_freq" "$min"
            write_node "$pdir/scaling_max_freq" "$max"
        done
        echo "[OK] 所有 policy 已解除定频"
        exit 0
    fi
    policy=$(resolve_policy "$raw_policy")
    if [ -z "$policy" ]; then
        echo "[ERROR] 找不到对应的 policy: $raw_policy"
        echo "  当前设备可用 policy: $(list_policies | tr '\n' ' ')"
        exit 1
    fi
    pdir="/sys/devices/system/cpu/cpufreq/$policy"
    min=$(read_node "$pdir/cpuinfo_min_freq")
    max=$(read_node "$pdir/cpuinfo_max_freq")
    write_node "$pdir/scaling_min_freq" "$min"
    write_node "$pdir/scaling_max_freq" "$max"
    ;;

# ---- 全部 policy 定频 ----
fix-freq-all)
    freq="$PARAM1"
    if [ -z "$freq" ]; then
        echo "[ERROR] 用法: fix-freq-all <freq_khz>  例如: fix-freq-all 1800000"
        exit 1
    fi
    for policy in $(list_policies); do
        pdir="/sys/devices/system/cpu/cpufreq/$policy"
        cur_min=$(read_node "$pdir/scaling_min_freq")
        if [ "$freq" -ge "$cur_min" ] 2>/dev/null; then
            write_node "$pdir/scaling_max_freq" "$freq"
            write_node "$pdir/scaling_min_freq" "$freq"
        else
            write_node "$pdir/scaling_min_freq" "$freq"
            write_node "$pdir/scaling_max_freq" "$freq"
        fi
    done
    ;;

# ---- 解除所有定频 ----
unfix-all)
    for policy in $(list_policies); do
        pdir="/sys/devices/system/cpu/cpufreq/$policy"
        min=$(read_node "$pdir/cpuinfo_min_freq")
        max=$(read_node "$pdir/cpuinfo_max_freq")
        write_node "$pdir/scaling_min_freq" "$min"
        write_node "$pdir/scaling_max_freq" "$max"
    done
    echo "[OK] 所有 policy 已解除定频"
    ;;

# ---- CPU boost ----
boost)
    val="$PARAM1"
    if [ "$val" != "0" ] && [ "$val" != "1" ]; then
        echo "[ERROR] 用法: boost <0|1>"
        exit 1
    fi
    plat=$(detect_platform)
    echo "平台: $plat  boost -> $val"
    case "$plat" in
        MTK)      mtk_boost "$val" ;;
        Qualcomm) qcom_boost "$val" ;;
        UNISOC)   unisoc_boost "$val" ;;
        *)
            # 通用 schedutil boost 尝试
            found=0
            for policy in $(list_policies); do
                node="/sys/devices/system/cpu/cpufreq/$policy/schedutil/boost"
                if [ -f "$node" ]; then
                    write_node "$node" "$val"
                    found=1
                fi
            done
            [ "$found" = "0" ] && echo "[WARN] 未找到 boost 节点，平台可能不支持"
            ;;
    esac
    ;;

# ---- 绑核（taskset）----
affinity)
    pid="$PARAM1"
    mask="$PARAM2"
    if [ -z "$pid" ] || [ -z "$mask" ]; then
        echo "[ERROR] 用法: affinity <pid> <hex_mask>"
        echo "  例如: affinity 1234 f0   (绑到 cpu4-cpu7)"
        echo "  mask 计算: cpu0=0x01 cpu1=0x02 cpu2=0x04 ... 叠加"
        exit 1
    fi
    taskset -p "$mask" "$pid" && echo "[OK] pid $pid 已绑核 mask=0x$mask" || echo "[ERROR] taskset 失败，请检查 pid 和权限"
    ;;

# ---- 切换 governor ----
gov)
    # 单参数直接切换所有 policy 的 governor (如 gov performance)
    if [ -n "$PARAM1" ] && [ -z "$PARAM2" ]; then
        governor="$PARAM1"
        for policy in $(list_policies); do
            pdir="/sys/devices/system/cpu/cpufreq/$policy"
            write_node "$pdir/scaling_governor" "$governor"
        done
        exit 0
    fi

    raw_policy="$PARAM1"
    governor="$PARAM2"
    if [ -z "$raw_policy" ] || [ -z "$governor" ]; then
        echo "[ERROR] 用法: gov [policy|cpu_id] <governor>"
        echo "  常用 governor: schedutil performance powersave ondemand conservative"
        echo "  例如: gov performance (所有 policy) 或 gov 4 schedutil (指定 policy4)"
        echo "  可用 policy: $(list_policies | tr '\n' ' ')"
        exit 1
    fi
    policy=$(resolve_policy "$raw_policy")
    if [ -z "$policy" ]; then
        echo "[ERROR] 找不到对应的 policy: $raw_policy"
        echo "  当前设备可用 policy: $(list_policies | tr '\n' ' ')"
        exit 1
    fi
    pdir="/sys/devices/system/cpu/cpufreq/$policy"
    avail=$(read_node "$pdir/scaling_available_governors")
    echo "可用 governor: $avail"
    write_node "$pdir/scaling_governor" "$governor"
    ;;

# ---- 全部 policy 切换 governor ----
gov-all)
    governor="$PARAM1"
    if [ -z "$governor" ]; then
        echo "[ERROR] 用法: gov-all <governor>"
        exit 1
    fi
    for policy in $(list_policies); do
        pdir="/sys/devices/system/cpu/cpufreq/$policy"
        write_node "$pdir/scaling_governor" "$governor"
    done
    ;;

# ---- 限制最大频率（cap）----
cap)
    # 单参数直接限制所有 policy 最大频率 (如 cap 2400000)
    is_num=0
    case "$PARAM1" in
        *[!0-9]*) is_num=0 ;;
        "")       is_num=0 ;;
        *)        is_num=1 ;;
    esac

    if [ "$is_num" -eq 1 ] && [ -z "$PARAM2" ]; then
        freq="$PARAM1"
        for policy in $(list_policies); do
            pdir="/sys/devices/system/cpu/cpufreq/$policy"
            cur_min=$(read_node "$pdir/scaling_min_freq")
            if [ "$freq" -lt "$cur_min" ] 2>/dev/null; then
                write_node "$pdir/scaling_min_freq" "$freq"
            fi
            write_node "$pdir/scaling_max_freq" "$freq"
        done
        exit 0
    fi

    raw_policy="$PARAM1"
    freq="$PARAM2"
    if [ -z "$raw_policy" ] || [ -z "$freq" ]; then
        echo "[ERROR] 用法: cap [policy|cpu_id] <freq_khz>"
        echo "  例如: cap 2400000 (所有 policy) 或 cap 4 2400000 (指定 policy4)"
        echo "  可用 policy: $(list_policies | tr '\n' ' ')"
        exit 1
    fi
    policy=$(resolve_policy "$raw_policy")
    if [ -z "$policy" ]; then
        echo "[ERROR] 找不到对应的 policy: $raw_policy"
        echo "  当前设备可用 policy: $(list_policies | tr '\n' ' ')"
        exit 1
    fi
    pdir="/sys/devices/system/cpu/cpufreq/$policy"

    cur_min=$(read_node "$pdir/scaling_min_freq")
    if [ "$freq" -lt "$cur_min" ] 2>/dev/null; then
        write_node "$pdir/scaling_min_freq" "$freq"
    fi
    write_node "$pdir/scaling_max_freq" "$freq"
    ;;

# ---- 解除最大频率限制 ----
uncap)
    raw_policy="$PARAM1"
    # 无参数或传 all 时解除所有 policy 限制
    if [ -z "$raw_policy" ] || [ "$raw_policy" = "all" ]; then
        for policy in $(list_policies); do
            pdir="/sys/devices/system/cpu/cpufreq/$policy"
            max=$(read_node "$pdir/cpuinfo_max_freq")
            write_node "$pdir/scaling_max_freq" "$max"
        done
        echo "[OK] 所有 policy 已解除最大频率限制"
        exit 0
    fi

    policy=$(resolve_policy "$raw_policy")
    if [ -z "$policy" ]; then
        echo "[ERROR] 找不到对应的 policy: $raw_policy"
        echo "  当前设备可用 policy: $(list_policies | tr '\n' ' ')"
        exit 1
    fi
    pdir="/sys/devices/system/cpu/cpufreq/$policy"
    max=$(read_node "$pdir/cpuinfo_max_freq")
    write_node "$pdir/scaling_max_freq" "$max"
    ;;

# ---- 未知命令 ----
*)
    echo "[ERROR] 未知命令: $ACTION"
    echo ""
    echo "可用命令:"
    echo "  info                          - CPU 总览（大小核、频率、governor）"
    echo "  freq                          - 各 policy 可用频率列表"
    echo "  online                        - 各核 online 状态"
    echo "  platform                      - 检测芯片平台"
    echo "  set-online   <cpu_id> <0|1>   - 上下线指定核"
    echo "  fix-freq     [policy] <khz>   - 定频指定 policy（单参数如 1800000 默认定频所有 policy）"
    echo "  unfix-freq   [policy]         - 解除定频（无参数默认解除所有 policy）"
    echo "  fix-freq-all <khz>            - 所有 policy 统一定频"
    echo "  unfix-all                     - 解除所有 policy 定频"
    echo "  boost        <0|1>            - CPU boost 开关（平台自适应）"
    echo "  affinity     <pid> <mask>     - 绑核（taskset hex mask）"
    echo "  gov          [policy] <gov>   - 切换 governor（单参数默认切换所有 policy）"
    echo "  gov-all      <gov>            - 所有 policy 统一切换 governor"
    echo "  cap          [policy] <khz>   - 限制最大频率（单参数如 2400000 默认限制所有 policy）"
    echo "  uncap        [policy]         - 解除最大频率限制（无参数默认解除所有 policy）"
    exit 1
    ;;
esac

exit 0