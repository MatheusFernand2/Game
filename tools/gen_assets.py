"""
Gera os assets provisórios do jogo (sons e texturas) de forma procedural.

Uso:  python tools/gen_assets.py
Requer: numpy, scipy, pillow

Tudo aqui é placeholder sintetizado — dá pra trocar depois por sons/texturas
reais (Freesound, Poly Haven etc.) mantendo os mesmos nomes de arquivo.
"""
from __future__ import annotations

import os
import struct
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX = os.path.join(ROOT, "assets", "audio")
TEX = os.path.join(ROOT, "assets", "textures")
SR = 22050
rng = np.random.default_rng(1337)


# ----------------------------------------------------------------- áudio utils

def write_wav(name: str, data: np.ndarray, loop: bool = False, normalize: float = 0.9) -> None:
    os.makedirs(SFX, exist_ok=True)
    data = np.asarray(data, dtype=np.float64)
    peak = np.max(np.abs(data)) or 1.0
    data = data / peak * normalize
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    path = os.path.join(SFX, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    if loop:
        _add_smpl_loop(path, len(pcm))


def _add_smpl_loop(path: str, n_samples: int) -> None:
    """Anexa um chunk 'smpl' com ponto de loop (o Godot detecta sozinho)."""
    smpl = struct.pack(
        "<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0
    ) + struct.pack("<6I", 0, 0, 0, n_samples - 1, 0, 0)
    chunk = b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(path, "r+b") as f:
        content = f.read()
        content += chunk
        riff_size = len(content) - 8
        content = content[:4] + struct.pack("<I", riff_size) + content[8:]
        f.seek(0)
        f.write(content)
        f.truncate()


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SR)) / SR


def noise(seconds: float) -> np.ndarray:
    return rng.uniform(-1, 1, int(seconds * SR))


def bandpass(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, cutoff, order=2):
    sos = signal.butter(order, cutoff, btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, cutoff, order=2):
    sos = signal.butter(order, cutoff, btype="high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def env_exp(n, decay):
    return np.exp(-np.arange(n) / SR * decay)


def reverb(x, seconds=1.2, decay=4.0, wet=0.35, tone=3500):
    ir = noise(seconds) * env_exp(int(seconds * SR), decay)
    ir = lowpass(ir, tone)
    ir[0] = 0
    wet_sig = signal.fftconvolve(x, ir)[: len(x) + len(ir) - 1]
    dry = np.concatenate([x, np.zeros(len(ir) - 1)])
    wet_sig = wet_sig / (np.max(np.abs(wet_sig)) or 1) * (np.max(np.abs(x)) or 1)
    return dry * (1 - wet) + wet_sig * wet


def pad(x, seconds):
    return np.concatenate([x, np.zeros(int(seconds * SR))])


# ----------------------------------------------------------------- sons

def footsteps():
    for i in range(4):
        dur = 0.35
        n = int(dur * SR)
        t = t_axis(dur)
        f0 = rng.uniform(70, 110)
        thud = np.sin(2 * np.pi * f0 * t * (1 - 0.3 * t)) * env_exp(n, 28)
        click = bandpass(noise(dur), 900, 4000) * env_exp(n, 90) * 0.5
        scuff = bandpass(noise(dur), 300, 1500) * env_exp(n, 18) * 0.25
        x = thud + click + scuff
        # Às vezes o assoalho range.
        if i in (1, 3):
            creak_t = t_axis(0.25)
            rate = 35 + 15 * np.sin(2 * np.pi * 3 * creak_t)
            phase = np.cumsum(rate / SR)
            pulses = (np.diff(np.floor(phase), prepend=0) > 0).astype(float)
            creak = bandpass(pulses, 600, 1400, 4) * np.hanning(len(pulses)) * 3
            x[: len(creak)] += creak * 0.6
        write_wav(f"footstep_wood_{i + 1}.wav", reverb(x, 0.6, 9, 0.25))


def flashlight_click():
    dur = 0.12
    n = int(dur * SR)
    x = highpass(noise(dur), 2000) * env_exp(n, 160)
    s = int(0.03 * SR)
    m = n - s
    x[s:] += highpass(noise(dur), 2500)[:m] * env_exp(m, 200) * 0.7
    write_wav("flashlight_click.wav", x, normalize=0.6)


def breathing():
    dur = 4.0
    t = t_axis(dur)
    n = len(t)
    x = noise(dur)
    inhale = bandpass(x, 900, 3200) * np.clip(np.sin(np.pi * np.clip(t / 1.5, 0, 1)), 0, 1)
    exhale_env = np.clip(np.sin(np.pi * np.clip((t - 1.8) / 1.9, 0, 1)), 0, 1)
    exhale = bandpass(x, 400, 1800) * exhale_env
    y = inhale * 0.7 + exhale
    y *= np.where((t > 0.05) & (t < dur - 0.05), 1, 0)
    write_wav("breathing_loop.wav", y, loop=True, normalize=0.7)


def heartbeat():
    dur = 1.0
    n = int(dur * SR)
    y = np.zeros(n)

    def beat(start, amp):
        bn = int(0.18 * SR)
        bt = np.arange(bn) / SR
        b = np.sin(2 * np.pi * 52 * bt) * env_exp(bn, 22) + np.sin(2 * np.pi * 95 * bt) * env_exp(bn, 40) * 0.5
        s = int(start * SR)
        y[s : s + bn] += b * amp

    beat(0.0, 1.0)
    beat(0.24, 0.7)
    write_wav("heartbeat_loop.wav", lowpass(y, 300), loop=True)


def ambient_drone():
    dur = 32.0
    t = t_axis(dur)
    y = np.zeros_like(t)
    # Frequências múltiplas de 1/dur para o loop fechar perfeito.
    for f, a in [(41.0, 1.0), (41.25, 0.8), (55.0, 0.5), (61.9375, 0.35), (82.0, 0.25), (123.0625, 0.08)]:
        y += np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * a
    # Vento/ar abafado: ruído filtrado com cross-fade circular para loop.
    wind = lowpass(noise(dur + 2), 350)
    fade = int(2 * SR)
    w = wind[fade:]
    w[:fade] = w[:fade] * np.linspace(0, 1, fade) + wind[len(wind) - fade:] * np.linspace(1, 0, fade)
    w = w[: len(t)]
    wind_lfo = 0.5 + 0.5 * np.sin(2 * np.pi * t / 16.0)
    y = y * 0.5 + w * 2.2 * wind_lfo
    write_wav("ambient_drone_loop.wav", y, loop=True, normalize=0.8)


def light_buzz():
    dur = 2.0
    t = t_axis(dur)
    y = np.zeros_like(t)
    for h in range(1, 12):
        y += np.sin(2 * np.pi * 60 * h * t) / h ** 1.2
    y = np.sign(y) * np.abs(y) ** 0.7
    y += bandpass(noise(dur), 3000, 7000) * 0.05
    write_wav("light_buzz_loop.wav", highpass(y, 100), loop=True, normalize=0.5)


def bulb_pop():
    dur = 0.6
    n = int(dur * SR)
    x = highpass(noise(dur), 1500) * env_exp(n, 30)
    x += bandpass(noise(dur), 4000, 9000) * env_exp(n, 12) * 0.3  # vidrinhos
    write_wav("bulb_pop.wav", reverb(x, 0.8, 6, 0.3))


def door_creak():
    dur = 1.6
    t = t_axis(dur)
    rate = 18 + 40 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.7 * t + 1)) + rng.normal(0, 4, len(t))
    phase = np.cumsum(rate / SR)
    pulses = (np.diff(np.floor(phase), prepend=0) > 0).astype(float)
    pulses *= rng.uniform(0.5, 1.0, len(pulses))
    y = bandpass(pulses, 500, 900, 6) * 2 + bandpass(pulses, 1400, 2200, 6) + bandpass(pulses, 2800, 3600, 4) * 0.5
    y *= np.hanning(len(y)) ** 0.5
    write_wav("door_creak.wav", reverb(y, 1.0, 5, 0.3))


def door_slam():
    dur = 0.8
    n = int(dur * SR)
    t = t_axis(dur)
    boom = np.sin(2 * np.pi * 60 * t * (1 - 0.4 * t)) * env_exp(n, 9)
    crack = bandpass(noise(dur), 200, 3000) * env_exp(n, 35)
    rattle = bandpass(noise(dur), 2000, 6000) * env_exp(n, 15) * 0.3
    write_wav("door_slam.wav", pad(reverb(boom * 1.4 + crack + rattle, 1.6, 3.5, 0.4), 0.2))


def door_locked():
    """Maçaneta forçada: estalos metálicos."""
    out = np.zeros(int(0.7 * SR))
    for start in (0.0, 0.12, 0.31, 0.42):
        dur = 0.09
        n = int(dur * SR)
        t = t_axis(dur)
        click = (np.sin(2 * np.pi * 2400 * t) + np.sin(2 * np.pi * 3700 * t) * 0.6) * env_exp(n, 70)
        click += bandpass(noise(dur), 1500, 5000) * env_exp(n, 120) * 0.8
        s = int(start * SR)
        out[s : s + n] += click
    write_wav("door_locked.wav", reverb(out, 0.5, 8, 0.2), normalize=0.7)


def pickup():
    dur = 0.25
    n = int(dur * SR)
    x = bandpass(noise(dur), 1200, 5000) * env_exp(n, 40)
    x[: int(0.05 * SR)] += highpass(noise(0.05), 3000) * 0.5
    write_wav("pickup.wav", x, normalize=0.6)


def knocks():
    out = np.zeros(0)
    for i, gap in enumerate([0.0, 0.32, 0.30]):
        out = np.concatenate([out, np.zeros(int(gap * SR))])
        dur = 0.2
        n = int(dur * SR)
        t = t_axis(dur)
        k = np.sin(2 * np.pi * 140 * t) * env_exp(n, 40) + bandpass(noise(dur), 400, 2000) * env_exp(n, 70) * 0.6
        out = np.concatenate([out, k * (1.0 - i * 0.05)])
    out = lowpass(out, 1800)  # "do outro lado da parede"
    write_wav("knock_3x.wav", reverb(pad(out, 0.2), 1.4, 4, 0.4))


def whisper():
    dur = 2.8
    t = t_axis(dur)
    x = noise(dur)
    y = np.zeros_like(t)
    # Sílabas sem sentido: formantes que mudam aleatoriamente.
    syl = 0.0
    while syl < dur - 0.2:
        length = rng.uniform(0.12, 0.3)
        s, e = int(syl * SR), int(min(dur, syl + length) * SR)
        f1, f2 = rng.uniform(500, 900), rng.uniform(1500, 2800)
        seg = bandpass(x[s:e], f1 * 0.8, f1 * 1.2) + bandpass(x[s:e], f2 * 0.9, f2 * 1.1) * 0.8
        seg += highpass(x[s:e], 4500) * 0.6  # sibilância
        y[s:e] += seg * np.hanning(e - s)
        syl += length + rng.uniform(0.02, 0.15)
    write_wav("whisper.wav", reverb(y, 2.0, 2.5, 0.5), normalize=0.7)


def stinger():
    """O 'GRITO' do susto: cluster dissonante + estouro grave."""
    dur = 2.6
    n = int(dur * SR)
    t = t_axis(dur)
    y = np.zeros(n)
    attack = np.clip(t / 0.015, 0, 1)
    decay = np.exp(-t * 1.6)
    for f in [880, 932, 987, 1046, 1244, 1318, 1760, 1864]:
        vib = 1 + 0.02 * np.sin(2 * np.pi * rng.uniform(5, 9) * t)
        y += signal.sawtooth(2 * np.pi * f * vib * t + rng.uniform(0, 6)) * 0.12
    y = bandpass(y, 600, 5000) * attack * decay
    screech = bandpass(noise(dur), 2500, 6000) * np.exp(-t * 3) * 0.5
    boom = np.sin(2 * np.pi * 38 * t) * np.exp(-t * 2.2) * 1.4 * attack
    hit = lowpass(noise(dur), 400) * np.exp(-t * 18) * 2
    write_wav("stinger_scream.wav", reverb(y + screech + boom + hit, 2.5, 2.2, 0.35), normalize=0.98)


def low_rumble():
    """Tensão crescente antes de um susto."""
    dur = 6.0
    t = t_axis(dur)
    rise = (t / dur) ** 2
    y = np.sin(2 * np.pi * (30 + 25 * rise) * t) * rise
    y += lowpass(noise(dur), 120) * 3 * rise
    y += np.sin(2 * np.pi * (440 + 30 * np.sin(2 * np.pi * 0.3 * t)) * t) * 0.05 * rise
    y *= np.clip((dur - t) / 0.05, 0, 1)
    write_wav("tension_rise.wav", y)


# ----------------------------------------------------------------- texturas

def save_tex(name, img: Image.Image, size=128):
    os.makedirs(TEX, exist_ok=True)
    img = img.convert("RGB").resize((size, size), Image.NEAREST)
    img = img.quantize(colors=32, dither=Image.Dither.NONE).convert("RGB")
    img.save(os.path.join(TEX, name))


def stain_layer(size, count, color, max_r, blur):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(count):
        x, y = rng.integers(0, size, 2)
        r = rng.integers(max_r // 4, max_r)
        a = int(rng.integers(20, 70))
        for ox in (-size, 0, size):  # repetir nas bordas para tileable
            for oy in (-size, 0, size):
                d.ellipse([x - r + ox, y - r + oy, x + r + ox, y + r + oy], fill=color + (a,))
    return layer.filter(ImageFilter.GaussianBlur(blur))


def wallpaper():
    s = 256
    base = np.zeros((s, s, 3))
    base[:] = (92, 84, 62)
    xs = np.arange(s)
    stripe = ((xs // 16) % 2 == 0)[None, :, None]
    base = np.where(stripe, base * 0.88, base)
    img = Image.fromarray(base.astype(np.uint8))
    d = ImageDraw.Draw(img)
    # Motivo floral simplificado.
    for cx in range(16, s, 64):
        for cy in range(16, s, 64):
            off = 32 if (cy // 64) % 2 else 0
            x = (cx + off) % s
            d.ellipse([x - 6, cy - 9, x + 6, cy + 9], outline=(64, 58, 42))
            d.line([x, cy - 14, x, cy + 14], fill=(70, 62, 46))
    img = Image.alpha_composite(img.convert("RGBA"), stain_layer(s, 18, (40, 34, 20), 40, 10))
    img = Image.alpha_composite(img, stain_layer(s, 8, (30, 40, 25), 25, 6))  # mofo
    arr = np.array(img.convert("RGB")).astype(float)
    # Sujeira escorrendo de cima pra baixo.
    for _ in range(14):
        x = rng.integers(0, s)
        w = rng.integers(1, 4)
        length = rng.integers(40, 200)
        arr[:length, x : x + w] *= 0.8
    arr += rng.normal(0, 6, arr.shape)
    save_tex("wallpaper_dirty.png", Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)))


def wood_floor():
    s = 256
    arr = np.zeros((s, s, 3))
    plank_w = 32
    for i in range(s // plank_w):
        tone = rng.uniform(0.75, 1.1)
        color = np.array([78, 52, 32]) * tone
        x0 = i * plank_w
        yy = np.arange(s)[:, None]
        grain = np.sin(yy * rng.uniform(0.15, 0.3) + np.arange(plank_w)[None, :] * 0.4 + rng.uniform(0, 6)) * 8
        arr[:, x0 : x0 + plank_w] = color + grain[:, :, None]
        arr[:, x0] *= 0.45
        cut = rng.integers(0, s)
        arr[cut : cut + 2, x0 : x0 + plank_w] *= 0.5
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA")
    img = Image.alpha_composite(img, stain_layer(s, 10, (20, 12, 6), 35, 8))
    arr = np.array(img.convert("RGB")).astype(float) + rng.normal(0, 5, (s, s, 3))
    save_tex("wood_floor.png", Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)))


def ceiling():
    s = 256
    arr = np.full((s, s, 3), 118.0)
    arr += rng.normal(0, 8, arr.shape)
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1)).convert("RGBA")
    img = Image.alpha_composite(img, stain_layer(s, 6, (80, 60, 30), 60, 14))  # infiltração
    d = ImageDraw.Draw(img)
    for _ in range(5):  # rachaduras
        x, y = rng.integers(0, s, 2)
        pts = [(int(x), int(y))]
        for _ in range(8):
            x += rng.integers(-12, 13)
            y += rng.integers(-12, 13)
            pts.append((int(x), int(y)))
        d.line(pts, fill=(60, 58, 54, 255), width=1)
    save_tex("ceiling_stained.png", img)


def door_wood():
    s = 128
    arr = np.zeros((s, s, 3))
    yy = np.arange(s)[:, None]
    xx = np.arange(s)[None, :]
    grain = np.sin(xx * 0.25 + np.sin(yy * 0.05) * 3) * 10
    arr[:] = (64, 40, 26)
    arr += grain[:, :, None]
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    for box in ([14, 10, 114, 56], [14, 70, 114, 118]):
        d.rectangle(box, outline=(36, 22, 14), width=3)
    arr = np.array(img).astype(float) + rng.normal(0, 5, (s, s, 3))
    save_tex("door_wood.png", Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)), size=128)


def concrete():
    s = 256
    arr = np.full((s, s, 3), 85.0)
    arr += np.array(Image.fromarray(rng.integers(0, 255, (s // 8, s // 8)).astype(np.uint8)).resize((s, s), Image.BILINEAR))[:, :, None] * 0.12
    arr += rng.normal(0, 7, arr.shape)
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA")
    img = Image.alpha_composite(img, stain_layer(s, 12, (30, 28, 24), 50, 12))
    save_tex("concrete.png", img)


if __name__ == "__main__":
    footsteps()
    flashlight_click()
    breathing()
    heartbeat()
    ambient_drone()
    light_buzz()
    bulb_pop()
    door_creak()
    door_slam()
    door_locked()
    pickup()
    knocks()
    whisper()
    stinger()
    low_rumble()
    wallpaper()
    wood_floor()
    ceiling()
    door_wood()
    concrete()
    print("Assets gerados em", SFX, "e", TEX)
