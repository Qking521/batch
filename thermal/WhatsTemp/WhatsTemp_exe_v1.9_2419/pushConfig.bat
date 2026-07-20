@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for pushConfig.bat
:: ============================================================
adb shell "mkdir -p /sdcard/WhatsTemp/"
adb push tool.config /sdcard/WhatsTemp/
pause
chcp 65001 >nul
setlocal