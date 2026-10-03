/* ================= ЗВУК: синтезатор, секвенсор, треки, эффекты ================= */
let AC = null, MASTER, MUS, SFXB, REV, NOISE, PULSE25, PULSE12, LEG, legDelay;
let pendingTrack = null;
const VOL = { mus: .8, sfx: .9 };
const mf = m => 440 * 2 ** ((m - 69) / 12);

function initAudio() {
  if (AC) { if (AC.state !== 'running') AC.resume(); return; }
  const C = window.AudioContext || window.webkitAudioContext; if (!C) return;
  AC = new C(); buildGraph();
  setInterval(schedMusic, 25);
  if (pendingTrack !== null) { const p = pendingTrack; pendingTrack = null; music(p); }
}
function buildGraph() {
  const comp = AC.createDynamicsCompressor();
  comp.threshold.value = -16; comp.knee.value = 12; comp.ratio.value = 3; comp.attack.value = .004; comp.release.value = .2;
  MASTER = AC.createGain(); MASTER.gain.value = .9; MASTER.connect(comp); comp.connect(AC.destination);
  // ревербератор (сгенерированный импульс)
  REV = AC.createConvolver(); const len = AC.sampleRate * 2.4, ir = AC.createBuffer(2, len, AC.sampleRate);
  for (let ch = 0; ch < 2; ch++) { const d = ir.getChannelData(ch); for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / len) ** 3.4; }
  REV.buffer = ir; const rg = AC.createGain(); rg.gain.value = .32; REV.connect(rg); rg.connect(MASTER);
  MUS = AC.createGain(); MUS.gain.value = VOL.mus; MUS.connect(MASTER);
  SFXB = AC.createGain(); SFXB.gain.value = VOL.sfx; SFXB.connect(MASTER);
  NOISE = AC.createBuffer(1, AC.sampleRate * 2, AC.sampleRate);
  const nd = NOISE.getChannelData(0); for (let i = 0; i < nd.length; i++) nd[i] = Math.random() * 2 - 1;
  // 25% пульс для чиптюна
  const n = 32, re = new Float32Array(n), im = new Float32Array(n);
  for (let k = 1; k < n; k++) im[k] = 2 / (k * PI) * Math.sin(k * PI * .25);
  PULSE25 = AC.createPeriodicWave(re, im);
  const im2 = new Float32Array(n); for (let k = 1; k < n; k++) im2[k] = 2 / (k * PI) * Math.sin(k * PI * .125); PULSE12 = AC.createPeriodicWave(re, im2);
  // «старая» шина для боевой музыки — как в оригинальной игре (задержка 0.3с)
  LEG = AC.createGain(); LEG.gain.value = .8;
  const d = AC.createDelay(), g = AC.createGain(), lp = AC.createBiquadFilter();
  d.delayTime.value = .3; g.gain.value = .3; lp.frequency.value = 2400;
  LEG.connect(MUS); LEG.connect(d); d.connect(lp); lp.connect(g); g.connect(d); g.connect(MUS);
}
function setVol() { if (!AC) return; MUS.gain.setTargetAtTime(VOL.mus, AC.currentTime, .05); SFXB.gain.setTargetAtTime(VOL.sfx, AC.currentTime, .05); }

/* ---------- кирпичики синтеза ---------- */
function envG(out, t, v, a, d, sus = 0, rel = 0) { // a=атака, d=длительность, sus>0 — держать уровень
  const g = AC.createGain(); g.gain.setValueAtTime(.0001, t); g.gain.linearRampToValueAtTime(v, t + a);
  if (sus) { g.gain.setTargetAtTime(v * sus, t + a, d * .3); g.gain.setTargetAtTime(.0001, t + d, rel / 4 + .01); }
  else g.gain.exponentialRampToValueAtTime(.0001, t + d);
  g.connect(out); return g;
}
function osc(type, fr, t, end, dest) { const o = AC.createOscillator(); if (type === 'p25') o.setPeriodicWave(PULSE25); else if (type === 'p12') o.setPeriodicWave(PULSE12); else o.type = type; o.frequency.value = fr; o.connect(dest); o.start(t); o.stop(end); return o; }
function fm(out, t, fr, d, v, ratio, idx, idd, a = .004) {
  const g = envG(out, t, v, a, d), c = osc('sine', fr, t, t + d + .05, g);
  const m = AC.createOscillator(), mg = AC.createGain(); m.frequency.value = fr * ratio;
  mg.gain.setValueAtTime(fr * idx, t); mg.gain.exponentialRampToValueAtTime(fr * idx * .04 + .01, t + idd);
  m.connect(mg); mg.connect(c.frequency); m.start(t); m.stop(t + d + .05);
}
function noise(out, t, d, v, type, fq, q = 1, a = .002) {
  const s = AC.createBufferSource(), fl = AC.createBiquadFilter(), g = envG(out, t, v, a, d);
  s.buffer = NOISE; fl.type = type; fl.frequency.value = fq; fl.Q.value = q; s.connect(fl); fl.connect(g);
  s.start(t, Math.random() * Math.max(0, 1.9 - d)); s.stop(t + d + .05); return fl;
}

/* ---------- инструменты: (выход, время, midi, длительность(с), громкость) ---------- */
const INS = {
  ep(o, t, m, d, v) { const fr = mf(m), dd = Math.max(.5, d * 1.4); fm(o, t, fr, dd, v, 1, 1.6, .35); fm(o, t, fr * 2.001, dd * .5, v * .22, 1, .6, .15); fm(o, t, fr, .12, v * .25, 14, 1.2, .08); },
  vibe(o, t, m, d, v) {
    const fr = mf(m), dd = Math.max(.9, d * 2), g = envG(o, t, v, .003, dd);
    const tr = AC.createGain(); tr.gain.value = .75; tr.connect(g);
    const l = AC.createOscillator(), lg = AC.createGain(); l.frequency.value = 5.2; lg.gain.value = .25; l.connect(lg); lg.connect(tr.gain); l.start(t); l.stop(t + dd + .05);
    osc('sine', fr, t, t + dd + .05, tr); const g2 = envG(o, t, v * .35, .002, .25); osc('sine', fr * 4, t, t + .3, g2);
  },
  marimba(o, t, m, d, v) { const fr = mf(m); osc('sine', fr, t, t + .5, envG(o, t, v, .002, .42)); osc('sine', fr * 3.98, t, t + .1, envG(o, t, v * .3, .001, .07)); osc('triangle', fr * 2, t, t + .2, envG(o, t, v * .15, .001, .12)); },
  pluck(o, t, m, d, v) {
    const fr = mf(m), dd = Math.min(.6, d + .2), g = envG(o, t, v, .002, dd), lp = AC.createBiquadFilter();
    lp.type = 'lowpass'; lp.Q.value = 3; lp.frequency.setValueAtTime(5200, t); lp.frequency.exponentialRampToValueAtTime(600, t + dd * .8); lp.connect(g);
    osc('sawtooth', fr, t, t + dd + .05, lp); osc('square', fr * 1.004, t, t + dd + .05, lp).detune.value = 7;
  },
  sq(o, t, m, d, v) {
    const fr = mf(m), g = envG(o, t, v, .006, d, .7, .08), lp = AC.createBiquadFilter(); lp.frequency.value = 4200; lp.connect(g);
    const s = osc('square', fr, t, t + d + .2, lp);
    if (d > .2) { const l = AC.createOscillator(), lg = AC.createGain(); l.frequency.value = 5.5; lg.gain.setValueAtTime(0, t); lg.gain.linearRampToValueAtTime(fr * .012, t + .25); l.connect(lg); lg.connect(s.frequency); l.start(t); l.stop(t + d + .2); }
  },
  pulse(o, t, m, d, v) { const g = envG(o, t, v, .004, d, .6, .05); osc('p25', mf(m), t, t + d + .15, g); },
  tri(o, t, m, d, v) { const g = envG(o, t, v, .004, d, .85, .03); osc('triangle', mf(m), t, t + d + .1, g); },
  bass(o, t, m, d, v) {
    const fr = mf(m), dd = Math.max(.25, d), g = envG(o, t, v, .006, dd * 1.1), lp = AC.createBiquadFilter(); lp.frequency.value = 700; lp.connect(g);
    osc('triangle', fr, t, t + dd * 1.1 + .05, lp); osc('sine', fr, t, t + dd * 1.1 + .05, lp); osc('sine', fr * 2, t, t + .08, envG(o, t, v * .25, .002, .06));
  },
  sbass(o, t, m, d, v) {
    const fr = mf(m), g = envG(o, t, v, .004, d, .55, .05), lp = AC.createBiquadFilter(); lp.Q.value = 6;
    lp.frequency.setValueAtTime(1400, t); lp.frequency.exponentialRampToValueAtTime(260, t + .18); lp.connect(g);
    osc('sawtooth', fr, t, t + d + .12, lp); osc('sine', fr / 2, t, t + d + .12, g);
  },
  pad(o, t, m, d, v) {
    const fr = mf(m), g = envG(o, t, v, .35, d, .9, .7), lp = AC.createBiquadFilter(); lp.frequency.value = 1300; lp.connect(g);
    osc('sawtooth', fr, t, t + d + .9, lp).detune.value = -7; osc('sawtooth', fr, t, t + d + .9, lp).detune.value = 7; osc('triangle', fr / 2, t, t + d + .9, lp);
  },
  str(o, t, m, d, v) {
    const fr = mf(m), g = envG(o, t, v, .18, d, .9, .4), lp = AC.createBiquadFilter(); lp.frequency.value = 2200; lp.connect(g);
    const a = osc('sawtooth', fr, t, t + d + .6, lp); a.detune.value = -5; const b = osc('sawtooth', fr, t, t + d + .6, lp); b.detune.value = 6;
    const l = AC.createOscillator(), lg = AC.createGain(); l.frequency.value = 5; lg.gain.value = fr * .006; l.connect(lg); lg.connect(a.frequency); lg.connect(b.frequency); l.start(t); l.stop(t + d + .6);
  },
  bell(o, t, m, d, v) { fm(o, t, mf(m), Math.max(1.4, d * 2), v, 3.5, 3, .9); },
  mbox(o, t, m, d, v) { const fr = mf(m); osc('sine', fr, t, t + 1.3, envG(o, t, v, .002, 1.2)); osc('sine', fr * 3, t, t + .5, envG(o, t, v * .22, .001, .4)); osc('sine', fr * 5.4, t, t + .2, envG(o, t, v * .1, .001, .15)); },
  piano(o, t, m, d, v) {
    const fr = mf(m), dd = Math.max(.6, d * 1.6), lp = AC.createBiquadFilter(), g = envG(o, t, v, .003, dd);
    lp.frequency.setValueAtTime(3600, t); lp.frequency.exponentialRampToValueAtTime(900, t + dd); lp.connect(g);
    osc('triangle', fr, t, t + dd + .05, lp); osc('sine', fr * 2.002, t, t + dd + .05, lp); osc('sawtooth', fr * .999, t, t + .3, envG(lp, t, v * .15, .002, .25));
  },
  // ведущий чиптюн-голос: 25%-пульс, удвоение с расстройкой, вибрато с задержкой
  lead(o, t, m, d, v) {
    const fr = mf(m), g = envG(o, t, v, .005, d, .72, .07), lp = AC.createBiquadFilter(); lp.frequency.value = 5200; lp.connect(g);
    const a = osc('p25', fr, t, t + d + .15, lp), b = osc('p25', fr, t, t + d + .15, lp); b.detune.value = 9;
    if (d > .18) { const l = AC.createOscillator(), lg = AC.createGain(); l.frequency.value = 6; lg.gain.setValueAtTime(0, t); lg.gain.linearRampToValueAtTime(fr * .016, t + .22); l.connect(lg); lg.connect(a.frequency); lg.connect(b.frequency); l.start(t); l.stop(t + d + .15); }
  },
  // тонкий 12.5%-пульс для арпеджио
  chip(o, t, m, d, v) { const g = envG(o, t, v, .002, Math.min(d, .22), .4, .04); osc('p12', mf(m), t, t + Math.min(d, .22) + .08, g); },
  saw(o, t, m, d, v) { const g = envG(o, t, v, .005, d, .7, .06), lp = AC.createBiquadFilter(); lp.frequency.value = 2600; lp.Q.value = 2; lp.connect(g); osc('sawtooth', mf(m), t, t + d + .15, lp); osc('square', mf(m) * .5, t, t + d + .15, envG(lp, t, v * .3, .005, d, .7, .06)); },
};
const DRUM = {
  k(o, t, v) { const g = envG(o, t, v, .002, .32), s = AC.createOscillator(); s.frequency.setValueAtTime(150, t); s.frequency.exponentialRampToValueAtTime(42, t + .14); s.connect(g); s.start(t); s.stop(t + .35); noise(o, t, .02, v * .25, 'lowpass', 2500); },
  s(o, t, v) { noise(o, t, .17, v * .8, 'bandpass', 1900, .8); osc('triangle', 190, t, t + .1, envG(o, t, v * .5, .002, .08)); },
  h(o, t, v) { noise(o, t, .04, v * .5, 'highpass', 7800); },
  oh(o, t, v) { noise(o, t, .22, v * .45, 'highpass', 7000); },
  r(o, t, v) { osc('triangle', 1650, t, t + .05, envG(o, t, v * .7, .001, .035)); noise(o, t, .015, v * .4, 'bandpass', 3000, 3); },
  sh(o, t, v) { noise(o, t, .06, v * .35, 'bandpass', 6500, 1.5, .012); },
  c(o, t, v) { for (let i = 0; i < 3; i++) noise(o, t + i * .011, .09, v * .6, 'bandpass', 1300, 1.2); },
  br(o, t, v) { const fl = noise(o, t, .2, v * .4, 'bandpass', 3200, .7, .03); fl.frequency.exponentialRampToValueAtTime(1500, t + .2); },
  tk(o, t, v) { osc('sine', 2600, t, t + .03, envG(o, t, v * .4, .001, .02)); },
  orb(o, t, v) { const g = envG(o, t, v * .5, .002, .16), s = AC.createOscillator(); s.type = 'sine'; s.frequency.setValueAtTime(380 + Math.random() * 240, t); s.frequency.exponentialRampToValueAtTime(1400 + Math.random() * 600, t + .1); s.connect(g); s.start(t); s.stop(t + .18); },
};

/* ---------- нотная запись ---------- */
const NN = { c: 0, d: 2, e: 4, f: 5, g: 7, a: 9, b: 11 };
function nm(s) { const m = /^([a-gA-G])(#|b)?(-?\d)$/.exec(s); if (!m) return null; return NN[m[1].toLowerCase()] + (m[2] === '#' ? 1 : m[2] === 'b' ? -1 : 0) + (+m[3] + 1) * 12; }
function parseMel(bars) {
  return bars.map(b => { const ev = []; let s = 0; for (const tk of b.trim().split(/\s+/)) { if (!tk) continue; const [n, l] = tk.split(':'), d = +(l || 2); if (n !== 'r') ev.push({ s, m: nm(n), d }); s += d; } return ev; });
}
const QUAL = { '': [0, 4, 7], m: [0, 3, 7], '7': [0, 4, 7, 10], maj7: [0, 4, 7, 11], m7: [0, 3, 7, 10], m6: [0, 3, 7, 9], '6': [0, 4, 7, 9], '9': [0, 4, 10, 14], m9: [0, 3, 10, 14], maj9: [0, 4, 11, 14], dim: [0, 3, 6], dim7: [0, 3, 6, 9], m7b5: [0, 3, 6, 10], sus4: [0, 5, 7], sus2: [0, 2, 7], add9: [0, 4, 7, 14], '7#9': [0, 4, 10, 15], aug: [0, 4, 8], '7b9': [0, 4, 10, 13], mmaj7: [0, 3, 7, 11] };
function chord(sym) {
  const m = /^([A-G])(#|b)?(.*)$/.exec(sym); let r = NN[m[1].toLowerCase()] + (m[2] === '#' ? 1 : m[2] === 'b' ? -1 : 0);
  const iv = QUAL[m[3]] || QUAL['']; const vo = iv.map(i => { let n = 48 + r + i; while (n < 55) n += 12; while (n > 70) n -= 12; return n; }).sort((a, b) => a - b);
  return { root: 36 + r, iv, vo };
}
function parseChords(bars) { return bars.map(b => { const cs = b.trim().split(/\s+/); return cs.map((c, i) => ({ s: i * 16 / cs.length, c: chord(c) })); }); }

// узоры аккомпанемента и баса: [шаг, интервал/индекс, длительность в 16-х]
const BASSPAT = {
  bossa: [[0, 0, 5], [6, 7, 2], [8, 7, 5], [14, 0, 2]],
  funk: [[0, 0, 3], [3, 0, 1], [6, 12, 1], [8, 0, 2], [10, 7, 1], [11, 10, 1], [12, 12, 2], [14, 7, 2]],
  root8: [[0, 0, 2], [2, 12, 2], [4, 0, 2], [6, 12, 2], [8, 0, 2], [10, 12, 2], [12, 0, 2], [14, 12, 2]],
  drive: [[0, 0, 1], [2, 0, 1], [4, 0, 1], [6, 0, 1], [8, 0, 1], [10, 0, 1], [12, 0, 1], [14, 12, 1]],
  half: [[0, 0, 8], [8, 7, 8]], whole: [[0, 0, 16]], pulse: [[0, 0, 3], [4, 7, 3], [8, 0, 3], [12, 7, 3]],
  walk: 'walk',
};
const COMPPAT = {
  bossa: [[0, 3], [3, 2], [6, 3], [10, 2], [12, 3]], stab: [[4, 2], [12, 2]], off: [[2, 1], [6, 1], [10, 1], [14, 1]],
  pad: [[0, 16]], half: [[0, 8], [8, 8]], charl: [[0, 2], [6, 2], [8, 2], [11, 3]],
};
function drumParse(s) { return s ? [...s].map(c => c === 'X' ? 1 : c === 'x' ? .7 : c === 'o' ? .3 : 0) : null; }

/* ---------- треки (вся музыка оригинальная, в духе указанных жанров) ---------- */
const TR = {};
function track(name, def) {
  def.name = name; def.mel = def.mel ? parseMel(def.mel) : null; def.ch = parseChords(def.chords); def.bars = def.ch.length;
  if (def.mel2) def.mel2 = parseMel(def.mel2);
  if (def.drums) { const d = {}; for (const k in def.drums) d[k] = drumParse(def.drums[k]); def.drums = d; }
  if (def.drumsB) { const d = {}; for (const k in def.drumsB) d[k] = drumParse(def.drumsB[k]); def.drumsB = d; }
  TR[name] = def;
}
// Утро (запасной синтез-вариант; основной — готовый трек MUS_SRC.home, см. ниже)
track('morning_syn', {
  bpm: 114, swing: .13, tr: 0, rev: .35,
  chords: ['Fmaj7', 'Em7 A7', 'Dm7', 'Cm7 F7', 'Bbmaj7', 'Bbm6', 'Am7 D7', 'Gm7 C7', 'Fmaj7', 'D7', 'Gm7', 'C7', 'Am7 D7', 'Gm7 C7', 'F6', 'Gm7 C7'],
  mel: ['A4:2 C5:2 E5:3 r:1 D5:2 C5:2 A4:4', 'G#4:2 A4:2 C#5:2 E5:2 G5:3 F5:1 E5:4', 'F5:3 E5:1 D5:2 C5:2 A4:4 r:4', 'Eb5:2 D5:2 C5:2 Bb4:2 A4:2 C5:2 Eb5:4',
    'D5:3 r:1 D5:2 F5:2 A5:4 G5:2 F5:2', 'Db5:2 F5:2 G5:3 r:1 F5:2 Db5:2 Bb4:4', 'C5:2 E5:2 G5:2 E5:2 F#5:3 r:1 A5:4', 'Bb5:2 A5:2 G5:2 F5:2 E5:2 D5:2 C5:2 Bb4:2',
    'A5:4 r:2 G5:1 A5:1 G5:2 E5:2 C5:4', 'F#5:3 r:1 F#5:2 A5:2 C6:4 A5:2 F#5:2', 'G5:2 Bb5:2 D6:3 r:1 C6:2 Bb5:2 G5:4', 'E5:2 G5:2 Bb5:2 G5:2 E5:2 C5:2 Db5:2 D5:2',
    'E5:3 r:1 C5:2 A4:2 F#5:3 r:1 D5:4', 'F5:2 D5:2 Bb4:2 G4:2 E5:3 r:1 C5:4', 'A4:2 C5:2 D5:2 F5:2 A5:6 r:2', 'G5:1 Ab5:1 A5:2 Bb5:2 B5:2 C6:4 r:4'],
  parts: [{ t: 'mel', i: 'vibe', v: .13, o: 12 }, { t: 'mel', i: 'ep', v: .05, o: 0 }, { t: 'comp', i: 'ep', v: .045, p: 'bossa' }, { t: 'bass', i: 'bass', v: .3, p: 'bossa' }],
  drums: { r: 'x..x..x...x..x..', sh: 'oxoxoxoxoxoxoxox', k: 'x.......x.....o.', br: '....x.......x...' },
});
// Школа: бодрый чиптюн в духе Deltarune — пульс-лид, маримба октавой ниже, «прыгающий» бас
track('school', {
  bpm: 116, swing: .1, rev: .2,
  chords: ['C', 'Em', 'Am', 'F', 'Dm', 'G', 'C', 'G'],
  mel: ['E5:2 G5:2 C6:2 G5:2 E5:2 D5:2 C5:4', 'B4:2 E5:2 G5:2 B5:2 A5:2 G5:2 E5:4', 'A5:3 r:1 A5:2 C6:2 B5:2 A5:2 E5:4', 'F5:2 A5:2 C6:2 A5:2 G5:4 r:4',
    'D5:2 F5:2 A5:2 D6:2 C6:2 A5:2 F5:4', 'G5:2 B5:2 D6:2 G6:3 r:1 F6:2 D6:2 B5:2', 'E6:3 r:1 D6:2 C6:2 G5:2 E5:2 C6:4', 'B5:2 C6:2 D6:2 B5:2 G5:4 r:4'],
  parts: [{ t: 'mel', i: 'lead', v: .05, o: 0 }, { t: 'mel', i: 'marimba', v: .07, o: -12 }, { t: 'comp', i: 'piano', v: .025, p: 'off' }, { t: 'bass', i: 'tri', v: .2, p: 'root8' }],
  drums: { k: 'x.......x..x....', s: '....x.......x...', h: 'x.o.x.o.x.o.x.o.' },
});
// Битва — оставлена как в оригинале (см. legacyBattle)
TR.battle = { name: 'battle', legacy: 1, bpm: 156 };
track('title', {
  bpm: 84, swing: 0, rev: .5,
  chords: ['Am', 'F', 'C', 'G', 'Am', 'F', 'Dm', 'E'],
  mel: ['E5:4 A5:4 B5:2 C6:2 B5:4', 'A5:6 G5:2 F5:4 E5:4', 'G5:4 C6:4 E6:4 D6:2 C6:2', 'D6:8 B5:4 G5:4', 'E5:4 A5:4 C6:4 B5:2 A5:2', 'F5:4 A5:4 C6:4 D6:4', 'F6:4 E6:4 D6:4 C6:2 B5:2', 'B5:8 G#5:4 E5:4'],
  parts: [{ t: 'mel', i: 'bell', v: .07, o: 0 }, { t: 'arp', i: 'piano', v: .06, every: 2, o: 0 }, { t: 'comp', i: 'pad', v: .035, p: 'pad' }, { t: 'bass', i: 'bass', v: .26, p: 'whole' }],
  drums: { k: 'x.......x.......' },
});
track('town_syn', {
  bpm: 124, swing: .06, rev: .18,
  chords: ['G', 'Em', 'C', 'D', 'G', 'B7', 'C Cm', 'G D'],
  mel: ['B4:2 D5:2 G5:2 D5:2 B5:3 A5:1 G5:4', 'E5:2 G5:2 B5:2 G5:2 E5:4 D5:2 E5:2', 'G5:3 r:1 E5:2 C5:2 E5:2 G5:2 C6:4', 'A5:2 F#5:2 D5:2 E5:2 F#5:3 G5:1 A5:4',
    'B5:2 r:2 B5:2 C6:2 D6:3 r:1 B5:4', 'D#5:2 F#5:2 A5:2 B5:2 D#6:3 r:1 B5:4', 'C6:2 B5:2 A5:2 G5:2 Eb5:3 r:1 G5:4', 'G5:4 r:2 D5:2 F#5:2 A5:2 C6:2 F#5:2'],
  parts: [{ t: 'mel', i: 'sq', v: .05, o: 0 }, { t: 'arp', i: 'pulse', v: .025, every: 2, o: 12 }, { t: 'bass', i: 'tri', v: .2, p: 'root8' }],
  drums: { k: 'x...x...x...x...', s: '....x.......x...', h: 'x.x.x.x.x.x.x.xx' },
});
track('evening', {
  bpm: 80, swing: 0, rev: .45,
  chords: ['Cmaj7', 'Am7', 'Fmaj7', 'G', 'Em7', 'Am7', 'Dm7 G7', 'C'],
  mel: ['E5:4 G5:4 B5:4 G5:4', 'C6:6 B5:2 A5:4 E5:4', 'F5:4 A5:4 C6:4 E6:4', 'D6:8 B5:4 G5:4', 'G5:4 B5:4 D6:4 B5:4', 'C6:4 E6:4 D6:2 C6:2 A5:4', 'F5:4 A5:4 B5:4 D6:4', 'C6:12 r:4'],
  parts: [{ t: 'mel', i: 'mbox', v: .1, o: 0 }, { t: 'mel', i: 'piano', v: .04, o: -12 }, { t: 'arp', i: 'piano', v: .045, every: 4, o: 0 }, { t: 'comp', i: 'str', v: .02, p: 'pad' }, { t: 'bass', i: 'bass', v: .22, p: 'half' }],
});
track('night', {
  bpm: 66, swing: 0, rev: .6,
  chords: ['F', 'Dm', 'Bb', 'C', 'F', 'Am', 'Bb C', 'F'],
  mel: ['C6:4 A5:4 F5:4 A5:4', 'D6:4 A5:4 F5:4 D5:4', 'D6:4 C6:4 Bb5:4 F5:4', 'C6:8 G5:4 E5:4', 'F6:4 E6:4 C6:4 A5:4', 'E6:4 C6:4 A5:4 E5:4', 'D6:4 Bb5:4 E6:4 C6:4', 'F6:12 r:4'],
  parts: [{ t: 'mel', i: 'mbox', v: .11, o: 0 }, { t: 'comp', i: 'pad', v: .025, p: 'pad' }, { t: 'bass', i: 'bass', v: .14, p: 'whole' }],
});
track('garage', {
  bpm: 104, swing: 0, rev: .3,
  chords: ['Em', 'Cmaj7', 'Am7', 'B7', 'Em', 'Cmaj7', 'Am7', 'B7'],
  mel: ['B5:4 r:4 G5:2 A5:2 B5:4', 'E6:6 D6:2 B5:4 G5:4', 'C6:4 B5:2 A5:2 E5:8', 'D#6:4 C6:2 B5:2 A5:4 F#5:4', 'E6:4 r:2 D6:2 B5:4 G5:4', 'G5:2 A5:2 B5:4 E6:8', 'E6:2 D6:2 C6:2 B5:2 A5:4 C6:4', 'B5:12 r:4'],
  parts: [{ t: 'mel', i: 'bell', v: .05, o: 0 }, { t: 'arp', i: 'pluck', v: .04, every: 1, o: 12 }, { t: 'bass', i: 'sbass', v: .18, p: 'drive' }, { t: 'comp', i: 'pad', v: .02, p: 'pad' }],
  drums: { k: 'x.....x...x.....', h: '..x...x...x...x.', tk: 'x.x.x.x.x.x.x.x.' },
});
track('citadel', {
  bpm: 72, swing: 0, rev: .55,
  chords: ['Dm', 'Bb', 'Gm', 'A7', 'Dm', 'Bb', 'Eb', 'A'],
  mel: ['A5:8 F5:4 D5:4', 'D6:8 C6:4 Bb5:4', 'Bb5:6 A5:2 G5:4 D5:4', 'C#6:8 E5:4 A5:4', 'F5:4 A5:4 D6:4 F6:4', 'E6:6 D6:2 C6:4 Bb5:4', 'G5:4 Bb5:4 Eb6:4 D6:4', 'C#6:12 r:4'],
  parts: [{ t: 'mel', i: 'bell', v: .06, o: 0 }, { t: 'arp', i: 'piano', v: .055, every: 2, o: -12 }, { t: 'comp', i: 'pad', v: .03, p: 'pad' }, { t: 'bass', i: 'bass', v: .24, p: 'whole' }],
  drums: { tk: 'x...x...x...x...', k: 'x...............' },
});
track('escape', {
  bpm: 158, swing: 0, rev: .2,
  chords: ['Dm', 'Dm', 'Bb', 'C', 'Dm', 'Dm', 'Gm', 'A'],
  mel: ['D5:2 F5:2 A5:2 D6:2 C6:2 A5:2 F5:2 A5:2', 'D6:4 C6:2 A5:2 G5:2 F5:2 E5:2 F5:2', 'F5:2 Bb5:2 D6:2 F6:2 D6:2 Bb5:2 F5:2 D5:2', 'E5:2 G5:2 C6:2 E6:2 G6:4 E6:4',
    'D5:2 F5:2 A5:2 D6:2 C6:2 A5:2 F5:2 A5:2', 'F6:4 E6:2 D6:2 C6:2 A5:2 C6:2 D6:2', 'G5:2 Bb5:2 D6:2 G6:2 F6:2 D6:2 Bb5:2 G5:2', 'A5:2 C#6:2 E6:2 A6:2 G6:2 E6:2 C#6:2 A5:2'],
  parts: [{ t: 'mel', i: 'saw', v: .045, o: 0 }, { t: 'bass', i: 'sbass', v: .2, p: 'root8' }, { t: 'comp', i: 'pad', v: .025, p: 'pad' }],
  drums: { k: 'x...x...x...x...', s: '....x.......x...', h: 'xxxxxxxxxxxxxxxx' },
});
track('fridge', {
  bpm: 100, swing: .08, rev: .55,
  chords: ['Amaj7', 'F#m7', 'Dmaj7', 'E', 'C#m7', 'F#m7', 'Dmaj7', 'E7'],
  mel: ['E6:4 C#6:4 A5:4 G#5:4', 'A5:4 C#6:4 E6:4 F#6:4', 'F#6:6 E6:2 C#6:4 A5:4', 'B5:8 G#5:4 E5:4', 'E6:4 G#6:4 E6:4 C#6:4', 'C#6:4 A5:4 F#5:4 A5:4', 'A5:4 C#6:4 F#6:4 E6:4', 'D6:4 B5:4 G#5:4 E5:4'],
  parts: [{ t: 'mel', i: 'bell', v: .06, o: 0 }, { t: 'mel', i: 'marimba', v: .07, o: -12 }, { t: 'arp', i: 'pluck', v: .025, every: 2, o: 0 }, { t: 'bass', i: 'bass', v: .22, p: 'pulse' }],
  drums: { sh: 'x.x.x.x.x.x.x.x.', k: 'x.......x.......', r: '....x.......x...' },
});
track('space', {
  bpm: 90, swing: 0, rev: .7,
  chords: ['Em9', 'Cmaj9', 'Em9', 'D6'],
  parts: [{ t: 'arp', i: 'bell', v: .035, every: 2, o: 12 }, { t: 'comp', i: 'pad', v: .04, p: 'pad' }, { t: 'bass', i: 'bass', v: .2, p: 'whole' }],
});


/* ---------- боевые темы: у каждого врага своя (чиптюн в духе Undertale/Deltarune) ---------- */
// Мистер Мисикс: гиперактивный мажор, «Я ХОЧУ ПОМОЧЬ!»
track('battle_mees', {
  bpm: 168, swing: 0, rev: .15,
  chords: ['E', 'B', 'C#m', 'A', 'E', 'B', 'A', 'B'],
  mel: ['E5:2 G#5:2 B5:2 G#5:2 E6:3 r:1 B5:2 G#5:2', 'F#5:2 A#5:2 C#6:2 A#5:2 F#6:3 r:1 D#6:2 C#6:2', 'C#6:2 B5:2 G#5:2 E5:2 G#5:2 B5:2 C#6:4', 'A5:2 B5:2 C#6:2 E6:2 D#6:2 C#6:2 B5:4',
    'E6:1 D#6:1 E6:2 B5:2 G#5:2 E5:2 G#5:2 B5:4', 'D#6:1 C#6:1 D#6:2 B5:2 F#5:2 D#5:2 F#5:2 B5:4', 'C#6:2 E6:2 A6:2 E6:2 C#6:2 A5:2 C#6:2 E6:2', 'F#6:3 r:1 E6:2 D#6:2 C#6:2 B5:2 A#5:2 B5:2'],
  parts: [{ t: 'mel', i: 'lead', v: .05, o: 0 }, { t: 'arp', i: 'chip', v: .03, every: 2, o: 12 }, { t: 'bass', i: 'tri', v: .22, p: 'root8' }],
  drums: { k: 'x...x...x...x.x.', s: '....x.......x..o', h: 'xoxoxoxoxoxoxoxo' },
});
// Огурчик-Рик: рок-н-ролльный «безумный учёный» в ля миноре
track('battle_pickle', {
  bpm: 150, swing: 0, rev: .15,
  chords: ['Am', 'F', 'G', 'Am', 'Am', 'F', 'G', 'E'],
  mel: ['A4:2 C5:2 E5:2 A5:3 r:1 G5:2 E5:2 C5:2', 'F5:3 r:1 E5:2 F5:2 A5:4 G5:2 F5:2', 'G5:2 B5:2 D6:2 B5:2 G5:2 D5:2 G5:4', 'E6:4 D6:2 C6:2 B5:2 A5:2 G5:2 E5:2',
    'A5:2 A5:1 A5:1 C6:2 A5:2 E6:3 r:1 D6:2 C6:2', 'F6:3 r:1 E6:2 C6:2 A5:2 C6:2 F6:4', 'G6:2 F6:2 E6:2 D6:2 B5:2 G5:2 B5:2 D6:2', 'E6:4 r:2 G#5:2 B5:2 E6:2 G#6:4'],
  parts: [{ t: 'mel', i: 'saw', v: .042, o: 0 }, { t: 'mel', i: 'sq', v: .025, o: -12 }, { t: 'bass', i: 'sbass', v: .2, p: 'drive' }, { t: 'comp', i: 'pad', v: .018, p: 'pad' }],
  drums: { k: 'x..x..x.x..x....', s: '....x.......x...', h: 'x.x.x.x.x.x.x.x.' },
});
// Злой Морти: тревожный ре минор, струнные и арпеджио фортепиано
track('battle_evil', {
  bpm: 140, swing: 0, rev: .35,
  chords: ['Dm', 'Bb', 'F', 'C', 'Gm', 'Dm', 'A', 'A7'],
  mel: ['D5:4 F5:2 A5:2 D6:6 C6:2', 'Bb5:4 A5:2 F5:2 D5:6 r:2', 'C6:4 A5:2 F5:2 C6:2 D6:2 F6:4', 'E6:6 D6:2 C6:2 G5:2 E5:4',
    'D6:3 r:1 Bb5:2 G5:2 D6:2 Eb6:2 D6:4', 'A5:4 F5:2 D5:2 F5:2 A5:2 D6:4', 'C#6:4 E6:2 A6:2 G6:2 F6:2 E6:4', 'E6:2 C#6:2 A5:2 G5:2 E5:2 C#5:2 A4:4'],
  parts: [{ t: 'mel', i: 'lead', v: .05, o: 0 }, { t: 'arp', i: 'piano', v: .035, every: 1, o: -12 }, { t: 'comp', i: 'str', v: .018, p: 'pad' }, { t: 'bass', i: 'sbass', v: .2, p: 'root8' }],
  drums: { k: 'x.....x.x.......', s: '....x.......x...', h: 'x.x.x.x.x.x.x.x.', tk: '..x...x...x...x.' },
});
// Робот-надзиратель: механический до минор, чёткие «пип-пип»
track('battle_robot', {
  bpm: 132, swing: 0, rev: .12,
  chords: ['Cm', 'Cm', 'Ab', 'G', 'Cm', 'Cm', 'Fm', 'G'],
  mel: ['C5:1 r:1 C5:1 r:1 Eb5:2 G5:2 C6:2 G5:2 Eb5:2 G5:2', 'C6:2 Bb5:2 G5:2 Eb5:2 F5:2 G5:2 C5:4', 'Ab5:1 r:1 Ab5:1 r:1 C6:2 Eb6:2 Ab5:2 C6:2 Eb6:4', 'D6:2 B5:2 G5:2 F5:2 D5:2 B4:2 G4:4',
    'G5:2 C6:2 Eb6:2 C6:2 G5:2 Eb5:2 C5:4', 'C6:1 C6:1 r:2 Bb5:1 Bb5:1 r:2 G5:2 Bb5:2 C6:4', 'F5:2 Ab5:2 C6:2 F6:2 Eb6:2 C6:2 Ab5:4', 'G5:4 B5:4 D6:4 G6:4'],
  parts: [{ t: 'mel', i: 'pulse', v: .055, o: 0 }, { t: 'arp', i: 'chip', v: .03, every: 1, o: 0 }, { t: 'bass', i: 'tri', v: .24, p: 'drive' }],
  drums: { k: 'x...x...x...x...', s: '....x.......x...', tk: 'x.xxx.xxx.xxx.xx' },
});
// Брэд: спортивный фанк-марш, «вышибалы!»
track('battle_brad', {
  bpm: 144, swing: 0, rev: .15,
  chords: ['G', 'F', 'C', 'G', 'G', 'F', 'C', 'D'],
  mel: ['G5:2 r:1 G5:1 F5:2 G5:2 B5:2 D6:2 B5:4', 'A5:2 r:1 A5:1 G5:2 F5:2 C5:2 F5:2 A5:4', 'G5:2 E5:2 C5:2 E5:2 G5:2 C6:2 E6:4', 'D6:3 r:1 B5:2 G5:2 D5:4 r:4',
    'B5:2 D6:2 G6:2 D6:2 F6:2 D6:2 B5:4', 'C6:2 A5:2 F5:2 A5:2 C6:2 F6:2 C6:4', 'E6:2 G6:2 E6:2 C6:2 G5:2 E5:2 G5:4', 'F#5:2 A5:2 D6:2 F#6:2 A6:3 r:1 F#6:4'],
  parts: [{ t: 'mel', i: 'sq', v: .045, o: 0 }, { t: 'mel', i: 'pulse', v: .018, o: 12 }, { t: 'bass', i: 'sbass', v: .2, p: 'funk' }, { t: 'comp', i: 'pluck', v: .028, p: 'stab' }],
  drums: { k: 'x..x..x...x.....', s: '....x..o....x...', h: 'x.x.x.x.x.x.x.x.', c: '............x...' },
});
// Мясной рулет: «булькающий» вальяжный свинг на маримбе
track('battle_slime', {
  bpm: 110, swing: .12, rev: .25,
  chords: ['F', 'D7', 'Gm', 'C7', 'F', 'D7', 'Gm7', 'C7'],
  mel: ['C5:2 F5:2 A5:2 F5:2 C5:2 r:2 A4:4', 'F#5:2 A5:2 C6:2 A5:2 F#5:4 D5:4', 'Bb5:2 D6:2 Bb5:2 G5:2 D5:4 G5:4', 'E5:2 G5:2 Bb5:2 C6:2 Bb5:2 G5:2 E5:4',
    'A5:3 G#5:1 A5:2 C6:2 F6:4 r:4', 'F#6:2 D6:2 A5:2 F#5:2 C6:4 A5:4', 'G5:2 Bb5:2 D6:2 F6:2 E6:2 D6:2 Bb5:4', 'C6:4 Bb5:2 G5:2 E5:2 C5:2 r:4'],
  parts: [{ t: 'mel', i: 'marimba', v: .12, o: 0 }, { t: 'mel', i: 'chip', v: .018, o: 12 }, { t: 'bass', i: 'bass', v: .26, p: 'pulse' }, { t: 'comp', i: 'pluck', v: .025, p: 'off' }],
  drums: { k: 'x.......x.......', s: '....o.......o...', sh: 'x.o.x.o.x.o.x.o.' },
});
// Рик-охранник: Цитадель рушится — быстрая тревожная погоня в ми миноре
track('battle_guard', {
  bpm: 160, swing: 0, rev: .2,
  chords: ['Em', 'C', 'D', 'B', 'Em', 'C', 'Am', 'B7'],
  mel: ['E5:2 G5:2 B5:2 E6:2 D6:2 B5:2 G5:2 B5:2', 'C6:3 r:1 B5:2 G5:2 E5:4 G5:4', 'F#5:2 A5:2 D6:2 F#6:2 E6:2 D6:2 A5:4', 'D#6:4 F#6:4 B5:4 D#6:4',
    'G6:2 F#6:2 E6:2 B5:2 G5:2 B5:2 E6:4', 'E6:2 D6:2 C6:2 G5:2 E5:2 G5:2 C6:4', 'A5:2 C6:2 E6:2 A6:2 G6:2 E6:2 C6:4', 'B5:2 D#6:2 F#6:2 A6:2 B6:4 r:4'],
  parts: [{ t: 'mel', i: 'saw', v: .042, o: 0 }, { t: 'arp', i: 'chip', v: .025, every: 1, o: 12 }, { t: 'bass', i: 'sbass', v: .2, p: 'root8' }],
  drums: { k: 'x...x...x...x...', s: '....x.......x...', h: 'xoxoxoxoxoxoxoxo' },
});

// Рик-наёмник: «вестерн»-чиптюн в ля миноре, пила и щелчки
track('battle_hunter', {
  bpm: 152, swing: 0, rev: .15,
  chords: ['Am', 'Am', 'G', 'F', 'Am', 'Dm', 'E', 'E7'],
  mel: ['A4:3 r:1 E5:2 A5:2 G5:2 E5:2 C5:2 D5:2', 'E5:4 D5:2 C5:2 B4:2 C5:2 A4:4', 'G4:2 B4:2 D5:2 G5:3 r:1 F5:2 D5:2 B4:2', 'C5:2 F5:2 A5:2 C6:4 A5:2 F5:4',
    'A5:2 A5:1 A5:1 C6:2 A5:2 E6:3 r:1 D6:2 C6:2', 'D6:3 r:1 C6:2 A5:2 F5:2 A5:2 D6:4', 'E6:2 D6:2 C6:2 B5:2 G#5:2 B5:2 E6:4', 'G#5:2 B5:2 D6:2 E6:2 D6:2 B5:2 G#5:2 E5:2'],
  parts: [{ t: 'mel', i: 'saw', v: .042, o: 0 }, { t: 'arp', i: 'chip', v: .026, every: 2, o: 12 }, { t: 'bass', i: 'sbass', v: .2, p: 'drive' }, { t: 'comp', i: 'pad', v: .016, p: 'pad' }],
  drums: { k: 'x..x..x.x..x..x.', s: '....x.......x...', h: 'x.x.x.x.x.x.x.xx', tk: '..x...x...x...x.' },
});
/* ---------- Цитадель: город, Нижний ярус, туннель ---------- */
// Центральный квартал: бодрый «городской» чиптюн
track('citcity', {
  bpm: 118, swing: .08, rev: .22,
  chords: ['Fmaj7', 'Em7', 'Dm7', 'C', 'Bb', 'Am7', 'Gm7', 'C7'],
  mel: ['A5:2 C6:2 E6:2 C6:2 A5:3 r:1 G5:2 F5:2', 'G5:2 B5:2 D6:2 B5:2 G5:4 E5:4', 'F5:2 A5:2 C6:2 F6:3 r:1 E6:2 D6:2 C6:2', 'E6:4 C6:2 G5:2 E5:2 G5:2 C6:4',
    'D6:2 Bb5:2 F5:2 Bb5:2 D6:3 r:1 F6:4', 'E6:2 C6:2 A5:2 E5:2 A5:2 C6:2 E6:4', 'D6:2 Bb5:2 G5:2 D5:2 F5:2 G5:2 Bb5:4', 'C6:3 r:1 Bb5:2 G5:2 E5:2 C5:2 E5:2 G5:2'],
  parts: [{ t: 'mel', i: 'lead', v: .045, o: 0 }, { t: 'mel', i: 'marimba', v: .06, o: -12 }, { t: 'comp', i: 'piano', v: .024, p: 'off' }, { t: 'bass', i: 'tri', v: .2, p: 'root8' }],
  drums: { k: 'x.......x..x....', s: '....x.......x...', h: 'x.o.x.o.x.o.x.o.' },
});
// Нижний ярус: грязноватый фанк в ми миноре
track('mortytown', {
  bpm: 100, swing: .15, rev: .25,
  chords: ['Em7', 'Em7', 'Am7', 'B7', 'Em7', 'Em7', 'Cmaj7', 'B7'],
  mel: ['E5:2 r:1 E5:1 G5:2 A5:2 B5:3 r:1 A5:2 G5:2', 'E5:4 r:4 D5:2 E5:2 G5:4', 'A5:2 r:1 A5:1 C6:2 B5:2 A5:3 r:1 G5:2 E5:2', 'F#5:2 A5:2 B5:2 D#6:2 C6:2 B5:2 A5:4',
    'B5:2 r:1 B5:1 D6:2 B5:2 G5:3 r:1 E5:4', 'G5:2 A5:2 B5:2 E6:4 D6:2 B5:4', 'C6:2 B5:2 G5:2 E5:2 G5:2 B5:2 C6:4', 'D#6:3 r:1 B5:2 A5:2 F#5:2 D#5:2 B4:4'],
  parts: [{ t: 'mel', i: 'pluck', v: .07, o: 0 }, { t: 'bass', i: 'sbass', v: .2, p: 'funk' }, { t: 'comp', i: 'ep', v: .04, p: 'stab' }, { t: 'arp', i: 'chip', v: .018, every: 2, o: 12 }],
  drums: { k: 'x.....x...x.....', s: '....x.......x..o', h: 'x.xox.x.x.xox.xo' },
});
// технический туннель: напряжённый «стелс»
track('tunnel', {
  bpm: 96, swing: 0, rev: .4,
  chords: ['Dm', 'Dm', 'Bb', 'A', 'Dm', 'Dm', 'Gm', 'A'],
  mel: ['D5:2 r:2 F5:2 r:2 A5:2 r:2 G5:2 F5:2', 'E5:2 r:2 D5:2 r:6 A4:4', 'D5:2 r:2 F5:2 r:2 Bb5:4 A5:2 G5:2', 'A5:2 r:2 G5:2 r:2 E5:4 C#5:4',
    'D5:1 D5:1 r:2 F5:2 r:2 A5:2 r:2 D6:4', 'C6:2 A5:2 F5:2 D5:2 r:8', 'G5:2 r:2 Bb5:2 r:2 D6:3 r:1 C6:2 Bb5:2', 'A5:4 E5:4 C#5:4 A4:4'],
  parts: [{ t: 'mel', i: 'chip', v: .05, o: 0 }, { t: 'mel', i: 'pulse', v: .018, o: -12 }, { t: 'comp', i: 'pad', v: .02, p: 'pad' }, { t: 'bass', i: 'tri', v: .2, p: 'pulse' }],
  drums: { tk: 'x.x.x.x.x.x.x.x.', k: 'x.......x.......' },
});
// готовые треки (сгенерированы под стиль игры, встроены build.js как MUS_SRC); если не декодируются — играет синтез-вариант
if (typeof MUS_SRC !== 'undefined' && MUS_SRC.home) TR.morning = { name: 'morning', src: MUS_SRC.home, start: 3.9, loopStart: 5.39, loopEnd: 55.385, xfade: 1.25, fallback: 'morning_syn' }; else TR.morning = TR.morning_syn;
if (typeof MUS_SRC !== 'undefined' && MUS_SRC.town) TR.town = { name: 'town', src: MUS_SRC.town, loopStart: 2.14, loopEnd: 50.145, xfade: 1.09, fallback: 'town_syn' }; else TR.town = TR.town_syn;

/* ---------- выравнивание громкости треков (замерено офлайн-рендером, цель ≈ −24 дБ RMS) ---------- */
const TGAIN = { morning: .32, morning_syn: .63, town_syn: .49, school: .5, title: .54, town: .37, evening: .72, night: .81, garage: .64, citadel: .59, escape: .45, fridge: .86, space: .6, battle: 1,
  battle_mees: .5, battle_pickle: .6, battle_evil: .5, battle_robot: .64, battle_brad: .54, battle_slime: .86, battle_guard: .5, battle_hunter: .59,
  citcity: .5, mortytown: .5, tunnel: .57 };
/* ---------- секвенсор ---------- */
let CUR = null; const OLD = [];
function music(name) {
  if (!AC) { pendingTrack = name; return; }
  if (CUR && CUR.name === name) return;
  const now = AC.currentTime;
  if (CUR) { CUR.bus.gain.cancelScheduledValues(now); CUR.bus.gain.setTargetAtTime(.0001, now, .2); CUR.dead = now + 1.6; OLD.push(CUR); if (CUR.srcs) { const ss = CUR.srcs; setTimeout(() => ss.forEach(x_ => { try { x_.stop(); } catch (_) { } }), 1700); } }
  CUR = null; if (!name || !TR[name]) return;
  if (TR[name].bad && TR[name].fallback) return music(TR[name].fallback);
  const def = TR[name], bus = AC.createGain();
  bus.gain.setValueAtTime(.0001, now); bus.gain.setTargetAtTime(TGAIN[name] || 1, now + .05, .25);
  if (def.src) { bus.connect(MUS); CUR = { name, def, bus, step: 0, nt: now + .12, srcs: [] }; playSample(CUR); return; }
  if (def.legacy) bus.connect(LEG); else { bus.connect(MUS); const s = AC.createGain(); s.gain.value = def.rev || .3; bus.connect(s); s.connect(REV); }
  CUR = { name, def, bus, step: 0, nt: now + .12 };
}
let battleKey = 0;
// готовый трек (mp3 в data URL): декодируется один раз, играет петлёй с плавным переходом
const BUFS = {};
async function playSample(c) {
  const def = c.def; let buf = BUFS[def.name];
  if (!buf) { try { const bin = atob(def.src.split(',')[1]), u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); buf = BUFS[def.name] = await AC.decodeAudioData(u.buffer); } catch (e) { console.warn('трек не декодирован', e); def.bad = 1; if (CUR === c && def.fallback) { CUR = null; music(def.fallback); } return; } }
  if (CUR !== c) return;
  // петля по тактам: новый проход стартует за xf секунд до loopStart, так что к моменту loopEnd он ровно на loopStart (биты совпадают)
  const end = def.loopEnd || buf.duration - 2.5, xf = def.xfade || 1, L0 = Math.max(xf, def.loopStart || 0);
  const go = (when, start, first) => { if (CUR !== c) return; const s = AC.createBufferSource(), e = AC.createGain(), len = end - start; s.buffer = buf; s.connect(e); e.connect(c.bus);
    if (first) e.gain.setValueAtTime(1, when); else { e.gain.setValueAtTime(.0001, when); e.gain.linearRampToValueAtTime(1, when + xf); }
    e.gain.setValueAtTime(1, when + len - xf); e.gain.linearRampToValueAtTime(.0001, when + len);
    s.start(when, start); s.stop(when + len + .05); c.srcs.push(s); if (c.srcs.length > 4) c.srcs.shift();
    const next = when + len - xf; setTimeout(() => go(next, L0 - xf, false), Math.max(0, (next - AC.currentTime - .8) * 1000)); };
  go(AC.currentTime + .05, def.start || 0, true);
}
function schedMusic() {
  if (!AC) return;
  for (let i = OLD.length - 1; i >= 0; i--) if (AC.currentTime > OLD[i].dead) { try { OLD[i].bus.disconnect(); } catch (_) { } OLD.splice(i, 1); }
  const c = CUR; if (!c || c.def.src) return;
  const def = c.def, sd = def.legacy ? 30 / def.bpm : 15 / def.bpm;
  if (c.nt < AC.currentTime - .2) c.nt = AC.currentTime + .05;
  while (c.nt < AC.currentTime + .14) {
    if (def.legacy) legacyBattle(c, c.nt, sd); else stepTrack(c, c.nt, sd);
    c.nt += sd; c.step++;
  }
}
function stepTrack(c, t0, sd) {
  const def = c.def, s = c.step % 16, bar = ((c.step / 16) | 0) % def.bars, o = c.bus, tr = def.tr || 0;
  const t = t0 + (s % 2 ? def.swing * sd : 0);
  const chs = def.ch[bar]; let cur = chs[0]; for (const q of chs) if (q.s <= s) cur = q;
  for (const p of def.parts) {
    const ins = INS[p.i];
    if (p.t === 'mel') { const mel = (p.m2 ? def.mel2 : def.mel); if (!mel) continue; for (const e of mel[bar]) if (e.s === s) ins(o, t, e.m + (p.o || 0) + tr, e.d * sd * .95, p.v); }
    else if (p.t === 'comp') { for (const [st, d] of COMPPAT[p.p]) if (st === s) for (const n of chordAt(chs, s).vo) ins(o, t, n + tr, d * sd, p.v); }
    else if (p.t === 'arp') { if (s % p.every === 0) { const vo = chordAt(chs, s).vo, k = (s / p.every) | 0, seq = [0, 1, 2, 3, 2, 1]; const n = vo[seq[k % seq.length] % vo.length]; ins(o, t, n + (p.o || 0) + tr, p.every * sd * 1.4, p.v); } }
    else if (p.t === 'bass') {
      const ch = chordAt(chs, s);
      if (p.p === 'walk') { if (s % 4 === 0) { const iv = [0, ch.iv[1], ch.iv[2], 11][s / 4]; ins(o, t, ch.root + iv + tr, sd * 3.6, p.v); } }
      else for (const [st, iv, d] of BASSPAT[p.p]) if (st === s) ins(o, t, ch.root + iv + tr, d * sd * .92, p.v);
    }
  }
  if (def.drums) for (const k in def.drums) { const v = def.drums[k][s]; if (v) DRUM[k](o, t, v * .5); }
}
function chordAt(chs, s) { let cur = chs[0]; for (const q of chs) if (q.s <= s) cur = q; return cur.c; }

/* Боевая тема: ноты, тембры и сведение — без изменений из оригинальной игры */
const LEGM = { bpm: 156, ch: [[62, 65, 69], [58, 62, 65], [57, 60, 65], [60, 64, 67]], bs: [38, 34, 41, 36], ml: [81, 0, 77, 81, 84, 0, 81, 77, 82, 0, 77, 82, 86, 0, 82, 77, 81, 0, 77, 81, 84, 0, 88, 86, 84, 0, 0, 81, 79, 0, 81, 84] };
function ltn(o, fr, t, d, ty, v) { const s = AC.createOscillator(), g = AC.createGain(); s.type = ty; s.frequency.value = fr; g.gain.setValueAtTime(.0001, t); g.gain.linearRampToValueAtTime(v, t + .008); g.gain.exponentialRampToValueAtTime(.0001, t + d); s.connect(g); g.connect(o); s.start(t); s.stop(t + d + .05); }
function lpno(o, m, t, d, v) { const fr = mf(m); ltn(o, fr, t, d, 'triangle', v); ltn(o, fr * 2, t, d * .5, 'sine', v * .35); ltn(o, fr * .5 * 1.003, t, d, 'sine', v * .3); }
function lns(o, t, d, v, fq) { const s = AC.createBufferSource(), g = AC.createGain(), h = AC.createBiquadFilter(); s.buffer = NOISE; h.type = 'highpass'; h.frequency.value = fq; g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(.0001, t + d); s.connect(h); h.connect(g); g.connect(o); s.start(t); s.stop(t + d); }
function lkick(o, t) { const s = AC.createOscillator(), g = AC.createGain(); s.frequency.setValueAtTime(130, t); s.frequency.exponentialRampToValueAtTime(40, t + .15); g.gain.setValueAtTime(.5, t); g.gain.exponentialRampToValueAtTime(.0001, t + .2); s.connect(g); g.connect(o); s.start(t); s.stop(t + .25); }
function legacyBattle(c, t, sd) {
  const m = LEGM, s = c.step % 32, bar = s >> 3, i = s & 7, ch = m.ch[bar], tr = battleKey, o = c.bus;
  lpno(o, ch[[0, 1, 2, 1, 0, 1, 2, 1][i]] + tr, t, sd * 2.4, .06);
  if (i === 0) ch.forEach(n => ltn(o, mf(n - 12 + tr), t, sd * 8, 'sine', .03));
  if (i % 2 === 0) ltn(o, mf(m.bs[bar] + tr), t, sd * 3, 'sine', .2);
  if (m.ml[s]) lpno(o, m.ml[s] + tr, t, sd * 3.2, .1);
  if (i === 0 || i === 4) lkick(o, t); if (i === 2 || i === 6) lns(o, t, .12, .14, 1800); lns(o, t, .03, .05, 7500);
}

/* ---------- звуковые эффекты ---------- */
const VOICE = {
  morty: { f: 430, w: 'square' }, rick: { f: 150, w: 'sawtooth' }, beth: { f: 330, w: 'triangle' }, jerry: { f: 250, w: 'square' }, summer: { f: 380, w: 'triangle' },
  evil: { f: 300, w: 'sawtooth' }, jessica: { f: 400, w: 'triangle' }, ethan: { f: 260, w: 'square' }, gold: { f: 210, w: 'triangle' }, principal: { f: 180, w: 'square' },
  brad: { f: 160, w: 'square' }, mees: { f: 520, w: 'square' }, pickle: { f: 190, w: 'sawtooth' }, robot: { f: 120, w: 'square' }, guard: { f: 140, w: 'sawtooth' },
  poopy: { f: 470, w: 'sine' }, student: { f: 300, w: 'triangle' }, narr: { f: 240, w: 'square' }, mortyg: { f: 360, w: 'square' }, slime: { f: 110, w: 'sawtooth' },
};
function sfx(k, a) {
  if (!AC) return; const t = AC.currentTime, o = SFXB;
  switch (k) {
    case 'blip': { const v = VOICE[a] || VOICE.narr; const g = envG(o, t, .05, .002, .055); osc(v.w, v.f * (1 + (Math.random() - .5) * .12), t, t + .07, g); break; }
    case 'sel': osc('square', 880, t, t + .06, envG(o, t, .04, .002, .05)); break;
    case 'ok': osc('square', 660, t, t + .06, envG(o, t, .04, .002, .05)); osc('square', 990, t + .05, t + .12, envG(o, t + .05, .04, .002, .06)); break;
    case 'back': osc('square', 440, t, t + .08, envG(o, t, .04, .002, .07)); break;
    case 'portal': { const g = envG(o, t, .22, .02, .9), s = AC.createOscillator(); s.type = 'sawtooth'; s.frequency.setValueAtTime(140, t); s.frequency.exponentialRampToValueAtTime(900, t + .7); const lp = AC.createBiquadFilter(); lp.frequency.value = 1400; s.connect(lp); lp.connect(g); s.start(t); s.stop(t + 1); noise(o, t, .8, .12, 'bandpass', 1200, .6, .1); break; }
    case 'hurt': osc('sawtooth', 180, t, t + .25, envG(o, t, .18, .002, .22)); noise(o, t, .15, .18, 'lowpass', 900); break;
    case 'heal': [0, 4, 7, 12].forEach((n, i) => osc('triangle', mf(72 + n), t + i * .06, t + i * .06 + .2, envG(o, t + i * .06, .07, .003, .18))); break;
    case 'spare': [0, 7, 12, 16, 19].forEach((n, i) => INS.bell(o, t + i * .07, 79 + n, .3, .06)); break;
    case 'door': noise(o, t, .12, .2, 'lowpass', 500); osc('sine', 110, t, t + .1, envG(o, t, .12, .002, .08)); break;
    case 'bell': for (let i = 0; i < 14; i++) { osc('square', 1760, t + i * .07, t + i * .07 + .05, envG(o, t + i * .07, .045, .001, .05)); } break;
    case 'alarm': for (let i = 0; i < 4; i++) { osc('square', i % 2 ? 620 : 880, t + i * .22, t + i * .22 + .2, envG(o, t + i * .22, .07, .005, .19)); } break;
    case 'ship': { const g = envG(o, t, .2, .3, 2.6), s = AC.createOscillator(); s.type = 'sawtooth'; s.frequency.setValueAtTime(60, t); s.frequency.exponentialRampToValueAtTime(220, t + 2.4); const lp = AC.createBiquadFilter(); lp.frequency.value = 500; s.connect(lp); lp.connect(g); s.start(t); s.stop(t + 2.8); noise(o, t, 2.5, .1, 'lowpass', 700, 1, .4); break; }
    case 'hit': noise(o, t, .1, .25, 'bandpass', 900, 1); osc('square', 120, t, t + .1, envG(o, t, .1, .002, .09)); break;
    case 'boom': noise(o, t, 1.2, .35, 'lowpass', 400, 1, .005); osc('sine', 60, t, t + .8, envG(o, t, .3, .003, .7)); break;
    case 'save': [0, 4, 7, 11, 14].forEach((n, i) => INS.mbox(o, t + i * .08, 84 + n, .2, .06)); break;
    case 'step': noise(o, t, .03, .03, 'lowpass', 600); break;
    case 'zap': { const g = envG(o, t, .06, .002, .15), s = AC.createOscillator(); s.type = 'square'; s.frequency.setValueAtTime(1200, t); s.frequency.exponentialRampToValueAtTime(200, t + .14); s.connect(g); s.start(t); s.stop(t + .16); break; }
    case 'burp': { const g = envG(o, t, .12, .02, .45), s = AC.createOscillator(); s.type = 'sawtooth'; s.frequency.setValueAtTime(95, t); s.frequency.linearRampToValueAtTime(70, t + .4); const lp = AC.createBiquadFilter(); lp.frequency.value = 600; s.connect(lp); lp.connect(g); s.start(t); s.stop(t + .5); break; }
    case 'orb': DRUM.orb(o, t, .6); break;
    case 'beep': osc('sine', 1320, t, t + .1, envG(o, t, .06, .002, .09)); osc('sine', 1760, t + .12, t + .22, envG(o, t + .12, .06, .002, .09)); break;
  }
}
