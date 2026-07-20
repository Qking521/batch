@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for perf_eet.bat
:: ============================================================
chcp 65001 >nul
setlocal enabledelayedexpansion

echo SCRIPT_DIR=%SCRIPT_DIR%
python3 %SCRIPT_DIR%EET\modify_cpu_frequence.py