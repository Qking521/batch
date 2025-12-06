@echo off
adb shell am force-stop com.example.mtk10263.whatsTemp
rem Launch WhatsTemp tool
adb shell am start -n com.example.mtk10263.whatsTemp/.MainActivity
rem --ei t <timeout> timeout in minutes
adb shell am startservice -n com.example.mtk10263.whatsTemp/.GetInfo_Service --ei t 0