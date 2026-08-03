#!/system/bin/sh
# ============================================================
# Desc:   GPU 信息查询与调控工具
# Usage:  adb shell "sh -s <action> [param1] [param2]" < perf_gpu.sh
#
# 平台差异很大，Qualcomm 和 MTK 走完全独立的实现，不共用节点：
#   Qualcomm: /sys/class/kgsl/kgsl-3d0 (+ 其下 devfreq 子目录)
#   MTK:      /sys/kernel/ged/hal (频率控制) + /proc/gpufreq(v2) (信息dump，按内核版本分叉)
#             /sys/module/ged/parameters (idle率、trace开关)
#
# Actions:
#   info                    - GPU 总览
#   freq                    - 查看可用频率/opp dump
#   gov          <governor> - 切换GPU governor（仅Qualcomm支持）
#   fix-freq     <freq>     - 定频（单位 Hz）
#   unfix-freq              - 解除定频，恢复默认
#   cap          <freq>     - 限制最大频率
#   uncap                   - 解除最大频率限制
#   busy                    - 查看GPU占用率/idle率
#   power                   - 查看频点档位信息
#   idle-policy  <policy>   - 设置Mali kbase power_policy（如 always_on，仅MTK/Mali）
#   trace        <0|1>      - 开关GED perf trace（仅MTK）
# ============================================================

ACTION="$1"
PARAM1="$2"
PARAM2="$3"

# ---- 通用工具函数 ----

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

read_node() {
    cat "$1" 2>/dev/null || echo "N/A"
}

write_node() {
    node="$1"
    val="$2"
    if [ ! -w "$node" ]; then
        echo "[ERROR] 无写权限: $node （请确保 adb root 已开启）"
        return 1
    fi
    echo "$val" > "$node" && echo "[OK] $node = $val" || echo "[ERROR] 写入失败: $node"
}

# ---- GPU 节点探测 ----
# 设置全局变量：
#   GPU_TYPE  kgsl | mtk_ged | none
#   GPU_DIR   (仅kgsl用) devfreq标准属性目录
#   KGSL_DIR  (仅kgsl用) kgsl专属目录
#   MTK_GED   (仅mtk_ged用) GED hal目录
resolve_gpu() {
    GPU_TYPE="none"
    GPU_DIR=""
    KGSL_DIR=""
    MTK_GED=""

    plat=$(detect_platform)

    case "$plat" in
        Qualcomm)
            if [ -d /sys/class/kgsl/kgsl-3d0 ]; then
                KGSL_DIR="/sys/class/kgsl/kgsl-3d0"
                if [ -d "$KGSL_DIR/devfreq" ]; then
                    GPU_TYPE="kgsl"
                    GPU_DIR="$KGSL_DIR/devfreq"
                fi
            fi
            ;;
        MTK)
            if [ -d /sys/kernel/ged/hal ]; then
                GPU_TYPE="mtk_ged"
                MTK_GED="/sys/kernel/ged/hal"
            fi
            ;;
    esac
}

# 按内核版本探测MTK GPU信息dump节点（只读），从新到旧依次尝试
mtk_dump_path() {
    for p in \
        /proc/gpufreqv2/gpu_working_opp_table \
        /proc/gpufreqv2/stack_working_opp_table \
        /proc/gpufreq/gpufreq_power_dump \
        /proc/gpufreq/gpufreq_opp_dump
    do
        [ -f "$p" ] && { echo "$p"; return 0; }
    done
    return 1
}

# ============================================================
# 各 action 对应的实现函数
# ============================================================

cmd_info() {
    plat=$(detect_platform)
    echo "=========================================="
    echo " GPU 信息总览  [平台: $plat]"
    echo "=========================================="

    case "$GPU_TYPE" in
        kgsl)
            [ -n "$KGSL_DIR" ] && echo "GPU型号: $(read_node "$KGSL_DIR/gpu_model")"
            echo "节点:     $GPU_DIR"
            echo "当前频率: $(read_node "$GPU_DIR/cur_freq") Hz"
            echo "最小频率: $(read_node "$GPU_DIR/min_freq") Hz"
            echo "最大频率: $(read_node "$GPU_DIR/max_freq") Hz"
            echo "Governor: $(read_node "$GPU_DIR/governor")"
            [ -f "$KGSL_DIR/gpu_busy_percentage" ] && echo "GPU占用率: $(read_node "$KGSL_DIR/gpu_busy_percentage")"
            ;;
        mtk_ged)
            echo "当前频率:   $(read_node "$MTK_GED/current_freqency")"
            echo "频点档位数: $(read_node "$MTK_GED/total_gpu_freq_level_count")"
            echo "自定义下限: $(read_node "$MTK_GED/custom_boost_gpu_freq")"
            echo "自定义上限: $(read_node "$MTK_GED/custom_upbound_gpu_freq")"
            echo "GPU idle:   $(read_node /sys/module/ged/parameters/gpu_idle)"
            dump=$(mtk_dump_path)
            if [ -n "$dump" ]; then
                echo ""
                echo "--- opp dump ($dump) ---"
                read_node "$dump"
            fi
            ;;
        *)
            echo "[ERROR] 未找到可用的GPU控制节点（当前平台: $plat）"
            return 1
            ;;
    esac
}

cmd_freq() {
    case "$GPU_TYPE" in
        kgsl)
            echo "可用频率 (Hz):"
            for f in $(read_node "$GPU_DIR/available_frequencies"); do
                khz=$((f / 1000))
                echo "  ${f} Hz  (${khz} MHz)"
            done
            ;;
        mtk_ged)
            dump=$(mtk_dump_path)
            if [ -z "$dump" ]; then
                echo "[ERROR] 未找到opp dump节点（/proc/gpufreq[v2]/... 均不存在）"
                return 1
            fi
            echo "opp dump ($dump):"
            read_node "$dump"
            ;;
        *)
            echo "[ERROR] 未找到可用的GPU控制节点"
            return 1
            ;;
    esac
}

cmd_gov() {
    governor="$1"
    if [ -z "$governor" ]; then
        echo "[ERROR] 用法: gov <governor>  例如: gov performance"
        return 1
    fi
    if [ "$GPU_TYPE" != "kgsl" ]; then
        echo "[ERROR] gov 仅支持 Qualcomm(kgsl) 平台，当前平台不适用"
        return 1
    fi
    echo "可用governor: $(read_node "$GPU_DIR/available_governors")"
    write_node "$GPU_DIR/governor" "$governor"
}

cmd_fix_freq() {
    freq="$1"
    if [ -z "$freq" ]; then
        echo "[ERROR] 用法: fix-freq <freq_hz>"
        return 1
    fi
    case "$GPU_TYPE" in
        kgsl)
            write_node "$GPU_DIR/min_freq" "$freq"
            write_node "$GPU_DIR/max_freq" "$freq"
            ;;
        mtk_ged)
            write_node "$MTK_GED/custom_boost_gpu_freq" "$freq"
            write_node "$MTK_GED/custom_upbound_gpu_freq" "$freq"
            ;;
        *)
            echo "[ERROR] 未找到可用的GPU控制节点"
            return 1
            ;;
    esac
}

cmd_unfix_freq() {
    case "$GPU_TYPE" in
        kgsl)
            avail=$(read_node "$GPU_DIR/available_frequencies")
            min=$(echo "$avail" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -n | head -1)
            max=$(echo "$avail" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -n | tail -1)
            if [ -z "$min" ] || [ -z "$max" ]; then
                echo "[ERROR] 未能从 available_frequencies 解析出 min/max"
                return 1
            fi
            write_node "$GPU_DIR/min_freq" "$min"
            write_node "$GPU_DIR/max_freq" "$max"
            ;;
        mtk_ged)
            # 注意：写0代表"取消自定义边界、恢复默认"是基于GED接口的常见约定推测，
            # 未经你的设备实测验证，跑完请自行确认频率是否恢复正常
            write_node "$MTK_GED/custom_boost_gpu_freq" "0"
            write_node "$MTK_GED/custom_upbound_gpu_freq" "0"
            ;;
        *)
            echo "[ERROR] 未找到可用的GPU控制节点"
            return 1
            ;;
    esac
}

cmd_cap() {
    freq="$1"
    if [ -z "$freq" ]; then
        echo "[ERROR] 用法: cap <freq_hz>"
        return 1
    fi
    case "$GPU_TYPE" in
        kgsl)
            write_node "$GPU_DIR/max_freq" "$freq"
            ;;
        mtk_ged)
            write_node "$MTK_GED/custom_upbound_gpu_freq" "$freq"
            ;;
        *)
            echo "[ERROR] 未找到可用的GPU控制节点"
            return 1
            ;;
    esac
}

cmd_uncap() {
    case "$GPU_TYPE" in
        kgsl)
            max=$(read_node "$GPU_DIR/available_frequencies" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -n | tail -1)
            if [ -z "$max" ]; then
                echo "[ERROR] 未能解析出 max 频率"
                return 1
            fi
            write_node "$GPU_DIR/max_freq" "$max"
            ;;
        mtk_ged)
            # 同 unfix-freq，写0恢复默认上限，未经实测验证
            write_node "$MTK_GED/custom_upbound_gpu_freq" "0"
            ;;
        *)
            echo "[ERROR] 未找到可用的GPU控制节点"
            return 1
            ;;
    esac
}

cmd_busy() {
    case "$GPU_TYPE" in
        kgsl)
            if [ -n "$KGSL_DIR" ] && [ -f "$KGSL_DIR/gpu_busy_percentage" ]; then
                echo "GPU占用率: $(read_node "$KGSL_DIR/gpu_busy_percentage")"
            else
                echo "[WARN] 未找到 gpu_busy_percentage 节点"
                return 1
            fi
            ;;
        mtk_ged)
            echo "GPU idle: $(read_node /sys/module/ged/parameters/gpu_idle)"
            ;;
        *)
            echo "[ERROR] 未找到可用的GPU控制节点"
            return 1
            ;;
    esac
}

cmd_power() {
    case "$GPU_TYPE" in
        kgsl)
            echo "num_pwrlevels:     $(read_node "$KGSL_DIR/num_pwrlevels")"
            echo "default_pwrlevel:  $(read_node "$KGSL_DIR/default_pwrlevel")"
            echo "min_pwrlevel:      $(read_node "$KGSL_DIR/min_pwrlevel")"
            echo "max_pwrlevel:      $(read_node "$KGSL_DIR/max_pwrlevel")"
            ;;
        mtk_ged)
            echo "频点档位数: $(read_node "$MTK_GED/total_gpu_freq_level_count")"
            echo "当前频率:   $(read_node "$MTK_GED/current_freqency")"
            ;;
        *)
            echo "[ERROR] 未找到可用的GPU控制节点"
            return 1
            ;;
    esac
}

# Mali kbase 通用节点（不止MTK，一些非MTK的Mali平台也可能有），
# 写 always_on 可以关闭GPU idle自动降频，具体可选值以设备实际支持为准
cmd_idle_policy() {
    policy="$1"
    if [ -z "$policy" ]; then
        echo "[ERROR] 用法: idle-policy <policy>  例如: idle-policy always_on"
        return 1
    fi
    node="/sys/class/misc/mali0/device/power_policy"
    if [ ! -f "$node" ]; then
        echo "[ERROR] 节点不存在: $node"
        return 1
    fi
    echo "可选policy: $(read_node "$node")"
    write_node "$node" "$policy"
}

# GED perf trace开关，仅MTK
cmd_trace() {
    val="$1"
    if [ "$val" != "0" ] && [ "$val" != "1" ]; then
        echo "[ERROR] 用法: trace <0|1>"
        return 1
    fi
    node="/sys/module/ged/parameters/ged_log_perf_trace_enable"
    if [ ! -f "$node" ]; then
        echo "[ERROR] 节点不存在: $node（可能不是MTK平台，或该内核版本不支持）"
        return 1
    fi
    write_node "$node" "$val"
}

cmd_usage() {
    echo "可用命令:"
    echo "  info                     - GPU 总览"
    echo "  freq                     - 可用频率/opp dump"
    echo "  gov          <governor>  - 切换GPU governor（仅Qualcomm）"
    echo "  fix-freq     <freq_hz>   - 定频"
    echo "  unfix-freq               - 解除定频"
    echo "  cap          <freq_hz>   - 限制最大频率"
    echo "  uncap                    - 解除最大频率限制"
    echo "  busy                     - GPU占用率/idle率"
    echo "  power                    - 频点档位信息"
    echo "  idle-policy  <policy>    - 设置Mali kbase power_policy"
    echo "  trace        <0|1>       - GED perf trace开关（仅MTK）"
}

# ============================================================
# ACTION 分发：只做路由，全部转发给上面的 cmd_xxx 函数
# ============================================================

[ -n "$ACTION" ] && resolve_gpu

case "$ACTION" in
    info)         cmd_info ;;
    freq)         cmd_freq ;;
    gov)          cmd_gov "$PARAM1" ;;
    fix-freq)     cmd_fix_freq "$PARAM1" ;;
    unfix-freq)   cmd_unfix_freq ;;
    cap)          cmd_cap "$PARAM1" ;;
    uncap)        cmd_uncap ;;
    busy)         cmd_busy ;;
    power)        cmd_power ;;
    idle-policy)  cmd_idle_policy "$PARAM1" ;;
    trace)        cmd_trace "$PARAM1" ;;
    *)
        echo "[ERROR] 未知命令: $ACTION"
        echo ""
        cmd_usage
        exit 1
        ;;
esac

exit 0