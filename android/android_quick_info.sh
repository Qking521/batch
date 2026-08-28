#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-08-28
# Desc:   Android 原始调试命令与日志分析关键字速查字典 (Quick Info Cheat Sheet)
# Usage:  sh android_quick_info.sh <module>
#
# Modules:
#   log    - 常见 Logcat / dmesg 关键字与过滤表达式
#   therm  - Thermal Zone NTC 温度查询原始命令、Cooling Devices 与温升分析关键字
#   perf   - CPU 在线状态/实时频率/调频器/负载原始命令与性能分析关键字
#   power  - 电池状态/内核持锁/唤醒源原始命令与功耗休眠分析关键字
#   sys    - 前台焦点/屏幕状态原始命令与通用系统事件关键字
#   all    - 完整输出所有模块的原始命令与关键字
# ============================================================

MODULE="$1"

# ============================================================
# 1. LOG 模块: 日志分析关键字与正则过滤表达式
# ============================================================
show_log_info() {
    cat <<'EOF'
# ============================================================
# [LOG 模块] Logcat / Dmesg 日志分析关键字
# ============================================================

# 1. 查看唤醒锁和唤醒原因 (内核锁、应用 Partial 锁、屏幕点亮原因)
All kernel wake locks|All partial wake locks|All wakeup reasons|All screen wake reasons

# 2. 查看系统待机及唤醒 (进出 suspend 时间点、唤醒中断/Alarm 来源)
suspend entry|suspend exit|suspend wake up by|Resume caused by|caused by IRQ|set alarm :

# 3. 系统无法 suspend (休眠失败、被持锁源打断或阻止 suspend)
Pending Wakeup Sources|Wake lock|blocked by|prevent_suspend_time|PM: suspend returned|aborting suspend|active wakeup source

# 4. 系统 suspend 但子系统仍在工作 (AP 待机时 26M 时钟及子系统睡眠比率)
26M_off_pct|AP suspend ratio

# 5. 温升分析 (温升触发事件、thermal-engine 限频、温控策略执行)
DexOptimizer|ThermalInfo:|thermal_core|thermal IRQ|throttling|mmi_thermal_ratio|Apply thermal policy:|libPowerHal:

# 6. 系统异常与稳定性 (Java Exception、Native Crash、ANR 无响应、Tombstone)
FATAL EXCEPTION|ANR in|CRASH:|backtrace:|Build fingerprint:|Tombstone

# 7. 性能与掉帧卡顿 (主线程耗时、Choreographer 丢帧、慢 Handler 消息)
Skipped [0-9]+ frames|Choreographer|Slow Looper|Slow delivery:|Slow dispatch:|am_anr

# 8. 其它未分类 (屏幕开关事件、关机重启属性、对齐唤醒、传感器常驻)
screen_toggled|sys.powerctl|AlarmManager: Adjust deliver|sensorservice
EOF
}

# ============================================================
# 2. THERM 模块: Thermal Zone NTC 温度查询原始命令 + 温升关键字
# ============================================================
show_therm_info() {
    cat <<'EOF'
# ============================================================
# [THERM 模块] Thermal Zone 温度与冷却设备原始命令
# ============================================================

# 1. 查看 NTC 温度 (遍历所有 Thermal Zone)
adb shell "i=0 ; while [[ $i -lt 80 ]] ; do (type=`cat /sys/class/thermal/thermal_zone$i/type` ; temp=`cat /sys/class/thermal/thermal_zone$i/temp` ; echo \"$i $type : $temp\"); i=$((i+1));done"

# 2. 查看所有 Thermal Zone 类型与实时温度
adb shell "for tz in /sys/class/thermal/thermal_zone*; do echo \"$(basename $tz): $(cat $tz/type 2>/dev/null) = $(cat $tz/temp 2>/dev/null) mC\"; done"

# 3. 查看冷却设备状态 (Cooling Devices 档位与最大值)
adb shell "for cd in /sys/class/thermal/cooling_device*; do echo \"$(basename $cd): $(cat $cd/type 2>/dev/null) = cur:$(cat $cd/cur_state 2>/dev/null) / max:$(cat $cd/max_state 2>/dev/null)\"; done"

# 4. 温升分析关键字 (温升触发事件、thermal-engine 限频、温控策略执行)
DexOptimizer|ThermalInfo:|thermal_core|thermal IRQ|throttling|mmi_thermal_ratio|Apply thermal policy:|libPowerHal:
EOF
}

# ============================================================
# 3. PERF 模块: CPU 性能调控原始命令 + 性能关键字
# ============================================================
show_perf_info() {
    cat <<'EOF'
# ============================================================
# [PERF 模块] CPU 性能状态与调控原始命令
# ============================================================

# 1. 查看 CPU 在线核心状态
adb shell "cat /sys/devices/system/cpu/online"

# 2. 查看各 CPU 核心当前实时频率 (KHz)
adb shell "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"

# 3. 查看各 CPU Policy 调频器与核心分布
adb shell "for p in /sys/devices/system/cpu/cpufreq/policy*; do echo \"$(basename $p) cpus:[$(cat $p/affected_cpus 2>/dev/null)] cur:$(cat $p/scaling_cur_freq 2>/dev/null) gov:$(cat $p/scaling_governor 2>/dev/null)\"; done"

# 4. 查看 Policy0 可用频率列表
adb shell "cat /sys/devices/system/cpu/cpufreq/policy0/scaling_available_frequencies"

# 5. 查看系统平均负载 (Load Average)
adb shell "cat /proc/loadavg"

# 6. 查看 CPU 占用 Top 10 进程
adb shell "top -n 1 -m 10"

# 7. 性能与掉帧分析关键字 (丢帧、慢消息、ANR)
Skipped [0-9]+ frames|Choreographer|Slow Looper|Slow delivery:|Slow dispatch:|am_anr|am_crash
EOF
}

# ============================================================
# 4. POWER 模块: 电源与休眠待机原始命令 + 功耗关键字
# ============================================================
show_power_info() {
    cat <<'EOF'
# ============================================================
# [POWER 模块] 电源、电池与休眠待机原始命令
# ============================================================

# 1. 查看电池状态 (电量/温度/电压/充电状态)
adb shell "dumpsys battery"

# 2. 查看内核活动持锁 (Active Kernel Wake Locks)
adb shell "cat /sys/power/wake_lock"

# 3. 查看唤醒源统计 (Wakeup Sources)
adb shell "cat /sys/kernel/debug/wakeup_sources"

# 4. 查看框架层持锁 (Framework Wake Locks)
adb shell "dumpsys power | grep -A 20 'Wake Locks'"

# 5. 查看唤醒锁和唤醒原因关键字
All kernel wake locks|All partial wake locks|All wakeup reasons|All screen wake reasons

# 6. 查看系统无法休眠关键字 (休眠失败、被持锁源打断或阻止)
Pending Wakeup Sources|Wake lock|blocked by|prevent_suspend_time|PM: suspend returned|aborting suspend|active wakeup source

# 7. 查看系统待机及唤醒关键字 (进出 suspend 时间点、唤醒中断/Alarm 来源)
suspend entry|suspend exit|suspend wake up by|Resume caused by|caused by IRQ|set alarm :

# 8. 系统 suspend 但子系统仍在工作关键字
26M_off_pct|AP suspend ratio
EOF
}

# ============================================================
# 5. SYS 模块: 系统状态原始命令 + 通用事件关键字
# ============================================================
show_sys_info() {
    cat <<'EOF'
# ============================================================
# [SYS 模块] 系统状态原始命令与通用事件关键字
# ============================================================

# 1. 查看当前前台 Activity 焦点
adb shell "dumpsys window | grep mCurrentFocus"

# 2. 查看屏幕显示状态 (Display State)
adb shell "dumpsys display | grep mScreenState"

# 3. 查看电源休眠状态 (Wakefulness)
adb shell "dumpsys power | grep 'mWakefulness='"

# 4. 其它未分类通用系统日志关键字 (屏幕开关、关机重启属性、Alarm 调控、传感器)
screen_toggled|sys.powerctl|AlarmManager: Adjust deliver|sensorservice
EOF
}

# ============================================================
# 帮助信息
# ============================================================
usage() {
    cat <<'EOF'
============================================================
 Android 原始调试命令与日志分析关键字速查字典 (Quick Info)
============================================================
用法: ad qs <模块> 或 sh android_quick_info.sh <模块>

可用模块:
  log    - Logcat / dmesg 日志分析关键字分类汇总 (休眠/唤醒/温升/Crash等正则)
  therm  - Thermal Zone NTC 温度查询原始命令、Cooling Devices 与温升关键字
  perf   - CPU 频率/核心状态/负载/调频器原始命令与性能分析关键字
  power  - 电池状态/内核持锁/唤醒源原始命令与功耗休眠分析关键字
  sys    - 前台焦点/屏幕状态原始命令与未分类通用事件关键字
  all    - 完整输出所有模块的原始命令与关键字
  help   - 显示此帮助信息

示例:
  ad qs log
  ad qs therm
  ad qs perf
  ad qs all
EOF
    exit 0
}

# ============================================================
# 路由分发 (保持单行紧凑)
# ============================================================
case "$MODULE" in
    log|logs)         show_log_info ;;
    therm|thermal|tz) show_therm_info ;;
    perf|cpu)         show_perf_info ;;
    power|pwr|bat)    show_power_info ;;
    sys|system|other) show_sys_info ;;
    all|"")           show_log_info; echo ""; show_therm_info; echo ""; show_perf_info; echo ""; show_power_info; echo ""; show_sys_info ;;
    -h|--help|help)   usage ;;
    *)                echo "[ERROR] 未知模块: $MODULE"; echo ""; usage ;;
esac

exit 0
