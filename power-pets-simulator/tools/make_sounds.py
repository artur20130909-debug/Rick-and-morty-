#!/usr/bin/env python3
"""
make_sounds.py — синтезирует все звуки и музыку игры в assets/sounds/*.ogg.

Никаких чужих сэмплов: каждый звук собирается из синусоид и шума, физических моделей
(удар по бруску, струна Карплуса — Стронга, FM-колокольчик), проходит через реверберацию
и кодируется ffmpeg в OGG Vorbis. Roblox принимает .ogg и .mp3; .ogg зацикливается без паузы,
поэтому музыка собрана как бесшовная петля (хвосты нот и эха с конца перенесены в начало).

Запуск из папки игры:   python3 tools/make_sounds.py
Нужны: Python 3, numpy, ffmpeg.  Результат детерминирован: повторный запуск даёт те же файлы.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "assets", "sounds"))
RNG = np.random.default_rng(20261015)


# ===================================================================== базовые кирпичики

def n_of(seconds):
    return max(1, int(round(seconds * SR)))


def times(n):
    return np.arange(n) / SR


NOTE_INDEX = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(note):
    """'C#4' / 'Bb3' / число -> MIDI-номер."""
    if not isinstance(note, str):
        return note
    letter, rest, shift = note[0], note[1:], 0
    while rest and rest[0] in "#b":
        shift += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + NOTE_INDEX[letter] + shift


def hz(note):
    return 440.0 * 2 ** ((midi(note) - 69) / 12)


def phase(freq, n):
    freq = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    return 2 * np.pi * np.cumsum(freq) / SR


def smooth_attack(n, seconds):
    env = np.ones(n)
    k = min(n, max(1, n_of(seconds)))
    env[:k] = np.sin(np.linspace(0, np.pi / 2, k)) ** 2
    return env


def fade_out(x, seconds):
    k = min(len(x), n_of(seconds))
    x = x.copy()
    x[-k:] *= np.cos(np.linspace(0, np.pi / 2, k)) ** 2
    return x


def adsr(n, hold, a=0.01, d=0.2, s=0.7, r=0.2):
    """Огибающая: атака a, спад d до уровня s, нота держится hold секунд, затем затухание r."""
    t = times(n)
    attack = np.sin(np.clip(t / max(a, 1e-4), 0, 1) * np.pi / 2) ** 2
    decay = s + (1 - s) * np.exp(-np.maximum(t - a, 0) / max(d, 1e-4))
    release = np.clip(1 - (t - hold) / max(r, 1e-4), 0, 1) ** 2
    return attack * decay * release


def spectral(x, lo=None, hi=None, order=2):
    """Полосовой фильтр в частотной области (циклический — для петель это ровно то, что нужно)."""
    n = x.shape[-1]
    f = np.fft.rfftfreq(n, 1 / SR)
    h = np.ones_like(f)
    if hi:
        h /= np.sqrt(1 + (f / hi) ** (2 * order))
    if lo:
        h /= np.sqrt(1 + (lo / np.maximum(f, 1e-6)) ** (2 * order))
    return np.fft.irfft(np.fft.rfft(x, axis=-1) * h, n, axis=-1)


def noise(n, lo=None, hi=None, order=2, rng=None):
    """Шум в полосе lo..hi Гц со среднеквадратичным уровнем 1."""
    rng = rng or RNG
    x = rng.standard_normal(n)
    if lo or hi:
        x = spectral(x, lo, hi, order)
    return x / (np.std(x) + 1e-12)


def modal(freq, n, modes, attack=0.001, rng=None):
    """Удар по бруску / колокольчику: сумма затухающих синусоид. modes = [(кратность, громкость, затухание, с)]."""
    rng = rng or RNG
    t = times(n)
    out = np.zeros(n)
    for ratio, amp, decay in modes:
        f = freq * ratio
        if f >= SR * 0.45:
            continue
        out += amp * np.sin(2 * np.pi * f * t + rng.uniform(0, 0.3)) * np.exp(-t / decay)
    return out * smooth_attack(n, attack)


def formant_weight(f, formants):
    return 0.08 + sum(g * np.exp(-0.5 * ((f - c) / bw) ** 2) for c, bw, g in formants)


def additive(freq, n, kind="saw", cutoff=3000.0, max_h=48, formants=None, phase0=0.0):
    """Пила / меандр / треугольник без алиасинга + мягкий фильтр cutoff (число или массив — «фильтр-огибающая»)."""
    ph = phase(freq, n) + phase0
    f0 = float(np.max(freq))
    cutoff = np.asarray(cutoff, dtype=float)
    out = np.zeros(n)
    for k in range(1, max_h + 1):
        fk = k * f0
        if fk >= SR * 0.45:
            break
        if kind in ("square", "triangle") and k % 2 == 0:
            continue
        amp = (-1) ** ((k - 1) // 2) / k ** 2 if kind == "triangle" else 1 / k
        gain = amp / (1 + (fk / cutoff) ** 2)
        if formants:
            gain = gain * formant_weight(fk, formants)
        if np.max(np.abs(gain)) < 2e-4:
            continue
        out += gain * np.sin(k * ph)
    return out


def fm_bell(freq, n, ratio=1.4, index=2.5, index_decay=0.2, decay=0.8):
    t = times(n)
    mod = index * np.exp(-t / index_decay) * np.sin(2 * np.pi * freq * ratio * t)
    x = np.sin(2 * np.pi * freq * t + mod) * np.exp(-t / decay) * smooth_attack(n, 0.002)
    return fade_out(x, min(0.15, n / SR * 0.25))


def pluck(freq, n, t60=1.5, brightness=2, seed=0):
    """Струна Карплуса — Стронга, точно подстроенная по высоте пересэмплированием."""
    rng = np.random.default_rng(seed)
    period = max(4, int(SR / freq - 0.5))
    real_freq = SR / (period + 0.5)
    step = freq / real_freq
    total = int(n * step) + period + 2
    loss = 0.001 ** (1 / (real_freq * t60))
    y = np.zeros(total)
    burst = rng.uniform(-1, 1, period)
    for _ in range(brightness):
        burst = np.convolve(burst, [0.25, 0.5, 0.25], mode="same")
    y[:period] = burst - burst.mean()
    y[period] = loss * 0.5 * y[0]
    i = period + 1
    while i < total:
        j = min(i + period, total)
        y[i:j] = loss * 0.5 * (y[i - period:j - period] + y[i - period - 1:j - period - 1])
        i = j
    out = np.interp(np.arange(n) * step, np.arange(total), y)
    out *= smooth_attack(n, 0.001)
    return out / (np.max(np.abs(out)) + 1e-12)


def swept_noise(n, centers, width=0.5, count=500, seed=0):
    """Шум, полоса которого плавно движется (centers — центр полосы в Гц для каждого сэмпла)."""
    rng = np.random.default_rng(seed)
    t = times(n)
    log_c = np.log2(np.maximum(centers, 20))
    out = np.zeros(n)
    for f in 2 ** rng.uniform(np.log2(60), np.log2(16000), count):
        weight = np.exp(-0.5 * ((np.log2(f) - log_c) / width) ** 2)
        out += weight * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
    return out / (np.std(out) + 1e-12)


def convolve(x, h):
    size = 1 << (len(x) + len(h) - 2).bit_length()
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(h, size), size)[: len(x) + len(h) - 1]


def reverb_ir(rt60=1.8, damping=0.45, predelay=0.012, seed=1):
    """Импульс «комнаты»: затухающий шум, верх гаснет быстрее низа, плюс ранние отражения. Стерео."""
    rng = np.random.default_rng(seed)
    n = n_of(rt60 * 1.2)
    t = times(n)
    channels = []
    for _ in range(2):
        low = noise(n, hi=2500, rng=rng)
        high = noise(n, lo=2500, rng=rng)
        ir = low * np.exp(-6.9 * t / rt60) + 0.6 * high * np.exp(-6.9 * t / (rt60 * damping))
        ir *= smooth_attack(n, 0.01)
        for _k in range(8):
            ir[rng.integers(n_of(0.004), n_of(0.06))] += rng.uniform(-3, 3)
        ir = np.concatenate([np.zeros(n_of(predelay)), ir])
        channels.append(ir / np.sqrt(np.sum(ir ** 2)))
    return channels


def add(buf, sig, t0, gain=1.0):
    start = n_of(t0) if t0 > 0 else 0
    end = min(len(buf), start + len(sig))
    if end > start:
        buf[start:end] += sig[: end - start] * gain


def place(buf, sig, t0, gain=1.0, pan=0.0):
    """Моно-сигнал в стерео-буфер (2, N); pan от -1 (лево) до 1 (право), равная мощность."""
    start = n_of(t0) if t0 > 0 else 0
    end = min(buf.shape[1], start + len(sig))
    if end <= start:
        return
    seg = sig[: end - start] * gain
    angle = (pan + 1) * np.pi / 4
    buf[0, start:end] += seg * np.cos(angle)
    buf[1, start:end] += seg * np.sin(angle)


_CACHE = {}


def cached(fn):
    """Одинаковые ноты синтезируем один раз (аккорды в музыке повторяются)."""
    def wrapper(*args, **kwargs):
        key = (fn.__name__, args, tuple(sorted(kwargs.items())))
        if key not in _CACHE:
            _CACHE[key] = fn(*args, **kwargs)
        return _CACHE[key]
    return wrapper


# ===================================================================== инструменты

GLOCK = [(1, 1, 0.9), (2.76, 0.32, 0.32), (5.40, 0.16, 0.14), (8.93, 0.07, 0.06)]
VOWEL_AH = [(800, 130, 1.0), (1150, 150, 0.6), (2900, 260, 0.25)]


@cached
def glock(freq, length=1.4, scale=1.0):
    modes = [(r, a, d * scale) for r, a, d in GLOCK]
    return fade_out(modal(freq, n_of(length), modes, attack=0.0008), 0.05)


@cached
def marimba(freq, length=0.8):
    n = n_of(length)
    t = times(n)
    decay = 0.42 * (440 / freq) ** 0.35
    x = modal(freq, n, [(1, 1, decay), (4.0, 0.3, decay * 0.22), (9.9, 0.07, decay * 0.08)], attack=0.0015)
    x += noise(n, lo=700, hi=4000, rng=np.random.default_rng(1)) * np.exp(-t / 0.003) * 0.12
    return fade_out(x, 0.04)


@cached
def bass_pluck(freq, hold):
    n = n_of(hold + 0.1)
    t = times(n)
    cutoff = 260 + 1500 * np.exp(-t / 0.05)
    x = 0.55 * additive(freq, n, "saw", cutoff=cutoff, max_h=30) + 0.65 * np.sin(phase(freq, n))
    return x * adsr(n, hold, a=0.004, d=0.22, s=0.45, r=0.08)


@cached
def pad(freq, hold, cutoff=1200.0, attack=0.4, release=0.8, detune=8.0):
    n = n_of(hold + release)
    x = np.zeros(n)
    for i, cents in enumerate((-detune, 0.0, detune)):
        x += additive(freq * 2 ** (cents / 1200), n, "saw", cutoff=cutoff, max_h=40, phase0=1.3 * i)
    return x / 3 * adsr(n, hold, a=attack, d=1.0, s=0.85, r=release)


@cached
def flute(freq, hold, seed=0):
    """Флейта-ней: тон с вибрато и дыханием."""
    n = n_of(hold + 0.16)
    t = times(n)
    vibrato = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.12) / 0.25, 0, 1)
    scoop = 1 - 0.012 * np.exp(-t / 0.04)
    ph = phase(freq * vibrato * scoop, n)
    x = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph) + 0.03 * np.sin(4 * ph)
    breath = noise(n, lo=freq * 1.2, hi=freq * 5, rng=np.random.default_rng(seed)) * 0.08
    return (x + breath) * adsr(n, hold, a=0.07, d=0.35, s=0.8, r=0.13)


@cached
def oud(freq, length=0.9, seed=0):
    return fade_out(pluck(freq, n_of(length), t60=0.9, brightness=1, seed=seed), 0.05)


@cached
def e_piano(freq, length=1.0):
    n = n_of(length)
    x = 0.65 * fm_bell(freq, n, ratio=2.0, index=1.3, index_decay=0.12, decay=0.55)
    x += 0.35 * np.sin(phase(freq, n)) * np.exp(-times(n) / 0.8) * smooth_attack(n, 0.002)
    return fade_out(x, 0.05)


@cached
def lead(freq, hold):
    n = n_of(hold + 0.4)
    t = times(n)
    vibrato = 1 + 0.005 * np.sin(2 * np.pi * 5 * t) * np.clip((t - 0.2) / 0.3, 0, 1)
    x = np.sin(phase(freq * vibrato, n)) + 0.3 * additive(freq * vibrato, n, "triangle", cutoff=freq * 6, max_h=9)
    return x * adsr(n, hold, a=0.06, d=0.4, s=0.75, r=0.35)


@cached
def brass(freq, hold, bright=2600.0):
    n = n_of(hold + 0.2)
    t = times(n)
    cutoff = 350 + bright * (1 - np.exp(-t / 0.045)) * (0.75 + 0.25 * np.exp(-t / 0.3))
    vibrato = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.18) / 0.2, 0, 1)
    scoop = 1 - 0.025 * np.exp(-t / 0.03)
    x = additive(freq * vibrato * scoop, n, "saw", cutoff=cutoff, max_h=40)
    return x * adsr(n, hold, a=0.025, d=0.3, s=0.8, r=0.12)


@cached
def choir(freq, hold):
    n = n_of(hold + 0.8)
    t = times(n)
    x = np.zeros(n)
    for i, cents in enumerate((-9, 0, 8)):
        vibrato = 1 + 0.005 * np.sin(2 * np.pi * (4.8 + 0.3 * i) * t + 1.7 * i)
        x += additive(freq * 2 ** (cents / 1200) * vibrato, n, "saw", cutoff=5000, max_h=60,
                      formants=VOWEL_AH, phase0=1.1 * i)
    return x / 3 * adsr(n, hold, a=0.18, d=0.6, s=0.85, r=0.7)


# --- ударные

@cached
def kick(gain_click=0.3):
    n = n_of(0.4)
    t = times(n)
    f = 48 + 105 * np.exp(-t / 0.035)
    x = np.sin(phase(f, n)) * np.exp(-t / 0.16) * smooth_attack(n, 0.001)
    x += noise(n, lo=1000, hi=6000, rng=np.random.default_rng(2)) * np.exp(-t / 0.004) * gain_click
    return fade_out(x, 0.03)


@cached
def clap():
    n = n_of(0.3)
    t = times(n)
    burst = noise(n, lo=900, hi=4000, rng=np.random.default_rng(3))
    env = np.zeros(n)
    for k, delay in enumerate((0.0, 0.011, 0.022)):
        tt = np.maximum(t - delay, 0)
        env += (t >= delay) * np.exp(-tt / (0.008 if k < 2 else 0.07))
    return fade_out(burst * env * smooth_attack(n, 0.001) * 0.6, 0.03)


@cached
def shaker():
    n = n_of(0.09)
    t = times(n)
    env = smooth_attack(n, 0.012) * np.exp(-np.maximum(t - 0.012, 0) / 0.025)
    return fade_out(noise(n, lo=4500, hi=12000, rng=np.random.default_rng(4)) * env * 0.5, 0.02)


@cached
def hat():
    n = n_of(0.06)
    t = times(n)
    return fade_out(noise(n, lo=7000, hi=16000, rng=np.random.default_rng(5)) * np.exp(-t / 0.018) * 0.5, 0.01)


@cached
def woodblock():
    n = n_of(0.12)
    return fade_out(modal(980, n, [(1, 1, 0.03), (2.6, 0.4, 0.012)], attack=0.0005), 0.02)


@cached
def doum():
    n = n_of(0.45)
    t = times(n)
    x = np.sin(phase(80 + 45 * np.exp(-t / 0.03), n)) * np.exp(-t / 0.22) * smooth_attack(n, 0.001)
    x += noise(n, hi=700, rng=np.random.default_rng(6)) * np.exp(-t / 0.02) * 0.25
    return fade_out(x, 0.03)


@cached
def tek(pitch=1.0):
    n = n_of(0.12)
    t = times(n)
    x = 0.45 * modal(720 * pitch, n, [(1, 1, 0.035), (1.92, 0.6, 0.025), (3.1, 0.4, 0.015)], attack=0.0004)
    x += noise(n, lo=1500, hi=8000, rng=np.random.default_rng(7)) * np.exp(-t / 0.01) * 0.5
    return fade_out(x, 0.02)


@cached
def jingle(seed=0):
    rng = np.random.default_rng(100 + seed)
    n = n_of(0.16)
    x = np.zeros(n)
    for _ in range(7):
        part = modal(rng.uniform(5200, 9800), n, [(1, 1, 0.05), (1.5, 0.4, 0.03)], attack=0.0005, rng=rng)
        add(x, part * rng.uniform(0.3, 1), rng.uniform(0, 0.012))
    return fade_out(x * 0.35, 0.03)


@cached
def tink(freq, length=0.3):
    modes = [(1, 1, 0.07), (1.58, 0.55, 0.05), (2.69, 0.35, 0.03), (4.1, 0.15, 0.02)]
    return fade_out(modal(freq, n_of(length), modes, attack=0.0005), 0.02)


@cached
def chirp(seed=0):
    """Птичка: два-три быстрых свиста сверху вниз."""
    rng = np.random.default_rng(200 + seed)
    out = np.zeros(n_of(0.5))
    start = 0.0
    for _ in range(rng.integers(2, 4)):
        d = rng.uniform(0.05, 0.08)
        n = n_of(d)
        t = times(n)
        top = rng.uniform(3600, 4800)
        f = top - (top - 2400) * (t / d) ** 0.7
        add(out, np.sin(phase(f, n)) * np.sin(np.pi * t / d) ** 2, start)
        start += d + rng.uniform(0.02, 0.05)
    return out


# ===================================================================== звуковые эффекты

def finish_sfx(dry, wet=0.0, rt60=1.0, peak_db=-1.0):
    """Моно/стерео -> стерео с реверберацией, обрезка тишины в конце, пик peak_db."""
    if dry.ndim == 1:
        dry = np.array([dry, dry])
    if wet > 0:
        ir = reverb_ir(rt60=rt60, seed=9)
        mid = dry.mean(axis=0)
        length = len(mid) + len(ir[0]) - 1
        out = np.zeros((2, length))
        out[:, : dry.shape[1]] += dry
        out[0] += wet * convolve(0.7 * dry[0] + 0.3 * dry[1], ir[0])
        out[1] += wet * convolve(0.3 * dry[0] + 0.7 * dry[1], ir[1])
    else:
        out = dry.copy()
    level = np.max(np.abs(out), axis=0)
    loud = np.nonzero(level > np.max(level) * 10 ** (-58 / 20))[0]
    end = min(out.shape[1], loud[-1] + n_of(0.02)) if len(loud) else out.shape[1]
    out = np.array([fade_out(ch[:end], min(0.08, end / SR / 4)) for ch in out])
    return out * (10 ** (peak_db / 20) / np.max(np.abs(out)))


def sfx_click():
    """Мягкий «чпок» — звучит до 15 раз в секунду, поэтому короткий и не резкий."""
    n = n_of(0.14)
    t = times(n)
    f = 300 + 560 * np.exp(-t / 0.016)
    ph = phase(f, n)
    body = (np.sin(ph) + 0.22 * np.sin(2 * ph)) * np.exp(-t / 0.04)
    tick = noise(n, lo=2500, hi=9000, rng=np.random.default_rng(10)) * np.exp(-t / 0.0025) * 0.35
    return finish_sfx(fade_out((body + tick) * smooth_attack(n, 0.0015), 0.02), wet=0.08, rt60=0.4)


def sfx_button():
    n = n_of(0.12)
    t = times(n)
    x = modal(1250, n, [(1, 1, 0.03), (2.45, 0.35, 0.012), (0.5, 0.45, 0.035)], attack=0.0008)
    x += noise(n, lo=3000, hi=10000, rng=np.random.default_rng(11)) * np.exp(-t / 0.002) * 0.25
    return finish_sfx(fade_out(x, 0.02), wet=0.06, rt60=0.35)


def coin_tone(freq, length, decay):
    n = n_of(length)
    x = 0.5 * additive(freq, n, "square", cutoff=freq * 3.5, max_h=15) + 0.6 * np.sin(phase(freq, n))
    return fade_out(x * np.exp(-times(n) / decay) * smooth_attack(n, 0.002), min(0.1, length * 0.25))


def sfx_coin():
    x = np.zeros(n_of(0.8))
    add(x, fade_out(coin_tone(hz("B5"), 0.085, 0.25), 0.012), 0)
    add(x, coin_tone(hz("E6"), 0.65, 0.16) + 0.18 * glock(hz("E7"), 0.65), 0.075)
    return finish_sfx(x, wet=0.18, rt60=0.9)


def sfx_sell():
    """Касса: механический щелчок, «дзынь» и сыплющиеся монетки."""
    x = np.zeros(n_of(1.5))
    n = n_of(0.08)
    t = times(n)
    clunk = 0.7 * modal(320, n, [(1, 1, 0.03), (2.1, 0.5, 0.015)], attack=0.0005)
    clunk += noise(n, lo=1500, hi=6000, rng=np.random.default_rng(12)) * np.exp(-t / 0.01) * 0.5
    add(x, clunk, 0)
    add(x, clunk, 0.045, 0.6)
    bell_n = n_of(1.2)
    bell = fm_bell(hz("C7"), bell_n, ratio=1.41, index=2.2, index_decay=0.12, decay=0.45)
    bell += 0.7 * fm_bell(hz("G7"), bell_n, ratio=1.41, index=1.6, index_decay=0.1, decay=0.35)
    add(x, bell, 0.09, 0.8)
    rng = np.random.default_rng(13)
    for i in range(9):
        add(x, tink(rng.uniform(3200, 5200)), 0.14 + i * 0.045 + rng.uniform(0, 0.02), 0.5 * 0.88 ** i)
    return finish_sfx(x, wet=0.2, rt60=1.0)


def knock(freq):
    n = n_of(0.15)
    t = times(n)
    x = modal(freq, n, [(1, 1, 0.035), (2.31, 0.5, 0.018), (3.9, 0.25, 0.01)], attack=0.0006)
    x += noise(n, lo=1200, hi=5000, rng=np.random.default_rng(int(freq))) * np.exp(-t / 0.004) * 0.3
    return fade_out(x, 0.02)


def sfx_egg_shake():
    """Яйцо качается на подставке: два деревянных «тук-тук» (игра проигрывает его на каждом качании)."""
    x = np.zeros(n_of(0.26))
    add(x, knock(560), 0)
    add(x, knock(620), 0.075, 0.75)
    return finish_sfx(x, wet=0.1, rt60=0.5)


def sfx_egg_crack():
    x = np.zeros(n_of(0.8))
    rng = np.random.default_rng(14)
    start = 0.0
    for _ in range(7):
        n = n_of(0.03)
        t = times(n)
        crack = noise(n, lo=1800, hi=11000, rng=rng) * np.exp(-t / 0.0035) * rng.uniform(0.4, 1.0)
        crack += 0.5 * modal(rng.uniform(1500, 2600), n, [(1, 1, 0.006), (1.7, 0.6, 0.004)], attack=0.0003, rng=rng)
        add(x, crack, start)
        start += rng.uniform(0.012, 0.035)
    n = n_of(0.3)
    t = times(n)
    pop = np.sin(phase(180 + 480 * np.exp(-t / 0.03), n)) * np.exp(-t / 0.07) * smooth_attack(n, 0.001)
    pop += noise(n, lo=400, hi=3500, rng=rng) * np.exp(-t / 0.04) * 0.35
    add(x, pop, start + 0.04, 0.9)
    return finish_sfx(x, wet=0.15, rt60=0.7)


def sparkle(length, gain, seed=0):
    n = n_of(length)
    t = times(n)
    flicker = 0.5 + 0.5 * np.sin(2 * np.pi * 17 * t) * np.sin(2 * np.pi * 5.3 * t + seed)
    return noise(n, lo=6000, hi=14000, rng=np.random.default_rng(300 + seed)) * flicker * \
        adsr(n, length * 0.3, a=0.15, d=0.4, s=0.5, r=length * 0.65) * gain


def sfx_reveal():
    """Питомец появился: волшебное восходящее арпеджио колокольчиков и искры."""
    x = np.zeros(n_of(2.3))
    for i, note in enumerate(["C6", "E6", "G6", "C7", "E7", "G7"]):
        add(x, glock(hz(note), 1.6), 0.05 * i, 0.7 - 0.06 * i)
    add(x, sparkle(1.6, 0.12, 1), 0.02)
    return finish_sfx(x, wet=0.35, rt60=1.8)


def sfx_fanfare():
    """Редкий питомец: «та-та-та-таам» медных + литавры, тарелка и блёстки."""
    x = np.zeros(n_of(3.4))
    step = 0.11
    for i, note in enumerate(["G4", "C5", "E5"]):
        add(x, brass(hz(note), step * 0.85), step * i, 0.5)
    hit = step * 3
    add(x, brass(hz("G5"), 1.5), hit, 0.5)
    for note in ["C4", "E4", "C5", "E5"]:
        add(x, brass(hz(note), 1.5, bright=1800.0), hit, 0.3)
    n = n_of(1.2)
    t = times(n)
    timpani = np.sin(phase(65 + 25 * np.exp(-t / 0.08), n)) * np.exp(-t / 0.45) * smooth_attack(n, 0.002)
    add(x, timpani, hit, 0.9)
    n = n_of(2.0)
    add(x, noise(n, lo=4000, hi=14000, rng=np.random.default_rng(15)) * np.exp(-times(n) / 0.6) *
        smooth_attack(n, 0.004), hit, 0.18)
    for i, note in enumerate(["C7", "E7", "G7", "C8"]):
        add(x, glock(hz(note), 1.0), hit + 0.15 + 0.06 * i, 0.12)
    return finish_sfx(x, wet=0.3, rt60=1.6)


def sfx_rebirth():
    """Перерождение: нарастающий взлёт, удар и хор с блёстками."""
    x = np.zeros(n_of(4.4))
    rise = 1.3
    n = n_of(rise)
    t = times(n)
    progress = t / rise
    add(x, swept_noise(n, 300 * 20 ** progress, width=0.5, seed=1) * progress ** 2, 0, 0.35)
    glide = additive(hz("C3") * 2 ** (2 * progress), n, "saw", cutoff=400 + 3000 * progress ** 2, max_h=40)
    add(x, glide * progress ** 1.5, 0, 0.25)
    n = n_of(1.6)
    t = times(n)
    boom = np.sin(phase(42 + 60 * np.exp(-t / 0.05), n)) * np.exp(-t / 0.5) * smooth_attack(n, 0.002)
    add(x, boom, rise, 0.9)
    n = n_of(2.5)
    add(x, noise(n, lo=3000, hi=15000, rng=np.random.default_rng(16)) * np.exp(-times(n) / 0.8) *
        smooth_attack(n, 0.003), rise, 0.2)
    for note in ["C4", "G4", "C5", "E5", "G5"]:
        add(x, choir(hz(note), 1.8), rise, 0.22)
    for i, note in enumerate(["C6", "E6", "G6", "C7", "E7", "G7", "C8"]):
        add(x, glock(hz(note), 1.2), rise + 0.05 + 0.07 * i, 0.18)
    return finish_sfx(x, wet=0.38, rt60=2.4)


def sfx_unlock():
    """Новый мир / улучшение: восходящее арпеджио и аккорд-колокольчик."""
    x = np.zeros(n_of(1.9))
    for i, note in enumerate(["C5", "E5", "G5", "C6"]):
        add(x, coin_tone(hz(note), 0.5, 0.18), 0.075 * i, 0.6)
    for note in ["C6", "E6", "G6"]:
        n = n_of(1.3)
        chime = 0.35 * glock(hz(note), 1.3) + 0.25 * fm_bell(hz(note), n, ratio=2.0, index=1.0, index_decay=0.1, decay=0.5)
        add(x, chime, 0.3)
    add(x, sparkle(1.2, 0.08, 2), 0.3)
    return finish_sfx(x, wet=0.28, rt60=1.5)


def sfx_merge():
    """Слияние: два тона слева и справа сходятся в один, затем яркий «дзынь»."""
    total = n_of(2.3)
    out = np.zeros((2, total))
    n = n_of(0.6)
    t = times(n)
    target = hz("C6")
    for note, pan in (("A5", -0.8), ("E6", 0.8)):
        f = hz(note) + (target - hz(note)) * (1 - np.exp(-t / 0.15))
        tremolo = 0.75 + 0.25 * np.sin(2 * np.pi * 11 * t)
        tone = np.sin(phase(f, n)) * tremolo * adsr(n, 0.5, a=0.08, d=1, s=1, r=0.1)
        place(out, tone, 0, 0.4, pan)
    place(out, swept_noise(n, 600 * 8 ** (t / 0.6), width=0.45, seed=2) * (t / 0.6) ** 1.5, 0, 0.12)
    hit = 0.55
    ding = glock(hz("C6"), 1.6) + 0.6 * glock(hz("G6"), 1.6) + 0.4 * glock(hz("C7"), 1.6)
    ding = ding + 0.3 * fm_bell(hz("C6"), len(ding), ratio=3.5, index=1.5, index_decay=0.08, decay=0.6)
    place(out, ding, hit, 0.5)
    place(out, sparkle(1.3, 0.1, 3), hit)
    return finish_sfx(out, wet=0.35, rt60=1.8)


def sfx_teleport():
    """Телепорт: свист-вихрь вверх-вниз, пролетающий слева направо."""
    d = 0.95
    n = n_of(1.15)
    t = times(n)
    arc = np.sin(np.pi * np.clip(t / d, 0, 1))
    whoosh = swept_noise(n, 300 * 20 ** arc, width=0.55, seed=3) * arc ** 1.2
    warp = np.sin(phase(220 * 2 ** (2.5 * arc) * (1 + 0.03 * np.sin(2 * np.pi * 18 * t)), n)) * arc ** 2
    angle = np.pi / 2 * np.clip(t / d, 0, 1)
    mono = whoosh * 0.5 + warp * 0.15
    out = np.array([mono * np.cos(angle) * 1.2 + mono * 0.25, mono * np.sin(angle) * 1.2 + mono * 0.25])
    return finish_sfx(out, wet=0.3, rt60=1.2)


def sfx_error():
    """Ошибка: два мягких низких «бум» вниз — понятно, но не раздражает."""
    x = np.zeros(n_of(0.5))
    for note, start, hold in (("E4", 0.0, 0.08), ("C4", 0.11, 0.16)):
        n = n_of(hold + 0.06)
        tone = 0.6 * additive(hz(note), n, "square", cutoff=800, max_h=20) + 0.4 * np.sin(phase(hz(note), n))
        add(x, tone * adsr(n, hold, a=0.004, d=0.08, s=0.45, r=0.05), start)
    return finish_sfx(x, wet=0.08, rt60=0.4, peak_db=-5.0)


def sfx_purchase():
    """Покупка: звонкое «дзынь-дзынь» вверх и монетки."""
    x = np.zeros(n_of(1.3))
    add(x, fade_out(coin_tone(hz("E6"), 0.09, 0.3), 0.012), 0, 0.5)
    add(x, 0.5 * coin_tone(hz("B6"), 0.8, 0.22) + 0.5 * glock(hz("B6"), 0.8), 0.08)
    add(x, glock(hz("E7"), 0.9), 0.12, 0.25)
    rng = np.random.default_rng(17)
    for i in range(5):
        add(x, tink(rng.uniform(3500, 5500)), 0.16 + 0.05 * i + rng.uniform(0, 0.015), 0.35 * 0.85 ** i)
    return finish_sfx(x, wet=0.22, rt60=1.0)


# ===================================================================== музыка

class Song:
    """Бесшовная петля: ноты кладутся на дорожки, в конце хвосты с конца переносятся в начало."""

    def __init__(self, bpm, bars, tail=7.0):
        self.beat = 60 / bpm
        self.bar_len = 4 * self.beat
        self.length = bars * self.bar_len
        size = n_of(self.length + tail)
        self.dry = np.zeros((2, size))
        self.verb = np.zeros((2, size))
        self.echo = np.zeros((2, size))

    def at(self, bar, beat=0.0):
        return bar * self.bar_len + beat * self.beat

    def add(self, sig, time, gain=1.0, pan=0.0, verb=0.15, echo=0.0):
        place(self.dry, sig, time, gain, pan)
        if verb:
            place(self.verb, sig, time, gain * verb, pan)
        if echo:
            place(self.echo, sig, time, gain * echo, pan)

    def ambience(self, lo, hi, gain, cycles=3, seed=0):
        """Ветер / космический гул: циклический шум и целое число «волн» громкости — без шва."""
        L = n_of(self.length)
        rng = np.random.default_rng(400 + seed)
        u = np.arange(L) / L
        for ch in range(2):
            swell = 0.55 + 0.45 * np.sin(2 * np.pi * cycles * u + ch * 1.3 + seed)
            self.dry[ch, :L] += noise(L, lo=lo, hi=hi, rng=rng) * swell * gain

    def render(self, rt60=2.0, echo_time=None, echo_feedback=0.45, rms_db=-17.0):
        size = self.dry.shape[1]
        if echo_time and np.any(self.echo):
            mono = self.echo.mean(axis=0)
            echoed = np.zeros_like(self.echo)
            d = n_of(echo_time)
            for i in range(1, 9):
                shift = d * i
                if shift >= size:
                    break
                echoed[i % 2, shift:] += mono[:-shift] * echo_feedback ** (i - 1)
            echoed = spectral(echoed, lo=250, hi=5000)
            self.dry += echoed
            self.verb += echoed * 0.5
        ir = reverb_ir(rt60=rt60, seed=3)
        mix = self.dry.copy()
        mix[0] += convolve(0.7 * self.verb[0] + 0.3 * self.verb[1], ir[0])[:size]
        mix[1] += convolve(0.3 * self.verb[0] + 0.7 * self.verb[1], ir[1])[:size]
        L = n_of(self.length)
        loop = mix[:, :L].copy()
        rest = mix[:, L:]
        while rest.shape[1]:
            k = min(L, rest.shape[1])
            loop[:, :k] += rest[:, :k]
            rest = rest[:, k:]
        loop = spectral(loop, lo=28, order=2)
        return master(loop, rms_db)


def master(x, rms_db):
    x = x - x.mean(axis=1, keepdims=True)
    x = x * (10 ** (rms_db / 20) / (np.sqrt(np.mean(x ** 2)) + 1e-12))
    th = 0.6
    a = np.abs(x)
    x = np.sign(x) * np.where(a > th, th + (1 - th) * np.tanh((a - th) / (1 - th)), a)
    peak = np.max(np.abs(x))
    return x * (0.89 / peak) if peak > 0.89 else x


def parse_bar(text):
    """'E5:2 G5:1 r:1' -> [('E5', 2), ('G5', 1), (None, 1)]; длительности в восьмых, в такте 8."""
    notes = []
    for token in text.split():
        name, length = token.split(":")
        notes.append((None if name == "r" else name, float(length)))
    assert abs(sum(length for _, length in notes) - 8) < 1e-9, text
    return notes


CHORDS = {
    "C": ("C3", ["E4", "G4", "C5"], ["C4", "E4", "G4"]),
    "Am": ("A2", ["E4", "A4", "C5"], ["A3", "C4", "E4"]),
    "F": ("F2", ["F4", "A4", "C5"], ["F3", "A3", "C4"]),
    "G": ("G2", ["D4", "G4", "B4"], ["G3", "B3", "D4"]),
    "Dm": ("D3", ["D4", "F4", "A4"], ["D4", "F4", "A4"]),
    "Em": ("E3", ["E4", "G4", "B4"], ["E4", "G4", "B4"]),
}

FOREST_CHORDS = ["C", "Am", "F", "G", "C", "Am", "Dm G", "C",
                 "F", "G", "Em", "Am", "Dm", "G", "C", "G"]
FOREST_MELODY = [
    "E5:2 G5:1 E5:1 C5:2 G4:2", "A4:1 C5:1 E5:2 D5:1 C5:1 A4:2",
    "F4:1 A4:1 C5:2 F5:2 E5:1 D5:1", "D5:3 B4:1 G4:2 r:2",
    "E5:2 G5:1 E5:1 C6:2 B5:1 A5:1", "A5:2 G5:1 E5:1 C5:2 E5:2",
    "F5:2 E5:1 D5:1 B4:2 D5:1 G5:1", "C5:4 r:2 G4:1 A4:1",
    "C5:2 A4:1 C5:1 F5:3 E5:1", "D5:2 B4:1 D5:1 G5:3 F5:1",
    "E5:1 G5:1 B5:2 G5:1 E5:1 B4:2", "C5:1 E5:1 A5:2 G5:1 E5:1 C5:2",
    "D5:1 F5:1 A5:2 F5:1 D5:1 A4:2", "B4:1 D5:1 G5:2 F5:1 D5:1 B4:2",
    "C5:1 E5:1 G5:1 C6:1 E6:2 D6:1 C6:1", "B5:2 G5:2 D5:2 r:2",
]


def music_forest():
    """Лес: весёлая маримба, «умпа»-бас, шейкер и птицы. До мажор, 112 ударов в минуту."""
    song = Song(bpm=112, bars=32)
    for bar in range(32):
        second_pass = bar >= 16
        names = FOREST_CHORDS[bar % 16].split()
        span = 4 / len(names)
        for half, name in enumerate(names):
            root, stab, pad_notes = CHORDS[name]
            start = half * span
            for offset, note in ([(0, midi(root)), (2, midi(root) + 7)] if span == 4 else [(0, midi(root))]):
                song.add(bass_pluck(hz(note), 0.9 * song.beat), song.at(bar, start + offset), 0.5, 0, verb=0.04)
            for offset in ([1, 3] if span == 4 else [1]):
                for i, note in enumerate(stab):
                    song.add(marimba(hz(note), 0.6), song.at(bar, start + offset) + 0.004 * i, 0.13,
                             pan=-0.3 + 0.3 * i, verb=0.12)
            for i, note in enumerate(pad_notes):
                song.add(pad(hz(note), span * song.beat, cutoff=1000.0, attack=0.25, release=0.5),
                         song.at(bar, start), 0.06, pan=-0.4 + 0.4 * i, verb=0.3)
        for b in (0, 2):
            song.add(kick(), song.at(bar, b), 0.5, verb=0.02)
        for b in (1, 3):
            song.add(clap(), song.at(bar, b), 0.2, pan=0.05, verb=0.15)
        for e in range(8):
            song.add(shaker(), song.at(bar, e * 0.5), 0.1 if e % 2 else 0.055, pan=0.35, verb=0.05)
        if bar % 2 == 1:
            song.add(woodblock(), song.at(bar, 3.5), 0.16, pan=-0.35, verb=0.1)
        pos = 0.0
        for note, length in parse_bar(FOREST_MELODY[bar % 16]):
            if note:
                t = song.at(bar, pos / 2)
                song.add(marimba(hz(note), 0.9), t, 0.42, pan=0.05, verb=0.18)
                if second_pass:
                    song.add(glock(hz(note), 1.0, 0.6), t, 0.12, pan=0.2, verb=0.3)
            pos += length
    rng = np.random.default_rng(31)
    for i in range(14):
        song.add(chirp(i % 5), rng.uniform(0, song.length), rng.uniform(0.03, 0.06), pan=rng.uniform(-0.8, 0.8), verb=0.5)
    song.ambience(lo=200, hi=1500, gain=0.012, cycles=4, seed=1)
    return song.render(rt60=1.6)


DESERT_CHORDS = ["D", "Gm", "D", "Eb", "D", "Cm", "Eb", "D"]
OUD_PATTERNS = {
    "D": ["D3", "A3", "D4", "Eb4", "D4", "A3", "F#3", "A3"],
    "Gm": ["G2", "D3", "G3", "Bb3", "A3", "G3", "D3", "Bb2"],
    "Eb": ["Eb3", "Bb3", "Eb4", "D4", "Eb4", "Bb3", "G3", "Bb3"],
    "Cm": ["C3", "G3", "C4", "D4", "Eb4", "C4", "G3", "Eb3"],
}
DESERT_MELODY = [
    "r:2 A4:2 Bb4:1 A4:1 G4:1 F#4:1", "G4:4 Bb4:1 A4:1 G4:2",
    "F#4:1 G4:1 A4:2 D5:3 C5:1", "Bb4:2 G4:2 Eb4:3 r:1",
    "D4:1 Eb4:1 F#4:1 G4:1 A4:2 F#4:2", "G4:2 Eb4:2 C4:2 Eb4:1 F#4:1",
    "G4:2 Bb4:2 A4:1 G4:1 F#4:1 Eb4:1", "D4:6 r:2",
    "A4:1 Bb4:1 C5:1 D5:1 Eb5:2 D5:2", "D5:1 C5:1 Bb4:2 G4:2 Bb4:1 C5:1",
    "D5:2 F#5:2 A5:3 G5:1", "G5:2 Eb5:2 Bb4:2 C5:1 D5:1",
    "Eb5:1 D5:1 C5:1 Bb4:1 A4:2 D5:2", "C5:2 Bb4:1 A4:1 G4:2 Eb4:2",
    "F#4:1 G4:1 A4:1 Bb4:1 A4:1 G4:1 F#4:1 Eb4:1", "D4:4 r:4",
]


def music_desert():
    """Пустыня: ней (флейта), уд, дарбука и бурдон. Ре хиджаз, 100 ударов в минуту."""
    song = Song(bpm=100, bars=32)
    for bar in range(32):
        second_pass = bar >= 16
        local = bar % 16
        name = DESERT_CHORDS[local % 8]
        if bar % 2 == 0:
            for note, gain in (("D2", 0.5), ("A2", 0.28), ("D3", 0.2)):
                song.add(pad(hz(note), 2 * song.bar_len, cutoff=650.0, attack=0.8, release=1.2),
                         song.at(bar), gain * 0.3, verb=0.2)
        for e, note in enumerate(OUD_PATTERNS[name]):
            song.add(oud(hz(note), 0.9, e), song.at(bar, e * 0.5), 0.3 if e == 0 else 0.2, pan=-0.3, verb=0.15)
        for e in (0, 4):
            song.add(doum(), song.at(bar, e * 0.5), 0.55, verb=0.08)
        for e in (1, 3, 6):
            song.add(tek(), song.at(bar, e * 0.5), 0.32, pan=0.15, verb=0.1)
        for e in (2, 5, 7):
            song.add(tek(1.25), song.at(bar, e * 0.5), 0.12, pan=0.25, verb=0.1)
        for e in (1, 3, 5, 7):
            song.add(jingle(e), song.at(bar, e * 0.5), 0.14 if second_pass else 0.08, pan=0.45, verb=0.12)
        if bar % 4 == 3:
            for s in range(12, 16):
                song.add(tek(1.0 + 0.05 * (s % 2)), song.at(bar, s * 0.25), 0.18 + 0.03 * (s - 12), pan=0.15, verb=0.1)
        pos = 0.0
        for note, length in parse_bar(DESERT_MELODY[local]):
            if note:
                t = song.at(bar, pos / 2)
                hold = length / 2 * song.beat
                song.add(flute(hz(note), hold, int(pos)), t, 0.3, pan=0.12, verb=0.35)
                if second_pass:
                    song.add(oud(hz(note) / 2, 0.9, 7), t, 0.14, pan=-0.15, verb=0.2)
            pos += length
    song.ambience(lo=150, hi=900, gain=0.02, cycles=3, seed=2)
    return song.render(rt60=2.2)


SPACE_CHORDS = [
    ("A2", ["A3", "C4", "E4", "G4", "B4"]),
    ("F2", ["F3", "A3", "C4", "E4", "G4"]),
    ("C3", ["G3", "C4", "E4", "G4", "B4"]),
    ("G2", ["G3", "B3", "D4", "E4", "A4"]),
    ("D2", ["F3", "A3", "C4", "E4", "A4"]),
    ("F2", ["F3", "A3", "C4", "E4", "G4"]),
    ("E2", ["E3", "G3", "B3", "D4", "G4"]),
    ("A2", ["A3", "D4", "E4", "B4"]),
]
SPACE_MELODY = [
    "E5:3 D5:1 C5:2 B4:2", "C5:4 A4:2 G4:2", "G4:3 E4:1 G4:2 C5:2", "B4:6 D5:2",
    "E5:3 F5:1 E5:2 D5:2", "C5:4 E5:2 G5:2", "G5:3 E5:1 D5:2 B4:2", "A4:8",
]
ARP_ORDER = [0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 2, 3, 4, 5, 4, 3]


def music_space():
    """Космос: тёплые пэды, арпеджио электропиано с эхом, мелодия и искры. Ля минор, 84 удара."""
    song = Song(bpm=84, bars=32, tail=9.0)
    rng = np.random.default_rng(51)
    for bar in range(32):
        root, voicing = SPACE_CHORDS[bar % 8]
        cutoff = 900.0 if bar < 16 else 1400.0
        for i, note in enumerate(voicing):
            song.add(pad(hz(note), song.bar_len, cutoff=cutoff, attack=1.0, release=1.8, detune=10.0),
                     song.at(bar), 0.07, pan=-0.5 + 0.25 * i, verb=0.45)
        n = n_of(song.bar_len + 0.6)
        sub = np.sin(phase(hz(root), n)) + 0.15 * np.sin(2 * phase(hz(root), n))
        song.add(sub * adsr(n, song.bar_len, a=0.3, d=1.0, s=0.9, r=0.6), song.at(bar), 0.2, verb=0.0)
        if bar >= 4:
            tones = [midi(note) for note in voicing[1:]]
            tones += [tones[0] + 12, tones[1] + 12]
            for s, idx in enumerate(ARP_ORDER):
                velocity = 1.0 if s % 4 == 0 else 0.7
                song.add(e_piano(hz(tones[idx % len(tones)]), 0.9), song.at(bar, s * 0.25), 0.11 * velocity,
                         pan=-0.35 if s % 2 else 0.35, verb=0.3, echo=0.35)
        if bar >= 8:
            for b in (0, 2):
                song.add(kick(0.1), song.at(bar, b), 0.3, verb=0.1)
        if bar >= 16:
            for e in range(1, 8, 2):
                song.add(hat(), song.at(bar, e * 0.5), 0.05, pan=0.3, verb=0.15)
            phrase = SPACE_MELODY[bar % 8]
            shift = 12 if 24 <= bar < 28 else 0
            pos = 0.0
            for note, length in parse_bar(phrase):
                if note:
                    hold = length / 2 * song.beat
                    song.add(lead(hz(midi(note) + shift), hold), song.at(bar, pos / 2), 0.22,
                             pan=0.05, verb=0.4, echo=0.3)
                pos += length
        for _ in range(rng.integers(1, 3)):
            note = ["A6", "C7", "E7", "G7", "B6", "D7"][rng.integers(0, 6)]
            song.add(glock(hz(note), 1.4), song.at(bar, rng.uniform(0, 4)), 0.05,
                     pan=rng.uniform(-0.8, 0.8), verb=0.7)
    song.ambience(lo=250, hi=1800, gain=0.015, cycles=2, seed=3)
    return song.render(rt60=3.2, echo_time=0.75 * song.beat, echo_feedback=0.5)


# ===================================================================== запись

SOUNDS = {
    "click.ogg": sfx_click,
    "button.ogg": sfx_button,
    "coin.ogg": sfx_coin,
    "sell.ogg": sfx_sell,
    "egg_shake.ogg": sfx_egg_shake,
    "egg_crack.ogg": sfx_egg_crack,
    "reveal.ogg": sfx_reveal,
    "fanfare.ogg": sfx_fanfare,
    "rebirth.ogg": sfx_rebirth,
    "unlock.ogg": sfx_unlock,
    "merge.ogg": sfx_merge,
    "teleport.ogg": sfx_teleport,
    "error.ogg": sfx_error,
    "purchase.ogg": sfx_purchase,
    "music_forest.ogg": music_forest,
    "music_desert.ogg": music_desert,
    "music_space.ogg": music_space,
}


def write_ogg(path, stereo, quality):
    pcm = (np.clip(stereo.T, -1, 1) * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "sound.wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                        "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)


def main(names):
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, make in SOUNDS.items():
        if names and name not in names:
            continue
        audio = make()
        path = os.path.join(OUT_DIR, name)
        write_ogg(path, audio, 5 if name.startswith("music") else 6)
        peak = 20 * np.log10(np.max(np.abs(audio)))
        rms = 20 * np.log10(np.sqrt(np.mean(audio ** 2)))
        print(f"{name:20s} {audio.shape[1] / SR:6.2f} с  пик {peak:5.1f} dB  RMS {rms:5.1f} dB  "
              f"{os.path.getsize(path) // 1024} КБ")


if __name__ == "__main__":
    main(sys.argv[1:])
