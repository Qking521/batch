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
adb root
adb remount -R
adb push "%~dp0powersd" /data/local/tmp/powersd || exit /b 1
adb push "%~dp0powersd.rc" /data/local/tmp/powersd.rc || exit /b 1
adb shell "stop powersd; rm -f /system/bin/powersd; cp /data/local/tmp/powersd /system/bin/powersd; chmod 755 /system/bin/powersd; chcon u:object_r:shell_exec:s0 /system/bin/powersd; start powersd" || exit /b 1

endlocal
