@echo off
setlocal

echo ====================================
echo Perfetto Trace 本地服务器方案
echo ====================================
echo.

REM 检查 Python 是否安装
python --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未检测到 Python
    echo [提示] 请安装 Python 或直接访问 https://ui.perfetto.dev/
    pause
    exit /b 1
)

REM 检查是否有参数传入
if "%~1"=="" (
    echo [提示] 请拖放 .perfetto-trace 文件到此脚本上
    pause
    exit /b 1
)

REM 检查文件是否存在
if not exist "%~1" (
    echo [错误] 文件不存在: %~1
    pause
    exit /b 1
)

echo [信息] Trace 文件: %~nx1
echo [信息] 文件目录: %~dp1
echo [信息] 启动 HTTP 服务器...
echo.

REM 切换到文件所在目录
pushd "%~dp1"

REM 启动 Python HTTP 服务器
start "Perfetto-HTTP-Server" cmd /k python -m http.server 8000

REM 等待服务器启动
echo [等待] 服务器启动中...
timeout /t 3 /nobreak >nul

REM 打开浏览器
echo [信息] 正在打开浏览器...
start http://localhost:8000/%~nx1

timeout /t 2 /nobreak >nul

echo.
echo ========================================
echo [完成] 设置完成！
echo ========================================
echo.
echo 步骤1: HTTP 服务器已启动
echo        地址: http://localhost:8000
echo.
echo 步骤2: 请在浏览器中执行以下操作：
echo        1. 访问 https://ui.perfetto.dev/
echo        2. 点击 "Open trace file"
echo        3. 点击 "Open from URL"
echo        4. 输入: http://localhost:8000/%~nx1
echo        5. 点击 "Open"
echo.
echo        或者直接访问:
echo        https://ui.perfetto.dev/#!/?url=http://localhost:8000/%~nx1
echo.
echo [提示] 关闭 "Perfetto-HTTP-Server" 窗口可停止服务
echo.
pause

popd