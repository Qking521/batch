@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for stopLogging.bat
:: ============================================================
adb shell am stopservice -n com.example.mtk10263.whatsTemp/.GetInfo_Service
chcp 65001 >nul
setlocal