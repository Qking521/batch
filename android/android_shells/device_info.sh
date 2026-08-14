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
echo "开机时长: $(uptime)"