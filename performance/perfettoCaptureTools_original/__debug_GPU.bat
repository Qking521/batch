@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for __debug_GPU.bat
:: ============================================================
adb shell "setprop debug.hwui.skia_atrace_enabled true"
adb shell "setprop debug.hwui.skia_use_perfetto_track_events false"
adb shell "setprop debug.renderengine.skia_atrace_enabled true"
adb shell "setprop vendor.debug.gpu.provider meow"
adb shell "setprop debug.hwui.skia_tracing_enabled true"
chcp 65001 >nul
setlocal

adb shell "stop;start"
pause