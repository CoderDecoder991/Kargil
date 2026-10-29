"""Generate original low-cost wind and surface footfall placeholders."""
import math
import random
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
RATE = 22050

def write(name, samples):
    with wave.open(str(OUT / name), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(b"".join(int(max(-1, min(1, s)) * 32767).to_bytes(2, "little", signed=True) for s in samples))

rng = random.Random(1999)
low = 0.0
wind = []
for i in range(RATE * 24):
    t = i / RATE
    low = 0.994 * low + 0.006 * rng.uniform(-1, 1)
    gust = 0.22 + 0.13 * math.sin(t * 0.47) + 0.08 * math.sin(t * 1.14)
    wind.append(low * gust + 0.014 * rng.uniform(-1, 1))
write("wind.wav", wind)

for name, pitch, decay in [("snow_step.wav", 180, 16), ("rock_step.wav", 480, 25)]:
    rng.seed(pitch)
    low = 0.0
    samples = []
    for i in range(int(RATE * 0.32)):
        t = i / RATE
        low = 0.58 * low + 0.42 * rng.uniform(-1, 1)
        transient = math.exp(-t * decay)
        grain = math.sin(t * pitch * 2 * math.pi) * 0.12
        samples.append((low * 0.36 + grain) * transient)
    write(name, samples)

rng.seed(199905)
fire = []
last = 0.0
for i in range(int(RATE * 1.4)):
    t = i / RATE
    last = 0.91 * last + 0.09 * rng.uniform(-1, 1)
    pulse = math.exp(-t * 12) + (0.43 * math.exp(-(t - 0.31) * 14) if t >= 0.31 else 0)
    fire.append((last * 0.54 + 0.08 * math.sin(t * 110 * math.pi)) * pulse)
write("distant_fire.wav", fire)
