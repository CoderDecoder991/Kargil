"""Cut AK-47 weapon clips from the CC0 Free Firearm Sound Library (Prepared SFX Library/AK-47).

Usage: py -I tools/extract_ak_sounds.py <path to Prepared SFX Library/AK-47>
Source recordings: C_28P (single shots, near), C_27P (long bursts, near); 24-bit 96 kHz stereo.
Writes 16-bit 48 kHz stereo clips to assets/audio/weapons/.
"""
import sys, wave
from pathlib import Path
import numpy as np

OUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "weapons"
RATE = 48000
PRE = 0.004

def load(path):
    w = wave.open(str(path))
    ch, n = w.getnchannels(), w.getnframes()
    b = np.frombuffer(w.readframes(n), np.uint8).reshape(-1, 3).astype(np.int32)
    v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
    v = np.where(v >= 1 << 23, v - (1 << 24), v).astype(np.float64) / (1 << 23)
    x = v.reshape(-1, ch)
    # Halve 96 kHz to 48 kHz through a 20 kHz windowed-sinc low-pass.
    taps = np.arange(-64, 65)
    h = np.sinc(2 * 20000 / 96000 * taps) * np.blackman(len(taps))
    h /= h.sum()
    return np.stack([np.convolve(x[:, c], h, "same")[::2] for c in range(ch)], axis=1)

def onsets(x, thr=0.25, gap=0.05):
    hop = int(RATE * 0.002)
    m = np.abs(x).max(axis=1)
    env = m[: len(m) // hop * hop].reshape(-1, hop).max(axis=1)
    found = []
    for i, e in enumerate(env):
        if e > env.max() * thr and (not found or i * hop / RATE - found[-1] > gap):
            found.append(i * hop / RATE)
    return found

def cut(x, start, end, fade_in=0.0015, fade_out=0.03):
    seg = x[int(start * RATE): int(end * RATE)].copy()
    fi, fo = max(1, int(fade_in * RATE)), max(1, int(fade_out * RATE))
    seg[:fi] *= np.linspace(0, 1, fi)[:, None]
    seg[-fo:] *= np.linspace(1, 0, fo)[:, None] ** 2
    return seg

def write(name, seg, gain=0.89):
    peak = np.abs(seg).max()
    seg = seg * (gain / peak if peak > gain else 1.0)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes((np.clip(seg, -1, 1) * 32767).astype("<i2").tobytes())
    print(name, "%.3f s" % (len(seg) / RATE))

src = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
single = load(src / "C_28P.wav")
for i, t in enumerate(onsets(single)[:3]):
    write("ak_single_%d.wav" % (i + 1), cut(single, t - PRE, t + 1.8, fade_out=0.6))

auto = load(src / "C_27P.wav")
times = onsets(auto)
bursts = [[t for t in times if t < 3.0], [t for t in times if t >= 3.0]]
body = 0.122
n = 0
for burst in bursts:
    interval = float(np.median(np.diff(burst)))
    for t in burst[1:-1]:
        n += 1
        write("ak_auto_%d.wav" % n, cut(auto, t - PRE, t + body))
    last = burst[-1]
    k = bursts.index(burst) + 1
    write("ak_last_round_%d.wav" % k, cut(auto, last - PRE, last + 2.0, fade_out=0.7))
    write("ak_auto_tail_%d.wav" % k, cut(auto, last + interval, last + 2.0, fade_in=0.012, fade_out=0.7))
    print("burst interval %.4f s" % interval)
    # Seamless full-auto loop: shot 2 up to the onset of the final shot. Its last few ms are
    # crossfaded into the audio just before the loop start, so the wrap is continuous.
    s, e = int((burst[1] - PRE) * RATE), int((last - PRE) * RATE)
    seg = auto[s:e].copy()
    xf = int(0.004 * RATE)
    ramp = np.linspace(0, 1, xf)[:, None]
    seg[-xf:] = seg[-xf:] * (1 - ramp) + auto[s - xf:s] * ramp
    write("ak_auto_loop_%d.wav" % k, seg)
    print("loop %d: %d rounds, %.4f s per round" % (k, len(burst) - 2, (last - burst[1]) / (len(burst) - 2)))

# Recorded three-round strings: the last three shots of each four-shot short burst, with natural tail.
short = load(src / "C_29P.wav")
times = onsets(short)
for k, burst in enumerate([[t for t in times if t < 3.0], [t for t in times if t >= 3.0]], 1):
    write("ak_burst_%d.wav" % k, cut(short, burst[1] - PRE, burst[-1] + 2.0, fade_out=0.7))
