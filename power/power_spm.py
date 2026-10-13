#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
功耗汇总表自动生成脚本 (纯Python计算版，不依赖LibreOffice/Excel)
用法: python power_summary_pipeline.py

依赖: pip install openpyxl pandas
"""

import re
import csv
import sys
import os
import json
from datetime import datetime
from pathlib import Path
import pandas as pd
from openpyxl import Workbook, load_workbook
from openpyxl.styles import Font

# ============================================================
# 配置区：每次换数据只需要改这里
# ============================================================

RAW_DATA_PATH = sys.argv[2]          # 原始采集数据文件 (.csv 或 .xlsx)
CONFIG_PATH = sys.argv[1]             # 模块/网络配置表
PRODUCT_NAME = sys.argv[3] if len(sys.argv) > 3 else ""  # 产品名（如 ro.product.board），用于区分 module_map 文件
CONFIG_SHEET = None                     # 配置表要用哪个sheet, None=用第一个
CONFIG_MODULE_COL = "模块"               # 配置表里"模块"列的表头文字
CONFIG_NET_COL = "输入网络"               # 配置表里"网络"列的表头文字(带_P后缀)

_ts = datetime.now().strftime("%Y%m%d_%H%M%S")
_suffix = f"_{PRODUCT_NAME}" if PRODUCT_NAME else ""
OUTPUT_FILE_NAME = f"功耗汇总表{_suffix}_{_ts}.xlsx"

TEST_SHEET_NAME = "测试数据"
CONV_SHEET_NAME = "功耗折算表"
SUMMARY_SHEET_NAME = "功耗汇总表"

# module_map.json 的文件名（放在 CONFIG_PATH 同级目录），带 product 名前缀
# 格式：{PRODUCT_NAME}_module_map.json，无 product 名时退化为 module_map.json
MODULE_MAP_FILE = f"{PRODUCT_NAME}_module_map.json" if PRODUCT_NAME else "module_map.json"

# 单个Sub-Module电流超过这个阈值(mA)就提示可能是异常数据，不代表一定错，仅供人工复核
ANOMALY_THRESHOLD_MA = 1000

# ============================================================
# MODULE_MAP 加载 / 自动生成
#
# module_map.json 格式：
# {
#   "Sub-Module名": { "group": "归属大类名", "label": "显示标签" },
#   ...
# }
# group 默认等于 Sub-Module 名，用户可手动修改实现归类。
# label 默认为空，可填写汇总表中该大类的显示名称。
# ============================================================

def _module_map_path(config_path):
    """返回 module_map.json 的绝对路径（CONFIG_PATH 同级目录）"""
    return Path(config_path).parent / MODULE_MAP_FILE


def _generate_module_map(config_path):
    """
    从 CONFIG_PATH 的 CONFIG_MODULE_COL 列读取所有模块名，
    按字母排序、去重，生成默认 module_map（group=key, label=""），
    保存到 CONFIG_PATH 同级目录，并返回字典。
    """
    cfg_wb = load_workbook(config_path, data_only=True)
    cfg = cfg_wb[CONFIG_SHEET] if CONFIG_SHEET else cfg_wb[cfg_wb.sheetnames[0]]

    # 找到 CONFIG_MODULE_COL 所在列
    mod_col = None
    for c in range(1, cfg.max_column + 1):
        if cfg.cell(row=1, column=c).value == CONFIG_MODULE_COL:
            mod_col = c
            break
    if mod_col is None:
        raise ValueError(f"配置表里没找到列 '{CONFIG_MODULE_COL}'，请检查表头文字是否一致")

    # 读取所有模块名，去除空值，去重，按字母排序
    names = set()
    for r in range(2, cfg.max_row + 1):
        val = cfg.cell(row=r, column=mod_col).value
        if val is not None:
            names.add(str(val).strip())
    sorted_names = sorted(names, key=lambda x: x.upper())

    module_map = {name: {"group": name, "label": ""} for name in sorted_names}

    # 写入 JSON 文件
    out_path = _module_map_path(config_path)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(module_map, f, ensure_ascii=False, indent=4)
    print(f"[MODULE_MAP] 已从配置表自动生成并保存到：{out_path}")
    print(f"[MODULE_MAP] 共 {len(module_map)} 个 Sub-Module，可手动编辑 group/label 实现归类")
    return module_map


def load_module_map(config_path):
    """
    优先从 CONFIG_PATH 同级目录的 module_map.json 加载；
    若文件不存在，则自动从配置表生成并保存。
    """
    map_path = _module_map_path(config_path)
    if map_path.exists():
        with open(map_path, encoding="utf-8") as f:
            module_map = json.load(f)
        print(f"[MODULE_MAP] 已从文件加载：{map_path}，共 {len(module_map)} 项")
        return module_map
    else:
        print(f"[MODULE_MAP] 未找到 {map_path}，自动从配置表生成...")
        return _generate_module_map(config_path)



# ============================================================
# 第一步：读原始数据，自动定位表头行，算出每列平均值
# ============================================================

HEADER_SUFFIX_RE = re.compile(r".+_(I|P|V)$")


def _read_raw_rows(path):
    """读取原始文件所有行，csv/xlsx都支持，返回 list[list]"""
    if path.suffix.lower() == ".csv":
        with open(path, newline="", encoding="utf-8-sig") as f:
            return [row for row in csv.reader(f)]
    wb = load_workbook(path, data_only=True)
    ws = wb[wb.sheetnames[0]]
    return [["" if v is None else v for v in row] for row in ws.iter_rows(values_only=True)]


def _find_header_row(rows):
    """按 XXX_I / XXX_P / XXX_V 后缀特征找表头行，不依赖固定行号"""
    best_row, best_score = None, 0
    for i, row in enumerate(rows):
        score = sum(1 for cell in row if isinstance(cell, str) and HEADER_SUFFIX_RE.match(cell))
        if score > best_score:
            best_row, best_score = i, score
    if best_row is None:
        raise ValueError("没能在原始数据里找到形如 XXX_I/XXX_P/XXX_V 的表头行，请检查文件")
    return best_row


def _find_first_data_row(rows, header_idx):
    """表头行之后，找第一行第2列是数字的行，认定为数据起始行"""
    for i in range(header_idx + 1, len(rows)):
        val = rows[i][1] if len(rows[i]) > 1 else None
        try:
            float(val)
            return i
        except (TypeError, ValueError):
            continue
    raise ValueError("表头行之后没有找到数值数据，请检查文件")


def load_raw_averages(raw_path):
    """返回 (header列表, {列名: 平均值} 字典, 原始数据DataFrame)"""
    rows = _read_raw_rows(Path(raw_path))
    header_idx = _find_header_row(rows)
    data_start_idx = _find_first_data_row(rows, header_idx)

    header = rows[header_idx]
    df = pd.DataFrame(rows[data_start_idx:], columns=header)

    # 去掉重复/空列名 (比如 System Messages 后面那个没名字的列)
    df = df.loc[:, [c for c in df.columns if c not in ("", None)]]
    df = df.apply(pd.to_numeric, errors="coerce")  # 非数字(如空字符串)转NaN

    averages = df.mean(skipna=True).to_dict()  # NaN会被skipna跳过，等价于之前的IFERROR兜底

    print(f"[原始数据] 表头行=文件第{header_idx+1}行，数据从第{data_start_idx+1}行开始，共{len(df)}行样本")
    return header, averages, df


# ============================================================
# 第二步：按配置表 + 平均值字典，算出每个Sub-Module的Vavg/Iavg/Pavg
# ============================================================

def build_conversion_table(config_path, averages):
    cfg_wb = load_workbook(config_path, data_only=True)
    cfg = cfg_wb[CONFIG_SHEET] if CONFIG_SHEET else cfg_wb[cfg_wb.sheetnames[0]]

    mod_col = net_col = None
    for c in range(1, cfg.max_column + 1):
        v = cfg.cell(row=1, column=c).value
        if v == CONFIG_MODULE_COL and mod_col is None:
            mod_col = c
        elif v == CONFIG_NET_COL and net_col is None:
            net_col = c
    if mod_col is None or net_col is None:
        raise ValueError(f"配置表里没找到列 '{CONFIG_MODULE_COL}' 或 '{CONFIG_NET_COL}'，请检查表头文字是否一致")

    rows_out = []
    for r in range(2, cfg.max_row + 1):
        mod = cfg.cell(row=r, column=mod_col).value
        net = cfg.cell(row=r, column=net_col).value
        if mod is None and net is None:
            continue
        mod = mod.strip() if isinstance(mod, str) else mod
        net = net.strip() if isinstance(net, str) else net
        base = net[:-2] if net and net.endswith("_P") else net

        v_avg = averages.get(f"{base}_V", 0) or 0
        i_avg = averages.get(f"{base}_I", 0) or 0
        p_avg = averages.get(f"{base}_P", 0) or 0
        rows_out.append({
            "Sub-Module": mod, "Net": base,
            "Vavg(V)": v_avg / 1000, "Iavg(mA)": i_avg, "Pavg(mW)": p_avg,
        })

    conv_df = pd.DataFrame(rows_out)
    print(f"[功耗折算表] 共 {len(conv_df)} 行")
    return conv_df


# ============================================================
# 第三步：按 MODULE_MAP 归类汇总，Others兜底
# ============================================================

def build_summary_table(conv_df, module_map):
    """
    按 module_map 把 Sub-Module 映射到 group（大类），对 Pavg(mW) 分组求和后除以 4V，
    得到每个大类折算到电池侧的等效电流（4V Bat Current(mA)）。
    module_map 格式: { "Sub-Module名": {"group": "大类名", "label": "显示标签"} }
    没有映射到的 Sub-Module 自动归入 "Others"。
    """
    # Sub-Module -> group
    def _to_group(sub):
        entry = module_map.get(sub)
        return entry["group"] if entry and entry.get("group") else "Others"

    conv_df = conv_df.copy()
    conv_df["Group"] = conv_df["Sub-Module"].map(_to_group)

    # 按 group 对 Pavg(mW) 求和，再除以 4V，得到 4V 电池侧等效电流(mA)
    # 公式：I(mA) = P(mW) / V(V) = P(mW) / 4
    grouped_p = conv_df.groupby("Group")["Pavg(mW)"].sum()
    grouped_i = grouped_p / 4.0  # mW / 4V = mA

    total_p = conv_df["Pavg(mW)"].sum()
    total_i = total_p / 4.0  # mW / 4V = mA


    rows_out = [{"Module": "BAT", "4V Bat Current(mA)": round(total_i, 4), "Label": "电池"}]

    # 按 group 字母顺序输出（Others 最后）
    sorted_groups = sorted(g for g in grouped_i.index if g != "Others")
    for grp in sorted_groups:
        label = next(
            (v["label"] for v in module_map.values() if v.get("group") == grp),
            ""
        )
        rows_out.append({
            "Module": grp,
            "4V Bat Current(mA)": round(grouped_i[grp], 4),
            "Label": label
        })

    others_i = grouped_i.get("Others", 0.0)
    rows_out.append({"Module": "Others", "4V Bat Current(mA)": round(others_i, 4), "Label": ""})

    summary_df = pd.DataFrame(rows_out)
    # groups+Others 之和应等于 BAT（允许四舍五入带来的微小误差，通常 < 0.01mA）
    groups_sum = summary_df.loc[summary_df["Module"] != "BAT", "4V Bat Current(mA)"].sum()
    diff = abs(groups_sum - total_i)
    is_consistent = diff < 0.01  # 精度容差设为 0.01mA
    print(f"[功耗汇总表] BAT={total_i:.2f}mA (ΣPavg/{4.0}V) | 分类累加={groups_sum:.2f}mA  "
          f"({'一致 ✓' if is_consistent else f'不一致 ✗ (差异: {diff:.4f}mA)'})")
    return summary_df



# ============================================================
# 第四步：异常值检查
# ============================================================

def check_anomalies(conv_df):
    flagged = conv_df[conv_df["Iavg(mA)"].abs() >= ANOMALY_THRESHOLD_MA]
    if not flagged.empty:
        print(f"[警告] 以下 {len(flagged)} 项电流超过 {ANOMALY_THRESHOLD_MA}mA 阈值，"
              f"疑似原始数据异常，建议人工复核，不要直接采信：")
        for _, row in flagged.iterrows():
            print(f"  - {row['Sub-Module']} ({row['Net']}): {row['Iavg(mA)']:.2f} mA")


# ============================================================
# 写出xlsx
# ============================================================

def write_output(header, df_raw, conv_df, summary_df, output_file):
    wb = Workbook()

    ws = wb.active
    ws.title = TEST_SHEET_NAME
    ws.append(header)
    for row in df_raw.itertuples(index=False):
        ws.append(list(row))

    conv_ws = wb.create_sheet(CONV_SHEET_NAME)
    conv_ws.append(list(conv_df.columns))
    for row in conv_df.itertuples(index=False):
        conv_ws.append(list(row))

    summary_ws = wb.create_sheet(SUMMARY_SHEET_NAME)
    summary_ws.append(list(summary_df.columns))
    for row in summary_df.itertuples(index=False):
        summary_ws.append(list(row))

    header_font = Font(name="Arial", bold=True, size=10)
    body_font = Font(name="Arial", size=10)
    for ws_ in (conv_ws, summary_ws):
        for c in range(1, ws_.max_column + 1):
            ws_.cell(row=1, column=c).font = header_font
        for r in range(2, ws_.max_row + 1):
            for c in range(1, ws_.max_column + 1):
                ws_.cell(row=r, column=c).font = body_font

    wb.save(output_file)
    print(f"[保存] {output_file}")
    os.startfile(output_file)


# ============================================================
# 主流程
# ============================================================

def main():
    header, averages, df_raw = load_raw_averages(RAW_DATA_PATH)
    conv_df = build_conversion_table(CONFIG_PATH, averages)
    module_map = load_module_map(CONFIG_PATH)
    summary_df = build_summary_table(conv_df, module_map)
    check_anomalies(conv_df)
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
    BASE_DIR = os.path.dirname(SCRIPT_DIR)
    OUTPUT_FILE = os.path.join(BASE_DIR, "OUT", "power", OUTPUT_FILE_NAME)
    print("汇总文件：", OUTPUT_FILE)
    write_output(header, df_raw, conv_df, summary_df, OUTPUT_FILE)

if __name__ == "__main__":
    main()