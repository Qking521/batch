@echo off
chcp 65001 >nul
echo ====================================
echo    Android设备关键硬件信息
echo ====================================
echo.

REM 检查ADB是否可用
adb version >nul 2>&1
if %errorlevel% neq 0 (
    echo 错误：未找到ADB命令，请确保ADB已安装并添加到PATH环境变量中
    pause
    exit /b 1
)

REM 检查设备连接
echo 正在检查设备连接状态...
adb devices | findstr "device" | findstr /v "List" >nul
if %errorlevel% neq 0 (
    echo 错误：未检测到已连接的Android设备
    pause
    exit /b 1
)

echo 设备已连接，正在获取关键硬件信息...
echo.

REM 创建输出文件
set output_file=android_key_info_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.txt
set output_file=%output_file: =0%

echo 关键硬件信息 > %output_file%
echo 生成时间：%date% %time% >> %output_file%
echo ================================ >> %output_file%
echo. >> %output_file%

echo [1/6] 设备基本信息
echo === 设备基本信息 === >> %output_file%
echo 设备型号： >> %output_file%
adb shell getprop ro.product.model >> %output_file%
echo 制造商： >> %output_file%
adb shell getprop ro.product.manufacturer >> %output_file%
echo 品牌： >> %output_file%
adb shell getprop ro.product.brand >> %output_file%
echo Android版本： >> %output_file%
adb shell getprop ro.build.version.release >> %output_file%
echo. >> %output_file%

echo [2/6] 芯片信息
echo === 芯片信息 === >> %output_file%
echo 芯片型号： >> %output_file%
adb shell getprop ro.hardware >> %output_file%
echo 芯片平台： >> %output_file%
adb shell getprop ro.board.platform >> %output_file%
echo CPU架构： >> %output_file%
adb shell getprop ro.product.cpu.abi >> %output_file%
echo 处理器信息： >> %output_file%
adb shell "cat /proc/cpuinfo | grep 'Hardware\|Processor'" >> %output_file%
echo. >> %output_file%

echo [3/6] 显示屏信息
echo === 显示屏信息 === >> %output_file%
echo 屏幕分辨率： >> %output_file%
adb shell wm size >> %output_file%
echo 屏幕密度： >> %output_file%
adb shell wm density >> %output_file%
echo 屏幕相关属性： >> %output_file%
adb shell "getprop | grep 'lcd\|display'" >> %output_file%
echo. >> %output_file%

echo [4/6] 内存信息
echo === 内存信息 === >> %output_file%
echo 内存总量： >> %output_file%
adb shell "cat /proc/meminfo | grep MemTotal" >> %output_file%
echo 可用内存： >> %output_file%
adb shell "cat /proc/meminfo | grep MemAvailable" >> %output_file%
echo. >> %output_file%

echo [5/6] GPU信息
echo === GPU信息 === >> %output_file%
echo OpenGL版本： >> %output_file%
adb shell getprop ro.opengles.version >> %output_file%
echo GPU渲染器： >> %output_file%
adb shell "dumpsys SurfaceFlinger | grep 'GLES\|Renderer'" >> %output_file%
echo. >> %output_file%

echo [6/6] 其他硬件信息
echo === 其他硬件信息 === >> %output_file%
echo 电池信息： >> %output_file%
adb shell "dumpsys battery | grep 'technology\|present'" >> %output_file%
echo 摄像头数量： >> %output_file%
adb shell "dumpsys media.camera | grep 'Camera ID'" >> %output_file%
echo WiFi芯片： >> %output_file%
adb shell "getprop | grep wifi" >> %output_file%
echo. >> %output_file%

echo ================================ >> %output_file%
echo 关键信息获取完成 >> %output_file%

echo.
echo ✓ 关键硬件信息获取完成！
echo ✓ 信息已保存至：%output_file%
echo.

REM 在控制台显示关键信息
echo ==================== 关键信息摘要 ====================
echo.
echo 设备型号：
adb shell getprop ro.product.model

echo 制造商：
adb shell getprop ro.product.manufacturer

echo 芯片型号：
adb shell getprop ro.hardware

echo 芯片平台：
adb shell getprop ro.board.platform

echo 屏幕分辨率：
adb shell wm size

echo 屏幕密度：
adb shell wm density

start %output_file%