chcp 65001 >nul
setlocal enabledelayedexpansion

set "param1=%~2"
if "%param1%"=="" (
    echo 请传入apk具体路径, 使用示例:
    echo win de ^<apk-file^>
    exit /b 1
)
if not exist %param1% (
    echo "提供的apk文件不存在"， win de apk
    exit /b 1
)
echo MODULE_OUT_DIR=%MODULE_OUT_DIR%
echo 更多信息:java -jar apktool.jar -h
echo 官网地址:https://bitbucket.org/iBotPeaches/apktool/downloads/

set "APKTOOL_PATH=%SCRIPT_DIR%windows_tools\apktool.jar"

for %%i in ("%param1%") do set "APK_NAME=%%~ni"
if exist %MODULE_OUT_DIR%\%APK_NAME% (
    echo 已存在反编译目录，正在打开
    start %MODULE_OUT_DIR%\%APK_NAME%
    exit /b 0
)
echo 当前apktool版本号:
java -jar %APKTOOL_PATH% v
java -jar %APKTOOL_PATH% d  -f %param1% -o %MODULE_OUT_DIR%\%APK_NAME%
start %MODULE_OUT_DIR%
