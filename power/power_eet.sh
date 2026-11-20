#!/system/bin/sh
# ==================================================================
# power_eet.sh
# 功能：针对指定 cpufreq policy，关闭 thermal、加唤醒锁、隔离 CPU、
#       设置 performance governor 并锁定到指定固定频点
# 用法：adb shell "sh -s <policy> <freq>" < power_eet.sh
# ==================================================================

POLICY="$1"
FREQ="$2"
DEF_GOVERNOR="${3:-sugov_ext}"

CPUFREQ_DIR="/sys/devices/system/cpu/cpufreq"
POLICY_DIR="${CPUFREQ_DIR}/policy${POLICY}"
CPU_ONLINE_BASE="/sys/devices/system/cpu"

log() {
    echo "[INFO] $*"
}

err() {
    echo "[ERROR] $*" 1>&2
}

die() {
    err "$*"
    exit 1
}

usage() {
    echo ""
    echo "用法: power eet <policy> <freq>"
    echo ""
    for policy_path in ${CPUFREQ_DIR}/policy[0-9]*; do
        p_num=$(basename "$policy_path")
        p_num=${p_num#policy}
        case "$p_num" in *[!0-9]*) continue ;; esac
        freqs=$(cat "${policy_path}/scaling_available_frequencies" 2>/dev/null)
        echo "policy${p_num}: ${freqs:-<无可读取的频点>}"
    done
    echo ""
    echo "示例: power eet 0 650000"
    echo ""
    exit 1
}

# ---------- 通用可复用函数 ----------

# write_sysfs <path> <value> <描述>
# 所有 sysfs 写入操作的唯一入口，统一做存在性检查和结果打印
write_sysfs() {
    path="$1"
    value="$2"
    desc="$3"

    if [ ! -e "$path" ]; then
        err "节点不存在，跳过: $path ($desc)"
        return 1
    fi

    if ! echo "$value" > "$path" 2>/dev/null; then
        err "写入失败: $path <- $value ($desc)"
        return 1
    fi

    log "$desc -> $value ($path)"
    return 0
}

# set_cpu_online <cpu_num> <0|1>
set_cpu_online() {
    cpu_num="$1"
    val="$2"
    online_path="${CPU_ONLINE_BASE}/cpu${cpu_num}/online"
    # cpu0 通常没有 online 节点（不可下线），write_sysfs 内部会自动跳过并打印提示
    write_sysfs "$online_path" "$val" "cpu${cpu_num} online=${val}"
}

set_governor() {
    policy_path="$1"
    governor_name="$2"
    desc="$3"
    gov_path="${policy_path}/scaling_governor"
    avail_gov_path="${policy_path}/scaling_available_governors"

    if [ ! -e "$gov_path" ]; then
        err "governor节点不存在，跳过: $gov_path ($desc)——通常是该policy下CPU已全部offline"
        return 1
    fi

    if [ -f "$avail_gov_path" ]; then
        supported=0
        for g in $(cat "$avail_gov_path"); do
            [ "$g" = "$governor_name" ] && supported=1 && break
        done
        if [ "$supported" != "1" ]; then
            err "governor不支持: '$governor_name' 不在 $avail_gov_path 列表里 [$(cat "$avail_gov_path")]，跳过 ($desc)"
            return 1
        fi
    fi

    write_sysfs "$gov_path" "$governor_name" "$desc"
}

reset() {
    log "===== 现场恢复: 所有CPU online ====="
    for cpu_path in ${CPU_ONLINE_BASE}/cpu[0-9]*; do
        cpu_name=$(basename "$cpu_path")
        cpu_num=${cpu_name#cpu}
        case "$cpu_num" in *[!0-9]*) continue ;; esac
        set_cpu_online "$cpu_num" "1"
    done

    log "===== 现场恢复: 恢复所有policy governor 默认为${DEF_GOVERNOR} ====="
    for policy_path in ${CPUFREQ_DIR}/policy[0-9]*; do
        p_name=$(basename "$policy_path")
        p_num=${p_name#policy}
        case "$p_num" in *[!0-9]*) continue ;; esac
        set_governor "$policy_path" "$DEF_GOVERNOR" "policy${p_num} 恢复governor"
    done
}

# ---------- 前置校验 ----------

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        die "此操作需要 root 权限，请在执行前运行 'adb root'"
    fi
}

# 检查 dhrystone 是否在运行 (perf ds start 后才会有 dhrystone.elf 进程)
check_dhrystone() {
    PID=$(ps -ef 2>/dev/null | grep -F "dhrystone.elf" | grep -v grep | awk '{print $2}')
    if [ -z "$PID" ]; then
        die "dhrystone 未运行, 请先运行 dhrystone (perf ds start)"
    fi
    log "检测到 dhrystone 进程: $PID"
}

# 参数解析与校验
parse_args() {
    case "$POLICY" in
        -h|--help|help|usage) usage ;;
    esac

    if [ -z "$POLICY" ] || [ -z "$FREQ" ]; then
        err "缺少必要的参数"
        usage
    fi

    # 这里限制 POLICY 只能是数字
    case "$POLICY" in
        ''|*[!0-9]*) die "policy 参数非法: '$POLICY'，必须为非负整数" ;;
    esac

    [ -d "$POLICY_DIR" ] || die "policy 目录不存在: $POLICY_DIR，请确认 policy 编号是否正确"

    # freq 的合法性完全以 scaling_available_frequencies 的真实内容为准
    AVAIL_FILE="${POLICY_DIR}/scaling_available_frequencies"
    [ -f "$AVAIL_FILE" ] || die "未找到 $AVAIL_FILE，无法校验 freq 是否合法，终止执行"

    AVAIL_FREQS=$(cat "$AVAIL_FILE")
    echo policy $POLICY的可用频点为 $AVAIL_FREQS
    FOUND=0
    for f in $AVAIL_FREQS; do
        [ "$f" = "$FREQ" ] && FOUND=1 && break
    done
    [ "$FOUND" = "1" ] || die "freq(${FREQ}) 不在 policy${POLICY} 可用频点列表中: [$AVAIL_FREQS]"

    log "参数校验通过：policy=${POLICY} freq=${FREQ}"
}

# ---------- 主流程 ----------

# 检测芯片平台 (参考 perf_cpu.sh do_platform)
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

# 关闭 thermal 相关服务 (按平台区分操作)
do_thermal_off() {
    log "===== 步骤1: 关闭 thermal 相关服务 ====="
    PLATFORM=$(detect_platform)
    log "当前平台: $PLATFORM"

    case "$PLATFORM" in
        MTK)
            /vendor/bin/thermal_intf apply disable_thermal.conf 2>/dev/null
            log "mtk平台: thermal 服务关闭指令已下发"
            ;;
        Qualcomm)
            stop thermal-engine-v2
            log "qcom平台: thermal-engine-v2 已停止"
            ;;
        *)
            err "不支持的平台: $PLATFORM, 无法关闭 thermal"
            usage
            ;;
    esac
}

# 设置唤醒锁
do_wakelock() {
    log "===== 步骤2: 设置唤醒锁 ====="
    write_sysfs "/sys/power/wake_lock" "temporary" "设置 wakelock"
}

# CPU隔离：只保留 cpu${POLICY} 在线
do_isolate_cpu() {
    log "===== 步骤3: CPU隔离（仅保留 cpu${POLICY} 在线）====="

    for cpu_path in ${CPU_ONLINE_BASE}/cpu[0-9]*; do
        cpu_name=$(basename "$cpu_path")
        cpu_num=${cpu_name#cpu}
        case "$cpu_num" in *[!0-9]*) continue ;; esac

        if [ "$cpu_num" = "$POLICY" ]; then
            set_cpu_online "$cpu_num" "1"
        else
            set_cpu_online "$cpu_num" "0"
        fi
    done
}

# 设置governor为performance
do_governor_perf() {
    log "===== 步骤4: 设置 scaling_governor=performance ====="

    for policy_path in ${CPUFREQ_DIR}/policy[0-9]*; do
        p_name=$(basename "$policy_path")
        p_num=${p_name#policy}
        case "$p_num" in *[!0-9]*) continue ;; esac

        if [ "$p_num" = "$POLICY" ]; then
            write_sysfs "${policy_path}/scaling_governor" "performance" "policy${p_num} 设置governor"
        fi
    done
}

# 固定频点：写入max/min (先提 max 再压 min，避免中间态 min > max 被内核拒绝)
do_pin_freq() {
    log "===== 步骤5: 固定频点为 ${FREQ} ====="
    write_sysfs "${POLICY_DIR}/scaling_max_freq" "$FREQ" "设置最大频率"
    write_sysfs "${POLICY_DIR}/scaling_min_freq" "$FREQ" "设置最小频率"
}

# 结果回显，便于 bat 端展示
show_result() {
    log "===== 全部步骤执行完成: policy${POLICY} 已固定在 ${FREQ} ====="
    echo "----- 当前状态 -----"
    echo "governor: $(cat ${POLICY_DIR}/scaling_governor 2>/dev/null)"
    echo "cur_freq: $(cat ${POLICY_DIR}/scaling_cur_freq 2>/dev/null)"
    echo "min_freq: $(cat ${POLICY_DIR}/scaling_min_freq 2>/dev/null)"
    echo "max_freq: $(cat ${POLICY_DIR}/scaling_max_freq 2>/dev/null)"
}

# 命令路由分发
route() {
    # 0. 重置cpu online状态和governor值
    reset
    # 1. 关闭 thermal
    do_thermal_off
    # 2. 设置唤醒锁
    do_wakelock
    # 3. 隔离CPU
    do_isolate_cpu
    # 4. 设置governor为performance
    do_governor_perf
    # 5. 固定频点
    do_pin_freq
    # 6. 结果回显
    show_result
}

main() {
    # 1. 前置校验 (root / 参数 / dhrystone 运行状态)
    check_root
    parse_args "$@"
    check_dhrystone

    # 2. 命令路由分发
    route
}

main "$@"
exit 0
