#!/usr/bin/env python3
# Генератор звуков игры (всё синтезируется с нуля, без чужих сэмплов):
#   assets/sounds/SfxAtlas.ogg      — все короткие звуки подряд в одном файле (куски — Config.Sfx)
#   assets/sounds/MusicMenu.ogg     — тема меню (таинственная, «портальная»), бесшовная петля
#   assets/sounds/MusicMorning.ogg  — утро, лаунж-босса-нова (мелодия из браузерной версии игры), петля
#   assets/sounds/atlas.txt         — таблица кусков для Config.Sfx
# Запуск: python3 tools/gen_audio.py       — всё (нужны numpy и ffmpeg)
#         python3 tools/gen_audio.py sfx   — только SfxAtlas.ogg (музыка остаётся как есть)
import os, subprocess, wave
import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'sounds')
rng = np.random.default_rng(7)

# ---------------------------------------------------------------- основы
def t_(d): return np.arange(int(d * SR)) / SR
def sine(f, d, ph=0.0):
    t = t_(d)
    if callable(f): return np.sin(ph + 2 * np.pi * np.cumsum(f(t)) / SR)
    return np.sin(ph + 2 * np.pi * f * t)
def sweep(f0, f1, d, curve='exp'):
    t = t_(d)
    if curve == 'exp': f = f0 * (f1 / f0) ** (t / max(d, 1e-6))
    else: f = f0 + (f1 - f0) * t / max(d, 1e-6)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)
def noise(d): return rng.uniform(-1, 1, int(d * SR))
def env_exp(d, tau, attack=0.002):
    t = t_(d)
    e = np.exp(-t / tau)
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    return e * a
def adsr(d, a=0.01, dec=0.1, s=0.7, r=0.08):
    n = int(d * SR); t = np.arange(n) / SR
    e = np.ones(n) * s
    e[t < a] = t[t < a] / max(a, 1e-5)
    m = (t >= a) & (t < a + dec)
    e[m] = 1 - (1 - s) * (t[m] - a) / max(dec, 1e-5)
    rl = t > d - r
    e[rl] *= np.clip((d - t[rl]) / max(r, 1e-5), 0, 1)
    return e
def band(x, lo=None, hi=None, soft=1.4):
    """полосовой фильтр в частотной области (мягкие края)"""
    n = len(x)
    if n == 0: return x
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(f)
    if lo: g *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** (2 * soft))
    if hi: g *= 1 / (1 + (f / hi) ** (2 * soft))
    return np.fft.irfft(X * g, n)
def norm(x, peak=0.9):
    m = np.max(np.abs(x)) if len(x) else 0
    return x * (peak / m) if m > 1e-9 else x
def mix_at(buf, x, t, gain=1.0):
    i = int(t * SR)
    if i >= len(buf): return
    j = min(len(buf), i + len(x))
    buf[i:j] += x[:j - i] * gain
def fade(x, a=0.005, b=0.02):
    n = len(x); x = x.copy()
    na, nb = int(a * SR), int(b * SR)
    if na: x[:na] *= np.linspace(0, 1, na)
    if nb: x[-nb:] *= np.linspace(1, 0, nb)
    return x
def reverb(x, decay=1.6, mix=0.25, pre=0.02, seed=3):
    r = np.random.default_rng(seed)
    n = int(decay * SR * 1.3)
    t = np.arange(n) / SR
    ir = r.uniform(-1, 1, n) * np.exp(-t * 6.9 / decay)
    ir = band(ir, 200, 7000)
    ir[:int(pre * SR)] = 0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    L = len(x) + n
    N = 1 << int(np.ceil(np.log2(L)))
    y = np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(ir, N), N)[:L]
    out = np.zeros(L)
    out[:len(x)] = x
    return out * (1 - mix) + y * mix * 0.6
def softclip(x, drive=1.2): return np.tanh(x * drive) / np.tanh(drive)

def write_wav(path, x, stereo=None):
    if stereo is not None:
        data = np.stack([x, stereo], axis=1)
        ch = 2
    else:
        data = x[:, None]
        ch = 1
    data = np.clip(data, -1, 1)
    pcm = (data * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(ch); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
def to_ogg(wav, ogg, q=5):
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', str(q), ogg], check=True)
    os.remove(wav)

# ---------------------------------------------------------------- инструменты
def midi_f(m): return 440.0 * 2 ** ((m - 69) / 12)
NN = {'c': 0, 'd': 2, 'e': 4, 'f': 5, 'g': 7, 'a': 9, 'b': 11}
def note_m(s):
    s = s.strip()
    n = NN[s[0].lower()]
    i = 1
    if len(s) > 1 and s[1] in '#b':
        n += 1 if s[1] == '#' else -1
        i = 2
    return n + (int(s[i:]) + 1) * 12
def chord_m(sym, octave=3):
    s = sym
    root = s[0]; i = 1
    if len(s) > 1 and s[1] in '#b': root += s[1]; i = 2
    q = s[i:]
    r = note_m(root + str(octave))
    Q = {'maj7': [0, 4, 7, 11], 'm7': [0, 3, 7, 10], '7': [0, 4, 7, 10], 'm6': [0, 3, 7, 9], '6': [0, 4, 7, 9],
         'm': [0, 3, 7], '': [0, 4, 7], 'dim': [0, 3, 6], 'sus4': [0, 5, 7]}
    return r, [r + k for k in Q.get(q, [0, 4, 7])]

def vibe(f, d):
    t = t_(d + 1.2)
    e = np.exp(-t / 1.1) * np.clip(t / 0.004, 0, 1)
    trem = 1 - 0.22 * (0.5 + 0.5 * np.sin(2 * np.pi * 5.2 * t))
    x = np.sin(2 * np.pi * f * t) + 0.22 * np.sin(2 * np.pi * 4 * f * t) * np.exp(-t / 0.15)
    rel = np.clip((d + 0.35 - t) / 0.35, 0, 1)
    return x * e * trem * np.maximum(rel, 0)
def epiano(f, d):
    t = t_(d + 0.25)
    idx = 1.8 * np.exp(-t / 0.25) + 0.25
    mod = np.sin(2 * np.pi * f * t) * idx
    x = np.sin(2 * np.pi * f * t + mod) + 0.3 * np.sin(2 * np.pi * f * 1.003 * t)
    e = np.exp(-t / 1.4) * np.clip(t / 0.003, 0, 1)
    rel = np.clip((d + 0.2 - t) / 0.2, 0, 1)
    return x * e * rel
def bassn(f, d):
    t = t_(d + 0.06)
    x = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.2) + 0.1 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t / 0.08)
    e = np.clip(t / 0.008, 0, 1) * (0.6 + 0.4 * np.exp(-t / 0.15)) * np.clip((d + 0.05 - t) / 0.05, 0, 1)
    return x * e
def bell(f, d):
    t = t_(d + 1.6)
    idx = 3.0 * np.exp(-t / 0.6)
    x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * 3.5 * t))
    return x * np.exp(-t / 1.5) * np.clip(t / 0.002, 0, 1)
def piano(f, d):
    t = t_(d + 0.8)
    x = sum(a * np.sin(2 * np.pi * f * k * t) * np.exp(-t * k * 0.9) for k, a in [(1, 1), (2, 0.45), (3, 0.22), (4, 0.1)])
    return x * np.clip(t / 0.003, 0, 1) * np.exp(-t / 1.6) * np.clip((d + 0.5 - t) / 0.5, 0, 1)
def pad(freqs, d, bright=6):
    t = t_(d + 1.2)
    x = np.zeros_like(t)
    for f in freqs:
        for det in (-0.004, 0.0, 0.005):
            for k in range(1, bright + 1):
                x += np.sin(2 * np.pi * f * (1 + det) * k * t + k * 1.3) / (k * 1.6)
    e = np.clip(t / 0.7, 0, 1) * np.clip((d + 1.0 - t) / 1.0, 0, 1)
    return x * e / (len(freqs) * 3)
def theremin(f, d):
    t = t_(d + 0.2)
    vib = 1 + 0.012 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.4, 0, 1)
    x = np.sin(2 * np.pi * np.cumsum(f * vib) / SR)
    x += 0.15 * np.sin(2 * 2 * np.pi * np.cumsum(f * vib) / SR)
    return x * np.clip(t / 0.08, 0, 1) * np.clip((d + 0.15 - t) / 0.15, 0, 1)
def square_lead(f, d):
    t = t_(d + 0.05)
    x = sum(np.sin(2 * np.pi * f * k * t) / k for k in (1, 3, 5, 7, 9))
    return x * np.clip(t / 0.004, 0, 1) * (0.5 + 0.5 * np.exp(-t / 0.12)) * np.clip((d + 0.04 - t) / 0.04, 0, 1)

def kick(v=1.0):
    d = 0.32
    return fade(sweep(140, 42, d) * env_exp(d, 0.09, 0.001) * v, 0.0005, 0.02)
def snare(v=1.0):
    d = 0.22
    n = band(noise(d), 900, 8000) * env_exp(d, 0.06)
    tone = sine(185, d) * env_exp(d, 0.04)
    return (n * 0.8 + tone * 0.5) * v
def rim(v=1.0):
    d = 0.08
    return (sine(1700, d) * env_exp(d, 0.012) + band(noise(d), 1500, 6000) * env_exp(d, 0.008) * 0.6) * v
def shaker(v=1.0):
    d = 0.07
    return band(noise(d), 4500, 10000) * adsr(d, 0.012, 0.03, 0.3, 0.03) * v
def hat(v=1.0):
    d = 0.05
    return band(noise(d), 7000, 16000) * env_exp(d, 0.015) * v
def brush(v=1.0):
    d = 0.18
    return band(noise(d), 2000, 9000) * adsr(d, 0.03, 0.1, 0.2, 0.05) * v

# ---------------------------------------------------------------- секвенсор
def parse_mel(bar):
    out = []
    for tok in bar.split():
        n, l = tok.split(':')
        out.append((None if n == 'r' else note_m(n), int(l)))
    return out
def render_track(spec, loops=3):
    bpm, swing = spec['bpm'], spec.get('swing', 0)
    step = 60 / bpm / 4
    nb = len(spec['chords'])
    loop_len = nb * 16 * step
    total = loop_len * loops + 3
    L = np.zeros(int(total * SR)); R = np.zeros(int(total * SR))
    def st(i):  # время шага с «качем»
        return i * step + (swing * step if i % 2 == 1 else 0)
    for lp in range(loops):
        base = lp * loop_len
        for b, cs in enumerate(spec['chords']):
            bar0 = base + b * 16 * step
            syms = cs.split()
            for ci, sym in enumerate(syms):
                s0 = ci * 16 // len(syms)
                s1 = (ci + 1) * 16 // len(syms)
                for part in spec['parts']:
                    part(L, R, bar0, st, s0, s1, sym, b, lp)
            for d in spec.get('drums', []):
                d(L, R, bar0, st, b, lp)
        for mel in spec.get('melodies', []):
            mel(L, R, base, st, step)
    return L, R, loop_len

def place(L, R, x, t, g, pan=0.0):
    mix_at(L, x, t, g * (1 - max(0, pan)))
    mix_at(R, x, t, g * (1 + min(0, pan)))

def finish_loop(L, R, loop_len, loops, rev=(1.8, 0.28), out_loop=1):
    Lr = reverb(L, rev[0], rev[1], seed=3)
    Rr = reverb(R, rev[0], rev[1], seed=4)
    a = int(loop_len * out_loop * SR)
    b = int(loop_len * (out_loop + 1) * SR)
    l, r = Lr[a:b], Rr[a:b]
    m = max(np.max(np.abs(l)), np.max(np.abs(r)))
    l, r = softclip(l / m * 0.95, 1.1) * 0.89, softclip(r / m * 0.95, 1.1) * 0.89
    return l, r

# ---------------------------------------------------------------- музыка: утро (босса-нова)
MORNING_CHORDS = ['Fmaj7', 'Em7 A7', 'Dm7', 'Cm7 F7', 'Bbmaj7', 'Bbm6', 'Am7 D7', 'Gm7 C7',
                  'Fmaj7', 'D7', 'Gm7', 'C7', 'Am7 D7', 'Gm7 C7', 'F6', 'Gm7 C7']
MORNING_MEL = ['A4:2 C5:2 E5:3 r:1 D5:2 C5:2 A4:4', 'G#4:2 A4:2 C#5:2 E5:2 G5:3 F5:1 E5:4', 'F5:3 E5:1 D5:2 C5:2 A4:4 r:4', 'Eb5:2 D5:2 C5:2 Bb4:2 A4:2 C5:2 Eb5:4',
               'D5:3 r:1 D5:2 F5:2 A5:4 G5:2 F5:2', 'Db5:2 F5:2 G5:3 r:1 F5:2 Db5:2 Bb4:4', 'C5:2 E5:2 G5:2 E5:2 F#5:3 r:1 A5:4', 'Bb5:2 A5:2 G5:2 F5:2 E5:2 D5:2 C5:2 Bb4:2',
               'A5:4 r:2 G5:1 A5:1 G5:2 E5:2 C5:4', 'F#5:3 r:1 F#5:2 A5:2 C6:4 A5:2 F#5:2', 'G5:2 Bb5:2 D6:3 r:1 C6:2 Bb5:2 G5:4', 'E5:2 G5:2 Bb5:2 G5:2 E5:2 C5:2 Db5:2 D5:2',
               'E5:3 r:1 C5:2 A4:2 F#5:3 r:1 D5:4', 'F5:2 D5:2 Bb4:2 G4:2 E5:3 r:1 C5:4', 'A4:2 C5:2 D5:2 F5:2 A5:6 r:2', 'G5:1 Ab5:1 A5:2 Bb5:2 B5:2 C6:4 r:4']

def morning():
    BOSSA_COMP = [(0, 3), (3, 2), (6, 3), (10, 2), (12, 3)]
    BOSSA_BASS = [(0, 0, 5), (6, 7, 2), (8, 7, 5), (14, 0, 2)]
    def comp(L, R, bar0, st, s0, s1, sym, b, lp):
        _, notes = chord_m(sym, 4)
        for s, l in BOSSA_COMP:
            if s0 <= s < s1:
                for k, m in enumerate(notes):
                    place(L, R, epiano(midi_f(m - 12 + 12), l * 0.13), bar0 + st(s) + k * 0.004, 0.045, pan=-0.3 + k * 0.18)
    def bass(L, R, bar0, st, s0, s1, sym, b, lp):
        r, _ = chord_m(sym, 2)
        for s, iv, l in BOSSA_BASS:
            if s0 <= s < s1:
                place(L, R, bassn(midi_f(r + iv), l * 0.13), bar0 + st(s), 0.32)
    def drums(L, R, bar0, st, b, lp):
        pat = {'r': 'x..x..x...x..x..', 'sh': 'oxoxoxoxoxoxoxox', 'k': 'x.......x.....o.', 'br': '....x.......x...'}
        fn = {'r': rim, 'sh': shaker, 'k': kick, 'br': brush}
        gain = {'r': 0.08, 'sh': 0.045, 'k': 0.34, 'br': 0.09}
        for k, p in pat.items():
            for i, c in enumerate(p):
                if c != '.':
                    v = 1 if c == 'x' else (0.7 if c == 'X' else 0.35)
                    place(L, R, fn[k](v), bar0 + st(i), gain[k], pan=0.25 if k in ('sh', 'r') else 0)
    def melody(L, R, base, st, step):
        s = 0
        for bi, bar in enumerate(MORNING_MEL):
            for n, l in parse_mel(bar):
                if n is not None:
                    t = base + st(bi * 16 + s)
                    place(L, R, vibe(midi_f(n + 12 - 12), l * step), t, 0.14, pan=0.15)
                    place(L, R, epiano(midi_f(n), l * step), t, 0.04, pan=-0.1)
                s += l
            s = 0
    spec = {'bpm': 114, 'swing': 0.13, 'chords': MORNING_CHORDS, 'parts': [comp, bass], 'drums': [drums], 'melodies': [melody]}
    L, R, ll = render_track(spec, 3)
    return finish_loop(L, R, ll, 3, (1.6, 0.26))

# ---------------------------------------------------------------- музыка: меню (таинственная тема портала)
TITLE_CHORDS = ['Am', 'F', 'C', 'G', 'Am', 'F', 'Dm', 'E']
TITLE_MEL = ['E5:4 A5:4 B5:2 C6:2 B5:4', 'A5:6 G5:2 F5:4 E5:4', 'G5:4 C6:4 E6:4 D6:2 C6:2', 'D6:8 B5:4 G5:4',
             'E5:4 A5:4 C6:4 B5:2 A5:2', 'F5:4 A5:4 C6:4 D6:4', 'F6:4 E6:4 D6:4 C6:2 B5:2', 'B5:8 G#5:4 E5:4']
def menu_theme():
    spec_chords = TITLE_CHORDS + TITLE_CHORDS
    def padp(L, R, bar0, st, s0, s1, sym, b, lp):
        _, notes = chord_m(sym, 3)
        place(L, R, pad([midi_f(m) for m in notes], 16 * 0.178), bar0, 0.16, pan=0)
    def arp(L, R, bar0, st, s0, s1, sym, b, lp):
        _, notes = chord_m(sym, 4)
        seq = notes + [notes[0] + 12, notes[1] + 12] + notes[::-1]
        for i in range(0, 16, 2):
            m = seq[(i // 2) % len(seq)]
            place(L, R, bell(midi_f(m + 12), 0.2), bar0 + st(i), 0.05, pan=-0.5 + (i / 16))
    def bass(L, R, bar0, st, s0, s1, sym, b, lp):
        r, _ = chord_m(sym, 2)
        place(L, R, bassn(midi_f(r), 16 * 0.178 * 0.95), bar0, 0.3)
        place(L, R, bassn(midi_f(r + 12), 0.2), bar0 + st(10), 0.12)
    def drums(L, R, bar0, st, b, lp):
        place(L, R, kick(0.9), bar0, 0.4)
        place(L, R, kick(0.6), bar0 + st(8), 0.3)
        if b % 2 == 1: place(L, R, snare(0.5), bar0 + st(12), 0.12)
        for i in range(0, 16, 2): place(L, R, hat(0.5 if i % 4 else 0.8), bar0 + st(i), 0.05, pan=0.3)
    def melody(L, R, base, st, step):
        for half in range(2):
            for bi, bar in enumerate(TITLE_MEL):
                s = 0
                for n, l in parse_mel(bar):
                    if n is not None:
                        t = base + st((half * 8 + bi) * 16 + s)
                        if half == 0:
                            place(L, R, bell(midi_f(n), l * step), t, 0.09, pan=0.2)
                        else:
                            place(L, R, theremin(midi_f(n - 12), l * step), t, 0.1, pan=-0.15)
                            place(L, R, bell(midi_f(n), l * step), t, 0.05, pan=0.25)
                    s += l
    spec = {'bpm': 84, 'swing': 0, 'chords': spec_chords, 'parts': [padp, arp, bass], 'drums': [drums], 'melodies': [melody]}
    L, R, ll = render_track(spec, 3)
    # «портальное» мерцание сверху
    t = np.arange(len(L)) / SR
    shimmer = band(rng.uniform(-1, 1, len(L)), 3000, 9000) * (0.5 + 0.5 * np.sin(2 * np.pi * t / (ll / 4))) * 0.02
    return finish_loop(L + shimmer, R + shimmer[::-1], ll, 3, (2.6, 0.38))

# ---------------------------------------------------------------- короткие звуки
def loop_render(fn, length):
    """бесшовная петля: рендер трёх копий подряд, берём среднюю"""
    x = fn(length * 3)
    a = int(length * SR)
    return x[a:2 * a]

def s_alarm(d):
    out = np.zeros(int(d * SR))
    cyc = 1.6
    t0 = 0.0
    while t0 < d:
        for k in range(4):
            b = sum(np.sin(2 * np.pi * 2400 * j * t_(0.085)) / j for j in (1, 3, 5)) * adsr(0.085, 0.003, 0.02, 0.8, 0.01)
            mix_at(out, b, t0 + k * 0.15, 0.55)
        t0 += cyc
    return out
def s_click():
    d = 0.15
    return fade(sine(1500, d) * env_exp(d, 0.012) * 0.7 + band(noise(d), 2000, 9000) * env_exp(d, 0.004) * 0.4)
def s_hover():
    d = 0.1
    return fade(sine(3200, d) * env_exp(d, 0.02) * 0.4)
def s_whoosh():
    d = 1.6
    t = t_(d)
    env = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
    n = noise(d)
    out = np.zeros_like(t)
    seg = 0.1
    for i in range(int(d / seg)):
        a = int(i * seg * SR); b = min(len(t), int((i + 1) * seg * SR) + 400)
        fc = 300 * (12 ** (i * seg / d))
        out[a:b] += band(n[a:b], fc * 0.6, fc * 1.8) * np.hanning(b - a)
    low = sweep(90, 30, d) * env * 0.5
    sparkle = band(noise(d), 6000, 14000) * env ** 3 * 0.25
    return fade(out * env * 0.9 + low + sparkle, 0.01, 0.1)
def s_hum(d):
    t = t_(d)
    x = (np.sin(2 * np.pi * 55 * t) * 0.5 + np.sin(2 * np.pi * 82.5 * t) * 0.25 + np.sin(2 * np.pi * 110.25 * t) * 0.15)
    x *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.5 * t)
    swirl = band(noise(d), 400, 1800) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.75 * t)) * 0.25
    out = x + swirl
    for k in range(int(d * 3)):
        mix_at(out, sine(rng.uniform(2500, 5000), 0.15) * env_exp(0.15, 0.04) * 0.08, rng.uniform(0, d))
    return out
def s_blink():
    d = 0.6
    return band(noise(d), 300, 2500) * adsr(d, 0.15, 0.2, 0.2, 0.2) * 0.25
def s_rustle():
    d = 1.4
    n = band(noise(d), 800, 7000)
    am = np.abs(band(noise(d), None, 18)) * 6
    return fade(n * np.clip(am, 0, 1) * adsr(d, 0.1, 0.4, 0.6, 0.4) * 0.8)
def s_step(seed):
    r = np.random.default_rng(seed)
    d = 0.3
    thump = sweep(120 + r.uniform(-20, 20), 50, d) * env_exp(d, 0.04) * 0.8
    scuff = band(r.uniform(-1, 1, int(d * SR)), 500, 3500) * env_exp(d, 0.025) * 0.5
    return fade(thump + scuff, 0.001, 0.05)
def s_alarmoff():
    d = 0.3
    out = np.zeros(int(d * SR))
    for k, tt in enumerate((0.0, 0.07)):
        c = band(noise(0.03), 1500, 7000) * env_exp(0.03, 0.006) + sine(900 + k * 300, 0.03) * env_exp(0.03, 0.008) * 0.6
        mix_at(out, c, tt, 0.8)
    return out
def s_pour():
    d = 2.0
    out = np.zeros(int(d * SR))
    for i in range(420):
        tt = rng.uniform(0.05, 1.85)
        dens = np.sin(np.pi * tt / 1.9)
        if rng.uniform() > dens: continue
        g = band(noise(0.02), 1500, 7000) * env_exp(0.02, 0.003)
        mix_at(out, g, tt, rng.uniform(0.15, 0.5))
    return fade(out + band(noise(d), 300, 1500) * adsr(d, 0.2, 0.5, 0.3, 0.4) * 0.08)
def s_milk():
    d = 2.0
    t = t_(d)
    n = noise(d)
    out = np.zeros_like(t)
    seg = 0.05
    for i in range(int(d / seg)):
        a = int(i * seg * SR); b = min(len(t), a + int(seg * SR) + 300)
        fc = 500 + 350 * np.sin(2 * np.pi * 7 * i * seg) + rng.uniform(-80, 80)
        out[a:b] += band(n[a:b], fc * 0.7, fc * 1.4) * np.hanning(b - a)
    gl = np.zeros_like(t)
    for k in range(9):
        mix_at(gl, sweep(260, 420, 0.06) * env_exp(0.06, 0.02), rng.uniform(0.1, 1.8), 0.3)
    return fade((out + gl) * adsr(d, 0.15, 0.3, 0.8, 0.3))
def s_crunch(seed):
    r = np.random.default_rng(seed)
    d = 0.7
    out = np.zeros(int(d * SR))
    for bite in (0.0, 0.22 + r.uniform(0, 0.05)):
        for i in range(80):
            tt = bite + abs(r.normal(0, 0.05))
            g = band(r.uniform(-1, 1, int(0.012 * SR)), 900, 6000) * env_exp(0.012, 0.003)
            mix_at(out, g, tt, r.uniform(0.2, 0.7))
        mix_at(out, sweep(160, 70, 0.08) * env_exp(0.08, 0.02) * 0.4, bite)
    return fade(out)
def s_spoon():
    d = 0.4
    t = t_(d)
    x = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t / dec) for f, a, dec in [(2150, 0.6, 0.12), (3480, 0.4, 0.08), (5230, 0.25, 0.05)])
    return fade(x * 0.7)
def s_phoneout():
    d = 0.6
    sw = band(noise(d), 1500, 8000) * adsr(d, 0.15, 0.2, 0.3, 0.2) * 0.5
    tick = np.zeros(int(d * SR)); mix_at(tick, sine(2600, 0.04) * env_exp(0.04, 0.01) * 0.4, 0.45)
    return fade(sw + tick)
def s_tap():
    d = 0.15
    return fade(sine(1200, d) * env_exp(d, 0.01) * 0.5 + band(noise(d), 3000, 9000) * env_exp(d, 0.003) * 0.3)
def s_swipe():
    d = 0.4
    t = t_(d)
    n = noise(d)
    out = np.zeros_like(t)
    seg = 0.04
    for i in range(int(d / seg)):
        a = int(i * seg * SR); b = min(len(t), a + int(seg * SR) + 300)
        fc = 800 * (6 ** (i * seg / d))
        out[a:b] += band(n[a:b], fc * 0.6, fc * 1.6) * np.hanning(b - a)
    return fade(out * np.sin(np.pi * t / d) * 0.6)
def s_tiktok(d):
    # бодрая поп-петля 120 bpm, 4 такта = 8 секунд
    bpm = 120
    step = 60 / bpm / 4
    out = np.zeros(int(d * SR))
    chords = ['C', 'Am', 'F', 'G']
    lead = ['E5:2 G5:2 C6:2 G5:1 A5:1 G5:4 E5:2 D5:2', 'C5:2 E5:2 A5:2 E5:1 G5:1 E5:4 C5:4', 'F5:2 A5:2 C6:2 A5:2 G5:2 F5:2 E5:4', 'D5:2 G5:2 B5:2 D6:2 C6:4 r:4']
    nbars = int(round(d / (16 * step)))
    for b in range(nbars):
        bar0 = b * 16 * step
        sym = chords[b % 4]
        r, notes = chord_m(sym, 3)
        for i in range(16):
            if i % 4 == 0: mix_at(out, kick(1.0), bar0 + i * step, 0.5)
            if i % 8 == 4: mix_at(out, snare(1.0), bar0 + i * step, 0.3)
            mix_at(out, hat(0.7 if i % 2 else 1.0), bar0 + i * step, 0.06)
            if i in (0, 3, 6, 8, 11, 14):
                mix_at(out, bassn(midi_f(r - 12 + (12 if i in (6, 14) else 0)), 0.14), bar0 + i * step, 0.35)
            if i in (2, 6, 10, 14):
                for m in notes:
                    mix_at(out, square_lead(midi_f(m + 12), 0.09), bar0 + i * step, 0.035)
        s = 0
        for n, l in parse_mel(lead[b % 4]):
            if n is not None:
                mix_at(out, square_lead(midi_f(n), l * step * 0.9), bar0 + s * step, 0.09)
                mix_at(out, bell(midi_f(n + 12), l * step), bar0 + s * step, 0.03)
            s += l
    return out
def s_glitch():
    d = 3.0
    out = np.zeros(int(d * SR))
    t = 0.0
    while t < 2.6:
        kind = rng.integers(0, 4)
        dur = rng.uniform(0.03, 0.18)
        if kind == 0:
            x = np.sign(np.sin(2 * np.pi * rng.uniform(200, 1800) * t_(dur))) * 0.5
        elif kind == 1:
            x = np.round(noise(dur) * 4) / 4 * 0.6
        elif kind == 2:
            x = sweep(rng.uniform(2000, 6000), rng.uniform(100, 600), dur) * 0.5
        else:
            seg = sine(rng.uniform(300, 900), 0.02) * 0.6
            x = np.tile(seg, int(dur / 0.02) + 1)[:int(dur * SR)]
        mix_at(out, fade(x, 0.001, 0.003), t, 0.7 + 0.3 * t / 2.6)
        t += dur * rng.uniform(0.6, 1.2)
    mix_at(out, sweep(1200, 40, 0.4) * env_exp(0.4, 0.15) * 0.8, 2.6)
    crush = np.round(out * 8) / 8
    return fade(crush * 0.8)
def s_vibrate():
    d = 1.0
    t = t_(d)
    x = sum(np.sin(2 * np.pi * 160 * k * t) / k for k in (1, 3, 5)) * 0.5
    am = ((t % 0.5) < 0.32).astype(float)
    am = band(am, None, 60)
    return fade(x * am * 0.7)
def s_notify():
    d = 0.8
    out = np.zeros(int(d * SR))
    mix_at(out, bell(midi_f(note_m('E6')), 0.2) * 0.6, 0.0)
    mix_at(out, bell(midi_f(note_m('B6')), 0.4) * 0.6, 0.12)
    return fade(out[:int(d * SR)])
def s_sting():
    d = 2.4
    t = t_(d)
    boom = sweep(70, 35, d) * env_exp(d, 0.7) * 0.9
    sw = sum(np.sin(2 * np.pi * f * t) for f in (311, 330, 466, 494)) * np.clip(t / 0.9, 0, 1) * np.exp(-np.maximum(t - 0.9, 0) / 0.5) * 0.2
    rev = band(noise(d), 4000, 12000) * np.clip(t / 0.9, 0, 1) ** 3 * (t < 0.95) * 0.4
    hit = np.zeros_like(t); mix_at(hit, snare(1.2) * 0.8, 0.9)
    return fade(boom + sw + rev + hit, 0.005, 0.3)
def s_birds(d):
    t = t_(d)
    out = band(noise(d), 200, 1500) * 0.035 * (0.7 + 0.3 * np.sin(2 * np.pi * t / d))
    n = 0
    while n < d * 2.2:
        n += 1
        t0 = rng.uniform(0, d - 0.6)
        base = rng.uniform(2500, 4800)
        for k in range(rng.integers(2, 6)):
            ch = sweep(base * rng.uniform(0.9, 1.1), base * rng.uniform(1.2, 1.6), 0.07) * env_exp(0.07, 0.03)
            mix_at(out, ch, t0 + k * 0.11, rng.uniform(0.05, 0.14))
    return out
def s_thought():
    d = 0.6
    out = np.zeros(int(d * SR))
    for k, m in enumerate(('C6', 'G6')):
        mix_at(out, bell(midi_f(note_m(m)), 0.3) * 0.35, k * 0.05)
    return fade(out[:int(d * SR)])
def s_locked():
    d = 0.5
    out = np.zeros(int(d * SR))
    for tt in (0.0, 0.09, 0.2, 0.27):
        c = band(noise(0.05), 1200, 6000) * env_exp(0.05, 0.01) + sine(rng.uniform(700, 1100), 0.05) * env_exp(0.05, 0.015) * 0.5
        mix_at(out, c, tt, 0.7)
    return fade(out)
def s_paper():
    d = 0.6
    n = band(noise(d), 1500, 9000)
    am = np.clip(np.abs(band(noise(d), None, 25)) * 8, 0, 1)
    return fade(n * am * adsr(d, 0.05, 0.2, 0.5, 0.2) * 0.6)
def s_chair():
    d = 0.8
    t = t_(d)
    creak = sweep(180, 120, d, 'lin') * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 34 * t))) * 0.3
    scrape = band(noise(d), 300, 2500) * adsr(d, 0.05, 0.3, 0.5, 0.2) * 0.4
    return fade(band(creak, 100, 3000) + scrape)

def s_tentacle():
    d = 2.0
    t = t_(d)
    n = noise(d)
    out = np.zeros_like(t)
    seg = 0.05
    for i in range(int(d / seg)):
        a = int(i * seg * SR); b = min(len(t), a + int(seg * SR) + 300)
        fc = max(90.0, 350 + 250 * np.sin(2 * np.pi * 3.3 * i * seg) + 150 * np.sin(2 * np.pi * 7.1 * i * seg))
        out[a:b] += band(n[a:b], fc * 0.6, fc * 1.6) * np.hanning(b - a)
    growl = np.sin(2 * np.pi * np.cumsum(55 + 12 * np.sin(2 * np.pi * 5 * t)) / SR) * 0.35
    for k in range(7):
        mix_at(out, band(noise(0.12), 200, 1200) * env_exp(0.12, 0.04) * 1.2, rng.uniform(0.1, 1.8))
    return fade((out + growl) * adsr(d, 0.15, 0.4, 0.8, 0.4), 0.01, 0.2)
def s_pull():
    d = 2.0
    t = t_(d)
    k = (t / d) ** 2
    rise = np.sin(2 * np.pi * np.cumsum(80 + 1400 * k) / SR) * (0.2 + 0.6 * k)
    n = noise(d)
    wh = np.zeros_like(t)
    seg = 0.08
    for i in range(int(d / seg)):
        a = int(i * seg * SR); b = min(len(t), a + int(seg * SR) + 400)
        fc = 300 * (20 ** (i * seg / d))
        wh[a:b] += band(n[a:b], fc * 0.6, fc * 1.7) * np.hanning(b - a)
    return fade(rise + wh * (0.3 + 0.7 * k), 0.02, 0.05)
def crush(x, levels=6):
    return np.round(x * levels) / levels
def s_land():
    d = 0.8
    sq = np.sign(sweep(220, 50, d)) * env_exp(d, 0.18) * 0.6
    cr = crush(band(noise(d), 200, 3000) * env_exp(d, 0.08), 4) * 0.6
    return fade(sq + cr)
def s_flicker():
    d = 0.6
    t = t_(d)
    buzz = np.sign(np.sin(2 * np.pi * 120 * t)) * 0.4 + band(noise(d), 2000, 8000) * 0.3
    gate = (rng.uniform(0, 1, int(d * 40)) > 0.45).astype(float)
    gate = np.repeat(gate, int(SR / 40) + 1)[:len(t)]
    return fade(buzz * gate)
def s_laser():
    d = 0.6
    t = t_(d)
    f = 2600 * np.exp(-t / 0.09) + 260
    z = np.sin(2 * np.pi * np.cumsum(f) / SR + 2.0 * np.sin(2 * np.pi * 80 * t)) * env_exp(d, 0.16)
    return fade(z * 0.8 + band(noise(d), 3000, 10000) * env_exp(d, 0.02) * 0.4)
def s_pixelburst():
    d = 0.8
    n = crush(noise(d), 3) * env_exp(d, 0.2)
    hold = np.repeat(n[::6], 6)[:len(n)]
    arp = np.zeros(len(n))
    for i, f in enumerate((880, 660, 440, 330, 220)):
        mix_at(arp, np.sign(sine(f, 0.08)) * 0.3, i * 0.08)
    return fade(hold * 0.7 + arp)
def s_burp():
    d = 1.2
    t = t_(d)
    f0 = 85 + 25 * np.sin(2 * np.pi * 1.3 * t) + 10 * rng.standard_normal(len(t)).cumsum() / np.sqrt(len(t)) * 0
    src = np.sign(np.sin(2 * np.pi * np.cumsum(f0) / SR)) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t))
    voice = band(src, 250, 900) * 1.5 + band(src, 1100, 1800) * 0.4
    return fade(voice * adsr(d, 0.06, 0.3, 0.8, 0.35), 0.01, 0.2)
def s_pixelamb(d):
    out = np.zeros(int(d * SR))
    drone = np.sin(2 * np.pi * 55 * t_(d)) * 0.25 + np.sign(np.sin(2 * np.pi * 110 * t_(d))) * 0.03
    out += drone
    notes = ['A3', 'C4', 'E4', 'G#3', 'A3', 'D4', 'F4', 'E4']
    step = 0.25
    i = 0
    tt = 0.0
    while tt < d:
        m = note_m(notes[(i // 4) % len(notes)]) + [0, 12, 7, 12][i % 4]
        x = np.sign(np.sin(2 * np.pi * midi_f(m) * t_(0.2))) * env_exp(0.2, 0.06) * 0.12
        mix_at(out, x, tt)
        tt += step
        i += 1
    for k in range(int(d / 3)):
        mix_at(out, crush(band(noise(0.2), 1000, 6000), 3) * env_exp(0.2, 0.05) * 0.15, rng.uniform(0, d - 0.3))
    return out

# ---------------------------------------------------------------- глава 2
# свой генератор случайных чисел: общий rng не трогаем, чтобы музыка и старые звуки не менялись
rng2 = np.random.default_rng(2024)
def noise2(d): return rng2.uniform(-1, 1, int(d * SR))
def saw(f, d):
    t = t_(d)
    if callable(f): ph = np.cumsum(f(t)) / SR
    else: ph = f * t
    return 2 * (ph - np.floor(ph + 0.5))

def s_explosion():
    d = 2.8
    t = t_(d)
    crack = noise2(d) * env_exp(d, 0.025) * 1.0
    boom = np.sin(2 * np.pi * np.cumsum(30 + 70 * np.exp(-t / 0.12)) / SR) * env_exp(d, 0.55, 0.004) * 1.2
    body = band(noise2(d), 25, 420) * env_exp(d, 0.9, 0.01) * 2.2
    tail = band(noise2(d), 20, 140) * env_exp(d, 1.6, 0.05) * 1.6
    out = crack + boom + body + tail
    for _ in range(26):
        tt = rng2.uniform(0.15, 2.2)
        mix_at(out, band(noise2(0.03), 1800, 7000) * env_exp(0.03, 0.006) * rng2.uniform(0.1, 0.35) * np.exp(-tt), tt)
    return fade(softclip(reverb(out, 2.2, 0.3)[:len(out)], 1.6), 0.002, 0.3)

def s_shiphum(d):
    t = t_(d)
    a = saw(46.0, d) + saw(46.75, d) * 0.8  # целое число периодов за 4 с — петля без щелчка
    low = band(a, 30, 320) * 0.7
    wub = 0.65 + 0.35 * np.sin(2 * np.pi * 2.0 * t) ** 2
    whine = np.sin(2 * np.pi * np.cumsum(1180 + 40 * np.sin(2 * np.pi * 0.5 * t)) / SR) * 0.05
    air = band(noise2(d), 500, 2500) * 0.08
    return (low * wub + whine + air)

def s_shipfly():
    d = 2.4
    t = t_(d)
    k = t / d
    amp = np.exp(-((k - 0.45) / 0.22) ** 2)
    f = 140 + 220 / (1 + np.exp((k - 0.45) * 12))
    tone = band(saw(lambda tt: 140 + 220 / (1 + np.exp((tt / d - 0.45) * 12)), d), 60, 1500) * 0.5
    n = noise2(d)
    wh = np.zeros_like(t)
    seg = 0.06
    for i in range(int(d / seg)):
        a = int(i * seg * SR); b = min(len(t), a + int(seg * SR) + 300)
        fc = 700 * np.exp(-((i * seg / d - 0.45) / 0.3) ** 2) + 250
        wh[a:b] += band(n[a:b], fc * 0.5, fc * 2.0) * np.hanning(b - a)
    rumble = band(noise2(d), 25, 120) * 0.8
    _ = f
    return fade((tone + wh * 0.8 + rumble) * amp, 0.02, 0.2)

def s_skyhorn():
    d = 5.0
    t = t_(d)
    bend = 1 - 0.06 * np.clip((t - 3.4) / 1.6, 0, 1)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5 * t)
    f1 = lambda tt: 55 * (1 - 0.06 * np.clip((tt - 3.4) / 1.6, 0, 1)) * (1 + 0.004 * np.sin(2 * np.pi * 5 * tt))
    f2 = lambda tt: 82.4 * (1 - 0.06 * np.clip((tt - 3.4) / 1.6, 0, 1)) * (1 + 0.004 * np.sin(2 * np.pi * 5.3 * tt))
    horn = band(saw(f1, d) + saw(f2, d) * 0.7 + saw(lambda tt: f1(tt) * 2.005, d) * 0.3, 30, 900)
    env = adsr(d, 1.0, 0.5, 0.85, 1.2)
    sub = np.sin(2 * np.pi * 27.5 * t) * 0.4 * env
    _ = (bend, vib)
    return fade(softclip(reverb(horn * env + sub, 3.0, 0.4)[:len(t)], 1.3), 0.05, 0.4)

def s_rumble():
    d = 3.5
    t = t_(d)
    out = band(noise2(d), 18, 150) * adsr(d, 0.4, 0.8, 0.7, 1.5) * 1.5
    for _ in range(6):
        tt = rng2.uniform(0.1, 2.4)
        mix_at(out, band(noise2(0.9), 30, 260) * env_exp(0.9, 0.3, 0.02) * rng2.uniform(0.5, 1.0), tt)
    crackle = band(noise2(d), 800, 3000) * env_exp(d, 0.25, 0.01) * 0.25
    return fade(out + crackle, 0.05, 0.4)

def s_beep():
    d = 0.15
    return fade(np.sign(sine(1850, d)) * 0.35 * adsr(d, 0.003, 0.02, 0.9, 0.02) + sine(3700, d) * 0.1, 0.002, 0.01)

def s_garagedoor():
    d = 3.4
    t = t_(d)
    motor = band(saw(lambda tt: 88 + 10 * np.clip(tt / 0.6, 0, 1), d), 60, 1200) * adsr(d, 0.25, 0.3, 0.8, 0.5) * 0.5
    out = motor.copy()
    tt = 0.15
    while tt < d - 0.4:
        mix_at(out, band(noise2(0.02), 1200, 5000) * env_exp(0.02, 0.005) * rng2.uniform(0.2, 0.45), tt)
        tt += rng2.uniform(0.04, 0.07)
    thump = np.sin(2 * np.pi * np.cumsum(90 * np.exp(-t_(0.4) / 0.1) + 40) / SR) * env_exp(0.4, 0.09) * 0.9
    mix_at(out, thump + band(noise2(0.4), 100, 1500) * env_exp(0.4, 0.03) * 0.4, d - 0.42)
    return fade(out, 0.02, 0.05)

def s_button():
    d = 0.3
    click = band(noise2(d), 2000, 8000) * env_exp(d, 0.004) * 0.6 + sine(1200, d) * env_exp(d, 0.01) * 0.3
    clunk = np.sin(2 * np.pi * np.cumsum(180 * np.exp(-t_(d) / 0.05) + 60) / SR) * env_exp(d, 0.05) * 0.7
    out = click.copy()
    mix_at(out, clunk, 0.04)
    return fade(out, 0.001, 0.05)

def s_siren(d):
    t = t_(d)
    k = (t % 2.0) / 2.0
    f = 620 + 560 * np.sin(np.pi * k) ** 2
    x = np.sin(2 * np.pi * np.cumsum(f) / SR)
    x = band(np.sign(x) * 0.3 + x * 0.7, 300, 4000)
    return x * 0.8

def s_labamb(d):
    t = t_(d)
    hum = (np.sin(2 * np.pi * 60 * t) * 0.3 + np.sin(2 * np.pi * 120 * t) * 0.15 + np.sin(2 * np.pi * 180 * t) * 0.06)
    hum *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.25 * t)
    out = hum + band(noise2(d), 200, 1200) * 0.05
    # бульканье бака
    for _ in range(int(d * 2.5)):
        tt = rng2.uniform(0, d - 0.2)
        f0 = rng2.uniform(250, 600)
        dd = rng2.uniform(0.06, 0.12)
        mix_at(out, np.sin(2 * np.pi * np.cumsum(np.linspace(f0, f0 * 2.2, int(dd * SR))) / SR) * env_exp(dd, dd / 3) * 0.18, tt)
    # компьютер пикает
    for _ in range(int(d / 2.5)):
        tt = rng2.uniform(0, d - 0.3)
        mix_at(out, sine(rng2.choice([1320, 1760, 2093]), 0.07) * env_exp(0.07, 0.03) * 0.08, tt)
    return out

def s_baseamb(d):
    t = t_(d)
    rumble = band(noise2(d), 25, 110) * 0.6
    hvac = (np.sin(2 * np.pi * 100 * t) * 0.12 + np.sin(2 * np.pi * 200 * t) * 0.05) * (0.9 + 0.1 * np.sin(2 * np.pi * 0.2 * t))
    air = band(noise2(d), 1500, 6000) * 0.04
    out = rumble + hvac + air
    clanks = np.zeros_like(t)
    for _ in range(int(d / 2.2)):
        tt = rng2.uniform(0, d - 1.5)
        f = rng2.uniform(300, 900)
        dd = 1.2
        c = (np.sin(2 * np.pi * f * t_(dd)) * 0.5 + np.sin(2 * np.pi * f * 2.76 * t_(dd)) * 0.3) * env_exp(dd, 0.25)
        c += band(noise2(dd), 500, 4000) * env_exp(dd, 0.01) * 0.5
        mix_at(clanks, c * rng2.uniform(0.08, 0.2), tt)
    out += reverb(clanks, 2.5, 0.6)[:len(t)]
    return out

def s_camzoom():
    d = 0.8
    t = t_(d)
    f = 650 + 450 * np.clip(t / 0.6, 0, 1)
    whir = band(np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)), 400, 5000) * (0.7 + 0.3 * np.sign(np.sin(2 * np.pi * 55 * t))) * 0.35
    env = adsr(d, 0.03, 0.1, 0.9, 0.12)
    out = whir * env
    mix_at(out, band(noise2(0.05), 2000, 9000) * env_exp(0.05, 0.008) * 0.6, 0.66)
    return fade(out, 0.005, 0.05)

def s_bass():
    d = 0.9
    t = t_(d)
    def thump(dd):
        tt = t_(dd)
        return np.sin(2 * np.pi * np.cumsum(45 + 90 * np.exp(-tt / 0.04)) / SR) * env_exp(dd, 0.22, 0.003)
    out = np.zeros_like(t)
    mix_at(out, thump(0.5), 0.0, 1.0)
    mix_at(out, thump(0.45), 0.42, 0.85)
    out += band(noise2(d), 60, 300) * env_exp(d, 0.1) * 0.15
    return fade(softclip(out, 1.5), 0.002, 0.05)

def s_tension(d):
    t = t_(d)
    # частоты подобраны так, чтобы за 12 с укладывалось целое число периодов (петля без щелчка)
    drone = band(saw(36.75, d) + saw(443 / 12, d) * 0.8 + saw(73.5, d) * 0.4, 25, 400) * 0.45
    drone *= 0.8 + 0.2 * np.sin(2 * np.pi * t / 6.0)
    out = drone
    # «сердцебиение» раз в секунду
    for k in range(int(d)):
        for off, g in ((0.0, 1.0), (0.24, 0.6)):
            hit = np.sin(2 * np.pi * np.cumsum(42 + 60 * np.exp(-t_(0.35) / 0.03)) / SR) * env_exp(0.35, 0.12, 0.003)
            mix_at(out, hit * 0.7 * g, k + off)
    # диссонанс струнных: ре и ми-бемоль с тремоло
    strings = (saw(587.25, d) + saw(622.25, d) * 0.8 + saw(293.75, d) * 0.5)
    strings = band(strings, 200, 2500) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t)) * 0.06
    strings *= 0.5 + 0.5 * np.sin(2 * np.pi * t / 12.0) ** 2
    out = out + reverb(strings, 2.4, 0.5)[:len(t)]
    return out

ATLAS = [
    ('Alarm', 0.0, 1.6, lambda: loop_render(s_alarm, 1.6)),
    ('Click', 2.0, 2.15, s_click), ('Hover', 2.4, 2.5, s_hover),
    ('Whoosh', 3.0, 4.6, s_whoosh), ('PortalHum', 5.0, 9.0, lambda: loop_render(s_hum, 4.0)),
    ('Blink', 9.5, 10.1, s_blink), ('Rustle', 10.5, 11.9, s_rustle),
    ('Step1', 12.5, 12.8, lambda: s_step(1)), ('Step2', 13.0, 13.3, lambda: s_step(2)),
    ('Step3', 13.5, 13.8, lambda: s_step(3)), ('Step4', 14.0, 14.3, lambda: s_step(4)),
    ('AlarmOff', 14.5, 14.8, s_alarmoff), ('Pour', 15.0, 17.0, s_pour), ('Milk', 17.5, 19.5, s_milk),
    ('Crunch1', 20.0, 20.7, lambda: s_crunch(11)), ('Crunch2', 21.0, 21.7, lambda: s_crunch(12)), ('Crunch3', 22.0, 22.7, lambda: s_crunch(13)),
    ('Spoon', 23.0, 23.4, s_spoon), ('PhoneOut', 23.8, 24.4, s_phoneout), ('PhoneTap', 24.6, 24.75, s_tap),
    ('Swipe', 25.0, 25.4, s_swipe), ('TikTokSong', 25.8, 33.8, lambda: loop_render(s_tiktok, 8.0)),
    ('Glitch', 34.2, 37.2, s_glitch), ('Vibrate', 37.6, 38.6, s_vibrate), ('Notify', 39.0, 39.8, s_notify),
    ('Sting', 40.2, 42.6, s_sting), ('Birds', 43.0, 55.0, lambda: loop_render(s_birds, 12.0)),
    ('Thought', 55.5, 56.1, s_thought), ('Locked', 56.5, 57.0, s_locked), ('Paper', 57.4, 58.0, s_paper),
    ('Chair', 58.4, 59.2, s_chair),
    ('Tentacle', 60.0, 62.0, s_tentacle), ('Pull', 62.5, 64.5, s_pull), ('Land', 65.0, 65.8, s_land),
    ('Flicker', 66.2, 66.8, s_flicker), ('Laser', 67.2, 67.8, s_laser), ('PixelBurst', 68.2, 69.0, s_pixelburst),
    ('Burp', 69.4, 70.6, s_burp), ('PixelAmb', 71.0, 87.0, lambda: loop_render(s_pixelamb, 16.0)),
    # глава 2
    ('Explosion', 87.5, 90.3, s_explosion), ('ShipHum', 90.8, 94.8, lambda: loop_render(s_shiphum, 4.0)),
    ('ShipFly', 95.3, 97.7, s_shipfly), ('SkyHorn', 98.2, 103.2, s_skyhorn), ('Rumble', 103.7, 107.2, s_rumble),
    ('Beep', 107.7, 107.85, s_beep), ('GarageDoor', 108.3, 111.7, s_garagedoor), ('Button', 112.2, 112.5, s_button),
    ('Siren', 113.0, 115.0, lambda: loop_render(s_siren, 2.0)), ('LabAmb', 115.5, 123.5, lambda: loop_render(s_labamb, 8.0)),
    ('BaseAmb', 124.0, 134.0, lambda: loop_render(s_baseamb, 10.0)), ('CamZoom', 134.5, 135.3, s_camzoom),
    ('Bass', 135.8, 136.7, s_bass), ('Tension', 137.2, 149.2, lambda: loop_render(s_tension, 12.0)),
]

def build_atlas():
    total = 150.0
    out = np.zeros(int(total * SR))
    lines = []
    for name, a, b, fn in ATLAS:
        x = np.asarray(fn(), dtype=float)
        n = int((b - a) * SR)
        x = x[:n]
        if len(x) < n: x = np.concatenate([x, np.zeros(n - len(x))])
        x = norm(x, 0.85)
        out[int(a * SR):int(a * SR) + n] = x
        lines.append('\t%s = { %.2f, %.2f },' % (name, a, b))
    return out, lines

def main():
    import sys
    os.makedirs(OUT, exist_ok=True)
    atlas, lines = build_atlas()
    p = os.path.join(OUT, 'SfxAtlas.wav')
    write_wav(p, atlas)
    to_ogg(p, os.path.join(OUT, 'SfxAtlas.ogg'), 6)
    open(os.path.join(OUT, 'atlas.txt'), 'w').write('-- куски SfxAtlas.ogg (вставить в Config.Sfx)\n' + '\n'.join(lines) + '\n')
    print('SfxAtlas.ogg', len(atlas) / SR, 's')
    if 'sfx' in sys.argv[1:]:
        return  # только звуки: музыку не трогаем (её не нужно загружать заново)
    l, r = morning()
    p = os.path.join(OUT, 'MusicMorning.wav')
    write_wav(p, l, r)
    to_ogg(p, os.path.join(OUT, 'MusicMorning.ogg'), 5)
    print('MusicMorning.ogg', len(l) / SR, 's')
    l, r = menu_theme()
    p = os.path.join(OUT, 'MusicMenu.wav')
    write_wav(p, l, r)
    to_ogg(p, os.path.join(OUT, 'MusicMenu.ogg'), 5)
    print('MusicMenu.ogg', len(l) / SR, 's')

if __name__ == '__main__':
    main()
