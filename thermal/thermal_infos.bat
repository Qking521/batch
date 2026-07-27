@echo off
chcp 65001 >nul

set "cmd=%~2"
set "param1=%~3"
set "param2=%~4"

if /i "%cmd%"=="tz" goto thermal_zones
if /i "%cmd%"=="cd" goto thermal_cooling_devices
if /i "%cmd%"=="hw" goto thermal_hwmon

echo Unknown command: %cmd%
goto usage
exit /b

:usage
echo 查看thermal信息的工具
echo =======================
echo.
echo 可用命令:
echo   tz [en/dis]          - 查看当前所有温度传感器信息 (默认动作).
echo   cd                   - 查看当前所有冷却设备的状态信息 (默认动作).
echo   hw                   - 查看当前所有硬件监控器的状态信息 (默认动作).
echo   help                 - 显示此帮助信息.
echo.
echo Examples:
echo   therm info tz
echo.
exit /b

:thermal_zones
if /i "%param1%"=="" set "ACTION=info"
if /i "%param1%"=="dis" set "ACTION=disable"
if /i "%param1%"=="en" set "ACTION=enable"
set "SH_SCRIPT=%SCRIPT_DIR%thermal_thermal_zones.sh"
adb shell "sh -s %ACTION%" < "%SH_SCRIPT%"
exit /b

:thermal_cooling_devices
set "SH_SCRIPT=%SCRIPT_DIR%thermal_cooling_devices.sh"
adb shell "sh -s" < "%SH_SCRIPT%"
exit /b

:thermal_hwmon
set "SH_SCRIPT=%SCRIPT_DIR%thermal_hwmon.sh"
adb shell "sh -s"  < "%SH_SCRIPT%"
exit /b