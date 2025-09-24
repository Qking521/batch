@echo off
setlocal enabledelayedexpansion

:: 这个BAT脚本会创建一个VBS文件，用于模拟按键以防止Windows自动锁屏。
:: VBS会每60秒发送一次Scroll Lock键（无害操作），保持系统活跃。
:: 运行后，它会无限循环，直到手动停止（在任务管理器中结束wscript.exe进程）。

:: 创建临时VBS文件
set "vbsFile=%temp%\prevent_lock.vbs"
echo Set WshShell = WScript.CreateObject("WScript.Shell") > "%vbsFile%"
echo Do >> "%vbsFile%"
echo     WshShell.SendKeys "{SCROLLLOCK}" >> "%vbsFile%"
echo     WScript.Sleep 60000 >> "%vbsFile%"
echo Loop >> "%vbsFile%"

:: 运行VBS文件
start /b wscript "%vbsFile%"

echo 脚本已启动！现在你的电脑不会自动锁屏了。
echo 要停止，请在任务管理器中结束wscript.exe进程。
pause