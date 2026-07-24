adb root 
adb wait-for-device
::adb remount
adb push dhry_64.elf /data/dhrystone.elf
adb push dhrystone.sh /data/
adb push dhrystone_multi.sh /data/
adb push _dhrystone_multi.sh /data/
adb push input.txt /data/
adb shell chmod 777 /data/dhrystone.elf
adb shell chmod 777 /data/dhrystone.sh
adb shell chmod 777 /data/_dhrystone_multi.sh
adb shell chmod 777 /data/dhrystone_multi.sh
pause