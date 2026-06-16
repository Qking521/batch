@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
set "PARAM=%~1"

:: 1. 精确分类匹配
if /i "!PARAM!"==""      goto :SHOW_HELP
if /i "!PARAM!"=="help"  goto :SHOW_HELP
if /i "!PARAM!"=="-h"    goto :SHOW_HELP
if /i "!PARAM!"=="basic" ( call :CATEGORY_BASIC & goto :FINAL_END )
if /i "!PARAM!"=="pm"    ( call :CATEGORY_PM    & goto :FINAL_END )
if /i "!PARAM!"=="am"    ( call :CATEGORY_AM    & goto :FINAL_END )
if /i "!PARAM!"=="sys"   ( call :CATEGORY_SYS   & goto :FINAL_END )
if /i "!PARAM!"=="wm"    ( call :CATEGORY_WM    & goto :FINAL_END )
if /i "!PARAM!"=="file"  ( call :CATEGORY_FILE  & goto :FINAL_END )
if /i "!PARAM!"=="user"  ( call :CATEGORY_USER  & goto :FINAL_END )
if /i "!PARAM!"=="power" ( call :CATEGORY_POWER & goto :FINAL_END )

echo [提示] 未找到包含 "!PARAM!" 的具体命令。
goto :SHOW_HELP

:SHOW_HELP
echo ============================================================
echo                ADB 常用命令快捷查询助手
echo ============================================================
echo [用法] ad adbd [分类参数 / 搜索关键字]
echo.
echo [可用分类 (支持二级查询)]
echo   basic  - 基础操作 (devices, root, connect, remount)
echo   pm     - 应用管理 (install, list packages, path, clear)
echo   am     - 交互管理 (start, force-stop, broadcast, stack)
echo   sys    - 系统查询 (logcat, battery, properties, bugreport)
echo   wm     - 窗口显示 (size, density, window)
echo   file   - 文件传输 (push, pull, ls)
echo   user   - 用户管理 (list users, switch-user)
echo   power  - 电源重启 (reboot, keyevent)
echo.
echo [示例]
echo   ad adbd basic    - 查看所有基础命令
echo   ad adbd root     - 模糊搜索带 "root" 的命令
goto :FINAL_END

:CATEGORY_BASIC
echo [基础操作 (Basic)]
echo   adb devices                        - 列出所有连接的设备
echo   adb connect [IP:PORT]              - 通过网络连接设备
echo   adb disconnect                     - 断开所有网络连接
echo   adb root                           - 以 root 权限运行 adbd
echo   adb remount                        - 重新挂载系统分区为可读写
echo   adb kill-server                    - 停止 adb 服务
echo   adb start-server                   - 启动 adb 服务
echo.
exit /b

:CATEGORY_PM
echo [包管理模块 (PM)]
echo   adb shell pm list packages         - 列出所有包名 (-s:系统, -3:第三方)
echo   adb install [path_to_apk]          - 安装应用
echo   adb uninstall [package_name]       - 卸载应用
echo   adb shell pm path [package]        - 查看应用 APK 路径
echo   adb shell pm clear [package]       - 清除应用数据和缓存
echo.
exit /b

:CATEGORY_AM
echo [交互管理模块 (AM)]
echo   adb shell am start -n [cmp]        - 启动指定 Activity
echo   adb shell am force-stop [package]  - 强制停止应用
echo   adb shell am broadcast -a [action] - 发送广播
echo   adb shell am stack list            - 查看 Activity 堆栈
echo.
exit /b

:CATEGORY_SYS
echo [系统查询/调试 (Sys)]
echo   adb logcat                         - 查看实时日志 (Ctrl+C 停止)
echo   adb shell dumpsys battery          - 查看电池状态
echo   adb shell getprop [property]       - 获取系统属性
echo   adb bugreport [path]               - 导出系统调试报告
echo   adb shell settings get global [n]  - 获取全局设置
echo.
exit /b

:CATEGORY_WM
echo [窗口管理/显示 (WM)]
echo   adb shell wm size                  - 查看/修改屏幕分辨率
echo   adb shell wm density               - 查看/修改屏幕密度
echo   adb shell dumpsys window windows   - 查看当前窗口信息
echo.
exit /b

:CATEGORY_FILE
echo [文件传输 (File)]
echo   adb push [local] [remote]          - 发送文件到设备
echo   adb pull [remote] [local]          - 从设备拉取文件
echo   adb shell ls [path]                - 列出目录内容
echo.
exit /b

:CATEGORY_USER
echo [用户管理 (User)]
echo   adb shell pm list users            - 列出所有系统用户
echo   adb shell am switch-user [id]      - 切换用户
echo.
exit /b

:CATEGORY_POWER
echo [电源/按键 (Power)]
echo   adb reboot                         - 重启设备
echo   adb reboot bootloader              - 重启到 fastboot 模式
echo   adb shell input keyevent 26        - 模拟按键:电源
echo   adb shell input keyevent 3         - 模拟按键:主页
echo   adb shell input keyevent 4         - 模拟按键:返回
echo.
exit /b

:FINAL_END
echo ============================================================
endlocal