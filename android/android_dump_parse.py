#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Android dumpsys 输出解析器，按 service 分派解析逻辑。

用法: python android_dump_parse.py <service> <dump.txt>
支持 service: sf / surfaceflinger
"""
import re
import sys


def read_text(path):
    for enc in ("utf-8", "gbk", "latin-1"):
        try:
            with open(path, "r", encoding=enc) as f:
                return f.read()
        except (UnicodeDecodeError, ValueError):
            continue
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def first_match(pattern, text, default=""):
    m = re.search(pattern, text, re.MULTILINE | re.IGNORECASE)
    return m.group(1).strip() if m else default


def parse_surfaceflinger(text):
    print("=" * 60)
    print("           SurfaceFlinger 屏幕重点解析 (Screen Highlights)")
    print("=" * 60)

    size = first_match(r"Physical size\s*:\s*([0-9]+x[0-9]+)", text)
    print(f"[分辨率]  {size or 'N/A'}")

    rr = first_match(r"refresh[- ]rate\s*[=:]\s*([0-9.]+)", text)
    print(f"[刷新率]  {rr or 'N/A'}")

    density = first_match(r"[Dd]ensity\s*[=:]\s*([0-9.]+)", text)
    print(f"[密度]    {density or 'N/A'}")

    hdr = first_match(r"HDR\s*(?:display\s*)?support(?:s)?\s*[=:]\s*(\w+)", text)
    print(f"[HDR]     {hdr or 'N/A'}")

    colors = first_match(r"[Cc]olor\s?[Mm]ode\s*[=:]\s*([A-Za-z0-9_ ]+)", text)
    print(f"[色彩模式] {colors.strip() if colors else 'N/A'}")

    comp = {}
    for key in ("Client composition", "Device composition", "Real GPU composition",
                "Never SDK Client composition", "HWC next available", "TOTAL"):
        m = re.search(re.escape(key) + r"\s*[=:]\s*(\d+)", text, re.IGNORECASE)
        if m:
            comp[key] = m.group(1)
    if comp:
        print("[合成方式统计]")
        for k, v in comp.items():
            print(f"  - {k}: {v}")
    else:
        print("[合成方式统计] N/A")

    displays = re.findall(r"Display\s+\d+\s+.*", text, re.IGNORECASE)
    if displays:
        print("[Display 列表]")
        for d in displays[:8]:
            print(f"  - {d.strip()}")

    print("=" * 60)


def main():
    if len(sys.argv) < 3:
        print("Usage: python android_dump_parse.py <service> <dump.txt>")
        print("  service: sf / surfaceflinger")
        sys.exit(1)

    service = sys.argv[1].lower()
    text = read_text(sys.argv[2])

    # 仅处理支持的服务，其余默认不处理
    if service in ("sf", "surfaceflinger"):
        parse_surfaceflinger(text)


if __name__ == "__main__":
    main()