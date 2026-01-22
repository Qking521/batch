@echo off

rem mtk thermal config decrypt
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 检查thermal策略
for /f %%a in ('adb shell getprop ro.vendor.mtk_thermal_2_0') do set thermalVersion=%%a
if not %thermalVersion%=="" (
	echo ro.vendor.mtk_thermal_2_0 = %thermalVersion%
)

:: 设置主目录路径
set "DECRYPT_DIR=%userprofile%\batScript\power\thermal_decrypt"

:: 检查主目录是否存在
if not exist "%DECRYPT_DIR%" (
    echo 错误: 主目录不存在: %DECRYPT_DIR%
    pause
    exit /b 1
)
:: 获取格式化的时间format_time
call %userprofile%\batScript\init.bat
set "OUT_DIR=%userprofile%\batScript\OUT\power\thermal_decrypt\%format_time%"
:: 检查日期文件夹是否存在，存在则删除
if exist "%OUT_DIR%" (
    rd /s /q "%OUT_DIR%"
)
mkdir "%OUT_DIR%"
if !errorlevel! neq 0 (
	echo 错误: 无法创建目录 %OUT_DIR%
	pause
	exit /b 1
)
echo thermal文件目录创建成功: %OUT_DIR%

:: 执行adb pull命令
echo 正在执行adb pull命令...
if %thermalVersion%==0 (
	adb pull /vendor/etc/.tp/ "%OUT_DIR%"
)else (
	adb pull /vendor/etc/thermal/. "%OUT_DIR%"
)
if %errorlevel% neq 0 (
    echo 错误: adb pull命令执行失败
    echo 请确保:
    echo 1. adb已正确安装并在PATH中
    echo 2. 设备已连接并启用USB调试
    echo 3. 设备上存在该文件路径
    pause
    exit /b 1
)
echo adb pull命令执行成功

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