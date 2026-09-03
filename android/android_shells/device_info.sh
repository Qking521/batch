#!/system/bin/sh
# 用法: device_info.sh

echo "型号: $(getprop ro.product.model)"
echo "品牌: $(getprop ro.product.brand)"
echo "设备名: $(getprop ro.product.device)"
echo "Android版本: $(getprop ro.build.version.release)"
echo "SDK: $(getprop ro.build.version.sdk)"
echo "Build号: $(getprop ro.build.display.id)"
echo "内核版本: $(uname -r)"
echo "CPU ABI: $(getprop ro.product.cpu.abi)"
echo "序列号: $(getprop ro.serialno)"
if [ -d /sys/block/sda/device ]; then
    echo "UFS厂商: $(cat /sys/block/sda/device/vendor 2>/dev/null | tr -d '\r\n')"
    echo "UFS型号: $(cat /sys/block/sda/device/model 2>/dev/null | tr -d '\r\n')"
    echo "UFS固件: $(cat /sys/block/sda/device/rev 2>/dev/null | tr -d '\r\n')"
elif [ -d /sys/block/mmcblk0/device ]; then
    echo "eMMC型号: $(cat /sys/block/mmcblk0/device/name 2>/dev/null | tr -d '\r\n')"
    echo "eMMC厂商: $(cat /sys/block/mmcblk0/device/manfid 2>/dev/null | tr -d '\r\n')"
    echo "eMMC固件: PRV:$(cat /sys/block/mmcblk0/device/prv 2>/dev/null | tr -d '\r\n'), FW:$(cat /sys/block/mmcblk0/device/fwrev 2>/dev/null | tr -d '\r\n')"
fi
echo "开机时长: $(uptime)"