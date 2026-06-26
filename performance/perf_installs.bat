@echo off
:: perf_installs.bat - 安装性能辅助工具apk
chcp 65001 >nul
setlocal

:: 检查参数
if "%~1"=="" goto :show_help
if /i "%~1"=="help" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%1"=="ds" goto dhrystone
if /i "%1"=="gl" goto webGL

echo [错误]: 未知工具指令: %1
goto :show_help

:show_help
echo.
echo 性能工具安装器
echo =======================
echo 用法: power install [tool_name]
echo.
echo 可用工具:
echo   ds   - 安装并配置 dhrystone 测试CPU性能的工具.
echo   gl   - 安装并配置 dhrystone 测试GPU性能的工具.
echo.
echo 示例:
echo   perf install ds
exit /b 1

:dhrystone
set DHRYSTONE_FILE_PATH=%SCRIPT_DIR%apks\dhrystone-7.0.apk
adb install --bypass-low-target-sdk-block %DHRYSTONE_FILE_PATH%
exit /b

:webGL
set WebGL_FILE_PATH=%SCRIPT_DIR%apks\WebGLSamples_Aquarium.apk
adb install --bypass-low-target-sdk-block %WebGL_FILE_PATH%
exit /b

