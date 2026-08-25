@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

set "SH_SCRIPT=%SCRIPT_DIR%power_wallpaper.sh"
set "WALLPAPER_DIR=%SCRIPT_DIR%power_wallpapers"
set "MAGIACK_FILE=%SCRIPT_DIR%power_tools\magick.exe"

:: 帮助信息
if /i "%~1"=="help" goto :usage
if /i "%~1"=="-h"   goto :usage
if "%~1"==""        goto :usage


set "color=%~1"
set "action=%~2"
if "!action!"=="" set "action=set"

:: 仅允许 set / view
if /i "!action!"=="set"  goto :resolve_wallpaper
if /i "!action!"=="view" goto :resolve_wallpaper
echo [ERROR] 未知 action: !action! (支持: set ^| view)
goto :usage

if not exist "%SH_SCRIPT%" (
    echo [ERROR] 找不到 shell 脚本: %SH_SCRIPT%
    exit /b 1
)

:resolve_wallpaper
:: 先检查是否为固定资源壁纸（直接取 power_wallpapers 目录中的文件）
set FIXED_COLOR_LIST=fruit
for %%f in (%FIXED_COLOR_LIST%) do (
	if /i "%%f"=="!color!" (
		set "wallpaper=!color!_wallpaper.png"
		set "local_wallpaper=%WALLPAPER_DIR%\!wallpaper!"
		echo local_wallpaper=%local_wallpaper%
		if exist "!local_wallpaper!" (
			echo [INFO] 使用固定资源壁纸: !local_wallpaper!
			goto :push_and_set
			exit /b 0
		) else (
			echo [ERROR] 找不到固定资源壁纸: !local_wallpaper!
			exit /b 1
		)
	)
)

:: ============================================================
:general_wallpaper
:: ============================================================
call :screen_size
set "wallpaper=!color!_!WIDTH!x!HEIGHT!_wallpaper.png"
echo wallpaper=%wallpaper%
set "local_wallpaper=%WALLPAPER_DIR%\!wallpaper!"

:: 如果文件还不存在则用 PowerShell 生成
if not exist "!local_wallpaper!" (
    :: 首字母大写（PowerShell.Drawing 需要标准颜色名称）
    set "color_cap=!color!"
    for /f "delims=" %%A in ('powershell -nologo -command "$s='!color!'; $s.Substring(0,1).ToUpper()+$s.Substring(1)"') do set "color_cap=%%A"

    echo [INFO] 正在生成 !color_cap! 纯色壁纸
    ::powershell -Command "Add-Type -AssemblyName System.Drawing; $bmp = New-Object System.Drawing.Bitmap(%WIDTH%, %HEIGHT%); $g = [System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::%color%); $bmp.Save('%local_wallpaper%', [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()" >nul 2>&1
	%MAGIACK_FILE% -size !WIDTH!x!HEIGHT! xc:!color_cap! "%local_wallpaper%"

    if not exist "!local_wallpaper!" (
        echo [ERROR] 无法创建指定颜色的壁纸文件，请确认颜色名称是否为合法 .NET 颜色
        exit /b 1
    )
    echo [OK] 壁纸已生成: !local_wallpaper!
)

:: ============================================================
:push_and_set
:: ============================================================
	set "remote_path=/sdcard/!wallpaper!"

	echo [INFO] 正在推送壁纸到设备: !remote_path!
	adb push "!local_wallpaper!" "!remote_path!" >nul 2>&1
	if !ERRORLEVEL! neq 0 (
		echo [ERROR] 推送壁纸失败
		exit /b 1
	)
	echo [OK] 推送成功: !remote_path!

	:: 调用 shell 脚本执行设备侧操作
	adb shell "sh -s !action! !remote_path!" < "%SH_SCRIPT%"
	if !ERRORLEVEL! neq 0 (
		echo [FAIL] 设备侧操作失败
		exit /b 1
	)
exit /b 0

:: 获取屏幕分辨率
:screen_size
	set "SCREEN_SIZE="
	for /f "tokens=3" %%i in ('adb shell wm size 2^>nul ^| findstr "Physical size"') do set "SCREEN_SIZE=%%i"
	if "!SCREEN_SIZE!"=="" (
		echo [WARN] 无法获取屏幕分辨率，使用默认 1080x1920
		set "SCREEN_SIZE=1080x1920"
	) else (
		echo [INFO] 屏幕分辨率: !SCREEN_SIZE!
	)
	for /f "tokens=1 delims=x" %%w in ("!SCREEN_SIZE!") do set "WIDTH=%%w"
	for /f "tokens=2 delims=x" %%h in ("!SCREEN_SIZE!") do set "HEIGHT=%%h"
exit /b 0

:: ============================================================
:usage
:: ============================================================
echo.
echo 用法: power wallpaper ^<color^> [action]
echo.
echo 参数:
echo   color   壁纸颜色，如 black、white、red、gray 等 .NET 标准颜色名
echo           特殊值: fruit (使用预置图片)
echo   action  set   设置壁纸到系统（默认）
echo           view  仅在设备上预览图片
echo.
echo 示例:
echo   power wallpaper black
echo   power wallpaper white set
echo   power wallpaper gray view
echo   power wallpaper fruit
echo.
exit /b 0