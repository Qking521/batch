#!/system/bin/sh
# ==================================================================
# set_policy.sh
# 功能：针对指定 cpufreq policy，关闭 thermal、加唤醒锁、隔离 CPU、
#       设置 performance governor 并锁定到指定固定频点
# 用法：sh -s <policy> <freq>
#       (通过 adb shell "sh -s" <policy> <freq> < set_policy.sh 调用)
# ==================================================================

POLICY="$1"
FREQ="$2"
DEF_GOVERNOR="${3:-sugov_ext}"

CPUFREQ_DIR="/sys/devices/system/cpu/cpufreq"
POLICY_DIR="${CPUFREQ_DIR}/policy${POLICY}"
CPU_ONLINE_BASE="/sys/devices/system/cpu"

# ---------- 分发: restore 走单独流程，不需要 POLICY/FREQ ----------
ACTION="$1"
if [ "$ACTION" = "restore" ]; then
    restore
    exit 0
fi

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

# 恢复现场：取消唤醒锁、所有CPU online、重启thermal服务。
restore() {
    log "===== 现场恢复: 取消唤醒锁 ====="
    write_sysfs "/sys/power/wake_unlock" "$WAKE_LOCK_NAME" "取消 wakelock"
 
    log "===== 现场恢复: 重启 thermal 相关服务 ====="
    start thermal-engine 2>/dev/null
    start vendor.thermal-engine 2>/dev/null

    reset
 
    log "===== 现场恢复完成 ====="
}
 
reset(){
    log "===== 现场恢复: 所有CPU online ====="
    for cpu_path in ${CPU_ONLINE_BASE}/cpu[0-9]*; do
        cpu_name=$(basename "$cpu_path")
        cpu_num=${cpu_name#cpu}
        case "$cpu_num" in *[!0-9]*) continue ;; esac
        set_cpu_online "$cpu_num" "1"
    done

    log "===== 现场恢复: 恢复所有policy governor 默认为sugov_ext ====="
    for policy_path in ${CPUFREQ_DIR}/policy[0-9]*; do
        p_name=$(basename "$policy_path")
        p_num=${p_name#policy}
        case "$p_num" in *[!0-9]*) continue ;; esac
        set_governor "$policy_path" "$DEF_GOVERNOR" "policy${p_num} 恢复governor"
    done
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
# ---------- 0. 重置cpu online状态和governor值 ----------
reset

# ---------- 参数校验 ----------

# 这里限制 POLICY 只能是数字，目的不是"格式校验"本身
# （因为下面的目录存在性检查一样能拦住 "abc" 这种输入），
# 而是防止 POLICY 里混入 "/" 或 ".." 等字符时，
# 拼接出来的 POLICY_DIR 逃逸到 cpufreq 目录之外，
# 被用来误写其它 sysfs 节点。
case "$POLICY" in
    ''|*[!0-9]*) die "policy 参数非法: '$POLICY'，必须为非负整数" ;;
esac

[ -d "$POLICY_DIR" ] || die "policy 目录不存在: $POLICY_DIR，请确认 policy 编号是否正确"

# freq 的合法性完全以 scaling_available_frequencies 的真实内容为准，
# 不再单独做数字格式判断。如果这个节点都不存在，说明没有可信依据能
# 判断 freq 是否合法，此时直接 die，而不是跳过校验静默放行。
AVAIL_FILE="${POLICY_DIR}/scaling_available_frequencies"
[ -f "$AVAIL_FILE" ] || die "未找到 $AVAIL_FILE，无法校验 freq 是否合法，终止执行"

AVAIL_FREQS=$(cat "$AVAIL_FILE")
FOUND=0
for f in $AVAIL_FREQS; do
    [ "$f" = "$FREQ" ] && FOUND=1 && break
done
[ "$FOUND" = "1" ] || die "freq(${FREQ}) 不在 policy${POLICY} 可用频点列表中: [$AVAIL_FREQS]"

log "参数校验通过：policy=${POLICY} freq=${FREQ}"


# ---------- 1. 关闭 thermal 进程 ----------
log "===== 步骤1: 关闭 thermal 相关服务 ====="
/vendor/bin/thermal_intf apply disable_thermal.conf
log "thermal 服务关闭指令已下发（若服务不存在会被忽略）"

# ---------- 2. 设置唤醒锁 ----------
log "===== 步骤2: 设置唤醒锁 ====="
write_sysfs "/sys/power/wake_lock" "temporary" "设置 wakelock"

# ---------- 3. 隔离CPU：只保留 cpu${POLICY} 在线 ----------
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

# ---------- 4. 设置governor为performance ----------
log "===== 步骤4: 设置 scaling_governor=performance ====="
 
for policy_path in ${CPUFREQ_DIR}/policy[0-9]*; do
    p_name=$(basename "$policy_path")
    p_num=${p_name#policy}
    case "$p_num" in *[!0-9]*) continue ;; esac
 
    if [ "$p_num" = "$POLICY" ]; then
        write_sysfs "${policy_path}/scaling_governor" "performance" "policy${p_num} 设置governor"
    fi
done

# ---------- 5. 固定频点：写入max/min ----------
log "===== 步骤5: 固定频点为 ${FREQ} ====="
# 先提 max 再压 min，避免中间态 min > max 被内核拒绝
write_sysfs "${POLICY_DIR}/scaling_max_freq" "$FREQ" "设置最大频率"
write_sysfs "${POLICY_DIR}/scaling_min_freq" "$FREQ" "设置最小频率"

log "===== 全部步骤执行完成: policy${POLICY} 已固定在 ${FREQ} ====="

# ---------- 结果回显，便于 bat 端展示 ----------
echo "----- 当前状态 -----"
echo "governor: $(cat ${POLICY_DIR}/scaling_governor 2>/dev/null)"
echo "cur_freq: $(cat ${POLICY_DIR}/scaling_cur_freq 2>/dev/null)"
echo "min_freq: $(cat ${POLICY_DIR}/scaling_min_freq 2>/dev/null)"
echo "max_freq: $(cat ${POLICY_DIR}/scaling_max_freq 2>/dev/null)"

exit 0