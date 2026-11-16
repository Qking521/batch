@echo off
setlocal
echo ============================================================================
echo powersd deployment - prerequisites
echo ============================================================================
echo   [require] arm64-v8a device
echo   [require] ro.debuggable=1            (adb root must work)
echo   [require] dm-verity disabled         (adb remount must work)
echo   [require] NDK on this PC             (ANDROID_NDK_ROOT or local.properties)
echo ============================================================================

echo.
echo [1/6] Locating NDK...
set NDK_CLANG=%ANDROID_NDK_ROOT%\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android24-clang.cmd
echo NDK_CLANG=%NDK_CLANG%
if not exist "%NDK_CLANG%" (
  echo [ERROR] clang not found: !NDK_CLANG!
  exit /b 1
)

echo.
echo [2/6] Compiling powersd.c
call "%NDK_CLANG%" -O2 -o "%~dp0powersd" "%~dp0powersd.c" || exit /b 1

echo.
echo [3/6] Installing to /system...
call :remount

echo [4/6]Pushing powersd + powersd.rc...
adb push "%~dp0powersd" /data/local/tmp/powersd || exit /b 1
adb push "%~dp0powersd.rc" /data/local/tmp/powersd.rc || exit /b 1

echo [5/6]Installing binary + init service...
adb shell "stop powersd 2>/dev/null; rm -f /system/bin/powersd /system/etc/init/powersd.rc; cp /data/local/tmp/powersd /system/bin/powersd; chmod 755 /system/bin/powersd; chcon u:object_r:shell_exec:s0 /system/bin/powersd; cp /data/local/tmp/powersd.rc /system/etc/init/powersd.rc; chmod 644 /system/etc/init/powersd.rc; chcon u:object_r:system_file:s0 /system/etc/init/powersd.rc" || exit /b 1

echo [6/6]Rebooting to register init service...
adb reboot
adb wait-for-device
adb root
adb wait-for-device
adb shell "getprop init.svc.powersd"

:: remount 操作（静默执行，不显示中间结果）
:remount
(
    adb root
    adb remount -R
    adb wait-for-device
    adb root
    adb remount -R
    adb wait-for-device
) >nul 2>&1
    exit /b 0

endlocal
