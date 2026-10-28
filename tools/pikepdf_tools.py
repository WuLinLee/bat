#!/usr/bin/env python3
"""Self-contained helper for the BAT PDF utilities.

Commands:
  pikepdf-tools.exe merge <input-list.txt> <desktop>
  pikepdf-tools.exe split <input-list.txt> <desktop>
  pikepdf-tools.exe pagecount <input.pdf>
"""
from __future__ import annotations

import os
import random
import sys
from datetime import datetime

from pikepdf import Array, Pdf


def configure_console() -> None:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass


def read_paths(list_path: str) -> list[str]:
    with open(list_path, "r", encoding="utf-8") as handle:
        return [line.rstrip("\n") for line in handle if line.strip()]


def pagecount(pdf_path: str) -> int:
    with Pdf.open(pdf_path) as pdf:
        return len(pdf.pages)


def merge(list_path: str, desktop: str) -> int:
    files = read_paths(list_path)
    if not files:
        print("没有文件")
        return 1

    print()
    print("已拖入的文件：")
    print()
    for index, path in enumerate(files):
        try:
            pages = pagecount(path)
        except Exception:
            pages = "?"
        print(f"  [{index + 1}] {os.path.basename(path)}  （{pages}页）")
    print()

    user_input = input("请输入顺序（如 2 4 6 3 1 10，空格分隔，直接回车=默认顺序）: ").strip()
    if not user_input:
        order = list(range(1, len(files) + 1))
    else:
        order = []
        for item in user_input.split():
            try:
                number = int(item)
                if 1 <= number <= len(files):
                    order.append(number)
            except ValueError:
                pass

    if not order:
        print("顺序无效")
        return 1
    sorted_files = [files[number - 1] for number in order]

    print()
    print("请选择合并模式：")
    print("  1 = 不改变任何东西（保持原样）")
    print("  2 = 统一页面宽度（内容自动缩放）")
    print()
    mode = input("输入数字（默认1）: ").strip() or "1"

    out_pdf = Pdf.new()
    if mode == "2":
        max_width = 0.0
        for path in sorted_files:
            with Pdf.open(path) as src:
                for page in src.pages:
                    width = float(page.MediaBox[2]) - float(page.MediaBox[0])
                    if width > max_width:
                        max_width = width
        print(f"  最大宽度：{max_width:.1f} pt")

        for path in sorted_files:
            with Pdf.open(path) as src:
                for page in src.pages:
                    width = float(page.MediaBox[2]) - float(page.MediaBox[0])
                    height = float(page.MediaBox[3]) - float(page.MediaBox[1])
                    contents = page.obj["/Contents"]
                    if isinstance(contents, Array):
                        parts = [stream.read_bytes() for stream in contents]
                        original = b"\n".join(parts)
                    else:
                        original = contents.read_bytes()

                    out_pdf.pages.append(page)
                    new_page = out_pdf.pages[-1]
                    if width < max_width:
                        scale = max_width / width
                        new_content = (
                            b"q "
                            + f"{scale:.6f} 0 0 {scale:.6f} 0 0 cm\n".encode()
                            + original
                            + b"\nQ\n"
                        )
                        new_page.obj["/Contents"] = out_pdf.make_stream(new_content)
                        new_page.MediaBox = Array([0, 0, max_width, height * scale])
    else:
        for path in sorted_files:
            with Pdf.open(path) as src:
                for page in src.pages:
                    out_pdf.pages.append(page)

    timestamp = datetime.now().strftime("%Y.%m.%d %H.%M")
    suffix = "".join(random.choices("abcdefghijklmnopqrstuvwxyz", k=4))
    output_path = os.path.join(
        desktop, f"合并输出{len(sorted_files)}个 {timestamp} {suffix}.pdf"
    )
    out_pdf.save(output_path)
    print()
    print(f"完成：{output_path}")
    return 0


def split(list_path: str, desktop: str) -> int:
    files = read_paths(list_path)
    if not files:
        print("没有文件")
        return 1
    pdf_path = files[0]
    base = os.path.splitext(os.path.basename(pdf_path))[0]

    with Pdf.open(pdf_path) as src:
        total = len(src.pages)
        print()
        print(f"  文件：{os.path.basename(pdf_path)}")
        print(f"  总页数：{total}")
        print()
        print("  输入页码范围，空格分隔，每个范围生成一个 PDF")
        print("  例1：1-3 4-9 10-17")
        print("  例2：1-5 8-11 10-16 18-33 可跳过 可重叠")
        print()

        while True:
            user_input = input("请输入范围: ").strip()
            if not user_input:
                print("  请输入至少一个范围")
                continue
            ranges: list[tuple[int, int]] = []
            valid = True
            for item in user_input.split():
                try:
                    if "-" in item:
                        start_text, end_text = item.split("-", 1)
                        start, end = int(start_text), int(end_text)
                    else:
                        start = end = int(item)
                except ValueError:
                    print(f"  格式错误：{item}")
                    valid = False
                    break
                if start < 1 or end < 1 or start > total or end > total:
                    print(f"  页码超出范围：{item}  必须在 1 到 {total} 之间")
                    valid = False
                    break
                if start > end:
                    print(f"  起始页大于结束页：{item}")
                    valid = False
                    break
                ranges.append((start, end))
            if valid and ranges:
                break

        timestamp = datetime.now().strftime("%Y.%m.%d %H.%M")
        print()
        print(f"  共生成 {len(ranges)} 个 PDF：")
        print()
        for start, end in ranges:
            page_label = f"({start})" if start == end else f"({start}-{end})"
            output_path = os.path.join(desktop, f"{base} {page_label} {timestamp}.pdf")
            if os.path.exists(output_path):
                print(f"    已存在：{os.path.basename(output_path)}")
                answer = input("    覆盖？(Y=覆盖 / 其他=跳过): ").strip().lower()
                if answer != "y":
                    print(f"    跳过：{os.path.basename(output_path)}")
                    continue
            out_pdf = Pdf.new()
            for index in range(start - 1, end):
                out_pdf.pages.append(src.pages[index])
            out_pdf.save(output_path)
            print(f"    {os.path.basename(output_path)}")
        print()
        print("  完成")
    return 0


def main(argv: list[str]) -> int:
    configure_console()
    if not argv:
        print("用法：pikepdf-tools.exe merge|split <input-list.txt> <desktop>")
        print("      pikepdf-tools.exe pagecount <input.pdf>")
        return 2
    command = argv[0].lower()
    try:
        if command == "pagecount" and len(argv) == 2:
            print(pagecount(argv[1]))
            return 0
        if command == "merge" and len(argv) == 3:
            return merge(argv[1], argv[2])
        if command == "split" and len(argv) == 3:
            return split(argv[1], argv[2])
        print("参数错误。")
        return 2
    except KeyboardInterrupt:
        print("\n已取消。")
        return 130
    except Exception as exc:
        print(f"\n处理失败：{exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
