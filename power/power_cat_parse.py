#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Power cat 的 PC 端解析器。

把设备端抓取的原始文本，按子命令解析为 xlsx 表格。

Usage:
    python power_cat_parse.py <subcommand> <input_txt> <output_xlsx>

子命令：
    irq   解析 /proc/interrupts
"""
import sys
import csv

from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter


def _write_xlsx(out_path, rows, widths, footer=None):
    """rows: 数据行（含表头）。footer: 末尾插入的说明文字（红色跨列）。"""
    wb = Workbook()
    ws = wb.active

    header = rows[0]
    for c, h in enumerate(header, 1):
        cell = ws.cell(row=1, column=c, value=h)
        cell.font = Font(bold=True)

    for r, row in enumerate(rows[1:], start=2):
        for c, v in enumerate(row, 1):
            ws.cell(row=r, column=c, value=v)

    # 列宽自适应（限制上下限，保证每个单元格内容充分显示）
    for c, w in enumerate(widths, 1):
        ws.column_dimensions[get_column_letter(c)].width = w

    if footer:
        fr = len(rows) + 2  # 空一行
        last_col = len(header)
        ws.merge_cells(start_row=fr, start_column=1, end_row=fr, end_column=last_col)
        cell = ws.cell(row=fr, column=1, value=footer)
        cell.font = Font(color='FFFF0000')
        cell.alignment = Alignment(wrap_text=True, vertical='center')
        # 结构化 footer 按行显示，行高随行数拉开，保证完整可见
        nlines = str(footer).count('\n') + 1
        ws.row_dimensions[fr].height = 15 * nlines

    wb.save(out_path)


def parse_irq(in_path, out_path):
    """解析 /proc/interrupts 为 xlsx。"""
    header = ['IRQ号', 'CPU0', 'CPU1', 'CPU2', 'CPU3', 'CPU4', 'CPU5', 'CPU6', 'CPU7',
              '中断控制器', '硬件中断号', '触发类型', '设备名']
    rows = [header]
    with open(in_path, 'r', encoding='utf-8', errors='replace') as f:
        for raw in f:
            line = raw.strip()
            if not line:
                continue
            parts = line.split()
            if parts[0] == 'CPU0':
                continue
            irq = parts[0].rstrip(':')
            if irq == 'Err':
                continue
            cpus = parts[1:9]
            rest = parts[9:]
            if irq.startswith('IPI'):
                row = [irq] + cpus + ['', '', '', ' '.join(rest)]
            else:
                controller = rest[0] if len(rest) > 0 else ''
                hwirq = rest[1] if len(rest) > 1 else ''
                trig = rest[2] if len(rest) > 2 else ''
                device = ' '.join(rest[3:]) if len(rest) > 3 else ''
                row = [irq] + cpus + [controller, hwirq, trig, device]
            rows.append(row)

    widths = [8, 10, 10, 10, 10, 10, 10, 10, 10, 16, 10, 8, 30]
    footer = ('硬件中断号范围：\n'
              '0~15 → SGI（软件生成中断）\n'
              '16~31 → PPI（每个CPU私有外设中断）\n'
              '32~1019 → SPI（共享外设中断）')
    _write_xlsx(out_path, rows, widths, footer=footer)


PARSERS = {
    'irq': parse_irq,
}


def main():
    if len(sys.argv) != 4:
        print('Usage: power_cat_parse.py <subcommand> <input_txt> <output_xlsx>', file=sys.stderr)
        sys.exit(1)
    sub = sys.argv[1]
    parser = PARSERS.get(sub)
    if parser is None:
        print('[ERROR] 未知子命令: %s (可用: %s)' % (sub, ', '.join(PARSERS)), file=sys.stderr)
        sys.exit(1)
    parser(sys.argv[2], sys.argv[3])


if __name__ == '__main__':
    main()