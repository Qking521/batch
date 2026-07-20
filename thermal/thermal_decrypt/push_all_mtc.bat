@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for push_all_mtc.bat
:: ============================================================
forfiles.exe -pmtc -s -m*.mtc -c"cmd /c adb push \"@FILE\" /data"
pause
chcp 65001 >nul
setlocal