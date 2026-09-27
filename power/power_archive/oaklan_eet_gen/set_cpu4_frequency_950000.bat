adb root

adb shell "echo temporary > /sys/power/wake_lock"

adb shell "echo 1 > /sys/devices/system/cpu/cpu0/online"
adb shell "echo 1 > /sys/devices/system/cpu/cpu1/online"
adb shell "echo 1 > /sys/devices/system/cpu/cpu2/online"
adb shell "echo 1 > /sys/devices/system/cpu/cpu3/online"

adb shell "echo 1 > /sys/devices/system/cpu/cpu4/online"
adb shell "echo 1 > /sys/devices/system/cpu/cpu5/online"
adb shell "echo 1 > /sys/devices/system/cpu/cpu6/online"
adb shell "echo 1 > /sys/devices/system/cpu/cpu7/online"

adb shell "echo 0 > /sys/devices/system/cpu/cpu0/online"
adb shell "echo 0 > /sys/devices/system/cpu/cpu1/online"
adb shell "echo 0 > /sys/devices/system/cpu/cpu2/online"
adb shell "echo 0 > /sys/devices/system/cpu/cpu3/online"

adb shell "echo 1 > /sys/devices/system/cpu/cpu4/online"
adb shell "echo 0 > /sys/devices/system/cpu/cpu5/online"
adb shell "echo 0 > /sys/devices/system/cpu/cpu6/online"
adb shell "echo 0 > /sys/devices/system/cpu/cpu7/online"

adb shell "echo performance > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor"
adb shell "echo 950000 > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq"
adb shell "echo 950000 > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq"

adb shell "cat /sys/devices/system/cpu/cpufreq/policy4/scaling_governor | awk '{print "governor:" $0}'"
adb shell "cat /sys/devices/system/cpu/cpufreq/policy4/scaling_cur_freq | awk '{print "cur_freq:" $0}'"
adb shell "cat /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq | awk '{print "min_freq:" $0}'"
adb shell "cat /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq | awk '{print "max_freq:" $0}'"
pause
