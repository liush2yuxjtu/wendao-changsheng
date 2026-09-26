#!/usr/bin/env python3
"""程序化合成全部音频（无外部素材，无版权问题）。

用法：python3 tools/make_audio.py   （需要 numpy + ffmpeg/libvorbis）
输出：assets/audio/*.ogg
- qin_XX.ogg  古琴式拨弦（Karplus-Strong + 滑音），五声音阶两个八度
- drone.ogg   低音持续铺底，16 秒无缝循环
- sfx_*.ogg   各类音效
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


def save(name, x, peak=0.8):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    pcm = (x * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as t:
        tmp = t.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dst = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    os.remove(tmp)


def mix(*xs):
    n = max(len(x) for x in xs)
    out = np.zeros(n)
    for x in xs:
        out[: len(x)] += x
    return out


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(dur, attack=0.005, decay=1.0):
    t = t_axis(dur)
    e = np.exp(-t / decay)
    a = int(SR * attack)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def pluck(freq, dur=3.0, bright=0.5, slide=0.0):
    """Karplus-Strong 拨弦；slide>0 时起音后轻微上滑（吟猱感）。"""
    n = int(SR * dur)
    out = np.zeros(n)
    period = SR / freq
    buf_len = int(period) + 2
    buf = rng.uniform(-1, 1, buf_len)
    # 先低通一下初始噪声，音色更圆润（古琴偏暗）
    for _ in range(3):
        buf = 0.5 * (buf + np.roll(buf, 1))
    pos = 0.0
    idx = 0
    decay = 0.996 - (1 - bright) * 0.004
    delay = np.array(buf)
    L = len(delay)
    last = 0.0
    for i in range(n):
        # 滑音：周期随时间轻微变短
        p = period * (1.0 - slide * min(i / (SR * 0.4), 1.0))
        read = (idx - p) % L
        j = int(read)
        f = read - j
        s = delay[j] * (1 - f) + delay[(j + 1) % L] * f
        y = decay * 0.5 * (s + last)
        last = s
        delay[idx % L] = y
        out[i] = y
        idx = (idx + 1) % L
    # 琴身共鸣：叠一点低八度正弦 + 泛音
    t = t_axis(dur)
    body = 0.15 * np.sin(2 * np.pi * freq * t) * np.exp(-t / 1.2)
    fade = np.ones(n)
    fade[-int(SR * 0.3):] = np.linspace(1, 0, int(SR * 0.3))
    return mix(out, body) * fade


def bell(freq, dur=2.5, partials=((1, 1), (2.76, 0.5), (5.4, 0.25), (8.93, 0.12)), decay=1.0):
    t = t_axis(dur)
    x = sum(a * np.sin(2 * np.pi * freq * r * t) * np.exp(-t * r ** 0.5 / decay) for r, a in partials)
    x *= env(dur, 0.002, 10)
    return x


def gong(freq, dur=4.0):
    t = t_axis(dur)
    ratios = [1, 1.52, 2.03, 2.61, 3.3, 4.1]
    x = np.zeros_like(t)
    for k, r in enumerate(ratios):
        wob = 1 + 0.003 * np.sin(2 * np.pi * (0.7 + k * 0.3) * t)
        x += (0.8 ** k) * np.sin(2 * np.pi * freq * r * wob * t) * np.exp(-t / (dur * (0.5 - k * 0.05)))
    x += 0.3 * rng.uniform(-1, 1, len(t)) * np.exp(-t / 0.05)
    return x * env(dur, 0.004, 100)


def noise_burst(dur, cutoff_passes=6, decay=0.03):
    x = rng.uniform(-1, 1, int(SR * dur))
    for _ in range(cutoff_passes):
        x = 0.5 * (x + np.roll(x, 1))
    return x * env(dur, 0.001, decay)


def main():
    # 五声音阶（宫商角徵羽）：C D E G A，从 C3 到 A4
    base = 130.81
    semis = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]
    for k, s in enumerate(semis):
        f = base * 2 ** (s / 12)
        save("qin_%02d" % k, pluck(f, 3.2, bright=0.35, slide=0.004 if k % 3 == 0 else 0.0), 0.7)

    # 16 秒无缝循环铺底：频率取 1/16 Hz 的整数倍
    dur = 16.0
    t = t_axis(dur)
    def q(f):
        return round(f * dur) / dur
    trem = 0.75 + 0.25 * np.sin(2 * np.pi * t / 8.0)
    drone = (np.sin(2 * np.pi * q(65.41) * t) + 0.6 * np.sin(2 * np.pi * q(98.0) * t)
             + 0.25 * np.sin(2 * np.pi * q(130.81) * t) + 0.12 * np.sin(2 * np.pi * q(196.0) * t)) * trem
    save("drone", drone, 0.5)

    # 音效
    save("sfx_tap", mix(noise_burst(0.25, 8, 0.02) * 0.5, bell(880, 0.25, ((1, 1), (2.0, 0.2)), 0.08)), 0.5)
    ok = np.concatenate([bell(523.25, 0.18, decay=0.4)[: int(SR * 0.12)], bell(783.99, 1.4, decay=0.6)])
    save("sfx_break_ok", ok, 0.6)
    major = gong(110, 4.0)
    arp = np.zeros_like(major)
    for i, f in enumerate([261.63, 329.63, 392.0, 523.25, 659.25]):
        b = bell(f, 2.5, decay=0.8)
        st = int(SR * (0.25 + i * 0.12))
        arp[st: st + len(b)] += b[: len(arp) - st] * 0.5
    save("sfx_break_major", mix(major, arp), 0.85)
    fail = mix(gong(55, 2.0) * 0.8, noise_burst(2.0, 12, 0.25) * 0.6)
    save("sfx_break_fail", fail, 0.7)
    save("sfx_event", bell(1046.5, 1.5, decay=0.5), 0.45)
    win = np.zeros(int(SR * 1.2))
    for i, f in enumerate([392.0, 523.25]):
        p = pluck(f, 1.0, 0.6)
        st = int(SR * i * 0.09)
        win[st: st + len(p)] += p[: len(win) - st]
    save("sfx_win", win, 0.5)
    lose = np.zeros(int(SR * 1.2))
    for i, f in enumerate([196.0, 146.83]):
        p = pluck(f, 1.0, 0.3)
        st = int(SR * i * 0.18)
        lose[st: st + len(p)] += p[: len(lose) - st]
    save("sfx_lose", lose, 0.5)
    item = np.zeros(int(SR * 1.5))
    for i, f in enumerate([1318.5, 1568.0, 2093.0]):
        b = bell(f, 1.2, decay=0.4)
        st = int(SR * i * 0.07)
        item[st: st + len(b)] += b[: len(item) - st]
    save("sfx_item", item, 0.45)
    save("sfx_craft", mix(noise_burst(0.3, 3, 0.08) * 0.4, pluck(293.66, 0.8, 0.5) * 0.8), 0.45)
    save("sfx_death", gong(41.2, 5.0), 0.7)


if __name__ == "__main__":
    main()
