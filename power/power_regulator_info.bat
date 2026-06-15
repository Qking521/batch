@echo off
chcp 65001 >nul
setlocal

if /i "%~1"=="help" goto :show_help
if /i "%~1"=="-h" goto :show_help

goto :process

:show_help
echo Regulator 信息工具
echo =======================
echo 用法: power regu [help]
echo.
echo 可用命令:
echo   (空)     - 查看当前所有供电单元 (Regulator) 的详细信息 (默认动作).
echo   help     - 显示此帮助信息.
echo.
exit /b

:process
:: 配置临时文件路径
set "LOCAL_SH=%TEMP%\regu_process.sh"
set "REMOTE_SH=/data/local/tmp/regu_process.sh"

:: 1. 提取嵌入的 Shell 脚本
for /f "tokens=1 delims=:" %%n in ('findstr /n "^:BEGIN_SHELL_SCRIPT" "%~f0"') do set /a SKIP=%%n
more +%SKIP% "%~f0" > "%LOCAL_SH%"

:: 2. 推送到设备并处理换行符，然后执行
adb push "%LOCAL_SH%" %REMOTE_SH% >nul 2>&1
adb shell "sed -i 's/\r//' %REMOTE_SH% && sh %REMOTE_SH%"

:: 3. 清理 PC 端临时文件
del "%LOCAL_SH%" >nul 2>&1
exit /b

:: ============================================================
:: 嵌入式 Linux Shell 脚本开始
:: ============================================================
:BEGIN_SHELL_SCRIPT
#!/bin/sh
echo "正在获取供电单元信息 (Regulators)..."
printf '%-3s %-15s %-30s %-10s\n' 'ID' 'TYPE' 'NAME' 'USERS'
echo "----------------------------------------------------------------"
for d in /sys/class/regulator/regulator.[0-9]*; do
  [ -d "$d" ] || continue
  id=${d##*regulator.}
  name=$(cat $d/name 2>/dev/null || echo 'N/A')
  type=$(cat $d/type 2>/dev/null || echo 'N/A')
  num_users=$(cat $d/num_users 2>/dev/null || echo 'N/A')
  printf '%-3s %-15s %-30s %-10s\n' "$id" "$type" "$name" "$num_users"
done | sort -n