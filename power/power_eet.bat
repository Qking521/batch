@echo off
setlocal EnableDelayedExpansion

set "cmd=%~1"
set "param1=%~2"
set "param2=%~3"

if "%cmd%"=="eet" goto :eet_test

echo Unknown command: %1
goto usage
exit /b

:usage
echo.
echo 用法: %~nx0 ^<policy^> ^<freq^>
echo   policy : cpufreq policy 编号, such as 0, 4, 6
echo   freq   : available frequency, 6500000, 2000000. 25000000
echo.
echo Examples:
echo   power eet 0 650000
echo.
exit /b 1

:eet_test

    if "%param1%"=="restore" goto :eet_restore
    if "%param1%"=="" goto :usage
    if "%param2%"=="" goto :usage

    call :env_check
    if %ERRORLEVEL% neq 0 (
        exit /b 1
    )

    set "POLICY=%~2"
    set "FREQ=%~3"

    set "SCRIPT_DIR=%~dp0"
    set "SH_SCRIPT=%SCRIPT_DIR%power_eet.sh"

    set "DEFAULT_GOVERNOR="
    if "%DEFAULT_GOVERNOR%"=="" (
        for /f "usebackq delims=" %%g in (`adb shell cat /sys/devices/system/cpu/cpufreq/policy%POLICY%/scaling_governor 2^>nul`) do (
            set "DEFAULT_GOVERNOR=%%g"
        )
        echo DEFAULT_GOVERNOR=%DEFAULT_GOVERNOR%
    )

    echo ============================================
    echo   设置 CPU Policy%POLICY% 固定频点 %FREQ%
    echo ============================================
    echo.

    rem 将本地 shell 脚本通过 stdin 传给设备端 sh 执行，避免额外 push 文件
    adb shell "sh -s %POLICY% %FREQ% %DEFAULT_GOVERNOR%" < "%SH_SCRIPT%"
    set "RET=%ERRORLEVEL%"

    if "%RET%"=="0" (
        echo [OK] 脚本执行完成
    ) else (
        echo [FAIL] 脚本执行失败，错误码: %RET%
    )
    exit /b %RET%

:env_check
    echo ============================================
    echo   检查 dhrystone 进程
    echo ============================================
    set "DHRY_PID="
    for /f "usebackq delims=" %%p in (`adb shell "ps -ef | grep dhrystone.sh | grep -v grep"`) do (
        set "DHRY_PID=%%p"
    )
    if defined DHRY_PID (
        echo [INFO] 检测到 dhrystone 进程已启动...
        exit /b 0
    ) else (
        echo [INFO] 未检测到dhrystone进程，请先执行dhrystone进程 "perf ds push && perf ds start"
        exit /b 1
    )
    exit /b

:eet_restore
    set "SCRIPT_DIR=%~dp0"
    set "SH_SCRIPT=%SCRIPT_DIR%power_eet.sh"
    adb shell "sh -s restore" < "%SH_SCRIPT%"
    exit /b



