adb root 
adb wait-for-device
adb remount
adb push dhry.elf /data/dhrystone.elf
adb push dhrystone.sh /data/
adb push input.txt /data/
adb shell chmod 777 /data/dhrystone.elf
adb shell chmod 777 /data/dhrystone.sh
adb shell chmod 777 /data/dhrystone_multi.sh
pause