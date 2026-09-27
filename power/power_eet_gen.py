# -*- coding: utf-8 -*-
import os
import re
import sys
import subprocess

if sys.stdout.encoding.lower() != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

def run_adb_cmd(cmd_list):
    """执行 adb 命令并返回输出字符串"""
    try:
        res = subprocess.run(
            cmd_list,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="ignore"
        )
        return res.stdout.strip()
    except Exception as e:
        print(f"[ERROR] 执行命令失败 {' '.join(cmd_list)}: {e}")
        return ""

def get_device_cpus():
    """读取设备所有 CPU 编号，例如 [0, 1, 2, 3, 4, 5, 6, 7]"""
    out = run_adb_cmd(["adb", "shell", "ls -d /sys/devices/system/cpu/cpu[0-9]* 2>/dev/null"])
    nums = re.findall(r'cpu(\d+)', out)
    if nums:
        return sorted(list(set(int(n) for n in nums)))
    return list(range(8))

def get_device_policies():
    """直接读取设备的 policy 配置情况，例如 [0, 6] 或 [0, 4, 7]"""
    out = run_adb_cmd(["adb", "shell", "ls -d /sys/devices/system/cpu/cpufreq/policy[0-9]* 2>/dev/null"])
    nums = re.findall(r'policy(\d+)', out)
    if nums:
        return sorted(list(set(int(n) for n in nums)))
    return []

def get_policy_frequencies(policy_id):
    """读取指定 policy 的所有可用频点列表"""
    out = run_adb_cmd(["adb", "shell", f"cat /sys/devices/system/cpu/cpufreq/policy{policy_id}/scaling_available_frequencies 2>/dev/null"])
    return out.split()

def get_device_name():
    """获取设备名称 (ro.product.device，若为空则获取 ro.product.model)"""
    device_name = run_adb_cmd(["adb", "shell", "getprop ro.product.device"]).strip()
    if not device_name:
        device_name = run_adb_cmd(["adb", "shell", "getprop ro.product.model"]).strip()
    device_name = re.sub(r'[\\/:*?"<>|\s]', '_', device_name)
    return device_name if device_name else "device"

def generate_bat_content(policy, freq, cpus):
    """
    内容参考 set_cpu0_frequency_650000.bat，
    将 call only_open_cpuX.bat 和 call open_all_cpus.bat 的内容直接合并入单个文件。
    去掉 adb wait-for-device 和 pause，并在末尾通过明确命令显示设置结果。
    """
    lines = []
    lines.append('adb root')
    lines.append('')
    lines.append('adb shell "echo temporary > /sys/power/wake_lock"')
    lines.append('')

    # 1. 对应 open_all_cpus.bat 的全核心上线逻辑
    for idx, c in enumerate(cpus):
        if idx > 0 and idx % 4 == 0:
            lines.append('')
        lines.append(f'adb shell "echo 1 > /sys/devices/system/cpu/cpu{c}/online"')

    lines.append('')

    # 2. 对应 only_open_cpuX.bat 的 CPU 隔离逻辑 (仅目标 cpu 在线，其余下线)
    for idx, c in enumerate(cpus):
        if idx > 0 and idx % 4 == 0:
            lines.append('')
        val = 1 if c == policy else 0
        lines.append(f'adb shell "echo {val} > /sys/devices/system/cpu/cpu{c}/online"')

    lines.append('')

    # 3. 设置 performance governor 并固定频点
    lines.append(f'adb shell "echo performance > /sys/devices/system/cpu/cpu{policy}/cpufreq/scaling_governor"')
    lines.append(f'adb shell "echo {freq} > /sys/devices/system/cpu/cpufreq/policy{policy}/scaling_min_freq"')
    lines.append(f'adb shell "echo {freq} > /sys/devices/system/cpu/cpufreq/policy{policy}/scaling_max_freq"')
    lines.append('')

    # 4. 通过明确命令显示设置结果
    lines.append(f'adb shell "cat /sys/devices/system/cpu/cpufreq/policy{policy}/scaling_governor"')
    lines.append(f'adb shell "cat /sys/devices/system/cpu/cpufreq/policy{policy}/scaling_cur_freq"')
    lines.append(f'adb shell "cat /sys/devices/system/cpu/cpufreq/policy{policy}/scaling_min_freq"')
    lines.append(f'adb shell "cat /sys/devices/system/cpu/cpufreq/policy{policy}/scaling_max_freq"')

    return '\r\n'.join(lines) + '\r\n'

def generate_open_all_cpus_content(cpus):
    """生成恢复所有核心在线的 open_all_cpus.bat"""
    lines = []
    lines.append('adb root')
    lines.append('')
    lines.append('adb shell "echo temporary > /sys/power/wake_lock"')
    lines.append('')
    for idx, c in enumerate(cpus):
        if idx > 0 and idx % 4 == 0:
            lines.append('')
        lines.append(f'adb shell "echo 1 > /sys/devices/system/cpu/cpu{c}/online"')
    lines.append('')
    lines.append('adb shell "cat /sys/devices/system/cpu/online"')
    return '\r\n'.join(lines) + '\r\n'

def main():
    print("============================================================")
    print("  EET CPU 固定频率测试脚本生成器 (EET Generator)")
    print("============================================================")

    # 检查 ADB 连接
    devices_out = run_adb_cmd(["adb", "devices"])
    device_lines = [l for l in devices_out.splitlines()[1:] if l.strip() and not l.startswith('*')]
    if not device_lines:
        print("[ERROR] 未检测到已连接的 ADB 设备，请确认设备已连接并开启 USB 调试。")
        sys.exit(1)

    print("[INFO] 正在获取设备 root 权限...")
    run_adb_cmd(["adb", "root"])
    run_adb_cmd(["adb", "wait-for-device"])

    # 1. 直接读取设备 CPU 和 Policy 配置
    cpus = get_device_cpus()
    print(f"[INFO] 检测到设备 CPU 核心: {[f'cpu{c}' for c in cpus]}")

    policies = get_device_policies()
    if not policies:
        print("[ERROR] 未能读取到设备 /sys/devices/system/cpu/cpufreq/policy*，请检查设备内核支持情况。")
        sys.exit(1)

    print(f"[INFO] 成功读取到设备 Policy 配置: {[f'policy{p}' for p in policies]}")

    # 2. 确定输出目录 (power/power_archive/<device_name>_eet_gen)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # Use script_dir (power folder) directly for archive location
    device_name = get_device_name()
    target_dir_name = f"{device_name}_eet_gen"
    archive_dir = os.path.join(script_dir, "power_archive", target_dir_name)
    os.makedirs(archive_dir, exist_ok=True)
    print(f"[INFO] 脚本输出目录: {archive_dir}")

    total_generated = 0

    # 3. 遍历各 policy 及其可用频点生成 bat 脚本
    for policy in policies:
        freqs = get_policy_frequencies(policy)
        if not freqs:
            print(f"[WARN] policy{policy} 未读取到可用频点，跳过。")
            continue

        print(f"[INFO] policy{policy} 可用频点数: {len(freqs)}，正在生成对应脚本...")
        for freq in freqs:
            bat_name = f"set_cpu{policy}_frequency_{freq}.bat"
            bat_path = os.path.join(archive_dir, bat_name)
            content = generate_bat_content(policy, freq, cpus)
            with open(bat_path, "w", encoding="utf-8", newline="") as f:
                f.write(content)
            total_generated += 1

    # 生成配套的 open_all_cpus.bat
    open_all_path = os.path.join(archive_dir, "open_all_cpus.bat")
    with open(open_all_path, "w", encoding="utf-8", newline="") as f:
        f.write(generate_open_all_cpus_content(cpus))

    print("------------------------------------------------------------")
    print(f"[OK] 全部生成完成！共生成 {total_generated} 个频点控制脚本及 open_all_cpus.bat")
    print(f"[OK] 文件已归档至: {archive_dir}")
    print("============================================================")

if __name__ == '__main__':
    main()

