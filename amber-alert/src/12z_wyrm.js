/* ================= ШЕПЧУЩИЙ ЗМЕЙ (THE WHISPERING WYRM, «Субъект неизвестен») ================= */
// Оповещение — шаблон «потеря сигнала» (unknownAlert). Обычный охотник (m.hunt): шёпот рядом, нарастающее шипение в погоне.
// Тело — змея ~4 м из сегментов, которые у КАЖДОГО клиента повторяют путь головы (по реплицированной позиции).
// Вблизи (10 м) — помехи на экране и дрожание HUD. Ночью игрок снаружи дома сразу «засвечен»: змей идёт прямо к нему.
const WYRM = {
  SEG: 16, SP: .25, H: 1.42, NECK: 1.3,
  rad(b) { return b < this.NECK ? .16 + .06 * (b / this.NECK) : Math.max(.05, .22 - .17 * ((b - this.NECK) / 2.45)); },
  hgt(b, r) { return b < this.NECK ? r + (this.H - .3 - r) * (1 - Math.sin(PI / 2 * b / this.NECK)) : r; },
  hd(b) { return b < this.NECK ? b * .55 : this.NECK * .55 + (b - this.NECK); },          // расстояние вдоль следа (по горизонтали)
  curve(h) { return [.42 * Math.sin(h * 1.9) * Math.min(1, h / 1.2), -h * .95]; },        // поза по умолчанию (лобби/скример)

  /* ---------- хост ---------- */
  // ночью игрок вне дома (комната 'out') — его позиция сразу известна змею
  outdoorTarget(m) {
    let best = null;
    for (const pl of GAME.alivePlayers()) { if (pl.hid || GAME.roomAt(new V3(pl.x, pl.y, pl.z))) continue; const d = m.p.distanceTo(new V3(pl.x, pl.y, pl.z)); if (!best || d < best.d) best = { pl, d }; }
    return best;
  },
  outNode(p) { const N = WORLD.nav; let best = null, bd = 1e9; for (const k in N) { const n = N[k]; if (n.room !== 'out') continue; const d = n.p.distanceTo(p); if (d < bd) { bd = d; best = k; } } return best; },
  // обход багов общей навигации (см. отчёт): тупиковые узлы окон wi_*
  unstick(m, dt, spd) {
    const N = WORLD.nav; if (!N || m.path.length) return false;
    const k = m.nodeNear(m.p), n = k && N[k]; if (!n || !n.win || n.room === 'out') return false;
    let best = null, bd = 1e9;
    for (const q in N) { const o = N[q]; if (o.win || !o.room || o.room === 'out' || Math.abs(o.p.y - m.p.y) > 1) continue; const d = o.p.distanceTo(m.p); if (d < bd) { bd = d; best = o; } }
    if (!best) return false; m.stepTo(best.p, dt, spd); return true;
  },

  glowTex() { return canvasTex('wyrmGlow', 64, 64, g => { const r = g.createRadialGradient(32, 32, 2, 32, 32, 32); r.addColorStop(0, 'rgba(255,255,255,1)'); r.addColorStop(.35, 'rgba(255,255,255,.55)'); r.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = r; g.fillRect(0, 0, 64, 64); }); },
  /* ---------- клиент: помехи на экране ---------- */
  mkOverlay(parent) {
    const wrap = document.createElement('div'); Object.assign(wrap.style, { position: 'absolute', inset: '0', pointerEvents: 'none', opacity: '0' });
    const cv = document.createElement('canvas'); cv.width = 160; cv.height = 90; Object.assign(cv.style, { width: '100%', height: '100%', imageRendering: 'pixelated', display: 'block' });
    wrap.append(cv); parent.prepend(wrap);
    return { wrap, g: cv.getContext('2d'), img: null, t: 0 };
  },
  drawStatic(o, k) {
    const g = o.g, W = 160, H = 90; if (!o.img) o.img = g.createImageData(W, H); const d = o.img.data;
    for (let i = 0; i < d.length; i += 4) { const v = Math.random() * 255; d[i] = d[i + 1] = d[i + 2] = v; d[i + 3] = v > 150 ? 200 : 90; }
    g.putImageData(o.img, 0, 0);
    const n = 1 + (k * 6 | 0); for (let j = 0; j < n; j++) { g.fillStyle = Math.random() < .5 ? 'rgba(255,32,32,.85)' : 'rgba(40,240,255,.6)'; g.fillRect(0, Math.random() * H, W, 1 + Math.random() * 3 * k); }
    if (Math.random() < k * .5) { g.fillStyle = 'rgba(0,0,0,.85)'; g.fillRect(0, Math.random() * H, W, 4 + Math.random() * 10); }
  },
  glitch(m, c, dt) {
    const vis = m.vis !== 0 && m.p.y > -50 && WORLD.level === 'house', hp = new V3(m.p.x, m.p.y + 1.4, m.p.z); c.ov = c.ov || [];
    UI.vps.forEach((v, i) => {
      const lp = v.lp; let o = c.ov[i];
      let k = vis && lp ? clamp(1 - lp.cam.position.distanceTo(hp) / 10, 0, 1) ** 1.4 : 0; if (k > 0 && m.a === 1) k = Math.min(1, k * 1.3 + .08);
      if (k <= 0) { if (o && o.on) { o.on = false; o.wrap.style.opacity = '0'; o.wrap.style.display = 'none'; v.el.style.transform = ''; } return; }
      if (!o || o.wrap.parentNode !== v.el) { if (o) o.wrap.remove(); o = c.ov[i] = this.mkOverlay(v.el); }
      if (!o.on) { o.on = true; o.wrap.style.display = 'block'; } o.el = v.el;
      o.t -= dt; if (o.t <= 0) { o.t = .05; this.drawStatic(o, k); }
      o.wrap.style.opacity = Math.min(.55, .04 + k * .36 + (Math.random() < k * .12 ? .22 : 0)).toFixed(2);
      v.el.style.transform = Math.random() < k * .22 ? `translate(${((Math.random() - .5) * 16 * k).toFixed(1)}px,${((Math.random() - .5) * 6 * k).toFixed(1)}px)` : '';
    });
  },
  /* ---------- клиент: звук (шёпот и шипение) ---------- */
  audio(m, c, dt) {
    const A = AU.ctx; if (!A) return;
    const vis = m.vis !== 0 && m.p.y > -50, x = m.p.x, y = m.p.y + 1.4, z = m.p.z;
    if (!c.au) {
      const pan = AU.at(new V3(x, y, z)), src = [];
      const mk = (type, fq, q) => { const s = A.createBufferSource(); s.buffer = AU.noise; s.loop = true; const f = A.createBiquadFilter(); f.type = type; f.frequency.value = fq; f.Q.value = q; const g = A.createGain(); g.gain.value = 0; s.connect(f); f.connect(g); g.connect(pan); s.start(A.currentTime, Math.random() * 1.5); src.push(s); return { s, f, g }; };
      c.au = { pan, src, w1: mk('bandpass', 2600, 3), w2: mk('bandpass', 1100, 1.4), h: mk('highpass', 2500, .7), next: 0, chase: null };
      const gr = A.createOscillator(), gl = A.createBiquadFilter(), gg = A.createGain(); gr.type = 'sawtooth'; gr.frequency.value = 46; gl.type = 'lowpass'; gl.frequency.value = 180; gg.gain.value = 0;
      gr.connect(gl); gl.connect(gg); gg.connect(pan); gr.start(); src.push(gr); c.au.growl = gg;
    }
    const au = c.au, t = A.currentTime, P = au.pan;
    if (P.positionX) { P.positionX.setTargetAtTime(x, t, .05); P.positionY.setTargetAtTime(y, t, .05); P.positionZ.setTargetAtTime(z, t, .05); } else P.setPosition(x, y, z);
    // шёпот: «слоги» шума с плавающей формантой и паузами между фразами
    if (t > au.next) {
      const pause = Math.random() < .09, dur = pause ? .6 + Math.random() * .9 : .07 + Math.random() * .2, on = vis && !pause && Math.random() < .8;
      au.next = t + dur;
      au.w1.g.gain.setTargetAtTime(on ? .05 + Math.random() * .07 : 0, t, .03); au.w1.f.frequency.setTargetAtTime(1800 + Math.random() * 2800, t, .05);
      au.w2.g.gain.setTargetAtTime(on && Math.random() < .5 ? .03 + Math.random() * .04 : 0, t, .04); au.w2.f.frequency.setTargetAtTime(600 + Math.random() * 900, t, .06);
    }
    // погоня: шипение нарастает и поднимается по высоте + низкий рык
    const ch = vis && m.a === 1;
    if (ch !== au.chase) {
      au.chase = ch; const g = au.h.g.gain, f = au.h.f.frequency; g.cancelScheduledValues(t); f.cancelScheduledValues(t);
      g.setTargetAtTime(ch ? .15 : 0, t, ch ? 1.1 : .25); f.setValueAtTime(ch ? 2200 : f.value, t); f.setTargetAtTime(ch ? 6500 : 2500, t, ch ? 1.6 : .3);
      au.growl.gain.setTargetAtTime(ch ? .06 : 0, t, ch ? .6 : .2);
    }
  },
  stopAudio(c) {
    const au = c && c.au; if (!au) return; c.au = null;
    for (const s of au.src) try { s.stop(); } catch (_) { }
    for (const n of [au.w1.g, au.w2.g, au.h.g, au.growl, au.pan]) try { n.disconnect(); } catch (_) { }
  },
};

INMATES.def({
  key: 'wyrm', num: '???', name: 'ШЕПЧУЩИЙ ЗМЕЙ', en: 'THE WHISPERING WYRM', cls: 'НЕИЗВЕСТЕН', hp: 600, speed: 2.8, chase: 5.2, color: '#ff2020',
  difficulty: 1, minNight: 1, unknownAlert: true, eye: 1.45, darkSight: 5, directive: 'STAY_INDOORS', ns: WYRM,
  alert: ['СВЯЗЬ ПРЕРЫВАЕТСЯ. ПЕРЕХВАЧЕННЫЕ ОБРЫВКИ ОПИСЫВАЮТ ДЛИННОЕ ЗМЕЕПОДОБНОЕ ТЕЛО, ЗАНАВЕС ДЛИННЫХ ЧЁРНЫХ ВОЛОС, ЛИЦО БЕЗ ВЕК И КРАСНОЕ СВЕЧЕНИЕ ВОКРУГ ГОЛОВЫ.',
    'ВБЛИЗИ СУБЪЕКТА ОТКАЗЫВАЕТ ЭЛЕКТРОНИКА И СЛЫШЕН НЕПРЕРЫВНЫЙ ШЁПОТ. ЛЮБОЙ, КТО НАХОДИТСЯ СНАРУЖИ, БУДЕТ ОБНАРУЖЕН.',
    'ГРАЖДАНАМ РЕКОМЕНДУЕТСЯ ОСТАВАТЬСЯ В ПОМЕЩЕНИИ.'],
  tip: 'Ночью не выходи из дома — снаружи оно сразу знает, где ты. Шёпот и помехи — оно рядом: прячься в шкаф или петляй. Дробовик работает.',
  model() {
    const g = new THREE.Group(), P = { g, segs: [], hair: [] }; g.userData.wyrm = P;
    const head = new THREE.Group(); head.position.set(0, WYRM.H, 0); g.add(head); P.head = head;
    // гладкое бледное лицо без век и ушей
    MM.sph(head, .2, '#d8d1ca', 0, 0, .02, { sy: 1.3, sz: .95, seg: 14, seg2: 12 });
    const black = mat('#000000', { basic: true });
    for (const s of [-1, 1]) {
      MM.sph(head, .064, '#7a0c0c', s * .078, .07, .15, { seg: 10, seg2: 8 });
      MM.sph(head, .054, '#f6f2ea', s * .078, .07, .162, { seg: 10, seg2: 8 });
      MM.sph(head, .013, '', s * .078, .066, .214, { seg: 6, seg2: 4, mat: black });
    }
    MM.box(head, .17, .08, .12, '#3a0606', 0, -.15, .1);              // пасть
    MM.box(head, .15, .03, .02, '#efe8d8', 0, -.125, .178);           // верхние зубы
    P.jaw = new THREE.Group(); P.jaw.position.set(0, -.15, .02); head.add(P.jaw);
    MM.box(P.jaw, .19, .05, .18, '#cfc8c2', 0, -.035, .075); MM.box(P.jaw, .14, .03, .02, '#efe8d8', 0, .0, .158);
    // занавес длинных чёрных волос (лицо видно в проборе)
    MM.sph(head, .215, '#0b0a0c', 0, .08, -.045, { sy: 1.15, seg: 12, seg2: 10 });
    const hair = mat('#0a090b'), angs = []; for (const s of [-1, 1]) for (let k = 0; k < 6; k++) angs.push(s * (.75 + k * .42)); angs.push(PI);
    angs.forEach((a, i) => {
      const L = 1.15 + ((i * 37) % 5) * .05, pv = new THREE.Group(); pv.position.set(Math.sin(a) * .2, .2, Math.cos(a) * .2 - .03); pv.rotation.y = a; head.add(pv);
      const st = new THREE.Mesh(new THREE.BoxGeometry(.085, L, .025), hair); st.position.y = -L / 2; pv.add(st); P.hair.push(pv);
    });
    // красное свечение вокруг головы
    const halo = new THREE.Sprite(new THREE.SpriteMaterial({ map: WYRM.glowTex(), color: '#ff2020', transparent: true, opacity: .8, blending: THREE.AdditiveBlending, depthWrite: false, fog: false }));
    halo.scale.set(1.5, 1.5, 1); halo.position.set(0, .02, -.22); head.add(halo); P.halo = halo;
    // тело: сегменты (в позе по умолчанию — изгиб назад)
    const cols = [mat('#463c42'), mat('#362f34')];
    for (let i = 0; i < WYRM.SEG; i++) {
      const b = i * WYRM.SP, r = WYRM.rad(b), [x, z] = WYRM.curve(WYRM.hd(b));
      const s = new THREE.Mesh(new THREE.SphereGeometry(r, 12, 9), cols[i % 2]); s.position.set(x, WYRM.hgt(b, r), z); s.scale.set(1, .9, 1); g.add(s); P.segs.push(s);
    }
    return g;
  },
  init(m) { m.cl = {}; const c = m.cl; c.lamp = { pos: new V3(0, -100, 0), on: () => !m.gone && m.vis !== 0 && m.p.y > -50, color: '#ff2020', power: 2.6, range: 4.5, flicker: true, room: 'wyrm' }; WORLD.lamps.push(c.lamp); },
  cleanup(m) {
    const c = m.cl || {}; WYRM.stopAudio(c);
    if (c.lamp) { const i = WORLD.lamps.indexOf(c.lamp); if (i >= 0) WORLD.lamps.splice(i, 1); }
    for (const o of c.ov || []) if (o) { o.wrap.remove(); if (o.el) o.el.style.transform = ''; }
    for (const v of UI.vps) v.el.style.transform = '';
  },
  tick(m, dt) { const y0 = m.p.y; m.T.think(m, dt); if (y0 - m.p.y > 1.2) m.p.y = y0; },   // откат «провала» в щель у лестницы (см. отчёт)
  think(m, dt) {
    const T = m.T; m.speedNow = 0;
    const out = m.stun <= 0 && GAME.st.phase === 'night' ? WYRM.outdoorTarget(m) : null;
    if (out) {                                     // игрок снаружи — позиция «передаётся» змею
      const pl = out.pl, tp = new V3(pl.x, pl.y, pl.z);
      m.state = 'chase'; m.chaseId = pl.id; m.lastSeen = tp.clone(); m.lostT = 0; m.a = 1;
      const key = 'rv_' + pl.id; if (!(m.mem[key] > m.t)) { m.mem[key] = m.t + 25; GAME.toastTo(pl.id, '📡 …шшш… оно знает, где ты. Вернись в дом!'); }
      const h = m.headPos(), ph = new V3(pl.x, pl.y + 1.2, pl.z);
      const outside = !GAME.roomAt(m.p);
      if (outside && Math.abs(pl.y - m.p.y) < 1.2 && h.distanceTo(ph) < 16 && WORLD.coll.los(h, ph)) { m.path = []; m.stepTo(tp, dt, T.chase); }
      else { const goal = WYRM.outNode(tp); if (!m.path.length || m.goal !== goal) m.goNode(goal); if (m.follow(dt, T.chase) && outside) m.stepTo(tp, dt, T.chase); }
      m.tryKill(1.15); return;
    }
    if ((m.state === 'roam' || m.state === 'investigate') && WYRM.unstick(m, dt, T.speed)) { m.a = 0; m.tryKill(1.15); return; }
    m.hunt(dt, { sight: 20, reach: 1.15 });
  },
  anim(m, dt, moving) {
    const P = m.model.userData.wyrm, c = m.cl || (m.cl = {}), M = m.model, t = m.t, chase = m.a === 1;
    c.moving = moving;
    // голова: покачивание (змеиный ход), рывок вперёд и раскрытая пасть в погоне
    c.sw = damp(c.sw || 0, moving ? (chase ? .17 : .12) : .03, 4, dt); c.ph = (c.ph || 0) + dt * (moving ? (chase ? 7 : 4) : 1.2);
    const sway = Math.sin(c.ph) * c.sw;
    P.head.position.set(sway, WYRM.H + Math.sin(c.ph * 2) * .02 - (chase ? .08 : 0), chase ? .12 : 0);
    P.head.rotation.set(chase ? .15 : (m.a === 2 ? .5 : Math.sin(t * .7) * .06), -sway * .8, Math.sin(t * .5) * .08);
    c.jaw = damp(c.jaw || 0, chase ? .85 : m.a === 2 ? .35 : .05, 8, dt); P.jaw.rotation.x = c.jaw;
    P.hair.forEach((h, i) => { h.rotation.x = (moving ? (chase ? .35 : .18) : .02) + Math.sin(t * 2.2 + i * 1.3) * .05; h.rotation.z = Math.sin(t * 1.7 + i) * .04; });
    P.halo.material.opacity = (chase ? .95 : .7) + Math.sin(t * 5) * .1;
    // след головы в мировых координатах → сегменты тела
    const yaw = M.rotation.y, cs = Math.cos(yaw), sn = Math.sin(yaw), hx = m.p.x + sway * cs, hz = m.p.z - sway * sn, hy = m.p.y;
    let tr = c.trail;
    if (!tr || Math.hypot(hx - tr[0].x, hz - tr[0].z) > 3 || Math.abs(hy - tr[0].y) > 2.5) {
      tr = c.trail = [];
      for (let h = 0; h <= 3.5; h += .2) { const [lx, lz] = WYRM.curve(h); tr.push({ x: m.p.x + lx * cs + lz * sn, y: hy, z: m.p.z - lx * sn + lz * cs }); }
    }
    if (Math.hypot(hx - tr[0].x, hz - tr[0].z) > .1) { tr.unshift({ x: hx, y: hy, z: hz }); let L = 0; for (let i = 1; i < tr.length; i++) { L += Math.hypot(tr[i].x - tr[i - 1].x, tr[i].z - tr[i - 1].z); if (L > 3.8) { tr.length = i + 1; break; } } }
    let j = -1, ax = hx, ay = hy, az = hz, acc = 0;            // курсор по ломаной: [голова, tr[0], tr[1], ...]
    for (let i = 0; i < P.segs.length; i++) {
      const b = i * WYRM.SP, want = WYRM.hd(b); let px = ax, py = ay, pz = az;
      while (true) {
        const nx = tr[j + 1]; if (!nx) { px = ax; py = ay; pz = az; break; }
        const sl = Math.hypot(nx.x - ax, nx.z - az);
        if (acc + sl >= want) { const k = sl > 1e-6 ? (want - acc) / sl : 0; px = ax + (nx.x - ax) * k; py = ay + (nx.y - ay) * k; pz = az + (nx.z - az) * k; break; }
        acc += sl; ax = nx.x; ay = nx.y; az = nx.z; j++;
      }
      const r = WYRM.rad(b), dx = px - m.p.x, dz = pz - m.p.z;
      const wob = b > WYRM.NECK ? Math.sin(t * 2.4 - b * 2.2) * .015 : 0;
      P.segs[i].position.set(dx * cs - dz * sn, py - m.p.y + WYRM.hgt(b, r) + wob, dx * sn + dz * cs);
    }
    if (c.lamp) c.lamp.pos.set(hx, hy + WYRM.H, hz);
  },
  sound(m, dt) { const c = m.cl; if (!c) return; WYRM.glitch(m, c, dt); WYRM.audio(m, c, dt); },
});
