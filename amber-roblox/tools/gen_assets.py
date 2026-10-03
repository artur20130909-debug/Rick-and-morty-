#!/usr/bin/env python3
# Процедурный генератор звуков и текстур для Amber Alert (Roblox).
# Всё создаётся с нуля (синтез + шум), без внешних файлов и чужих логотипов.
#
#   python3 tools/gen_assets.py                  # всё: звуки, картинки, превью, MANIFEST.md
#   python3 tools/gen_assets.py --only sounds    # только звуки (или images)
#   python3 tools/gen_assets.py --keys EasTone,Carpet   # только выбранные ключи
#   python3 tools/gen_assets.py --check          # только анализ готовых файлов
#
# Нужно: Python 3, numpy, scipy, Pillow, ffmpeg (с libvorbis) в PATH.
# Результат: assets/sounds/<Key>.ogg, assets/images/<Key>.png, assets/MANIFEST.md,
#            assets/preview.png (контактный лист картинок), assets/preview_audio.png (спектрограммы).
# Генерация детерминирована: у каждого ключа своё зерно, повторный запуск даёт те же файлы.

import argparse
import hashlib
import io
import json
import math
import os
import re
import shutil
import subprocess
import sys
import time

import numpy as np
from scipy import ndimage, signal
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'assets')
SND_DIR = os.path.join(ASSETS, 'sounds')
IMG_DIR = os.path.join(ASSETS, 'images')
CONFIG_LUA = os.path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared', 'Config.lua')

SR = 44100
PEAK = 10 ** (-1.0 / 20)   # -1 dBFS
TAU = 2 * np.pi


def seed_of(key):
    # стабильное зерно из имени ключа
    return int(hashlib.sha1(key.encode('utf-8')).hexdigest()[:8], 16)


# =====================================================================================
# DSP: базовые кирпичики
# =====================================================================================

def ns(d):
    return int(round(d * SR))


def tvec(n):
    return np.arange(n) / SR


def arr(v, n):
    if np.isscalar(v):
        return np.full(n, float(v))
    v = np.asarray(v, dtype=float)
    return v[:n] if len(v) >= n else np.pad(v, (0, n - len(v)), mode='edge')


def pw(points, n):
    # кусочно-линейная огибающая: [(сек, значение), ...]
    ts = np.array([p[0] for p in points]) * SR
    vs = np.array([p[1] for p in points], dtype=float)
    return np.interp(np.arange(n), ts, vs)


def pwexp(points, n):
    # то же, но интерполяция в логарифме (для частот)
    return np.exp(pw([(t, np.log(max(v, 1e-9))) for t, v in points], n))


def expdec(n, tau, delay=0):
    t = tvec(n) - delay
    e = np.exp(-np.maximum(t, 0) / tau)
    e[t < 0] = 0
    return e


def fade(x, fin=0.002, fout=0.02):
    x = np.array(x, dtype=float, copy=True)
    n = x.shape[-1]
    a, b = min(ns(fin), n // 2), min(ns(fout), n // 2)
    if a > 1:
        x[..., :a] *= 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a))
    if b > 1:
        x[..., n - b:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, b))
    return x


def phase_of(freq, n, phase0=0.0):
    f = arr(freq, n)
    return TAU * (np.concatenate([[0.0], np.cumsum(f)[:-1]]) / SR) + phase0


def loop_phase(freq, n, phase0=0.0):
    # фаза, которая за n отсчётов делает целое число оборотов (для бесшовных петель)
    f = arr(freq, n)
    tot = f.sum() / SR
    if tot > 0.5:
        f = f * (round(tot) / tot)
    return phase_of(f, n, phase0)


def sine(freq, n, phase0=0.0):
    return np.sin(phase_of(freq, n, phase0))


def saw(freq, n, phase0=0.0, loop=False):
    # пила с PolyBLEP (без алиасинга)
    f = arr(freq, n)
    dt = np.maximum(f / SR, 1e-9)
    ph = (loop_phase(f, n) if loop else phase_of(f, n)) / TAU + phase0
    ph = ph % 1.0
    y = 2 * ph - 1
    m = ph < dt
    t = ph[m] / dt[m]
    y[m] -= t + t - t * t - 1
    m = ph > 1 - dt
    t = (ph[m] - 1) / dt[m]
    y[m] -= t * t + t + t + 1
    return y


def pulse(freq, n, width=0.5, loop=False, phase0=0.0):
    return 0.5 * (saw(freq, n, phase0, loop) - saw(freq, n, phase0 + width, loop))


def tri(freq, n, loop=False):
    ph = ((loop_phase(freq, n) if loop else phase_of(freq, n)) / TAU) % 1.0
    return 4 * np.abs(ph - 0.5) - 1


# ---------- шумы ----------

def white(n, rng):
    return rng.standard_normal(n)


def colored(n, rng, slope_db=-3.0, lo=None, hi=None):
    # шум с наклоном спектра (дБ/октава), периодический по длине n (годится для петель)
    spec = rng.standard_normal(n // 2 + 1) + 1j * rng.standard_normal(n // 2 + 1)
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = f[1]
    g = (f / 1000.0) ** (slope_db / 6.0206)
    if lo:
        g *= 1 / np.sqrt(1 + (lo / f) ** 4)
    if hi:
        g *= 1 / np.sqrt(1 + (f / hi) ** 4)
    g[0] = 0
    y = np.fft.irfft(spec * g, n)
    return y / (np.std(y) + 1e-12)


def pink(n, rng, **kw):
    return colored(n, rng, -3.0, **kw)


def brown(n, rng, **kw):
    return colored(n, rng, -6.0, **kw)


def slow_curve(n, rng, rate=0.5, lo=0.0, hi=1.0):
    # гладкая случайная кривая (периодична по n), значения в [lo, hi]
    k = max(2, int(rate * n / SR))
    spec = np.zeros(n // 2 + 1, complex)
    m = min(k, len(spec) - 1)
    spec[1:m + 1] = (rng.standard_normal(m) + 1j * rng.standard_normal(m)) / np.sqrt(np.arange(1, m + 1))
    y = np.fft.irfft(spec, n)
    y = (y - y.min()) / (y.max() - y.min() + 1e-12)
    return lo + (hi - lo) * y


def dust(n, rng, rate, amp_sd=0.5):
    # редкие случайные импульсы (треск)
    x = np.zeros(n)
    cnt = rng.poisson(rate * n / SR)
    idx = rng.integers(0, n, cnt)
    x[idx] += rng.standard_normal(cnt) * amp_sd + np.sign(rng.standard_normal(cnt))
    return x


# ---------- фильтры ----------

def _sos(kind, f, order=2):
    nyq = SR / 2
    if kind == 'bandpass':
        lo, hi = f
        lo = max(lo, 5.0)
        hi = min(hi, nyq * 0.98)
        return signal.butter(order, [lo / nyq, hi / nyq], 'bandpass', output='sos')
    return signal.butter(order, min(f, nyq * 0.98) / nyq, kind, output='sos')


def lp(x, f, order=2):
    return signal.sosfilt(_sos('lowpass', f, order), x, axis=-1)


def hp(x, f, order=2):
    return signal.sosfilt(_sos('highpass', f, order), x, axis=-1)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos('bandpass', (lo, hi), order), x, axis=-1)


def rbj(kind, f0, Q=0.707, gain_db=0.0):
    f0 = min(max(f0, 10.0), SR * 0.49)
    A = 10 ** (gain_db / 40)
    w0 = TAU * f0 / SR
    al = np.sin(w0) / (2 * Q)
    cw = np.cos(w0)
    if kind == 'bpf':
        b = [al, 0, -al]
        a = [1 + al, -2 * cw, 1 - al]
    elif kind == 'peak':
        b = [1 + al * A, -2 * cw, 1 - al * A]
        a = [1 + al / A, -2 * cw, 1 - al / A]
    elif kind == 'lpf':
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + al, -2 * cw, 1 - al]
    elif kind == 'hpf':
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + al, -2 * cw, 1 - al]
    elif kind == 'lowshelf':
        sq = 2 * np.sqrt(A) * al
        b = [A * ((A + 1) - (A - 1) * cw + sq), 2 * A * ((A - 1) - (A + 1) * cw), A * ((A + 1) - (A - 1) * cw - sq)]
        a = [(A + 1) + (A - 1) * cw + sq, -2 * ((A - 1) + (A + 1) * cw), (A + 1) + (A - 1) * cw - sq]
    elif kind == 'highshelf':
        sq = 2 * np.sqrt(A) * al
        b = [A * ((A + 1) + (A - 1) * cw + sq), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - sq)]
        a = [(A + 1) - (A - 1) * cw + sq, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - sq]
    else:
        raise ValueError(kind)
    return np.array([b[0] / a[0], b[1] / a[0], b[2] / a[0], 1.0, a[1] / a[0], a[2] / a[0]])


def biquad(x, kind, f0, Q=0.707, gain_db=0.0):
    return signal.sosfilt(rbj(kind, f0, Q, gain_db)[None, :], x, axis=-1)


def reson(x, f0, Q):
    return biquad(x, 'bpf', f0, Q)


def eq(x, bands):
    # bands: [(kind, f, Q, gain_db), ...]
    sos = np.array([rbj(k, f, q, g) for k, f, q, g in bands])
    return signal.sosfilt(sos, x, axis=-1)


def tvf(x, kind, f, Q=0.707, block=64, poles=2):
    # фильтр с меняющейся частотой (поблочно, состояние переносится)
    n = len(x)
    f = arr(f, n)
    y = np.array(x, dtype=float)
    for _ in range(poles // 2):
        out = np.empty(n)
        zi = np.zeros((1, 2))
        for s in range(0, n, block):
            e = min(n, s + block)
            sos = rbj(kind, f[(s + e) // 2], Q)[None, :]
            out[s:e], zi = signal.sosfilt(sos, y[s:e], zi=zi)
        y = out
    return y


def circ(x, fn, pad):
    # применить фильтр «по кругу», чтобы петля осталась бесшовной
    pad = min(pad, x.shape[-1])
    xx = np.concatenate([x[..., -pad:], x], axis=-1)
    return fn(xx)[..., pad:]


def spec_shape(x, gain_fn, nper=1024, circular=False):
    # фильтр во времени-частоте: gain_fn(freqs[F], times[T]) -> матрица усилений F x T
    hop = nper // 4
    n = len(x)
    pad = nper * 2 if circular else 0
    xx = np.concatenate([x[-pad:], x, x[:pad]]) if circular else x
    f, t, Z = signal.stft(xx, SR, nperseg=nper, noverlap=nper - hop)
    t = t - pad / SR
    if circular:
        t = np.mod(t, n / SR)
    G = gain_fn(f, t)
    _, y = signal.istft(Z * G, SR, nperseg=nper, noverlap=nper - hop)
    y = y[pad:pad + n]
    if len(y) < n:
        y = np.pad(y, (0, n - len(y)))
    return y


# ---------- динамика ----------

def sat(x, drive=2.0):
    return np.tanh(drive * x) / np.tanh(drive)


def asym_sat(x, drive=2.0, bias=0.2):
    y = np.tanh(drive * (x + bias)) - np.tanh(drive * bias)
    return y / (np.max(np.abs(y)) + 1e-12)


def env_follow(x, win=0.01):
    w = max(1, ns(win))
    return np.sqrt(ndimage.uniform_filter1d(x ** 2, w, mode='nearest') + 1e-12)


def compress(x, thresh_db=-18, ratio=4.0, win=0.01, makeup=True):
    mono = x if x.ndim == 1 else np.max(np.abs(x), axis=0)
    e = env_follow(mono / (np.max(np.abs(mono)) + 1e-12), win)
    th = 10 ** (thresh_db / 20)
    g = np.ones_like(e)
    m = e > th
    g[m] = (th * (e[m] / th) ** (1 / ratio)) / e[m]
    g = ndimage.uniform_filter1d(g, max(1, ns(win / 2)), mode='nearest')
    y = x * g
    return y


def normalize(x, peak=PEAK):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def dc_block(x, loop=False):
    if loop:
        return circ(x - np.mean(x, axis=-1, keepdims=True), lambda v: hp(v, 18, 2), ns(1.0))
    return hp(x, 18, 2)


def pan2(x, p):
    # равномощностная панорама, p в [-1, 1]
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)])


def mix_into(buf, sig, t, gain=1.0, wrap=False):
    # добавить сигнал в буфер с момента t (сек); wrap=True — по кругу (для петель)
    n = buf.shape[-1]
    i0 = int(round(t * SR))
    m = sig.shape[-1]
    if wrap:
        s = sig if (buf.ndim == 1 or sig.ndim == 2) else np.stack([sig] * buf.shape[0])
        pos = 0
        i = i0 % n
        while pos < m:
            k = min(m - pos, n - i)
            buf[..., i:i + k] += s[..., pos:pos + k] * gain
            pos += k
            i = 0
        return buf
    if i0 >= n:
        return buf
    a = max(0, i0)
    s0 = a - i0
    e = min(n, i0 + m)
    if e <= a:
        return buf
    if buf.ndim == 1:
        buf[a:e] += sig[s0:s0 + e - a] * gain
    else:
        s = sig if sig.ndim == 2 else np.stack([sig] * buf.shape[0])
        buf[:, a:e] += s[:, s0:s0 + e - a] * gain
    return buf


# ---------- модальный синтез ----------

def modes(n, freqs, decays, amps=None, rng=None, phase_rand=True):
    t = tvec(n)
    y = np.zeros(n)
    amps = amps if amps is not None else [1.0] * len(freqs)
    for i, (f, d, a) in enumerate(zip(freqs, decays, amps)):
        if f >= SR * 0.47 or f <= 0:
            continue
        ph = rng.uniform(0, TAU) if (rng is not None and phase_rand) else 0.0
        m = int(min(n, d * 9 * SR))
        e = np.exp(-t[:m] / d)
        e = np.clip(e - e[-1], 0, None) / max(1e-9, 1 - e[-1])   # дотянуть до нуля — без щелчка в конце
        y[:m] += a * e * np.sin(TAU * f * t[:m] + ph)
    return y


def click_pulse(width=0.0005):
    # короткий импульс-«удар» (ширина задаёт яркость)
    m = max(2, ns(width))
    return np.hanning(m + 2)[1:-1]


def strike(n, freqs, decays, amps, rng, width=0.0004, noise=0.0, noise_tau=0.004):
    ir = modes(n, freqs, decays, amps, rng)
    ex = click_pulse(width)
    y = signal.fftconvolve(ir, ex)[:n]
    if noise > 0:
        y += noise * white(n, rng) * expdec(n, noise_tau) * np.max(np.abs(y))
    return y


# ---------- реверберация (синтетические импульсные отклики) ----------

def make_ir(rt60, dur=None, pre=0.0, early=(), bands=(1.25, 1.0, 0.7, 0.45), stereo=False, rng=None,
            lowcut=60, highcut=12000, density_ms=0.0):
    rng = rng or np.random.default_rng(1)
    dur = dur or min(rt60 * 1.4, 6.0)
    n = ns(dur)
    t = tvec(n)
    chans = []
    for _ in range(2 if stereo else 1):
        src = white(n, rng)
        if density_ms > 0:
            # разреженный хвост (флаттер/улица)
            src = src * (rng.random(n) < 1.0 / (density_ms * SR / 1000))
            src *= 6.0
        edges = [lowcut, 300, 2000, 6000, highcut]
        y = np.zeros(n)
        for i, k in enumerate(bands):
            lo, hi = edges[i], edges[i + 1]
            if lo >= hi:
                continue
            b = bp(src, lo, hi, 2)
            rt = rt60 * k
            y += b * 10 ** (-3 * t / rt)
        y *= 1 - np.exp(-t / 0.006)
        ref = np.std(y[:ns(0.06)]) + 1e-9
        for (dt_, g) in early:
            i = ns(dt_)
            if i < n - 8:
                y[i:i + 8] += g * ref * 5 * (1 if rng.random() < 0.5 else -1) * np.hanning(10)[1:-1]
        if pre > 0:
            y = np.concatenate([np.zeros(ns(pre)), y])[:n]
        y = y / np.sqrt(np.sum(y ** 2) + 1e-12)
        chans.append(y)
    return np.stack(chans) if stereo else chans[0]


_IR_CACHE = {}


def ir_preset(name, stereo=False):
    k = (name, stereo)
    if k in _IR_CACHE:
        return _IR_CACHE[k]
    rng = np.random.default_rng(seed_of('ir_' + name))
    if name == 'room':       # небольшая комната с мебелью
        er = [(rng.uniform(0.002, 0.025), rng.uniform(0.2, 0.6)) for _ in range(10)]
        ir = make_ir(0.42, 0.7, early=er, bands=(1.1, 1.0, 0.6, 0.35), stereo=stereo, rng=rng)
    elif name == 'closet':   # шкаф, очень сухо
        er = [(rng.uniform(0.001, 0.008), rng.uniform(0.3, 0.6)) for _ in range(6)]
        ir = make_ir(0.18, 0.3, early=er, bands=(1.0, 0.8, 0.45, 0.25), stereo=stereo, rng=rng)
    elif name == 'hall':     # коридор / лестница
        er = [(0.011 * i + rng.uniform(-0.001, 0.001), 0.55 * 0.82 ** i) for i in range(1, 12)]
        ir = make_ir(1.15, 1.6, early=er, bands=(1.2, 1.0, 0.7, 0.4), stereo=stereo, rng=rng)
    elif name == 'outdoor':  # улица: редкие отражения от домов, тёмный хвост
        er = [(rng.uniform(0.04, 0.45), rng.uniform(0.15, 0.45)) for _ in range(9)]
        ir = make_ir(0.9, 1.4, early=er, bands=(1.0, 0.8, 0.45, 0.25), stereo=stereo, rng=rng,
                     density_ms=1.2)
    elif name == 'big':      # большой зал для стингеров
        er = [(rng.uniform(0.01, 0.08), rng.uniform(0.2, 0.5)) for _ in range(14)]
        ir = make_ir(2.8, 3.6, pre=0.012, early=er, bands=(1.3, 1.0, 0.7, 0.45), stereo=stereo, rng=rng)
    elif name == 'plate':    # мягкий «музыкальный» хвост
        ir = make_ir(1.8, 2.4, pre=0.008, bands=(1.0, 1.0, 0.85, 0.6), stereo=stereo, rng=rng)
    else:
        raise ValueError(name)
    _IR_CACHE[k] = ir
    return ir


def reverb(x, ir, wet=0.3, dry=1.0, tail=None, loop=False):
    # свёртка с ИХ; loop=True — круговая (петля остаётся бесшовной)
    if isinstance(ir, str):
        ir = ir_preset(ir, stereo=(x.ndim == 2))
    n = x.shape[-1]
    if loop:
        L = n
        X = np.fft.rfft(x, L, axis=-1)
        H = np.fft.rfft(ir[..., :L] if ir.shape[-1] > L else ir, L, axis=-1)
        w = np.fft.irfft(X * H, L, axis=-1)
        return dry * x + wet * w
    if x.ndim == 1 and ir.ndim == 1:
        w = signal.fftconvolve(x, ir)
    elif x.ndim == 2 and ir.ndim == 2:
        w = np.stack([signal.fftconvolve(x[c], ir[c]) for c in range(2)])
    elif x.ndim == 1:
        w = np.stack([signal.fftconvolve(x, ir[c]) for c in range(2)])
        x = np.stack([x, x])
    else:
        w = np.stack([signal.fftconvolve(x[c], ir) for c in range(2)])
    m = w.shape[-1] if tail is None else min(w.shape[-1], n + ns(tail))
    out = np.zeros(w.shape[:-1] + (m,))
    out[..., :n] += dry * x[..., :m]
    out += wet * w[..., :m]
    return out


# ---------- голосовые форманты ----------

VOWELS = {  # F1, F2, F3 (Гц), шёпотные варианты чуть выше
    'a': (850, 1350, 2700), 'o': (560, 950, 2550), 'u': (400, 850, 2450), 'e': (560, 1900, 2650),
    'i': (330, 2300, 3100), 'y': (420, 1600, 2500), 'ae': (700, 1750, 2600),
}


def formant_gain(f, fs, bws, amps):
    g = np.zeros_like(f)
    for F, B, A in zip(fs, bws, amps):
        g += A / (1 + ((f - F) / (B / 2)) ** 2)
    return g


# =====================================================================================
# Общие «инструменты» для звуков: удары, щелчки, скрипы, птицы, музыка
# =====================================================================================

def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def unit(y):
    m = np.max(np.abs(y))
    return y / m if m > 0 else y


def metal_click(rng, f0=2500, dur=0.15, dec=0.03, noise=0.35, width=0.00015):
    n = ns(dur)
    ratios = [1, 1.47, 2.09, 2.76, 3.52, 4.3, 5.4]
    fr = [f0 * r * rng.uniform(0.97, 1.03) for r in ratios]
    dc = [dec * rng.uniform(0.6, 1.2) / (1 + 0.35 * i) for i in range(len(ratios))]
    am = [rng.uniform(0.5, 1.0) / (1 + 0.45 * i) for i in range(len(ratios))]
    return unit(strike(n, fr, dc, am, rng, width=width, noise=noise, noise_tau=0.0015))


def wood_knock(rng, f0=300, dur=0.25, dec=0.06, width=0.0008, noise=0.15):
    n = ns(dur)
    ratios = [1, 1.58, 2.37, 3.1, 4.4, 5.9, 7.3, 9.6]
    fr = [f0 * r * rng.uniform(0.95, 1.05) for r in ratios]
    dc = [dec * rng.uniform(0.7, 1.1) / (1 + 0.55 * i) for i in range(len(ratios))]
    am = [rng.uniform(0.6, 1.0) / (1 + 0.3 * i) for i in range(len(ratios))]
    return unit(strike(n, fr, dc, am, rng, width=width, noise=noise, noise_tau=0.003))


def plastic_click(rng, f0=1800, dur=0.08):
    n = ns(dur)
    fr = [f0 * r * rng.uniform(0.95, 1.05) for r in (1, 1.9, 2.8, 4.1, 5.3)]
    dc = [0.006, 0.005, 0.004, 0.003, 0.0025]
    am = [1, 0.8, 0.6, 0.4, 0.3]
    y = strike(n, fr, dc, am, rng, width=0.0002, noise=0.5, noise_tau=0.0012)
    y += 0.4 * unit(modes(n, [240 * rng.uniform(0.9, 1.1)], [0.012], [1], rng))
    return unit(y)


def thump(rng, dur=0.5, f_hi=110, f_lo=48, dec=0.12, noise=0.6, lpf=260):
    n = ns(dur)
    f = pwexp([(0, f_hi), (dec * 1.5, f_lo), (dur, f_lo * 0.9)], n)
    y = np.sin(phase_of(f, n)) * expdec(n, dec)
    y += noise * lp(white(n, rng), lpf, 2) * expdec(n, dec * 0.4) * 2.5
    return unit(y)


def burst(rng, dur, lo, hi, tau, order=2):
    n = ns(dur)
    return unit(bp(white(n, rng), lo, hi, order) * expdec(n, tau))


def door_ir(rng, dur=0.35, scale=1.0, damp=1.0):
    fr = np.array([88, 143, 229, 318, 452, 610, 845, 1130, 1490, 1960, 2580, 3350, 4300]) * scale
    fr = fr * rng.uniform(0.96, 1.04, len(fr))
    dc = np.array([0.12, 0.10, 0.08, 0.07, 0.06, 0.05, 0.04, 0.035, 0.03, 0.025, 0.02, 0.015, 0.012]) * damp
    am = np.array([1.0, 0.9, 0.8, 0.75, 0.7, 0.6, 0.5, 0.45, 0.4, 0.3, 0.25, 0.2, 0.15]) * rng.uniform(0.7, 1.0, len(fr))
    return modes(ns(dur), fr, dc, am, rng)


def hinge_ir(rng, dur=0.3):
    fr = np.array([930, 1460, 2210, 2950, 3870]) * rng.uniform(0.97, 1.03, 5)
    return modes(ns(dur), fr, [0.09, 0.07, 0.05, 0.04, 0.03], [1, 0.8, 0.6, 0.4, 0.3], rng)


def creak(rng, n, rate, amp, ir, jitter=0.07, width=0.0003, noise=0.03, double=0.0):
    # трение «прилип-сорвался»: неровная череда импульсов через резонатор (дверь, доска, петля)
    rate = arr(rate, n)
    amp = arr(amp, n)
    exc = np.zeros(n)
    t = 0.0
    while True:
        i = int(t * SR)
        if i >= n:
            break
        a = amp[i]
        if a > 1e-3:
            exc[i] += a * rng.uniform(0.55, 1.0)
            if double > 0 and rng.random() < double:   # срыв в два импульса — «хрип»
                j = i + int(SR / max(rate[i], 4.0) * 0.5)
                if j < n:
                    exc[j] += a * rng.uniform(0.2, 0.5)
        per = 1.0 / max(rate[i], 4.0)
        t += per * max(0.3, 1 + jitter * rng.standard_normal())
    exc = np.convolve(exc, click_pulse(width), mode='same')
    y = signal.fftconvolve(exc, ir)[:n]
    if noise > 0:
        y += noise * bp(white(n, rng), 900, 6000) * amp * (np.max(np.abs(y)) + 1e-9)
    return y


def wobble(n, rng, depth=0.15, rate=3.0):
    return 1 + depth * (2 * slow_curve(n, rng, rate) - 1)


def fm_bell(f, n, ratio=3.5, index=4.0, dec=1.2, idx_dec=0.35, att=0.002):
    t = tvec(n)
    I = index * np.exp(-t / idx_dec)
    y = np.sin(TAU * f * t + I * np.sin(TAU * f * ratio * t))
    env = np.exp(-t / dec) * np.minimum(1, t / max(att, 1e-4))
    return y * env


def epiano(f, n, vel=1.0, dec=1.1):
    # DX-подобное электропиано: тело + металлический «зубец» на атаке
    t = tvec(n)
    body = np.sin(TAU * f * t + (1.6 * vel) * np.exp(-t / 0.5) * np.sin(TAU * f * t))
    tine = np.sin(TAU * f * t + 1.2 * vel * np.exp(-t / 0.02) * np.sin(TAU * f * 14 * t)) * np.exp(-t / 0.08)
    env = np.exp(-t / dec) * np.minimum(1, t / 0.002)
    return (body * 0.8 + 0.35 * tine) * env


def brass(f, n, rng, att=0.03, rel=0.12, cut_pk=3200, cut_sus=1100, cut_dec=0.35, detune=7, voices=3,
          sus=0.8, vib=0.0, loop=False):
    # «медь» на пилах: фильтр раскрывается с атакой и опускается
    y = np.zeros(n)
    for k in range(voices):
        d = (k - (voices - 1) / 2) * detune
        y += saw(f * 2 ** (d / 1200) * (1 + vib * np.sin(TAU * 5.2 * tvec(n))), n, rng.random())
    y /= voices
    t = tvec(n)
    env_a = np.minimum(1, t / att)
    cut = 220 + (cut_sus + (cut_pk - cut_sus) * np.exp(-t / cut_dec) - 220) * env_a ** 0.7
    y = tvf(y, 'lpf', np.minimum(cut, f * 18), Q=1.1, poles=4)
    env = env_a * (sus + (1 - sus) * np.exp(-t / 0.15))
    r = ns(rel)
    if n > r:
        env[-r:] *= np.linspace(1, 0, r) ** 2
    return y * env


def pad(freqs, n, rng, cut=1400, att=0.6, rel=1.0, detune=9, loop=False):
    y = np.zeros(n)
    for f in freqs:
        for d in (-detune, 0, detune):
            y += saw(f * 2 ** (d / 1200), n, rng.random(), loop=loop)
    y = lp(y / (3 * len(freqs)), cut, 2)
    t = tvec(n)
    env = np.minimum(1, t / att)
    r = ns(rel)
    if n > r and not loop:
        env[-r:] *= np.linspace(1, 0, r) ** 2
    return y * env


def bird(rng, kind, f0=None):
    # синтетические птицы: короткие FM-свисты разных «видов»
    if kind == 'tweet':
        d = rng.uniform(0.05, 0.1)
        n = ns(d)
        f1 = f0 or rng.uniform(3600, 5200)
        f = pwexp([(0, f1 * 0.85), (d * 0.3, f1 * 1.25), (d, f1 * 0.7)], n)
        env = np.sin(np.pi * np.arange(n) / n) ** 1.5
    elif kind == 'whistle':
        d = rng.uniform(0.22, 0.38)
        n = ns(d)
        f1 = f0 or rng.uniform(2600, 3800)
        f = f1 * (1 + 0.025 * np.sin(TAU * 11 * tvec(n))) * pw([(0, 1.02), (d, 0.97)], n)
        env = pw([(0, 0), (0.03, 1), (d - 0.05, 0.85), (d, 0)], n)
    elif kind == 'trill':
        k = rng.integers(8, 18)
        per = rng.uniform(0.04, 0.055)
        n = ns(per * k + 0.05)
        f1 = f0 or rng.uniform(4000, 5600)
        f = np.full(n, f1)
        env = np.zeros(n)
        for i in range(k):
            a, b = ns(i * per), ns(i * per + per * 0.6)
            f[a:b] = np.linspace(f1 * 1.12, f1 * 0.9, b - a)
            env[a:b] = np.sin(np.linspace(0, np.pi, b - a)) * (0.7 + 0.3 * np.sin(np.pi * i / k))
    else:  # warble
        d = rng.uniform(0.3, 0.55)
        n = ns(d)
        f1 = f0 or rng.uniform(2400, 3600)
        t = tvec(n)
        f = f1 * pw([(0, 0.9), (d * 0.5, 1.15), (d, 0.95)], n) + 420 * np.sin(TAU * rng.uniform(22, 32) * t)
        env = np.sin(np.pi * np.arange(n) / n) ** 0.8
    ph = phase_of(f, n)
    y = (np.sin(ph) + 0.12 * np.sin(2 * ph) + 0.04 * np.sin(3 * ph)) * env
    return y


def bird_phrase(rng, kind=None):
    kind = kind or rng.choice(['tweet', 'tweet', 'whistle', 'trill', 'warble'])
    parts = []
    if kind == 'tweet':
        f0 = rng.uniform(3600, 5200)
        for _ in range(rng.integers(3, 8)):
            parts.append(bird(rng, 'tweet', f0 * rng.uniform(0.94, 1.06)))
            parts.append(np.zeros(ns(rng.uniform(0.04, 0.12))))
    elif kind == 'whistle':
        f0 = rng.uniform(2800, 3800)
        parts += [bird(rng, 'whistle', f0), np.zeros(ns(0.08)), bird(rng, 'whistle', f0 * rng.uniform(0.82, 0.9))]
    elif kind == 'trill':
        parts.append(bird(rng, 'trill'))
    else:
        for _ in range(rng.integers(1, 3)):
            parts.append(bird(rng, 'warble'))
            parts.append(np.zeros(ns(0.07)))
    return np.concatenate(parts)


def dog_bark(rng, f0=None, dur=None):
    dur = dur or rng.uniform(0.16, 0.24)
    f0 = f0 or rng.uniform(430, 560)
    n = ns(dur)
    f = pwexp([(0, f0 * 0.75), (0.025, f0 * 1.15), (dur, f0 * 0.55)], n)
    f = f * (1 + 0.03 * lp(white(n, rng), 60))
    src = saw(f, n) + 0.35 * bp(white(n, rng), 300, 5000)
    y = reson(src, 620, 3.0) + 0.7 * reson(src, 1350, 5.0) + 0.35 * reson(src, 2700, 6.0)
    env = pw([(0, 0), (0.008, 1), (dur * 0.35, 0.75), (dur, 0)], n)
    rough = 1 + 0.4 * np.sin(TAU * rng.uniform(28, 40) * tvec(n))
    return unit(sat(unit(y * env * rough), 1.5))


def cricket_chirp(rng, f, syll=3, slen=0.014, sgap=0.017):
    n = ns(syll * (slen + sgap) + 0.01)
    y = np.zeros(n)
    m = ns(slen)
    t = tvec(m)
    for s in range(syll):
        ff = f * (1 - 0.015 * s) * pw([(0, 1.0), (slen, 0.985)], m)
        tone = np.sin(phase_of(ff, m)) + 0.08 * np.sin(2 * phase_of(ff, m))
        e = np.sin(np.pi * np.arange(m) / m) ** 1.2 * (0.8 + 0.2 * (s == 1))
        mix_into(y, tone * e, s * (slen + sgap))
    return y


def snare(rng, dur=0.35, tone=190, gate=0.18):
    n = ns(dur)
    body = np.sin(phase_of(pwexp([(0, tone * 1.4), (0.03, tone)], n), n)) * expdec(n, 0.06)
    nz = bp(white(n, rng), 1500, 9000) * expdec(n, 0.09)
    y = 0.6 * body + 0.8 * nz
    y = reverb(y, 'room', 0.6, tail=0)
    g = np.ones(n)
    g[ns(gate):] = 0
    g = ndimage.uniform_filter1d(g, ns(0.01))
    return unit(y * g)


def kick(rng, dur=0.35):
    n = ns(dur)
    f = pwexp([(0, 140), (0.04, 62), (dur, 45)], n)
    y = np.sin(phase_of(f, n)) * expdec(n, 0.12)
    y += 0.3 * metal_click(rng, 3000, dur)[:n] * expdec(n, 0.003)
    return unit(y)


def hat(rng, dur=0.08, tau=0.018):
    n = ns(dur)
    return unit(hp(white(n, rng), 7000, 2) * expdec(n, tau))


def timpani(rng, f=73.4, dur=1.5, vel=1.0):
    n = ns(dur)
    t = tvec(n)
    ratios = [1, 1.5, 1.98, 2.44, 2.94]
    y = sum(np.sin(TAU * f * r * t * (1 + 0.01 * np.exp(-t / 0.05))) * np.exp(-t / (0.6 / (1 + 0.6 * i))) / (1 + i)
            for i, r in enumerate(ratios))
    y += 0.4 * lp(white(n, rng), 900) * expdec(n, 0.02)
    return unit(y) * vel


def crash(rng, dur=2.5):
    n = ns(dur)
    y = hp(white(n, rng), 3500, 2) * expdec(n, 0.7)
    y += 0.5 * bp(white(n, rng), 5000, 12000) * expdec(n, 0.25)
    return unit(y)


def tv_speaker(x, drive=1.4):
    # окраска маленького динамика ЭЛТ-телевизора
    y = hp(x, 140, 2)
    y = lp(y, 7000, 2)
    y = eq(y, [('peak', 1150, 1.2, 3.5), ('peak', 3200, 2.0, 2.5), ('peak', 420, 1.0, -2.0)])
    return sat(unit(y), drive)


# =====================================================================================
# ЗВУКИ. Каждая функция получает rng и возвращает моно (n,) или стерео (2, n) массив.
# Нормализация до -1 dBFS, фейды и запись в .ogg делаются снаружи.
# =====================================================================================

SOUNDS = []


def snd(key, desc, vol, loop=False, stereo=False, q=5, roll=None, note=''):
    def deco(fn):
        SOUNDS.append(dict(key=key, fn=fn, desc=desc, vol=vol, loop=loop, stereo=stereo, q=q,
                           roll=roll, note=note))
        return fn
    return deco


# ---------- телевизор / оповещение ----------

def afsk_burst(data, rng):
    # SAME-подобная посылка: 520.83 бод, «1» = 2083.3 Гц, «0» = 1562.5 Гц, младший бит первым, фаза непрерывна
    baud = 520.8333333
    bits = []
    for byte in data:
        for k in range(8):
            bits.append((byte >> k) & 1)
    nb = len(bits)
    n = int(math.ceil(nb / baud * SR))
    idx = np.minimum((np.arange(n) * baud / SR).astype(int), nb - 1)
    f = np.where(np.array(bits)[idx] == 1, 2083.333, 1562.5)
    y = np.sin(phase_of(f, n))
    return fade(y, 0.002, 0.002)


def same_noise_bytes(rng, count):
    # «случайный» заголовок: похож на SAME, но не декодируется (без ZCZC) — безопасно для приёмников
    alphabet = b'ABCDEFGHJKLMPQRSTUVWXY0123456789-+/'
    while True:
        b = bytes(int(v) for v in rng.choice(list(alphabet), count))
        if b'ZCZC' not in b and b'NNNN' not in b:
            return b


@snd('EasTone', 'Сигнал EAS: 3 AFSK-заголовка (520.83 бод, 2083.3/1562.5 Гц), 8 с двухтонального сигнала '
     '853+960 Гц, 3 пакета EOM. Полоса 300–3400 Гц, лёгкое шипение. Заголовок нарочно «мусорный» (не декодируется).',
     0.7, roll=(10, 90))
def s_eas_tone(rng):
    pre = bytes([0xAB] * 16)
    header = pre + same_noise_bytes(rng, 52)
    eom = pre + b'NNNN'
    parts = [(0.35, None)]
    hb = afsk_burst(header, rng)
    eb = afsk_burst(eom, rng)
    segs = []
    t = 0.35
    for _ in range(3):
        segs.append((t, hb * 0.92))
        t += len(hb) / SR + 1.0
    nt = ns(8.0)
    tt = tvec(nt)
    tone = 0.5 * np.sin(TAU * 853 * tt) + 0.5 * np.sin(TAU * 960 * tt)
    tone = fade(tone, 0.004, 0.004)
    segs.append((t, tone))
    t += 8.0 + 1.0
    for i in range(3):
        segs.append((t, eb * 0.92))
        t += len(eb) / SR + 1.0
    total = t - 1.0 + 0.6
    n = ns(total)
    y = np.zeros(n)
    for st, s in segs:
        mix_into(y, s, st)
    # тракт ТВ: полоса, лёгкая компрессия/насыщение, шипение и чуть фона
    y = bp(y, 300, 3400, 3)
    y = sat(y * 0.9, 1.3)
    hiss = 0.018 * hp(pink(n, rng), 1200) + 0.006 * white(n, rng)
    hum = 0.006 * (np.sin(TAU * 59.94 * tvec(n)) + 0.5 * np.sin(TAU * 179.82 * tvec(n)))
    y = y + hiss + hum
    return y


def tv_bed(rng, n, loop=True):
    # общий «эфирный» шум: полосовой шум + кадровое жужжание 59.94 Гц + писк строчника
    t = tvec(n)
    nz = colored(n, rng, -1.0, lo=180, hi=7000)
    buzz = loop_phase(59.94, n)
    frame = (np.mod(buzz / TAU, 1.0) < 0.08).astype(float)
    frame = circ(frame - frame.mean(), lambda v: bp(v, 100, 3000, 2), ns(0.2)) if loop else bp(frame, 100, 3000)
    whine = np.sin(loop_phase(15734.0, n))
    return nz, unit(frame), whine


@snd('EasNoise', 'Фон эфира во время оповещения: помехи, кадровое жужжание, провалы сигнала, треск. Петля 30 с.',
     0.35, loop=True, roll=(10, 80))
def s_eas_noise(rng):
    n = ns(30.0)
    nz, frame, whine = tv_bed(rng, n)
    level = slow_curve(n, rng, 0.35, 0.35, 1.0)
    # провалы сигнала: короткие «дыры» и всплески
    drops = np.ones(n)
    for _ in range(6):
        c = rng.uniform(0, 30)
        w = rng.uniform(0.15, 0.6)
        d = np.exp(-0.5 * (((tvec(n) - c + 15) % 30 - 15) / (w / 2)) ** 2)
        drops *= 1 - 0.85 * d
    hiss = nz * level * drops
    crack = circ(dust(n, rng, 35, 0.4), lambda v: hp(v, 2500, 2), ns(0.05))
    crack *= slow_curve(n, rng, 0.8, 0.2, 1.0)
    hum = np.sin(loop_phase(59.94, n)) + 0.5 * np.sin(loop_phase(119.88, n)) + 0.3 * np.sin(loop_phase(179.82, n))
    y = 0.75 * hiss + 0.25 * frame * level + 1.2 * crack + 0.12 * hum * (1.4 - drops) + 0.012 * whine
    y = circ(y, lambda v: eq(v, [('peak', 1150, 1.0, 3.0), ('lowshelf', 200, 0.7, -4)]), ns(0.3))
    return sat(unit(y), 1.2)


@snd('Static', 'ТВ-«снег»: белый шум через динамик телевизора с кадровым гулом. Петля 10 с.', 0.35, loop=True,
     roll=(8, 60))
def s_static(rng):
    n = ns(10.0)
    nz, frame, whine = tv_bed(rng, n)
    am = 1 + 0.12 * np.sin(loop_phase(59.94, n)) + 0.08 * (2 * slow_curve(n, rng, 2.0) - 1)
    y = nz * am + 0.18 * frame + 0.01 * whine
    y = circ(y, lambda v: eq(lp(hp(v, 150), 7500), [('peak', 1150, 1.2, 3), ('peak', 3200, 2, 2)]), ns(0.3))
    return sat(unit(y), 1.3)


@snd('TvNews', 'Заставка местных новостей 90-х: медь, литавры, «тикер»-арпеджио, бас, гейтованный малый. '
     '128 BPM, 16 тактов = ровно 30 с, бесшовная петля. Окрашено как динамик ТВ.', 0.45, loop=True, roll=(10, 70))
def s_tv_news(rng):
    bpm = 128.0
    beat = 60.0 / bpm
    bars = 16
    L = bars * 4 * beat
    n = ns(L)
    y = np.zeros(n)

    def at(bar, b):
        return ((bar - 1) * 4 + b) * beat

    D, Bm, G, A = [62, 66, 69], [59, 62, 66], [55, 59, 62], [57, 61, 64]
    chords = [D, D, Bm, Bm, G, G, A, A, D, D, Bm, Bm, G, G, [57, 62, 64], A]
    roots = [50, 50, 47, 47, 43, 43, 45, 45, 50, 50, 47, 47, 43, 43, 45, 45]
    # пэд (струнные)
    for bar in range(1, bars + 1):
        ch = chords[bar - 1]
        m = ns(4 * beat + 0.6)
        p = pad([mtof(x) for x in ch] + [mtof(ch[0] + 12)], m, rng, cut=1800, att=0.25, rel=0.5, detune=10)
        mix_into(y, p * 0.22, at(bar, 0), wrap=True)
    # бас восьмыми
    for bar in range(1, bars + 1):
        r = roots[bar - 1]
        for k in range(8):
            nn = r if k % 2 == 0 else r + 12
            if k == 7 and bar % 2 == 0:
                nn = r + 7
            m = ns(beat * 0.48)
            f = mtof(nn - 12)
            v = saw(f, m) * 0.6 + np.sin(phase_of(f, m)) * 0.8
            v = lp(v, 700) * pw([(0, 0), (0.004, 1), (beat * 0.4, 0.6), (beat * 0.48, 0)], m)
            mix_into(y, v * 0.38, at(bar, k * 0.5), wrap=True)
    # тикер 16-ми (FM-щипок) — главный «новостной» мотив
    for bar in range(1, bars + 1):
        ch = chords[bar - 1]
        tones = [ch[0] + 12, ch[2] + 12, ch[1] + 24, ch[2] + 12]
        for k in range(16):
            nn = tones[k % 4] if k % 8 < 6 else tones[(k + 1) % 4] + 12
            m = ns(beat * 0.3)
            v = fm_bell(mtof(nn), m, ratio=2.0, index=1.6, dec=0.07, idx_dec=0.03)
            acc = 1.0 if k % 4 == 0 else 0.6
            g = 0.10 if bar <= 2 else 0.16
            mix_into(y, v * acc * g, at(bar, k * 0.25), wrap=True)
    # барабаны
    K, S, H = kick(rng), snare(rng), hat(rng)
    for bar in range(1, bars + 1):
        for b in (0, 2, 2.5) if bar % 4 == 0 else (0, 2):
            mix_into(y, K * 0.55, at(bar, b), wrap=True)
        for b in (1, 3):
            mix_into(y, S * 0.32, at(bar, b), wrap=True)
        for k in range(8):
            mix_into(y, H * (0.09 if k % 2 else 0.05), at(bar, k * 0.5), wrap=True)
    for bar in (1, 9):
        mix_into(y, crash(rng) * 0.28, at(bar, 0), wrap=True)
    # литавры: удар на «раз» и дробь в последнем такте (ведёт обратно в начало петли)
    mix_into(y, timpani(rng, mtof(38), 1.8) * 0.55, at(1, 0), wrap=True)
    mix_into(y, timpani(rng, mtof(38), 1.8) * 0.4, at(9, 0), wrap=True)
    for k in range(16):
        mix_into(y, timpani(rng, mtof(33), 0.5, 0.15 + 0.35 * k / 15), at(16, k * 0.25), wrap=True)
    # медь: фанфара (оригинальная мелодия) в тактах 1–2 и её эхо в 9–10, стэбы
    fan = [(0, 1.5, 74), (1.5, 0.5, 69), (2, 0.5, 74), (2.5, 0.5, 76), (3, 1, 78),
           (4, 2, 81), (6, 0.5, 79), (6.5, 0.5, 78), (7, 1, 76)]
    for bar0, gain in ((1, 0.30), (9, 0.18)):
        for b, d, nn in fan:
            m = ns(d * beat + 0.15)
            v = brass(mtof(nn), m, rng, att=0.025, rel=0.1, cut_pk=4200, cut_sus=1800) + \
                0.5 * brass(mtof(nn - 12), m, rng, att=0.03, rel=0.1, cut_pk=2500, cut_sus=1000)
            mix_into(y, v * gain, at(bar0, b), wrap=True)
    for bar in (3, 5, 7, 11, 13):
        ch = chords[bar - 1]
        for b in (0, 1.5):
            m = ns(beat * 0.45)
            v = sum(brass(mtof(x), m, rng, att=0.01, rel=0.06, cut_pk=3000, cut_sus=1200, voices=2) for x in ch)
            mix_into(y, v * 0.10, at(bar, b), wrap=True)
    for k, b in enumerate((0, 1, 2, 3, 3.5)):     # нарастание в такте 16
        m = ns(beat * 0.45)
        v = sum(brass(mtof(x), m, rng, att=0.01, rel=0.06, voices=2) for x in [57, 61, 64, 69])
        mix_into(y, v * (0.07 + 0.03 * k), at(16, b), wrap=True)
    y = reverb(y, 'plate', 0.18, loop=True)
    y = circ(y, lambda v: tv_speaker(v, 1.3), ns(0.2))
    y = compress(y, -14, 3.0, 0.02)
    return np.roll(y, ns(beat))   # файл начинается с затакта (дробь литавр) — стык петли не на ударе


# ---------- двери ----------

@snd('DoorOpen', 'Дверь открывается: щелчок защёлки и долгий скрип (синтез трения через резонансы полотна и петли).',
     0.7, roll=(8, 70))
def s_door_open(rng):
    n = ns(2.3)
    y = np.zeros(n)
    mix_into(y, metal_click(rng, 2400, 0.15, 0.025) * 0.5, 0.02)
    mix_into(y, wood_knock(rng, 420, 0.2, 0.03) * 0.25, 0.022)
    mix_into(y, metal_click(rng, 3100, 0.1, 0.015) * 0.3, 0.15)
    cn = ns(1.75)
    ir = door_ir(rng) + 0.5 * hinge_ir(rng, 0.35)
    rate = pwexp([(0, 45), (0.2, 95), (0.55, 210), (0.8, 300), (1.05, 240), (1.35, 150), (1.75, 70)], cn)
    rate *= wobble(cn, rng, 0.12, 6.0)
    amp = pw([(0, 0), (0.12, 0.5), (0.5, 1.0), (1.0, 0.9), (1.45, 0.55), (1.75, 0)], cn) * wobble(cn, rng, 0.3, 9)
    c = creak(rng, cn, rate, amp, ir, jitter=0.06, double=0.15)
    c2 = creak(rng, cn, rate * 3.02, amp * pw([(0, 0), (0.5, 0), (0.75, 0.5), (1.1, 0.2), (1.75, 0)], cn),
               hinge_ir(rng), jitter=0.03)
    mix_into(y, unit(c) * 0.8 + unit(c2) * 0.18, 0.18)
    air = lp(white(n, rng), 300) * pw([(0, 0), (0.6, 0), (1.2, 1), (2.0, 0)], n)
    y += 0.05 * unit(air)
    return reverb(y, 'room', 0.25, tail=0.5)


@snd('DoorClose', 'Дверь закрывается: короткий скрип, глухой удар полотна о коробку и щелчок защёлки.', 0.7,
     roll=(8, 70))
def s_door_close(rng):
    n = ns(1.5)
    y = np.zeros(n)
    cn = ns(0.42)
    rate = pwexp([(0, 160), (0.25, 120), (0.42, 70)], cn) * wobble(cn, rng, 0.1, 8)
    amp = pw([(0, 0), (0.08, 0.7), (0.3, 0.6), (0.42, 0)], cn)
    mix_into(y, unit(creak(rng, cn, rate, amp, door_ir(rng), double=0.2)) * 0.35, 0.0)
    hit = 0.45
    body = signal.fftconvolve(np.convolve(np.r_[1.0], click_pulse(0.0025)), door_ir(rng, 0.5, 0.9, 1.4))
    mix_into(y, unit(body) * 0.9, hit)
    mix_into(y, thump(rng, 0.5, 120, 60, 0.07) * 0.7, hit)
    mix_into(y, metal_click(rng, 2700, 0.15, 0.03) * 0.55, hit + 0.004)
    for k in range(4):
        mix_into(y, metal_click(rng, rng.uniform(2200, 3600), 0.08, 0.012) * 0.12 / (k + 1), hit + 0.03 + 0.025 * k)
    return reverb(sat(y, 1.5), 'room', 0.3, tail=0.5)


@snd('DoorLock', 'Замок: короткий скрежет ригеля и двойной металлический щелчок.', 0.6, roll=(6, 40))
def s_door_lock(rng):
    n = ns(0.6)
    y = np.zeros(n)
    sl = bp(white(ns(0.07), rng), 2000, 7000) * pw([(0, 0), (0.05, 1), (0.07, 0)], ns(0.07))
    mix_into(y, unit(sl) * 0.25, 0.01)
    mix_into(y, metal_click(rng, 1900, 0.2, 0.04) * 0.9, 0.08)
    mix_into(y, wood_knock(rng, 520, 0.15, 0.02) * 0.35, 0.081)
    mix_into(y, metal_click(rng, 3300, 0.1, 0.02) * 0.45, 0.15)
    return reverb(y, 'room', 0.22, tail=0.3)


@snd('DoorBash', 'Тяжёлый удар в деревянную дверь: низкий «бум» полотна, дребезг петель и защёлки.', 0.9,
     roll=(12, 140))
def s_door_bash(rng):
    n = ns(1.6)
    y = np.zeros(n)
    ex = np.zeros(ns(0.02))
    ex[0] = 1
    ex = np.convolve(ex, click_pulse(0.004))
    body = signal.fftconvolve(ex, door_ir(rng, 0.7, 0.8, 2.0))[:n]
    mix_into(y, unit(body) * 1.0, 0.01)
    mix_into(y, thump(rng, 0.8, 100, 42, 0.14, noise=0.8) * 1.0, 0.01)
    mix_into(y, wood_knock(rng, 260, 0.3, 0.05, width=0.002) * 0.45, 0.012)
    t = 0.03
    for k in range(9):
        mix_into(y, metal_click(rng, rng.uniform(1800, 4200), 0.07, 0.01) * 0.28 * 0.8 ** k, t)
        t += rng.uniform(0.012, 0.035)
    cn = ns(0.35)
    c = creak(rng, cn, pwexp([(0, 40), (0.35, 25)], cn), pw([(0, 0.8), (0.35, 0)], cn), door_ir(rng), jitter=0.2)
    mix_into(y, unit(c) * 0.15, 0.06)
    y = sat(unit(y) * 1.2, 2.0)
    return reverb(y, 'hall', 0.22, tail=0.8)


@snd('DoorBreak', 'Дверь выбита: мощный удар, треск древесины с щепками, звон петли, падающие обломки.', 1.0,
     roll=(15, 160))
def s_door_break(rng):
    n = ns(3.0)
    y = np.zeros(n)
    ex = np.convolve(np.r_[1.0], click_pulse(0.0025))
    mix_into(y, unit(signal.fftconvolve(ex, door_ir(rng, 0.8, 0.75, 2.5))) * 1.0, 0.0)
    mix_into(y, thump(rng, 1.0, 120, 38, 0.2, noise=1.0) * 1.0, 0.0)
    # треск: зернистый хруст + щепки
    cr_n = ns(0.5)
    crunch = dust(cr_n, rng, 2500, 0.5) * expdec(cr_n, 0.12)
    crunch = bp(crunch, 600, 5000) + 0.5 * reson(crunch, 1300, 2) + 0.3 * reson(crunch, 2700, 3)
    mix_into(y, unit(crunch) * 0.7, 0.004)
    mix_into(y, burst(rng, 0.3, 300, 6000, 0.05) * 0.8, 0.0)
    for _ in range(140):
        tt = rng.exponential(0.18)
        if tt > 1.2:
            continue
        f = np.exp(rng.uniform(np.log(900), np.log(7000)))
        m = ns(rng.uniform(0.005, 0.03))
        s = bp(white(m, rng), f * 0.7, min(f * 1.4, 20000)) * expdec(m, m / SR / 4)
        s += 0.5 * modes(m, [f, f * 1.7], [0.006, 0.004], [1, 0.5], rng)
        mix_into(y, unit(s) * rng.uniform(0.1, 0.5) * np.exp(-tt / 0.4), 0.01 + tt)
    # петля/шуруп со звоном
    mix_into(y, unit(modes(ns(0.8), [1870, 3240, 4410, 6020], [0.25, 0.18, 0.12, 0.08], [1, 0.6, 0.5, 0.3], rng)) * 0.12, 0.03)
    # дверь бьётся о стену и обломки падают
    mix_into(y, thump(rng, 0.6, 90, 50, 0.1) * 0.55, 0.32)
    mix_into(y, unit(signal.fftconvolve(ex, door_ir(rng, 0.5, 0.9, 1.5))) * 0.5, 0.32)
    t = 0.45
    for k in range(16):
        t += rng.exponential(0.09)
        if t > 2.3:
            break
        mix_into(y, wood_knock(rng, rng.uniform(250, 900), 0.2, 0.03, width=0.001) * 0.35 * np.exp(-(t - 0.45) / 0.8), t)
    y = sat(unit(y) * 1.3, 2.2)
    return reverb(y, 'hall', 0.3, tail=1.0)


@snd('GlassBreak', 'Разбитое окно: хлопок трещины, шумовой всплеск и сотни коротких звонких осколков с падением на пол.',
     0.9, roll=(12, 140))
def s_glass_break(rng):
    n = ns(2.6)
    y = np.zeros(n)
    mix_into(y, burst(rng, 0.05, 400, 3000, 0.01) * 0.9, 0.0)
    mix_into(y, burst(rng, 0.4, 1500, 14000, 0.07) * 0.8, 0.002)
    mix_into(y, burst(rng, 0.6, 3000, 12000, 0.18) * 0.35, 0.01)
    mix_into(y, thump(rng, 0.3, 160, 90, 0.04, noise=0.3) * 0.4, 0.0)

    def shard(f, amp, dec):
        m = ns(dec * 6)
        fr = [f, f * rng.uniform(2.1, 2.5), f * rng.uniform(3.6, 4.4)]
        s = strike(m, fr, [dec, dec * 0.7, dec * 0.5], [1, 0.5, 0.3], rng, width=0.00008, noise=0.6,
                   noise_tau=0.0008)
        return unit(s) * amp

    for _ in range(90):   # первые осколки
        tt = rng.exponential(0.035)
        f = np.exp(rng.uniform(np.log(2500), np.log(11000)))
        mix_into(y, shard(f, rng.uniform(0.15, 0.6), rng.uniform(0.01, 0.06)), tt)
    for _ in range(170):  # падение на пол
        tt = 0.12 + rng.gamma(2.0, 0.22)
        if tt > 2.2:
            continue
        f = np.exp(rng.uniform(np.log(2000), np.log(9500)))
        a = rng.uniform(0.05, 0.4) * np.exp(-(tt - 0.12) / 0.7)
        mix_into(y, shard(f, a, rng.uniform(0.008, 0.05)), tt)
    return reverb(y, 'room', 0.22, tail=0.6)


@snd('FlashlightClick', 'Щелчок кнопки фонарика: пластик + пружинка.', 0.5, roll=(4, 25))
def s_flash(rng):
    n = ns(0.25)
    y = np.zeros(n)
    mix_into(y, plastic_click(rng, 1700) * 0.9, 0.005)
    mix_into(y, plastic_click(rng, 2300) * 0.6, 0.035)
    mix_into(y, unit(modes(ns(0.1), [5400, 7900], [0.03, 0.02], [1, 0.5], rng)) * 0.06, 0.036)
    return reverb(y, 'closet', 0.15, tail=0.1)


# ---------- предметы и действия ----------

@snd('ApplePick', 'Сорвать яблоко: шелест листвы, щелчок черенка, мягкий шлепок в ладонь.', 0.6, roll=(6, 50))
def s_apple(rng):
    n = ns(0.75)
    y = np.zeros(n)
    rn = ns(0.5)
    rust = hp(white(rn, rng), 1500) * (0.3 + dust(rn, rng, 300, 0.3) ** 2 * 3)
    rust = lp(rust, 9000) * pw([(0, 0), (0.05, 0.9), (0.15, 0.5), (0.25, 0.9), (0.5, 0)], rn)
    mix_into(y, unit(rust) * 0.35, 0.0)
    snap = burst(rng, 0.03, 2000, 9000, 0.003) * 0.8 + 0.5 * unit(modes(ns(0.03), [1900, 3200], [0.008, 0.006], [1, 0.6], rng))
    mix_into(y, unit(snap) * 0.8, 0.18)
    mix_into(y, unit(modes(ns(0.1), [230], [0.02], [1], rng)) * 0.3, 0.181)
    mix_into(y, thump(rng, 0.25, 180, 110, 0.03, noise=1.2, lpf=500) * 0.45, 0.3)
    return reverb(y, 'outdoor', 0.1, tail=0.3)


@snd('Coin', 'Монеты: звон двух монет с отскоком и короткий колокольчик кассы — продажа/награда.', 0.6, roll=(6, 40))
def s_coin(rng):
    n = ns(1.9)
    y = np.zeros(n)
    ratios = [1, 1.594, 2.136, 2.296, 2.653, 2.918, 3.501, 4.1]
    for t0, f0, a in ((0.0, 2050, 1.0), (0.06, 2480, 0.7), (0.17, 2050, 0.35), (0.25, 2480, 0.2)):
        fr = [f0 * r * rng.uniform(0.995, 1.005) for r in ratios]
        dc = [rng.uniform(0.15, 0.45) / (1 + 0.25 * i) for i in range(len(ratios))]
        am = [rng.uniform(0.4, 1.0) / (1 + 0.2 * i) for i in range(len(ratios))]
        mix_into(y, unit(strike(ns(1.6), fr, dc, am, rng, width=0.0001, noise=0.4, noise_tau=0.001)) * a, t0)
    mix_into(y, unit(fm_bell(1568, ns(0.8), 3.0, 1.5, 0.35, 0.1)) * 0.25, 0.02)
    mix_into(y, unit(fm_bell(2349, ns(0.8), 3.0, 1.2, 0.3, 0.1)) * 0.2, 0.09)
    return reverb(y, 'room', 0.18, tail=0.3)


def relay_clunk(rng):
    n = ns(0.4)
    y = np.zeros(n)
    mix_into(y, unit(modes(n, [110, 190, 420, 760], [0.09, 0.06, 0.04, 0.02], [1, 0.8, 0.6, 0.4], rng)) * 0.9, 0)
    mix_into(y, metal_click(rng, 2900, 0.15, 0.02) * 0.6, 0.001)
    bz = pulse(120, ns(0.06), 0.2) * expdec(ns(0.06), 0.02)
    mix_into(y, unit(bp(bz, 200, 4000)) * 0.25, 0.0)
    return unit(sat(y, 1.5))


def mains_hum(f, n, harm=(1, 0.7, 0.45, 0.5, 0.25, 0.2, 0.12, 0.1)):
    ph = phase_of(f, n)
    return sum(a * np.sin((k + 1) * ph) for k, a in enumerate(harm))


@snd('PowerDown', 'Отключение света: щелчок реле, гул 60 Гц падает и глохнет, «уходящий» писк электроники.', 0.8,
     roll=(10, 90))
def s_power_down(rng):
    n = ns(3.4)
    y = np.zeros(n)
    mix_into(y, relay_clunk(rng), 0.02)
    f = pwexp([(0, 60), (0.15, 58), (1.2, 34), (2.8, 14)], n)
    hum = mains_hum(f, n) * pw([(0, 0), (0.01, 1), (0.6, 0.8), (2.6, 0.2), (3.2, 0)], n)
    y += 0.5 * unit(sat(hum, 1.5))
    wf = pwexp([(0, 9000), (0.3, 6000), (2.2, 600)], n)
    whine = np.sin(phase_of(wf, n)) * pw([(0, 0), (0.05, 1), (1.6, 0.3), (2.3, 0)], n)
    y += 0.07 * whine
    fl = bp(pulse(120, n, 0.1), 300, 6000) * pw([(0, 1), (0.08, 0.6), (0.2, 0)], n)
    y += 0.12 * unit(fl)
    return reverb(y, 'room', 0.2, tail=0.4)


@snd('PowerUp', 'Включение света: щелчок реле, гул растёт до 60 Гц, стартёры ламп щёлкают, ровное жужжание.', 0.8,
     roll=(10, 90))
def s_power_up(rng):
    n = ns(3.4)
    y = np.zeros(n)
    mix_into(y, relay_clunk(rng), 0.02)
    f = pwexp([(0, 22), (0.8, 57), (1.2, 60), (3.4, 60)], n)
    hum = mains_hum(f, n) * pw([(0, 0), (0.05, 0.4), (0.9, 1), (2.6, 0.9), (3.4, 0)], n)
    y += 0.45 * unit(sat(hum, 1.5))
    wf = pwexp([(0, 700), (1.4, 8500), (3.4, 9000)], n)
    y += 0.05 * np.sin(phase_of(wf, n)) * pw([(0, 0), (0.3, 1), (1.6, 0.6), (3.0, 0.3), (3.4, 0)], n)
    buzz = bp(pulse(120, n, 0.12), 400, 7000)
    gate = np.zeros(n)
    for t0, d in ((0.45, 0.06), (0.72, 0.09), (1.0, 0.05), (1.18, 2.2)):
        gate[ns(t0):ns(t0 + d)] = 1
        mix_into(y, metal_click(rng, rng.uniform(3500, 5000), 0.05, 0.01) * 0.15, t0)
    gate = ndimage.uniform_filter1d(gate, ns(0.004)) * pw([(0, 1), (2.8, 1), (3.4, 0)], n)
    y += 0.1 * unit(buzz) * gate
    return reverb(y, 'room', 0.2, tail=0.4)


@snd('Fuse', 'Предохранитель/щиток: щелчок, искрящий «дзз» дуги, хлопок и короткий гул.', 0.7, roll=(8, 60))
def s_fuse(rng):
    n = ns(1.4)
    y = np.zeros(n)
    mix_into(y, wood_knock(rng, 480, 0.15, 0.02) * 0.5, 0.03)
    mix_into(y, metal_click(rng, 2600, 0.12, 0.025) * 0.6, 0.032)
    an = ns(0.22)
    arc = pulse(120 * wobble(an, rng, 0.1, 30), an, 0.15) + 1.5 * dust(an, rng, 900, 0.6)
    arc = bp(arc, 300, 9000) * pw([(0, 0), (0.005, 1), (0.15, 0.7), (0.22, 0)], an) * wobble(an, rng, 0.6, 40)
    mix_into(y, unit(sat(unit(arc), 3)) * 0.7, 0.06)
    mix_into(y, burst(rng, 0.05, 500, 9000, 0.008) * 0.8, 0.27)
    hn = ns(1.0)
    mix_into(y, unit(mains_hum(60, hn)) * pw([(0, 0), (0.05, 1), (1.0, 0)], hn) * 0.15, 0.3)
    return reverb(y, 'room', 0.2, tail=0.3)


@snd('Shotgun', 'Дробовик: выстрел (хлопок + низкий «бум» + насыщение, отражения коридора) и передёргивание цевья.',
     1.0, roll=(20, 300))
def s_shotgun(rng):
    n = ns(2.4)
    y = np.zeros(n)
    bn = ns(0.6)
    blast = 1.5 * white(bn, rng) * expdec(bn, 0.0015)
    blast += lp(white(bn, rng), 3500) * expdec(bn, 0.05) * 1.2
    blast += bp(white(bn, rng), 800, 3000) * expdec(bn, 0.02)
    blast += 1.6 * np.sin(phase_of(pwexp([(0, 130), (0.08, 55), (0.6, 40)], bn), bn)) * expdec(bn, 0.16)
    blast = sat(unit(blast) * 2.5, 2.5)
    blast = reverb(blast, 'hall', 0.45, tail=0.9)
    mix_into(y, unit(blast), 0.0)
    # передёргивание
    pump = np.zeros(ns(0.8))

    def slide(d, lo, hi):
        m = ns(d)
        return unit(bp(white(m, rng), lo, hi) * pw([(0, 0.2), (d * 0.8, 1), (d, 0)], m))

    mix_into(pump, slide(0.07, 1500, 6000) * 0.3, 0.0)
    mix_into(pump, metal_click(rng, 1450, 0.2, 0.05) * 0.9, 0.07)
    mix_into(pump, unit(modes(ns(0.2), [310, 520], [0.04, 0.03], [1, 0.6], rng)) * 0.4, 0.07)
    mix_into(pump, slide(0.06, 1800, 7000) * 0.25, 0.18)
    mix_into(pump, metal_click(rng, 1250, 0.2, 0.06) * 1.0, 0.24)
    mix_into(pump, unit(modes(ns(0.2), [280, 470], [0.05, 0.03], [1, 0.6], rng)) * 0.5, 0.24)
    pump = reverb(pump, 'room', 0.2, tail=0.1)
    mix_into(y, unit(pump) * 0.32, 0.85)
    for k, t0 in enumerate((1.45, 1.58, 1.66)):   # гильза падает на пол
        mix_into(y, plastic_click(rng, 1300) * 0.08 / (k + 1), t0)
    return y


@snd('Pepper', 'Перцовый баллончик: щелчок клапана и резкое шипение струи с турбулентностью.', 0.6, roll=(6, 40))
def s_pepper(rng):
    n = ns(1.3)
    y = np.zeros(n)
    mix_into(y, plastic_click(rng, 2100) * 0.4, 0.0)
    hn = ns(1.0)
    h = hp(white(hn, rng), 2500, 2) + 0.4 * bp(white(hn, rng), 600, 1600)
    h = eq(h, [('peak', 5500, 1.5, 6), ('peak', 8200, 2.0, 3)])
    h *= pw([(0, 0), (0.02, 1), (0.85, 0.9), (0.93, 0.4), (0.96, 0.8), (1.0, 0)], hn) * wobble(hn, rng, 0.15, 14)
    mix_into(y, unit(h) * 0.9, 0.012)
    mix_into(y, plastic_click(rng, 1800) * 0.25, 1.02)
    return reverb(y, 'room', 0.12, tail=0.2)


@snd('Stun', 'Электрошокер: частые щелчки разрядов (≈18 Гц), жужжание дуги и треск.', 0.8, roll=(8, 60))
def s_stun(rng):
    n = ns(1.25)
    y = np.zeros(n)
    on = ns(1.05)
    ex = np.zeros(on)
    t = 0.0
    while t < 1.0:
        ex[ns(t)] += rng.uniform(0.6, 1.0)
        t += 1 / 18.0 * rng.uniform(0.85, 1.15)
    ir = modes(ns(0.03), [2600, 3900, 6100], [0.004, 0.003, 0.002], [1, 0.7, 0.5], rng)
    clicks = signal.fftconvolve(ex, ir)[:on] + 0.4 * signal.fftconvolve(ex, white(ns(0.004), rng) * expdec(ns(0.004), 0.001))[:on]
    buzz = pulse(95 * wobble(on, rng, 0.05, 20), on, 0.1) + 0.6 * saw(190, on)
    buzz = bp(buzz, 250, 7000) * (0.5 + 0.5 * wobble(on, rng, 0.6, 35))
    crack = hp(dust(on, rng, 600, 0.5), 3000) * 1.5
    s = unit(clicks) * 0.9 + unit(buzz) * 0.45 + unit(crack) * 0.35
    s = sat(s, 2.5) * pw([(0, 0), (0.003, 1), (0.95, 1), (1.05, 0)], on)
    mix_into(y, unit(s), 0.0)
    return reverb(y, 'room', 0.12, tail=0.2)


@snd('TrapSnap', 'Капкан: щелчок спуска, свист пружины, лязг стальных дуг и звяканье цепи.', 0.9, roll=(10, 90))
def s_trap(rng):
    n = ns(1.1)
    y = np.zeros(n)
    mix_into(y, metal_click(rng, 3800, 0.05, 0.008) * 0.25, 0.0)
    wn = ns(0.04)
    mix_into(y, unit(bp(white(wn, rng), 2000, 9000) * np.linspace(0.2, 1, wn)) * 0.25, 0.005)
    snap = strike(ns(0.8), [620, 1430, 2380, 3570, 4900, 6200, 8100], [0.3, 0.22, 0.15, 0.1, 0.07, 0.05, 0.03],
                  [1, 0.8, 0.7, 0.6, 0.5, 0.35, 0.25], rng, width=0.00012, noise=0.7, noise_tau=0.002)
    mix_into(y, unit(snap) * 1.0, 0.045)
    mix_into(y, thump(rng, 0.3, 150, 70, 0.04, noise=0.6) * 0.5, 0.045)
    t = 0.07
    for k in range(18):
        t += rng.exponential(0.025)
        if t > 0.7:
            break
        mix_into(y, metal_click(rng, rng.uniform(2200, 5200), 0.06, 0.012) * 0.22 * np.exp(-(t - 0.07) / 0.3), t)
    y = sat(unit(y) * 1.1, 1.6)
    return reverb(y, 'room', 0.2, tail=0.3)


@snd('Heal', 'Лечение: мягкое колокольное арпеджио (ми мажор) с тёплой подложкой и хвостом.', 0.55)
def s_heal(rng):
    n = ns(2.1)
    y = np.zeros(n)
    for k, (nn, t0) in enumerate(((64, 0.0), (68, 0.09), (71, 0.18), (76, 0.27), (80, 0.40))):
        m = ns(1.6)
        v = fm_bell(mtof(nn), m, ratio=2.0, index=1.2, dec=0.7, idx_dec=0.15, att=0.006)
        v += 0.3 * fm_bell(mtof(nn + 12), m, ratio=3.5, index=0.8, dec=0.3, idx_dec=0.1, att=0.004)
        mix_into(y, v * (0.8 - 0.08 * k), t0)
    pm = ns(1.8)
    p = sum(np.sin(TAU * mtof(x) * tvec(pm)) for x in (52, 59, 64)) * pw([(0, 0), (0.3, 1), (1.0, 0.6), (1.8, 0)], pm)
    mix_into(y, p * 0.12, 0.0)
    return reverb(y, 'plate', 0.4, tail=0.6)


@snd('Defib', 'Дефибриллятор: нарастающий писк зарядки, сигнал готовности, разряд (хлопок + глухой удар).', 0.85,
     roll=(8, 60))
def s_defib(rng):
    n = ns(2.9)
    y = np.zeros(n)
    cn = ns(1.45)
    f = pwexp([(0, 700), (1.45, 4300)], cn)
    ch = np.sin(phase_of(f, cn)) + 0.25 * np.sin(3 * phase_of(f, cn))
    ch *= pw([(0, 0), (0.05, 0.4), (1.4, 1), (1.45, 0)], cn)
    mix_into(y, ch * 0.22, 0.0)
    bn = ns(0.09)
    beep = pulse(1046, bn, 0.5) * pw([(0, 0), (0.005, 1), (0.085, 1), (0.09, 0)], bn)
    mix_into(y, lp(beep, 5000) * 0.18, 1.5)
    mix_into(y, lp(beep, 5000) * 0.18, 1.62)
    tz = 1.85
    mix_into(y, thump(rng, 0.6, 85, 38, 0.13, noise=1.0, lpf=350) * 1.0, tz)
    mix_into(y, burst(rng, 0.03, 1500, 14000, 0.004) * 0.8, tz)
    zn = ns(0.05)
    zap = bp(pulse(140, zn, 0.1) + dust(zn, rng, 2000), 300, 8000) * expdec(zn, 0.015)
    mix_into(y, unit(zap) * 0.5, tz + 0.002)
    y = sat(y, 1.4)
    return reverb(y, 'room', 0.18, tail=0.4)


@snd('Jumpscare', 'Скример: диссонансный кластер расстроенных пил с «криковыми» формантами, шум, металлический '
     'FM-визг, падение высоты, суб-удар, жёсткое искажение.', 1.0)
def s_jumpscare(rng):
    n = ns(2.6)
    t = tvec(n)
    pitch = pwexp([(0, 1.0), (0.07, 1.07), (0.5, 0.93), (1.5, 0.62), (2.6, 0.36)], n)
    vibr = 2 ** ((0.25 * np.sin(phase_of(pw([(0, 5), (2.6, 11)], n), n)) * pw([(0, 0.2), (2.6, 1)], n)) / 12)
    base = 466.16
    sw = np.zeros(n)
    for semi in (0, 1, 6, 11, 13, 18):
        for det in (-14, 0, 13):
            sw += saw(base * 2 ** ((semi + det / 100) / 12) * pitch * vibr, n, rng.random())
    sw /= 18
    scream = reson(sw, 900, 3) + 0.9 * reson(sw, 1450, 4) + 0.7 * reson(sw, 2900, 5) + 0.4 * reson(sw, 4300, 6)
    nz = bp(white(n, rng), 900, 9000) * pw([(0, 1), (0.25, 0.45), (2.6, 0.3)], n)
    fmc = 2300 * pitch
    metal = np.sin(phase_of(fmc, n) + 6 * np.sin(phase_of(fmc * 1.414, n)))
    sub = np.sin(phase_of(pwexp([(0, 95), (0.6, 32), (2.6, 28)], n), n)) * expdec(n, 0.5)
    hit = white(n, rng) * expdec(n, 0.012)
    y = 1.0 * unit(scream) + 0.45 * unit(sw) + 0.5 * unit(nz) + 0.35 * metal + 0.9 * sub + 0.8 * hit
    y = hp(y, 35)
    y = sat(unit(y) * 3.0, 3.5)
    y = compress(y, -16, 6, 0.01)
    env = pw([(0, 0), (0.002, 1), (1.9, 0.9), (2.6, 0)], n)
    return y * env


# ---------- тело и голос ----------

@snd('Heartbeat', 'Сердцебиение 80 уд/мин, «тук-тук» глухо и плотно. Бесшовная петля 6 с (8 ударов) — '
     'для тревоги повышайте PlaybackSpeed.', 0.7, loop=True)
def s_heartbeat(rng):
    L = 6.0
    n = ns(L)
    y = np.zeros(n)

    def beat(f_hi, f_lo, dec, amp):
        m = ns(0.35)
        f = pwexp([(0, f_hi), (0.05, f_lo), (0.35, f_lo * 0.9)], m)
        v = np.sin(phase_of(f, m)) * expdec(m, dec) * pw([(0, 0), (0.006, 1), (0.35, 1)], m)
        v += 0.35 * lp(white(m, rng), 180) * expdec(m, dec * 0.6)
        return v * amp

    per = 0.75
    for k in range(8):
        t0 = 0.08 + k * per + rng.uniform(-0.004, 0.004)   # стык петли — в тишине перед ударом
        a = rng.uniform(0.92, 1.05)
        mix_into(y, beat(78, 46, 0.075, a), t0, wrap=True)
        mix_into(y, beat(92, 58, 0.06, a * 0.72), t0 + 0.29, wrap=True)
    y = circ(y, lambda v: lp(v, 260, 2), ns(0.5))
    y = sat(unit(y) * 1.6, 2.0)
    return y


@snd('Breath', 'Нервное дыхание (через рот, дрожащие вдохи) — петля 10 с, для прятанья в шкафу.', 0.5, loop=True)
def s_breath(rng):
    L = 10.0
    n = ns(L)
    y = np.zeros(n)
    plan = []
    t = 0.0
    while True:
        di = rng.uniform(0.45, 0.7)
        do = rng.uniform(0.6, 0.95)
        gap = rng.uniform(0.08, 0.3)
        if t + di + do + gap > L - 0.05:
            break
        plan.append((t, di, True, rng.random() < 0.5))
        plan.append((t + di + 0.03, do, False, False))
        t += di + do + gap + 0.03
    scale = L / t   # растянуть план ровно на длину петли
    for (t0, d, inhale, shaky) in plan:
        t0 = t0 * scale + 0.12
        d *= scale
        m = ns(d)
        nz = white(m, rng)
        if inhale:
            v = 0.7 * reson(nz, 1150, 2.5) + 0.6 * reson(nz, 2400, 4) + 0.35 * reson(nz, 3600, 5) + 0.15 * hp(nz, 4000)
            env = pw([(0, 0), (d * 0.25, 0.8), (d * 0.85, 1.0), (d, 0)], m) ** 1.3
            if shaky:
                env *= 1 + 0.45 * np.sin(TAU * rng.uniform(7, 11) * tvec(m))
            g = 0.75
        else:
            v = 0.8 * reson(nz, 750, 2.0) + 0.6 * reson(nz, 1500, 3) + 0.25 * reson(nz, 2600, 4) + 0.1 * lp(nz, 600)
            env = pw([(0, 0), (d * 0.12, 1.0), (d * 0.5, 0.6), (d, 0)], m) ** 1.6
            g = 1.0
        mix_into(y, unit(v * env) * g * rng.uniform(0.85, 1.0), t0, wrap=True)
    y = reverb(y, 'closet', 0.25, loop=True)
    return circ(y, lambda v: hp(v, 120), ns(0.3))


@snd('Whisper', 'Жуткий шёпот без слов: формантный шум «слогами», два голоса, обратный отзвук и хвост коридора.', 0.6,
     roll=(6, 40))
def s_whisper(rng):
    n = ns(4.2)
    seq = []
    t = 0.45
    vow = list(VOWELS.keys())
    while t < 3.4:
        c = rng.choice(['s', 'sh', 'h', 'h', 't', 'k'])
        cd = 0.06 if c in ('t', 'k') else rng.uniform(0.07, 0.16)
        seq.append((t, cd, c))
        t += cd
        vd = rng.uniform(0.12, 0.28)
        seq.append((t, vd, rng.choice(vow)))
        t += vd + rng.uniform(0.0, 0.12)

    def voice(shift, rng2):
        x = white(n, rng2)

        def gain(f, tt):
            G = np.zeros((len(f), len(tt)))
            for j, ti in enumerate(tt):
                cur = None
                for (s0, d, ph) in seq:
                    if s0 <= ti < s0 + d:
                        cur = (s0, d, ph)
                if cur is None:
                    continue
                s0, d, ph = cur
                pos = (ti - s0) / d
                amp = np.sin(np.pi * min(1, max(0, pos))) ** 0.7
                if ph == 's':
                    g = formant_gain(f, [6500], [3000], [1.0]) * 0.8
                elif ph == 'sh':
                    g = formant_gain(f, [3200, 5200], [1600, 2500], [1, 0.6])
                elif ph in ('t', 'k'):
                    g = formant_gain(f, [4200 if ph == 't' else 2200], [3000], [1.0]) * (1 - pos) ** 3
                elif ph == 'h':
                    g = formant_gain(f, [900, 1700, 2800], [600, 800, 1000], [0.5, 0.4, 0.3])
                else:
                    F = np.array(VOWELS[ph]) * shift
                    g = formant_gain(f, F, [160, 220, 320], [1.0, 0.7, 0.4]) + 0.05
                    g *= np.clip(f / 400, 0, 1)
                G[:, j] = g * amp
            return G

        return spec_shape(x, gain, nper=512)

    y = unit(voice(1.0, rng)) + 0.55 * np.roll(unit(voice(1.12, np.random.default_rng(seed_of('whisper2')))), ns(0.11))
    y *= pw([(0, 0), (0.4, 1), (3.6, 1), (4.2, 0)], n)
    # обратный отзвук перед шёпотом
    rv = reverb(y, 'hall', 1.0, dry=0.0, tail=1.5)
    pre = rv[::-1][-n:] if rv.shape[-1] >= n else rv[::-1]
    out = reverb(y, 'hall', 0.45, tail=1.2)
    mix_into(out, unit(pre[:ns(0.8)]) * pw([(0, 0), (0.75, 0.35), (0.8, 0)], ns(0.8)) * 0.6, 0.0)
    return out


# ---------- окружение (стерео, бесшовные петли) ----------

def wind_layer(rng, n, strength=1.0, whistle=0.6, gust_rate=0.12, shift=0.0):
    gust = slow_curve(n, rng, gust_rate, 0, 1) ** 1.6
    flut = slow_curve(n, rng, 0.9, 0, 1)
    g = 0.2 + 0.8 * gust * (0.85 + 0.15 * flut)
    if shift:
        g = np.roll(g, ns(shift))
    gi = lambda tt: np.interp(tt * SR, np.arange(n), g)
    low = brown(n, rng, hi=260) * (0.4 + 0.6 * g)
    body_src = pink(n, rng)

    def body_gain(f, tt):
        c = 250 + 1100 * gi(tt)
        return (1 / (1 + ((np.log(f[:, None] + 1) - np.log(c[None, :])) / 0.7) ** 2)) * (0.3 + gi(tt))[None, :]

    body = spec_shape(body_src, body_gain, 2048, circular=True)

    def whis_gain(f, tt):
        c = 520 + 700 * gi(tt)
        a = (1 / (1 + ((f[:, None] - c[None, :]) / 22) ** 2) + 0.5 / (1 + ((f[:, None] - 1.63 * c[None, :]) / 30) ** 2))
        return a * (gi(tt) ** 2)[None, :]

    wh = spec_shape(white(n, rng), whis_gain, 4096, circular=True) if whistle > 0 else 0
    return strength * (0.55 * unit(low) + 0.9 * unit(body) + whistle * 0.25 * unit(wh) if whistle > 0
                       else 0.55 * unit(low) + 0.9 * unit(body))


def stereo_wind(rng, n, **kw):
    return np.stack([wind_layer(rng, n, **kw), wind_layer(rng, n, shift=0.6, **kw)])


def cricket_field(rng, n, count=7, gain=1.0, far=0.4):
    L = n / SR
    out = np.zeros((2, n))
    for i in range(count):
        f = rng.uniform(4200, 5300)
        syl = int(rng.integers(3, 5))
        P = rng.uniform(0.32, 0.7)
        k = max(1, int(round(L / P)))
        P = L / k
        ch = cricket_chirp(rng, f, syl)
        dist = rng.uniform(0, 1)
        a = gain * (1.0 - 0.8 * dist) * rng.uniform(0.6, 1.0)
        if dist > far:
            ch = lp(ch, 6500 - 3000 * dist)
        st = pan2(ch, rng.uniform(-0.9, 0.9))
        off = rng.uniform(0, P)
        for j in range(k):
            mix_into(out, st, off + j * P + rng.uniform(-0.006, 0.006), a, wrap=True)
    # непрерывная трель древесного сверчка
    tf = rng.uniform(2700, 3100)
    m = n
    pr = (np.mod(loop_phase(48.0, m) / TAU, 1.0) < 0.45).astype(float)
    pr = ndimage.uniform_filter1d(pr, ns(0.004), mode='wrap')
    tr = np.sin(loop_phase(tf, m)) * pr * (0.3 + 0.7 * slow_curve(m, rng, 0.15, 0, 1) ** 2)
    out += pan2(tr, -0.3) * 0.25 * gain
    return out


def amb_finish(y):
    return circ(y, lambda v: hp(v, 25, 2), ns(1.0))


@snd('AmbientLobby', 'Лобби у лечебницы: холодный низкий дрон с биениями, далёкий ветер со свистом, гул прожекторов, '
     'редкий далёкий металлический скрип. Стерео, петля 45 с.', 0.35, loop=True, stereo=True)
def s_amb_lobby(rng):
    n = ns(45.0)
    y = np.zeros((2, n))
    for c, det in ((0, 1.0), (1, 1.004)):
        d = np.zeros(n)
        for f, a in ((55.0, 1.0), (82.4, 0.5), (110.3, 0.35), (116.6 * det, 0.18), (164.8, 0.12), (880.6 * det, 0.02),
                     (932.3, 0.012)):
            d += a * np.sin(loop_phase(f * det, n, rng.uniform(0, TAU)))
        d *= 0.7 + 0.3 * slow_curve(n, rng, 0.05, 0, 1)
        y[c] += 0.45 * unit(d)
    y += 0.55 * unit(stereo_wind(rng, n, whistle=0.8, gust_rate=0.09))
    buzz = sum(a * np.sin(loop_phase(120.0 * k, n)) for k, a in ((1, 1), (2, 0.5), (3, 0.6), (5, 0.3)))
    y += pan2(unit(buzz), 0.5) * 0.03
    for t0 in (13.0, 34.5):
        cn = ns(1.2)
        c = creak(rng, cn, pwexp([(0, 30), (0.6, 70), (1.2, 40)], cn), pw([(0, 0), (0.3, 1), (1.2, 0)], cn),
                  modes(ns(0.6), [310, 720, 1130, 1880], [0.2, 0.15, 0.1, 0.07], [1, 0.7, 0.5, 0.4], rng))
        c = reverb(lp(unit(c), 2500), 'outdoor', 0.8, tail=1.0)
        mix_into(y, pan2(unit(c), rng.uniform(-0.8, 0.8)) * 0.08, t0, wrap=True)
    y = reverb(y, 'outdoor', 0.15, loop=True)
    return amb_finish(y)


@snd('AmbientDay', 'Пригород днём: разные птицы (свисты, трели, щебет) на разных дистанциях, лёгкий ветерок с '
     'шелестом листвы, далёкий гул улицы и одна проезжающая машина. Стерео, петля 45 с.', 0.35, loop=True, stereo=True)
def s_amb_day(rng):
    n = ns(45.0)
    y = 0.16 * unit(stereo_wind(rng, n, whistle=0.0, gust_rate=0.15))
    leaves = np.stack([hp(white(n, rng), 2500) * (0.2 + dust(n, rng, 120, 0.4) ** 2) for _ in range(2)])
    leaves = circ(leaves, lambda v: lp(v, 9000), ns(0.1)) * slow_curve(n, rng, 0.15, 0.2, 1.0)
    y += 0.06 * unit(leaves)
    traffic = np.stack([brown(n, rng, hi=300), brown(n, rng, hi=300)])
    y += 0.03 * unit(traffic)
    birds = np.zeros((2, n))
    t = 0.3
    while t < 44.0:
        ph = bird_phrase(rng)
        dist = rng.uniform(0, 1)
        if dist > 0.4:
            ph = lp(ph, 7000 - 3500 * dist)
        mix_into(birds, pan2(ph, rng.uniform(-0.95, 0.95)), t, (1 - 0.75 * dist) * rng.uniform(0.6, 1.0), wrap=True)
        t += rng.exponential(0.9) + 0.25
    birds = reverb(birds, 'outdoor', 0.35, loop=True)
    y += 0.55 * unit(birds)
    cn = ns(7.0)
    car = lp(pink(cn, rng), 900) * pw([(0, 0), (3.2, 1), (3.8, 1), (7.0, 0)], cn) ** 2
    pan = pw([(0, -0.9), (7, 0.9)], cn)
    a = (pan + 1) * np.pi / 4
    mix_into(y, np.stack([car * np.cos(a), car * np.sin(a)]), 22.0, 0.05 / (np.std(car) * 4 + 1e-9), wrap=True)
    return amb_finish(y)


@snd('AmbientNight', 'Ночь во дворе: хор сверчков, далёкий лай собаки с эхом улицы, низкий тревожный дрон, слабый ветер. '
     'Стерео, петля 45 с.', 0.35, loop=True, stereo=True)
def s_amb_night(rng):
    n = ns(45.0)
    y = 0.6 * unit(cricket_field(rng, n, 7))
    y += 0.2 * unit(stereo_wind(rng, n, whistle=0.3, gust_rate=0.08))
    d = np.zeros(n)
    for f, a in ((41.2, 1.0), (61.7, 0.4), (82.4, 0.3), (87.3, 0.15), (329.6, 0.02), (349.2, 0.015)):
        d += a * np.sin(loop_phase(f, n, rng.uniform(0, TAU)))
    d *= 0.6 + 0.4 * slow_curve(n, rng, 0.04, 0, 1)
    y += 0.28 * np.stack([d, np.roll(d, ns(0.013))]) / np.max(np.abs(d))
    dog = np.zeros(n)
    for t0, cnt in ((11.0, 3), (30.5, 2), (31.6, 2)):
        f0 = 470 * rng.uniform(0.95, 1.05)
        for k in range(cnt):
            mix_into(dog, dog_bark(rng, f0 * rng.uniform(0.95, 1.05)), t0 + k * rng.uniform(0.35, 0.5),
                     rng.uniform(0.7, 1.0), wrap=True)
    dog = lp(dog, 1800)
    dogs = reverb(pan2(dog, -0.55), 'outdoor', 0.9, dry=0.5, loop=True)
    y += 0.12 * dogs / (np.max(np.abs(dogs)) + 1e-9)
    return amb_finish(y)


@snd('AmbientHouse', 'Дом изнутри: гул холодильника (компрессор ~59 Гц с биениями 118/120 Гц, вентилятор), '
     'настенные часы «тик-так» 1 Гц, тихий фон комнаты, редкий скрип дома. Стерео, петля 40 с.', 0.4, loop=True,
     stereo=True)
def s_amb_house(rng):
    n = ns(40.0)
    y = np.zeros((2, n))
    hum = sum(a * np.sin(loop_phase(f, n, rng.uniform(0, TAU))) for f, a in
              ((59.0, 0.5), (118.0, 1.0), (120.0, 0.6), (177.0, 0.3), (236.0, 0.35), (295, 0.1), (472.0, 0.06)))
    hum *= 0.9 + 0.1 * slow_curve(n, rng, 0.3, 0, 1)
    fan = circ(pink(n, rng, hi=1800), lambda v: v, 1)
    fridge = unit(hum) * 0.8 + 0.25 * unit(fan)
    y += pan2(fridge, -0.45) * 0.35
    room = np.stack([pink(n, rng, hi=3000), pink(n, rng, hi=3000)])
    y += 0.025 * unit(room)
    tick = np.zeros(n)
    for s in range(40):
        f0 = 2600 if s % 2 == 0 else 2150
        k = strike(ns(0.08), [f0, f0 * 1.52, f0 * 2.31, 900], [0.006, 0.004, 0.003, 0.015], [1, 0.6, 0.4, 0.5], rng,
                   width=0.00012, noise=0.3, noise_tau=0.001)
        mix_into(tick, unit(k) * (1.0 if s % 2 == 0 else 0.8), s + 0.25, wrap=True)
    tick = reverb(tick, 'room', 0.35, loop=True)
    y += pan2(unit(tick), 0.55) * 0.22
    cn = ns(0.9)
    c = creak(rng, cn, pwexp([(0, 18), (0.4, 35), (0.9, 22)], cn), pw([(0, 0), (0.2, 1), (0.9, 0)], cn),
              door_ir(rng, 0.3, 0.6), jitter=0.25)
    c = reverb(unit(c), 'hall', 0.4, tail=0.6)
    mix_into(y, pan2(unit(c), -0.2) * 0.06, 23.4, wrap=True)
    return amb_finish(y)


@snd('Wind', 'Порывистый ветер: низкий гул, «тело» с плавающим центром и свист щелей. Стерео, петля 40 с.', 0.4,
     loop=True, stereo=True)
def s_wind(rng):
    n = ns(40.0)
    y = stereo_wind(rng, n, strength=1.0, whistle=1.0, gust_rate=0.14)
    return amb_finish(y)


@snd('Crickets', 'Хор сверчков с трелью древесного сверчка и тихим ночным фоном. Стерео, петля 30 с.', 0.35, loop=True,
     stereo=True)
def s_crickets(rng):
    n = ns(30.0)
    y = unit(cricket_field(rng, n, 11, far=0.3))
    y += 0.04 * np.stack([pink(n, rng, hi=1200), pink(n, rng, hi=1200)]) / 3
    return amb_finish(y)


# ---------- музыкальные «стинги» ----------

@snd('Stinger', 'Хоррор-удар: низкий медный кластер (ре–ми♭–ля♭–ля), суб-бум, «смычковый» металл, большой зал.', 0.8)
def s_stinger(rng):
    n = ns(5.0)
    y = np.zeros(n)
    for nn, a in ((38, 1.0), (39, 0.8), (44, 0.75), (45, 0.6), (50, 0.5), (51, 0.35)):
        v = brass(mtof(nn), n, rng, att=0.012, rel=1.2, cut_pk=2600, cut_sus=700, cut_dec=0.6, detune=12, sus=0.45)
        y += a * v
    y = unit(y) * pw([(0, 1), (0.25, 0.85), (2.5, 0.55), (5.0, 0)], n)
    y += 0.8 * np.sin(phase_of(pwexp([(0, 70), (0.5, 33), (5, 30)], n), n)) * expdec(n, 0.7)
    y += 0.5 * lp(white(n, rng), 400) * expdec(n, 0.05)
    bow = modes(n, [1180, 1213, 2390, 3570, 3610, 4980], [1.5, 1.4, 1.2, 0.9, 0.9, 0.6], [1, 0.8, 0.6, 0.5, 0.4, 0.3], rng)
    y += 0.12 * unit(bow) * pw([(0, 0), (0.4, 1), (5.0, 0.3)], n)
    y = sat(unit(y) * 1.2, 1.6)
    return reverb(y, 'big', 0.45, tail=0.01)


@snd('Dawn', 'Рассвет: тёплый мажорный аккорд (ре add9) с плавной атакой, электропиано-арпеджио и пара птиц.', 0.6)
def s_dawn(rng):
    n = ns(5.8)
    y = np.zeros(n)
    ch = [50, 57, 62, 64, 66, 69]
    y += 0.5 * unit(pad([mtof(x) for x in ch], n, rng, cut=1600, att=1.2, rel=1.6, detune=8))
    for k, (nn, t0) in enumerate(((74, 0.6), (78, 0.85), (81, 1.1), (88, 1.35), (86, 1.75), (81, 2.2))):
        mix_into(y, epiano(mtof(nn), ns(2.5), 0.6) * 0.18, t0)
    for t0 in (3.1, 3.9):
        mix_into(y, lp(bird_phrase(rng, 'tweet'), 7000) * 0.07, t0)
    return reverb(y, 'plate', 0.4, tail=0.8)


@snd('Win', 'Победа: медная фанфара вверх по до мажору, литавры, тарелка и финальный аккорд.', 0.7)
def s_win(rng):
    n = ns(5.2)
    y = np.zeros(n)
    mel = [(0.0, 0.18, 67), (0.2, 0.18, 72), (0.4, 0.18, 76), (0.6, 0.5, 79), (1.15, 0.18, 76), (1.35, 1.6, 84)]
    for t0, d, nn in mel:
        m = ns(d + 0.15)
        mix_into(y, brass(mtof(nn), m, rng, att=0.02, rel=0.12, cut_pk=4500, cut_sus=2000) * 0.35, t0)
    m = ns(3.6)
    chord = sum(brass(mtof(x), m, rng, att=0.04, rel=1.4, cut_pk=3500, cut_sus=1500, sus=0.7) for x in (48, 55, 60, 64, 67, 72))
    mix_into(y, chord * 0.12, 1.35)
    for k in range(10):
        mix_into(y, timpani(rng, mtof(36), 0.5, 0.2 + 0.05 * k) * 0.35, 0.6 + k * 0.07)
    mix_into(y, timpani(rng, mtof(36), 2.2) * 0.6, 1.35)
    mix_into(y, crash(rng, 3.0) * 0.25, 1.35)
    return reverb(sat(y, 1.2), 'plate', 0.35, tail=0.6)


@snd('Lose', 'Поражение: низкий колокол, хроматический спуск в миноре, «замедление ленты» в конце.', 0.7)
def s_lose(rng):
    n = ns(4.8)
    y = np.zeros(n)
    mix_into(y, unit(fm_bell(mtof(33), ns(4.5), 1.4, 3.0, 2.0, 0.6)) * 0.55, 0.0)
    for t0, nn in ((0.15, 64), (0.75, 63), (1.35, 62), (1.95, 61)):
        m = ns(0.9)
        v = brass(mtof(nn - 12), m, rng, att=0.06, rel=0.4, cut_pk=1600, cut_sus=700, detune=14, voices=3)
        v += 0.6 * brass(mtof(nn - 24), m, rng, att=0.06, rel=0.4, cut_pk=900, cut_sus=400, detune=14)
        mix_into(y, v * 0.4, t0)
    m = ns(2.6)
    slow = pwexp([(0, 1.0), (0.6, 0.97), (2.6, 0.45)], m)
    f = mtof(45) * slow
    v = sum(saw(f * r * 2 ** (d / 1200), m, rng.random()) for r in (1, 1.189, 1.498) for d in (-10, 10))
    v = lp(v, 900) * pw([(0, 0), (0.1, 1), (1.8, 0.6), (2.6, 0)], m)
    mix_into(y, unit(v) * 0.45, 2.2)
    return reverb(sat(y, 1.3), 'big', 0.35, tail=0.01)


# ---------- интерфейс и шаги ----------

@snd('UiHover', 'Наведение на кнопку: короткий мягкий «тик» 2 кГц.', 0.25)
def s_ui_hover(rng):
    n = ns(0.12)
    t = tvec(n)
    y = (np.sin(TAU * 2100 * t) + 0.4 * np.sin(TAU * 3150 * t)) * np.exp(-t / 0.018) * np.minimum(1, t / 0.0015)
    y += 0.2 * hp(white(n, rng), 4000) * expdec(n, 0.002)
    return y


@snd('UiClick', 'Нажатие кнопки: пластиковый щелчок + короткий восходящий «блип».', 0.4)
def s_ui_click(rng):
    n = ns(0.16)
    y = np.zeros(n)
    mix_into(y, plastic_click(rng, 1600) * 0.8, 0.0)
    bn = ns(0.07)
    f = pwexp([(0, 880), (0.04, 1320), (0.07, 1320)], bn)
    b = (np.sin(phase_of(f, bn)) + 0.2 * np.sin(2 * phase_of(f, bn))) * pw([(0, 0), (0.003, 1), (0.07, 0)], bn) ** 1.5
    mix_into(y, b * 0.45, 0.008)
    return y


def footstep(rng, v):
    n = ns(0.5)
    y = np.zeros(n)
    sc = [1.0, 0.92, 1.08, 0.97][v]
    fr = np.array([95, 150, 240, 380, 610, 980, 1500, 2300, 3400]) * sc * rng.uniform(0.95, 1.05, 9)
    dc = [0.06, 0.05, 0.04, 0.03, 0.022, 0.015, 0.01, 0.007, 0.005]
    am = np.array([1.0, 0.9, 0.8, 0.7, 0.55, 0.45, 0.35, 0.3, 0.25]) * rng.uniform(0.6, 1.0, 9)
    heel = strike(ns(0.3), fr, dc, am, rng, width=0.0012 + 0.0003 * v, noise=0.25, noise_tau=0.006)
    mix_into(y, unit(heel), 0.005)
    tt = 0.005 + rng.uniform(0.06, 0.1)
    toe = strike(ns(0.25), fr * 1.15, dc, am * rng.uniform(0.5, 1.0, 9), rng, width=0.0008, noise=0.3, noise_tau=0.004)
    mix_into(y, unit(toe) * rng.uniform(0.35, 0.55), tt)
    sm = ns(0.06)
    scuff = bp(white(sm, rng), 1500, 6500) * pw([(0, 0), (0.01, 1), (0.06, 0)], sm)
    mix_into(y, unit(scuff) * 0.12, tt)
    if v == 2:
        cn = ns(0.18)
        c = creak(rng, cn, pwexp([(0, 35), (0.18, 22)], cn), pw([(0, 0), (0.04, 1), (0.18, 0)], cn), door_ir(rng, 0.2, 0.7))
        mix_into(y, unit(c) * 0.12, 0.04)
    return reverb(lp(y, 9000), 'room', 0.12, tail=0.2)


for _v in range(4):
    def _mk(v):
        def fn(rng):
            return footstep(rng, v)
        return fn
    snd('Footstep' if _v == 0 else 'Footstep%d' % (_v + 1),
        'Шаг ботинка по деревянному полу (пятка + носок, вариант %d). В Config есть только Footstep; '
        'остальные варианты — по желанию (случайный выбор).' % (_v + 1), 0.45, roll=(5, 45))(_mk(_v))


# =====================================================================================
# Запись и анализ звука
# =====================================================================================

def need_ffmpeg():
    if not shutil.which('ffmpeg') or not shutil.which('ffprobe'):
        sys.exit('Нужен ffmpeg/ffprobe в PATH (с libvorbis).')


def trim_tail(y, db=-62.0, keep=0.03):
    mono = np.max(np.abs(y), axis=0) if y.ndim == 2 else np.abs(y)
    th = np.max(mono) * 10 ** (db / 20)
    idx = np.nonzero(mono > th)[0]
    if len(idx) == 0:
        return y
    end = min(mono.shape[0], idx[-1] + ns(keep))
    return y[..., :end]


def finish_sound(spec, y):
    y = np.asarray(y, dtype=float)
    if spec['stereo'] and y.ndim == 1:
        y = np.stack([y, y])
    if not spec['stereo'] and y.ndim == 2:
        y = y.mean(axis=0)
    if spec['loop']:
        y = dc_block(y, loop=True)
    else:
        y = hp(y, 18, 2)
        y = trim_tail(y)
        y = fade(y, 0.0015, 0.03)
    return normalize(y, PEAK)


def _encode(path, y, q):
    y = np.asarray(y, dtype=np.float32)
    ch = 1 if y.ndim == 1 else y.shape[0]
    data = y if y.ndim == 1 else np.ascontiguousarray(y.T)
    cmd = ['ffmpeg', '-y', '-v', 'error', '-f', 'f32le', '-ar', str(SR), '-ac', str(ch), '-i', 'pipe:0',
           '-map_metadata', '-1', '-fflags', '+bitexact', '-flags:a', '+bitexact',
           '-c:a', 'libvorbis', '-q:a', str(q), '-ar', str(SR), path]
    subprocess.run(cmd, input=data.tobytes(), check=True)


def write_ogg(path, y, q=5):
    # Vorbis может «выстрелить» выше исходного пика (особенно на искажённых звуках) — подправляем уровень
    for _ in range(3):
        _encode(path, y, q)
        x, _, _ = read_audio(path)
        pk = np.max(np.abs(x))
        if pk <= 10 ** (-0.7 / 20):
            break
        y = y * (PEAK / pk)


def read_audio(path):
    pr = subprocess.run(['ffprobe', '-v', 'error', '-show_streams', '-of', 'json', path], capture_output=True,
                        check=True)
    st = json.loads(pr.stdout)['streams'][0]
    ch = int(st['channels'])
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le', '-'], capture_output=True,
                         check=True).stdout
    x = np.frombuffer(raw, np.float32).astype(float).reshape(-1, ch).T
    return x, int(st['sample_rate']), st.get('codec_name', '')


def seam_metrics(x):
    # стык петли: склеиваем конец с началом и смотрим, выделяется ли блок на стыке по ВЧ (щелчок)
    m = x.mean(axis=0)
    n = len(m)
    blk = 256
    xx = np.concatenate([m[-n // 2:], m[:n - n // 2]])       # стык ровно посередине
    hf = hp(xx, 3000, 4)
    k = len(hf) // blk
    bm = np.abs(hf[:k * blk]).reshape(k, blk).max(axis=1)
    sb = bm[(n // 2) // blk - 1:(n // 2) // blk + 1].max()
    rank = float(np.mean(bm < sb) * 100)
    jump = abs(m[0] - m[-1])
    dif = np.abs(np.diff(m))
    rms_a = np.sqrt(np.mean(m[-ns(0.25):] ** 2)) + 1e-12
    rms_b = np.sqrt(np.mean(m[:ns(0.25)] ** 2)) + 1e-12
    return dict(seam_rank=rank, seam_hf_ratio=sb / (np.percentile(bm, 99) + 1e-12),
                jump_pct=float(np.mean(dif < jump) * 100), level_step_db=20 * np.log10(rms_b / rms_a))


def analyze_sound(path, loop):
    x, sr, codec = read_audio(path)
    m = x.mean(axis=0)
    d = dict(dur=x.shape[1] / sr, ch=x.shape[0], sr=sr, codec=codec,
             peak_db=20 * np.log10(np.max(np.abs(x)) + 1e-12),
             rms_db=20 * np.log10(np.sqrt(np.mean(m ** 2)) + 1e-12),
             size=os.path.getsize(path))
    if loop:
        d.update(seam_metrics(x))
    return d


def gen_sounds(keys=None):
    need_ffmpeg()
    os.makedirs(SND_DIR, exist_ok=True)
    for spec in SOUNDS:
        if keys and spec['key'] not in keys:
            continue
        t0 = time.time()
        rng = np.random.default_rng(seed_of(spec['key']))
        y = finish_sound(spec, spec['fn'](rng))
        path = os.path.join(SND_DIR, spec['key'] + '.ogg')
        write_ogg(path, y, spec['q'])
        print('  звук %-16s %5.2f c  %s  (%.1f c)' % (spec['key'], y.shape[-1] / SR,
                                                     'стерео' if y.ndim == 2 else 'моно', time.time() - t0))


# ---------- спектрограммы ----------

_CMAP = np.array([[0, 0, 4], [40, 11, 84], [101, 21, 110], [159, 42, 99], [212, 72, 66], [245, 125, 21],
                  [250, 193, 39], [252, 255, 164]], float)


def colormap(v):
    v = np.clip(v, 0, 1) * (len(_CMAP) - 1)
    i = np.minimum(v.astype(int), len(_CMAP) - 2)
    f = (v - i)[..., None]
    return (_CMAP[i] * (1 - f) + _CMAP[i + 1] * f).astype(np.uint8)


def spectrogram_img(x, w, h, fmin=30.0, fmax=20000.0, rng_db=90.0):
    m = x.mean(axis=0) if x.ndim == 2 else x
    nper = 2048
    hop = max(64, len(m) // (w * 2))
    f, t, Z = signal.stft(m, SR, nperseg=nper, noverlap=max(0, nper - hop), boundary=None, padded=False)
    S = 20 * np.log10(np.abs(Z) + 1e-9)
    S -= S.max()
    ff = np.exp(np.linspace(np.log(fmax), np.log(fmin), h))
    rows = np.interp(ff, f, np.arange(len(f)))
    Si = ndimage.map_coordinates(S, np.meshgrid(rows, np.linspace(0, S.shape[1] - 1, w), indexing='ij'), order=1)
    return Image.fromarray(colormap((Si + rng_db) / rng_db))


def audio_preview(path_out, items):
    cols = 4
    cw, ch, wh, lh = 380, 150, 34, 30
    rows = (len(items) + cols - 1) // cols
    W, H = cols * (cw + 12) + 12, rows * (ch + wh + lh + 12) + 50
    im = Image.new('RGB', (W, H), (18, 18, 22))
    d = ImageDraw.Draw(im)
    d.text((12, 12), 'Amber Alert — спектрограммы звуков (лог. частота 30 Гц–20 кГц, 90 дБ)', fill=(230, 230, 230),
           font=font('sans', 20))
    small = font('mono', 13)
    for i, (key, path, info) in enumerate(items):
        x0 = 12 + (i % cols) * (cw + 12)
        y0 = 50 + (i // cols) * (ch + wh + lh + 12)
        x, sr, _ = read_audio(path)
        im.paste(spectrogram_img(x, cw, ch), (x0, y0 + lh))
        m = x.mean(axis=0)
        seg = np.array_split(np.abs(m), cw)
        pk = np.array([s.max() if len(s) else 0 for s in seg])
        yc = y0 + lh + ch + wh // 2
        for k, v in enumerate(pk):
            hh = int(v * (wh // 2 - 2))
            d.line([(x0 + k, yc - hh), (x0 + k, yc + hh)], fill=(120, 200, 160))
        lab = '%s  %.2fs %s pk %.1f dB' % (key, info['dur'], 'st' if info['ch'] == 2 else 'mono', info['peak_db'])
        d.text((x0, y0 + 6), lab, fill=(235, 235, 235), font=small)
    im.save(path_out, optimize=True)


# =====================================================================================
# КАРТИНКИ: утилиты (периодический шум, рисование «по кругу», шрифты, текст)
# =====================================================================================

_FONT_IDX = None
_FONT_CACHE = {}
FONT_PREFS = {
    'sans': ['DejaVuSans.ttf', 'LiberationSans-Regular.ttf', 'FreeSans.ttf', 'arial.ttf', 'Arial.ttf', 'Helvetica.ttc'],
    'sans-bold': ['DejaVuSans-Bold.ttf', 'LiberationSans-Bold.ttf', 'FreeSansBold.ttf', 'arialbd.ttf', 'Arial Bold.ttf'],
    'serif': ['DejaVuSerif.ttf', 'LiberationSerif-Regular.ttf', 'FreeSerif.ttf', 'times.ttf', 'Times New Roman.ttf'],
    'serif-bold': ['DejaVuSerif-Bold.ttf', 'LiberationSerif-Bold.ttf', 'FreeSerifBold.ttf', 'timesbd.ttf'],
    'mono': ['DejaVuSansMono.ttf', 'LiberationMono-Regular.ttf', 'FreeMono.ttf', 'cour.ttf', 'Courier New.ttf'],
    'mono-bold': ['DejaVuSansMono-Bold.ttf', 'LiberationMono-Bold.ttf', 'FreeMonoBold.ttf', 'courbd.ttf'],
    'typewriter': ['FreeMono.ttf', 'LiberationMono-Regular.ttf', 'cour.ttf', 'DejaVuSansMono.ttf'],
    'typewriter-bold': ['FreeMonoBold.ttf', 'LiberationMono-Bold.ttf', 'courbd.ttf', 'DejaVuSansMono-Bold.ttf'],
}
FONT_DIRS = ['/usr/share/fonts', '/usr/local/share/fonts', os.path.expanduser('~/.fonts'),
             os.path.expanduser('~/.local/share/fonts'), 'C:/Windows/Fonts', '/Library/Fonts', '/System/Library/Fonts']


def font(kind, size):
    global _FONT_IDX
    k = (kind, size)
    if k in _FONT_CACHE:
        return _FONT_CACHE[k]
    if _FONT_IDX is None:
        _FONT_IDX = {}
        for d in FONT_DIRS:
            if os.path.isdir(d):
                for r, _, files in os.walk(d):
                    for f in files:
                        _FONT_IDX.setdefault(f.lower(), os.path.join(r, f))
    f = None
    for name in FONT_PREFS.get(kind, FONT_PREFS['sans']):
        p = _FONT_IDX.get(name.lower())
        if p:
            try:
                f = ImageFont.truetype(p, size)
                break
            except OSError:
                pass
    if f is None:
        try:
            f = ImageFont.load_default(size)
        except TypeError:
            f = ImageFont.load_default()
    _FONT_CACHE[k] = f
    return f


def text_img(txt, fnt, fill=(0, 0, 0, 255), sx=1.0, sy=1.0, stroke=0, stroke_fill=None, spacing=0):
    # текст в отдельный RGBA-слой (можно сжать/растянуть — «узкий» шрифт)
    if spacing:
        parts = [text_img(c, fnt, fill, 1, 1, stroke, stroke_fill) for c in txt]
        sp = int(spacing)
        w = sum(p.width for p in parts) + sp * (len(parts) - 1)
        h = max(p.height for p in parts)
        im = Image.new('RGBA', (max(1, w), h), (0, 0, 0, 0))
        x = 0
        asc = fnt.getbbox('Hg')
        for c, p in zip(txt, parts):
            bb = fnt.getbbox(c) if c.strip() else asc
            im.alpha_composite(p, (x, max(0, bb[1] - asc[1])))
            x += p.width + sp
    else:
        bb = fnt.getbbox(txt, stroke_width=stroke)
        w, h = bb[2] - bb[0] + 4, bb[3] - bb[1] + 4
        im = Image.new('RGBA', (max(1, w), max(1, h)), (0, 0, 0, 0))
        ImageDraw.Draw(im).text((2 - bb[0], 2 - bb[1]), txt, font=fnt, fill=fill, stroke_width=stroke,
                                stroke_fill=stroke_fill)
    if sx != 1.0 or sy != 1.0:
        im = im.resize((max(1, int(im.width * sx)), max(1, int(im.height * sy))), Image.LANCZOS)
    return im


def put(canvas, layer, x, y, anchor='mt', rot=0.0, max_w=None):
    # вставить слой; anchor: m = центр по x, l/r; t = верх по y, m, b
    if max_w and layer.width > max_w:
        layer = layer.resize((int(max_w), layer.height), Image.LANCZOS)
    if rot:
        layer = layer.rotate(rot, resample=Image.BICUBIC, expand=True)
    ax = {'l': 0, 'm': layer.width / 2, 'r': layer.width}[anchor[0]]
    ay = {'t': 0, 'm': layer.height / 2, 'b': layer.height}[anchor[1]]
    canvas.alpha_composite(layer, (int(round(x - ax)), int(round(y - ay))))
    return layer.size


def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float) / 255.0


def per_noise(h, w, rng, sx, sy=None):
    # периодический гладкий шум (бесшовный), масштаб деталей ~sx, sy пикселей; среднее 0, СКО 1
    sy = sx if sy is None else sy
    spec = rng.standard_normal((h, w)) + 1j * rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2 * ((fx * sx) ** 2 + (fy * sy) ** 2))
    g[0, 0] = 0
    y = np.real(np.fft.ifft2(spec * g))
    return (y - y.mean()) / (y.std() + 1e-12)


def per_fbm(h, w, rng, beta=2.0, cut=2.0):
    spec = rng.standard_normal((h, w)) + 1j * rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    r = np.sqrt(fx ** 2 + fy ** 2)
    r[0, 0] = 1
    g = r ** (-beta / 2) * (1 - np.exp(-(r / cut) ** 2))
    g[0, 0] = 0
    y = np.real(np.fft.ifft2(spec * g))
    return (y - y.mean()) / (y.std() + 1e-12)


def wblur(a, s):
    if a.ndim == 3:
        return ndimage.gaussian_filter(a, (s, s, 0) if np.isscalar(s) else (s[0], s[1], 0), mode='wrap')
    return ndimage.gaussian_filter(a, s, mode='wrap')


def down2(a):
    # уменьшение вдвое усреднением 2x2 — не ломает бесшовность
    h, w = a.shape[:2]
    return a.reshape(h // 2, 2, w // 2, 2, *a.shape[2:]).mean(axis=(1, 3))


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def to_img(rgb, alpha=None):
    a = np.clip(rgb, 0, 1)
    a = (a * 255 + 0.5).astype(np.uint8)
    if alpha is not None:
        al = (np.clip(alpha, 0, 1) * 255 + 0.5).astype(np.uint8)
        return Image.fromarray(np.dstack([a, al]), 'RGBA')
    return Image.fromarray(a, 'RGB')


def from_img(im):
    return np.asarray(im.convert('RGB'), float) / 255.0


class WrapDraw:
    # рисование с повтором на соседние «копии» тайла (для бесшовных узоров)
    def __init__(self, im):
        self.im = im
        self.d = ImageDraw.Draw(im)
        self.w, self.h = im.size

    def _offs(self):
        return [(dx, dy) for dx in (-self.w, 0, self.w) for dy in (-self.h, 0, self.h)]

    def polygon(self, pts, fill):
        for dx, dy in self._offs():
            self.d.polygon([(x + dx, y + dy) for x, y in pts], fill=fill)

    def ellipse(self, box, fill=None, outline=None, width=1):
        x0, y0, x1, y1 = box
        for dx, dy in self._offs():
            self.d.ellipse((x0 + dx, y0 + dy, x1 + dx, y1 + dy), fill=fill, outline=outline, width=width)

    def line(self, pts, fill, width=1):
        for dx, dy in self._offs():
            self.d.line([(x + dx, y + dy) for x, y in pts], fill=fill, width=width, joint='curve')

    def rect(self, box, fill=None, outline=None, width=1):
        x0, y0, x1, y1 = box
        for dx, dy in self._offs():
            self.d.rectangle((x0 + dx, y0 + dy, x1 + dx, y1 + dy), fill=fill, outline=outline, width=width)

    def paste(self, layer, x, y):
        for dx, dy in self._offs():
            self.im.paste(layer, (int(x + dx), int(y + dy)), layer)


def bezier(p0, p1, p2, p3, k=48):
    t = np.linspace(0, 1, k)[:, None]
    p0, p1, p2, p3 = (np.array(p, float) for p in (p0, p1, p2, p3))
    return (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3


def taper(pts, w0, w1, shape=None):
    # полигон «мазка» вдоль кривой с переменной толщиной
    pts = np.asarray(pts, float)
    k = len(pts)
    s = np.linspace(0, 1, k)
    w = (w0 + (w1 - w0) * s) if shape is None else shape(s)
    d = np.gradient(pts, axis=0)
    d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
    nrm = np.stack([-d[:, 1], d[:, 0]], 1)
    left = pts + nrm * (w[:, None] / 2)
    right = pts - nrm * (w[:, None] / 2)
    return [tuple(p) for p in np.concatenate([left, right[::-1]])]


def star_pts(cx, cy, r, ri, k=5, rot=-90):
    pts = []
    for i in range(2 * k):
        a = np.radians(rot + i * 180 / k)
        rr = r if i % 2 == 0 else ri
        pts.append((cx + rr * np.cos(a), cy + rr * np.sin(a)))
    return pts


def poisson_torus(rng, w, h, rmin, count, tries=4000):
    pts = []
    for _ in range(tries):
        if len(pts) >= count:
            break
        p = np.array([rng.uniform(0, w), rng.uniform(0, h)])
        ok = True
        for q in pts:
            d = np.abs(p - q)
            d = np.minimum(d, [w, h] - d)
            if np.hypot(*d) < rmin:
                ok = False
                break
        if ok:
            pts.append(p)
    return pts


def paper_grain(h, w, rng, amt=0.03):
    return 1 + amt * (0.6 * rng.standard_normal((h, w)) + 0.4 * per_noise(h, w, rng, 1.2, 6.0))


IMAGES = []


def img(key, size, desc, studs=None, kind='tile', alpha=False, note=''):
    def deco(fn):
        IMAGES.append(dict(key=key, size=size, fn=fn, desc=desc, studs=studs, kind=kind, alpha=alpha, note=note))
        return fn
    return deco


# =====================================================================================
# КАРТИНКИ: бесшовные тайлы
# =====================================================================================

def damask_motif(wd, cx, cy, sx, sy, fill):
    # зеркально-симметричный цветочный мотив дамаска; координаты u,v в [-1,1]
    def P(u, v):
        return (cx + u * sx, cy + v * sy)

    def mirror(fn):
        fn(1)
        fn(-1)

    wd.polygon(taper([P(0, 0.95), P(0, 0.4), P(0, -0.1), P(0, -0.25)], 0.06 * sx, 0.035 * sx), fill)
    # центральный цветок: три лепестка + чашечка
    def petal(cu, cv, ru, rv, ang, f=fill):
        t = np.linspace(0, TAU, 40)
        x, y = ru * np.cos(t), rv * np.sin(t) * (1 + 0.25 * np.sin(t))
        a = np.radians(ang)
        xs, ys = x * np.cos(a) - y * np.sin(a), x * np.sin(a) + y * np.cos(a)
        wd.polygon([P(cu + xx, cv + yy) for xx, yy in zip(xs, ys)], f)

    petal(0, -0.66, 0.15, 0.33, 0)
    mirror(lambda s: petal(0.2 * s, -0.5, 0.12, 0.3, 32 * s))
    mirror(lambda s: petal(0.36 * s, -0.36, 0.08, 0.2, 62 * s))
    petal(0, -0.3, 0.3, 0.12, 0)
    # прожилки (вырезы цветом фона)
    wd.line([P(0, -0.92), P(0, -0.42)], 0, width=max(1, int(0.022 * sx)))
    mirror(lambda s: wd.line([P(0.12 * s, -0.68), P(0.22 * s, -0.42)], 0, width=max(1, int(0.016 * sx))))
    wd.ellipse((cx - 0.2 * sx, cy - 0.36 * sy, cx + 0.2 * sx, cy - 0.27 * sy), fill=0)
    # большие листья-аканты
    def leaf(s):
        c = bezier(P(0.02 * s, 0.22), P(0.35 * s, 0.35), P(0.75 * s, 0.1), P(0.9 * s, -0.22), 60)
        wd.polygon(taper(c, 0, 0, shape=lambda t: 0.25 * sx * np.sin(np.pi * t) ** 0.8 + 0.012 * sx), fill)
        wd.line([tuple(p) for p in c[5:50]], 0, width=max(1, int(0.02 * sx)))
        for k in (14, 26, 38):
            p = c[k]
            q = c[k + 1] - c[k - 1]
            q = q / (np.linalg.norm(q) + 1e-9)
            nrm = np.array([-q[1], q[0]]) * s
            lobe = bezier(p, p + nrm * 0.06 * sx + q * 0.05 * sx, p + nrm * 0.16 * sx + q * 0.02 * sx,
                          p + nrm * 0.2 * sx - q * 0.06 * sx, 30)
            wd.polygon(taper(lobe, 0, 0, shape=lambda t: 0.07 * sx * np.sin(np.pi * t) + 0.004 * sx), fill)
        c2 = bezier(P(0.04 * s, 0.32), P(0.25 * s, 0.62), P(0.55 * s, 0.62), P(0.62 * s, 0.42), 40)
        wd.polygon(taper(c2, 0, 0, shape=lambda t: 0.1 * sx * np.sin(np.pi * t) + 0.006 * sx), fill)
        # завиток-спираль снизу
        th = np.linspace(0, 2.6 * np.pi, 70)
        r = 0.17 * np.exp(-0.32 * th)
        cxs, cys = 0.42 * s, 0.82
        sp = [P(cxs + s * r[i] * np.cos(th[i] + np.pi), cys + r[i] * np.sin(th[i] + np.pi) * 0.9) for i in range(70)]
        wd.polygon(taper(sp, 0.05 * sx, 0.012 * sx), fill)
        wd.polygon(taper([P(0.02 * s, 0.7), P(0.15 * s, 0.86), P(0.3 * s, 0.85), P(0.42 * s - 0.17 * s, 0.82)],
                         0.04 * sx, 0.05 * sx), fill)
        for (u, v, rr) in ((0.33, -0.86, 0.035), (0.5, -0.7, 0.03), (0.6, -0.52, 0.025), (0.72, 0.42, 0.03),
                           (0.82, 0.3, 0.022)):
            x, y = P(u * s, v)
            wd.ellipse((x - rr * sx, y - rr * sx, x + rr * sx, y + rr * sx), fill=fill)

    mirror(leaf)
    x, y = P(0, -1.04)
    wd.ellipse((x - 0.04 * sx, y - 0.04 * sx, x + 0.04 * sx, y + 0.04 * sx), fill=fill)
    mirror(lambda s: wd.polygon(taper(bezier(P(0, 0.9), P(0.1 * s, 1.0), P(0.2 * s, 1.02), P(0.28 * s, 0.98), 20),
                                      0, 0, shape=lambda t: 0.07 * sx * np.sin(np.pi * t)), fill))


def rosette(wd, cx, cy, r, fill):
    for k in range(4):
        a = k * np.pi / 2
        t = np.linspace(0, TAU, 30)
        x, y = 0.38 * r * np.cos(t), 0.2 * r * np.sin(t)
        xs = x * np.cos(a) - y * np.sin(a) + np.cos(a) * 0.45 * r
        ys = x * np.sin(a) + y * np.cos(a) + np.sin(a) * 0.45 * r
        wd.polygon(list(zip(cx + xs, cy + ys)), fill)
    for k in range(4):
        a = k * np.pi / 2 + np.pi / 4
        wd.ellipse((cx + np.cos(a) * 0.75 * r - 0.07 * r, cy + np.sin(a) * 0.75 * r - 0.07 * r,
                    cx + np.cos(a) * 0.75 * r + 0.07 * r, cy + np.sin(a) * 0.75 * r + 0.07 * r), fill=fill)
    wd.ellipse((cx - 0.12 * r, cy - 0.12 * r, cx + 0.12 * r, cy + 0.12 * r), fill=0)


@img('WallpaperLiving', 1024, 'Обои гостиной: приглушённый пыльно-розовый дамаск 90-х, тон-в-тон, с «атласным» мотивом, '
     'вертикальной фактурой бумаги и лёгким пожелтением.', studs=(6, 6))
def i_wallpaper_living(rng, n):
    S = n * 2
    m = Image.new('L', (S, S), 0)
    wd = WrapDraw(m)
    for (cx, cy) in ((0.25, 0.25), (0.75, 0.75)):
        damask_motif(wd, cx * S, cy * S, 0.215 * S, 0.235 * S, 255)
    for (cx, cy) in ((0.75, 0.25), (0.25, 0.75)):
        rosette(wd, cx * S, cy * S, 0.075 * S, 255)
    mask = down2(np.asarray(m, float) / 255.0)
    ground, motif = hexc('#8a6464'), hexc('#a98480')
    emb = wblur(mask, 1.5)
    gy, gx = np.gradient(emb)
    shade = 1 + 0.6 * (-gx - gy)
    stripes = 1 + 0.025 * per_noise(n, n, rng, 1.0, 60.0)
    rgb = ground[None, None] * (1 - mask[..., None]) + motif[None, None] * mask[..., None]
    rgb *= (shade * stripes)[..., None]
    rgb *= paper_grain(n, n, rng, 0.025)[..., None]
    age = per_noise(n, n, rng, 90.0)
    rgb = rgb * (1 - 0.025 * age[..., None]) + 0.05 * (age[..., None] > 0.8) * (hexc('#b09a6a') - rgb)
    rgb *= (1 + 0.012 * per_fbm(n, n, rng, 2.5, 3))[..., None]
    return to_img(rgb)


@img('WallpaperBedroom', 512, 'Обои спальни: кремовая полоска тон-в-тон с тёмно-синими и бордовыми «пинстрайпами», '
     'неровности печати, фактура бумаги.', studs=(4, 4))
def i_wallpaper_bed(rng, n):
    x = np.arange(n)[None, :].repeat(n, 0).astype(float)
    jit = 0.35 * per_noise(n, n, rng, 2.0, 80.0)
    p = 64.0
    u = np.mod(x + jit, p)
    base = hexc('#d6ccb2')
    rgb = np.ones((n, n, 3)) * base
    band = smoothstep(0, 1.5, u - 20) * (1 - smoothstep(0, 1.5, u - 44))
    rgb *= (1 - 0.05 * band)[..., None]

    def line(c, w, col, a):
        k = np.clip(1 - np.abs(u - c) / (w / 2 + 0.5) + 0.5, 0, 1) * a * (0.85 + 0.15 * per_noise(n, n, rng, 3, 30))
        return k[..., None], hexc(col)

    for c, w, col, a in ((4, 2.6, '#2a3555', 0.9), (9, 1.0, '#7a2e35', 0.8), (59, 1.0, '#7a2e35', 0.8),
                         (32, 0.9, '#2a3555', 0.45)):
        k, cc = line(c, w, col, a)
        rgb = rgb * (1 - k) + cc * k
    rgb *= paper_grain(n, n, rng, 0.03)[..., None]
    age = per_noise(n, n, rng, 60.0)
    rgb = rgb * (1 - 0.02 * age[..., None]) + np.clip(age, 0, None)[..., None] * 0.03 * (hexc('#c2a86a') - rgb)
    return to_img(rgb)


@img('WallpaperKids', 512, 'Обои детской: выцветший голубой фон, звёзды, месяцы, кубики с буквами и мячики; '
     'лёгкий сдвиг печати, фактура бумаги.', studs=(5, 5))
def i_wallpaper_kids(rng, n):
    S = n * 2
    bg = hexc('#9fbfd4')
    out = Image.new('RGB', (S, S), tuple(int(v * 255) for v in bg))
    ink = Image.new('L', (S, S), 0)
    wo, wi = WrapDraw(out), WrapDraw(ink)
    pts = poisson_torus(rng, S, S, S * 0.15, 26)
    cols = ['#f2d16b', '#e8806e', '#f7f1e1', '#8fc79a', '#f2d16b', '#c79ad6']
    lf = font('sans-bold', int(S * 0.05))
    for i, (cx, cy) in enumerate(pts):
        kind = ['star', 'star', 'moon', 'block', 'ball', 'star'][i % 6]
        r = S * rng.uniform(0.035, 0.055)
        col = cols[rng.integers(len(cols))]
        off = S * 0.004
        if kind == 'star':
            p = star_pts(cx, cy, r, r * 0.45, rot=-90 + rng.uniform(-20, 20))
            wo.polygon([(a + off, b + off) for a, b in p], col)
            wi.line(p + [p[0]], 255, width=int(S * 0.004))
        elif kind == 'moon':
            wo.ellipse((cx - r + off, cy - r + off, cx + r + off, cy + r + off), fill='#f7e7a6')
            wo.ellipse((cx - r * 0.5 + off, cy - r * 1.05 + off, cx + r * 1.3 + off, cy + r * 0.75 + off), fill=tuple(int(v * 255) for v in bg))
            wi.ellipse((cx - r, cy - r, cx + r, cy + r), outline=255, width=int(S * 0.004))
            wi.ellipse((cx - r * 0.5, cy - r * 1.05, cx + r * 1.3, cy + r * 0.75), fill=0)
        elif kind == 'block':
            a = r * 0.85
            wo.rect((cx - a + off, cy - a + off, cx + a + off, cy + a + off), fill=col)
            wi.rect((cx - a, cy - a, cx + a, cy + a), outline=255, width=int(S * 0.004))
            ch = 'ABCАБВ'[rng.integers(6)]
            t = text_img(ch, lf, (255, 255, 255, 255))
            wi.paste(t.split()[3], cx - t.width / 2, cy - t.height / 2)
        else:
            wo.ellipse((cx - r + off, cy - r + off, cx + r + off, cy + r + off), fill=col)
            wo.rect((cx - r + off, cy - r * 0.18 + off, cx + r + off, cy + r * 0.18 + off), fill='#f7f1e1')
            wi.ellipse((cx - r, cy - r, cx + r, cy + r), outline=255, width=int(S * 0.004))
        for _ in range(2):
            dx, dy = rng.uniform(-1, 1, 2) * S * 0.07
            rr = S * 0.008
            wo.polygon(star_pts(cx + dx * 1.6, cy + dy * 1.6, rr * 1.6, rr * 0.7, 4), '#f7f1e1')
    rgb = down2(np.asarray(out, float) / 255.0)
    k = down2(np.asarray(ink, float) / 255.0)[..., None]
    rgb = rgb * (1 - k * 0.8) + hexc('#2d3b5c') * k * 0.8
    rgb = rgb * 0.85 + bg * 0.15
    rgb *= paper_grain(n, n, rng, 0.03)[..., None]
    rgb *= (1 + 0.04 * per_noise(n, n, rng, 70))[..., None]
    return to_img(rgb)


@img('KitchenTiles', 512, 'Линолеум кухни «шахматка» 4×4: кремовые и почти чёрные плитки с крошкой, грязь в швах, '
     'потёртости и чёрные следы каблуков.', studs=(4, 4))
def i_kitchen(rng, n):
    c = n // 4
    yy, xx = np.mgrid[0:n, 0:n]
    chk = ((xx // c + yy // c) % 2).astype(float)
    light, dark = hexc('#d9cfb4'), hexc('#2a2b2e')
    tv = rng.uniform(-0.03, 0.03, (4, 4))
    var = tv[yy // c, xx // c]
    rgb = np.where(chk[..., None] > 0, dark, light) * (1 + var)[..., None]
    fl = rng.random((n, n))
    flk = wblur((fl > 0.985).astype(float), 0.7) * 2.2
    flk2 = wblur((fl < 0.012).astype(float), 0.9) * 2.0
    rgb = rgb + (chk[..., None] * np.clip(flk, 0, 1)[..., None] * 0.35) - ((1 - chk)[..., None] * np.clip(flk2, 0, 1)[..., None] * 0.18)
    rgb *= (1 + 0.035 * per_noise(n, n, rng, 2.0))[..., None]
    u, v = xx % c, yy % c
    edge = np.minimum(np.minimum(u, c - 1 - u), np.minimum(v, c - 1 - v))
    seam = (edge < 1.2).astype(float)
    dirt = wblur(seam, 2.0) * (0.6 + 0.4 * per_noise(n, n, rng, 20))
    rgb *= (1 - 0.35 * seam - 0.25 * np.clip(dirt, 0, 1))[..., None]
    sc = Image.new('L', (n * 2, n * 2), 0)
    ws = WrapDraw(sc)
    for _ in range(14):
        cx, cy = rng.uniform(0, n * 2, 2)
        r = rng.uniform(15, 60)
        a0 = rng.uniform(0, 360)
        pts = [(cx + r * np.cos(np.radians(a)), cy + r * 0.5 * np.sin(np.radians(a))) for a in np.linspace(a0, a0 + rng.uniform(40, 120), 20)]
        ws.line(pts, int(rng.uniform(60, 160)), width=int(rng.uniform(2, 6)))
    scuff = down2(np.asarray(sc, float) / 255.0)
    rgb *= (1 - 0.5 * scuff)[..., None]
    wax = per_noise(n, n, rng, 40)
    rgb *= (1 + 0.04 * wax)[..., None]
    rgb = rgb + (1 - chk[..., None]) * 0.04 * np.clip(per_noise(n, n, rng, 90), 0, None)[..., None] * (hexc('#b89a55') - rgb)
    return to_img(rgb)


@img('BathTiles', 512, 'Мелкая квадратная керамическая плитка 8×8 (мятно-голубая глазурь) с затёртыми серыми швами, '
     'фасками, бликами и грязью в углах.', studs=(2, 2))
def i_bath(rng, n):
    k = 8
    c = n // k
    yy, xx = np.mgrid[0:n, 0:n]
    u, v = xx % c + 0.5, yy % c + 0.5
    g = 3.0
    e = np.minimum(np.minimum(u, c - u), np.minimum(v, c - v))
    hgt = smoothstep(g, g + 5, e)
    tile = (e > g).astype(float)
    gy, gx = np.gradient(wblur(hgt, 0.8))
    light = 1 + 1.0 * (-gx - gy)
    tv = rng.uniform(-0.04, 0.04, (k, k))
    tvar = tv[yy // c, xx // c]
    glaze = hexc('#a9d3c9') * (1 + tvar)[..., None] * (1 + 0.025 * per_noise(n, n, rng, 5))[..., None]
    spec = np.exp(-((u - v * 0.6 - c * 0.15) / (c * 0.18)) ** 2) * 0.06
    glaze = glaze * light[..., None] + spec[..., None]
    pits = (rng.random((n, n)) > 0.996).astype(float)
    glaze *= (1 - 0.25 * wblur(pits, 0.6) * 3)[..., None]
    grout = hexc('#a7a39a') * (1 + 0.08 * rng.standard_normal((n, n)))[..., None]
    grime = np.clip(per_noise(n, n, rng, 25), 0, 1)
    grout *= (1 - 0.35 * grime)[..., None]
    rgb = glaze * tile[..., None] + grout * (1 - tile)[..., None]
    corner = np.exp(-((np.minimum(u, c - u)) ** 2 + (np.minimum(v, c - v)) ** 2) / 40.0)
    rgb *= (1 - 0.1 * corner * (0.5 + grime))[..., None]
    return to_img(rgb)


@img('Carpet', 512, 'Ковролин бежевый «builder beige»: плотный ворс, оттенки волокон, лёгкие пятна и примятости.',
     studs=(6, 6))
def i_carpet(rng, n):
    base = hexc('#a8957a')
    fib = wblur(rng.standard_normal((n, n)), 0.8)
    fib /= fib.std()
    tuft = wblur(rng.standard_normal((n, n)), 1.6)
    tuft /= tuft.std()
    nap = per_noise(n, n, rng, 30, 9)
    low = per_noise(n, n, rng, 80)
    lum = 1 + 0.09 * fib + 0.13 * tuft + 0.04 * nap + 0.035 * low
    hue = np.stack([per_noise(n, n, rng, 1.5) for _ in range(3)], -1) * 0.025
    rgb = base * lum[..., None] * (1 + hue)
    sp = rng.random((n, n))
    rgb[sp > 0.9975] *= 1.35
    rgb[sp < 0.0015] *= 0.55
    stain = np.clip(per_noise(n, n, rng, 18) - 2.2, 0, None)
    rgb *= (1 - 0.25 * stain)[..., None]
    return to_img(rgb)


def wood_board(rng, h, l, tone):
    # одна доска: годичные кольца с искажением, волокна вдоль, поры
    vv, uu = np.mgrid[0:h, 0:l].astype(float)
    warp = ndimage.gaussian_filter(rng.standard_normal((h, l)), (6, 40)) * 60
    bend = 18 * np.sin(uu / l * TAU * rng.uniform(0.3, 1.2) + rng.uniform(0, TAU))
    ring = np.mod((vv + warp + bend) * rng.uniform(0.07, 0.12) + rng.uniform(0, 1), 1.0)
    late = smoothstep(0.6, 0.9, ring) * (1 - smoothstep(0.92, 1.0, ring))
    fiber = ndimage.gaussian_filter(rng.standard_normal((h, l)), (0.6, 18))
    fiber /= fiber.std() + 1e-9
    pores = ndimage.gaussian_filter((rng.random((h, l)) > 0.992).astype(float), (0.5, 3)) * 6
    lum = 1 - 0.22 * late + 0.06 * fiber - 0.25 * np.clip(pores, 0, 1)
    lum *= 1 + 0.06 * ndimage.gaussian_filter(rng.standard_normal((h, l)), (20, 120)) * 8
    return tone[None, None] * lum[..., None]


@img('WoodFloor', 1024, 'Паркетная доска «золотой дуб»: 8 рядов досок со случайными стыками, кольца и волокна, щели, '
     'лак с потёртостями и царапинами.', studs=(8, 8))
def i_wood(rng, n):
    rows = 8
    h = n // rows
    rgb = np.zeros((n, n, 3))
    tones = [hexc('#a8743f'), hexc('#9a6535'), hexc('#b5814a'), hexc('#8f5c31'), hexc('#a06d3c')]
    for r in range(rows):
        cuts = []
        x = rng.uniform(0, n)
        cuts.append(x)
        total = rng.uniform(300, 700)
        while total < n - 250:
            cuts.append(x + total)
            total += rng.uniform(300, 700)
        segs = [(cuts[i], (cuts[(i + 1) % len(cuts)] - cuts[i]) % n or n) for i in range(len(cuts))]
        for x0, ln in segs:
            ln = int(round(ln))
            tone = tones[rng.integers(len(tones))] * rng.uniform(0.92, 1.08)
            b = wood_board(rng, h, ln, tone)
            uu = np.arange(ln)
            b *= (1 - 0.18 * np.exp(-uu / 3.0) - 0.18 * np.exp(-(ln - 1 - uu) / 3.0))[None, :, None]
            b[:, :2] *= 0.45
            vv = np.arange(h)
            b *= (1 - 0.22 * np.exp(-vv / 2.5) - 0.12 * np.exp(-(h - 1 - vv) / 3.0))[:, None, None]
            b[:2] *= 0.45
            cols = (int(round(x0)) + uu) % n
            rgb[r * h:(r + 1) * h, cols] = b
    sc = Image.new('L', (n, n), 0)
    ws = WrapDraw(sc)
    for _ in range(60):
        x0, y0 = rng.uniform(0, n, 2)
        a = rng.normal(0, 0.25)
        ln = rng.uniform(20, 140)
        ws.line([(x0, y0), (x0 + ln * np.cos(a), y0 + ln * np.sin(a))], int(rng.uniform(40, 120)), width=1)
    scr = wblur(np.asarray(sc, float) / 255.0, 0.5)
    rgb = rgb + scr[..., None] * 0.18
    wear = np.clip(per_noise(n, n, rng, 120), 0, None)
    rgb = rgb * (1 + 0.05 * wear)[..., None] + 0.03 * wear[..., None] * (hexc('#c9a77a') - rgb)
    rgb *= (1 + 0.03 * per_noise(n, n, rng, 3))[..., None]
    return to_img(rgb)


@img('Ceiling', 512, 'Потолок «попкорн»: бугристая белёсая штукатурка с тенями и лёгким пожелтением.', studs=(8, 8))
def i_ceiling(rng, n):
    h = np.zeros((n, n))
    for rate, s, a in ((0.02, 1.0, 1.0), (0.006, 2.2, 1.6), (0.0015, 4.0, 2.2)):
        d = (rng.random((n, n)) < rate).astype(float) * rng.uniform(0.5, 1.0, (n, n))
        h += a * wblur(d, s) / (wblur(d, s).std() + 1e-9)
    h += 0.4 * per_noise(n, n, rng, 1.0)
    gy, gx = np.gradient(wblur(h, 0.7))
    nz = 1.0 / np.sqrt(1 + (gx * 0.9) ** 2 + (gy * 0.9) ** 2)
    L = np.array([-0.45, -0.55, 0.7])
    L /= np.linalg.norm(L)
    sh = (-gx * 0.9 * L[0] - gy * 0.9 * L[1] + L[2]) * nz
    ao = 1 - 0.08 * np.clip(wblur(h, 4) - h, 0, None)
    lum = 0.55 + 0.45 * sh
    rgb = hexc('#e2ddd2') * (lum * ao)[..., None]
    yel = np.clip(per_noise(n, n, rng, 100), 0, None)
    rgb = rgb + 0.05 * yel[..., None] * (hexc('#c9b98a') - rgb)
    return to_img(rgb)


@img('Siding', 512, 'Виниловый сайдинг «миндаль»: 8 горизонтальных досок с тенью под нахлёстом, тиснение под дерево, '
     'грязевые подтёки. Светлый — можно тонировать Texture.Color3.', studs=(6, 6))
def i_siding(rng, n):
    rows = 8
    h = n // rows
    yy, xx = np.mgrid[0:n, 0:n]
    v = (yy % h) / h
    prof = 0.72 + 0.28 * smoothstep(0.0, 0.25, v) - 0.06 * v
    prof -= 0.35 * np.exp(-((v - 0.0) / 0.035) ** 2)
    prof += 0.10 * np.exp(-((v - 0.97) / 0.02) ** 2)
    grain = per_noise(n, n, rng, 30, 0.8) * 0.035 + per_noise(n, n, rng, 120, 2) * 0.02
    rgb = hexc('#d9d2bf') * (prof + grain)[..., None]
    for r in range(rows):
        for _ in range(rng.integers(0, 2) + 1):
            x0 = rng.integers(0, n)
            d = np.minimum((xx - x0) % n, (x0 - xx) % n)
            m = (yy // h == r) & (d < 3)
            rgb[m] *= 0.82
    drip = np.clip(per_noise(n, n, rng, 4, 40), 0, None) * np.exp(-v / 0.4)
    rgb = rgb + 0.07 * np.clip(drip, 0, 1.5)[..., None] * (hexc('#6e6a52') - rgb)
    rgb *= (1 + 0.025 * per_noise(n, n, rng, 90))[..., None]
    rgb *= paper_grain(n, n, rng, 0.015)[..., None]
    return to_img(rgb)


@img('RoofShingles', 512, 'Битумная черепица «3 лепестка»: 8 рядов со смещением, гранулы разных цветов, тени под кромкой, '
     'прорези, выгоревшие и тёмные лепестки, подтёки.', studs=(8, 8))
def i_shingles(rng, n):
    rows = 8
    h = n // rows
    tw = n // 4
    yy, xx = np.mgrid[0:n, 0:n]
    r = yy // h
    xs = (xx + (r % 2) * (tw // 2)) % n
    tab = xs // tw
    v = (yy % h) / h
    gran = np.array([hexc('#3b3a39'), hexc('#2b2a2b'), hexc('#4a4640'), hexc('#58534b'), hexc('#24282a'), hexc('#5d4a3b')])
    gi = rng.choice(len(gran), (n, n), p=[0.3, 0.3, 0.15, 0.1, 0.1, 0.05])
    rgb = gran[gi]
    rgb = wblur(rgb, 0.45)
    tv = rng.uniform(-0.12, 0.12, (rows, 4))
    rgb *= (1 + tv[r, tab])[..., None]
    slot = (np.abs(xs % tw - tw / 2) > tw / 2 - 3) & (v > 0.45)
    rgb[slot] *= 0.35
    edge = np.exp(-((1 - v) / 0.04)) * 0.25
    shadow = 1 - 0.55 * np.exp(-v / 0.08)
    rgb *= (shadow + edge)[..., None]
    streak = np.clip(per_noise(n, n, rng, 3, 60), 0, None)
    rgb = rgb + 0.08 * streak[..., None] * (hexc('#4f5a45') - rgb)
    rgb *= (1 + 0.06 * per_noise(n, n, rng, 100))[..., None]
    return to_img(rgb)


@img('TvStatic', 512, 'ТВ-«снег» (бесшовно): зерно, горизонтальный смаз, строки развёртки, светлые/тёмные полосы. '
     'Для анимации сдвигайте OffsetStudsV/U или меняйте Rotation.', studs=(4, 4))
def i_tvstatic(rng, n):
    a = rng.standard_normal((n, n))
    a = wblur(a, (0.4, 1.1))
    a = (a - a.mean()) / a.std()
    lines = np.repeat(rng.standard_normal(n)[:, None], n, 1) * 0.25
    roll = 0.15 * np.sin(np.arange(n) / n * TAU * 2)[:, None]
    scan = np.where(np.arange(n) % 2 == 0, 1.0, 0.82)[:, None]
    lum = (0.5 + 0.2 * (a + lines + roll)) * scan
    rgb = np.stack([lum * 0.97, lum, lum * 1.03], -1)
    return to_img(rgb)


@img('Vignette', 512, 'Виньетка: чёрный, прозрачный центр, тёмные края (альфа). Растянуть ImageLabel на весь экран.',
     kind='overlay', alpha=True)
def i_vignette(rng, n):
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    u, v = (xx + 0.5) / n * 2 - 1, (yy + 0.5) / n * 2 - 1
    r = np.sqrt(u ** 2 * 0.9 + v ** 2 * 1.1)
    a = smoothstep(0.42, 1.25, r) ** 1.4 * 0.95
    a = np.clip(a + rng.uniform(-0.5, 0.5, (n, n)) / 255.0, 0, 1)
    return to_img(np.zeros((n, n, 3)), a)


@img('Grain', 512, 'Плёночное зерно (бесшовно, альфа): светлые и тёмные крупинки ~8% непрозрачности. '
     'ImageLabel с ScaleType = Tile, TileSize ~ 256 px, двигать каждый кадр.', kind='overlay', alpha=True)
def i_grain(rng, n):
    g = wblur(rng.standard_normal((n, n)), 0.55)
    g /= g.std()
    col = np.where(g > 0, 1.0, 0.0)
    a = np.clip(np.abs(g) * 0.075, 0, 0.4)
    return to_img(np.stack([col] * 3, -1), a)


def img_size(spec):
    s = spec['size']
    return (s, s) if np.isscalar(s) else tuple(s)


def gen_images(keys=None):
    os.makedirs(IMG_DIR, exist_ok=True)
    for spec in IMAGES:
        if keys and spec['key'] not in keys:
            continue
        t0 = time.time()
        rng = np.random.default_rng(seed_of(spec['key']))
        w, h = img_size(spec)
        im = spec['fn'](rng, w) if w == h else spec['fn'](rng, w, h)
        assert im.size == (w, h), (spec['key'], im.size)
        im = im.convert('RGBA' if spec['alpha'] else 'RGB')
        path = os.path.join(IMG_DIR, spec['key'] + '.png')
        im.save(path, optimize=True)
        print('  картинка %-16s %dx%d  %4d КБ  (%.1f c)' % (spec['key'], w, h, os.path.getsize(path) // 1024,
                                                           time.time() - t0))


# =====================================================================================
# КАРТИНКИ: эмблемы, плакаты, фото
# =====================================================================================

def arc_text(canvas, txt, fnt, cx, cy, r, center_deg, fill, bottom=False, track=1.0, stroke=0, stroke_fill=None):
    # текст по дуге: сверху — буквы «наружу», снизу — читается слева направо
    ws = [fnt.getlength(c) * track for c in txt]
    tot = sum(ws) / r
    a0 = np.radians(center_deg) + (tot / 2 if bottom else -tot / 2)
    cum = 0.0
    for c, w in zip(txt, ws):
        a = a0 + ((-1 if bottom else 1) * (cum + w / 2) / r)
        cum += w
        if not c.strip():
            continue
        g = text_img(c, fnt, fill, stroke=stroke, stroke_fill=stroke_fill)
        rot = -(np.degrees(a) - 90) if bottom else -(np.degrees(a) + 90)
        put(canvas, g, cx + r * np.cos(a), cy + r * np.sin(a), 'mm', rot=rot)


def disc_mask(S, cx, cy, r):
    yy, xx = np.mgrid[0:S, 0:S]
    return ((xx - cx) ** 2 + (yy - cy) ** 2 <= r * r)


def rgba_from(rgb, a):
    return to_img(rgb, a)


@img('EasLogo', 1024, 'Оригинальная эмблема «EAS»: круглый знак, синее кольцо с надписью EMERGENCY ALERT SYSTEM, янтарный '
     'диск с вышкой и радиоволнами, плашка EAS. Прозрачный фон.', kind='decal', alpha=True)
def i_eas_logo(rng, n):
    S = n * 2
    c = S / 2
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    navy, amber, white = (19, 37, 79, 255), (227, 162, 26, 255), (246, 244, 236, 255)
    d.ellipse((c - 0.485 * S, c - 0.485 * S, c + 0.485 * S, c + 0.485 * S), fill=amber)
    d.ellipse((c - 0.468 * S, c - 0.468 * S, c + 0.468 * S, c + 0.468 * S), fill=navy)
    d.ellipse((c - 0.357 * S, c - 0.357 * S, c + 0.357 * S, c + 0.357 * S), fill=white)
    # янтарный диск с радиальным градиентом
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    rr = np.hypot(xx - c, yy - c - 0.06 * S) / (0.34 * S)
    grad = hexc('#f7bd45') * (1 - rr[..., None] * 0.55) + hexc('#d2651a') * (rr[..., None] * 0.55)
    m = disc_mask(S, c, c, 0.342 * S)
    arr_ = np.asarray(im).copy()
    arr_[m, :3] = (np.clip(grad[m], 0, 1) * 255).astype(np.uint8)
    im = Image.fromarray(arr_, 'RGBA')
    d = ImageDraw.Draw(im)
    # вышка
    top = (c, c - 0.235 * S)
    lw = int(0.016 * S)
    L, R = (c - 0.1 * S, c + 0.07 * S), (c + 0.1 * S, c + 0.07 * S)
    d.line([L, top, R], fill=navy, width=lw, joint='curve')
    for k in range(1, 5):
        t = k / 5
        y = top[1] + (L[1] - top[1]) * t
        hw = 0.1 * S * t
        d.line([(c - hw, y), (c + hw, y)], fill=navy, width=int(lw * 0.6))
        if k < 4:
            t2 = (k + 1) / 5
            y2 = top[1] + (L[1] - top[1]) * t2
            hw2 = 0.1 * S * t2
            d.line([(c - hw, y), (c + hw2, y2)], fill=navy, width=int(lw * 0.45))
            d.line([(c + hw, y), (c - hw2, y2)], fill=navy, width=int(lw * 0.45))
    d.ellipse((top[0] - 0.022 * S, top[1] - 0.022 * S, top[0] + 0.022 * S, top[1] + 0.022 * S), fill=navy)
    for k, rad in enumerate((0.065, 0.11, 0.155)):
        rp = rad * S
        bb = (top[0] - rp, top[1] - rp, top[0] + rp, top[1] + rp)
        d.arc(bb, -40, 40, fill=navy, width=int(0.017 * S))
        d.arc(bb, 140, 220, fill=navy, width=int(0.017 * S))
    # плашка EAS
    by0, by1 = c + 0.075 * S, c + 0.245 * S
    d.rounded_rectangle((c - 0.29 * S, by0, c + 0.29 * S, by1), radius=int(0.03 * S), fill=navy,
                        outline=white, width=int(0.008 * S))
    t = text_img('EAS', font('sans-bold', int(0.16 * S)), white, sx=1.15, spacing=int(0.02 * S))
    put(im, t, c, (by0 + by1) / 2 + 0.004 * S, 'mm', max_w=0.5 * S)
    # подпись по кольцу
    arc_text(im, 'EMERGENCY ALERT SYSTEM', font('sans-bold', int(0.05 * S)), c, c, 0.413 * S, -90, white, track=1.02)
    arc_text(im, 'CIVIL BROADCAST NETWORK', font('sans-bold', int(0.04 * S)), c, c, 0.413 * S, 90, (227, 162, 26, 255),
             bottom=True, track=1.12)
    d = ImageDraw.Draw(im)
    for ang in (180, 0):
        a = np.radians(ang)
        d.polygon(star_pts(c + 0.413 * S * np.cos(a), c + 0.413 * S * np.sin(a), 0.028 * S, 0.012 * S), fill=white)
    im = im.resize((n, n), Image.LANCZOS)
    return im


def shield_poly(cx, top, w, h, k=60):
    l, r = cx - w / 2, cx + w / 2
    side = top + h * 0.5
    left = bezier((l, side), (l, top + h * 0.82), (cx - w * 0.25, top + h * 0.95), (cx, top + h), k)
    right = bezier((cx, top + h), (cx + w * 0.25, top + h * 0.95), (r, top + h * 0.82), (r, side), k)
    pts = [(l, top + h * 0.04), (cx - w * 0.25, top), (cx, top + h * 0.035), (cx + w * 0.25, top), (r, top + h * 0.04)]
    return pts + [(r, side)] + [tuple(p) for p in right[::-1]] + [tuple(p) for p in left[::-1]]


def key_layer(S, col):
    kl = Image.new('RGBA', (int(0.1 * S), int(0.34 * S)), (0, 0, 0, 0))
    d = ImageDraw.Draw(kl)
    w, h = kl.size
    d.ellipse((w * 0.12, 0, w * 0.88, w * 0.76), outline=col, width=int(w * 0.13))
    d.ellipse((w * 0.36, w * 0.24, w * 0.64, w * 0.52), outline=col, width=int(w * 0.08))
    d.rectangle((w * 0.42, w * 0.7, w * 0.58, h * 0.97), fill=col)
    for y0 in (0.78, 0.88):
        d.rectangle((w * 0.58, h * y0, w * 0.86, h * (y0 + 0.06)), fill=col)
    d.rectangle((w * 0.3, w * 0.86, w * 0.7, w * 0.94), fill=col)
    return kl


@img('BlackRidgeLogo', 1024, 'Оригинальный герб лечебницы Black Ridge: щит (костяная глава с чёрным хребтом и месяцем, '
     'тёмное поле со скрещёнными ключами), лавры, лента CUSTODIA ET CURA, надписи. Потёртость, прозрачный фон.',
     kind='decal', alpha=True)
def i_blackridge(rng, n):
    S = n * 2
    c = S / 2
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    gold, gold_d, bone, dark, ink = (176, 145, 82, 255), (120, 96, 52, 255), (220, 210, 186, 255), (29, 38, 34, 255), (18, 18, 18, 255)
    # лавры
    for s in (-1, 1):
        stem = bezier((c + s * 0.03 * S, 0.84 * S), (c + s * 0.36 * S, 0.8 * S), (c + s * 0.4 * S, 0.45 * S),
                      (c + s * 0.27 * S, 0.24 * S), 40)
        d.line([tuple(p) for p in stem], fill=gold_d, width=int(0.008 * S))
        for i in range(3, 38, 3):
            p = stem[i]
            q = stem[i + 1] - stem[i - 1]
            ang = np.degrees(np.arctan2(q[1], q[0]))
            for side in (-1, 1):
                lf = Image.new('RGBA', (int(0.07 * S), int(0.026 * S)), (0, 0, 0, 0))
                ImageDraw.Draw(lf).ellipse((0, 0, lf.width - 1, lf.height - 1), fill=gold if side > 0 else gold_d)
                put(im, lf, p[0] + side * 0.018 * S * np.cos(np.radians(ang + 90)),
                    p[1] + side * 0.018 * S * np.sin(np.radians(ang + 90)), 'mm', rot=-(ang + side * 35 * s))
    d = ImageDraw.Draw(im)
    # щит
    top, w, h = 0.25 * S, 0.44 * S, 0.56 * S
    outer = shield_poly(c, top - 0.018 * S, w + 0.036 * S, h + 0.04 * S)
    inner = shield_poly(c, top, w, h)
    d.polygon(outer, fill=gold)
    d.polygon(inner, fill=dark)
    chief = Image.new('L', (S, S), 0)
    ImageDraw.Draw(chief).polygon(inner, fill=255)
    ch_arr = np.asarray(chief).copy()
    ch_arr[int(top + 0.36 * h):] = 0
    im.paste(Image.new('RGBA', (S, S), bone), (0, 0), Image.fromarray(ch_arr))
    d = ImageDraw.Draw(im)
    yb = top + 0.36 * h
    xs = np.linspace(c - w / 2, c + w / 2, 9)
    ridge = [(c - w / 2, yb)]
    for i, x in enumerate(xs):
        ridge.append((x, yb - (0.05 + 0.13 * ((i * 7 + 3) % 5) / 4) * h * (1.4 if i == 4 else 1.0)))
    ridge.append((c + w / 2, yb))
    rmask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(rmask).polygon(ridge, fill=255)
    rm = np.minimum(np.asarray(rmask), ch_arr)
    im.paste(Image.new('RGBA', (S, S), ink), (0, 0), Image.fromarray(rm))
    d = ImageDraw.Draw(im)
    mx, my, mr = c - 0.12 * S, top + 0.085 * h, 0.03 * S
    d.ellipse((mx - mr, my - mr, mx + mr, my + mr), fill=ink)
    d.ellipse((mx - mr * 0.55, my - mr * 1.05, mx + mr * 1.4, my + mr * 0.8), fill=bone)
    d.line([(c - w / 2, yb), (c + w / 2, yb)], fill=gold, width=int(0.01 * S))
    for s in (-1, 1):
        put(im, key_layer(S, gold), c, top + 0.64 * h, 'mm', rot=36 * s)
    # надписи
    arc_text(im, 'BLACK RIDGE', font('serif-bold', int(0.078 * S)), c, 0.62 * S, 0.47 * S, -90, bone, track=1.04,
             stroke=int(0.006 * S), stroke_fill=ink)
    d = ImageDraw.Draw(im)
    rb = 0.82 * S
    for s in (-1, 1):
        d.polygon([(c + s * 0.2 * S, rb - 0.01 * S), (c + s * 0.36 * S, rb + 0.0 * S), (c + s * 0.32 * S, rb + 0.04 * S),
                   (c + s * 0.36 * S, rb + 0.08 * S), (c + s * 0.2 * S, rb + 0.07 * S)], fill=gold_d)
    ribbon = bezier((c - 0.3 * S, rb + 0.005 * S), (c - 0.1 * S, rb + 0.04 * S), (c + 0.1 * S, rb + 0.04 * S),
                    (c + 0.3 * S, rb + 0.005 * S), 50)
    d.polygon(taper(ribbon, 0.075 * S, 0.075 * S), fill=bone)
    d.line([tuple(p) for p in ribbon + [0, -0.034 * S]], fill=gold_d, width=int(0.005 * S))
    d.line([tuple(p) for p in ribbon + [0, 0.034 * S]], fill=gold_d, width=int(0.005 * S))
    put(im, text_img('CUSTODIA · ET · CURA', font('serif-bold', int(0.036 * S)), ink, spacing=int(0.004 * S)),
        c, rb + 0.033 * S, 'mm')
    put(im, text_img('STATE ASYLUM  ·  EST. 1911', font('serif-bold', int(0.032 * S)), bone, stroke=int(0.004 * S),
                     stroke_fill=ink, spacing=int(0.003 * S)), c, 0.935 * S, 'mm')
    im = im.resize((n, n), Image.LANCZOS)
    a = np.asarray(im).astype(float)
    wear = per_noise(n, n, rng, 2.0)
    specks = smoothstep(1.6, 2.4, wear) * 0.55 + smoothstep(2.8, 3.2, per_noise(n, n, rng, 0.8)) * 0.4
    a[..., 3] *= 1 - specks
    a[..., :3] *= (1 + 0.06 * per_noise(n, n, rng, 1.0))[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')


def halftone(g, cell=7.0, ang=45.0):
    # g: 0 — бело, 1 — черно; возвращает «чернила» 0..1
    h, w = g.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    a = np.radians(ang)
    u = (xx * np.cos(a) - yy * np.sin(a)) / cell
    v = (xx * np.sin(a) + yy * np.cos(a)) / cell
    du, dv = np.mod(u, 1) - 0.5, np.mod(v, 1) - 0.5
    dist = np.hypot(du, dv)
    rad = np.sqrt(np.clip(g, 0, 1) / np.pi) * 1.05
    return smoothstep(rad + 0.06, rad - 0.06, dist)


def xerox(rgb, rng, amt=1.0):
    h, w = rgb.shape[:2]
    sp = (rng.random((h, w)) > 1 - 0.0025 * amt).astype(float)
    sp = ndimage.gaussian_filter(sp, 0.7) * 3
    streak = np.repeat((rng.random((1, w)) > 0.985) * rng.uniform(0.04, 0.12, (1, w)), h, 0)
    edge = np.exp(-np.minimum.reduce([np.arange(w)[None, :].repeat(h, 0), w - 1 - np.arange(w)[None, :].repeat(h, 0),
                                      np.arange(h)[:, None].repeat(w, 1), h - 1 - np.arange(h)[:, None].repeat(w, 1)]) / (w * 0.02))
    dark = np.clip(sp + streak + 0.25 * edge * amt, 0, 1)[..., None]
    return rgb * (1 - dark) + 0.08 * dark


def moth_gray(h, w, rng):
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    u, v = (xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)
    g = np.zeros((h, w))
    for s in (-1, 1):
        for (cu, cv, ru, rv, ang, val) in ((0.45, -0.18, 0.55, 0.38, -20, 0.75), (0.32, 0.32, 0.36, 0.3, 25, 0.6)):
            a = np.radians(ang * s)
            du, dv = u - cu * s, v - cv
            x = du * np.cos(a) + dv * np.sin(a)
            y = -du * np.sin(a) + dv * np.cos(a)
            r = (x / ru) ** 2 + (y / rv) ** 2
            g = np.maximum(g, (r < 1) * (val * (0.6 + 0.4 * r)))
        er = np.hypot(u - 0.48 * s, v + 0.15)
        g = np.where(er < 0.16, 0.95, g)
        g = np.where(er < 0.1, 0.15, g)
        g = np.where(er < 0.05, 1.0, g)
        for k in range(4):
            vein = np.abs((u * s) * np.sin(0.35 + 0.25 * k) - (v + 0.05) * np.cos(0.35 + 0.25 * k))
            g = np.where((vein < 0.012) & (g > 0.2) & (u * s > 0.08), 0.95, g)
    body = ((u / 0.09) ** 2 + ((v - 0.05) / 0.5) ** 2) < 1
    g = np.where(body, 0.95, g)
    head = np.hypot(u, v + 0.48) < 0.08
    g = np.where(head, 1.0, g)
    for s in (-1, 1):
        ant = np.abs((u - s * 0.0) - s * (-(v + 0.5) * 0.9)) < 0.012
        g = np.where(ant & (v < -0.5) & (v > -0.85), 1.0, g)
    g = ndimage.gaussian_filter(g, 1.2)
    return g


def poster_paper(h, w, rng, col, amt=0.04):
    rgb = np.ones((h, w, 3)) * hexc(col)
    rgb *= (1 + amt * (0.5 * rng.standard_normal((h, w)) + per_noise(h, w, rng, 40)))[..., None]
    return rgb


def finish_poster(im, rng, fold=True, yellow=0.08, alpha_torn=None):
    a = np.asarray(im).astype(float) / 255.0
    rgb, al = a[..., :3], a[..., 3]
    h, w = al.shape
    rgb = rgb + yellow * (hexc('#c9b07a') - rgb) * (0.6 + 0.4 * per_noise(h, w, rng, 120)[..., None])
    if fold:
        for x in (w // 2,):
            prof = np.exp(-((np.arange(w) - x) / 1.6) ** 2)
            rgb *= (1 - 0.12 * prof)[None, :, None]
            rgb += 0.06 * np.exp(-((np.arange(w) - x - 3) / 2.0) ** 2)[None, :, None]
        for y in (h // 2, h // 4):
            prof = np.exp(-((np.arange(h) - y) / 1.6) ** 2)
            rgb *= (1 - 0.1 * prof)[:, None, None]
            rgb += 0.05 * np.exp(-((np.arange(h) - y - 3) / 2.0) ** 2)[:, None, None]
    scuff = np.clip(per_noise(h, w, rng, 2.5) - 2.3, 0, 1)
    rgb = rgb + 0.4 * scuff[..., None] * (1 - rgb)
    rgb *= (1 + 0.025 * rng.standard_normal((h, w)))[..., None]
    if alpha_torn is not None:
        al = al * alpha_torn
    return to_img(rgb, al)


def torn_edge_mask(h, w, rng, corner='br', size=0.18):
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    jag = per_noise(h, w, rng, 3) * 4 + per_noise(h, w, rng, 12) * 6
    if corner == 'br':
        dd = (w - xx) + (h - yy) * 0.6 - size * w
    else:
        dd = xx + (h - yy) * 0.6 - size * w
    return smoothstep(-1, 1, dd + jag)


def tape(w, h, rng, ang):
    t = Image.new('RGBA', (w, h), (232, 226, 200, 150))
    a = np.asarray(t).astype(float)
    a[..., 3] *= 0.85 + 0.15 * rng.random((h, w))
    a[:, :3, 3] *= rng.random((h, 3)) > 0.4
    a[:, -3:, 3] *= rng.random((h, 3)) > 0.4
    return Image.fromarray(a.astype(np.uint8), 'RGBA').rotate(ang, Image.BICUBIC, expand=True)


@img('Poster1', (512, 1024), 'Плакат группы (ксерокс на кислотно-жёлтой бумаге): MOTH CIRCUS, растровая бабочка-моль, '
     'машинописные строки, «вырезанные» буквы, скотч и оторванный угол. Пропорция 1:2.', kind='poster', alpha=True)
def i_poster1(rng, w, h):
    W, H = w * 2, h * 2
    rgb = poster_paper(H, W, rng, '#e6d544', 0.05)
    g = moth_gray(int(H * 0.33), int(W * 0.9), rng)
    ink = halftone(g, cell=11, ang=45)
    y0, x0 = int(H * 0.29), int(W * 0.05)
    reg = rgb[y0:y0 + ink.shape[0], x0:x0 + ink.shape[1]]
    reg *= (1 - 0.92 * ink[..., None])
    im = to_img(rgb, np.ones((H, W)))
    put(im, text_img('MOTH', font('sans-bold', int(W * 0.3)), (14, 14, 14, 255), sx=0.95, sy=1.35), W / 2, H * 0.025,
        'mt', rot=-2, max_w=W * 0.94)
    put(im, text_img('CIRCUS', font('sans-bold', int(W * 0.22)), (14, 14, 14, 255), sx=0.9, sy=1.2), W / 2, H * 0.178,
        'mt', rot=1.5, max_w=W * 0.95)
    tw = font('typewriter-bold', int(W * 0.052))
    lines = ['LIVE @ THE RUST ROOM', 'FRI 13 OCT 1995 / DOORS 9PM', 'w/ VELVET ANTENNA', '+ DOGWATCH']
    for i, ln in enumerate(lines):
        put(im, text_img(ln, tw, (16, 16, 16, 255)), W / 2, H * (0.64 + 0.045 * i), 'mt', rot=rng.uniform(-1, 1),
            max_w=W * 0.92)
    x = W * 0.12
    cols = [(240, 240, 235, 255), (20, 20, 20, 255), (220, 60, 60, 255), (250, 250, 250, 255)]
    for ch in '$5 ALL AGES':
        if ch == ' ':
            x += W * 0.04
            continue
        f = font(['sans-bold', 'serif-bold', 'mono-bold'][rng.integers(3)], int(W * rng.uniform(0.07, 0.09)))
        bgc = cols[rng.integers(len(cols))]
        fg = (20, 20, 20, 255) if bgc[0] > 200 else (245, 245, 240, 255)
        t = text_img(ch, f, fg)
        card = Image.new('RGBA', (t.width + 14, t.height + 14), bgc)
        card.alpha_composite(t, (7, 7))
        sz = put(im, card, x, H * 0.84, 'lm', rot=rng.uniform(-12, 12))
        x += sz[0] * 0.92
    put(im, text_img('NO COPS · NO CREEPS · BRING EARPLUGS', font('sans-bold', int(W * 0.032)), (20, 20, 20, 255)),
        W / 2, H * 0.92, 'mt', max_w=W * 0.9)
    a = np.asarray(im).astype(float) / 255.0
    rgb = xerox(a[..., :3], rng, 1.0)
    im = to_img(rgb, a[..., 3])
    put(im, tape(int(W * 0.22), int(W * 0.07), rng, 0), W * 0.1, H * 0.01, 'mt', rot=30)
    put(im, tape(int(W * 0.22), int(W * 0.07), rng, 0), W * 0.9, H * 0.01, 'mt', rot=-25)
    im = im.resize((w, h), Image.LANCZOS)
    return finish_poster(im, rng, fold=False, yellow=0.06, alpha_torn=torn_edge_mask(h, w, rng, 'br', 0.16))


@img('Poster2', (512, 1024), 'Постер фильма ужасов 1996 г. «THE QUIET CUL-DE-SAC»: луна, силуэты домов с одним горящим окном, '
     'фигура под фонарём, слоган, титры. Сгибы, выцветание. Пропорция 1:2.', kind='poster', alpha=False)
def i_poster2(rng, w, h):
    W, H = w * 2, h * 2
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    t = yy / H
    sky = np.stack([np.interp(t, [0, 0.35, 0.58, 0.66], c) for c in
                    ([0.03, 0.12, 0.55, 0.75], [0.04, 0.05, 0.13, 0.25], [0.12, 0.16, 0.14, 0.1])], -1)
    rgb = sky.copy()
    stars = (rng.random((H, W)) > 0.9993) * (t < 0.4)
    rgb += ndimage.gaussian_filter(stars.astype(float), 0.8)[..., None] * 3
    mx, my, mr = W * 0.64, H * 0.3, W * 0.21
    dist = np.hypot(xx - mx, yy - my)
    glow = np.exp(-np.maximum(dist - mr, 0) / (W * 0.12)) * 0.35
    rgb += glow[..., None] * hexc('#f2c9a0')
    moon = smoothstep(mr + 1.5, mr - 1.5, dist)
    crat = 1 - 0.1 * np.clip(per_noise(H, W, rng, 30), 0, None) - 0.05 * per_noise(H, W, rng, 70)
    rgb = rgb * (1 - moon[..., None]) + (hexc('#efe4c8') * crat[..., None]) * moon[..., None]
    im = to_img(rgb)
    d = ImageDraw.Draw(im)
    base = H * 0.66
    x = -W * 0.05
    sil = (8, 8, 12)
    windows = []
    while x < W * 1.05:
        bw = W * rng.uniform(0.22, 0.34)
        bh = H * rng.uniform(0.05, 0.08)
        rh = bw * rng.uniform(0.3, 0.45)
        d.rectangle((x, base - bh, x + bw, base + 2), fill=sil)
        d.polygon([(x - bw * 0.05, base - bh), (x + bw / 2, base - bh - rh), (x + bw * 1.05, base - bh)], fill=sil)
        if rng.random() < 0.5:
            d.rectangle((x + bw * 0.7, base - bh - rh * 0.9, x + bw * 0.78, base - bh - rh * 0.3), fill=sil)
        windows.append((x + bw * 0.3, base - bh * 0.7, bw))
        x += bw + W * rng.uniform(0.02, 0.06)
    wx, wy, bw = windows[min(2, len(windows) - 1)]
    d.rectangle((wx, wy, wx + bw * 0.16, wy + bw * 0.18), fill=(255, 206, 110))
    d.line([(wx + bw * 0.08, wy), (wx + bw * 0.08, wy + bw * 0.18)], fill=sil, width=3)
    d.rectangle((0, base, W, H), fill=(14, 12, 16))
    lx = W * 0.2
    d.rectangle((lx - 4, base - H * 0.16, lx + 4, base + H * 0.06), fill=(6, 6, 8))
    d.line([(lx, base - H * 0.16), (lx + W * 0.06, base - H * 0.165)], fill=(6, 6, 8), width=7)
    a = np.asarray(im).astype(float) / 255.0
    cone = np.clip(1 - np.abs(xx - (lx + W * 0.06)) / (W * 0.04 + (yy - (base - H * 0.16)) * 0.35), 0, 1)
    cone *= (yy > base - H * 0.16) * (yy < base + H * 0.07) * 0.35
    win_glow = np.exp(-np.hypot(xx - wx - bw * 0.08, yy - wy - bw * 0.09) / (W * 0.03)) * 0.5
    a[..., :3] += cone[..., None] * hexc('#ffd28a') + win_glow[..., None] * hexc('#ffb347')
    im = to_img(a[..., :3])
    d = ImageDraw.Draw(im)
    fx, fy = lx + W * 0.13, base + H * 0.07
    fh = H * 0.12
    d.ellipse((fx - fh * 0.06, fy - fh, fx + fh * 0.06, fy - fh * 0.86), fill=(2, 2, 3))
    d.polygon([(fx - fh * 0.09, fy - fh * 0.85), (fx + fh * 0.09, fy - fh * 0.85), (fx + fh * 0.07, fy - fh * 0.35),
               (fx - fh * 0.07, fy - fh * 0.35)], fill=(2, 2, 3))
    d.line([(fx - fh * 0.08, fy - fh * 0.82), (fx - fh * 0.16, fy - fh * 0.3)], fill=(2, 2, 3), width=int(fh * 0.04))
    d.line([(fx + fh * 0.08, fy - fh * 0.82), (fx + fh * 0.15, fy - fh * 0.32)], fill=(2, 2, 3), width=int(fh * 0.04))
    for s in (-1, 1):
        d.line([(fx + s * fh * 0.04, fy - fh * 0.36), (fx + s * fh * 0.06, fy)], fill=(2, 2, 3), width=int(fh * 0.05))
    im = im.convert('RGBA')
    put(im, text_img('LOCK THE DOOR.  THEN LOCK IT AGAIN.', font('sans', int(W * 0.036)), (230, 225, 215, 255),
                     spacing=int(W * 0.006)), W / 2, H * 0.035, 'mt', max_w=W * 0.92)
    put(im, text_img('THE QUIET', font('serif-bold', int(W * 0.075)), (236, 228, 210, 255), spacing=int(W * 0.02)),
        W / 2, H * 0.735, 'mt')
    title = text_img('CUL-DE-SAC', font('serif-bold', int(W * 0.17)), (240, 232, 214, 255), sx=0.92, sy=1.25)
    glow = Image.new('RGBA', (title.width + 60, title.height + 60), (0, 0, 0, 0))
    gl = title.copy()
    gl = Image.fromarray(np.dstack([np.full(gl.size[::-1] + (3,), (200, 30, 20), np.uint8), np.asarray(gl)[..., 3]]), 'RGBA')
    glow.alpha_composite(gl, (30, 30))
    glow = glow.filter(ImageFilter.GaussianBlur(14))
    put(im, glow, W / 2, H * 0.775 - 30, 'mt', max_w=W * 0.98 + 60)
    put(im, title, W / 2, H * 0.775, 'mt', max_w=W * 0.94)
    bf = font('sans-bold', int(W * 0.03))
    billing = ['MAPLE GROVE PICTURES PRESENTS A HOLLIS WEBB FILM  "THE QUIET CUL-DE-SAC"',
               'DANA ORLOV  MARCUS TEAGUE  JUNE ABERNATHY  AND OTIS GRAY AS "THE NEIGHBOR"',
               'MUSIC BY LEN KOVACS  EDITED BY RUTH SALAZAR  WRITTEN AND DIRECTED BY HOLLIS WEBB']
    for i, ln in enumerate(billing):
        put(im, text_img(ln, bf, (170, 160, 160, 255), sx=0.5, sy=1.3), W / 2, H * (0.875 + 0.022 * i), 'mt',
            max_w=W * 0.9)
    put(im, text_img('THIS OCTOBER', font('sans-bold', int(W * 0.05)), (220, 60, 45, 255), spacing=int(W * 0.012)),
        W / 2, H * 0.95, 'mt')
    rb = Image.new('RGBA', (int(W * 0.07), int(W * 0.08)), (0, 0, 0, 0))
    ImageDraw.Draw(rb).rectangle((0, 0, rb.width - 1, rb.height - 1), outline=(170, 160, 160, 255), width=3)
    put(rb, text_img('R', font('sans-bold', int(W * 0.06)), (170, 160, 160, 255)), rb.width / 2, rb.height / 2, 'mm')
    put(im, rb, W * 0.92, H * 0.955, 'mm')
    im = im.resize((w, h), Image.LANCZOS)
    a = np.asarray(im).astype(float) / 255.0
    a[..., :3] = a[..., :3] * 0.92 + 0.04
    return finish_poster(to_img(a[..., :3], np.ones((h, w))), rng, fold=True, yellow=0.07).convert('RGB')


def dog_photo(h, w, rng):
    S = Image.new('RGB', (w, h), (190, 200, 175))
    d = ImageDraw.Draw(S)
    d.rectangle((0, 0, w, h * 0.45), fill=(235, 235, 230))
    d.rectangle((0, h * 0.3, w, h * 0.45), fill=(205, 200, 190))
    for i in range(0, w, w // 10):
        d.rectangle((i, h * 0.18, i + w * 0.03, h * 0.45), fill=(150, 146, 135))
    d.rectangle((0, h * 0.22, w, h * 0.25), fill=(150, 146, 135))
    gold, dk = (150, 105, 55), (80, 50, 25)
    cx, cy = w * 0.5, h * 0.62
    d.ellipse((cx - w * 0.3, cy - h * 0.16, cx + w * 0.22, cy + h * 0.12), fill=gold)
    for lx in (-0.24, -0.12, 0.08, 0.16):
        d.rectangle((cx + lx * w, cy, cx + (lx + 0.06) * w, cy + h * 0.3), fill=gold)
        d.ellipse((cx + lx * w - 4, cy + h * 0.27, cx + (lx + 0.07) * w, cy + h * 0.32), fill=dk)
    d.polygon([(cx - w * 0.28, cy - h * 0.08), (cx - w * 0.45, cy - h * 0.3), (cx - w * 0.4, cy - h * 0.32),
               (cx - w * 0.25, cy - h * 0.12)], fill=gold)
    hx, hy = cx + w * 0.22, cy - h * 0.2
    d.ellipse((hx - w * 0.13, hy - h * 0.13, hx + w * 0.13, hy + h * 0.12), fill=gold)
    d.ellipse((hx + w * 0.03, hy - h * 0.01, hx + w * 0.24, hy + h * 0.1), fill=(175, 130, 80))
    d.ellipse((hx + w * 0.19, hy + h * 0.0, hx + w * 0.25, hy + h * 0.05), fill=(30, 25, 20))
    d.polygon([(hx - w * 0.1, hy - h * 0.08), (hx - w * 0.17, hy + h * 0.12), (hx - w * 0.06, hy + h * 0.1)], fill=dk)
    d.ellipse((hx + w * 0.02, hy - h * 0.06, hx + w * 0.06, hy - h * 0.02), fill=(20, 18, 15))
    d.rectangle((hx - w * 0.12, hy + h * 0.08, hx + w * 0.02, hy + h * 0.12), fill=(170, 30, 30))
    d.polygon([(hx + w * 0.12, hy + h * 0.09), (hx + w * 0.17, hy + h * 0.16), (hx + w * 0.2, hy + h * 0.09)], fill=(200, 90, 100))
    a = np.asarray(S).astype(float) / 255.0
    a = ndimage.gaussian_filter(a, (1.5, 1.5, 0))
    g = 1 - (0.3 * a[..., 0] + 0.59 * a[..., 1] + 0.11 * a[..., 2])
    g += 0.03 * per_noise(h, w, rng, 3)
    return np.clip((g - 0.12) * 1.4, 0, 1)


@img('Poster3', (512, 1024), 'Листовка «LOST DOG»: ксерокопия с фото пса Бисквита, приметы, телефон 555-0143, награда, '
     'красная надпись маркером STILL MISSING, отрывные язычки (двух нет), скотч. Пропорция 1:2.', kind='poster', alpha=True)
def i_poster3(rng, w, h):
    W, H = w * 2, h * 2
    rgb = poster_paper(H, W, rng, '#f1efe6', 0.025)
    ph_h, ph_w = int(H * 0.28), int(W * 0.84)
    g = dog_photo(ph_h, ph_w, rng)
    ink = halftone(g, cell=5, ang=45) * 0.75 + 0.25 * smoothstep(0.5, 0.65, g)
    y0, x0 = int(H * 0.17), int(W * 0.08)
    rgb[y0:y0 + ph_h, x0:x0 + ph_w] *= (1 - 0.9 * np.clip(ink, 0, 1))[..., None]
    rgb[y0 - 4:y0 + ph_h + 4, x0 - 4:x0] *= 0.15
    rgb[y0 - 4:y0 + ph_h + 4, x0 + ph_w:x0 + ph_w + 4] *= 0.15
    rgb[y0 - 4:y0, x0 - 4:x0 + ph_w + 4] *= 0.15
    rgb[y0 + ph_h:y0 + ph_h + 4, x0 - 4:x0 + ph_w + 4] *= 0.15
    im = to_img(rgb, np.ones((H, W)))
    put(im, text_img('LOST DOG', font('sans-bold', int(W * 0.2)), (12, 12, 12, 255), sx=0.9, sy=1.5), W / 2, H * 0.03,
        'mt', max_w=W * 0.92)
    tw = font('sans-bold', int(W * 0.05))
    tr = font('sans', int(W * 0.04))
    rows = [('ANSWERS TO "BISCUIT"', tw), ('Golden retriever mix, 6 yrs old', tr), ('Red collar. Very friendly.', tr),
            ('Last seen Oct 2 near Maple Ct.', tr), ('He is afraid of the dark.', tr), ('PLEASE CALL 555-0143', tw),
            ('$100 REWARD', font('sans-bold', int(W * 0.08)))]
    y = H * 0.47
    for txt, f in rows:
        sz = put(im, text_img(txt, f, (16, 16, 16, 255)), W / 2, y, 'mt', max_w=W * 0.9)
        y += sz[1] + H * 0.008
    tab_y = H * 0.84
    d = ImageDraw.Draw(im)
    for x in range(0, W, 14):
        d.line([(x, tab_y), (x + 7, tab_y)], fill=(60, 60, 60, 255), width=2)
    k = 8
    tw2 = W / k
    tf = font('sans-bold', int(W * 0.03))
    for i in range(k):
        x = i * tw2
        if i:
            for yy in range(int(tab_y), H, 14):
                d.line([(x, yy), (x, yy + 7)], fill=(60, 60, 60, 255), width=2)
        put(im, text_img('BISCUIT  555-0143', tf, (16, 16, 16, 255)), x + tw2 / 2, tab_y + (H - tab_y) / 2, 'mm', rot=90)
    a = np.asarray(im).astype(float) / 255.0
    rgb = xerox(a[..., :3], rng, 0.8)
    im = to_img(rgb, a[..., 3])
    mk = text_img('STILL MISSING', font('sans-bold', int(W * 0.12)), (200, 25, 30, 235), sx=0.8, sy=1.1)
    m = np.asarray(mk).astype(float)
    m[..., 3] *= 0.75 + 0.25 * rng.random(m.shape[:2])
    mk = Image.fromarray(m.astype(np.uint8), 'RGBA')
    put(im, mk, W * 0.5, H * 0.31, 'mm', rot=17, max_w=W * 0.95)
    put(im, tape(int(W * 0.3), int(W * 0.08), rng, 0), W / 2, -H * 0.005, 'mt', rot=-3)
    im = im.resize((w, h), Image.LANCZOS)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    alpha = np.ones((h, w))
    ty = int(h * 0.84) + 1
    jag = per_noise(h, w, rng, 2) * 2
    for i in (2, 5):
        x0, x1 = i * w / k, (i + 1) * w / k
        torn = (xx > x0 + 0.5) & (xx < x1 - 0.5) & (yy > ty + 6 + jag)
        alpha[torn] = 0
    return finish_poster(im, rng, fold=False, yellow=0.05, alpha_torn=alpha)


@img('FamilyPhoto', 512, 'Семейное фото (живописное, размытое, без реальных людей): папа, мама и двое детей на заднем '
     'дворе у сайдинга, цвета плёнки 90-х, виньетка, засветка и оранжевая дата «96 7 14».', kind='decal')
def i_family(rng, n):
    S = n * 2
    im = Image.new('RGB', (S, S), (150, 185, 210))
    d = ImageDraw.Draw(im)
    for i in range(0, int(S * 0.62), int(S * 0.035)):
        d.rectangle((0, i, S, i + S * 0.03), fill=(214, 206, 186))
        d.line([(0, i + S * 0.03), (S, i + S * 0.03)], fill=(150, 140, 120), width=4)
    d.rectangle((S * 0.62, S * 0.12, S * 0.9, S * 0.4), fill=(70, 80, 90))
    d.rectangle((S * 0.6, S * 0.1, S * 0.92, S * 0.42), outline=(240, 238, 230), width=14)
    d.rectangle((S * 0.05, S * 0.08, S * 0.18, S * 0.62), fill=(120, 60, 50))
    d.rectangle((0, S * 0.62, S, S), fill=(88, 128, 64))
    d.ellipse((-S * 0.2, S * 0.5, S * 0.35, S * 0.72), fill=(60, 100, 45))
    skin = [(232, 190, 160), (214, 168, 132), (238, 200, 170), (198, 150, 115)]
    people = [  # x, высота, ширина, рубашка, низ, волосы
        (0.3, 0.62, 0.15, (40, 90, 160), (190, 170, 130), (90, 60, 40)),
        (0.5, 0.56, 0.14, (30, 140, 140), (60, 70, 120), (130, 80, 40)),
        (0.67, 0.4, 0.11, (200, 50, 50), (70, 90, 150), (180, 130, 70)),
        (0.82, 0.32, 0.1, (240, 200, 60), (240, 200, 60), (200, 160, 90)),
    ]
    ground = S * 0.93
    for i, (px, ph, pwd, shirt, low, hair) in enumerate(people):
        x = px * S
        hgt = ph * S
        wd = pwd * S
        top = ground - hgt
        head = hgt * 0.15
        sk = skin[i]
        d.rounded_rectangle((x - wd * 0.28, top + head * 1.8 + hgt * 0.36, x + wd * 0.28, ground), radius=int(wd * 0.1), fill=low)
        if i == 3:
            d.polygon([(x - wd * 0.5, top + hgt * 0.75), (x + wd * 0.5, top + hgt * 0.75), (x + wd * 0.28, top + head * 1.6),
                       (x - wd * 0.28, top + head * 1.6)], fill=shirt)
            d.rectangle((x - wd * 0.2, top + hgt * 0.75, x + wd * 0.2, ground), fill=sk)
        d.rounded_rectangle((x - wd * 0.5, top + head * 1.6, x + wd * 0.5, top + head * 1.8 + hgt * 0.38), radius=int(wd * 0.25), fill=shirt)
        for s in (-1, 1):
            d.line([(x + s * wd * 0.45, top + head * 2.0), (x + s * wd * 0.62, top + hgt * 0.55)], fill=shirt, width=int(wd * 0.2))
            d.ellipse((x + s * wd * 0.62 - wd * 0.08, top + hgt * 0.55 - wd * 0.06, x + s * wd * 0.62 + wd * 0.08, top + hgt * 0.55 + wd * 0.1), fill=sk)
        d.rectangle((x - wd * 0.1, top + head * 1.3, x + wd * 0.1, top + head * 1.8), fill=sk)
        hr = (1.25 if i == 1 else 1.0)
        d.ellipse((x - head * 0.62 * hr, top - head * 0.15, x + head * 0.62 * hr, top + head * (1.25 if i == 1 else 0.9)), fill=hair)
        d.ellipse((x - head * 0.48, top + head * 0.05, x + head * 0.48, top + head * 1.42), fill=sk)
        d.ellipse((x - head * 0.5, top - head * 0.05, x + head * 0.5, top + head * 0.45), fill=hair)
        for s in (-1, 1):
            d.ellipse((x + s * head * 0.2 - head * 0.06, top + head * 0.7, x + s * head * 0.2 + head * 0.06, top + head * 0.8), fill=(90, 60, 50))
        d.arc((x - head * 0.2, top + head * 0.85, x + head * 0.2, top + head * 1.15), 20, 160, fill=(150, 80, 70), width=6)
        if i == 2:
            d.chord((x - head * 0.55, top - head * 0.2, x + head * 0.55, top + head * 0.5), 180, 360, fill=(30, 60, 140))
            d.rectangle((x, top + head * 0.1, x + head * 0.8, top + head * 0.25), fill=(30, 60, 140))
    a = np.asarray(im).astype(float) / 255.0
    a = ndimage.gaussian_filter(a, (3, 3, 0))
    # «живописные» мазки: цвет берётся из картинки
    out = Image.fromarray((a * 255).astype(np.uint8))
    dd = ImageDraw.Draw(out)
    for _ in range(9000):
        x, y = rng.uniform(0, S, 2)
        c = tuple(int(v * 255) for v in a[int(y), int(x)])
        L = rng.uniform(6, 18)
        ang = rng.normal(0.4, 0.5)
        dx, dy = np.cos(ang) * L, np.sin(ang) * L
        dd.line([(x - dx, y - dy), (x + dx, y + dy)], fill=c, width=int(rng.uniform(4, 8)))
    a = np.asarray(out).astype(float) / 255.0
    a = ndimage.gaussian_filter(a, (2.2, 2.2, 0))
    a = down2(a)
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    r = np.hypot(xx / n - 0.5, yy / n - 0.48)
    a *= (1.12 - 0.9 * r ** 2)[..., None]
    a = a ** 0.95 * 0.86 + 0.08
    a[..., 0] *= 1.06
    a[..., 2] *= 0.88
    leak = np.exp(-((xx - n * 1.02) ** 2 + (yy - n * 0.2) ** 2) / (2 * (n * 0.18) ** 2))
    a += leak[..., None] * np.array([0.45, 0.18, 0.02])
    a += 0.035 * rng.standard_normal((n, n, 1))
    lum = a.mean(-1, keepdims=True)
    a = lum + (a - lum) * 0.85
    im = to_img(a).convert('RGBA')
    ds = text_img("'96  7 14", font('mono-bold', int(n * 0.05)), (255, 150, 40, 255))
    glow = ds.filter(ImageFilter.GaussianBlur(3))
    put(im, glow, n * 0.93, n * 0.95, 'rb')
    put(im, ds, n * 0.93, n * 0.95, 'rb')
    return im.convert('RGB')


# =====================================================================================
# Превью, MANIFEST.md, запуск
# =====================================================================================

def image_preview(path_out):
    cols, cw, chh, lh = 5, 256, 256, 34
    items = [s for s in IMAGES if os.path.exists(os.path.join(IMG_DIR, s['key'] + '.png'))]
    rows = (len(items) + cols - 1) // cols
    W, H = cols * (cw + 16) + 16, rows * (chh + lh + 16) + 56
    sheet = Image.new('RGB', (W, H), (26, 26, 30))
    d = ImageDraw.Draw(sheet)
    d.text((16, 14), 'Amber Alert — текстуры (тайлы показаны 2×2 для проверки швов; прозрачные — на шахматке)',
           fill=(235, 235, 235), font=font('sans', 20))
    lf = font('mono', 13)
    chk = Image.new('RGB', (cw, chh))
    cd = ImageDraw.Draw(chk)
    for y in range(0, chh, 16):
        for x in range(0, cw, 16):
            cd.rectangle((x, y, x + 15, y + 15), fill=(200, 200, 200) if (x + y) // 16 % 2 else (150, 150, 150))
    for i, s in enumerate(items):
        x0 = 16 + (i % cols) * (cw + 16)
        y0 = 56 + (i // cols) * (chh + lh + 16)
        im = Image.open(os.path.join(IMG_DIR, s['key'] + '.png'))
        w, h = im.size
        cell = chk.copy() if im.mode == 'RGBA' else Image.new('RGB', (cw, chh), (26, 26, 30))
        if s['kind'] == 'tile':
            t = im.convert('RGB').resize((cw // 2, chh // 2), Image.LANCZOS)
            for dx in (0, cw // 2):
                for dy in (0, chh // 2):
                    cell.paste(t, (dx, dy))
        else:
            sc = min(cw / w, chh / h)
            t = im.convert('RGBA').resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS)
            cell.paste(t, ((cw - t.width) // 2, (chh - t.height) // 2), t)
        sheet.paste(cell, (x0, y0))
        d.text((x0, y0 + chh + 4), s['key'], fill=(240, 240, 240), font=lf)
        d.text((x0, y0 + chh + 19), '%dx%d %s %dKB' % (w, h, im.mode, os.path.getsize(os.path.join(IMG_DIR, s['key'] + '.png')) // 1024),
               fill=(160, 160, 170), font=lf)
    sheet.save(path_out, optimize=True)


def config_keys(section):
    try:
        txt = open(CONFIG_LUA, encoding='utf-8').read()
    except OSError:
        return []
    m = re.search(r'Config\.%s\s*=\s*\{(.*?)\n\}' % section, txt, re.S)
    if not m:
        return []
    body = re.sub(r'--[^\n]*', '', m.group(1))
    return re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*=', body)


def fmt_kb(b):
    return '%.0f КБ' % (b / 1024) if b < 1024 * 1024 else '%.1f МБ' % (b / 1048576)


PRIORITY = ['EasTone', 'Jumpscare', 'AmbientNight', 'DoorBash', 'GlassBreak', 'Heartbeat', 'Stinger', 'Static',
            'WallpaperLiving', 'WallpaperBedroom', 'WallpaperKids']


def write_manifest(sinfo):
    L = []
    L.append('# Ассеты Amber Alert — звуки и текстуры\n')
    L.append('Все файлы сгенерированы процедурно скриптом `tools/gen_assets.py` (синтез, шум, свёртка с синтетическими '
             'импульсными откликами комнат; рисование узоров с периодическим шумом). Никаких чужих записей, шрифтовых '
             'логотипов и реальных эмблем: эмблемы EAS и Black Ridge нарисованы с нуля.\n')
    L.append('Перегенерировать: `python3 tools/gen_assets.py` (нужны numpy, scipy, Pillow и ffmpeg с libvorbis). '
             'Только часть: `--only sounds|images`, `--keys EasTone,Carpet`. Результат детерминирован.\n')
    L.append('Превью: `preview.png` (картинки, тайлы 2×2) и `preview_audio.png` (спектрограммы всех звуков).\n')
    L.append('## Как загрузить в Roblox\n')
    L.append('1. Studio → **View → Asset Manager → Bulk Import** (кнопка импорта), выбрать файлы из `assets/sounds` и '
             '`assets/images`. Либо Creator Hub → **Development Items → Audio / Decals → Upload**.')
    L.append('2. После модерации: в Asset Manager ПКМ по ассету → **Copy Asset ID** (для картинок копируйте ID '
             '*изображения*; если грузили как Decal через сайт — вставьте Decal в Studio и возьмите число из его '
             'свойства `Texture`, оно отличается от ID декали).')
    L.append('3. Вставить ID в `ReplicatedStorage → Shared → Config`: `Config.Sounds.EasTone = "1234567890"`, '
             '`Config.Images.Carpet = "1234567890"` (только цифры). Пустая строка = звук/текстура не используется.\n')
    L.append('**Ограничения аудио** (на момент генерации, проверяйте в Creator Hub): `.ogg/.mp3/.wav/.flac`, до 7 минут и '
             'до 20 МБ на файл; квота — около 10 аудио в месяц без подтверждения личности и около 100 в месяц с '
             'подтверждённым ID (ID Verification). Каждый звук проходит модерацию. Аудио по умолчанию приватно: '
             'загружайте от того же аккаунта/группы, которой принадлежит место, иначе звук не заиграет. '
             'Картинки: до 1024×1024, PNG с альфой поддерживается.\n')
    L.append('**Что грузить в первую очередь** (максимум эффекта при маленькой квоте): ' +
             ', '.join('`%s`' % k for k in PRIORITY) + '. Потом — `DoorBreak`, `DoorOpen`, `AmbientHouse`, `TvNews`, '
             '`EasNoise`, `Whisper`, `Breath`, `Footstep`, а дальше всё остальное.\n')
    L.append('Петли (`Looped = true`) собраны бесшовно «по кругу» (шум, фильтры и реверберация замкнуты), формат Ogg '
             'Vorbis не добавляет паузы на стыке (в отличие от MP3). Все файлы нормализованы до −1 dBFS по пику, '
             'поэтому громкость в игре задаётся свойством `Volume` (рекомендации ниже).\n')
    L.append('## Звуки (`assets/sounds`, Ogg Vorbis 44.1 кГц)\n')
    L.append('| Ключ Config | Файл | Длительность / размер | Описание | Рекомендуемые свойства |')
    L.append('|---|---|---|---|---|')
    for s in SOUNDS:
        p = os.path.join(SND_DIR, s['key'] + '.ogg')
        info = sinfo.get(s['key'])
        if not info:
            continue
        props = 'Volume %.2f' % s['vol']
        props += ', Looped = true' if s['loop'] else ''
        if s['roll']:
            props += ', RollOffMinDistance %d, RollOffMaxDistance %d' % s['roll']
        if s['key'] == 'Heartbeat':
            props += ', PlaybackSpeed 1.0–1.6 по опасности'
        if s['key'].startswith('Footstep'):
            props += ', PlaybackSpeed 0.9–1.1 случайно'
        dur = '%.2f с · %s · %s' % (info['dur'], 'стерео' if info['ch'] == 2 else 'моно', fmt_kb(info['size']))
        L.append('| `%s` | `sounds/%s.ogg` | %s | %s | %s |' % (s['key'], s['key'], dur, s['desc'], props))
    L.append('\nВарианты `Footstep2…4` в `Config` нет — их можно добавить ключами `Footstep2`, `Footstep3`, `Footstep4` '
             'и выбирать случайно.\n')
    L.append('Готовая таблица громкостей (можно вставить в `Config.lua` и применять в `Sound.play`, если `props.Volume` '
             'не задан):\n')
    L.append('```lua')
    L.append('Config.SoundVolume = {')
    row = []
    for s in SOUNDS:
        row.append('%s = %.2f' % (s['key'], s['vol']))
        if len(row) == 6:
            L.append('\t' + ', '.join(row) + ',')
            row = []
    if row:
        L.append('\t' + ', '.join(row) + ',')
    L.append('}')
    L.append('```\n')
    L.append('## Картинки (`assets/images`, PNG)\n')
    L.append('| Ключ Config | Файл | Размер | Описание | Рекомендуемые свойства |')
    L.append('|---|---|---|---|---|')
    for s in IMAGES:
        p = os.path.join(IMG_DIR, s['key'] + '.png')
        if not os.path.exists(p):
            continue
        w, h = img_size(s)
        size = '%d×%d %s · %s' % (w, h, 'RGBA' if s['alpha'] else 'RGB', fmt_kb(os.path.getsize(p)))
        if s['kind'] == 'tile':
            props = 'Texture, бесшовный: StudsPerTileU = %d, StudsPerTileV = %d' % s['studs']
            if s['key'] in ('Siding',):
                props += '; Color3 для оттенка'
            if s['key'] == 'TvStatic':
                props += '; анимировать OffsetStudsU/V каждый кадр'
        elif s['kind'] == 'poster':
            props = 'Decal на грань 2×4 (ширина×высота) студа, пропорция 1:2'
        elif s['kind'] == 'overlay':
            props = 'ImageLabel на весь экран, BackgroundTransparency = 1' + (
                ', ScaleType = Tile, TileSize = UDim2.fromOffset(256, 256)' if s['key'] == 'Grain' else
                ', ScaleType = Stretch, ImageTransparency 0–0.3')
        else:
            props = 'Decal (или ImageLabel в SurfaceGui), квадратная грань'
            if s['key'] == 'FamilyPhoto':
                props = 'Decal на квадратную грань в рамке (например 2×2 студа)'
        L.append('| `%s` | `images/%s.png` | %s | %s | %s |' % (s['key'], s['key'], size, s['desc'], props))
    tot_s = sum(os.path.getsize(os.path.join(SND_DIR, f)) for f in os.listdir(SND_DIR)) if os.path.isdir(SND_DIR) else 0
    tot_i = sum(os.path.getsize(os.path.join(IMG_DIR, f)) for f in os.listdir(IMG_DIR)) if os.path.isdir(IMG_DIR) else 0
    L.append('\nИтого: звуки %s, картинки %s.\n' % (fmt_kb(tot_s), fmt_kb(tot_i)))
    L.append('## Заметки\n')
    L.append('- `EasTone`: настоящая структура сигнала EAS (заголовок AFSK 520.83 бод, 853+960 Гц ~8 с, три EOM), '
             'но байты заголовка случайные — реальные приёмники EAS его не распознают. Не транслируйте в эфир.')
    L.append('- `TvNews` ровно 16 тактов при 128 BPM (30 с): фанфара на «раз», дробь литавр в конце ведёт обратно в '
             'начало — можно зацикливать весь день. Тембр «из динамика ТВ», лучше вешать на корпус телевизора (3D).')
    L.append('- Амбиенты стерео: проигрывайте их в 2D (`Sound.loop(key, nil, ...)`, родитель — SoundService). '
             'Остальные звуки моно для 3D-позиционирования.')
    L.append('- Постеры 512×1024 (1:2): если грань другой пропорции, картинка растянется.')
    open(os.path.join(ASSETS, 'MANIFEST.md'), 'w', encoding='utf-8').write('\n'.join(L) + '\n')


def analyze_sounds(verbose=True):
    res = {}
    for s in SOUNDS:
        p = os.path.join(SND_DIR, s['key'] + '.ogg')
        if os.path.exists(p):
            res[s['key']] = analyze_sound(p, s['loop'])
    if verbose and res:
        print('\n  %-16s %7s %3s %7s %7s %8s  %s' % ('звук', 'сек', 'кан', 'пик дБ', 'RMS дБ', 'размер', 'стык петли'))
        for k, v in res.items():
            seam = ''
            if 'seam_hf_ratio' in v:
                seam = 'ВЧ на стыке: %3.0f-й процентиль (x%.2f к P99), скачок %2.0f%%-иль, уровень %+.1f дБ' % (
                    v['seam_rank'], v['seam_hf_ratio'], v['jump_pct'], v['level_step_db'])
            print('  %-16s %7.2f %3d %7.2f %7.1f %8s  %s' % (k, v['dur'], v['ch'], v['peak_db'], v['rms_db'],
                                                            fmt_kb(v['size']), seam))
    return res


def check_coverage():
    ok = True
    have_s = {s['key'] for s in SOUNDS}
    have_i = {s['key'] for s in IMAGES}
    for k in config_keys('Sounds'):
        if k not in have_s:
            print('  ВНИМАНИЕ: нет генератора для Config.Sounds.%s' % k)
            ok = False
    for k in config_keys('Images'):
        if k not in have_i:
            print('  ВНИМАНИЕ: нет генератора для Config.Images.%s' % k)
            ok = False
    return ok


def main():
    ap = argparse.ArgumentParser(description='Генератор звуков и текстур Amber Alert')
    ap.add_argument('--only', choices=['sounds', 'images'])
    ap.add_argument('--keys', help='через запятую')
    ap.add_argument('--check', action='store_true', help='только анализ, превью и MANIFEST')
    ap.add_argument('--no-preview', action='store_true')
    a = ap.parse_args()
    keys = set(a.keys.split(',')) if a.keys else None
    need_ffmpeg()
    os.makedirs(ASSETS, exist_ok=True)
    check_coverage()
    t0 = time.time()
    if not a.check:
        if a.only != 'images':
            print('Звуки:')
            gen_sounds(keys)
        if a.only != 'sounds':
            print('Картинки:')
            gen_images(keys)
    sinfo = analyze_sounds()
    write_manifest(sinfo)
    if not a.no_preview:
        image_preview(os.path.join(ASSETS, 'preview.png'))
        items = [(s['key'], os.path.join(SND_DIR, s['key'] + '.ogg'), sinfo[s['key']]) for s in SOUNDS if s['key'] in sinfo]
        audio_preview(os.path.join(ASSETS, 'preview_audio.png'), items)
    tot = 0
    for r, _, fs in os.walk(ASSETS):
        tot += sum(os.path.getsize(os.path.join(r, f)) for f in fs)
    print('\nГотово за %.0f с. Папка assets: %s' % (time.time() - t0, fmt_kb(tot)))


if __name__ == '__main__':
    main()
