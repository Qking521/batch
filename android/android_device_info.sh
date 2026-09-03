#!/system/bin/sh
# ============================================================
# Author: WangQiang
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
    echo "  Build 日期:    $(get_prop_or_unk ro.build.date)"
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

    # UFS / eMMC 硬件芯片信息提取
    local ufs_dev="/sys/block/sda/device"
    if [ -d "$ufs_dev" ]; then
        local ufs_ctrl=""
        if [ -d "$ufs_dev/../.." ] && ls "$ufs_dev/../.." 2>/dev/null | grep -q -E "ufshcd|gear|spec_version"; then
            ufs_ctrl="$(cd "$ufs_dev/../.." 2>/dev/null && pwd)"
        elif [ -d "$ufs_dev/../../.." ] && ls "$ufs_dev/../../.." 2>/dev/null | grep -q -E "ufshcd|gear|spec_version"; then
            ufs_ctrl="$(cd "$ufs_dev/../../.." 2>/dev/null && pwd)"
        fi
        if [ -z "$ufs_ctrl" ]; then
            ufs_ctrl=$(ls -d /sys/devices/platform/soc/*ufshcd* /sys/devices/platform/*ufshcd* 2>/dev/null | head -n 1)
        fi

        local ufs_vendor="$(cat "$ufs_dev/vendor" 2>/dev/null | sed 's/^[ \t]*//;s/[ \t]*$//')"
        local ufs_model="$(cat "$ufs_dev/model" 2>/dev/null | sed 's/^[ \t]*//;s/[ \t]*$//')"
        local ufs_rev="$(cat "$ufs_dev/rev" 2>/dev/null | sed 's/^[ \t]*//;s/[ \t]*$//')"

        local spec_raw=""
        if [ -f "$ufs_ctrl/spec_version" ]; then
            spec_raw=$(cat "$ufs_ctrl/spec_version" 2>/dev/null)
        elif [ -f "$ufs_dev/spec_version" ]; then
            spec_raw=$(cat "$ufs_dev/spec_version" 2>/dev/null)
        elif [ -f "$ufs_ctrl/dump_device_desc" ]; then
            spec_raw=$(grep -i "bSpecVersion" "$ufs_ctrl/dump_device_desc" 2>/dev/null | awk '{print $NF}')
        elif [ -f "$ufs_dev/dump_device_desc" ]; then
            spec_raw=$(grep -i "bSpecVersion" "$ufs_dev/dump_device_desc" 2>/dev/null | awk '{print $NF}')
        fi

        local ufs_spec="UNKNOWN"
        case "$spec_raw" in
            *0400*|*4.0*) ufs_spec="UFS 4.0 (${spec_raw})" ;;
            *0310*|*3.1*) ufs_spec="UFS 3.1 (${spec_raw})" ;;
            *0300*|*3.0*) ufs_spec="UFS 3.0 (${spec_raw})" ;;
            *0220*|*2.2*) ufs_spec="UFS 2.2 (${spec_raw})" ;;
            *0210*|*2.1*) ufs_spec="UFS 2.1 (${spec_raw})" ;;
            *0200*|*2.0*) ufs_spec="UFS 2.0 (${spec_raw})" ;;
            "")
                if [ -n "$ufs_vendor" ] || [ -n "$ufs_model" ]; then
                    ufs_spec="UFS"
                fi
                ;;
            *) ufs_spec="${spec_raw}" ;;
        esac

        local ufs_gear=""
        local ufs_lanes=""
        local ufs_pwr=""
        if [ -n "$ufs_ctrl" ]; then
            [ -f "$ufs_ctrl/gear" ] && ufs_gear=$(cat "$ufs_ctrl/gear" 2>/dev/null)
            [ -z "$ufs_gear" ] && [ -f "$ufs_ctrl/current_gear" ] && ufs_gear=$(cat "$ufs_ctrl/current_gear" 2>/dev/null)
            if [ -z "$ufs_gear" ] && [ -f "$ufs_ctrl/tx_gear" ]; then
                local tg=$(cat "$ufs_ctrl/tx_gear" 2>/dev/null)
                local rg=$(cat "$ufs_ctrl/rx_gear" 2>/dev/null)
                [ -n "$tg" ] && ufs_gear="TX:G${tg}/RX:G${rg}"
            fi

            [ -f "$ufs_ctrl/lane_count" ] && ufs_lanes=$(cat "$ufs_ctrl/lane_count" 2>/dev/null)
            if [ -z "$ufs_lanes" ] && [ -f "$ufs_ctrl/tx_lanes" ]; then
                local tl=$(cat "$ufs_ctrl/tx_lanes" 2>/dev/null)
                local rl=$(cat "$ufs_ctrl/rx_lanes" 2>/dev/null)
                [ -n "$tl" ] && ufs_lanes="TX:${tl}L/RX:${rl}L"
            fi

            [ -f "$ufs_ctrl/power_mode" ] && ufs_pwr=$(cat "$ufs_ctrl/power_mode" 2>/dev/null)
        fi

        local ufs_rate="UNKNOWN"
        if [ -n "$ufs_gear" ] || [ -n "$ufs_lanes" ] || [ -n "$ufs_pwr" ]; then
            local rate_parts=""
            [ -n "$ufs_pwr" ] && rate_parts="${ufs_pwr}"
            if [ -n "$ufs_gear" ]; then
                [ -n "$rate_parts" ] && rate_parts="${rate_parts}, Gear: ${ufs_gear}" || rate_parts="Gear: ${ufs_gear}"
            fi
            if [ -n "$ufs_lanes" ]; then
                [ -n "$rate_parts" ] && rate_parts="${rate_parts}, Lanes: ${ufs_lanes}" || rate_parts="Lanes: ${ufs_lanes}"
            fi
            ufs_rate="$rate_parts"
        fi

        echo "  存储芯片类型:  UFS"
        echo "  UFS 芯片厂商:  ${ufs_vendor:-UNKNOWN}"
        echo "  UFS 芯片型号:  ${ufs_model:-UNKNOWN}"
        echo "  UFS 固件版本:  ${ufs_rev:-UNKNOWN}"
        echo "  UFS 规范版本:  ${ufs_spec}"
        echo "  UFS 速率/通道: ${ufs_rate}"
    elif [ -d /sys/block/mmcblk0/device ]; then
        local mmc_dev="/sys/block/mmcblk0/device"
        local mmc_host="$(cd "$mmc_dev/.." 2>/dev/null && pwd)"
        [ ! -d "$mmc_host" ] && mmc_host=$(ls -d /sys/class/mmc_host/mmc* 2>/dev/null | head -n 1)

        local mmc_name="$(cat "$mmc_dev/name" 2>/dev/null | tr -d '\r\n')"
        local manfid_raw="$(cat "$mmc_dev/manfid" 2>/dev/null | tr -d '\r\n')"
        local mmc_prv="$(cat "$mmc_dev/prv" 2>/dev/null | tr -d '\r\n')"
        local mmc_fwrev="$(cat "$mmc_dev/fwrev" 2>/dev/null | tr -d '\r\n')"
        local mmc_date="$(cat "$mmc_dev/date" 2>/dev/null | tr -d '\r\n')"

        # 厂商 ID 映射
        local mmc_vendor="UNKNOWN"
        case "$manfid_raw" in
            0x15|0x000015|21)  mmc_vendor="Samsung" ;;
            0x90|0x000090|144) mmc_vendor="SKhynix" ;;
            0x13|0x000013|19)  mmc_vendor="Micron" ;;
            0x2c|0x00002c)     mmc_vendor="Micron" ;;
            0x45|0x000045|69)  mmc_vendor="SanDisk/WD" ;;
            0x11|0x000011|17)  mmc_vendor="Toshiba/Kioxia" ;;
            0xfe|0x0000fe|254) mmc_vendor="Kingston" ;;
            0x70|0x000070|112) mmc_vendor="Kingston" ;;
            0xdc|0x0000dc)     mmc_vendor="Longsys" ;;
            0x88|0x000088)     mmc_vendor="Foresee" ;;
            0x9b|0x00009b)     mmc_vendor="YMTC" ;;
            "")                mmc_vendor="UNKNOWN" ;;
            *)                 mmc_vendor="ManfID:${manfid_raw}" ;;
        esac
        [ "$mmc_vendor" != "UNKNOWN" ] && [ -n "$manfid_raw" ] && [ "$mmc_vendor" != "ManfID:${manfid_raw}" ] && mmc_vendor="${mmc_vendor} (${manfid_raw})"

        # 固件与硬件版本组合
        local mmc_rev_str="UNKNOWN"
        if [ -n "$mmc_prv" ] || [ -n "$mmc_fwrev" ]; then
            mmc_rev_str="PRV:${mmc_prv:-UNKNOWN}, FW:${mmc_fwrev:-UNKNOWN}"
        fi

        # 规范版本解析
        local spec_v="$(cat "$mmc_dev/spec_v" 2>/dev/null | tr -d '\r\n')"
        local mmc_spec="eMMC"
        if [ -n "$spec_v" ]; then
            mmc_spec="eMMC ${spec_v}"
        fi

        # 速率、时钟与总线宽度
        local mmc_timing=""
        local mmc_clock=""
        local mmc_width=""

        local ios_file=$(ls /sys/kernel/debug/mmc*/ios 2>/dev/null | head -n 1)
        if [ -f "$ios_file" ]; then
            local clk_hz=$(grep "clock:" "$ios_file" 2>/dev/null | awk '{print $2}')
            if [ -n "$clk_hz" ] && [ "$clk_hz" -gt 0 ] 2>/dev/null; then
                mmc_clock="$(( clk_hz / 1000000 ))MHz"
            fi
            local t_spec=$(grep "timing spec:" "$ios_file" 2>/dev/null | sed 's/.*timing spec:[ ]*//;s/[()]//g')
            [ -n "$t_spec" ] && mmc_timing="$t_spec"
            local b_width=$(grep "bus width:" "$ios_file" 2>/dev/null | awk '{print $3}')
            [ -n "$b_width" ] && mmc_width="${b_width}-bit"
        fi

        if [ -z "$mmc_timing" ] && [ -n "$mmc_host" ]; then
            [ -f "$mmc_host/timing" ] && mmc_timing=$(cat "$mmc_host/timing" 2>/dev/null | tr -d '\r\n')
        fi
        if [ -z "$mmc_clock" ] && [ -n "$mmc_host" ] && [ -f "$mmc_host/clock" ]; then
            local clk_hz=$(cat "$mmc_host/clock" 2>/dev/null | tr -d '\r\n')
            if [ -n "$clk_hz" ] && [ "$clk_hz" -gt 0 ] 2>/dev/null; then
                mmc_clock="$(( clk_hz / 1000000 ))MHz"
            fi
        fi
        if [ -z "$mmc_width" ] && [ -n "$mmc_host" ] && [ -f "$mmc_host/bus_width" ]; then
            local bw=$(cat "$mmc_host/bus_width" 2>/dev/null | tr -d '\r\n')
            [ -n "$bw" ] && mmc_width="${bw}-bit"
        fi

        local mmc_rate="UNKNOWN"
        if [ -n "$mmc_timing" ] || [ -n "$mmc_clock" ] || [ -n "$mmc_width" ]; then
            local rate_parts=""
            [ -n "$mmc_timing" ] && rate_parts="${mmc_timing}"
            if [ -n "$mmc_clock" ]; then
                [ -n "$rate_parts" ] && rate_parts="${rate_parts} (${mmc_clock})" || rate_parts="${mmc_clock}"
            fi
            if [ -n "$mmc_width" ]; then
                [ -n "$rate_parts" ] && rate_parts="${rate_parts}, ${mmc_width}" || rate_parts="${mmc_width}"
            fi
            mmc_rate="$rate_parts"
        fi

        echo "  存储芯片类型:  eMMC"
        echo "  eMMC 芯片厂商: ${mmc_vendor}"
        echo "  eMMC 芯片型号: ${mmc_name:-UNKNOWN}"
        echo "  eMMC 固件版本: ${mmc_rev_str}"
        echo "  eMMC 规范版本: ${mmc_spec}"
        echo "  eMMC 速率/总线: ${mmc_rate}"
        [ -n "$mmc_date" ] && echo "  eMMC 生产日期: ${mmc_date}"
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
