#!/usr/bin/env python3
"""检查裁剪字体是否覆盖了脚本里用到的每一个字。

改了中文文案却忘了重跑 tools/make_font.py，新字在网页/手机上会显示成方块。
这个检查把问题提前到本地：缺字就失败，并列出缺哪些字。
用法：python3 tools/check_font.py   （需要 fonttools）
"""
import glob
import os
import sys

from fontTools.ttLib import TTFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FONT = os.path.join(ROOT, "assets", "fonts", "NotoSerifSC-wendao.otf")

if not os.path.isfile(FONT):
    sys.exit(f"缺少字体 {FONT}，先运行 python3 tools/make_font.py")

used = set()
for path in glob.glob(os.path.join(ROOT, "scripts", "*.gd")) + [os.path.join(ROOT, "project.godot")]:
    with open(path, encoding="utf-8") as f:
        used |= set(f.read())
# 只关心会显示出来的非 ASCII 字符（ASCII 由 make_font 全量保留）
used = {c for c in used if ord(c) > 0x7E and (c.isprintable() or c == "　")}

cmap = TTFont(FONT).getBestCmap()
missing = sorted(c for c in used if ord(c) not in cmap)
if missing:
    print(f"字体缺 {len(missing)} 个字：{''.join(missing)}")
    print("修复：python3 tools/make_font.py（需要 Noto Serif CJK），然后提交 assets/fonts/")
    sys.exit(1)
print(f"字体覆盖 OK：{len(used)} 个非 ASCII 字符全部可显示")
