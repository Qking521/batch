@echo off
call "%~dp0init.bat"
set HTTP_PROXY=http://127.0.0.1:10809
set HTTPS_PROXY=http://127.0.0.1:10809

@REM  mediatek platform
doskey mtk=%USERPROFILE%\batScript\mediatek\mtklog.bat $*

@REM android
doskey ad=%USERPROFILE%\batScript\android\android_all.bat $*

@REM power
doskey power=%USERPROFILE%\batScript\power\power_all.bat $*

@REM performance
doskey perf=%USERPROFILE%\batScript\performance\perf_all.bat $*

@REM thermal
doskey therm=%USERPROFILE%\batScript\thermal\thermal_all.bat $*

@REM windows
doskey win=%USERPROFILE%\batScript\windows\windows_all.bat $*
@REM port forward for wsl
doskey usbip=%USERPROFILE%\batScript\windows\windows_all.bat usbip $*