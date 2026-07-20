@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for startLogging.bat
:: ============================================================
chcp 65001 >nul
setlocal
adb shell am force-stop com.example.mtk10263.whatsTemp
rem Launch WhatsTemp tool
adb shell am start -n com.example.mtk10263.whatsTemp/.MainActivity
rem --ei t <timeout> timeout in minutes
adb shell am startservice -n com.example.mtk10263.whatsTemp/.GetInfo_Service --ei t 0