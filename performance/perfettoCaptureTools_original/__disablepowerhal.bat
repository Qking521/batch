adb wait-for-device

adb root
adb shell "setprop persist.vendor.powerhal.enable 0"
adb reboot