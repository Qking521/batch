#!/system/bin/sh

# 写入 settings 并打印结果
run_setting() {
    namespace="$1"
    key="$2"
    value="$3"
    settings put "$namespace" "$key" "$value"
    if [ $? -eq 0 ]; then
        echo "  [OK] settings $namespace $key = $value"
    else
        echo "  [FAIL] settings $namespace $key = $value"
    fi
}

# 执行 svc 命令并打印结果
run_svc() {
    svc "$@" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "  [OK] svc $*"
    else
        echo "  [FAIL] svc $*"
    fi
}

# apply: 配置待机基准环境
do_apply() {
    echo ">>> 开始配置待机基准环境..."

    # 开启飞行模式
    run_setting global airplane_mode_on 1
    am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true >/dev/null 2>&1
    echo "  [OK] 飞行模式广播已发送"

    # 关闭 Wi-Fi / 蓝牙 / NFC
    run_svc wifi disable
    run_svc bluetooth disable
    run_svc nfc disable

    # 关闭 GPS（位置模式设为 0）
    run_setting secure location_mode 0

    # 关闭自动旋转
    run_setting system accelerometer_rotation 0

    # 关闭自动亮度，设置标准亮度值
    run_setting system screen_brightness_mode 0
    run_setting system screen_brightness 92

    # 设置息屏超时为 30 分钟（1800000 ms）
    run_setting system screen_off_timeout 1800000

    # motorola 机型额外处理
    brand=$(getprop ro.product.brand)
    if [ "$brand" = "motorola" ]; then
        echo ">>> 检测到 motorola 机型，执行额外配置..."
        pm disable-user com.motorola.bug2go >/dev/null 2>&1 && \
            echo "  [OK] 已禁用 com.motorola.bug2go" || \
            echo "  [FAIL] 禁用 com.motorola.bug2go 失败"
        echo "  [MANUAL] 请手动关闭 mtklog 里的 log 开关"
        echo "  [MANUAL] 请手动关闭 moto 应用里的手势操作开关"
        echo "  [MANUAL] 请手动关闭 moto 应用里的息屏显示开关"
        echo "  [MANUAL] 请手动关闭 moto 应用里的双击屏幕开关"
    fi

    echo ">>> 待机基准环境配置完成。"
}

do_apply
