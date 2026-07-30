:cpu_info
adb shell ls /sys/devices/system/cpu/cpufreq/
for /f "delims=" %%a in ('adb shell ls /sys/devices/system/cpu/cpufreq/') do (
	echo %%a频率:
	adb shell cat /sys/devices/system/cpu/cpufreq/%%a/scaling_available_frequencies
)
for /f "delims=" %%a in ('adb shell ls /sys/devices/system/cpu/') do (
	echo %%a | findstr /r "cpu[0-9]" > nul
	if not errorlevel == 1 (
		for /f "delims=" %%b in ('adb shell cat /sys/devices/system/cpu/%%a/online') do (
			if "%%b"=="0" echo "cpu%%a offline"
		)
	)
)
exit /b