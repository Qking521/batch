#!/system/bin/sh
# ============================================================
# Author: Antigravity Pair Program
# Date: 2026-08-06
# Desc: Android 设备信息采集业务层脚本
# Usage: adb shell "sh -s" < android_device_info.sh
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

# 1. 基础硬件与平台信息
get_hardware_info() {
    log_info "=== 硬件与平台信息 ==="
    echo "  品牌/厂商:      $(get_prop_or_unk ro.product.brand) / $(get_prop_or_unk ro.product.manufacturer)"
    echo "  设备型号:        $(get_prop_or_unk ro.product.model)"
    echo "  内部代号 (Device):$(get_prop_or_unk ro.product.device)"
    echo "  主板/芯片:      $(get_prop_or_unk ro.product.board)"
    echo "  SoC 型号:       $(get_prop_or_unk ro.vendor.soc.model.external_name)"
    echo "  SKU:           $(get_prop_or_unk ro.boot.hardware.sku)"
    echo "  序列号 (SN):    $(get_prop_or_unk ro.serialno)"
}

# 2. CPU / SoC 架构与核心信息
get_cpu_info() {
    log_info "=== CPU / SoC 详细信息 ==="
    local abi=$(get_prop_or_unk ro.product.cpu.abi)
    local cpu_cores=0
    if [ -d /sys/devices/system/cpu ]; then
        cpu_cores=$(ls -d /sys/devices/system/cpu/cpu[0-9]* 2>/dev/null | wc -l | tr -d ' ')
    fi
    [ "$cpu_cores" -eq 0 ] && cpu_cores="UNKNOWN"

    local governor="UNKNOWN"
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    fi

    echo "  CPU 架构 (ABI): ${abi}"
    echo "  核心数量:      ${cpu_cores} 核"
    echo "  调频模式:      ${governor}"
}

# 3. 系统版本与 Build 信息
get_system_info() {
    log_info "=== 系统版本信息 ==="
    echo "  Android 版本:  $(get_prop_or_unk ro.build.version.release)"
    echo "  API Level:     $(get_prop_or_unk ro.build.version.sdk)"
    echo "  Build ID:      $(get_prop_or_unk ro.build.id)"
    echo "  Build 描述:    $(get_prop_or_unk ro.build.description)"
    echo "  安全补丁版本:  $(get_prop_or_unk ro.build.version.security_patch)"

    # Mica 项目特有版本信息判断与打印
    local device_name="$(getprop ro.product.device 2>/dev/null)"
    local board_name="$(getprop ro.product.board 2>/dev/null)"
    if [ "$device_name" = "mica" ] || [ "$board_name" = "mica" ]; then
        echo "  [Mica 特有版本信息]"
        local incremental="$(getprop ro.build.version.incremental 2>/dev/null)"
        echo "    Incremental:     ${incremental:-UNKNOWN}"

        local ap_bootloader="$(getprop ro.bootloader 2>/dev/null)"
        echo "    AP (Bootloader): ${ap_bootloader:-UNKNOWN}"

        if command -v ectool >/dev/null 2>&1; then
            local ec_ro="$(ectool version 2>/dev/null | grep 'RO version:' | awk -F': ' '{print $2}' | tr -d '\r\n')"
            local ec_rw="$(ectool version 2>/dev/null | grep 'RW version:' | awk -F': ' '{print $2}' | tr -d '\r\n')"
            echo "    EC RO Version:   ${ec_ro:-UNKNOWN}"
            echo "    EC RW Version:   ${ec_rw:-UNKNOWN}"
        else
            echo "    EC Version:      UNKNOWN (ectool not found)"
        fi
    fi
}

# 4. 内存 (RAM) 信息
get_ram_info() {
    log_info "=== 内存 (RAM) 信息 ==="
    if [ -f /proc/meminfo ]; then
        local mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null)
        local mem_free_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null)
        if [ -n "$mem_kb" ]; then
            local mem_gb=$(( (mem_kb + 1048576 - 1) / 1048576 ))
            if [ -n "$mem_free_kb" ]; then
                local free_mb=$(( mem_free_kb / 1024 ))
                echo "  RAM 总容量:    ${mem_gb} GB (${mem_kb} KB, 可用约 ${free_mb} MB)"
            else
                echo "  RAM 总容量:    ${mem_gb} GB (${mem_kb} KB)"
            fi
        else
            echo "  RAM 总容量:    UNKNOWN"
        fi
    else
        echo "  RAM 总容量:    UNKNOWN"
    fi
}

# 5. 存储 (ROM/Data) 信息
get_rom_info() {
    log_info "=== 存储 (ROM) 信息 ==="
    local total_kb=""

    total_kb=$(df /data 2>/dev/null | awk 'NR>1 {print $2}' | grep -E '^[0-9]+$' | head -n 1)

    if [ -z "$total_kb" ]; then
        local disk_line=$(dumpsys diskstats 2>/dev/null | grep -i "Data-Free")
        if [ -n "$disk_line" ]; then
            total_kb=$(echo "$disk_line" | awk '{print $2}' | cut -d'/' -f2 | sed 's/K//i' | grep -E '^[0-9]+$')
        fi
    fi

    if [ -n "$total_kb" ]; then
        local total_gb=$(( total_kb / 1000000 ))
        local rom_size="UNKNOWN"
        for s in 16 32 64 128 256 512 1024 2048; do
            if [ "$total_gb" -le "$s" ]; then
                rom_size="$s"
                break
            fi
        done
        echo "  ROM 标称规格:  ${rom_size} GB (实际分区: $((total_kb / 1024 / 1024)) GB)"
    else
        echo "  ROM 标称规格:  UNKNOWN"
    fi
}

# 6. 显示与屏幕信息
get_display_info() {
    log_info "=== 显示与屏幕信息 ==="
    local wm_size=$(wm size 2>/dev/null | awk -F': ' '{print $2}')
    local wm_density=$(wm density 2>/dev/null | awk -F': ' '{print $2}')
    local refresh_rate=$(dumpsys SurfaceFlinger 2>/dev/null | grep -i "refresh-rate" | head -n 1 | awk -F': ' '{print $2}')
    local brightness=$(settings get system screen_brightness 2>/dev/null)

    echo "  屏幕分辨率:    ${wm_size:-UNKNOWN}"
    echo "  屏幕 PPI/DPI:  ${wm_density:-UNKNOWN}"
    echo "  当前刷新率:    ${refresh_rate:-UNKNOWN}"
    echo "  当前屏幕亮度:  ${brightness:-UNKNOWN}"
}

# 7. 电池与电源状态
get_battery_info() {
    log_info "=== 电池与电源状态 ==="
    local batt_dump=$(dumpsys battery 2>/dev/null)
    if [ -n "$batt_dump" ]; then
        local level=$(echo "$batt_dump" | grep "  level:" | awk '{print $2}' | tr -d '\r\n')
        local temp_raw=$(echo "$batt_dump" | grep "  temperature:" | awk '{print $2}' | tr -d '\r\n')
        local status_code=$(echo "$batt_dump" | grep "  status:" | awk '{print $2}' | tr -d '\r\n')
        local health_code=$(echo "$batt_dump" | grep "  health:" | awk '{print $2}' | tr -d '\r\n')

        local temp_c="UNKNOWN"
        if [ -n "$temp_raw" ]; then
            temp_c="$(( temp_raw / 10 )).$(( temp_raw % 10 )) C"
        fi

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

        echo "  电量百分比:    ${level:-UNKNOWN}%"
        echo "  电池温度:      ${temp_c}"
        echo "  充电状态:      ${status_str}"
        echo "  电池健康度:    ${health_str}"
    else
        echo "  电池状态:      UNKNOWN"
    fi
}

# 8. 网络与连接状态
get_network_info() {
    log_info "=== 网络与连接状态 ==="
    local wlan_ip=$(ip -4 addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d'/' -f1)
    local wlan_mac=$(ip link show wlan0 2>/dev/null | awk '/link\/ether/ {print $2}')

    echo "  Wi-Fi IP 地址: ${wlan_ip:-未连接/无}"
    echo "  Wi-Fi MAC 地址:${wlan_mac:-UNKNOWN}"
}

# 9. 运行时状态
get_runtime_info() {
    log_info "=== 系统运行时状态 ==="
    local uptime_str=$(uptime 2>/dev/null | sed 's/^[ \t]*//')
    local focus_act=$(dumpsys window 2>/dev/null | grep mCurrentFocus | awk -F'[{}]' '{print $2}')

    echo "  系统运行时间:  ${uptime_str:-UNKNOWN}"
    echo "  当前焦点界面:  ${focus_act:-UNKNOWN}"
}

# 模块扩展注册函数
show_all_info() {
    echo "============================================================"
    echo "             Android 设备信息概览 (Device Info)"
    echo "============================================================"
    get_hardware_info
    echo ""
    get_cpu_info
    echo ""
    get_system_info
    echo ""
    get_ram_info
    echo ""
    get_rom_info
    echo ""
    get_display_info
    echo ""
    get_battery_info
    echo ""
    get_network_info
    echo ""
    get_runtime_info
    echo "============================================================"
}

main() {
    show_all_info
}

main "$@"
