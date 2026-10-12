@echo off
:: ============================================================
:: Author: WangQiang
:: Date:   2026-09-20
:: Desc:   Convert PowerMonitor CSV to Battery Historian format
:: Usage:  power pm2bh <csv_file>
::         csv_file: PowerMonitor 导出的 CSV，文件名须为 YYYY-MM-DD-HH-mm-ss.csv
:: ============================================================
chcp 65001 >nul
setlocal EnableDelayedExpansion

set "param1=%~2"

if /i "!param1!"=="-h"   goto :usage
if /i "!param1!"=="help" goto :usage
if "!param1!"==""        goto :usage

:: 验证输入文件存在
if not exist "!param1!" (
    echo [ERROR] 找不到 CSV 文件: !param1!
    exit /b 1
)

:: 验证 py 脚本存在
set "PY_SCRIPT=%SCRIPT_DIR%power_pm2bh.py"
if not exist "%PY_SCRIPT%" (
    echo [ERROR] 找不到脚本: %PY_SCRIPT%
    exit /b 1
)

:: 取输入文件的完整路径（供 python 正确找到源文件）
for %%F in ("!param1!") do set "CSV_FULL=%%~fF"
for %%F in ("!param1!") do set "CSV_NAME=%%~nxF"

:: 切换到 OUT 目录，使 python 脚本的 open("BH-...") 直接落到该目录
pushd "%MODULE_OUT_DIR%"

echo 正在转换中
python "%PY_SCRIPT%" "!CSV_FULL!"
set "_ERR=%ERRORLEVEL%"

popd

if !_ERR! neq 0 (
    echo [ERROR] pm2bh 转换失败，退出码: !_ERR!
    exit /b !_ERR!
)

:: 找到生成的 BH- 文件并提示
set "BH_FILE=%MODULE_OUT_DIR%\BH-!CSV_NAME!"
if exist "!BH_FILE!" (
    echo [OK] 转换完成: !BH_FILE!
    start "" "%MODULE_OUT_DIR%"
) else (
    echo [WARN] 未找到预期输出文件: !BH_FILE!
    echo        请检查 python 脚本的实际输出。
)

exit /b 0

:usage
echo.
echo Usage: power pm2bh ^<csv_file^>
echo.
echo Description:
echo   将 PowerMonitor 导出的 CSV 转换为 Battery Historian 可读格式。
echo   输出文件（BH-^<原文件名^>.csv）保存到 power 的 OUT 目录。
echo.
echo Arguments:
echo   csv_file   PowerMonitor 导出的 CSV 文件路径
echo              文件名格式须为: YYYY-MM-DD-HH-mm-ss.csv
echo.
echo Examples:
echo   power pm2bh 2025-01-09-19-31-28.csv
echo   power pm2bh D:\data\2025-01-09-19-31-28.csv
echo.
exit /b 0
