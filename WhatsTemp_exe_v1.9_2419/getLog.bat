@echo off
set whatstemp_date_string=
for /f "tokens=1-3 delims=/ " %%a in ('date /t') do set _date=%%a-%%b-%%c
for /f "tokens=1-3 delims=: " %%a in ('time /t') do set _time=%%a-%%b
set whatstemp_date_string=%_date%-%_time%
IF "%whatstemp_date_string%"=="" (
    echo Error from getting date
	set whatstemp_date_string=log
) ELSE (
	echo Today is %whatstemp_date_string%
)

adb shell am stopservice -n com.example.mtk10263.whatsTemp/.GetInfo_Service
adb pull /sdcard/WhatsTemp/log/ .\%whatstemp_date_string%\
adb shell rm /sdcard/WhatsTemp/log/*
pause