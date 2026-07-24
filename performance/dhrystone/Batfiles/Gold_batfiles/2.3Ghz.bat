adb wait-for-device root
adb wait-for-device remount
adb shell "echo test > /sys/power/wake_lock"
adb shell "echo 0 > /sys/devices/system/cpu/cpu0/online"
adb shell "echo 0 > /sys/devices/system/cpu/cpu1/online"
adb shell "echo 0 > /sys/devices/system/cpu/cpu2/online"
adb shell "echo 0 > /sys/devices/system/cpu/cpu3/online"
adb shell "echo 0 > /sys/devices/system/cpu/cpu4/online"
adb shell "echo 0 > /sys/devices/system/cpu/cpu5/online"
adb shell "echo 0 > /sys/devices/system/cpu/cpu6/online"
adb shell "echo 1 > /sys/devices/system/cpu/cpu7/online"
adb shell "echo 2361600 > /sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq"
adb shell "echo 2361600 > /sys/devices/system/cpu/cpu7/cpufreq/scaling_min_freq"
adb shell "cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq"
adb shell "cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_min_freq
adb shell "cat /sys/devices/system/cpu/cpu7/cpufreq/cpuinfo_cur_freq"
adb shell "echo performance > /sys/devices/system/cpu/cpu7/cpufreq/scaling_governor"
adb shell cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_governor
adb shell cat /sys/devices/system/cpu/cpu*/online