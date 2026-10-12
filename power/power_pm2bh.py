# -*- coding: utf-8 -*-
import os
import sys
import re
import datetime

help_msg = "usage: power_pm2bh.py <filename.csv>"

if len(sys.argv) < 2:
    print(help_msg)
    sys.exit(1)

input_path = sys.argv[1]
if not os.path.exists(input_path):
    print(f"[ERROR] 找不到输入文件: {input_path}", file=sys.stderr)
    sys.exit(1)

base_name = os.path.basename(input_path)

# 从文件名解析开始时间 (例如: 2026-09-21-18-13-55.csv)
match = re.search(r"(\d{4})-(\d{2})-(\d{2})-(\d{2})-(\d{2})-(\d{2})", base_name)
if not match:
    print(f"[ERROR] 无法从文件名解析时间戳 (格式须包含 YYYY-MM-DD-HH-mm-ss): {base_name}", file=sys.stderr)
    sys.exit(1)

year, month, day, hour, minute, second = [int(x) for x in match.groups()]

# 转换为本地时间的 Unix 时间戳 (秒，含浮点精度)
start_dt = datetime.datetime(year, month, day, hour, minute, second)
test_start_unix_time_stamp = start_dt.timestamp()

output_path = "BH-" + base_name
print(f"[INFO] 输入文件: {base_name}")
print(f"[INFO] 测试开始时间(本地): {start_dt} (Unix时间戳: {test_start_unix_time_stamp})")

count = 0
first_offset_sec = None
last_offset_sec = None

with open(input_path, "r", encoding="utf-8", errors="ignore") as f_in, \
     open(output_path, "w", encoding="utf-8") as f_out:

    # 读取并解析 CSV 表头以自动识别单位
    header_line = f_in.readline()
    header_parts = [p.strip().lower() for p in header_line.split(",")]

    # 1. 自动识别时间单位 (min / ms / h / s)
    time_factor = 1.0  # 默认按秒 (s) 计算
    time_unit_str = "秒 (s)"
    if len(header_parts) > 0:
        time_hdr = header_parts[0]
        if "min" in time_hdr:
            time_factor = 60.0
            time_unit_str = "分钟 (min)"
        elif "ms" in time_hdr:
            time_factor = 0.001
            time_unit_str = "毫秒 (ms)"
        elif "h" in time_hdr:
            time_factor = 3600.0
            time_unit_str = "小时 (h)"

    # 2. 自动识别电流单位 (mA / uA / A)
    current_factor = 1.0 / 1000.0  # 默认 mA -> A
    if len(header_parts) > 1:
        curr_hdr = header_parts[1]
        if "ua" in curr_hdr or "μa" in curr_hdr:
            current_factor = 1.0 / 1000000.0
        elif "ma" in curr_hdr:
            current_factor = 1.0 / 1000.0
        elif "a" in curr_hdr:
            current_factor = 1.0

    print(f"[INFO] 识别到时间列单位: {time_unit_str} (时间换算系数: {time_factor})")
    print(f"[INFO] 正在转换并输出到: {output_path} ...")

    for line in f_in:
        line = line.strip()
        if not line:
            continue
        parts = line.split(",")
        if len(parts) < 2:
            continue

        try:
            raw_time = float(parts[0])
            raw_curr = float(parts[1])
        except ValueError:
            continue

        # 将时间统一转换为以“秒”为单位的偏移量
        offset_sec = raw_time * time_factor
        if first_offset_sec is None:
            first_offset_sec = offset_sec
        last_offset_sec = offset_sec

        # 绝对时间戳：保留 6 位小数
        offset_time_stamp = test_start_unix_time_stamp + offset_sec
        # Battery Historian 秒级格式要求电流单位为 A (安培)
        current_amp = raw_curr * current_factor

        # 输出格式: <epoch_seconds_with_fraction> <amps>
        f_out.write(f"{offset_time_stamp:.6f} {current_amp:.6f}\n")
        count += 1

if first_offset_sec is not None and last_offset_sec is not None:
    duration_sec = last_offset_sec - first_offset_sec
    print(f"[INFO] 采集总时长: {duration_sec:.1f} 秒 ({duration_sec / 60:.2f} 分钟)")

print(f"[OK] 转换完成，共处理 {count} 条数据。")