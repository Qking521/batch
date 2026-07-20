@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo SCRIPT_DIR=%SCRIPT_DIR%
python3 %SCRIPT_DIR%EET\modify_cpu_frequence.py