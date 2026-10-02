/* ================= ЗВУК: синтез в Web Audio, 3D-позиционирование, голос диктора ================= */
const AU = {
  ctx: null, master: null, music: null, sfx: null, rev: null, noise: null, amb: null, musicNode: null, listener: null,
  init() {
    if (this.ctx) { if (this.ctx.state !== 'running') this.ctx.resume(); return; }
    const C = window.AudioContext || window.webkitAudioContext; if (!C) return;
    const c = this.ctx = new C();
    const comp = c.createDynamicsCompressor(); comp.threshold.value = -12; comp.ratio.value = 4; comp.connect(c.destination);
    this.master = c.createGain(); this.master.gain.value = SETTINGS.volume; this.master.connect(comp);
    this.music = c.createGain(); this.music.gain.value = .45; this.music.connect(this.master);
    this.sfx = c.createGain(); this.sfx.gain.value = 1; this.sfx.connect(this.master);
    this.rev = c.createConvolver(); const len = c.sampleRate * 2.2, ir = c.createBuffer(2, len, c.sampleRate);
    for (let ch = 0; ch < 2; ch++) { const d = ir.getChannelData(ch); for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / len) ** 3; }
    this.rev.buffer = ir; const rg = c.createGain(); rg.gain.value = .25; this.rev.connect(rg); rg.connect(this.master);
    this.noise = c.createBuffer(1, c.sampleRate * 2, c.sampleRate); const nd = this.noise.getChannelData(0); for (let i = 0; i < nd.length; i++) nd[i] = Math.random() * 2 - 1;
    this.listener = c.listener;
  },
  t() { return this.ctx ? this.ctx.currentTime : 0; },
  setVol(v) { SETTINGS.volume = v; if (this.master) this.master.gain.setTargetAtTime(v, this.t(), .05); },
  // огибающая
  env(dest, t, v, a, d, sus = 0, rel = .05) { const g = this.ctx.createGain(); g.gain.setValueAtTime(.0001, t); g.gain.linearRampToValueAtTime(v, t + a); if (sus) { g.gain.setValueAtTime(v, t + d); g.gain.linearRampToValueAtTime(.0001, t + d + rel); } else g.gain.exponentialRampToValueAtTime(.0001, t + a + d); g.connect(dest); return g; },
  osc(type, f, t, end, dest) { const o = this.ctx.createOscillator(); o.type = type; o.frequency.value = f; o.connect(dest); o.start(t); o.stop(end); return o; },
  nz(dest, t, d, v, type = 'lowpass', fq = 1000, q = 1, a = .005) { const s = this.ctx.createBufferSource(), f = this.ctx.createBiquadFilter(), g = this.env(dest, t, v, a, d); s.buffer = this.noise; s.loop = true; f.type = type; f.frequency.value = fq; f.Q.value = q; s.connect(f); f.connect(g); s.start(t, Math.random()); s.stop(t + a + d + .1); return { s, f, g }; },
  // точка в пространстве для звука
  at(pos, out = this.sfx) {
    if (!pos) return out; const p = this.ctx.createPanner(); p.panningModel = 'HRTF'; p.distanceModel = 'inverse'; p.refDistance = 2; p.rolloffFactor = 1.4; p.maxDistance = 60;
    if (p.positionX) { p.positionX.value = pos.x; p.positionY.value = pos.y; p.positionZ.value = pos.z; } else p.setPosition(pos.x, pos.y, pos.z);
    p.connect(out); return p;
  },
  setListener(cam) {
    if (!this.ctx) return; const l = this.listener, p = cam.position, f = new V3(0, 0, -1).applyQuaternion(cam.quaternion), u = new V3(0, 1, 0).applyQuaternion(cam.quaternion), t = this.t();
    if (l.positionX) { l.positionX.setTargetAtTime(p.x, t, .02); l.positionY.setTargetAtTime(p.y, t, .02); l.positionZ.setTargetAtTime(p.z, t, .02); l.forwardX.setTargetAtTime(f.x, t, .02); l.forwardY.setTargetAtTime(f.y, t, .02); l.forwardZ.setTargetAtTime(f.z, t, .02); l.upX.value = u.x; l.upY.value = u.y; l.upZ.value = u.z; }
    else { l.setPosition(p.x, p.y, p.z); l.setOrientation(f.x, f.y, f.z, u.x, u.y, u.z); }
  },
  play(k, pos, o = {}) {
    if (!this.ctx) return; const c = this.ctx, t = this.t(), out = this.at(pos);
    switch (k) {
      case 'click': this.osc('square', 1800, t, t + .02, this.env(out, t, .08, .001, .015)); this.nz(out, t, .02, .1, 'highpass', 3000); break;
      case 'switch': this.osc('square', 900, t, t + .03, this.env(out, t, .12, .001, .02)); this.nz(out, t, .03, .2, 'bandpass', 2500, 2); break;
      case 'doorOpen': { const n = this.nz(out, t, .45, .18, 'bandpass', 500, 4, .05); n.f.frequency.linearRampToValueAtTime(900, t + .4); this.osc('sawtooth', 210, t, t + .4, this.env(out, t, .02, .1, .3)).frequency.linearRampToValueAtTime(260, t + .35); break; }
      case 'doorClose': this.nz(out, t, .25, .5, 'lowpass', 400); this.osc('sine', 70, t, t + .2, this.env(out, t, .4, .002, .18)); break;
      case 'lock': this.osc('square', 1200, t, t + .03, this.env(out, t, .1, .001, .02)); this.osc('square', 700, t + .07, t + .1, this.env(out, t + .07, .12, .001, .03)); this.nz(out, t, .1, .15, 'highpass', 2000); break;
      case 'locked': this.nz(out, t, .08, .35, 'bandpass', 900, 3); this.nz(out, t + .12, .08, .35, 'bandpass', 900, 3); break;
      case 'knock': for (let i = 0; i < (o.n || 3); i++) { const tt = t + i * .22; this.nz(out, tt, .09, .9, 'lowpass', 300, 1, .002); this.osc('sine', 90, tt, tt + .1, this.env(out, tt, .6, .002, .08)); } break;
      case 'bang': this.nz(out, t, .3, 1, 'lowpass', 250, 1, .002); this.osc('sine', 55, t, t + .3, this.env(out, t, .9, .002, .25)); break;
      case 'glass': for (let i = 0; i < 9; i++) { const tt = t + Math.random() * .3; this.osc('sine', 2500 + Math.random() * 3500, tt, tt + .15, this.env(out, tt, .06, .001, .12)); } this.nz(out, t, .4, .5, 'highpass', 2500); break;
      case 'curtain': this.nz(out, t, .35, .12, 'bandpass', 3500, .6, .08); break;
      case 'step': this.nz(out, t, .06, o.v || .08, 'lowpass', 500 + Math.random() * 300, 1, .004); break;
      case 'stepHeavy': this.nz(out, t, .12, o.v || .5, 'lowpass', 220, 1, .004); this.osc('sine', 60, t, t + .1, this.env(out, t, .3, .002, .09)); break;
      case 'breath': { const n = this.nz(out, t, 1.1, .12, 'bandpass', 700, 1.2, .4); n.f.frequency.linearRampToValueAtTime(400, t + 1.2); break; }
      case 'scream': { const o1 = this.osc('sawtooth', 600, t, t + 1.1, this.env(out, t, .35, .02, 1)); o1.frequency.linearRampToValueAtTime(1300, t + .3); o1.frequency.linearRampToValueAtTime(500, t + 1); this.nz(out, t, 1, .6, 'bandpass', 1800, .8, .01); this.osc('square', 45, t, t + .8, this.env(out, t, .5, .005, .7)); break; }
      case 'sting': this.osc('sawtooth', 110, t, t + 1.4, this.env(out, t, .25, .005, 1.3)).detune.value = 25; this.osc('sawtooth', 116, t, t + 1.4, this.env(out, t, .25, .005, 1.3)); this.nz(out, t, .9, .5, 'highpass', 4000, 1, .002); break;
      case 'heart': for (const d of [0, .18]) { this.osc('sine', 52, t + d, t + d + .15, this.env(out, t + d, .7, .004, .12)); } break;
      case 'static': this.nz(out, t, o.d || .5, o.v || .25, 'highpass', 1200, .5, .01); break;
      case 'ring': for (let i = 0; i < 2; i++) { const tt = t + i * .45; for (const f of [440, 480]) this.osc('sine', f, tt, tt + .38, this.env(out, tt, .12, .01, .36, 1, .02)); } break;
      case 'ui': this.osc('sine', 880, t, t + .07, this.env(out, t, .08, .002, .06)); break;
      case 'ui2': this.osc('sine', 660, t, t + .06, this.env(out, t, .08, .002, .05)); this.osc('sine', 990, t + .06, t + .14, this.env(out, t + .06, .08, .002, .06)); break;
      case 'coin': [0, 7, 12].forEach((n, i) => this.osc('square', 880 * 2 ** (n / 12), t + i * .06, t + i * .06 + .1, this.env(out, t + i * .06, .05, .002, .08))); break;
      case 'clock': this.osc('square', 2600, t, t + .015, this.env(out, t, .04, .001, .01)); break;
      case 'chime': [0, 4, 7, 12].forEach((n, i) => this.osc('triangle', 523 * 2 ** (n / 12), t + i * .18, t + i * .18 + 1.4, this.env(out, t + i * .18, .09, .004, 1.3))); break;
      case 'rooster': { const o1 = this.osc('sawtooth', 700, t, t + 1, this.env(out, t, .1, .02, .9)); o1.frequency.setValueAtTime(700, t); o1.frequency.linearRampToValueAtTime(1100, t + .2); o1.frequency.setValueAtTime(900, t + .4); o1.frequency.linearRampToValueAtTime(600, t + .9); break; }
      case 'scratch': for (let i = 0; i < 4; i++) this.nz(out, t + i * .16, .12, .3, 'bandpass', 3000 + Math.random() * 1500, 4, .01); break;
      case 'whisper': this.nz(out, t, 1.4, .15, 'bandpass', 2400, 3, .3); break;
      case 'buzz': this.osc('sawtooth', 60, t, t + (o.d || .5), this.env(out, t, .06, .01, o.d || .5)); break;
    }
  },
  // сигнал экстренного оповещения: «посылки» данных (AFSK) + двутональный сигнал 853+960 Гц
  eas(onDone) {
    if (!this.ctx) { onDone && setTimeout(onDone, 500); return; }
    const t0 = this.t() + .05, out = this.sfx, baud = 1 / 520.83;
    const burst = t => { const o = this.ctx.createOscillator(); o.type = 'square'; const g = this.env(out, t, .07, .005, .95, 1, .02); o.connect(g); for (let i = 0; i < 480; i++) o.frequency.setValueAtTime(Math.random() < .5 ? 2083.3 : 1562.5, t + i * baud * 1.9); o.start(t); o.stop(t + 1); };
    for (let i = 0; i < 3; i++) burst(t0 + i * 1.1);
    const tt = t0 + 3.6; for (const f of [853, 960]) this.osc('sine', f, tt, tt + 4, this.env(out, tt, .16, .01, 4, 1, .05));
    onDone && setTimeout(onDone, 8200);
  },
  // «посылки» конца сообщения
  eom() { if (!this.ctx) return; const t0 = this.t() + .05, baud = 1 / 520.83; for (let k = 0; k < 3; k++) { const t = t0 + k * .7, o = this.ctx.createOscillator(); o.type = 'square'; o.connect(this.env(this.sfx, t, .06, .005, .5, 1, .02)); for (let i = 0; i < 260; i++) o.frequency.setValueAtTime(Math.random() < .5 ? 2083.3 : 1562.5, t + i * baud * 1.9); o.start(t); o.stop(t + .55); } },
  // голос диктора через синтез речи браузера (если есть)
  speak(text, o = {}) {
    if (!window.speechSynthesis || SETTINGS.tts === false) return;
    try {
      const u = new SpeechSynthesisUtterance(text); const vs = speechSynthesis.getVoices(); const v = vs.find(v => /ru/i.test(v.lang) && /male|муж|pavel|dmitri|yuri/i.test(v.name)) || vs.find(v => /ru/i.test(v.lang));
      if (v) u.voice = v; u.lang = 'ru-RU'; u.rate = o.rate || .92; u.pitch = o.pitch ?? .55; u.volume = SETTINGS.volume;
      speechSynthesis.speak(u);
    } catch (_) { }
  },
  hush() { try { window.speechSynthesis && speechSynthesis.cancel(); } catch (_) { } },
  // фоновые слои
  ambient(kind) {
    if (!this.ctx) { this.pendingAmb = kind; return; }
    if (this.ambKind === kind) return; this.ambKind = kind;
    const c = this.ctx, t = this.t();
    if (this.amb) { const old = this.amb; old.g.gain.setTargetAtTime(.0001, t, .6); setTimeout(() => { try { old.stop(); } catch (_) { } }, 3000); }
    this.amb = null; if (!kind) return;
    const g = c.createGain(); g.gain.value = .0001; g.gain.setTargetAtTime(1, t, 1); g.connect(this.music); const nodes = [];
    const lfoNoise = (fq, v, q = .7) => { const s = c.createBufferSource(); s.buffer = this.noise; s.loop = true; const f = c.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = fq; f.Q.value = q; const gg = c.createGain(); gg.gain.value = v; const l = c.createOscillator(); l.frequency.value = .07 + Math.random() * .08; const lg = c.createGain(); lg.gain.value = fq * .4; l.connect(lg); lg.connect(f.frequency); s.connect(f); f.connect(gg); gg.connect(g); s.start(); l.start(); nodes.push(s, l); };
    const drone = (f, v, type = 'sine') => { const o = c.createOscillator(); o.type = type; o.frequency.value = f; const gg = c.createGain(); gg.gain.value = v; const lp = c.createBiquadFilter(); lp.frequency.value = 500; o.connect(lp); lp.connect(gg); gg.connect(g); o.start(); nodes.push(o); };
    if (kind === 'lobby') { lfoNoise(420, .05); drone(55, .05); drone(82.4, .03, 'triangle'); this.lobbyMusic(g, nodes); }
    else if (kind === 'night') { lfoNoise(300, .09); lfoNoise(1200, .02, 2); drone(41, .07); drone(61.7, .025, 'sawtooth'); }
    else if (kind === 'tense') { lfoNoise(500, .07); drone(46.2, .1, 'sawtooth'); drone(49, .06, 'sawtooth'); drone(98, .02, 'square'); }
    else if (kind === 'dawn') { lfoNoise(2000, .015, 1); drone(130.8, .03, 'triangle'); drone(196, .02, 'triangle'); }
    this.amb = { g, stop: () => nodes.forEach(n => { try { n.stop(); } catch (_) { } }) };
  },
  // спокойная тревожная мелодия лобби (музыкальная шкатулка + пэд)
  lobbyMusic(dest, nodes) {
    const c = this.ctx, seq = [69, 72, 76, 74, 72, 71, 69, 64, 65, 69, 72, 71, 69, 68, 69, 0], dur = .55; let i = 0;
    const tick = () => { if (this.ambKind !== 'lobby') return; const t = this.t() + .05, n = seq[i++ % seq.length];
      if (n) { const f = 440 * 2 ** ((n - 69) / 12); this.osc('sine', f, t, t + 1.6, this.env(dest, t, .05, .003, 1.5)); this.osc('sine', f * 3, t, t + .5, this.env(dest, t, .012, .002, .4)); }
      if (i % 8 === 1) for (const m of [45, 52, 57]) this.osc('triangle', 440 * 2 ** ((m - 69) / 12), t, t + 4.2, this.env(dest, t, .025, 1.2, 3));
      setTimeout(tick, dur * 1000); };
    tick();
  },
};
