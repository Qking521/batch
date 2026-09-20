# -*- coding: utf-8 -*-
import os
import sys
import time
import datetime
from itertools import islice
help_msg = " usage: pm2bh.py filename.csv"
if len(sys.argv) < 2:
    print (help_msg)
    sys.exit()
if sys.argv[1].startswith('--'):
    option = sys.argv[1][2:]
print ("argv = ", sys.argv)
print (os.path.basename(sys.argv[1]))
# 根据-符号,解析出文件名的开始时间戳：2025-01-09-19-31-28.csv，故csv格式的文件名写powermonitor开始的时间戳
filename = os.path.basename(sys.argv[1]).split(".")[0].split("-")
# 解析年：例如 2025
year = int(str(filename[0]))
# 解析月：例如 01
month = int(str(filename[1]))
# 解析日：例如 09
day = int(str(filename[2]))
# 解析时：例如 19
hour = int(str(filename[3]))
# 解析分：例如 31
minute = int(str(filename[4]))
# 解析秒：例如 28
second = int(str(filename[5]))
# 将开始时间转换为Unix时间戳，其中减去8*3600转化为UTC+8时区北京时区
test_start_unix_time_stamp = (datetime.datetime(year,month,day,hour,minute,second) - datetime.datetime(1970,1,1)).total_seconds() - 8*3600
f = open(sys.argv[1],"r")
f_out = open("BH-"+os.path.basename(sys.argv[1]),"w")
for line in islice(f, 1, None):
    t = line.strip().split(",")
    # 测试开始时间+PowerMonitor的时间偏移量
    offset_time = float(t[0])
    # 计算偏移后的时间戳
    offset_time_stamp = offset_time + test_start_unix_time_stamp
    # 转换为本地时间datetime对象
    local_datetime = datetime.datetime.fromtimestamp(int(offset_time_stamp))
    # 转换为UTC时间datetime对象，直接使用浮点数时间戳
    utc_datetime = datetime.datetime.utcfromtimestamp(offset_time_stamp)
    # 平均电流值，将单位mA转换为uA（微安）
    main_avg_current = str(float(t[1]) / 1000)
    print("offset_time=" + str(offset_time) + ", offset_time_stamp=" + str(offset_time_stamp) + ", utc_datetime=" + utc_datetime.strftime('%Y-%m-%d %H:%M:%S') + ", main_avg_current=" + main_avg_current + "μA " + "\n")
    # Battery Historian 只需要Unix时间戳和电流值数据格式
    f_out.write(str(int(offset_time_stamp)) + " " + main_avg_current + " \n")
f_out.close()