@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

if %1=="" (
	echo 请指定壁纸颜色
	exit /b
)

::获取屏幕分辨率
for /f "tokens=3" %%i in ('adb shell wm size 2^>nul ^| findstr "Physical size"') do set SCREEN_SIZE=%%i
if "%SCREEN_SIZE%"=="" (
    echo 警告: 无法获取屏幕分辨率，使用默认分辨率 1080x1920
    set SCREEN_SIZE=1080x1920
) else (
    echo 屏幕分辨率: %SCREEN_SIZE%
)

:: 解析宽度和高度
for /f "tokens=1 delims=x" %%w in ("%SCREEN_SIZE%") do set WIDTH=%%w
for /f "tokens=2 delims=x" %%h in ("%SCREEN_SIZE%") do set HEIGHT=%%h

set "color=%1"
set wallpaper=%color%_wallpaper.png

:: 调用 PowerShell 处理首字母大写
for /f "delims=" %%A in ('powershell -nologo -command "$str='%color%'; $str.Substring(0,1).ToUpper() + $str.Substring(1)"') do (
    set "color=%%A"
)

:: 使用PowerShell创建指定颜色图片
if exist %wallpaper% del %wallpaper%
powershell -Command "Add-Type -AssemblyName System.Drawing; $bmp = New-Object System.Drawing.Bitmap(%WIDTH%, %HEIGHT%); $g = [System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::%color%); $bmp.Save('%wallpaper%', [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()" >nul 2>&1
if exist %wallpaper% (
    goto :push_and_set
)
echo 错误: 无法创建指定颜色壁纸文件
pause
exit /b 1


:push_and_set
:: 推送壁纸到设备
echo 正在推送壁纸到设备...
adb push %wallpaper% /sdcard/%wallpaper% >nul 2>&1
if %errorlevel% neq 0 (
    echo 错误: 无法推送文件到设备
    pause
    exit /b 1
)

echo 壁纸已生成,路径：/sdcard/%wallpaper%
echo 请在设备上手动设置壁纸
::adb shell am start -a android.intent.action.VIEW -d file:///sdcard/%wallpaper% -t image/*
adb shell am start -a android.intent.action.ATTACH_DATA -d file:///sdcard/%wallpaper% -t image/* --ez set-wallpaper true
pause
endlocal