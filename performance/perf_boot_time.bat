@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ============================================================
:: Reboot -> wait for desktop -> capture bugreport -> unzip -> open
:: Output dir: OUT\performance\boot_time_<original bugreport name>
:: ============================================================

:: 1. Reboot device
echo [1/4] Rebooting device...
adb reboot
if errorlevel 1 (
    echo [ERROR] Failed to send reboot command.
    exit /b 1
)

:: 2. Wait for device reconnect and boot complete (desktop shown)
echo [2/4] Waiting for device to reboot and show desktop...
adb wait-for-device
if errorlevel 1 (
    echo [ERROR] Waiting for device timed out.
    exit /b 1
)

:wait_boot
set "BOOT="
for /f "tokens=1 delims= " %%b in ('adb shell getprop sys.boot_completed 2^>nul') do set "BOOT=%%b"
if not "%BOOT%"=="1" (
    timeout /t 2 /nobreak >nul
    goto :wait_boot
)
echo Device has booted, desktop shown.

:: 3. Generate filename and capture bugreport
for /f "tokens=1 delims= " %%a in ('adb shell getprop ro.product.device 2^>nul') do set "model=%%a"
if not exist "%MODULE_OUT_DIR%" mkdir "%MODULE_OUT_DIR%"

set "BASE=bugreport_%model%_%FORMAT_TIME%"
set "ZIPFILE=%MODULE_OUT_DIR%\%BASE%.zip"
set "OUTDIR=%MODULE_OUT_DIR%\boot_time_%BASE%"

echo [3/4] Capturing bugreport: %BASE%.zip
adb bugreport "%ZIPFILE%"
if errorlevel 1 (
    echo [ERROR] Failed to capture bugreport.
    exit /b 1
)

:: 4. Unzip to boot_time_xxx folder
echo [4/4] Extracting to: %OUTDIR%
where 7z >nul 2>&1
if %errorlevel%==0 (
    7z x "%ZIPFILE%" -o"%OUTDIR%" -y >nul 2>&1
) else (
    unzip -o "%ZIPFILE%" -d "%OUTDIR%" >nul 2>&1
)

:: 5. Open output folder
if exist "%OUTDIR%" (
    start "" "%OUTDIR%"
    echo [DONE] Folder: %OUTDIR%
) else (
    echo [WARN] Output folder not created, check: %OUTDIR%
)

endlocal
exit /b 0