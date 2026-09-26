#!/usr/bin/env python3
"""从 Godot 官方导出模板包（.tpz，约 1GB 的 zip）里只下载网页模板那一个文件（约 8MB）。

利用 HTTP Range 读 zip 末尾的中央目录，找到目标条目的偏移，再只取那一段。
用法：python3 tools/fetch_web_template.py <版本如 4.3> <输出目录>
"""
import struct
import sys
import urllib.request
import zlib

WANT = ("templates/web_nothreads_release.zip", "templates/version.txt")


def get(url, start, end):
    req = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}"})
    with urllib.request.urlopen(req, timeout=120) as r:
        if r.status != 206:
            sys.exit(f"服务器不支持分段下载（HTTP {r.status}）")
        total = int(r.headers["Content-Range"].split("/")[-1])
        return r.read(), total


def main():
    ver, out = sys.argv[1], sys.argv[2]
    url = f"https://github.com/godotengine/godot/releases/download/{ver}-stable/Godot_v{ver}-stable_export_templates.tpz"
    _, size = get(url, 0, 0)
    tail, _ = get(url, max(0, size - 65536 - 22), size - 1)
    i = tail.rfind(b"PK\x05\x06")
    if i < 0:
        sys.exit("找不到 zip 目录结尾")
    cd_size, cd_off = struct.unpack("<II", tail[i + 12:i + 20])
    if cd_off == 0xFFFFFFFF:  # zip64
        j = tail.rfind(b"PK\x06\x06")
        cd_size, cd_off = struct.unpack("<QQ", tail[j + 40:j + 56])
    cd, _ = get(url, cd_off, cd_off + cd_size - 1)

    p, found = 0, {}
    while p < len(cd) and cd[p:p + 4] == b"PK\x01\x02":
        method, = struct.unpack("<H", cd[p + 10:p + 12])
        csize, usize = struct.unpack("<II", cd[p + 20:p + 28])
        nlen, elen, clen = struct.unpack("<HHH", cd[p + 28:p + 34])
        loff, = struct.unpack("<I", cd[p + 42:p + 46])
        name = cd[p + 46:p + 46 + nlen].decode()
        extra = cd[p + 46 + nlen:p + 46 + nlen + elen]
        if 0xFFFFFFFF in (csize, usize, loff):  # zip64 扩展字段
            q = 0
            while q < len(extra):
                hid, hlen = struct.unpack("<HH", extra[q:q + 4])
                if hid == 1:
                    vals = list(struct.unpack(f"<{hlen // 8}Q", extra[q + 4:q + 4 + hlen]))
                    if usize == 0xFFFFFFFF: usize = vals.pop(0)
                    if csize == 0xFFFFFFFF: csize = vals.pop(0)
                    if loff == 0xFFFFFFFF: loff = vals.pop(0)
                q += 4 + hlen
        if name in WANT:
            found[name] = (method, csize, usize, loff)
        p += 46 + nlen + elen + clen

    import os
    os.makedirs(out, exist_ok=True)
    for name in WANT:
        if name not in found:
            sys.exit(f"模板包里没有 {name}")
        method, csize, usize, loff = found[name]
        hdr, _ = get(url, loff, loff + 29)
        nlen, elen = struct.unpack("<HH", hdr[26:30])
        start = loff + 30 + nlen + elen
        data, _ = get(url, start, start + csize - 1)
        if method == 8:
            data = zlib.decompressobj(-15).decompress(data)
        elif method != 0:
            sys.exit(f"{name} 压缩方式 {method} 不支持")
        if len(data) != usize:
            sys.exit(f"{name} 大小不符：{len(data)} != {usize}")
        with open(os.path.join(out, os.path.basename(name)), "wb") as f:
            f.write(data)
        print(f"{name}：{usize // 1024} KB")


if __name__ == "__main__":
    main()
