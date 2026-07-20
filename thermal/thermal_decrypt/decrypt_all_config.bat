@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for decrypt_all_config.bat
:: ============================================================
forfiles.exe -m*.mtc -c"cmd /c decrypt.exe \"@FILE\" "
pause
chcp 65001 >nul
setlocal