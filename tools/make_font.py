#!/usr/bin/env python3
"""把 Noto Serif CJK SC 裁剪成只含游戏用到的字（约几百 KB），供网页/手机端使用。

改了文案后重新运行：python3 tools/make_font.py
来源字体：Noto Serif CJK SC Regular（SIL Open Font License 1.1），默认读系统 fonts-noto-cjk，
也可用 NOTO_TTC=/path/to/NotoSerifCJK-Regular.ttc 指定。
"""
import glob
import os
import subprocess

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.environ.get("NOTO_TTC", "/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc")
DST = os.path.join(ROOT, "assets", "fonts", "NotoSerifSC-wendao.otf")

chars = set(chr(c) for c in range(0x20, 0x7F))
chars |= set("，。！？、：；“”‘’（）《》【】「」·…—～×％＋－　0123456789")
for path in glob.glob(os.path.join(ROOT, "scripts", "*.gd")) + [os.path.join(ROOT, "project.godot")]:
    with open(path, encoding="utf-8") as f:
        chars |= set(f.read())
chars = {c for c in chars if c.isprintable() or c == "　"}
text = "".join(sorted(chars))
subprocess.run([
    "pyftsubset", SRC, "--font-number=2", "--text=" + text,
    "--output-file=" + DST, "--layout-features=*", "--no-hinting", "--desubroutinize",
], check=True)
print("glyph chars:", len(chars), "->", DST, os.path.getsize(DST) // 1024, "KB")
