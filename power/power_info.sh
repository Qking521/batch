#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date: 2026-08-07
# Desc: Android 功耗相关设备与状态信息采集业务层脚本
# Usage: adb shell "sh -s" < power_info.sh
# ============================================================

log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" 1>&2; }
log_err()  { echo "[ERROR] $*" 1>&2; }

# 获取系统 Property 封装函数
get_prop_or_unk() {
    local prop="$1"
    local val="$(getprop "$prop" 2>/dev/null)"
    if [ -z "$val" ]; then
        echo "UNKNOWN"
    else
        echo "$val"
    fi
}

# 1. 硬件与 Platform 标识信息（功耗芯片及单板环境）
get_hardware_info() {
    log_info "=== 硬件与平台环境 ==="
    echo "  品牌/厂商:      $(get_prop_or_unk ro.product.brand) / $(get_prop_or_unk ro.product.manufacturer)"
    echo "  设备型号:        $(get_prop_or_unk ro.product.model)"
    echo "  内部代号 (Device):$(get_prop_or_unk ro.product.device)"
    echo "  主板/芯片:      $(get_prop_or_unk ro.product.board)"
    echo "  SoC 型号:       $(get_prop_or_unk ro.vendor.soc.model.external_name)"
    echo "  SKU:           $(get_prop_or_unk ro.boot.hardware.sku)"
    echo "  序列号 (SN):    $(get_prop_or_unk ro.serialno)"
    echo "  Build ID:      $(get_prop_or_unk ro.build.id)"
}

# 2. CPU / GPU 架构与调频配置 (功耗主要消耗源)
get_cpu_gpu_info() {
    log_info "=== CPU / GPU 架构与调频 ==="
    local abi=$(get_prop_or_unk ro.product.cpu.abi)
    
    local cpu_cores=0
    if [ -d /sys/devices/system/cpu ]; then
        cpu_cores=$(ls -d /sys/devices/system/cpu/cpu[0-9]* 2>/dev/null | wc -l | tr -d ' ')
    fi
    [ "$cpu_cores" -eq 0 ] && cpu_cores="UNKNOWN"

    # CPU 簇/政策分层
    local cpu_layout="UNKNOWN"
    if [ -d /sys/devices/system/cpu/cpufreq ]; then
        cpu_layout=$(ls -d /sys/devices/system/cpu/cpufreq/policy* 2>/dev/null | while read -r p; do
            if [ -f "$p/related_cpus" ]; then
                wc -w < "$p/related_cpus" | tr -d ' '
            fi
        done | xargs | sed 's/ /+/g')
    fi
    [ -z "$cpu_layout" ] && cpu_layout="UNKNOWN"

    # CPU Governor (默认取 cpu0)
    local governor="UNKNOWN"
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    fi

    # GPU 信息
    local gpu_info="UNKNOWN"
    local sf_gles=$(dumpsys SurfaceFlinger 2>/dev/null | grep "^GLES:" | head -n 1 | cut -d',' -f2 | sed 's/^[ ]*//')
    if [ -n "$sf_gles" ]; then
        gpu_info="$sf_gles"
    fi

    echo "  CPU 架构 (ABI): ${abi}"
    echo "  核心布局:      ${cpu_cores} 核 (簇分布: ${cpu_layout})"
    echo "  CPU 调频模式:  ${governor}"
    echo "  GPU 信息:      ${gpu_info}"
}

# 3. 屏幕显示与亮度 (显示功耗)
get_display_info() {
    log_info "=== 显示与屏幕功耗参数 ==="
    local wm_size=$(wm size 2>/dev/null | awk -F': ' '{print $2}')
    local refresh_rate=$(dumpsys SurfaceFlinger 2>/dev/null | grep -oE "vsyncRate=[0-9.]+" | head -n 1 | cut -d'=' -f2)
    [ -z "$refresh_rate" ] && refresh_rate=$(dumpsys SurfaceFlinger 2>/dev/null | grep -i "refresh-rate" | head -n 1 | awk -F': ' '{print $2}')

    local brightness=$(settings get system screen_brightness 2>/dev/null)
    local bri_mode=$(settings get system screen_brightness_mode 2>/dev/null)

    local mode_str="UNKNOWN"
    case "$bri_mode" in
        0) mode_str="0 (Manual / 手动)" ;;
        1) mode_str="1 (Automatic / 自动)" ;;
    esac

    echo "  屏幕分辨率:    ${wm_size:-UNKNOWN}"
    echo "  屏幕刷新率:    ${refresh_rate:-UNKNOWN} Hz"
    echo "  当前屏幕亮度:  ${brightness:-UNKNOWN}"
    echo "  亮度调节模式:  ${mode_str}"
}

# 4. 内存与存储规格 (内存功耗与基准)
get_memory_info() {
    log_info "=== 内存与存储规格 ==="
    local mem_gb="UNKNOWN"
    if [ -f /proc/meminfo ]; then
        local mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null)
        if [ -n "$mem_kb" ]; then
            mem_gb=$(( (mem_kb + 1048576 - 1) / 1048576 ))
        fi
    fi

    local rom_size="UNKNOWN"
    local total_kb=$(df /data 2>/dev/null | awk 'NR>1 {print $2}' | grep -E '^[0-9]+$' | head -n 1)
    if [ -z "$total_kb" ]; then
        local disk_line=$(dumpsys diskstats 2>/dev/null | grep -i "Data-Free")
        if [ -n "$disk_line" ]; then
            total_kb=$(echo "$disk_line" | awk '{print $2}' | cut -d'/' -f2 | sed 's/K//i' | grep -E '^[0-9]+$')
        fi
    fi

    if [ -n "$total_kb" ]; then
        local total_gb=$(( total_kb / 1000000 ))
        for s in 16 32 64 128 256 512 1024 2048; do
            if [ "$total_gb" -le "$s" ]; then
                rom_size="$s"
                break
            fi
        done
    fi

    echo "  RAM 规格:      ${mem_gb} GB"
    echo "  ROM 规格:      ${rom_size} GB"
}

# 5. 电池状态与实时功率指标 (核心 Power 指标)
get_battery_power_info() {
    log_info "=== 电池状态与实时功率 ==="
    local batt_dump=$(dumpsys battery 2>/dev/null)
    if [ -n "$batt_dump" ]; then
        local level=$(echo "$batt_dump" | grep "  level:" | awk '{print $2}' | tr -d '\r\n')
        local temp_raw=$(echo "$batt_dump" | grep "  temperature:" | awk '{print $2}' | tr -d '\r\n')
        local status_code=$(echo "$batt_dump" | grep "  status:" | awk '{print $2}' | tr -d '\r\n')
        local health_code=$(echo "$batt_dump" | grep "  health:" | awk '{print $2}' | tr -d '\r\n')
        local volt_mv=$(echo "$batt_dump" | grep "  voltage:" | awk '{print $2}' | tr -d '\r\n')
        local curr_raw=$(echo "$batt_dump" | grep -Ei "current now|currentnow" | head -n 1 | awk '{print $NF}' | tr -d '\r\n')
        local counter_raw=$(echo "$batt_dump" | grep -Ei "charge counter|chargecounter" | head -n 1 | awk '{print $NF}' | tr -d '\r\n')

        # 电池温度 (0.1°C -> °C)
        local temp_c="UNKNOWN"
        if [ -n "$temp_raw" ]; then
            temp_c="$(( temp_raw / 10 )).$(( temp_raw % 10 )) °C"
        fi

        # 状态解惑
        local status_str="UNKNOWN"
        case "$status_code" in
            1) status_str="Unknown (未知)" ;;
            2) status_str="Charging (充电中)" ;;
            3) status_str="Discharging (放电中)" ;;
            4) status_str="Not charging (未充电)" ;;
            5) status_str="Full (已充满)" ;;
        esac

        local health_str="UNKNOWN"
        case "$health_code" in
            1) health_str="Unknown (未知)" ;;
            2) health_str="Good (良好)" ;;
            3) health_str="Overheat (过热)" ;;
            4) health_str="Dead (损坏)" ;;
            5) health_str="Over voltage (过压)" ;;
            6) health_str="Unspecified failure (未指定故障)" ;;
            7) health_str="Cold (过冷)" ;;
        esac

        # 电流 (uA -> mA)
        local curr_ma=0
        if [ -n "$curr_raw" ]; then
            curr_ma=$(( curr_raw / 1000 ))
        fi

        # 累计已充/放电量 (uAh -> mAh)
        local batt_mah=0
        if [ -n "$counter_raw" ]; then
            batt_mah=$(( counter_raw / 1000 ))
        fi

        # 实时功率计算 (W = (mV * mA) / 1,000,000)
        local power_w="UNKNOWN"
        if [ -n "$volt_mv" ] && [ "$curr_ma" -ne 0 ]; then
            local mw_val=$(( (volt_mv * curr_ma) / 1000 ))
            local p_sign=""
            if [ "$mw_val" -lt 0 ]; then
                p_sign="-"
                mw_val=$(( -mw_val ))
            fi
            local p_main=$(( mw_val / 1000 ))
            local p_rem=$(( mw_val % 1000 ))
            local p_dec=$(printf "%03d" "$p_rem" | cut -c1-2)
            power_w="${p_sign}${p_main}.${p_dec} W"
        fi

        echo "  电量百分比:    ${level:-UNKNOWN}%"
        echo "  当前电量计数:  ${batt_mah} mAh"
        echo "  电池温度:      ${temp_c}"
        echo "  电池电压:      ${volt_mv:-UNKNOWN} mV"
        echo "  实时电流:      ${curr_ma} mA"
        echo "  实时功率:      ${power_w}"
        echo "  充电状态:      ${status_str}"
        echo "  电池健康度:    ${health_str}"
    else
        echo "  电池状态:      UNKNOWN"
    fi
}

# 6. 电源管理与待机唤醒状态 (Wake Lock & System Uptime)
get_power_management_info() {
    log_info "=== 电源管理与待机状态 ==="
    # Uptime
    local uptime_sec=$(cat /proc/uptime 2>/dev/null | cut -d' ' -f1 | cut -d'.' -f1)
    local up_min="UNKNOWN"
    if [ -n "$uptime_sec" ]; then
        up_min=$(( uptime_sec / 60 ))
    fi

    # Wake Lock 状态汇总
    local wl_raw=$(dumpsys power 2>/dev/null | grep "mWakeLockSummary=" | head -n 1 | cut -d'=' -f2 | awk '{print $1}')
    local wl_str="${wl_raw:-UNKNOWN}"
    case "$wl_raw" in
        "0x0")  wl_str="0x0 (None / 无持锁)" ;;
        "0x1")  wl_str="0x1 (PARTIAL / 局部唤醒锁)" ;;
        "0x2")  wl_str="0x2 (OTHER / 界面持锁)" ;;
        "0x40") wl_str="0x40 (DOZE / 低功耗休眠锁)" ;;
    esac

    echo "  系统运行时间:  ${up_min} 分钟 (${uptime_sec:-UNKNOWN} 秒)"
    echo "  WakeLock 状态: ${wl_str}"
}

show_all_power_info() {
    echo "============================================================"
    echo "             Android 功耗相关设备信息 (Power Info)"
    echo "============================================================"
    get_hardware_info
    echo ""
    get_cpu_gpu_info
    echo ""
    get_display_info
    echo ""
    get_memory_info
    echo ""
    get_battery_power_info
    echo ""
    get_power_management_info
    echo "============================================================"
}

main() {
    show_all_power_info
}

main "$@"
