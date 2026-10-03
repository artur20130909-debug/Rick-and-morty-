/* ================= МУЗЫКА: чиптюн-трекер в духе Undertale/Deltarune + готовые треки =================
   Песня — набор каналов с нотными строками, по 1 токену на шаг (1/16 такта по умолчанию):
     'C5' — нота, '-' — тянуть предыдущую, '.' — пауза, 'x' — тянуть без новой атаки (то же, что '-');
     ударные: 'k' бочка, 's' малый, 'h' хэт, 'o' открытый хэт, 'c' тарелка, 't' там, '.' — тишина.
   Инструмент канала: { wave: 'pulse12'|'pulse25'|'square'|'triangle'|'saw'|'sine'|'noise'|'drums', vol, a, d, s, r,
                        vib: [частота Гц, глубина в полутонах, задержка с], oct: сдвиг октав, detune: центы (второй голос),
                        echo: [время, обратная связь], min: порог «напряжения» 0..1, с которого канал звучит, glide }
   MUS.def(key, { bpm, steps: 16, ch: { lead: { inst, pat: ['...', '...'] }, ... } })  — pat-строки играются по очереди и зацикливаются.
   MUS.def(key, { src: 'data:audio/mpeg;base64,...', vol, loopEnd }) — готовый трек (кроссфейд-петля).
   MUS.play(key, { fade }) / MUS.stop(fade) / MUS.intensity(0..1) — слои с min > напряжения затихают. */
const NOTE_I = { C: 0, 'C#': 1, Db: 1, D: 2, 'D#': 3, Eb: 3, E: 4, F: 5, 'F#': 6, Gb: 6, G: 7, 'G#': 8, Ab: 8, A: 9, 'A#': 10, Bb: 10, B: 11 };
function noteHz(tok) { const m = /^([A-G][#b]?)(-?\d)$/.exec(tok); if (!m) return 0; return 440 * 2 ** ((NOTE_I[m[1]] + (+m[2] + 1) * 12 - 69) / 12); }
const MUS = {
  songs: {}, cur: null, key: null, inten: 0, waves: {}, timer: null, bufs: {},
  def(key, s) { this.songs[key] = s; s.key = key; return s; },
  wave(kind) {
    const c = AU.ctx; if (this.waves[kind]) return this.waves[kind];
    const duty = { pulse12: .125, pulse25: .25, square: .5 }[kind]; if (!duty) return null;
    const n = 64, re = new Float32Array(n), im = new Float32Array(n); for (let k = 1; k < n; k++) im[k] = 2 / (k * PI) * Math.sin(k * PI * duty);
    return this.waves[kind] = c.createPeriodicWave(re, im);
  },
  // ---- переключение ----
  play(key, o = {}) {
    if (!AU.ctx) { this.pending = key; return; }
    if (this.key === key && this.cur) return; this.stop(o.fade ?? 1.2); this.key = key; const S = this.songs[key]; if (!S) return;
    const c = AU.ctx, g = c.createGain(); g.gain.value = .0001; g.gain.setTargetAtTime(S.vol ?? 1, c.currentTime, o.fadeIn ?? .4); g.connect(AU.music);
    const cur = this.cur = { S, g, t0: c.currentTime + .08, step: 0, chans: {}, srcs: [] };
    if (S.src) { this.playSample(cur); return; }
    for (const name in S.ch) { const ch = S.ch[name], cg = c.createGain(); cg.gain.value = this.chanOn(ch) ? 1 : .0001; cg.connect(g);
      let out = cg; if (ch.inst && ch.inst.echo) { const d = c.createDelay(1), fb = c.createGain(), wet = c.createGain(); d.delayTime.value = ch.inst.echo[0]; fb.gain.value = ch.inst.echo[1]; wet.gain.value = .35; cg.connect(d); d.connect(fb); fb.connect(d); d.connect(wet); wet.connect(g); }
      const toks = ch.pat.join(' ').trim().split(/\s+/); cur.chans[name] = { ch, cg, toks, last: null };
      if (!cur.len || toks.length > cur.len) cur.len = toks.length; }
    this.timer = this.timer || setInterval(() => this.sched(), 25); this.sched();
  },
  stop(fade = 1) {
    const cur = this.cur; this.cur = null; this.key = null; if (!cur || !AU.ctx) return;
    const t = AU.ctx.currentTime; cur.g.gain.cancelScheduledValues(t); cur.g.gain.setTargetAtTime(.0001, t, Math.max(.01, fade / 3));
    setTimeout(() => { try { cur.g.disconnect(); } catch (_) { } for (const s of cur.srcs) try { s.stop(); } catch (_) { } }, fade * 1000 + 600);
  },
  chanOn(ch) { return (ch.inst && ch.inst.min || 0) <= this.inten + 1e-6; },
  intensity(v) {
    v = clamp(v, 0, 1); if (Math.abs(v - this.inten) < .02) return; this.inten = v; const cur = this.cur; if (!cur || !AU.ctx) return; const t = AU.ctx.currentTime;
    for (const n in cur.chans) { const C = cur.chans[n]; C.cg.gain.setTargetAtTime(this.chanOn(C.ch) ? 1 : .0001, t, .6); }
    if (cur.S.tempoUp) cur.rate = 1 + cur.S.tempoUp * v;
  },
  // ---- планировщик шагов ----
  sched() {
    const cur = this.cur; if (!cur || cur.S.src || !AU.ctx) return; const c = AU.ctx, S = cur.S;
    const spb = 60 / S.bpm / ((S.steps || 16) / 4) / (cur.rate || 1);
    while (cur.t0 < c.currentTime + .2) {
      const t = cur.t0, i = cur.step;
      for (const n in cur.chans) { const C = cur.chans[n], tok = C.toks[i % C.toks.length]; this.note(C, tok, t, spb); }
      cur.step++; cur.t0 += spb * (S.swing && i % 2 === 0 ? 1 + S.swing : S.swing && i % 2 ? 1 - S.swing : 1);
    }
  },
  note(C, tok, t, spb) {
    if (!tok || tok === '-' || tok === 'x') return;
    const I = C.ch.inst || {}, c = AU.ctx, out = C.cg;
    if (tok === '.') { if (C.last) { C.last.gain.cancelScheduledValues(t); C.last.gain.setTargetAtTime(.0001, t, (I.r || .04) / 2); C.last = null; } return; }
    if (I.wave === 'drums') return this.drum(tok, t, out, I.vol ?? .3);
    // длительность: сколько '-' дальше
    let len = 1; const toks = C.toks, start = (this.cur.step) % toks.length; for (let j = start + 1; j < start + toks.length && (toks[j % toks.length] === '-' || toks[j % toks.length] === 'x'); j++) len++;
    const dur = len * spb, f = noteHz(tok) * 2 ** (I.oct || 0); if (!f) return;
    if (C.last) { C.last.gain.cancelScheduledValues(t); C.last.gain.setTargetAtTime(.0001, t, .01); }
    const g = c.createGain(), v = I.vol ?? .12, a = I.a ?? .005, d = I.d ?? .12, s = I.s ?? .55, r = I.r ?? .06;
    g.gain.setValueAtTime(.0001, t); g.gain.linearRampToValueAtTime(v, t + a); g.gain.setTargetAtTime(v * s, t + a, d / 3);
    g.gain.setTargetAtTime(.0001, t + Math.max(a, dur - r * .5), r / 3); g.connect(out); C.last = g;
    const voices = I.detune ? [-I.detune / 2, I.detune / 2] : [0];
    for (const dt of voices) {
      let o;
      if (I.wave === 'noise') { o = c.createBufferSource(); o.buffer = AU.noise; o.loop = true; const bp = c.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = f; bp.Q.value = 6; o.connect(bp); bp.connect(g); }
      else { o = c.createOscillator(); const pw = this.wave(I.wave || 'square'); if (pw) o.setPeriodicWave(pw); else o.type = I.wave === 'saw' ? 'sawtooth' : I.wave || 'square';
        o.frequency.setValueAtTime(C.glideF && I.glide ? C.glideF : f, t); if (I.glide) o.frequency.exponentialRampToValueAtTime(f, t + I.glide); o.detune.value = dt;
        if (I.vib) { const l = c.createOscillator(), lg = c.createGain(); l.frequency.value = I.vib[0]; lg.gain.setValueAtTime(0, t); lg.gain.linearRampToValueAtTime(f * (2 ** (I.vib[1] / 12) - 1), t + (I.vib[2] ?? .12) + .05); l.connect(lg); lg.connect(o.frequency); l.start(t); l.stop(t + dur + r + .1); }
        if (voices.length > 1) { const half = c.createGain(); half.gain.value = .6; o.connect(half); half.connect(g); } else o.connect(g); }
      o.start(t); o.stop(t + dur + r + .15);
    }
    C.glideF = f;
  },
  drum(k, t, out, v) {
    const c = AU.ctx, g = c.createGain(); g.connect(out);
    const nz = (dur, fq, type, vol, q = 1) => { const s = c.createBufferSource(), f = c.createBiquadFilter(), e = c.createGain(); s.buffer = AU.noise; f.type = type; f.frequency.value = fq; f.Q.value = q; e.gain.setValueAtTime(vol, t); e.gain.exponentialRampToValueAtTime(.0001, t + dur); s.connect(f); f.connect(e); e.connect(g); s.start(t, Math.random()); s.stop(t + dur + .02); };
    if (k === 'k') { const o = c.createOscillator(), e = c.createGain(); o.type = 'triangle'; o.frequency.setValueAtTime(150, t); o.frequency.exponentialRampToValueAtTime(42, t + .12); e.gain.setValueAtTime(v * 1.6, t); e.gain.exponentialRampToValueAtTime(.0001, t + .18); o.connect(e); e.connect(g); o.start(t); o.stop(t + .2); }
    else if (k === 's') { nz(.14, 1800, 'bandpass', v * .9, .8); const o = c.createOscillator(), e = c.createGain(); o.type = 'triangle'; o.frequency.setValueAtTime(220, t); o.frequency.exponentialRampToValueAtTime(140, t + .06); e.gain.setValueAtTime(v * .6, t); e.gain.exponentialRampToValueAtTime(.0001, t + .08); o.connect(e); e.connect(g); o.start(t); o.stop(t + .1); }
    else if (k === 'h') nz(.035, 8000, 'highpass', v * .35);
    else if (k === 'o') nz(.22, 7000, 'highpass', v * .3);
    else if (k === 'c') nz(.9, 5000, 'highpass', v * .35);
    else if (k === 't') { const o = c.createOscillator(), e = c.createGain(); o.type = 'triangle'; o.frequency.setValueAtTime(180, t); o.frequency.exponentialRampToValueAtTime(90, t + .15); e.gain.setValueAtTime(v, t); e.gain.exponentialRampToValueAtTime(.0001, t + .2); o.connect(e); e.connect(g); o.start(t); o.stop(t + .22); }
  },
  // ---- готовый трек из data URL: декодируем один раз, петля с кроссфейдом ----
  async playSample(cur) {
    const S = cur.S, c = AU.ctx;
    let buf = this.bufs[S.key];
    if (!buf) { try { const b64 = S.src.split(',')[1], bin = atob(b64), u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); buf = this.bufs[S.key] = await c.decodeAudioData(u.buffer); } catch (e) { console.warn('music decode', e); return; } }
    if (this.cur !== cur) return;
    const end = S.loopEnd || buf.duration - 2.5, xf = S.xfade || 2.5, L0 = S.loopStart || 0;
    // каждый экземпляр играет [start, end], следующий вступает за xf секунд до конца с плавным переходом
    const go = (when, start, first) => { if (this.cur !== cur) return; const s = c.createBufferSource(), e = c.createGain(), len = end - start; s.buffer = buf; s.connect(e); e.connect(cur.g);
      if (first) e.gain.setValueAtTime(1, when); else { e.gain.setValueAtTime(.0001, when); e.gain.linearRampToValueAtTime(1, when + xf); }
      e.gain.setValueAtTime(1, when + len - xf); e.gain.linearRampToValueAtTime(.0001, when + len);
      s.start(when, start); s.stop(when + len + .05); cur.srcs.push(s); if (cur.srcs.length > 4) cur.srcs.shift();
      const next = when + len - xf; setTimeout(() => go(next, L0, false), Math.max(0, (next - c.currentTime - .6) * 1000)); };
    go(c.currentTime + .05, S.start || 0, true);
  },
};

/* ---- общие инструменты ---- */
const INS = {
  lead: { wave: 'pulse25', vol: .085, a: .005, d: .15, s: .6, r: .08, vib: [5.5, .18, .18] },
  lead2: { wave: 'square', vol: .06, a: .01, d: .2, s: .5, r: .1, vib: [5, .12, .2], detune: 8 },
  thin: { wave: 'pulse12', vol: .055, a: .003, d: .08, s: .35, r: .05 },
  bell: { wave: 'sine', vol: .1, a: .002, d: .5, s: .05, r: .4, oct: 1 },
  bass: { wave: 'triangle', vol: .2, a: .004, d: .1, s: .8, r: .05 },
  pad: { wave: 'triangle', vol: .06, a: .25, d: .5, s: .8, r: .6 },
  drums: { wave: 'drums', vol: .32 },
  saw: { wave: 'saw', vol: .045, a: .02, d: .3, s: .6, r: .2, detune: 12 },
};
