adb install -r whatsTemp_v1.9.apk
adb shell "mkdir -p /sdcard/WhatsTemp/"
adb push tool.config /sdcard/WhatsTemp/

adb root
adb wait-for-device

adb shell setenforce 0

adb shell chmod 664 /sys/devices/system/cpu/cpu0/online
adb shell chmod 664 /sys/devices/system/cpu/cpu1/online
adb shell chmod 664 /sys/devices/system/cpu/cpu2/online
adb shell chmod 664 /sys/devices/system/cpu/cpu3/online
adb shell chmod 664 /sys/devices/system/cpu/cpu4/online
adb shell chmod 664 /sys/devices/system/cpu/cpu5/online
adb shell chmod 664 /sys/devices/system/cpu/cpu6/online
adb shell chmod 664 /sys/devices/system/cpu/cpu7/online

pause