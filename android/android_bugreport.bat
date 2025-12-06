@echo off
:: === 1. 获取额外参数 ===
set "param=%~1"
set "EXT_INFO="
if not "%param%"=="" (
	set "EXT_INFO=_%param%"
)
for /f "delims= " %%a in ('adb shell getprop ro.product.board') do set model=%%a

:: === 2. 创建 bugreport 文件夹 ===
::获取脚本所在目录，自带反斜杠
set "scriptDir=%~dp0"
set OUT_DIR=%userprofile%\batScript\OUT\bugreport
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

:: === 3. 生成 bugreport zip 文件 ===
set ZIPFILE=%OUT_DIR%\%model%_bugreport%EXT_INFO%_%ftime%.zip
echo Generating bugreport: %ZIPFILE%
adb bugreport "%ZIPFILE%" > nul

:: === 4. 解压 zip 文件（使用 PowerShell） ===
set UNZIPDIR=%OUT_DIR%\%model%_bugreport%EXT_INFO%_%ftime%
echo Eracting bugreport...
:: 优先用 7z 解压
where 7z >nul 2>&1
if %errorlevel%==0 (
    7z x "%ZIPFILE%" -o"%UNZIPDIR%" -y
) else (
    :: 尝试用 unzip（cmder 自带的 msys 通常有）
    unzip -o "%ZIPFILE%" -d "%UNZIPDIR%"
)

:: === 5. 打开 bugreport*.txt 文件 ===
for %%f in ("%UNZIPDIR%\bugreport*.txt") do (
    start "" "%%f"
	echo starting bugreport...
    goto :done
)
echo UNZIPDIR=%UNZIPDIR%
for %%f in ("%UNZIPDIR%\dumpstate*.txt") do (
    start "" "%%f"
	echo starting bugreport...
    goto :done
)
:done