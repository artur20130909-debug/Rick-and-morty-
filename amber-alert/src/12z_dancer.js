/* ================= ТАНЦОВЩИЦА (THE DANCER, «Кружащаяся»), заключённая 214 ================= */
// Входит в дом, идёт к телевизору (позже — и к старому радио на кухне) и включает его: играет жестяной вальс
// музыкальной шкатулки. Каждый играющий источник даёт +25% к скорости (погоня — не быстрее 6.2 м/с).
// Охотится на освещённые комнаты и шум, в темноте видит недалеко. Хрупкая: 2 выстрела вблизи.
// Контр: выключить ТВ/радио (или щиток), погасить свет, прятаться подальше от музыки.
// Общее состояние: WS.TV.on (телевизор дома), WS.DANCER_RADIO.on (радио — интерактив создаётся в init у всех).
const DANCER = {
  RADIO: 'DANCER_RADIO', n: 0, radio: null,
  // где встать и куда тянуться, чтобы включить источник
  spots: {
    TV: { node: 'liv2', stand: new V3(6.42, 0, 2.55), dev: new V3(7.0, 1.0, 2.6) },
    DANCER_RADIO: { node: 'kit2', stand: new V3(6.72, 0, -4.6), dev: new V3(7.32, 1.12, -4.6) },
  },
  on(id) { return !!(WS[id] && WS[id].on); },
  ids() { return WS[this.RADIO] ? ['TV', this.RADIO] : ['TV']; },
  playing() { if (!GAME.power()) return 0; let n = 0; for (const id of this.ids()) if (this.on(id)) n++; return n; },

  /* ---------- радио на кухне (интерактив у всех клиентов) ---------- */
  makeRadio() {
    const id = this.RADIO, g = new THREE.Group(); g.position.set(7.5, .95, -4.6); g.rotation.y = -PI / 2; WORLD.add(g);
    const box = (w, h, d, c, x, y, z, m) => { const b = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m || mat(c)); b.position.set(x, y, z); g.add(b); return b; };
    const body = box(.58, .34, .34, '#5a3820', 0, .17, 0);
    const grille = box(.3, .24, .02, '#d8c8a0', -.1, .17, .176);
    const dial = box(.17, .09, .02, '', .16, .22, .176, new THREE.MeshBasicMaterial({ color: '#2a2418' }));
    for (const kx of [.1, .21]) { const k = new THREE.Mesh(new THREE.CylinderGeometry(.03, .03, .03, 10), mat('#c8b070')); k.rotation.x = PI / 2; k.position.set(kx, .1, .182); g.add(k); }
    const ant = new THREE.Mesh(new THREE.CylinderGeometry(.006, .006, .55, 4), mat('#bbbbbb')); ant.position.set(.22, .55, -.08); ant.rotation.z = -.45; g.add(ant);
    const def = interactable({ id, mesh: [body, grille, dial], pos: this.spots[id].dev.clone(), range: 2.6, init: WS[id] ? undefined : { on: 0 },
      label: () => this.on(id) ? 'Выключить радио' : 'Включить радио',
      use: () => { wsSet(id, { on: this.on(id) ? 0 : 1 }); GAME.sfxAt('click', this.spots[id].dev); },
      apply: s => dial.material.color.set(s && s.on ? '#ffb24a' : '#2a2418') });
    if (WS[id]) def.apply(WS[id]);
    this.radio = { g, def };
  },
  removeRadio() {
    const r = this.radio; if (!r) return; this.radio = null;
    if (r.g.parent) r.g.parent.remove(r.g);
    if (WORLD.inter.get(this.RADIO) === r.def) WORLD.inter.delete(this.RADIO);
    r.g.traverse(o => { if (o.isMesh) o.geometry.dispose(); });
    delete WS[this.RADIO];
  },

  /* ---------- хост: ИИ ---------- */
  // Обход двух багов общей навигации (подробно — в отчёте интегратору):
  // 1) узлы окон wi_* связаны сами с собой, из них нет маршрута — дойти до ближайшего узла комнаты напрямую;
  // 2) щель между верхней ступенькой и полом 2 этажа: fixY роняет на 1 этаж — такой «провал» откатываем.
  unstick(m, dt, spd) {
    const N = WORLD.nav; if (!N || m.path.length) return false;
    const k = m.nodeNear(m.p), n = k && N[k]; if (!n || !n.win || n.room === 'out') return false;
    let best = null, bd = 1e9;
    for (const q in N) { const o = N[q]; if (o.win || !o.room || o.room === 'out' || Math.abs(o.p.y - m.p.y) > 1) continue; const d = o.p.distanceTo(m.p); if (d < bd) { bd = d; best = o; } }
    if (!best) return false; m.stepTo(best.p, dt, spd); return true;
  },
  spot(m, maxD) { let best = null; for (const pl of GAME.alivePlayers()) if (m.canSee(pl, maxD)) { const d = m.p.distanceTo(new V3(pl.x, pl.y, pl.z)); if (!best || d < best.d) best = { pl, d }; } return best; },
  chase(m, s) { m.state = 'chase'; m.chaseId = s.pl.id; m.lastSeen = new V3(s.pl.x, s.pl.y, s.pl.z); m.lostT = 0; m.path = []; },
  // какой источник включить: тот, что только что выключили, иначе ближайший
  offSource(m) {
    if (!GAME.power()) return null; const last = m.mem.lastOff; if (last && WS[last] && !this.on(last)) return last;
    let best = null, bd = 1e9;
    for (const id of this.ids()) { if (this.on(id)) continue; const d = this.spots[id].stand.distanceTo(m.p) + Math.abs(m.p.y) * 3; if (d < bd) { bd = d; best = id; } }
    return best;
  },
  startTune(m, id) { const mem = m.mem; m.state = 'tune'; mem.tuneId = id; mem.tunePh = 'go'; mem.tuneT = 0; mem.tuneAge = 0; m.goNode(this.spots[id].node); },
  tune(m, dt, spd) {
    const mem = m.mem, id = mem.tuneId, S = this.spots[id]; mem.tuneAge += dt;
    if (!S || mem.tuneAge > 35 || (mem.tunePh === 'go' && this.on(id))) { m.state = 'roam'; m.path = []; mem.nextTune = m.t + 10; return; }
    if (mem.tunePh === 'go') {
      m.a = 0;
      if (m.path.length) m.follow(dt, spd * 1.1);
      else if (S.stand.distanceTo(m.p) > 2.5 && (this.unstick(m, dt, spd) || (m.goNode(S.node), m.path.length))) { }
      else if (m.stepTo(S.stand, dt, spd)) { mem.tunePh = 'flip'; mem.tuneT = 0; m.yaw = Math.atan2(S.dev.x - m.p.x, S.dev.z - m.p.z); }
    } else if (mem.tunePh === 'flip') {          // тянется к переключателю
      m.a = 4; m.speedNow = 0; mem.tuneT += dt;
      if (mem.tuneT > .9) {
        wsSet(id, { on: 1 }); mem['on_' + id] = 1; if (mem.lastOff === id) mem.lastOff = null; GAME.fxAll('click', S.dev); GAME.fxAll('static', S.dev, { d: .35, v: .2 });
        if (!mem.said) { mem.said = 1; GAME.fxAll('say', S.dev, { text: 'Потанцуем?..', voice: 'dancer' }); }
        mem.tunePh = 'spin'; mem.tuneT = 0;
      }
    } else {                                      // пируэт от радости
      m.a = 3; m.speedNow = 0; mem.tuneT += dt;
      if (mem.tuneT > 1.8) { m.state = 'roam'; m.path = []; mem.nextTune = m.t + 22 + Math.random() * 10; }
    }
  },
  // комната для обхода: освещённые — в приоритете, рядом с музыкой — тоже
  pickRoom(m) {
    const cur = GAME.roomAt(m.p), pw = GAME.power(), cands = []; let tot = 0;
    for (const k in WORLD.nav) {
      const nd = WORLD.nav[k]; if (!nd.room || nd.win || nd.room === 'out' || nd.room === cur) continue;
      let w = 1; if (pw && WS['L_' + nd.room] && WS['L_' + nd.room].on) w += 4;
      if (pw && ((nd.room === 'living' && this.on('TV')) || (nd.room === 'kitchen' && this.on(this.RADIO)))) w += 2;
      cands.push([k, w]); tot += w;
    }
    let r = Math.random() * tot; for (const [k, w] of cands) if ((r -= w) <= 0) return k;
    return cands.length ? cands[0][0] : null;
  },

  /* ---------- клиент: музыка (вальс музыкальной шкатулки из ТВ/радио) ---------- */
  mus: { ch: {}, nextT: 0, step: 0 },
  musUpdate() {
    const A = AU.ctx; if (!A) return; const M = this.mus, t = A.currentTime, pw = GAME.power() && WORLD.level === 'house';
    const want = [];
    if (pw && HOUSE.tv && this.on('TV')) want.push(['TV', HOUSE.tv.pos]);
    if (pw && this.radio && this.on(this.RADIO)) want.push([this.RADIO, this.spots[this.RADIO].dev]);
    for (const id in M.ch) if (!want.some(w => w[0] === id)) this.musDrop(id);
    if (!want.length) { M.nextT = 0; return; }
    for (const [id, pos] of want) if (!M.ch[id]) {
      const g = A.createGain(), hp = A.createBiquadFilter(), lp = A.createBiquadFilter(), pan = AU.at(pos);
      hp.type = 'highpass'; hp.frequency.value = 260; lp.type = 'lowpass'; lp.frequency.value = 3400; g.gain.value = 1;
      g.connect(hp); hp.connect(lp); lp.connect(pan); M.ch[id] = { g, hp, lp, pan };
    }
    const fast = INM.some(q => q.type === 'dancer' && q.a === 1), beat = fast ? .3 : .42;
    if (!M.nextT || M.nextT < t - .3) { M.nextT = t + .08; if (!M.playing) M.step = 0; }
    M.playing = true;
    const chains = Object.values(M.ch);
    while (M.nextT < t + .25) { this.musNote(M.step++, M.nextT, chains, beat); M.nextT += beat; }
  },
  musDrop(id) {
    const M = this.mus, ch = M.ch[id]; if (!ch) return; delete M.ch[id]; if (!Object.keys(M.ch).length) M.playing = false;
    try { ch.g.gain.setTargetAtTime(0, AU.t(), .03); } catch (_) { }
    setTimeout(() => { for (const n of [ch.g, ch.hp, ch.lp, ch.pan]) try { n.disconnect(); } catch (_) { } }, 400);
  },
  musStop() { for (const id in this.mus.ch) this.musDrop(id); this.mus.nextT = 0; this.mus.playing = false; },
  musNote(step, t, chains, beat) {
    const b = DANCER_WALTZ[step % DANCER_WALTZ.length], hz = n => 440 * 2 ** ((n - 69) / 12);
    for (const ch of chains) {
      const d = ch.g;
      if (b.mel) { const f = hz(b.mel[0]) * (1 + (Math.random() - .5) * .01), dur = Math.max(.7, b.mel[1] * beat * 1.7);
        AU.osc('sine', f, t, t + dur + .05, AU.env(d, t, .075, .002, dur));
        AU.osc('sine', f * 2, t, t + .5, AU.env(d, t, .02, .002, .4));
        AU.osc('sine', f * 5.4, t, t + .12, AU.env(d, t, .012, .001, .08)); }
      if (b.bass) AU.osc('triangle', hz(b.bass + 12), t, t + .55, AU.env(d, t, .055, .004, .48));
      if (b.chord) for (const n of b.chord) AU.osc('sine', hz(n + 12), t, t + .32, AU.env(d, t, .016, .003, .26));
    }
  },
  /* ---------- клиент: звуковые подсказки ---------- */
  sTap(pos, v) { const t = AU.t(), out = AU.at(pos); AU.nz(out, t, .03, v, 'highpass', 2500, 1, .001); AU.osc('sine', 1300 + Math.random() * 300, t, t + .05, AU.env(out, t, v * .45, .001, .035)); },
  sSwish(pos) {
    const t = AU.t(), out = AU.at(pos), n = AU.nz(out, t, .8, .1, 'bandpass', 700, 1.2, .2); n.f.frequency.linearRampToValueAtTime(2400, t + .7);
    [93, 88, 84].forEach((k, i) => { const f = 440 * 2 ** ((k - 69) / 12), tt = t + .1 + i * .12; AU.osc('sine', f, tt, tt + .45, AU.env(out, tt, .045, .002, .4)); });
  },
  sChase(pos) {
    const t = AU.t(), out = AU.at(pos);
    [81, 84, 88, 93, 96].forEach((k, i) => { const f = 440 * 2 ** ((k - 69) / 12), tt = t + i * .06; AU.osc('sine', f, tt, tt + .55, AU.env(out, tt, .09, .002, .5)); AU.osc('sine', f * 1.06, tt, tt + .3, AU.env(out, tt, .03, .002, .25)); });
  },
  sGiggle(pos) {
    const A = AU.ctx, t = AU.t(), out = AU.at(pos), bp = A.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 1500; bp.Q.value = 2; bp.connect(out);
    for (let i = 0; i < 4; i++) { const tt = t + i * .13, o = AU.osc('triangle', 820 + i * 40, tt, tt + .1, AU.env(bp, tt, .11, .01, .08)); o.frequency.linearRampToValueAtTime(990 + i * 30, tt + .08); }
  },
};
// вальс ля минор 3/4: по долям {mel:[midi, долей], bass, chord}
const DANCER_WALTZ = (() => {
  const bars = [[[69, 2], [72, 1]], [[76, 2], [74, 1]], [[72, 1], [71, 1], [69, 1]], [[68, 3]], [[71, 2], [74, 1]], [[77, 2], [76, 1]], [[74, 1], [72, 1], [71, 1]], [[69, 3]],
    [[76, 2], [81, 1]], [[79, 2], [77, 1]], [[76, 1], [74, 1], [72, 1]], [[71, 3]], [[72, 1], [76, 1], [81, 1]], [[80, 2], [83, 1]], [[81, 1], [76, 1], [72, 1]], [[69, 3]]];
  const Am = [45, [57, 60, 64]], E = [40, [56, 59, 62]], F = [41, [57, 60, 65]], Dm = [38, [53, 57, 62]], G7 = [43, [53, 59, 62]], C = [48, [55, 60, 64]];
  const harm = [Am, Am, F, E, E, Dm, E, Am, Am, G7, C, E, Am, E, Am, Am], out = [];
  bars.forEach((bar, i) => { const ev = {}; let k = 0; for (const [n, d] of bar) { ev[k] = [n, d]; k += d; } for (let j = 0; j < 3; j++) out.push({ mel: ev[j] || null, bass: j === 0 ? harm[i][0] : 0, chord: j ? harm[i][1] : null }); });
  return out;
})();

INMATES.def({
  key: 'dancer', num: '214', name: 'ТАНЦОВЩИЦА', en: 'THE DANCER', cls: 'ОХОТНИЦА ЗА РАЗДРАЖИТЕЛЯМИ', hp: 100, speed: 2.6, chase: 5.0, color: '#e092b0',
  difficulty: 1, minNight: 1, eye: 1.85, darkSight: 4, directive: 'LIGHTS_OFF', ns: DANCER,
  alert: ['ТАКТИЧЕСКОЕ СКАНИРОВАНИЕ ПРОАНАЛИЗИРОВАЛО ПОВЕДЕНИЕ СУБЪЕКТА «ТАНЦОВЩИЦА». ОНА ИЩЕТ ТЕЛЕВИЗОРЫ И РАДИОПРИЁМНИКИ И ВКЛЮЧАЕТ МУЗЫКУ, КОТОРАЯ УСКОРЯЕТ ЕЁ ДВИЖЕНИЯ.',
    'СУБЪЕКТ ФИЗИЧЕСКИ ХРУПОК, НО ПОД ДЕЙСТВИЕМ МУЗЫКИ ЧРЕЗВЫЧАЙНО ПРОВОРЕН.',
    'ЕСЛИ В ВАШЕМ ДОМЕ ЗАИГРАЛА МУЗЫКА — ПОГАСИТЕ ВЕСЬ СВЕТ И СПРЯЧЬТЕСЬ ПОДАЛЬШЕ ОТ ИСТОЧНИКА.'],
  tip: 'Музыка её ускоряет: выключи телевизор и радио (или щиток), погаси свет, прячься подальше от вальса. Хрупкая — два выстрела.',
  model() {
    const g = new THREE.Group(); g.rotation.order = 'YXZ'; const p = { g }; g.userData.parts = p;
    const legH = 1.0, torH = .55, w = .32, skin = '#e8ddd6', tights = '#f2cfd8', pink = '#e092b0', pinkD = '#b06a88', dirt = '#8a5a68', hair = '#2a1a16';
    // ноги на пуантах
    p.ll = MM.limb(g, .11, legH, tights, -.075, legH, 0); p.rl = MM.limb(g, .11, legH, tights, .075, legH, 0);
    for (const L of [p.ll, p.rl]) { MM.box(L, .12, .16, .15, '#f6b6c8', 0, -legH + .08, .015); MM.box(L, .125, .03, .125, '#c86a8a', 0, -legH + .3, 0); }
    // корсет, пояс, грязная пачка с оборванными лоскутами
    p.torso = MM.box(g, w, torH, .2, pink, 0, legH + torH / 2, 0); MM.box(g, w + .02, .06, .22, pinkD, 0, legH + .03, 0);
    p.tutu = new THREE.Group(); p.tutu.position.y = legH + .02; g.add(p.tutu);
    MM.cyl(p.tutu, .5, .52, .07, pink, 0, 0, 0, { seg: 9 }); MM.cyl(p.tutu, .44, .47, .06, '#c87a98', 0, -.06, 0, { seg: 7 }).rotation.y = .3;
    for (const [a, h] of [[.4, .2], [2.2, .26], [3.9, .16], [5.1, .22]]) MM.box(p.tutu, .12, h, .02, dirt, Math.sin(a) * .47, -h / 2 - .02, Math.cos(a) * .47, { ry: a });
    // тонкие руки
    const sh = legH + torH - .04;
    p.la = MM.limb(g, .085, .62, skin, -(w / 2 + .055), sh, 0); p.ra = MM.limb(g, .085, .62, skin, w / 2 + .055, sh, 0);
    MM.box(g, .07, .08, .07, skin, 0, legH + torH + .03, 0);
    // голова: пучок и треснувшая белая театральная маска
    p.head = new THREE.Group(); p.head.position.set(0, legH + torH + .06, 0); g.add(p.head); p.headH = legH + torH + .06;
    MM.box(p.head, .26, .3, .26, skin, 0, .15, 0);
    MM.box(p.head, .28, .1, .28, hair, 0, .31, -.01); MM.box(p.head, .28, .26, .06, hair, 0, .16, -.12); MM.sph(p.head, .1, hair, 0, .37, -.1, { seg: 8, seg2: 6 });
    MM.box(p.head, .16, .05, .05, '#d0507a', 0, .44, -.1);
    MM.box(p.head, .28, .34, .035, '#f6f4ef', 0, .15, .145);
    const black = mat('#000000', { basic: true });
    for (const s of [-1, 1]) {
      MM.box(p.head, .078, .042, .012, '', s * .065, .195, .166, { rz: s * .28, mat: black });   // пустые глазницы
      MM.box(p.head, .012, .09, .01, '#151515', s * .07, .128, .166);                            // чёрные слёзы
      MM.box(p.head, .045, .025, .008, '#e8a0b0', s * .095, .09, .166);                          // румяна
    }
    MM.box(p.head, .085, .03, .01, '#a01828', 0, .055, .166);
    MM.box(p.head, .01, .17, .008, '#3a3330', .035, .235, .168, { rz: .5 }); MM.box(p.head, .01, .1, .008, '#3a3330', .072, .15, .168, { rz: -.45 });
    // сломанный чёрный зонт в правой руке (держится вертикально)
    p.umb = new THREE.Group(); p.umb.rotation.order = 'ZYX'; p.umb.position.set(0, -.6, 0); p.ra.add(p.umb);
    MM.cyl(p.umb, .013, .013, 1.3, '#1a1a1a', 0, .55, 0); MM.box(p.umb, .03, .1, .03, '#3a2a1a', 0, -.12, .02);
    const can = new THREE.Mesh(new THREE.ConeGeometry(.6, .3, 8, 1, true), mat('#221c28', { side: THREE.DoubleSide })); can.position.set(0, 1.22, 0); can.rotation.z = .12; p.umb.add(can);
    MM.box(p.umb, .3, .015, .22, '#221c28', .5, 1.0, .1, { rz: -1.0 });
    MM.cyl(p.umb, .006, .006, .5, '#555555', -.45, 1.05, -.2, { rz: 1.1 });
    MM.sph(p.umb, .025, '#1a1a1a', 0, 1.4, 0, { seg: 6, seg2: 4 });
    // поза по умолчанию (лобби/скример): руки во второй позиции, зонт над головой
    p.la.rotation.set(-.15, 0, -1.15); p.ra.rotation.set(-.65, 0, .15); p.umb.rotation.set(.65, 0, -.15);
    return g;
  },
  init(m) { m.cl = {}; if (DANCER.n++ === 0 && WORLD.level === 'house') DANCER.makeRadio(); },
  cleanup(m) {
    DANCER.n = Math.max(0, DANCER.n - 1);
    if (!DANCER.n || !INM.some(q => q !== m && !q.gone && q.type === 'dancer')) { DANCER.n = 0; DANCER.removeRadio(); DANCER.musStop(); }
  },
  spawn(m) {
    // вещание обрывается: телевизор гаснет, радио молчит — она включит их сама
    wsSet('TV', { on: 0 }); if (WS[DANCER.RADIO]) wsSet(DANCER.RADIO, { on: 0 });
    const ents = HOUSE.entries, e = Math.random() < .5 ? ents[0] : pick(ents); m.entry = e; m.p.copy(e.out); m.state = 'enter'; m.goNode(m.nodeNear(e.in));
    m.mem.nextTune = 0; m.mem.spinNext = 8;
  },
  tick(m, dt) { const y0 = m.p.y; m.T.think(m, dt); if (y0 - m.p.y > 1.2) m.p.y = y0; },
  think(m, dt) {
    const D = DANCER, mem = m.mem, mul = 1 + .25 * D.playing();
    const spd = m.T.speed * mul, chs = Math.min(6.2, m.T.chase * mul), opt = { speed: spd, chase: chs, sight: 22 };
    m.speedNow = 0; mem.mul = mul;
    // музыку выключили — заметит и скоро вернётся её включить
    for (const id of D.ids()) { const on = D.on(id); if (mem['on_' + id] && !on) { mem.nextTune = Math.min(mem.nextTune || 0, m.t + 4); mem.lastOff = id; } mem['on_' + id] = on; }
    if (m.stun > 0) { mem.spinT = 0; if (m.state === 'tune') { m.state = 'roam'; m.path = []; } m.hunt(dt, opt); return; }
    if (m.state === 'enter') { m.hunt(dt, opt); return; }
    if (m.state === 'tune' || mem.spinT > 0) {
      const seen = D.spot(m, 22);
      if (seen && (m.state !== 'tune' || seen.d < 14)) { mem.spinT = 0; D.chase(m, seen); }   // заметила жертву — бросает всё
      else if (m.state === 'tune') { D.tune(m, dt, spd); m.tryKill(1.1); return; }
      else { mem.spinT -= dt; m.a = 3; m.tryKill(1.1); return; }
    }
    if (m.state !== 'chase' && m.state !== 'investigate') {
      const off = D.offSource(m);
      if (off && m.t >= (mem.nextTune || 0)) { D.startTune(m, off); D.tune(m, dt, spd); m.tryKill(1.1); return; }
      if ((m.state === 'roam' || m.state === 'investigate') && D.unstick(m, dt, spd)) { m.a = 0; m.tryKill(1.1); return; }
      if (m.state === 'roam' && !m.path.length) {
        if (m.t > (mem.spinNext || 0)) { mem.spinNext = m.t + 9 + Math.random() * 7; mem.spinT = 1.7; m.a = 3; return; }   // пируэт посреди комнаты
        const node = D.pickRoom(m); if (node) m.goNode(node);
      }
    }
    m.hunt(dt, opt);
  },
  anim(m, dt, moving) {
    const p = m.model.userData.parts, c = m.cl || (m.cl = {}), M = m.model, t = m.t, a = m.a;
    c.moving = moving;
    for (const k of ['ll', 'rl', 'la', 'ra']) p[k].rotation.set(0, 0, 0);
    p.head.rotation.set(0, 0, 0); p.tutu.scale.set(1, 1, 1); p.tutu.rotation.y = 0;
    let lean = 0;
    if (a === 3) {          // пируэт: арабеск, рука над головой, зонт кружится
      c.spin = (c.spin || 0) + dt * 10; M.rotation.y += c.spin;
      p.la.rotation.set(-2.75, 0, -.35); p.ra.rotation.set(0, 0, 1.25); p.rl.rotation.x = 1.25; p.ll.rotation.x = -.05;
      p.tutu.scale.set(1.15, .8, 1.15); p.tutu.rotation.y = c.spin * .3; p.head.rotation.z = .25;
    } else {
      c.spin = 0;
      if (a === 1) {        // погоня: мелкие быстрые шаги на пуантах, рука вскинута, голова дёргается
        lean = .18; const s = Math.sin(m.walkT * 1.5) * .45; p.ll.rotation.x = s; p.rl.rotation.x = -s;
        p.la.rotation.set(-2.5 + Math.sin(t * 9) * .25, 0, -.45); p.ra.rotation.set(-.85 + Math.sin(t * 9) * .2, 0, .25);
        p.head.rotation.z = Math.sin(t * 7) * .3; p.head.rotation.x = -.1;
      } else if (a === 2) { // оглушена
        lean = .4; p.la.rotation.set(-.2, 0, -.15); p.ra.rotation.set(-.3, 0, .1); p.head.rotation.x = .55; p.ll.rotation.x = -.3;
      } else if (a === 4) { // тянется к переключателю
        p.la.rotation.set(-1.5, 0, .05); p.ra.rotation.set(-.6, 0, .15); p.head.rotation.set(.2, 0, -.15);
      } else {              // обход: изящная походка, голова склоняется, иногда резкий наклон
        const s = moving ? Math.sin(m.walkT) * .38 : 0; p.ll.rotation.x = s; p.rl.rotation.x = -s;
        p.la.rotation.set(-.15 + Math.sin(t * 1.3) * .1, 0, -1.15 + Math.sin(t * 1.7) * .12); p.ra.rotation.set(-.65, 0, .15);
        p.head.rotation.z = Math.sin(t * .9) * .2 + (Math.sin(t * 2.3) > .96 ? .5 : 0);
      }
    }
    M.rotation.x = lean;
    const r = p.ra.rotation; p.umb.rotation.set(-(r.x + lean), 0, -r.z);
  },
  sound(m, dt) {
    DANCER.musUpdate();
    const c = m.cl; if (!AU.ctx || !c || m.vis === 0 || m.p.y < -50) return;
    const feet = m.p.clone().add(new V3(0, .2, 0)), head = m.p.clone().add(new V3(0, 1.7, 0));
    const ph = Math.floor(m.walkT / PI); if (ph !== c.ph) { c.ph = ph; if (c.moving) DANCER.sTap(feet, m.a === 1 ? .16 : .1); }
    if (m.a !== c.lastA) { if (m.a === 1) DANCER.sChase(head); else if (m.a === 3) DANCER.sSwish(head); c.lastA = m.a; }
    c.gig = (c.gig ?? 6 + Math.random() * 8) - dt;
    if (c.gig < 0) { c.gig = 10 + Math.random() * 12; if (m.a === 0 || m.a === 3) DANCER.sGiggle(head); }
  },
});
