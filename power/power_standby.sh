#!/system/bin/sh
# ============================================================
# Author: WangQiang
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

# 写入 moto settings 并打印结果
run_moto_setting() {
    namespace="$1"
    key="$2"
    value="$3"
    content="content://com.motorola.android.providers.settings"
    content call --uri $content/$namespace --method PUT_$namespace --arg $key --extra value:s:$value --extra _user:i:0 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "moto settings $namespace $key = $value"
    else
        err "moto settings $namespace $key = $value"
    fi
}

# 读取 moto settings 节点值
get_moto_setting() {
    namespace="$1"
    key="$2"
    def_val="$3"
    content="content://com.motorola.android.providers.settings"
    val=$(content query --uri $content/$namespace/$key --projection value | sed -n 's/.*value=//p' 2>/dev/null)
    # 处理 null 情况
    [ "$val" = "null" ] || [ "$val" = "NULL" ] || [ -z "$val" ] && val="$def_val"
    echo "$val"
}

# 写入 Moto Actions Settings 并打印结果
run_moto_actions_setting() {
    key="$1"
    value="$2"
    content="content://com.motorola.actions.settings.provider/actionscontainer"
    content update --uri $content/$key --bind ENABLED:b:$value 2>/dev/null
    if [ $? -eq 0 ]; then
        log "moto actions settings $key = $value"
    else
        err "moto actions settings $key = $value"
    fi
}

# 写入 Moto Actions Settings 并打印结果
get_moto_actions_setting() {
    key="$1"
    value="$2"
    content="content://com.motorola.actions.settings.provider/actionscontainer"
    val=$(content query --uri $content/$key --projection VALUE | sed -n 's/.*VALUE=//p' 2>/dev/null)
    # 处理 null 情况
    [ "$val" = "null" ] || [ -z "$val" ] && val=""
    [ "$val" = "1" ] && val=true || val=false
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
    #获取moto setting的值
    doze_always_on=$(get_moto_setting secure doze_always_on 0)
    is_tap_to_wake_enable=$(get_moto_setting secure is_tap_to_wake_enable)
    lift_phone_to_wake=$(get_moto_setting secure lift_phone_to_wake 1)
    put_display_to_sleep=$(get_moto_setting global put_display_to_sleep)
    # 获取moto 手势action setting值
    split_screen=$(get_moto_actions_setting split_screen)
    quick_screenshot=$(get_moto_actions_setting quick_screenshot)
    tap_tap=$(get_moto_actions_setting tap_tap)
    quick_capture=$(get_moto_actions_setting quick_capture)
    flash_on_chop=$(get_moto_actions_setting flash_on_chop)
    lift_to_silence=$(get_moto_actions_setting lift_to_silence)
    flip_to_mute=$(get_moto_actions_setting flip_to_mute)

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
doze_always_on=${doze_always_on:-0}
is_tap_to_wake_enable=${is_tap_to_wake_enable:-0}
lift_phone_to_wake=${lift_phone_to_wake:-0}
put_display_to_sleep=${put_display_to_sleep:-0}
split_screen=${split_screen:-0}
quick_screenshot=${quick_screenshot:-0}
tap_tap=${tap_tap:-0}
quick_capture=${quick_capture:-0}
flash_on_chop=${flash_on_chop:-0}
lift_to_silence=${lift_to_silence:-0}
flip_to_mute=${flip_to_mute:-0}
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

standby_for_moto() {
    pm disable-user com.motorola.bug2go >/dev/null 2>&1 && \
        log "已禁用 com.motorola.bug2go" || \
        err "禁用 com.motorola.bug2go 失败"
    # 关闭息屏显示
    run_moto_setting secure doze_always_on 0
    # 关闭双击唤醒
    run_moto_setting secure is_tap_to_wake_enable 0
    # 关闭抬起唤醒
    run_moto_setting secure lift_phone_to_wake 0
    # 关闭双击息屏
    run_moto_setting global put_display_to_sleep 0
    # 关闭手势-三指上滑分屏
    run_moto_actions_setting split_screen false
    # 关闭手势-三指上滑截图
    run_moto_actions_setting quick_screenshot false
    # 关闭手势-双击背部
    run_moto_actions_setting tap_tap false
    # 关闭手势-转腕开相机
    run_moto_actions_setting quick_capture false
    # 关闭手势-快速手电筒
    run_moto_actions_setting flash_on_chop false
    # 关闭手势-拿起解锁 当前先忽略
    # run_moto_actions_setting lift_to_unlock false
    # 关闭手势-拿起静音
    run_moto_actions_setting lift_to_silence false
    # 关闭手势-翻转免打扰
    run_moto_actions_setting flip_to_mute false
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
        standby_for_moto
    fi

    manufacturer=$(getprop ro.vendor.soc.manufacturer)
    if [ "$manufacturer" = "Mediatek" ]; then
        am broadcast -a com.debug.loggerui.ADB_CMD -e cmd_name stop --ei cmd_target -1 -n com.debug.loggerui/.framework.LogReceiver >/dev/null
        log "mtklog已关闭"
    fi

    log ">>> 待机基准环境配置完成。"
}

restore_for_moto() {
    DEF_FILE=$1

    pm enable com.motorola.bug2go >/dev/null 2>&1 && \
    log "已重新启用 com.motorola.bug2go"

    doze_always_on=$(grep '^doze_always_on=' "$DEF_FILE" | cut -d'=' -f2)
    [ -n "$doze_always_on" ] && run_moto_setting secure doze_always_on "$doze_always_on"

    is_tap_to_wake_enable=$(grep '^is_tap_to_wake_enable=' "$DEF_FILE" | cut -d'=' -f2)
    [ -n "$is_tap_to_wake_enable" ] && run_moto_setting secure is_tap_to_wake_enable "$is_tap_to_wake_enable"

    lift_phone_to_wake=$(grep '^lift_phone_to_wake=' "$DEF_FILE" | cut -d'=' -f2)
    [ -n "$lift_phone_to_wake" ] && run_moto_setting secure lift_phone_to_wake "$lift_phone_to_wake"

    put_display_to_sleep=$(grep '^put_display_to_sleep=' "$DEF_FILE" | cut -d'=' -f2)
    [ -n "$put_display_to_sleep" ] && run_moto_setting global put_display_to_sleep "$put_display_to_sleep"

    split_screen=$(grep '^split_screen=' "$DEF_FILE" | cut -d'=' -f2)
    [ -n "$split_screen" ] && run_moto_actions_setting split_screen "$split_screen"

    quick_screenshot=$(grep '^quick_screenshot=' "$DEF_FILE" | cut -d'=' -f2)
    [ -n "$quick_screenshot" ] && run_moto_actions_setting quick_screenshot "$quick_screenshot"

    tap_tap=$(grep '^tap_tap=' "$DEF_FILE" | cut -d'=' -f2)
    [ -n "$tap_tap" ] && run_moto_actions_setting tap_tap "$tap_tap"

    quick_capture=$(grep '^quick_capture=' "$DEF_FILE" | cut -d'=' -f2)
    [ -n "$quick_capture" ] && run_moto_actions_setting quick_capture "$quick_capture"

    flash_on_chop=$(grep '^flash_on_chop=' "$DEF_FILE" | cut -d'=' -f2)
    [ -n "$flash_on_chop" ] && run_moto_actions_setting flash_on_chop "$flash_on_chop"

    lift_to_silence=$(grep '^lift_to_silence=' "$DEF_FILE" | cut -d'=' -f2)
    [ -n "$lift_to_silence" ] && run_moto_actions_setting lift_to_silence "$lift_to_silence"

    flip_to_mute=$(grep '^flip_to_mute=' "$DEF_FILE" | cut -d'=' -f2)
    [ -n "$flip_to_mute" ] && run_moto_actions_setting flip_to_mute "$flip_to_mute"
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

    # 恢复moto的settingProvider值
        # motorola 机型恢复处理
    brand=$(getprop ro.product.brand)
    if [ "$brand" = "motorola" ]; then
        restore_for_moto $DEF_FILE
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
