@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

：：此脚本由thermal_config.bat在平台为mediatek时调用
:: 检查thermal策略
set thermalVersion=-1
for /f %%a in ('adb shell getprop ro.vendor.mtk_thermal_2_0') do set thermalVersion=%%a
echo MTK_THERMAL_VERSION = %thermalVersion%

:: 设置主目录路径
set "DECRYPT_DIR=%SCRIPT_DIR%\thermal_decrypt"
set "OUT_DIR=%OUT_DIR%\thermal_decrypt\%FORMAT_TIME%"

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

echo thermal文件目录创建成功: %OUT_DIR%

:: 执行adb pull命令
echo 正在执行adb pull命令...
if %thermalVersion%==0 (
	adb pull /vendor/etc/.tp/ "%OUT_DIR%"
)else (
	adb pull /vendor/etc/thermal/. "%OUT_DIR%"
)

:: 重命名文件后缀为.mtc
cd "%OUT_DIR%"
for /r %%f in (*.conf) do (
	if exist "%%f" (
        set "filename=%%~nf"
        copy "%%f" "!filename!.mtc" >nul
    )
)

copy "%DECRYPT_DIR%"\forfiles.exe %OUT_DIR%
copy "%DECRYPT_DIR%"\decrypt.exe %OUT_DIR%
copy "%DECRYPT_DIR%"\decrypt_all_config.bat %OUT_DIR%

rem decrypt_all_config.bat有pause，<nul会让 pause 立即收到一个“空输入”，相当于自动按下回车，不会卡住
call decrypt_all_config.bat <nul
if %errorlevel% neq 0 (
    echo 警告: 解密脚本执行可能有问题
)

:: 删除所有 .mtc 文件
del *.mtc

start %OUT_DIR%