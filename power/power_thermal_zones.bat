@echo off
chcp 65001 >nul
setlocal

:: 映射参数到 Shell 内部动作
set "ACTION=info"
if /i "%~1"=="help" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="dis" set "ACTION=disable"
if /i "%~1"=="en" set "ACTION=enable"
if not "%~1"=="" if not "%ACTION%"=="disable" if not "%ACTION%"=="enable" (
    echo [错误]: 未知参数 "%~1"
    goto :show_help
)

goto :process

:show_help
echo Thermal Zones 控制工具
echo =======================
echo 用法: power tz [en/dis/help]
echo.
echo 可用命令:
echo   (空)    - 查看当前所有温度传感器信息 (默认动作)
echo   en      - 恢复先前禁用的传感器 (根据记录文件)
echo   dis     - 记录并禁用当前开启的传感器
echo   help    - 显示此帮助信息
echo.
exit /b

:process

:: 配置临时文件路径
set "LOCAL_SH=%TEMP%\tz_process.sh"
set "REMOTE_SH=/data/local/tmp/tz_process.sh"

:: 1. 提取嵌入的 Shell 脚本,%~f0: 代表当前批处理文件的完整路径,即从当前bat脚本查找BEGIN_SHELL_SCRIPT开头的行号
for /f "tokens=1 delims=:" %%n in ('findstr /n "^:BEGIN_SHELL_SCRIPT" "%~f0"') do set /a SKIP=%%n
more +%SKIP% "%~f0" > "%LOCAL_SH%"

:: 2. 推送到设备并处理换行符，然后执行
adb push "%LOCAL_SH%" %REMOTE_SH% >nul 2>&1
adb shell "sed -i 's/\r//' %REMOTE_SH% && sh %REMOTE_SH% %ACTION%"

:: 3. 清理 PC 端临时文件
del "%LOCAL_SH%" >nul 2>&1
exit /b

:: ============================================================
:: 嵌入式 Linux Shell 脚本开始
:: ============================================================
:BEGIN_SHELL_SCRIPT
#!/bin/sh
ACTION=$1
LOG_FILE="/data/local/tmp/orig_enabled_tz.txt"

case "$ACTION" in
    "disable")
        echo "正在记录并禁用当前开启的温度传感器 (Thermal Zones)..."
        rm -f "$LOG_FILE"
        # 使用 sort -V 进行自然排序 (zone1, zone2, zone10)
        for d in $(ls -d /sys/class/thermal/thermal_zone* | sort -V); do
            mode=$(cat $d/mode 2>/dev/null)
            if [ "$mode" = "enabled" ]; then
                echo $d >> "$LOG_FILE"
                echo "disabled" > $d/mode
                type=$(cat $d/type 2>/dev/null || echo 'unknown')
                echo "[已禁用] $d ($type)"
            fi
        done
        [ -f "$LOG_FILE" ] && echo "\n操作完成。记录在: $LOG_FILE" || echo "\n无需操作：没有发现处于开启状态的传感器。"
        ;;

    "enable")
        echo "正在恢复先前被禁用的温度传感器..."
        if [ ! -f "$LOG_FILE" ]; then
            echo "[警告] 未找到状态记录文件 $LOG_FILE，可能未执行过 tz-dis 或已恢复。"
            exit 1
        fi
        for d in $(cat "$LOG_FILE"); do
            if [ -d "$d" ]; then
                echo "enabled" > $d/mode
                type=$(cat $d/type 2>/dev/null || echo 'unknown')
                echo "[已恢复] $d ($type)"
            fi
        done
        rm -f "$LOG_FILE"
        echo "\n恢复完成。"
        ;;

    "info")
        echo "正在获取温度传感器信息 (NTC)..."
        printf '%-3s %-25s %-8s %-10s %-10s\n' 'ID' 'TYPE' 'TEMP(C)' 'POLICY' 'MODE'
        echo "--------------------------------------------------------------------------"
        for d in $(ls -d /sys/class/thermal/thermal_zone* | sort -V); do
            id=${d##*zone}
            type=$(cat $d/type 2>/dev/null || echo 'unknown')
            raw_temp=$(cat $d/temp 2>/dev/null)

            # 温度换算
            if [ -z "$raw_temp" ]; then
                temp='N/A'
            else
                temp=$((raw_temp / 1000))
            fi

            policy=$(cat $d/policy 2>/dev/null || echo 'N/A')
            mode=$(cat $d/mode 2>/dev/null || echo 'N/A')

            printf '%-3s %-25s %-8s %-10s %-10s\n' "$id" "$type" "$temp" "$policy" "$mode"
        done
        ;;
esac