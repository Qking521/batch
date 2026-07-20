@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for __debug_mispeed.bat
:: ============================================================
adb shell "setprop  persist.miuibooster.debug true"
adb shell "setprop  persist.sys.debug_rtmode true"

chcp 65001 >nul
setlocal