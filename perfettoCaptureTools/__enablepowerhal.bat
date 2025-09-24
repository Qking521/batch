adb wait-for-device

adb root
adb shell "setprop persist.vendor.powerhal.enable 1"
adb reboot