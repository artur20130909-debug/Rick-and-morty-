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
        idx = (np.arange(m) + i0) % n
        if buf.ndim == 1:
            np.add.at(buf, idx, sig * gain)
        else:
            for c in range(buf.shape[0]):
                s = sig[c] if sig.ndim == 2 else sig
                np.add.at(buf[c], idx, s * gain)
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
        y[:m] += a * np.exp(-t[:m] / d) * np.sin(TAU * f * t[:m] + ph)
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
        for (dt_, g) in early:
            i = ns(dt_)
            if i < n:
                y[i] += g * (1 if rng.random() < 0.5 else -1) * np.sqrt(np.sum(y[:ns(0.05)] ** 2) / 50 + 1e-9) * 12
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
