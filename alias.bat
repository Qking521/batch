@echo off
call batScript\init.bat
@REM open microsoft apps
doskey msapp=explorer.exe shell:AppsFolder

@REM  $* 表示这个命令可能会有参数
@REM  @doskey表示执行这个命令时,不显示这条命令本身
@REM | nedd to transfer to  ^|
@REM the $T instead of &&
@REM $1 is first param, $* represent all params
@REM $T is represent &&
@REM start filename.txt -- use default app open file
doskey ls=dir /w $*
doskey ll=dir $*
doskey myalias=doskey /macros
doskey cpn=adb shell dumpsys window ^| findstr mCurrentFocus
doskey bd=adb shell getprop ^| findstr "ro.build.date"
doskey getprop=adb shell getprop ^| findstr $*
doskey enable=adb root ^&^& adb remount
doskey wq=adb logcat -s "wq"
doskey wqc=adb logcat -c ^&^& adb logcat -s "wq"
doskey logcat=adb logcat ^> logcat.txt
doskey logcatc=adb logcat -c ^&^& adb logcat ^> logcat.txt

@REM adb settings
doskey ggs= adb shell settings get global $*
doskey gsys= adb shell settings get system $*
doskey gses= adb shell settings get secure $*

@REM screenshot&screenrecord, break on -- register control + c action
doskey screenshot=adb shell screencap -p /sdcard/screenshot.png ^&^& adb pull sdcard/screenshot.png . ^&^& start .\screenshot.png
doskey record=adb shell screenrecord  --bugreport /sdcard/record.mp4 ^
$T break on ^
$T adb pull /sdcard/record.mp4 . ^&^& start .\record.mp4

doskey pullrecord=adb pull /sdcard/record.mp4 . ^&^& start .\record.mp4

@REM enable layout inspector
doskey enableLI=adb shell setprop persist.debug.dalvik.vm.jdwp.enabled 1 $T adb reboot 

@REM dumpsys
doskey dumpsurface=adb shell dumpsys SurfaceFlinger ^> surface.txt ^&^& start .\surface.txt
doskey dumpwindow=adb shell dumpsys window ^> window.txt ^&^& start .\window.txt
doskey dumpwindows=adb shell dumpsys window windows ^> windows.txt ^&^& start .\windows.txt
doskey surface=%USERPROFILE%\batScript\sf.bat

@REM dumpheap
doskey dumphp=adb shell "am dumpheap $(ps -A | grep systemui | grep -v grep | awk '{print $2}') /data/local/tmp/heap.hprof"

@REM pid input packagename
doskey getPid=adb shell pidof $* 
doskey killPid=adb shell "pidof "$1" | xargs kill -9"

@REM version
doskey findSetting=%USERPROFILE%\batScript\settings_lookfor.bat $*

@REM  mtklog
doskey mtklog=%USERPROFILE%\batScript\mtk\mtklog.bat $*

@REM xiaomi push ota to phone
doskey miota=adb shell rm -rf sdcard/ota/* ^&^& adb push D:\Download\ota.zip /sdcard/ota/
doskey milogc=adb shell rm -rf Android/data/com.mi.health/files/log/devicelog ^&^& adb shell rm -rf Android/Download/wearablelog
doskey milog=%USERPROFILE%\batScript\milog.bat

@REM android cmd
doskey ad=%USERPROFILE%\batScript\android\android_all.bat $*

@REM power
doskey power=%USERPROFILE%\batScript\power\power_all.bat $*

@REM performance
doskey perf=%USERPROFILE%\batScript\performance\perf_all.bat $*
