@echo off
:: ============================================================
:: Author: Antigravity Pair Program
:: Date: 2026-07-20
:: Description: Optimized script for windows_clear.bat
:: ============================================================
del /f /s /q %systemdrive%\*.tmp
del /f /s /q %systemdrive%\*._mp
del /f /s /q %systemdrive%\*.gid
del /f /s /q %systemdrive%\*.chk
del /f /s /q %systemdrive%\*.old
chcp 65001 >nul
setlocal
del /f /s /q %windir%\*.bak
del /f /s /q %windir%\temp\*.*
del /f /s /q %systemdrive%\*.sqm
del /f /s /q %windir%\SoftwareDistribution\Download\*.*
del /f /s /q "%userprofile%\cookies\*.*"
del /f /s /q "%userprofile%\recent\*.*"
del /f /s /q "%userprofile%\local settings\temporary internet files\*.*"
del /f /s /q "%userprofile%\local settings\temp\*.*"
del /f /s /q %userprofile%\appdata\local\temp\*.*