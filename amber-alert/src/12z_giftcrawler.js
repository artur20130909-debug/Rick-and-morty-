/* ================= ЗАКЛЮЧЁННЫЙ 305: ЯДОВИТЫЙ ПОЛЗУН (GIFTCRAWLER) — паразит у самого пола ================= */
// Длинное сегментное тело с десятками тонких ног и бледной человеческой головой. Ползает 3.6 м/с, по лестнице — 1.5 м/с.
// Не может подняться над полом: игрока, стоящего выше 0.4 м над полом (кровать, стол, стул, ступени над ним), не достаёт —
// подползает к краю мебели и ждёт внизу (≈14 с), потом теряет интерес. Касание головы — смерть. Капкан держит его (общая логика GAME).
// m.a: 0 — ползает/ищет, 1 — погоня, 2 — пойман капканом/оглушён, 3 — ждёт внизу (встаёт на дыбы), 4 — замер.
(() => {
  const V_CHASE = 3.6, V_ROAM = 2.4, V_STAIRS = 1.5, HIGH = .4, REACH = .8, WAIT_MAX = 14, IGNORE_T = 12;
  const NSEG = 10, SEG0 = .3, SEGD = .285;
  const losF = b => !b.door || !(WS[b.door] && (WS[b.door].o || WS[b.door].b));

  /* ---------- навигация (хост) ---------- */
  // узлы окон в WORLD.nav — тупики (связаны сами с собой), поэтому цель-окно заменяем ближайшим обычным узлом той же стороны
  function fixNode(k) {
    const N = WORLD.nav, n = N[k]; if (!n || !n.win) return k; let best = null, bd = 1e9;
    for (const q in N) { const o = N[q]; if (o.win || (o.room === 'out') !== (n.room === 'out') || Math.abs(o.p.y - n.p.y) > 1) continue; const d = o.p.distanceTo(n.p); if (d < bd) { bd = d; best = q; } }
    return best || k;
  }
  function goSafe(m, node) {
    node = fixNode(node); m.goNode(node); if (m.path.length || !node) return;
    const from = m.nodeNear(m.p); if (!from || from === node) return;
    const alt = fixNode(from); if (alt !== from) m.path = [{ node: alt }];
  }
  function rooms() { return Object.values(WORLD.nav).filter(n => n.room && n.room !== 'out' && !n.win); }
  function onStairs(p) { return p.x > -3.1 && p.x < -1.8 && p.z > -3.4 && p.z < .35 && p.y > .05 && p.y < F2 - .05; }
  const spd = (m, v) => onStairs(m.p) ? V_STAIRS : v;
  // пол под телом: ступень не выше 0.33 м (лестница — да, стулья/столики/кровати — нет); круг пошире перемахивает щель у верха лестницы
  function fixY(hint) { const g = WORLD.coll.groundAt(this.p.x, this.p.z, .4, this.p.y + .33); this.p.y = g > -40 ? g : hint; }
  function go(m, tp, dt, v, G) {
    const dh = Math.hypot(tp.x - m.p.x, tp.z - m.p.z);
    const direct = dh < 8 && Math.abs(tp.y - m.p.y) < 1.2 && WORLD.coll.los(new V3(m.p.x, m.p.y + 1.1, m.p.z), new V3(tp.x, m.p.y + 1.1, tp.z), losF);
    if (direct) { m.path = []; m.stepTo(tp, dt, spd(m, v)); return; }
    if (!m.path.length || G.rt <= 0) { goSafe(m, m.nodeNear(tp)); G.rt = .7; }
    if (m.follow(dt, spd(m, v))) m.stepTo(tp, dt, spd(m, v));
  }
  // к игроку на возвышении: до края мебели (дальше не лезет) — возвращает true, когда упёрся/дошёл
  function approach(m, pl, dt, G) {
    const dh = Math.hypot(pl.x - m.p.x, pl.z - m.p.z);
    if (dh < .45) return true;
    if (dh < 3 && Math.abs(pl.y - m.p.y) < 1.4) {
      const s = Math.min(dh, spd(m, V_CHASE) * dt), ux = (pl.x - m.p.x) / dh, uz = (pl.z - m.p.z) / dh;
      m.yaw = Math.atan2(ux, uz);
      if (WORLD.coll.blocked(m.p.x + ux * (s + .22), m.p.y, m.p.z + uz * (s + .22), .2, .55, .33)) return true;
      m.p.x += ux * s; m.p.z += uz * s; m.fixY(m.p.y); m.speedNow = V_CHASE; return false;
    }
    go(m, new V3(pl.x, pl.y, pl.z), dt, V_CHASE, G); return false;
  }

  /* ---------- восприятие (хост) ---------- */
  function sees(m, pl) {
    const e = new V3(m.p.x, m.p.y + .45, m.p.z), pp = new V3(pl.x, pl.y + (pl.cr ? .6 : 1), pl.z), d = e.distanceTo(pp);
    if (d > 14) return false; if (!(pl.l || GAME.litAt(pp)) && d > 5) return false;
    return WORLD.coll.los(e, pp, losF);
  }
  const floorish = h => (h > -.05 && h <= .3) || (h > F2 - .05 && h <= F2 + .3);
  // может ли он добраться до ног игрока: от опоры игрока вниз шагами ≤ 0.36 м до пола (ступени лестницы — да, стол/кровать — нет)
  function reachable(pl) {
    const C = WORLD.coll, h0 = C.groundAt(pl.x, pl.z, .3, pl.y + .05);
    if (h0 < -40 || floorish(h0)) return true;
    for (let k = 0; k < 8; k++) {
      const a = k * PI / 4, dx = Math.sin(a), dz = Math.cos(a); let cur = h0;
      for (let s = .2; s <= 3.4; s += .2) { const g = C.groundAt(pl.x + dx * s, pl.z + dz * s, .1, cur + .05); if (g < cur - .36) break; cur = g; if (floorish(cur)) return true; }
    }
    return false;
  }
  function reachC(G, pl) { const c = G.rc[pl.id]; if (c && c.t > G.t && Math.abs(c.x - pl.x) + Math.abs(c.y - pl.y) + Math.abs(c.z - pl.z) < .15) return c.v; const v = reachable(pl); G.rc[pl.id] = { t: G.t + .3, x: pl.x, y: pl.y, z: pl.z, v }; return v; }
  function kill(m) {
    for (const pl of GAME.alivePlayers()) { if (pl.hid) continue; const d = Math.hypot(pl.x - m.p.x, pl.z - m.p.z), dy = pl.y - m.p.y; if (d < REACH && dy < HIGH && dy > -.9) GAME.killPlayer(pl.id, m); }
  }
  function watchdog(m, dt, G) {
    const W = G.wd; W.mv += m.speedNow > 0 ? dt : 0; W.t += dt; if (W.t < 3) return;
    const d = Math.hypot(m.p.x - W.x, m.p.z - W.z);
    if (W.mv > 1.5 && d < .3) { m.path = []; W.n++; if (W.n >= 3) { const k = fixNode(m.nodeNear(m.p)); if (k) m.p.copy(WORLD.nav[k].p); W.n = 0; } } else if (d >= .3) W.n = 0;
    W.t = 0; W.mv = 0; W.x = m.p.x; W.z = m.p.z;
  }

  /* ---------- модель ---------- */
  const GC = {};
  function merged(parts) { // склейка коробок в одну геометрию (меньше мешей): {w,h,d,x,y,z,q|rx,ry,rz,c}
    const pos = [], nor = [], col = [], m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(), one = new V3(1, 1, 1), cc = new THREE.Color();
    for (const p of parts) {
      const g = new THREE.BoxGeometry(p.w, p.h, p.d).toNonIndexed();
      if (p.q) q.copy(p.q); else q.setFromEuler(e.set(p.rx || 0, p.ry || 0, p.rz || 0));
      g.applyMatrix4(m4.compose(new V3(p.x, p.y, p.z), q, one));
      const a = g.attributes.position.array, n = g.attributes.normal.array; for (let i = 0; i < a.length; i++) { pos.push(a[i]); nor.push(n[i]); }
      if (p.c) { cc.set(p.c); for (let i = 0; i < a.length / 3; i++) col.push(cc.r, cc.g, cc.b); }
      g.dispose();
    }
    const out = new THREE.BufferGeometry(); out.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); out.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3));
    if (col.length) out.setAttribute('color', new THREE.Float32BufferAttribute(col, 3)); return out;
  }
  function stick(A, B, t) { const d = new V3().subVectors(B, A), L = d.length(); return { w: t, h: L, d: t, x: (A.x + B.x) / 2, y: (A.y + B.y) / 2, z: (A.z + B.z) / 2, q: new THREE.Quaternion().setFromUnitVectors(new V3(0, 1, 0), d.normalize()) }; }
  function segDims(i) { const w = [.34, .4, .44, .45, .45, .44, .42, .37, .3, .22][i]; return { w, h: w * .76, cy: .1 + w * .38 }; }
  function segGeo(i) { // тело сегмента: синюшно-фиолетовое, с тёмной спинной пластиной и желтоватыми «синяками» по бокам
    const k = 'seg' + i; if (GC[k]) return GC[k];
    const { w, h, cy } = segDims(i), base = i % 2 ? '#6a3570' : '#5a2c63';
    const P = [{ w, h, d: .27, x: 0, y: cy, z: 0, c: base }, { w: w * .64, h: .05, d: .21, x: 0, y: cy + h / 2 + .02, z: 0, c: '#381a42' }, { w: w * .86, h: .04, d: .23, x: 0, y: cy - h / 2 - .01, z: 0, c: '#4a2244' }];
    for (const s of [-1, 1]) P.push({ w: .03, h: h * .42, d: .1, x: s * (w / 2 + .012), y: cy + .01, z: (i % 3 - 1) * .04, c: i % 2 ? '#8f8a46' : '#7c5a7e' });
    if (i > 0 && i < 8 && i % 2) P.push({ w: .08, h: .06, d: .08, x: (i % 4 - 2) * .05, y: cy + h / 2 + .06, z: .02, c: '#9a6a8a' });   // нарыв
    return (GC[k] = merged(P));
  }
  function legGeo(i, s) { // две ноги одной стороны сегмента, начало координат — у бедра
    const k = 'leg' + i + s; if (GC[k]) return GC[k];
    const { cy } = segDims(i), P = [];
    for (const dz of [-.075, .075]) { const A = new V3(0, 0, dz), K = new V3(s * .14, .09, dz * 1.25), F = new V3(s * .27, -cy + .015, dz * 1.6 + .02); P.push(stick(A, K, .022), stick(K, F, .016)); }
    return (GC[k] = merged(P));
  }
  function mats() { if (!GC.mBody) { GC.mBody = new THREE.MeshLambertMaterial({ vertexColors: true }); GC.mLeg = mat('#120e14'); } return GC; }

  /* ---------- звук (у всех клиентов) ---------- */
  function clicks(pos, n, v) { const out = AU.at(pos), t = AU.t(); for (let i = 0; i < n; i++) { const tt = t + i * (.016 + Math.random() * .03); AU.nz(out, tt, .01 + Math.random() * .012, v * (.6 + Math.random() * .6), 'bandpass', 2600 + Math.random() * 3600, 3, .001); } }
  function rustle(pos, v) { AU.nz(AU.at(pos), AU.t(), .2, v, 'bandpass', 420 + Math.random() * 300, 1.2, .05); }
  function hiss(pos) { // влажное шипение + низкое бульканье
    const c = AU.ctx, t = AU.t(), out = AU.at(pos); AU.nz(out, t, 1.1, .07, 'bandpass', 3200, 2.5, .35);
    const f = c.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 240; f.connect(AU.env(out, t, .12, .2, .9));
    const o = AU.osc('sawtooth', 62, t, t + 1.2, f); o.frequency.linearRampToValueAtTime(48, t + 1.1);
  }
  function squeal(pos) { const t = AU.t(), out = AU.at(pos), o = AU.osc('sawtooth', 720, t, t + .5, AU.env(out, t, .045, .02, .45)); o.frequency.linearRampToValueAtTime(1150, t + .15); o.frequency.linearRampToValueAtTime(520, t + .48); clicks(pos, 6, .08); }

  INMATES.def({
    key: 'giftcrawler', num: '305', name: 'ЯДОВИТЫЙ ПОЛЗУН', en: 'GIFTCRAWLER', cls: 'ПАРАЗИТИЧЕСКИЙ ХИЩНИК',
    hp: 300, speed: V_ROAM, chase: V_CHASE, color: '#6a3570', difficulty: 1, minNight: 1, eye: .47, canHear: true,
    alert: [
      'ПАРАЗИТИЧЕСКИЙ ХИЩНИК, ОБОЗНАЧЕННЫЙ КАК ЗАКЛЮЧЁННЫЙ 305, ЗАМЕЧЕН В ВАШЕМ РАЙОНЕ. ЭТО ПОЛЗУЧЕЕ СУЩЕСТВО ПЕРЕДВИГАЕТСЯ ПО ПОЛУ И ПРЯЧЕТСЯ ПОД МЕБЕЛЬЮ.',
      'СУБЪЕКТ НЕ ОТРЫВАЕТСЯ ОТ ПОЛА. ПОСЛЕ КОНТАКТА ЗАРАЖЕНИЕ НАСТУПАЕТ МГНОВЕННО И НЕОБРАТИМО.',
      'ЕСЛИ ВЫ СЛЫШИТЕ ШОРОХ, ЦОКОТ ИЛИ ДВИЖЕНИЕ У САМОГО ПОЛА — НЕ ПРИБЛИЖАЙТЕСЬ.',
    ],
    tip: 'Не подходи на цокот у пола. Залезь повыше — кровать, стол, стул: он не достанет и будет ждать внизу. Капкан его держит.',
    model() {
      const M = mats(), g = new THREE.Group(), head = new THREE.Group(), segs = [];
      g.add(head); g.userData.gc = { head, segs };
      // голова: бледная лысая человеческая, широко раскрытые глаза; чуть задрана вверх — смотрит на тебя снизу
      const skin = '#e2d3c6', hd = new THREE.Group(); hd.position.set(0, .2, 0); hd.rotation.x = -.22; head.add(hd);
      MM.box(head, .18, .16, .3, '#a07892', 0, .22, -.17, { rx: .3 });          // шея уходит в тело
      MM.box(hd, .33, .35, .32, skin, 0, .2, .02); MM.box(hd, .27, .06, .27, skin, 0, .4, .02); MM.box(hd, .26, .06, .2, '#d8c6b8', 0, .01, .02);
      for (const s of [-1, 1]) {
        MM.box(hd, .14, .12, .02, '#7c4a5c', s * .078, .24, .181);                 // тёмные веки-синяки
        MM.sph(hd, .066, '#f7f3ea', s * .078, .24, .168, { sz: .55, seg: 10, seg2: 8 });
        MM.sph(hd, .022, '#140a08', s * .078 + s * .006, .245, .203, { seg: 8, seg2: 6 });
        MM.box(hd, .035, .09, .07, '#d4beb2', s * .18, .21, .01);                   // уши
        MM.box(hd, .012, .14, .012, '#7a4a8a', s * .11, .35, .13, { rz: s * .5 });  // вздувшиеся вены
      }
      MM.box(hd, .05, .075, .05, '#d3bcaf', 0, .165, .195);
      MM.box(hd, .15, .055, .02, '#3a0a12', 0, .085, .182); MM.box(hd, .13, .018, .022, '#a8707a', 0, .056, .182);
      // сегменты тела с ногами
      for (let i = 0; i < NSEG; i++) {
        const sg = new THREE.Group(); sg.rotation.order = 'YXZ'; sg.position.set(0, 0, -(SEG0 + i * SEGD)); g.add(sg);
        sg.add(new THREE.Mesh(segGeo(i), M.mBody)); const S = { g: sg };
        if (i < NSEG - 1) { const { w, cy } = segDims(i); for (const s of [-1, 1]) { const l = new THREE.Mesh(legGeo(i, s), M.mLeg); l.position.set(s * w * .45, cy, 0); sg.add(l); S[s < 0 ? 'L' : 'R'] = l; } }
        segs.push(S);
      }
      return g;
    },
    init(m) { m.fixY = fixY; m.gcC = { tr: [], a: m.a, v: 0, lp: m.p.clone(), ph: 0, rr: 0, kt: .2, rt: 0, ht: 1, hb: 0, A: new V3(), F: new V3(), B: new V3() }; },
    cleanup(m) { if (m.gcC) m.gcC.tr.length = 0; },
    tick(m, dt) {
      const G = m.gc || (m.gc = { t: 0, rt: 0, tid: null, last: null, lost: 0, wait: 0, ign: {}, pause: 0, rc: {}, wd: { t: 0, x: m.p.x, z: m.p.z, n: 0, mv: 0 } });
      m.speedNow = 0; G.t += dt; G.rt -= dt;
      if (m.stun > 0) { m.stun -= dt; m.a = 2; if (m.state !== 'pinned') { m.state = 'pinned'; m.path = []; } return; }   // капкан/шокер
      if (m.state === 'pinned') { m.state = 'roam'; m.path = []; }
      if (m.state === 'enter') { m.a = 0; if (!m.path.length && m.entry) goSafe(m, m.nodeNear(m.entry.in)); if (m.follow(dt, spd(m, V_ROAM))) { m.state = 'roam'; m.path = []; } kill(m); return; }
      // ---- кого чувствует: вибрация рядом, шаги, взгляд с пола ----
      let tgt = null;
      for (const pl of GAME.alivePlayers()) {
        if (pl.hid || (G.ign[pl.id] || 0) > G.t) continue;
        const d = m.p.distanceTo(new V3(pl.x, pl.y, pl.z));
        if (!(d < 3.5 || m.hears(pl) || sees(m, pl))) continue;
        const sc = d - (pl.id === G.tid ? 2.5 : 0); if (!tgt || sc < tgt.sc) tgt = { pl, d, sc };
      }
      if (tgt) { if (tgt.pl.id !== G.tid) G.wait = 0; G.tid = tgt.pl.id; G.last = new V3(tgt.pl.x, tgt.pl.y, tgt.pl.z); G.lost = 0; }
      else if (G.tid) { G.lost += dt; if (G.lost > 6 || !GAME.alivePlayers().some(q => q.id === G.tid && !q.hid)) G.tid = null; }
      if (tgt) {
        const pl = tgt.pl;
        if (reachC(G, pl)) { m.state = 'chase'; m.a = 1; G.wait = Math.max(0, G.wait - dt); go(m, new V3(pl.x, pl.y, pl.z), dt, V_CHASE, G); }
        else { // высоко: подползти к краю и ждать внизу
          const at = approach(m, pl, dt, G), dh = Math.hypot(pl.x - m.p.x, pl.z - m.p.z);
          if (at) { m.state = 'wait'; m.a = 3; m.yaw = Math.atan2(pl.x - m.p.x, pl.z - m.p.z); m.path = []; } else { m.state = 'stalk'; m.a = 1; }
          if (dh < 2.2) G.wait += dt;
          if (G.wait > WAIT_MAX) { // надоело — уходит подальше
            G.ign[pl.id] = G.t + IGNORE_T; G.tid = null; G.wait = 0; m.state = 'roam'; m.a = 0;
            const far = rooms().filter(n => n.p.distanceTo(m.p) > 7); goSafe(m, pick(far.length ? far : rooms()).id);
          }
        }
      } else if (G.tid && G.last) { m.state = 'search'; m.a = 0; if (!m.path.length) goSafe(m, m.nodeNear(G.last)); if (m.follow(dt, spd(m, V_ROAM * 1.25))) { G.tid = null; G.pause = 1.5; m.path = []; } }
      else { // бродит, иногда замирает под мебелью
        m.state = 'roam';
        if (G.pause > 0) { G.pause -= dt; m.a = 4; }
        else { m.a = 0; if (!m.path.length) goSafe(m, pick(rooms()).id); if (m.follow(dt, spd(m, V_ROAM)) || !m.path.length) G.pause = Math.random() < .6 ? .8 + Math.random() * 2.5 : 0; }
      }
      kill(m); watchdog(m, dt, G);
    },
    anim(m, dt, moving) {
      const U = m.model.userData.gc, C = m.gcC, P = m.p, yaw = m.yaw, t = m.t, a = m.a;
      const sp = P.distanceTo(C.lp) / Math.max(dt, 1e-3); C.lp.copy(P); C.v = damp(C.v, Math.min(sp, 8), 8, dt);
      // след головы — по нему укладываются сегменты (тело огибает углы, а не торчит сквозь стены)
      const tr = C.tr, l0 = tr[0];
      if (!l0 || Math.hypot(P.x - l0.x, P.z - l0.z) > 2.5 || Math.abs(P.y - l0.y) > 2.5) { tr.length = 0; tr.push({ x: P.x, y: P.y, z: P.z }); }
      else if (Math.hypot(P.x - l0.x, P.y - l0.y, P.z - l0.z) > .06) { tr.unshift({ x: P.x, y: P.y, z: P.z }); if (tr.length > 90) tr.pop(); }
      const sample = (s, out) => {
        let acc = 0, pv = P, px = 0, pz = 0;
        for (const q of tr) { const L = Math.hypot(q.x - pv.x, q.y - pv.y, q.z - pv.z); if (L > 1e-5) { if (acc + L >= s) { const k = (s - acc) / L; return out.set(pv.x + (q.x - pv.x) * k, pv.y + (q.y - pv.y) * k, pv.z + (q.z - pv.z) * k); } const hl = Math.hypot(q.x - pv.x, q.z - pv.z) || 1; px = (q.x - pv.x) / hl; pz = (q.z - pv.z) / hl; acc += L; pv = q; } }
        if (!px && !pz) { px = -Math.sin(yaw); pz = -Math.cos(yaw); }
        return out.set(pv.x + px * (s - acc), pv.y, pv.z + pz * (s - acc));
      };
      const cy = Math.cos(yaw), sy = Math.sin(yaw), amp = clamp(C.v / 2, 0, 1);
      C.ph += dt * (2 + C.v * 7); C.rr = damp(C.rr, a === 3 ? 1 : 0, 5, dt);
      const rear = [.26, .13, .04], rearP = [.55, .35, .12];
      for (let i = 0; i < NSEG; i++) {
        const S = U.segs[i], s = SEG0 + i * SEGD, A = sample(s, C.A), F = sample(Math.max(0, s - .14), C.F), B = sample(s + .14, C.B);
        const dx = A.x - P.x, dz = A.z - P.z, fx = F.x - B.x, fy = F.y - B.y, fz = F.z - B.z, fh = Math.hypot(fx, fz);
        S.g.position.set(dx * cy - dz * sy, A.y - P.y + Math.sin(C.ph * .5 + i * .8) * .015 * amp + (i < 3 ? rear[i] * C.rr : 0), dx * sy + dz * cy);
        S.g.rotation.set((fh > 1e-4 ? -Math.atan2(fy, fh) : 0) - (i < 3 ? rearP[i] * C.rr : 0), fh > 1e-4 ? Math.atan2(fx, fz) - yaw : 0, 0);
        if (a === 2) S.g.position.x += Math.sin(t * 22 + i * 1.3) * .05;
        if (S.L) { const f = C.ph + i * .9, k = .1 + amp * .45; S.L.rotation.x = Math.sin(f) * k; S.R.rotation.x = Math.sin(f + PI) * k; S.L.rotation.z = -Math.max(0, Math.cos(f)) * .3 * amp; S.R.rotation.z = Math.max(0, Math.cos(f + PI)) * .3 * amp; }
      }
      const h = U.head; h.position.y = C.rr * .36 + (a === 1 ? Math.sin(C.ph) * .02 : 0);
      h.rotation.set(-C.rr * .65, a === 2 ? Math.sin(t * 28) * .35 : 0, Math.sin(t * 1.7) * .1 + (a === 3 ? Math.sin(t * 3.1) * .15 : 0));
    },
    sound(m, dt) {
      if (!AU.ctx) return;
      const C = m.gcC, pos = new V3(m.p.x, m.p.y + .2, m.p.z);
      let ld = 1e9; for (const lp of LOCALS) ld = Math.min(ld, lp.cam.position.distanceTo(pos));
      if (m.a !== C.a) { if (m.a === 2) squeal(pos); if (m.a === 3) { hiss(pos); C.ht = 2.5; } C.a = m.a; }
      if (ld > 32 || m.vis === 0 || m.p.y < -50) return;
      const mv = C.v > .25; C.kt -= dt;
      if (C.kt <= 0) { if (mv) { clicks(pos, C.v > 3 ? 5 : 3, .09); C.kt = (C.v > 3 ? .07 : .11) * (.7 + Math.random() * .6); } else { if (Math.random() < .5) clicks(pos, 1 + ((Math.random() * 3) | 0), .05); C.kt = .25 + Math.random() * .8; } }
      if (mv) { C.rt -= dt; if (C.rt <= 0) { rustle(pos, .05); C.rt = .22; } }
      if (m.a === 3 || m.a === 2) { C.ht -= dt; if (C.ht <= 0) { if (m.a === 3) { hiss(pos); C.ht = 2.2 + Math.random() * 1.5; } else { squeal(pos); C.ht = 1 + Math.random(); } } }
      // «не приближайтесь»: стук сердца, когда он в 4.5 м от тебя
      C.hb -= dt;
      if (C.hb <= 0) for (const lp of LOCALS) { if (!lp.alive) continue; const b = lp.body.p; if (Math.hypot(b.x - m.p.x, b.z - m.p.z) < 4.5 && Math.abs(b.y - m.p.y) < 2) { AU.play('heart'); C.hb = .95; break; } }
    },
  });
})();
