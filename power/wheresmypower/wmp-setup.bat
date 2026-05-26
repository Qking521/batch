set "package=com.motorola.wheresmypower"
adb shell "chmod +r /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq"
adb shell "chmod +r /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq"
adb shell "appops set %package% SYSTEM_ALERT_WINDOW allow"
adb shell "appops set %package% READ_MEDIA_AUDIO allow
adb shell "appops set %package% READ_MEDIA_IMAGES allow
adb shell "appops set %package% READ_MEDIA_VIDEO allow
adb shell "appops set %package% ACCESS_RESTRICTED_SETTINGS allow"
adb shell "am force-stop %package%"
adb shell "am start -a android.intent.action.VIEW -n com.motorola.wheresmypower/com.motorola.wheresmypower.SettingsActivity"
