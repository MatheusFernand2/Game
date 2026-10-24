"""
Gera os sons e texturas provisórios da floresta (Ato 1 em diante).

Uso:  python tools/gen_forest_assets.py
Requer: numpy, scipy, pillow (e tools/gen_assets.py ao lado)

Tudo é sintetizado. Dá pra trocar por gravações reais mantendo o nome do arquivo.
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_assets as ga  # noqa: E402
from gen_assets import SR, bandpass, env_exp, highpass, lowpass, reverb, t_axis, write_wav  # noqa: E402

rng = np.random.default_rng(2024)
TEX = ga.TEX


def noise(seconds: float) -> np.ndarray:
    return rng.uniform(-1, 1, int(seconds * SR))


def place(buf: np.ndarray, snd: np.ndarray, start_s: float, gain: float = 1.0) -> None:
    s = int(start_s * SR)
    e = min(len(buf), s + len(snd))
    if e > s:
        buf[s:e] += snd[: e - s] * gain


# ================================================================ CACHORRO

def bark(pitch: float, dur: float = 0.16) -> np.ndarray:
    t = t_axis(dur)
    n = len(t)
    f = pitch * (1.25 - 0.45 * (t / dur))  # cai de tom
    phase = 2 * np.pi * np.cumsum(f) / SR
    voice = np.zeros(n)
    for h in range(1, 9):
        voice += np.sin(h * phase) / h ** 0.9
    voice += bandpass(noise(dur), 300, 3000) * 0.9  # rouquidão
    # formantes de boca de cachorro
    y = bandpass(voice, 450, 900) * 1.2 + bandpass(voice, 1100, 2200) * 0.8
    env = np.clip(t / 0.008, 0, 1) * np.exp(-t * 14)
    return y * env


def dog_barks():
    variants = [
        [(0.0, 420), (0.24, 400)],
        [(0.0, 460)],
        [(0.0, 380), (0.2, 400), (0.42, 370)],
    ]
    for i, seq in enumerate(variants):
        out = np.zeros(int(1.0 * SR))
        for start, p in seq:
            place(out, bark(p * rng.uniform(0.95, 1.05)), start)
        write_wav(f"dog_bark_{i + 1}.wav", reverb(out, 1.4, 3.0, 0.35, 3000))


def dog_whine():
    dur = 2.4
    t = t_axis(dur)
    f = 820 - 120 * (t / dur) + 30 * np.sin(2 * np.pi * 5.5 * t)
    phase = 2 * np.pi * np.cumsum(f) / SR
    y = np.sin(phase) + 0.3 * np.sin(2 * phase) + 0.1 * np.sin(3 * phase)
    y = bandpass(y, 600, 2600)
    env = np.clip(np.sin(np.pi * t / dur), 0, 1) ** 0.6
    env *= 0.75 + 0.25 * np.sin(2 * np.pi * 1.7 * t)  # choro "quebrado"
    write_wav("dog_whine.wav", reverb(y * env, 1.0, 4.0, 0.25), normalize=0.7)


# ================================================================ MATA À NOITE

def forest_night_loop():
    dur = 30.0
    t = t_axis(dur)
    n = len(t)
    y = np.zeros(n)

    # Vento nas árvores (cross-fade circular pra fechar o loop).
    wind = lowpass(noise(dur + 3), 500) * 3
    fade = int(3 * SR)
    w = wind[fade: fade + n].copy()
    w[:fade] = w[:fade] * np.linspace(0, 1, fade) + wind[n: n + fade] * np.linspace(1, 0, fade)
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * t / 15.0) * np.sin(2 * np.pi * t / 10.0)
    y += w * gust
    leaves = bandpass(noise(dur), 2000, 6000) * 0.25 * np.clip(gust - 0.4, 0, 1)
    y += leaves

    # Grilos: cada grilo tem um ritmo que divide 30 s (loop perfeito).
    for k, (freq, rate, amp) in enumerate([(4300, 2.0, 0.08), (4700, 2.5, 0.05), (3900, 1.5, 0.06), (5100, 3.0, 0.03)]):
        gate = (np.sin(2 * np.pi * rate * t + k) > 0.6).astype(float)
        trill = (np.sin(2 * np.pi * 30 * t) > 0).astype(float)
        y += np.sin(2 * np.pi * freq * t) * gate * trill * amp

    # Sapos ao longe (eventos dentro do loop, sem cruzar a emenda).
    for start in np.arange(1.5, dur - 2, 3.7):
        croak_t = t_axis(0.35)
        c = np.sin(2 * np.pi * 180 * croak_t) * (np.sin(2 * np.pi * 22 * croak_t) > 0)
        c = lowpass(c * np.hanning(len(c)), 900) * rng.uniform(0.04, 0.09)
        place(y, c, start + rng.uniform(-0.6, 0.6))
    write_wav("forest_night_loop.wav", y, loop=True, normalize=0.75)


def bush_rustle():
    dur = 0.9
    n = int(dur * SR)
    y = np.zeros(n)
    for _ in range(14):
        s = rng.uniform(0, dur - 0.1)
        g = int(0.06 * SR)
        burst = bandpass(noise(0.06), 1200, 6000) * env_exp(g, 50) * rng.uniform(0.3, 1.0)
        place(y, burst, s)
    y += lowpass(noise(dur), 400) * 0.3 * np.hanning(n)
    write_wav("bush_rustle.wav", y, normalize=0.7)


def branch_crack():
    dur = 0.7
    n = int(dur * SR)
    y = highpass(noise(dur), 800) * env_exp(n, 60) * 1.5
    for _ in range(6):
        place(y, bandpass(noise(0.03), 1500, 5000) * env_exp(int(0.03 * SR), 90), rng.uniform(0.02, 0.25), 0.6)
    write_wav("branch_crack.wav", reverb(y, 1.2, 3.5, 0.35))


def footsteps_dirt():
    for i in range(4):
        dur = 0.35
        n = int(dur * SR)
        t = t_axis(dur)
        thud = np.sin(2 * np.pi * rng.uniform(60, 90) * t) * env_exp(n, 35) * 0.7
        crunch = np.zeros(n)
        for _ in range(8):  # folhas secas
            place(crunch, bandpass(noise(0.03), 1500, 6000) * env_exp(int(0.03 * SR), 80), rng.uniform(0.0, 0.12), rng.uniform(0.3, 0.8))
        soil = bandpass(noise(dur), 200, 1200) * env_exp(n, 22) * 0.4
        write_wav(f"footstep_dirt_{i + 1}.wav", thud + crunch + soil, normalize=0.8)


# ================================================================ COISA FUNDA

def coisa_steps():
    for i in range(3):
        dur = 0.6
        n = int(dur * SR)
        t = t_axis(dur)
        boom = np.sin(2 * np.pi * rng.uniform(32, 45) * t) * env_exp(n, 10) * 1.6
        crush = bandpass(noise(dur), 300, 2500) * env_exp(n, 20) * 0.7
        twigs = np.zeros(n)
        for _ in range(5):
            place(twigs, bandpass(noise(0.025), 2000, 6000) * env_exp(int(0.025 * SR), 100), rng.uniform(0, 0.15), 0.4)
        write_wav(f"coisa_step_{i + 1}.wav", reverb(boom + crush + twigs, 1.0, 4, 0.3, 1800))


def coisa_breath_loop():
    dur = 6.0
    t = t_axis(dur)
    # Respiração lenta e molhada, frequências múltiplas de 1/6 Hz pra fechar o loop.
    cycle = np.sin(2 * np.pi * t / 3.0)
    inhale = np.clip(cycle, 0, 1) ** 1.5
    exhale = np.clip(-cycle, 0, 1) ** 1.2
    x = noise(dur)
    y = bandpass(x, 150, 700) * exhale * 1.3 + bandpass(x, 500, 1800) * inhale * 0.6
    growl = np.sin(2 * np.pi * 55 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t)) * exhale * 0.5
    gurgle = bandpass(noise(dur), 80, 250) * (np.sin(2 * np.pi * 13 * t) > 0.3) * exhale * 0.5
    write_wav("coisa_breath_loop.wav", lowpass(y + growl + gurgle, 2200), loop=True, normalize=0.8)


def coisa_hiss():
    dur = 1.8
    n = int(dur * SR)
    t = t_axis(dur)
    hiss = highpass(noise(dur), 2500) * np.clip(t / 0.05, 0, 1) * np.exp(-t * 1.4)
    rattle = bandpass(noise(dur), 300, 1200) * (np.sin(2 * np.pi * 28 * t) > 0) * np.exp(-t * 2) * 0.8
    low = np.sin(2 * np.pi * 70 * t * (1 - 0.2 * t / dur)) * np.exp(-t * 1.5) * 0.7
    write_wav("coisa_hiss.wav", reverb(hiss + rattle + low, 1.4, 3, 0.3), normalize=0.9)


# ================================================================ CORUJA, QUEDA, TROMBADA

def owl():
    dur = 1.2
    t = t_axis(dur)
    # Suindara: grito rouco e áspero.
    rough = (np.sin(2 * np.pi * 45 * t) > -0.2).astype(float)
    y = bandpass(noise(dur), 2200, 6500) * rough
    y += bandpass(noise(dur), 1200, 2200) * 0.4
    env = np.clip(t / 0.03, 0, 1) * np.exp(-t * 1.8)
    write_wav("owl_screech.wav", reverb(y * env, 1.6, 2.5, 0.35), normalize=0.9)

    out = np.zeros(int(0.9 * SR))
    for k in range(9):
        fl = lowpass(noise(0.07), 700) * env_exp(int(0.07 * SR), 40)
        place(out, fl, k * 0.085, 1.0 - k * 0.05)
    write_wav("wing_flaps.wav", out, normalize=0.8)


def body_fall():
    dur = 2.5
    n = int(dur * SR)
    y = np.zeros(n)
    # galhos e folhas no caminho
    for _ in range(10):
        place(y, bandpass(noise(0.05), 1500, 6000) * env_exp(int(0.05 * SR), 60), rng.uniform(0, 0.5), 0.5)
    # impacto
    tt = t_axis(1.2)
    imp = np.sin(2 * np.pi * 50 * tt * (1 - 0.3 * tt)) * np.exp(-tt * 6) * 2.0
    imp += lowpass(rng.uniform(-1, 1, len(tt)), 600) * np.exp(-tt * 12) * 1.5
    crack = highpass(rng.uniform(-1, 1, int(0.08 * SR)), 1500) * env_exp(int(0.08 * SR), 60)
    place(y, imp, 0.55)
    place(y, crack, 0.57, 1.4)
    # pedrinhas rolando
    for _ in range(12):
        place(y, bandpass(noise(0.02), 2000, 5000) * env_exp(int(0.02 * SR), 120), rng.uniform(0.7, 2.0), rng.uniform(0.1, 0.35))
    write_wav("body_fall.wav", y, normalize=0.95)


def impact_thud():
    dur = 0.8
    n = int(dur * SR)
    t = t_axis(dur)
    y = np.sin(2 * np.pi * 70 * t * (1 - 0.4 * t)) * np.exp(-t * 9) * 1.5
    y += lowpass(noise(dur), 900) * env_exp(n, 25)
    # ar saindo do peito
    grunt = bandpass(noise(0.35), 300, 1400) * np.hanning(int(0.35 * SR))
    place(y, grunt, 0.05, 0.6)
    write_wav("impact_thud.wav", y, normalize=0.95)


def tinnitus():
    dur = 4.0
    t = t_axis(dur)
    y = np.sin(2 * np.pi * 6200 * t) * np.exp(-t * 0.8) * np.clip(t / 0.2, 0, 1)
    write_wav("tinnitus.wav", y, normalize=0.25)


# ================================================================ TEXTURAS

def tileable_blobs(size, count, color, max_r, blur):
    return ga.stain_layer(size, count, color, max_r, blur)


def value_noise(size, cells, seed_scale=1.0):
    small = rng.random((cells, cells))
    small = np.tile(small, (3, 3))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((size * 3, size * 3), Image.BICUBIC)
    arr = np.array(img).astype(float)[size: 2 * size, size: 2 * size] / 255.0
    return arr * seed_scale


def forest_floor():
    s = 256
    n1 = value_noise(s, 8)
    n2 = value_noise(s, 32)
    base = np.array([42, 34, 24], float)
    arr = base[None, None, :] * (0.7 + 0.5 * n1[:, :, None]) + (n2[:, :, None] - 0.5) * 18
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(img)
    for _ in range(260):  # folhas secas
        x, y = rng.integers(0, s, 2)
        r = rng.integers(2, 5)
        c = tuple(int(v) for v in rng.choice([[70, 52, 28], [58, 40, 22], [80, 66, 34], [36, 42, 24]])) + (255,)
        ang = rng.uniform(0, np.pi)
        dx, dy = abs(np.cos(ang)) * r, abs(np.sin(ang)) * r * 0.5
        for ox in (-s, 0, s):
            for oy in (-s, 0, s):
                d.ellipse([x - dx - 1 + ox, y - dy - 1 + oy, x + dx + 1 + ox, y + dy + 1 + oy], fill=c)
    for _ in range(25):  # gravetos
        x, y = rng.integers(0, s, 2)
        L = rng.integers(6, 16)
        a = rng.uniform(0, np.pi)
        d.line([x, y, x + np.cos(a) * L, y + np.sin(a) * L], fill=(30, 22, 14, 255), width=1)
    arr = np.array(img.convert("RGB")).astype(float) + rng.normal(0, 4, (s, s, 3))
    ga.save_tex("forest_floor.png", Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)))


def dirt_path():
    s = 256
    n1 = value_noise(s, 6)
    n2 = value_noise(s, 40)
    base = np.array([74, 60, 44], float)
    arr = base[None, None, :] * (0.8 + 0.35 * n1[:, :, None]) + (n2[:, :, None] - 0.5) * 20
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA")
    img = Image.alpha_composite(img, tileable_blobs(s, 10, (40, 32, 22), 30, 8))
    d = ImageDraw.Draw(img)
    for _ in range(120):  # pedrinhas
        x, y = rng.integers(0, s, 2)
        g = int(rng.integers(80, 120))
        d.point((int(x), int(y)), fill=(g, g - 6, g - 14, 255))
    arr = np.array(img.convert("RGB")).astype(float) + rng.normal(0, 4, (s, s, 3))
    ga.save_tex("dirt_path.png", Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)))


def bark_texture():
    s = 128
    xx = np.arange(s)[None, :]
    yy = np.arange(s)[:, None]
    ridges = np.sin(xx * 0.9 + np.sin(yy * 0.08) * 2.5) * 0.5 + 0.5
    cracks = value_noise(s, 16)
    v = 0.55 + 0.35 * ridges * (0.6 + 0.4 * cracks)
    arr = np.array([52, 42, 34], float)[None, None, :] * v[:, :, None]
    arr += rng.normal(0, 4, (s, s, 3))
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA")
    img = Image.alpha_composite(img, tileable_blobs(s, 6, (40, 52, 30), 14, 4))  # musgo
    ga.save_tex("bark.png", img.transpose(Image.TRANSPOSE), size=128)


def foliage():
    s = 128
    n = value_noise(s, 24)
    arr = np.array([24, 38, 26], float)[None, None, :] * (0.6 + 0.6 * n[:, :, None])
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    for _ in range(500):  # agulhas
        x, y = rng.integers(0, s, 2)
        L = rng.integers(3, 7)
        g = int(rng.integers(30, 60))
        d.line([x, y, x + rng.integers(-2, 3), y + L], fill=(g // 2, g, g // 2), width=1)
    ga.save_tex("foliage.png", img, size=128)


def alpha_sprite(name, size, draw_fn):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(img), size)
    img = img.resize((size, size), Image.NEAREST)
    os.makedirs(TEX, exist_ok=True)
    img.save(os.path.join(TEX, name))


def grass_sprite():
    def draw(d, s):
        for _ in range(70):
            x0 = rng.uniform(4, s - 4)
            h = rng.uniform(s * 0.35, s * 0.98)
            lean = rng.uniform(-10, 10)
            g = int(rng.integers(36, 70))
            col = (int(g * 0.7), g, int(g * 0.45), 255)
            d.line([x0, s - 1, x0 + lean, s - h], fill=col, width=int(rng.integers(1, 3)))
    alpha_sprite("grass_tuft.png", 64, draw)


def bush_sprite():
    def draw(d, s):
        for _ in range(140):
            cx = rng.normal(s / 2, s * 0.18)
            cy = rng.normal(s * 0.58, s * 0.17)
            r = rng.uniform(2, 6)
            g = int(rng.integers(26, 56))
            d.ellipse([cx - r, cy - r * 0.6, cx + r, cy + r * 0.6], fill=(int(g * 0.6), g, int(g * 0.5), 255))
        for _ in range(8):  # galhos
            x0 = s / 2 + rng.uniform(-6, 6)
            d.line([x0, s - 1, x0 + rng.uniform(-24, 24), s * rng.uniform(0.3, 0.6)], fill=(34, 26, 18, 255), width=1)
    alpha_sprite("bush.png", 96, draw)


def blood_decal():
    s = 64
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(9):
        cx, cy = rng.normal(s / 2, 8, 2)
        r = rng.uniform(2, 9)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(60, 6, 6, 230))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(TEX, "blood_decal.png"))


if __name__ == "__main__":
    dog_barks()
    dog_whine()
    forest_night_loop()
    bush_rustle()
    branch_crack()
    footsteps_dirt()
    coisa_steps()
    coisa_breath_loop()
    coisa_hiss()
    owl()
    body_fall()
    impact_thud()
    tinnitus()
    forest_floor()
    dirt_path()
    bark_texture()
    foliage()
    grass_sprite()
    bush_sprite()
    blood_decal()
    print("Assets da floresta gerados.")
