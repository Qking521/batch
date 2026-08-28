@echo off
:: ============================================================
:: Author: wangqiang
:: Date:   2026-08-28
:: Desc:   MTK 平台 Thermal 配置文件导出与解密工具
:: Usage:  therm config decrypt
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 1. 检查 MTK Thermal 策略版本 (2.0 或 1.0)
set "thermalVersion=-1"
for /f "delims=" %%a in ('adb shell getprop ro.vendor.mtk_thermal_2_0 2^>nul') do set "thermalVersion=%%a"
echo [INFO] MTK_THERMAL_VERSION = !thermalVersion!

:: 2. 设置路径 (SCRIPT_DIR 末尾已有斜杠)
set "DECRYPT_DIR=%SCRIPT_DIR%thermal_decrypt"
set "MODULE_OUT_DIR=%MODULE_OUT_DIR%\thermal_decrypt\%FORMAT_TIME%"

if not exist "%MODULE_OUT_DIR%" mkdir "%MODULE_OUT_DIR%"
echo [INFO] Thermal 导出目录: %MODULE_OUT_DIR%

:: 3. 从设备拉取 Thermal 配置文件
echo [INFO] 正在从设备拉取 thermal 配置文件...
if "!thermalVersion!"=="0" (
    adb pull /vendor/etc/.tp/. "%MODULE_OUT_DIR%"
) else (
    adb pull /vendor/etc/thermal/. "%MODULE_OUT_DIR%"
)

:: 4. 进入输出目录执行格式转换与解密
pushd "%MODULE_OUT_DIR%"

if not exist "%DECRYPT_DIR%\decrypt.exe" (
    echo [ERROR] 未找到解密工具: %DECRYPT_DIR%\decrypt.exe
    popd
    exit /b 1
)

for /r %%f in (*.conf) do (
    if exist "%%f" (
        set "filename=%%~nf"
        copy /y "%%f" "!filename!.mtc" >nul 2>&1
    )
)

copy /y "%DECRYPT_DIR%\decrypt.exe" . >nul 2>&1

:: 对所有 .mtc 文件调用 decrypt.exe 进行解密
for %%f in (*.mtc) do (
    if exist "%%f" (
        echo [INFO] 正在解密: %%f
        decrypt.exe "%%f" >nul 2>&1
    )
)

:: 清理临时 .exe 与 .mtc 文件
del /f /q decrypt.exe >nul 2>&1
del /f /q *.mtc >nul 2>&1

echo [OK] Thermal 配置文件解密完成.

popd

start "" "%MODULE_OUT_DIR%"
exit /b 0