@echo off
setlocal

:: Define variables
set USER_DIR=%USERPROFILE%\files
set LOG_PATH=%USER_DIR%\log\devicelog\857133513_mijia.watch.o62
set ZIP_PATH=C:\Program Files\7-Zip\7z.exe
set NPP_PATH=C:\Program Files\Notepad++\notepad++.exe
set FILE_NAME=_data_tmp_19969_log
set TAR_GZ_FILE=%LOG_PATH%\%FILE_NAME%.tar.gz
set TAR_FILE=%LOG_PATH%\%FILE_NAME%.tar
set TARGET_DIR=%LOG_PATH%\%FILE_NAME%\
set TARGET_LOG=%TARGET_DIR%log\offlinelog\tmp.log

:: Clean existing directory if exists
if exist "%USER_DIR%" (rd /s /q "%USER_DIR%")

:: upload log from watch device to phone
adb shell am broadcast -a com.xiaomi.fitness.debug.PULL

:: wait 15s
timeout /t 15 >nul

:: Pull files from Android device
adb pull /sdcard/Android/data/com.mi.health/files/ .

:: Extract the .tar.gz file
"%ZIP_PATH%" x "%TAR_GZ_FILE%" -o"%LOG_PATH%" -y

:: Extract the .tar file
"%ZIP_PATH%" x "%TAR_FILE%" -o"%TARGET_DIR%" -y

:: Open the log file in Notepad++
"%NPP_PATH%" "%TARGET_LOG%"

echo Log extraction complete.
endlocal