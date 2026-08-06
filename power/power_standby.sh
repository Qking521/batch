#!/system/bin/sh
# ============================================================
# Author: Antigravity Pair Program
# Date:   2026-08-06
# Desc:   Android 待机基准环境配置与恢复脚本
# Usage:  adb shell "sh -s <apply|restore|get_default>" < power_standby.sh
# ============================================================

ACTION="$1"

# 获取设备名称 ro.product.device
DEVICE_NAME=$(getprop ro.product.device 2>/dev/null | tr -d '\r\n')
[ -z "$DEVICE_NAME" ] && DEVICE_NAME="unknown"

DEF_DIR="/data/local/tmp/power_archive"
DEF_FILE="${DEF_DIR}/${DEVICE_NAME}_standby_default.conf"

log() {
    echo "[INFO] $*"
}

err() {
    echo "[ERROR] $*" >&2
}

# 写入 settings 并打印结果
run_setting() {
    namespace="$1"
    key="$2"
    value="$3"
    settings put "$namespace" "$key" "$value"
    if [ $? -eq 0 ]; then
        log "settings $namespace $key = $value"
    else
        err "settings $namespace $key = $value"
    fi
}

# 读取 settings 节点值
get_setting() {
    namespace="$1"
    key="$2"
    val=$(settings get "$namespace" "$key" 2>/dev/null)
    # 处理 null 情况
    [ "$val" = "null" ] || [ -z "$val" ] && val=""
    echo "$val"
}

# 执行 svc 命令并打印结果
run_svc() {
    svc "$@" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "svc $*"
    else
        err "svc $*"
    fi
}

# 备份系统当前设置到本地 power_archive 目录
do_get_default() {
    log ">>> 开始获取并保存系统默认待机配置 (设备: $DEVICE_NAME)..."

    # 获取 settings 配置
    air_mode=$(get_setting global airplane_mode_on)
    loc_mode=$(get_setting secure location_mode)
    rot_mode=$(get_setting system accelerometer_rotation)
    bright_mode=$(get_setting system screen_brightness_mode)
    bright_val=$(get_setting system screen_brightness)
    timeout_val=$(get_setting system screen_off_timeout)

    # 原样获取网络/开关原始值
    wifi_val=$(get_setting global wifi_on)
    bt_val=$(get_setting global bluetooth_on)
    nfc_val=$(get_setting global nfc_on)

    # 创建 power_archive 目录
    mkdir -p "$DEF_DIR"

    # 写入配置文件 (格式: key=value)
    cat <<EOF > "$DEF_FILE"
airplane_mode_on=${air_mode:-0}
location_mode=${loc_mode:-0}
accelerometer_rotation=${rot_mode:-1}
screen_brightness_mode=${bright_mode:-1}
screen_brightness=${bright_val:-102}
screen_off_timeout=${timeout_val:-60000}
wifi_on=${wifi_val:-0}
bluetooth_on=${bt_val:-0}
nfc_on=${nfc_val:-0}
EOF

    if [ -f "$DEF_FILE" ]; then
        log "默认配置已成功保存至 $DEF_FILE:"
        cat "$DEF_FILE" | while read -r line; do
            log "  $line"
        done
        return 0
    else
        err "保存默认配置失败: $DEF_FILE"
        return 1
    fi
}

# 配置待机基准环境
do_standby() {
    # 如果默认配置文件不存在，先自动执行获取默认配置操作
    if [ ! -f "$DEF_FILE" ]; then
        log "在 $DEF_DIR 中未检测到设备 $DEVICE_NAME 的默认配置文件，先执行获取默认配置操作..."
        do_get_default
    fi

    log ">>> 开始配置待机基准环境 (设备: $DEVICE_NAME)..."

    # 开启飞行模式
    run_setting global airplane_mode_on 1
    am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true >/dev/null 2>&1
    log "飞行模式广播已发送"

    # 关闭 Wi-Fi / 蓝牙 / NFC
    run_svc wifi disable
    run_svc bluetooth disable
    run_svc nfc disable

    # 关闭 GPS（位置模式设为 0）
    run_setting secure location_mode 0

    # 关闭自动旋转
    run_setting system accelerometer_rotation 0

    # 关闭自动亮度，设置标准亮度值 92
    run_setting system screen_brightness_mode 0
    run_setting system screen_brightness 92

    # 设置息屏超时为 30 分钟（1800000 ms）
    run_setting system screen_off_timeout 1800000

    # motorola 机型额外处理
    brand=$(getprop ro.product.brand)
    if [ "$brand" = "motorola" ]; then
        log "检测到 motorola 机型，执行额外配置..."
        pm disable-user com.motorola.bug2go >/dev/null 2>&1 && \
            log "已禁用 com.motorola.bug2go" || \
            err "禁用 com.motorola.bug2go 失败"
        echo "[MANUAL] 请手动关闭 mtklog 里的 log 开关"
        echo "[MANUAL] 请手动关闭 moto 应用里的手势操作开关"
        echo "[MANUAL] 请手动关闭 moto 应用里的息屏显示开关"
        echo "[MANUAL] 请手动关闭 moto 应用里的双击屏幕开关"
    fi

    log ">>> 待机基准环境配置完成。"
}

# 恢复默认配置
do_restore() {
    log ">>> 开始恢复默认待机配置 (设备: $DEVICE_NAME)..."

    # 如果恢复时发现没有默认值文件，也先自动做下获取操作
    if [ ! -f "$DEF_FILE" ]; then
        log "在 $DEF_DIR 中未检测到设备 $DEVICE_NAME 的默认配置文件，先执行获取默认配置操作..."
    fi

    # 从备份文件读取并恢复配置
    air_mode=$(grep '^airplane_mode_on=' "$DEF_FILE" | cut -d'=' -f2)
    loc_mode=$(grep '^location_mode=' "$DEF_FILE" | cut -d'=' -f2)
    rot_mode=$(grep '^accelerometer_rotation=' "$DEF_FILE" | cut -d'=' -f2)
    bright_mode=$(grep '^screen_brightness_mode=' "$DEF_FILE" | cut -d'=' -f2)
    bright_val=$(grep '^screen_brightness=' "$DEF_FILE" | cut -d'=' -f2)
    timeout_val=$(grep '^screen_off_timeout=' "$DEF_FILE" | cut -d'=' -f2)
    wifi_on=$(grep '^wifi_on=' "$DEF_FILE" | cut -d'=' -f2)
    bt_on=$(grep '^bluetooth_on=' "$DEF_FILE" | cut -d'=' -f2)
    nfc_on=$(grep '^nfc_on=' "$DEF_FILE" | cut -d'=' -f2)

    [ -n "$air_mode" ] && run_setting global airplane_mode_on "$air_mode"
    [ "$air_mode" = "1" ] && am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true >/dev/null 2>&1
    [ "$air_mode" = "0" ] && am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false >/dev/null 2>&1

    [ -n "$loc_mode" ] && run_setting secure location_mode "$loc_mode"
    [ -n "$rot_mode" ] && run_setting system accelerometer_rotation "$rot_mode"
    [ -n "$bright_mode" ] && run_setting system screen_brightness_mode "$bright_mode"
    [ -n "$bright_val" ] && run_setting system screen_brightness "$bright_val"
    [ -n "$timeout_val" ] && run_setting system screen_off_timeout "$timeout_val"

    # 恢复网络/开关：判断原始保存值是否大于 0
    if [ -n "$wifi_on" ] && [ "$wifi_on" -gt 0 ] 2>/dev/null; then
        run_svc wifi enable
    else
        run_svc wifi disable
    fi

    if [ -n "$bt_on" ] && [ "$bt_on" -gt 0 ] 2>/dev/null; then
        run_svc bluetooth enable
    else
        run_svc bluetooth disable
    fi

    if [ -n "$nfc_on" ] && [ "$nfc_on" -gt 0 ] 2>/dev/null; then
        run_svc nfc enable
    else
        run_svc nfc disable
    fi

    # motorola 机型恢复处理
    brand=$(getprop ro.product.brand)
    if [ "$brand" = "motorola" ]; then
        pm enable com.motorola.bug2go >/dev/null 2>&1 && \
            log "已重新启用 com.motorola.bug2go"
    fi

    log ">>> 恢复默认待机配置完成。"
}

case "$ACTION" in
    standby) do_standby ;;
    restore) do_restore ;;
    default) do_get_default ;;
    *)
        # 默认无参数或未知参数时执行 standby
        do_standby
        ;;
esac
