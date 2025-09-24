@echo off
chcp 65001 >nul

REM 创建临时目录
if not exist temp mkdir temp

:: [1/4] 打开最近应用界面...
adb shell input keyevent KEYCODE_APP_SWITCH
timeout /t 2 /nobreak >nul

:: [2/4] 获取当前UI布局信息...
adb shell uiautomator dump /sdcard/ui_dump.xml >nul
adb pull /sdcard/ui_dump.xml temp/ui_dump.xml >nul 2>&1

if not exist temp\ui_dump.xml (
    echo 最近列表已清理
    exit /b
)

:: [3/4] 分析UI布局，查找Clear all按钮...

REM 只搜索"Clear all"按钮
set "clear_found=false"
set "clear_x="
set "clear_y="

:: 正在搜索Clear all按钮...

REM 搜索"Clear all"按钮文本
findstr /i "Clear all" temp\ui_dump.xml >nul
if not errorlevel 1 (
    goto extract_coordinates
)else (
	echo 最近列表已清理
    exit /b
)

:extract_coordinates
:: 解析Clear all按钮坐标...
for /f "tokens=*" %%a in ('findstr /i "Clear all" temp\ui_dump.xml') do (
    call :parse_bounds "%%a"
)
goto click_button

:parse_bounds
set "line=%~1"
findstr /i "Clear all" ui_dump.xml > clear_all_line.txt
if exist clear_all_line.txt (
    for /f "delims=" %%a in (clear_all_line.txt) do (
        set "line=%%a"
        echo 找到Clear all元素
        
        REM 提取bounds属性中的坐标
        for /f "tokens=*" %%b in ('echo !line! ^| findstr /r "bounds="') do (
            set "bounds_line=%%b"
            
            REM 使用更简单的方法提取坐标
            for /f "tokens=2 delims=[]" %%c in ('echo !bounds_line! ^| findstr /o bounds=') do (
                set "coords=%%c"
                
                REM 解析第一个坐标对 [x1,y1]
                for /f "tokens=1,2 delims=," %%d in ("!coords!") do (
                    set "x1=%%d"
                    set "y1=%%e"
                )
                
                REM 获取第二个坐标对，计算中心点
                for /f "tokens=3 delims=[]" %%f in ('echo !bounds_line!') do (
                    for /f "tokens=1,2 delims=," %%g in ("%%f") do (
                        set "x2=%%g"
                        set "y2=%%h"
                        
                        REM 计算中心点
                        set /a clear_x=(!x1!+!x2!)/2
                        set /a clear_y=(!y1!+!y2!)/2
                        set "found=true"
                        
                        echo Clear All按钮位置: (!clear_x!, !clear_y!)
                        goto click_button
                    )
                )
            )
        )
    )
)
goto :eof

:click_button
if "%clear_found%"=="true" (
    if defined clear_x if defined clear_y (
        adb shell input tap %clear_x% %clear_y%
        timeout /t 1 /nobreak >nul
        goto cleanup
    )
)

:cleanup
REM 清理临时文件
if exist temp\ui_dump.xml del temp\ui_dump.xml
if exist temp rmdir temp
adb shell rm /sdcard/ui_dump.xml 2>nul
adb shell input keyevent KEYCODE_HOME