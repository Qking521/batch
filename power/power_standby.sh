#!/system/bin/sh
# ============================================================
# Author: WangQiang
# Date:   2026-08-06
# Desc:   Android 待机基准环境配置与恢复脚本
# Usage:  adb shell "sh -s <apply|restore|archive|cmd>" < power_standby.sh
# ============================================================

ACTION="$1"

# 获取设备名称 ro.product.device
DEVICE_NAME=$(getprop ro.product.device 2>/dev/null | tr -d '\r\n')
[ -z "$DEVICE_NAME" ] && DEVICE_NAME="unknown"

ARCHIVE_DIR="/data/local/tmp/power_archive"
ARCHIVE_FILE="${ARCHIVE_DIR}/${DEVICE_NAME}_standby_default.conf"

# moto 扩展 SettingsProvider URI
MOTO_SETTINGS_URI="content://com.motorola.android.providers.settings"
MOTO_ACTIONS_URI="content://com.motorola.actions.settings.provider/actionscontainer"

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
    { [ "$val" = "null" ] || [ -z "$val" ]; } && val=""
    echo "$val"
}

# 写入 moto settings 并打印结果
run_moto_setting() {
    namespace="$1"
    key="$2"
    value="$3"
    content call --uri "$MOTO_SETTINGS_URI/$namespace" --method "PUT_$namespace" --arg "$key" --extra "value:s:$value" --extra _user:i:0 >/dev/null 2>&1
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
    val=$(content query --uri "$MOTO_SETTINGS_URI/$namespace/$key" --projection value 2>/dev/null | sed -n 's/.*value=//p')
    { [ "$val" = "null" ] || [ "$val" = "NULL" ] || [ -z "$val" ]; } && val="$def_val"
    echo "$val"
}

# 写入 Moto Actions Settings 并打印结果
run_moto_actions_setting() {
    key="$1"
    value="$2"
    content update --uri "$MOTO_ACTIONS_URI/$key" --bind ENABLED:b:$value 2>/dev/null
    if [ $? -eq 0 ]; then
        log "moto actions settings $key = $value"
    else
        err "moto actions settings $key = $value"
    fi
}

# 读取 Moto Actions Settings 值
get_moto_actions_setting() {
    key="$1"
    val=$(content query --uri "$MOTO_ACTIONS_URI/$key" --projection VALUE 2>/dev/null | sed -n 's/.*VALUE=//p')
    { [ "$val" = "null" ] || [ -z "$val" ]; } && val=""
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

# ---- 配置键清单（单一数据源）----
# 每行格式: namespace|key|default
# 新增/删除配置只需在此清单增减一行，get / 存档 / restore 三处自动同步
settings_keys() {
    cat <<'EOF'
global|airplane_mode_on|0
secure|location_mode|0
system|accelerometer_rotation|1
system|screen_brightness_mode|1
system|screen_brightness|102
system|screen_off_timeout|60000
global|wifi_on|0
global|bluetooth_on|0
global|nfc_on|0
EOF
}

# moto 扩展 settings: namespace|key|default
moto_settings_keys() {
    cat <<'EOF'
secure|doze_always_on|0
secure|is_tap_to_wake_enable|0
secure|lift_phone_to_wake|1
global|put_display_to_sleep|0
EOF
}

# moto actions: key|default
moto_actions_keys() {
    cat <<'EOF'
split_screen|false
quick_screenshot|false
tap_tap|false
quick_capture|false
flash_on_chop|false
lift_to_silence|false
flip_to_mute|false
EOF
}

# 从配置文件读取指定键的值
conf_get() {
    grep "^$2=" "$1" 2>/dev/null | cut -d'=' -f2-
}

# 生成所有配置项的完整 adb 命令清单（数字默认 0，bool 默认 false）
do_cmd() {
    log ">>> 生成完整 adb 命令清单（数字默认 0，bool 默认 false）..."

    echo "[SETTINGS]"
    settings_keys | while IFS='|' read -r ns key def; do
        echo "adb shell settings put $ns $key 0"
    done

    echo "[MOTO_SETTINGS]"
    moto_settings_keys | while IFS='|' read -r ns key def; do
        echo "adb shell content call --uri $MOTO_SETTINGS_URI/$ns --method PUT_$ns --arg $key --extra value:s:0 --extra _user:i:0"
    done

    echo "[MOTO_ACTIONS]"
    moto_actions_keys | while IFS='|' read -r key def; do
        echo "adb shell content update --uri $MOTO_ACTIONS_URI/$key --bind ENABLED:b:false"
    done
}

# 备份系统当前设置到本地 power_archive 目录
do_archive() {
    log ">>> 开始获取并保存系统默认待机配置 (设备: $DEVICE_NAME)..."

    mkdir -p "$ARCHIVE_DIR"
    : > "$ARCHIVE_FILE"

    settings_keys | while IFS='|' read -r ns key def; do
        val=$(get_setting "$ns" "$key")
        echo "${key}=${val:-${def}}" >> "$ARCHIVE_FILE"
    done

    moto_settings_keys | while IFS='|' read -r ns key def; do
        val=$(get_moto_setting "$ns" "$key" "$def")
        echo "${key}=${val:-${def}}" >> "$ARCHIVE_FILE"
    done

    moto_actions_keys | while IFS='|' read -r key def; do
        val=$(get_moto_actions_setting "$key")
        echo "${key}=${val:-${def}}" >> "$ARCHIVE_FILE"
    done

    if [ -f "$ARCHIVE_FILE" ]; then
        log "默认配置已成功保存至 $ARCHIVE_FILE:"
        while IFS= read -r line; do
            log "  $line"
        done < "$ARCHIVE_FILE"
        return 0
    else
        err "保存默认配置失败: $ARCHIVE_FILE"
        return 1
    fi
}

standby_for_moto() {
    pm disable-user com.motorola.bug2go >/dev/null 2>&1 && \
        log "已禁用 com.motorola.bug2go" || \
        err "禁用 com.motorola.bug2go 失败"

    # moto 扩展 setting 写入：串行 content 命令 Java 冷启动开销大, 改为并发后台执行再统一 wait
    # 关闭息屏显示
    run_moto_setting secure doze_always_on 0 &
    # 关闭双击唤醒
    run_moto_setting secure is_tap_to_wake_enable 0 &
    # 关闭抬起唤醒
    run_moto_setting secure lift_phone_to_wake 0 &
    # 关闭双击息屏
    run_moto_setting global put_display_to_sleep 0 &
    # 关闭手势-三指上滑分屏
    run_moto_actions_setting split_screen false &
    # 关闭手势-三指上滑截图
    run_moto_actions_setting quick_screenshot false &
    # 关闭手势-双击背部
    run_moto_actions_setting tap_tap false &
    # 关闭手势-转腕开相机
    run_moto_actions_setting quick_capture false &
    # 关闭手势-快速手电筒
    run_moto_actions_setting flash_on_chop false &
    # 关闭手势-拿起解锁 当前先忽略
    # run_moto_actions_setting lift_to_unlock false
    # 关闭手势-拿起静音
    run_moto_actions_setting lift_to_silence false &
    # 关闭手势-翻转免打扰
    run_moto_actions_setting flip_to_mute false &
    wait
}

# 配置待机基准环境
do_standby() {
    # 如果默认配置文件不存在，先自动执行获取默认配置操作
    if [ ! -f "$ARCHIVE_FILE" ]; then
        log "在 $ARCHIVE_DIR 中未检测到设备 $DEVICE_NAME 的默认配置文件，先执行获取默认配置操作..."
        do_archive
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

# 恢复默认配置
do_restore() {
    log ">>> 开始恢复默认待机配置 (设备: $DEVICE_NAME)..."

    # 如果恢复时发现没有默认值文件（正常由 bat 层保证 push 基准档）
    if [ ! -f "$ARCHIVE_FILE" ]; then
        log "在 $ARCHIVE_DIR 中未检测到设备 $DEVICE_NAME 的默认配置文件..."
    fi

    # 标准 settings 项恢复
    settings_keys | while IFS='|' read -r ns key def; do
        val=$(conf_get "$ARCHIVE_FILE" "$key")
        [ -z "$val" ] && continue
        case "$key" in
            wifi_on|bluetooth_on|nfc_on)
                if [ "$val" -gt 0 ] 2>/dev/null; then
                    run_svc "${key%_on}" enable
                else
                    run_svc "${key%_on}" disable
                fi
                ;;
            airplane_mode_on)
                run_setting "$ns" "$key" "$val"
                [ "$val" = "1" ] && am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true >/dev/null 2>&1
                [ "$val" = "0" ] && am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false >/dev/null 2>&1
                ;;
            *)
                run_setting "$ns" "$key" "$val"
                ;;
        esac
    done

    # motorola 机型恢复处理
    brand=$(getprop ro.product.brand)
    if [ "$brand" = "motorola" ]; then
        pm enable com.motorola.bug2go >/dev/null 2>&1 && \
            log "已重新启用 com.motorola.bug2go"
        moto_settings_keys | while IFS='|' read -r ns key def; do
            val=$(conf_get "$ARCHIVE_FILE" "$key")
            [ -n "$val" ] && run_moto_setting "$ns" "$key" "$val"
        done
        moto_actions_keys | while IFS='|' read -r key def; do
            val=$(conf_get "$ARCHIVE_FILE" "$key")
            [ -n "$val" ] && run_moto_actions_setting "$key" "$val"
        done
    fi

    log ">>> 恢复默认待机配置完成。"
}

case "$ACTION" in
    apply)   do_standby ;;
    restore) do_restore ;;
    archive) do_archive ;;
    cmd)     do_cmd ;;
    *)
    # 默认无参数或未知参数时执行 apply
    do_standby
    ;;
esac