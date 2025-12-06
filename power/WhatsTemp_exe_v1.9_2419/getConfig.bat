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

adb pull /sdcard/WhatsTemp/tool.config .\%whatstemp_date_string%\tool.config
pause