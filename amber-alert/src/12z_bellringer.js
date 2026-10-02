/* ================= ЗАКЛЮЧЁННЫЙ 192: ЗВОНАРЬ (THE BELL RINGER) — охотник прямой видимости ================= */
// Постоянно звенит колокольчиками (позиционный синтез). Лампы в радиусе 8 м мигают (только визуально, у каждого клиента).
// Увидел игрока → колокольчики смолкают (a=3) → один металлический УДАР (a=4) → через 1.5 с рывок по прямой 8 м/с на 4 с (a=1).
// Разорвал линию видимости до рывка — потерял. Рывок останавливают стены, мебель и закрытые двери. Попадание дробью — оглушение 3 с (a=2).
// m.a: 0 — бродит/звенит, 1 — рывок, 2 — оглушён/врезался, 3 — тишина (заметил), 4 — замах после удара.
(() => {
  const EYE_Y = 1.85;                       // высота «глаз» для проверки видимости (ниже дверных перемычек)
  const SIGHT = 18, DARK = 6, CONE = .64;   // 100° обзор, 18 м на свету, 6 м в темноте
  const T_SILENT = .75, T_WIND = 1.5, T_CHARGE = 4, V_CHARGE = 8, DAZE = 3, FLICK_R = 8;
  const losF = b => !b.door || !(WS[b.door] && (WS[b.door].o || WS[b.door].b));

  /* ---------- восприятие (хост) ---------- */
  function sees(m, pl, maxD, cone) {
    if (!pl || pl.hid) return false;
    const e = new V3(m.p.x, m.p.y + EYE_Y, m.p.z), pp = new V3(pl.x, pl.y + (pl.cr ? .9 : 1.4), pl.z), d = e.distanceTo(pp);
    if (d > maxD) return false;
    if (cone) { const dx = pp.x - e.x, dz = pp.z - e.z, h = Math.hypot(dx, dz) || 1; if ((dx * Math.sin(m.yaw) + dz * Math.cos(m.yaw)) / h < cone && h > 1.2) return false; }
    if (!(pl.l || GAME.litAt(pp)) && d > DARK) return false;
    return WORLD.coll.los(e, pp, losF);
  }
  function spot(m) {
    let best = null;
    for (const pl of GAME.alivePlayers()) { if (!sees(m, pl, SIGHT, CONE)) continue; const d = Math.hypot(pl.x - m.p.x, pl.z - m.p.z); if (!best || d < best.d) best = { pl, d }; }
    return best;
  }
  // пол под ногами: чуть шире круг (перемахивает щель у верха лестницы), ступень не выше 0.36 м (не залезает на стулья/столики)
  function fixY(hint) { const g = WORLD.coll.groundAt(this.p.x, this.p.z, .4, this.p.y + .36); this.p.y = g > -40 ? g : hint; }

  /* ---------- рывок по прямой с коллизией (хост) ---------- */
  function charge(m, dt) {
    const B = m.br; let left = V_CHARGE * dt;
    while (left > 1e-4) {
      const s = Math.min(.12, left); left -= s;
      const nx = m.p.x + B.dir.x * s, nz = m.p.z + B.dir.z * s;
      const hit = WORLD.coll.blocked(nx, m.p.y, nz, .27, 1.8, .36);
      if (hit) return hit;
      m.p.x = nx; m.p.z = nz; m.fixY(m.p.y);
      m.tryKill(.9);
    }
    return null;
  }
  // сторож: если «идёт», но не сдвинулся за 3 с — сбросить путь (а после трёх раз — встать на ближайший узел)
  function watchdog(m, dt) {
    const W = m.br.wd; W.t += dt; if (W.t < 3) return;
    const d = Math.hypot(m.p.x - W.x, m.p.z - W.z);
    if (W.mv > 1.5 && d < .3) { m.path = []; W.n++; if (m.state === 'investigate') m.state = 'roam'; if (W.n >= 3) { const k = m.nodeNear(m.p); if (k) m.p.copy(WORLD.nav[k].p); W.n = 0; } } else if (d >= .3) W.n = 0;
    W.t = 0; W.mv = 0; W.x = m.p.x; W.z = m.p.z;
  }
  // узлы окон в WORLD.nav — тупики (связаны сами с собой), поэтому цель-окно заменяем ближайшим обычным узлом той же стороны
  function fixNode(k) {
    const N = WORLD.nav, n = N[k]; if (!n || !n.win) return k; let best = null, bd = 1e9;
    for (const q in N) { const o = N[q]; if (o.win || (o.room === 'out') !== (n.room === 'out') || Math.abs(o.p.y - n.p.y) > 1) continue; const d = o.p.distanceTo(n.p); if (d < bd) { bd = d; best = q; } }
    return best || k;
  }
  function goSafe(m, node) {
    node = fixNode(node); m.goNode(node); if (m.path.length || !node) return;
    const from = m.nodeNear(m.p); if (!from || from === node) return;
    const alt = fixNode(from); if (alt !== from) m.path = [{ node: alt }];     // стоит на тупиковом узле окна — сначала к обычному узлу
  }
  function roamGoal(m) { const rooms = Object.values(WORLD.nav).filter(n => n.room && n.room !== 'out' && !n.win); goSafe(m, pick(rooms).id); }
  // можно ли рвануть по прямой: между ним и целью нет стен (подоконники, перегородки); мебель и двери не мешают решению
  // (три параллельных луча по ширине тела на двух высотах — косяки дверей и подоконники тоже считаются)
  function chargeable(m, pl) {
    const f = b => !b.door && b.y1 - b.y0 > .9, dx = pl.x - m.p.x, dz = pl.z - m.p.z, d = Math.hypot(dx, dz); if (d < .5) return true;
    const ux = dx / d, uz = dz / d, L = Math.max(.3, d - .5);
    for (const o of [0, -.24, .24]) for (const y of [.5, 1.3]) { const ax = m.p.x - uz * o, az = m.p.z + ux * o; if (!WORLD.coll.los(new V3(ax, m.p.y + y, az), new V3(ax + ux * (o ? L : d), m.p.y + y, az + uz * (o ? L : d)), f)) return false; }
    return true;
  }

  /* ---------- звук (у всех клиентов) ---------- */
  const P_JINGLE = [[1, 1], [2.32, .45], [4.07, .22], [6.1, .1]];
  const P_BELL = [[.5, .25], [1, 1], [1.19, .45], [1.5, .3], [2, .4], [2.74, .12]];
  function bell(out, t, f, v, dec, parts) {
    const g = AU.env(out, t, v, .002, dec);
    for (const [k, a] of parts) { const og = AU.ctx.createGain(); og.gain.value = a; og.connect(g); AU.osc('sine', f * k, t, t + dec + .1, og); }
  }
  function jingle(pos, n, v) { // гроздь бубенцов
    const out = AU.at(pos), t = AU.t();
    for (let i = 0; i < n; i++) { const tt = t + Math.random() * .07; bell(out, tt, 2300 + Math.random() * 2000, v * (.6 + Math.random() * .5), .12 + Math.random() * .25, P_JINGLE); }
    AU.nz(out, t, .03, v * .5, 'highpass', 6000, 1, .001);
  }
  function brass(pos, v) { const out = AU.at(pos), t = AU.t(); bell(out, t, 560 + Math.random() * 520, v, 1.1 + Math.random() * .6, P_BELL); }
  function chime(pos, v) { const out = AU.at(pos), t = AU.t(), f = [1046, 1175, 1397, 1568, 1760, 2093][(Math.random() * 6) | 0]; bell(out, t, f, v, 1.4, [[1, 1], [2.76, .3], [5.4, .12]]); }
  function crash(pos, near) { // один оглушительный металлический удар
    const t = AU.t();
    for (const [out, v] of [[AU.at(pos), 1], [AU.sfx, .22 + .3 * near]]) {
      AU.nz(out, t, 1.7, .55 * v, 'highpass', 2600, .7, .002); AU.nz(out, t, .6, .7 * v, 'bandpass', 900, 1.4, .002);
      for (let i = 0; i < 12; i++) AU.osc(i % 3 ? 'sine' : 'triangle', 170 + Math.random() * 4200, t, t + 2.6, AU.env(out, t, .045 * v, .001, 1.1 + Math.random() * 1.2));
      bell(out, t, 410, .2 * v, 2.4, P_BELL); AU.osc('sine', 52, t, t + .5, AU.env(out, t, .8 * v, .002, .4));
    }
  }
  function growl(pos) { // низкий нарастающий гул в замахе
    const c = AU.ctx, t = AU.t(), out = AU.at(pos), f = c.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 260;
    const g = AU.env(out, t, .25, 1.2, .35); f.connect(g);
    const o = AU.osc('sawtooth', 48, t, t + 1.7, f); o.frequency.linearRampToValueAtTime(82, t + 1.5);
  }
  function clatter(pos) { // колокольчики беспорядочно бренчат (оглушён/врезался)
    const out = AU.at(pos), t = AU.t();
    for (let i = 0; i < 9; i++) { const tt = t + i * .06 + Math.random() * .05; bell(out, tt, 700 + Math.random() * 2800, .05, .3 + Math.random() * .5, P_JINGLE); }
    AU.nz(out, t, .25, .3, 'bandpass', 1800, 1.5, .002);
  }

  /* ---------- мигание ламп рядом (у всех клиентов; восстановить в cleanup) ---------- */
  function lampOff(st) {
    const a = st.m.a, t = now() + st.seed;
    const n = Math.sin(t * 11.3) + Math.sin(t * 5.7 + 1.3) * .8 + Math.sin(t * 23.9 + .7) * .6;
    return n > (a === 3 ? -.7 : a === 4 || a === 1 ? .45 : 1.7);
  }
  function flicker(m) {
    const S = m.brL || (m.brL = new Map()), c = new V3(m.p.x, m.p.y + 1.4, m.p.z), vis = m.vis !== 0 && m.p.y > -50;
    for (const L of WORLD.lamps) {
      if (!L || !L.pos || typeof L.on !== 'function') continue;
      const st = S.get(L), inR = vis && L.pos.distanceTo(c) < (st ? FLICK_R + 1 : FLICK_R);
      if (inR && !st) { const s = { L, m, on: L.on, flicker: L.flicker, active: true, seed: Math.random() * 50 }; s.w = () => s.on.call(L) && !(s.active && lampOff(s)); L.on = s.w; L.flicker = true; S.set(L, s); }
      else if (!inR && st) unflick(S, st);
    }
  }
  function unflick(S, s) { s.active = false; if (s.L.on === s.w) { s.L.on = s.on; s.L.flicker = s.flicker; } S.delete(s.L); }

  INMATES.def({
    key: 'bellringer', num: '192', name: 'ЗВОНАРЬ', en: 'THE BELL RINGER', cls: 'ОХОТНИК ПРЯМОЙ ВИДИМОСТИ',
    hp: 700, speed: 2.6, chase: V_CHARGE, color: '#a3261c', difficulty: 2, minNight: 1, eye: 2.75, canHear: true,
    alert: [
      'ТАКТИЧЕСКОЕ СКАНИРОВАНИЕ ПРОАНАЛИЗИРОВАЛО СУБЪЕКТА «ЗВОНАРЬ» — ЗАКЛЮЧЁННЫЙ 192. ЕГО ТЕЛО ОБМОТАНО ВЕРЁВКАМИ С КОЛОКОЛЬЧИКАМИ, ИХ ПОСТОЯННЫЙ ЗВОН ВЫДАЁТ ЕГО ПРИБЛИЖЕНИЕ. РЯДОМ С НИМ МИГАЕТ СВЕТ.',
      'ЭТО ОХОТНИК ПРЯМОЙ ВИДИМОСТИ. ЕСЛИ ВАС ЗАМЕТИЛИ — НЕ ПЫТАЙТЕСЬ УБЕЖАТЬ ОТ НЕГО ПО ОТКРЫТОМУ ПРОСТРАНСТВУ.',
      'ЕСЛИ ЗВОН СМЕНИТСЯ ОДНИМ ОГЛУШИТЕЛЬНЫМ МЕТАЛЛИЧЕСКИМ УДАРОМ — У ВАС ЕСТЬ СЕКУНДЫ. НЕМЕДЛЕННО РАЗОРВИТЕ ЛИНИЮ ВИДИМОСТИ.',
    ],
    tip: 'Звон стих и грохнул удар — у тебя полторы секунды: за угол или за дверь. Не беги через открытую комнату. Выстрел оглушает его на 3 с.',
    model() {
      const s = 1.12, p = MM.humanoid({ s, leg: .98, torso: .82, arm: 1.12, w: .5, shirt: '#3a271e', sleeve: '#3f2a20', pants: '#1d1512' }), g = p.g;
      g.userData.parts = p; g.rotation.order = 'YXZ';
      const legH = .98 * s, torH = .82 * s, armL = 1.12 * s, top = legH + torH;
      const brassM = mat('#c99a32', { emissive: '#2a1a00' }), ropeM = mat('#7a5a34'), steel = mat('#b8c2cc', { emissive: '#101418' });
      // рваный подол плаща
      MM.box(g, .62, .62, .38, '#33221a', 0, legH - .2, 0);
      for (const [x, h] of [[-.2, .42], [.17, .5]]) MM.box(g, .13, h, .04, '#251813', x, legH - .5 - h / 2 + .06, .17);
      // перевязи крест-накрест с бубенцами
      for (const sg of [-1, 1]) {
        const rz = sg * .62; MM.box(g, .07, 1.08, .05, '#7a5a34', 0, legH + torH * .5, .17, { mat: ropeM, rz });
        for (const k of [-.36, 0, .36]) MM.cyl(g, .025, .06, .09, '', -Math.sin(rz) * k, legH + torH * .5 + Math.cos(rz) * k - .03, .215, { mat: brassM });
      }
      MM.cyl(g, .05, .13, .18, '', 0, legH + torH * .66, .23, { mat: brassM });     // большой колокол на груди
      MM.box(g, .58, .07, .4, '', 0, legH + .07, 0, { mat: ropeM });                 // пояс-верёвка
      for (const x of [-.22, -.075, .075, .22]) MM.cyl(g, .03, .075, .11, '', x, legH - .04, .21, { mat: brassM });
      // кисти рук и связки «музыки ветра»
      for (const a of [p.la, p.ra]) {
        MM.box(a, .14, .2, .11, '#6a1c14', 0, -armL - .08, 0);
        MM.box(a, .26, .025, .025, '', 0, -armL - .2, 0, { mat: ropeM });
        for (const [x, h] of [[-.08, .34], [.08, .26]]) MM.cyl(a, .016, .016, h, '', x, -armL - .22 - h / 2, 0, { mat: steel, seg: 6 });
      }
      // шея и голова: сырое красное «узловатое» лицо (асимметричное)
      MM.box(g, .16, .16, .16, '#7e1c14', 0, top + .05, -.01);
      const h = p.head; h.position.y = top + .1;
      MM.box(h, .44, .5, .4, '#9e2219', 0, .25, 0);
      MM.box(h, .46, .1, .16, '#7a1610', 0, .42, .14);                        // нависший лоб
      MM.box(h, .3, .018, .02, '#3e0805', .02, .47, .215);   // морщины-борозды
      MM.sph(h, .1, '#b8352a', -.13, .4, .16, { seg: 6, seg2: 5 });           // вздутие над левым глазом
      MM.box(h, .14, .14, .09, '#c4432f', -.16, .13, .18);                     // наросты на щеках и челюсти
      MM.box(h, .11, .2, .08, '#86190f', .17, .2, .18, { rz: .25 });
      MM.sph(h, .09, '#8e2016', .2, .44, .05, { seg: 6, seg2: 5 });
      MM.sph(h, .08, '#c03a2a', -.22, .34, -.04, { seg: 6, seg2: 5 });
      MM.box(h, .12, .1, .12, '#6e140e', .05, .52, -.08);
      MM.box(h, .13, .11, .04, '#080303', -.1, .29, .19); MM.box(h, .09, .07, .04, '#080303', .105, .32, .19);   // глазницы разного размера
      const eyeM = new THREE.MeshBasicMaterial({ color: '#f2e6a8' });
      const pupils = [[-.1, .285], [.105, .32]].map(([x, y]) => MM.sph(h, .022, '', x, y, .215, { mat: eyeM, seg: 6, seg2: 5 }));
      for (const x of [-.025, .025]) MM.box(h, .025, .04, .02, '#160404', x, .22, .205);   // ноздри-дыры
      MM.box(h, .26, .13, .04, '#120404', .01, .08, .19, { rz: -.08 });       // растянутая пасть
      for (const [x, th] of [[-.085, .07], [-.025, .05], [.035, .08], [.1, .055]]) MM.box(h, .03, th, .02, '#e2d4b4', x, .135 - th / 2 + .01, .215);
      // проволочный нимб
      const haloM = new THREE.MeshLambertMaterial({ color: '#a0937e', emissive: '#000000' });
      const halo = new THREE.Mesh(new THREE.TorusGeometry(.34, .03, 6, 22), haloM); halo.position.set(0, .3, -.24); h.add(halo);
      for (let i = 0; i < 5; i++) { const a = i / 5 * TAU + .3, l = .1 + (i % 3) * .05; MM.box(h, .016, l, .016, '', Math.cos(a) * (.36 + l / 2), .3 + Math.sin(a) * (.36 + l / 2), -.24, { mat: haloM, rz: a - PI / 2 }); }
      g.userData.br = { eyeM, haloM, pupils, halo };
      return g;
    },
    init(m) { m.fixY = fixY; m.brL = new Map(); m.brS = { a: m.a, jt: .3, bt: 2, ct: 1.5, st: 0, lp: m.p.clone(), v: 0, rr: 0 }; },
    cleanup(m) { if (m.brL) for (const s of [...m.brL.values()]) unflick(m.brL, s); },
    tick(m, dt) {
      const B = m.br || (m.br = { t: 0, hp: m.hp, lost: 0, dir: new V3(), last: null, tid: null, wd: { t: 0, x: m.p.x, z: m.p.z, n: 0, mv: 0 } });
      m.speedNow = 0; B.t += dt;
      // любое попадание (дробовик) — оглушение на 3 с
      if (m.hp < B.hp - .01) m.stun = Math.max(m.stun, DAZE);
      B.hp = m.hp;
      if (m.stun > 0) { m.stun -= dt; m.a = 2; if (m.state !== 'daze') { m.state = 'daze'; m.path = []; B.tid = null; } return; }
      if (m.state === 'daze') { m.state = 'roam'; m.path = []; B.t = 0; }
      const S = m.state;
      // ---- заметил: тишина → удар → замах ----
      if (S === 'silent' || S === 'windup') {
        const pl = GAME.alivePlayers().find(q => q.id === B.tid);
        if (pl && sees(m, pl, SIGHT + 4, 0)) { B.lost = 0; B.last = new V3(pl.x, pl.y, pl.z); m.yaw = Math.atan2(pl.x - m.p.x, pl.z - m.p.z); } else B.lost += dt;
        if (!pl || B.lost > .3) { m.state = 'lost'; B.t = 0; m.a = 0; return; }        // разорвали линию видимости — потерял
        m.a = S === 'silent' ? 3 : 4;
        if (S === 'silent' && B.t > T_SILENT) { m.state = 'windup'; B.t = 0; m.a = 4; }
        else if (S === 'windup' && B.t > T_WIND && !chargeable(m, pl)) { m.state = 'investigate'; m.path = []; m.a = 0; }
        else if (S === 'windup' && B.t > T_WIND) { const dx = pl.x - m.p.x, dz = pl.z - m.p.z, d = Math.hypot(dx, dz) || 1; B.dir.set(dx / d, 0, dz / d); m.yaw = Math.atan2(dx, dz); m.state = 'charge'; B.t = 0; m.a = 1; }
        m.tryKill(1);
        return;
      }
      // ---- рывок ----
      if (S === 'charge') {
        m.a = 1; m.speedNow = V_CHARGE; const hit = charge(m, dt);
        if (hit) { m.state = 'impact'; B.t = 0; m.a = 2; GAME.fxAll('bang', new V3(m.p.x + B.dir.x * .4, m.p.y + 1.2, m.p.z + B.dir.z * .4)); CAMSHAKE(m.p, .9); }
        else if (B.t > T_CHARGE) { m.state = 'recover'; B.t = 0; m.a = 0; }
        return;
      }
      if (S === 'impact') { m.a = 2; if (B.t > 1.2) { m.state = 'roam'; m.path = []; B.t = 0; } return; }
      // ---- обычное поведение: войти, бродить, проверять шум; везде — высматривать ----
      const seen = spot(m);
      if (seen) {
        const pl = seen.pl;
        if (Math.abs(pl.y - m.p.y) < 1.6 && chargeable(m, pl)) { m.state = 'silent'; B.tid = pl.id; B.t = 0; B.lost = 0; m.path = []; B.last = new V3(pl.x, pl.y, pl.z); m.yaw = Math.atan2(pl.x - m.p.x, pl.z - m.p.z); m.a = 3; return; }
        if (m.state !== 'enter' && (!B.last || B.last.distanceTo(new V3(pl.x, pl.y, pl.z)) > 3)) { m.state = 'investigate'; m.path = []; } // на другом этаже — идёт туда
        B.last = new V3(pl.x, pl.y, pl.z);
      } else if (m.state !== 'enter' && m.state !== 'lost' && m.state !== 'recover') {
        for (const pl of GAME.alivePlayers()) if (!pl.hid && m.hears(pl)) { const q = new V3(pl.x, pl.y, pl.z); if (m.state !== 'investigate' || !B.last || B.last.distanceTo(q) > 3) { m.state = 'investigate'; m.path = []; } B.last = q; break; }
      }
      m.a = 0;
      if (m.state === 'lost' || m.state === 'recover') { if (B.t > (m.state === 'lost' ? 1.2 : .8)) { m.state = m.state === 'lost' && B.last ? 'investigate' : 'roam'; m.path = []; } }
      else if (m.state === 'enter') { if (!m.path.length && m.entry) goSafe(m, m.nodeNear(m.entry.in)); if (m.follow(dt, m.T.speed)) { m.state = 'roam'; m.path = []; } }
      else if (m.state === 'investigate' && B.last) { if (!m.path.length) goSafe(m, m.nodeNear(B.last)); if (m.follow(dt, m.T.speed * 1.15)) { m.state = 'roam'; m.path = []; B.last = null; } }
      else { m.state = 'roam'; if (!m.path.length) roamGoal(m); m.follow(dt, m.T.speed); }
      B.wd.mv += m.speedNow > 0 ? dt : 0; watchdog(m, dt);
      m.tryKill(1);
    },
    anim(m, dt, moving) {
      const p = m.model.userData.parts, U = m.model.userData.br, a = m.a, t = m.t, g = m.model;
      flicker(m);
      MM.walk(p, m.walkT, a === 1 ? .95 : moving && a === 0 ? .5 : 0);
      let lean = 0; p.la.rotation.z = -.08; p.ra.rotation.z = .08; p.head.rotation.set(0, 0, Math.sin(t * 1.3) * .08);
      if (a === 1) { lean = .32; p.la.rotation.x = p.ra.rotation.x = 1.15; p.la.rotation.z = -.35; p.ra.rotation.z = .35; p.head.rotation.x = -.25; }
      else if (a === 2) { lean = Math.sin(t * 2.2) * .07; g.rotation.z = Math.sin(t * 3.1) * .12; p.head.rotation.set(.35, 0, .55 + Math.sin(t * 2) * .2); p.la.rotation.x = Math.sin(t * 3) * .3; p.ra.rotation.x = -Math.sin(t * 3) * .3; }
      else if (a === 3) { p.head.rotation.set(-.1, 0, .5); p.la.rotation.x = p.ra.rotation.x = -.25; }
      else if (a === 4) { lean = .22; p.la.rotation.x = p.ra.rotation.x = .7; p.la.rotation.z = -.95; p.ra.rotation.z = .95; p.ll.rotation.x = -.35; p.rl.rotation.x = .3; p.head.rotation.set(-.2 + (Math.random() - .5) * .06, (Math.random() - .5) * .08, 0); }
      g.rotation.x = lean; if (a !== 2) g.rotation.z = 0;
      // глаза и нимб раскаляются, когда он заметил жертву
      const hot = a === 3 || a === 4 || a === 1; const C = m.brS; C.rr = damp(C.rr, hot ? 1 : 0, 8, dt);
      U.eyeM.color.setRGB(.95, .9 - C.rr * .75, .66 - C.rr * .62); U.haloM.emissive.setRGB(C.rr * .9, C.rr * .12, 0); U.halo.rotation.z += dt * (a === 4 ? 4 : .3);
    },
    sound(m, dt) {
      if (!AU.ctx) return;
      const C = m.brS, a = m.a, pos = new V3(m.p.x, m.p.y + 1.7, m.p.z);
      const sp = m.p.distanceTo(C.lp) / Math.max(dt, 1e-3); C.lp.copy(m.p); C.v = damp(C.v, Math.min(sp, 10), 6, dt);
      let ld = 1e9; for (const lp of LOCALS) ld = Math.min(ld, lp.cam.position.distanceTo(pos));
      if (a !== C.a) { // смены состояний — разовые звуки
        if (a === 4) { crash(pos, clamp(1 - ld / 20, 0, 1)); growl(pos); CAMSHAKE(m.p, 1.2); }
        if (a === 2) clatter(pos);
        if (a === 1) jingle(pos, 6, .09);
        C.a = a;
      }
      if (ld > 42 || m.vis === 0 || m.p.y < -50) return;
      if (a === 0) { // постоянный звон: чаще на ходу
        const mov = C.v > .3; C.jt -= dt; if (C.jt <= 0) { jingle(pos, mov ? 3 : 2, mov ? .05 : .035); C.jt = (mov ? .16 : .55) * (.5 + Math.random()); }
        C.bt -= dt; if (C.bt <= 0) { brass(pos, .06); C.bt = 1.6 + Math.random() * 2.4; }
        C.ct -= dt; if (C.ct <= 0) { chime(pos, .035); C.ct = .7 + Math.random() * 1.6; }
      } else if (a === 1) { // рывок: бешеный звон и тяжёлые шаги
        C.jt -= dt; if (C.jt <= 0) { jingle(pos, 4, .08); C.jt = .07; }
        C.st -= dt; if (C.st <= 0) { AU.play('stepHeavy', new V3(m.p.x, m.p.y, m.p.z), { v: .55 }); C.st = .2; }
      } else if (a === 2) { C.jt -= dt; if (C.jt <= 0) { jingle(pos, 1, .03); C.jt = .3 + Math.random() * .5; } }
      // a === 3 / 4 — тишина (только гул замаха)
    },
  });
})();
