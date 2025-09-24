@echo off

rem mtk thermal config decrypt
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 检查thermal策略
for /f %%a in ('adb shell getprop ro.vendor.mtk_thermal_2_0') do set thermalVer=%%a
if not %thermalVer%=="" (
	echo ro.vendor.mtk_thermal_2_0 = %thermalVer%
)

:: 设置主目录路径
set "MAIN_DIR=C:\Users\59901733\Desktop\Thermal_Config_Tool_exe_v1.1942.1\thermal_config_tool_V1.20.0_dev\decrypt"

:: 检查主目录是否存在
if not exist "%MAIN_DIR%" (
    echo 错误: 主目录不存在: %MAIN_DIR%
    pause
    exit /b 1
)

:: 获取当前日期 (格式: YYYY-MM-DD)
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do (
    if not "%%I"=="" set datetime=%%I
)
set "CURRENT_DATE=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%"

:: 创建日期文件夹
set "DATE_FOLDER=%MAIN_DIR%\%CURRENT_DATE%"
:: 检查日期文件夹是否存在，存在则删除
if exist "%DATE_FOLDER%" (
    rd /s /q "%DATE_FOLDER%"
)
mkdir "%DATE_FOLDER%"
if !errorlevel! neq 0 (
	echo 错误: 无法创建目录 %DATE_FOLDER%
	pause
	exit /b 1
)
echo thermal文件目录创建成功: %DATE_FOLDER%

:: 执行adb pull命令
echo 正在执行adb pull命令...
adb pull /vendor/etc/thermal/. "%DATE_FOLDER%"
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
cd "%DATE_FOLDER%"
for /r %%f in (*.conf) do (
	if exist "%%f" (
        set "filename=%%~nf"
        copy "%%f" "!filename!.mtc" >nul
    )
)

copy "%MAIN_DIR%"\forfiles.exe %DATE_FOLDER%
copy "%MAIN_DIR%"\decrypt.exe %DATE_FOLDER%
copy "%MAIN_DIR%"\decrypt_all_config.bat %DATE_FOLDER%

call decrypt_all_config.bat
if %errorlevel% neq 0 (
    echo 警告: 解密脚本执行可能有问题
)

:: 删除所有 .mtc 文件
del *.mtc

start %DATE_FOLDER%
pause