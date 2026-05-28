@echo off
:: power_installs.bat - 安装功耗辅助工具apk
setlocal

if /i "%1"=="wt" goto whatstempeture
if /i "%1"=="wmp" goto wheresmypower

echo [错误]: 未知工具指令: %1
exit /b 1

:whatstempeture
echo [信息]: 准备安装并配置 whatstempeture
cd /d "%SCRIPT_DIR%WhatsTemp_exe_v1.9_2419"
call install_LogTool.bat
if %ERRORLEVEL% neq 0 (
    echo [错误]: WhatsTemp 安装脚本执行失败。
    exit /b %ERRORLEVEL%
)
adb shell pm grant com.example.mtk10263.whatsTemp android.permission.POST_NOTIFICATIONS
adb shell pm grant com.example.mtk10263.whatsTemp android.permission.WRITE_EXTERNAL_STORAGE
adb shell dumpsys deviceidle whitelist +com.example.mtk10263.whatsTemp
exit /b

:wheresmypower
echo [信息]: 准备安装并配置 wheresmypower
cd /d "%SCRIPT_DIR%wheresmypower
adb install -r wheresmypower.apk
call wmp-setup.bat
