@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for android_package_toggle.bat
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

set cmd=%1
set param=%2

echo cmd=%cmd%, param=%param%

if /i "%cmd%"=="" goto show_help
if /i "%cmd%"=="-h" goto show_help
if /i "%cmd%"=="help" goto show_help
if /i "%cmd%"=="enable" goto toggle
if /i "%cmd%"=="disable" goto toggle

echo Unknown command: %1
goto show_help
exit /b

:show_help
echo.
echo Usage: ad [command] [param]
echo.
echo Available commands:
echo   enable               - enbale package
echo   disable              - disable package
echo Available params:
echo   google               - All package names related to Google
echo   moto                 - All package names related to Moto
echo   -h                   - Show help (alias: help).
echo.
echo Examples:
echo   ad enable google
echo   ad disable google
echo.
exit /b

:: usebackq规则换成更符合直觉的方式
:: eof是 cmd 内置的虚拟标签，代表文件结尾
:toggle
set "section=:%param%_packages"
set "found=0"
for /f "usebackq delims=" %%L in ("%~f0") do (
    set "line=%%L"
    if "!found!"=="1" (
        if "!line:~0,1!"==":" goto :eof
        for /f "tokens=2 delims==" %%P in ("!line!") do (
            echo !cmd! %%P
            if "!cmd!"=="disable" (
                adb shell pm disable-user %%P
            )else (
                adb shell pm enable %%P
            )
        )
    )
    if "!line!"=="!section!" set "found=1"
)

:: ============================================================
:: 下面是数据段区域，可以自由增删/修改。
:: 每段必须以 ":标签名_packages" 开头（冒号不能少）。
:: 段与段之间不需要空行分隔，只要下一行是 ":xxx" 就会自动截断。
:: ============================================================
 
:google_packages
Assistant=com.google.android.apps.googleassistant
Calendar=com.google.android.calendar
Chrome=com.android.chrome
Digital wellbeing=com.google.android.apps.wellbeing
Drive=com.google.android.apps.docs
Duo=com.google.android.apps.tachyon
Gboard=com.google.android.inputmethod.latin
Gmail=com.google.android.gm
Google=com.google.android.googlequicksearchbox
Google Play Movies& TV=com.google.android.videos
Google Play services=com.google.android.gms
Google Play Store=com.android.vending
Maps=com.google.android.apps.maps
Photos=com.google.android.apps.photos
YouTube=com.google.android.youtube
YouTube Music=com.google.android.apps.youtube.music
Google One=com.google.android.apps.subscriptions.red
Kids Space=com.google.android.apps.kids.home
Google contacts=com.google.android.contacts
Google Play Book=com.google.android.apps.books
Android Auto=com.google.android.projection.gearhead
Keep=com.google.android.keep
Google Voice=com.google.android.tts
Google Pay=com.google.android.apps.walletnfcrel
Google Partner Setup=com.google.android.partnersetup
Carrier Services=com.google.android.ims
test=com.roger.test
 
:moto_packages
batterytracer=com.motorola.tools.batterytracer
searchbox=com.google.android.googlequicksearchbox 
bug2go=com.motorola.bug2go
stats=com.motorola.moto_stats
 
:end_packages
