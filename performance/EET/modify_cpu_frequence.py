# -*- coding: utf-8 -*-
import os,shutil

print("##########请选择手机对应的Polic：#############")
print('请输入1：policy0 policy6')
print('请输入2：policy0 policy4')
print('请输入3：policy0 policy3 policy7')
print('请输入4：policy0 policy4 policy7')
print('请输入5：退出')
print("#############################################")

select=int(input("请输入你的选择: "))

if select==4:

	command_0 = 'adb shell cat /sys/devices/system/cpu/cpufreq/policy0/scaling_available_frequencies'
	command_4 = 'adb shell cat /sys/devices/system/cpu/cpufreq/policy4/scaling_available_frequencies'
	command_7 = 'adb shell cat /sys/devices/system/cpu/cpufreq/policy7/scaling_available_frequencies'

	prt_com_0 = os.popen(command_0).read()
	prt_com_4 = os.popen(command_4).read()
	prt_com_7 = os.popen(command_7).read()

	print(prt_com_0)
	print(prt_com_4)
	print(prt_com_7)

# 将替换的字符串写到一个新的文件中，然后将原文件删除，新文件改为原来文件的名字
# 	:param foldername：文件夹名字
#     :param file: 文件路径
#     :param old_str: 文本内容中需要替换的字符串
#     :param new_str: 新文件.bat名字中需要替换的字符串
#     :param file_new: 新文件.bat名字

	def alter(foldername, file, old_str, new_str, file_new):
		if not os.path.exists(foldername):
			os.makedirs(foldername)

		filepath = os.path.join(foldername, file_new)
		with open(file, "r", encoding="utf-8") as f1, open(filepath, "w", encoding="utf-8") as f2:
			for line in f1:
				if old_str in line:
					line = line.replace(old_str, new_str)
				f2.write(line)


	if __name__ == '__main__':
	    for i in prt_com_0.split():
	        alter('data', 'set_cpu0_frequency_org', '$change_v', i, 'set_cpu0_frequency_%s.bat' % i)
	    for i in prt_com_4.split():
	        alter('data', 'set_cpu4_frequency_org', '$change_v', i, 'set_cpu4_frequency_%s.bat' % i)
	    for i in prt_com_7.split():
	        alter('data', 'set_cpu7_frequency_org', '$change_v', i, 'set_cpu7_frequency_%s.bat' % i)
if select==3:

	command_0 = 'adb shell cat /sys/devices/system/cpu/cpufreq/policy0/scaling_available_frequencies'
	command_3 = 'adb shell cat /sys/devices/system/cpu/cpufreq/policy3/scaling_available_frequencies'
	command_7 = 'adb shell cat /sys/devices/system/cpu/cpufreq/policy7/scaling_available_frequencies'

	prt_com_0 = os.popen(command_0).read()
	prt_com_3 = os.popen(command_3).read()
	prt_com_7 = os.popen(command_7).read()

	print(prt_com_0)
	print(prt_com_3)
	print(prt_com_7)


	def alter(foldername, file, old_str, new_str, file_new):
		if not os.path.exists(foldername):
			os.makedirs(foldername)

		filepath = os.path.join(foldername, file_new)
		with open(file, "r", encoding="utf-8") as f1, open(filepath, "w", encoding="utf-8") as f2:
			for line in f1:
				if old_str in line:
					line = line.replace(old_str, new_str)
				f2.write(line)


	if __name__ == '__main__':
	    for i in prt_com_0.split():
	        alter('data', 'set_cpu0_frequency_org', '$change_v', i, 'set_cpu0_frequency_%s.bat' % i)
	    for i in prt_com_3.split():
	        alter('data', 'set_cpu3_frequency_org', '$change_v', i, 'set_cpu3_frequency_%s.bat' % i)
	    for i in prt_com_7.split():
	        alter('data', 'set_cpu7_frequency_org', '$change_v', i, 'set_cpu7_frequency_%s.bat' % i)

if select==2:

	command_0 = 'adb shell cat /sys/devices/system/cpu/cpufreq/policy0/scaling_available_frequencies'
	command_4 = 'adb shell cat /sys/devices/system/cpu/cpufreq/policy4/scaling_available_frequencies'
	
	prt_com_0 = os.popen(command_0).read()
	prt_com_4 = os.popen(command_4).read()

	print(prt_com_0)
	print(prt_com_4)


	def alter(foldername, file, old_str, new_str, file_new):
		if not os.path.exists(foldername):
			os.makedirs(foldername)

		filepath = os.path.join(foldername, file_new)
		with open(file, "r", encoding="utf-8") as f1, open(filepath, "w", encoding="utf-8") as f2:
			for line in f1:
				if old_str in line:
					line = line.replace(old_str, new_str)
				f2.write(line)


	if __name__ == '__main__':
	    for i in prt_com_0.split():
	        alter('data', 'set_cpu0_frequency_org', '$change_v', i, 'set_cpu0_frequency_%s.bat' % i)
	    for i in prt_com_4.split():
	        alter('data', 'set_cpu4_frequency_org', '$change_v', i, 'set_cpu4_frequency_%s.bat' % i)

if select==1:

	command_0 = 'adb shell cat /sys/devices/system/cpu/cpufreq/policy0/scaling_available_frequencies'
	command_6 = 'adb shell cat /sys/devices/system/cpu/cpufreq/policy6/scaling_available_frequencies'


	prt_com_0 = os.popen(command_0).read()
	prt_com_6 = os.popen(command_6).read()


	print("CPU0:", prt_com_0)
	print("CPU6:", prt_com_6)



	def alter(foldername, file, old_str, new_str, file_new):
		if not os.path.exists(foldername):
			os.makedirs(foldername)

		filepath = os.path.join(foldername, file_new)
		with open(file, "r", encoding="utf-8") as f1, open(filepath, "w", encoding="utf-8") as f2:
			for line in f1:
				if old_str in line:
					line = line.replace(old_str, new_str)
				f2.write(line)


	if __name__ == '__main__':
	    for i in prt_com_0.split():
	        alter('data', 'set_cpu0_frequency_org', '$change_v', i, 'set_cpu0_frequency_%s.bat' % i)
	    for i in prt_com_6.split():
	        alter('data', 'set_cpu6_frequency_org', '$change_v', i, 'set_cpu6_frequency_%s.bat' % i)

#退出程序        
if select==5:
	quit()

