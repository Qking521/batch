@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for __disablepowerhal.bat
:: ============================================================
adb wait-for-device

adb root
adb shell "setprop persist.vendor.powerhal.enable 0"
adb reboot
chcp 65001 >nul
setlocal