/* ================= ЗАКЛЮЧЁННЫЙ 460: МАРИОНЕТКА ДЖОРДЖ (GEORGE THE PUPPET; у нас — «Мистер Терпение») ================= */
// Деревянная марионетка в человеческий рост: тесный коричневый костюм, красный галстук, нарисованная улыбка,
// обрезанные нити на запястьях. Сухо щёлкает суставами (позиционный синтез у всех клиентов).
// Ночью охотится как обычный заключённый (обход 2.8, погоня 4.8 — от бегущего можно уйти кругами по дому).
// ТЕРПЕНИЕ: если кто-то сидит в укрытии дольше 2.5 с (или спрятался у него на глазах), он неспешно идёт к этому
// шкафу, встаёт перед дверцей и поправляет галстук (a=3), через ~1.3 с стучит. Через 8 с — рывок дверцы (a=4):
// GAME.toggleHide выталкивает игрока, и марионетка хватает его, если он ещё рядом (a=1, ~1.2 с, только по контакту).
// Приманка: если видимый игрок окажется у него на виду ближе 6 м — бросает шкаф и гонится (кооп-контрплей).
// m.a: 0 — ходит, 1 — погоня/хватает, 2 — оглушён (обмяк, как кукла с обрезанными нитями), 3 — поправляет галстук, 4 — рвёт дверцу.
(() => {
  const SPEED = 2.8, CHASE = 4.8, NOTICE = 2.5, VIGIL = 8, YANK = .6, GRAB = 1.2, STAND = 1.3, LURE = 6;
  const losF = b => !b.door || !(WS[b.door] && (WS[b.door].o || WS[b.door].b));
  const hd = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);

  /* ---------- навигация (хост): обходы багов общего графа ---------- */
  // узлы окон wi_*/wo_* связаны сами с собой (тупики) — цель-окно заменяем ближайшим обычным узлом той же стороны
  function fixNode(k) {
    const N = WORLD.nav, n = N && N[k]; if (!n || !n.win) return k; let best = null, bd = 1e9;
    for (const q in N) { const o = N[q]; if (o.win || (o.room === 'out') !== (n.room === 'out') || Math.abs(o.p.y - n.p.y) > 1) continue; const d = o.p.distanceTo(n.p); if (d < bd) { bd = d; best = q; } }
    return best || k;
  }
  // пол под ногами: круг пошире (перешагивает щель между верхней ступенькой и полом 2 этажа), ступень не выше 0.36 м
  function fixY(hint) { const g = WORLD.coll.groundAt(this.p.x, this.p.z, .4, this.p.y + .36); this.p.y = g > -40 ? g : hint; }
  function patchNav(m) {
    m.fixY = fixY;
    m.goNode = function (node) {
      if (this.state !== 'enter') node = fixNode(node);
      Inmate.prototype.goNode.call(this, node);
      if (this.path.length || !node || this.state === 'enter') return;
      const from = this.nodeNear(this.p), n = from && WORLD.nav[from];     // стоит на тупиковом узле окна — сначала к обычному узлу
      if (n && n.win && from !== node) { const alt = fixNode(from); if (alt !== from) this.path = [{ node: alt }]; }
    };
  }
  function enter(m) {
    const ents = HOUSE.entries, e = Math.random() < .5 ? ents[0] : pick(ents); m.entry = e; m.p.copy(e.out); m.state = 'enter';
    if (e.kind === 'window' && WORLD.nav['wi_' + e.id]) { const a = 'wi_' + e.id; m.path = [{ node: 'wo_' + e.id }, { node: a, via: 'win:' + e.id }, { node: fixNode(a) }]; }
    else m.goNode(m.nodeNear(e.in));
  }
  // сторож: «идёт», но 3 с не сдвинулся — сбросить путь; после трёх раз — встать на ближайший узел (не во время взлома двери/окна)
  function watchdog(m, dt) {
    const W = m.mem.wd || (m.mem.wd = { t: 0, x: m.p.x, z: m.p.z, n: 0 }); W.t += dt; if (W.t < 3) return;
    const moved = Math.hypot(m.p.x - W.x, m.p.z - W.z), wants = (m.path.length > 0 && !m.path[0].via) || m.mem.g === 'stalk';
    if (wants && moved < .3 && m.stun <= 0 && m.state !== 'enter') { m.path = []; if (++W.n >= 3) { const k = m.nodeNear(m.p); if (k) m.p.copy(WORLD.nav[fixNode(k)].p); W.n = 0; } }
    else if (moved >= .3) W.n = 0;
    W.t = 0; W.x = m.p.x; W.z = m.p.z;
  }

  /* ---------- укрытия: где у шкафа «перед» (у некоторых hideSpot.yaw/out смотрят в стену — считаем сами) ---------- */
  const FRONT = new WeakMap();
  function hideFront(h) {
    let f = FRONT.get(h); if (f) return f;
    const ry = h.mesh && h.mesh.parent ? h.mesh.parent.rotation.y : 0, ax = new V3(Math.sin(ry), 0, Math.cos(ry));
    const room = GAME.roomAt(h.pos.clone().setY(h.pos.y + 1));
    const ok = s => { const q = h.pos.clone().addScaledVector(ax, s); return GAME.roomAt(q.clone().setY(q.y + 1)) === room && !WORLD.coll.blocked(q.x, h.pos.y, q.z, .2, 1.6, .4); };
    let s; const a = ok(1), b = ok(-1);
    if (a !== b) s = a ? 1 : -1; else s = h.out.clone().sub(h.pos).dot(ax) >= 0 ? 1 : -1;
    f = ax.multiplyScalar(s); FRONT.set(h, f); return f;
  }
  function standPt(h) {
    const f = hideFront(h);
    for (const d of [STAND, 1.15, 1.5, 1]) { const q = h.pos.clone().addScaledVector(f, d); if (!WORLD.coll.blocked(q.x, h.pos.y, q.z, .25, 1.6, .4)) return q; }
    return h.pos.clone().addScaledVector(f, STAND);
  }

  /* ---------- ИИ (хост) ---------- */
  function spot(m, maxD) { let best = null; for (const pl of GAME.alivePlayers()) if (m.canSee(pl, maxD)) { const d = hd(m.p, pl); if (!best || d < best.d) best = { pl, d }; } return best; }
  function chase(m, s) { m.state = 'chase'; m.chaseId = s.pl.id; m.lastSeen = new V3(s.pl.x, s.pl.y, s.pl.z); m.lostT = 0; m.path = []; }
  function startStalk(m, o) { const mem = m.mem; mem.g = 'stalk'; mem.h = o.h; mem.pid = o.pid; mem.stand = standPt(o.h); mem.vt = 0; mem.knock = 0; mem.rt = 0; m.state = 'stalk'; m.path = []; m.goNode(m.nodeNear(mem.stand)); }
  function endPatience(m) { const mem = m.mem; mem.g = null; mem.h = null; m.state = 'roam'; m.path = []; }

  function think(m, dt) {
    const mem = m.mem; watchdog(m, dt);
    // кто сидит в укрытиях и как долго
    const hid = [], HT = mem.hidT || (mem.hidT = {});
    for (const h of WORLD.hides) { const by = WS[h.id] && WS[h.id].by, P = by && GAME.players[by]; if (P && P.alive) { hid.push({ h, pid: by }); HT[by] = (HT[by] || 0) + dt; } }
    for (const pid in HT) if (!hid.some(o => o.pid === pid)) delete HT[pid];
    if (m.stun > 0) { m.stun -= dt; m.speedNow = 0; m.a = 2; return; }
    if (mem.g) { patience(m, dt); return; }
    if (m.state !== 'enter') {
      const seenHide = m.state === 'chase' && hid.find(o => o.pid === m.chaseId);        // спрятался у него на глазах
      const cand = seenHide ? [seenHide] : hid.filter(o => HT[o.pid] >= NOTICE);
      if (cand.length && (seenHide || !(m.state === 'chase' && spot(m, 22)))) {
        const cost = h => hd(m.p, h.pos) + Math.abs(m.p.y - h.pos.y) * 4;
        cand.sort((a, b) => cost(a.h) - cost(b.h)); startStalk(m, cand[0]); patience(m, dt); return;
      }
    }
    m.hunt(dt);
  }
  function patience(m, dt) {
    const mem = m.mem, h = mem.h, occ = WS[h.id] && WS[h.id].by, P = GAME.players[mem.pid];
    if (mem.g === 'stalk' || mem.g === 'vigil') {
      if (occ !== mem.pid || !P || !P.alive) { endPatience(m); m.hunt(dt); return; }    // вышел сам (прямо к нему в руки) или погиб
      const s = spot(m, LURE); if (s) { endPatience(m); chase(m, s); m.hunt(dt); return; }   // приманка: видимый игрок рядом
    }
    if (mem.g === 'stalk') {
      m.a = 0; const S = mem.stand;
      if (m.path.length) m.follow(dt, SPEED);
      else if (Math.abs(m.p.y - S.y) < 1.2 && (hd(m.p, S) < 3.5 || WORLD.coll.los(m.p.clone().setY(m.p.y + 1), S.clone().setY(S.y + 1), losF))) { if (m.stepTo(S, dt, SPEED)) { mem.g = 'vigil'; m.state = 'vigil'; mem.vt = 0; } }
      else if ((mem.rt += dt) > 1) { mem.rt = 0; m.goNode(m.nodeNear(S)); }
      m.tryKill(1.1); return;
    }
    if (mem.g === 'vigil') {
      m.a = 3; m.speedNow = 0; m.yaw = Math.atan2(h.pos.x - m.p.x, h.pos.z - m.p.z); mem.vt += dt;
      if (!mem.knock && mem.vt > 1.3) { mem.knock = 1; GAME.fxAll('knock', h.eye, { n: 3 }); }
      if (mem.vt >= VIGIL) { mem.g = 'yank'; m.state = 'yank'; mem.vt = 0; }
      m.tryKill(1.1); return;
    }
    if (mem.g === 'yank') {
      m.a = 4; m.speedNow = 0; mem.vt += dt;
      if (mem.vt >= YANK) {
        if (occ === mem.pid) { GAME.toggleHide(mem.pid, h); GAME.fxAll('bang', h.eye); GAME.fxAll('doorOpen', h.eye); CAMSHAKE(h.eye, .8); }
        mem.g = 'grab'; m.state = 'grab'; mem.vt = 0;
      }
      return;
    }
    // хватает вытолкнутого (только при контакте)
    m.a = 1; mem.vt += dt; let pp = null;
    if (P && P.alive && !P.pose.hid) {
      pp = new V3(P.pose.x, P.pose.y, P.pose.z);
      if (hd(m.p, pp) < 3.2 && Math.abs(pp.y - m.p.y) < 1.2 && WORLD.coll.los(m.headPos(), pp.clone().setY(pp.y + 1.2), losF)) m.stepTo(pp, dt, CHASE * 1.15); else m.speedNow = 0;
    }
    m.tryKill(1.2);
    if (mem.vt >= GRAB || !P || !P.alive) { endPatience(m); if (pp && P.alive) { m.state = 'chase'; m.chaseId = mem.pid; m.lastSeen = pp; m.lostT = 0; } }
  }

  /* ---------- звук (у всех клиентов) ---------- */
  function clack(pos, v, n = 2) {    // сухой стук деревянного сустава
    const t = AU.t(), out = AU.at(pos);
    for (let i = 0; i < n; i++) {
      const tt = t + i * (.06 + Math.random() * .03), f = (i ? 760 : 1120) + Math.random() * 260;
      AU.osc('sine', f, tt, tt + .06, AU.env(out, tt, v, .001, .045)); AU.osc('triangle', f * 2.63, tt, tt + .03, AU.env(out, tt, v * .3, .001, .02));
      AU.nz(out, tt, .02, v * .7, 'bandpass', 2600, 2.5, .001);
    }
  }
  function creak(pos, v) {             // скрип дерева
    const A = AU.ctx, t = AU.t(), out = AU.at(pos), f = A.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 1100; f.Q.value = 7; f.connect(AU.env(out, t, v, .08, .55));
    const o = AU.osc('sawtooth', 62 + Math.random() * 20, t, t + .75, f); o.frequency.linearRampToValueAtTime(105 + Math.random() * 30, t + .65);
  }
  function rustle(pos, v) { const t = AU.t(), out = AU.at(pos); AU.nz(out, t, .28, v, 'highpass', 2800, .7, .06); AU.nz(out, t + .3, .12, v * .6, 'highpass', 3400, .7, .02); }
  function clatter(pos) { const t = AU.t(); for (let i = 0; i < 6; i++) { const p = pos.clone(); p.y -= i * .25; const tt = t + i * .07 + Math.random() * .04, out = AU.at(p); AU.osc('sine', 600 + Math.random() * 700, tt, tt + .05, AU.env(out, tt, .14, .001, .04)); AU.nz(out, tt, .02, .1, 'bandpass', 2200, 2, .001); } }

  /* ---------- нити всегда висят вниз: локальный поворот = (поворот родителей)^-1 · (рыскание + покачивание) ---------- */
  const _q = new THREE.Quaternion(), _q2 = new THREE.Quaternion(), _e = new THREE.Euler();
  function hangStrings(p, M, t = 0) {
    for (const [A, F, S, k] of [[p.la, p.lf, p.sl, 0], [p.ra, p.rf, p.sr, 2]]) {
      _q.copy(M.quaternion).multiply(A.quaternion).multiply(F.quaternion).invert();
      _e.set(Math.sin(t * 2.3 + k) * .1, M.rotation.y, Math.sin(t * 1.7 + k) * .06); _q2.setFromEuler(_e);
      S.quaternion.copy(_q.multiply(_q2));
    }
  }
  /* ---------- модель ---------- */
  function model() {
    const g = new THREE.Group(), p = { g }; g.userData.parts = p;
    const wood = '#d4a46c', woodD = '#a8774a', jawC = '#c8955e', suit = '#6b4426', suitD = '#4e2f1a', shirt = '#ece6d6', tie = '#b3121e', shoe = '#17110c', hair = '#3a2212', ink = '#121010', red = '#a8161c', str = '#d8d4c8';
    const piv = (par, x, y, z) => { const q = new THREE.Group(); q.position.set(x, y, z); par.add(q); return q; };
    const H = .95;
    // ноги: короткие брюки, деревянные щиколотки-шпеньки, крашеные башмаки
    p.ll = piv(g, -.12, H, 0); p.rl = piv(g, .12, H, 0);
    for (const L of [p.ll, p.rl]) { MM.box(L, .19, .66, .21, suit, 0, -.33, 0); MM.cyl(L, .05, .056, .22, wood, 0, -.76, 0, { seg: 8 }); MM.box(L, .16, .1, .3, shoe, 0, -.9, .05); }
    // таз, торчащая рубашка, тесный пиджак
    MM.box(g, .42, .12, .23, suitD, 0, H + .02, 0); MM.box(g, .4, .07, .22, shirt, 0, H + .11, 0);
    p.torso = MM.box(g, .44, .46, .26, suit, 0, H + .37, 0);
    MM.box(g, .13, .28, .01, shirt, 0, H + .46, .131);
    for (const s of [-1, 1]) { MM.box(g, .075, .27, .012, suitD, s * .078, H + .47, .135, { rz: -s * .22 }); MM.box(g, .09, .05, .03, shirt, s * .055, H + .61, .12, { rz: s * .45 }); }
    MM.sph(g, .022, '#c8a040', .075, H + .27, .135, { seg: 6, seg2: 4 });
    // красный галстук (отдельная группа — его поправляют)
    p.tie = piv(g, 0, H + .58, .142); MM.box(p.tie, .075, .06, .035, tie, 0, 0, 0); MM.box(p.tie, .064, .4, .014, tie, 0, -.22, 0); MM.box(p.tie, .046, .046, .014, tie, 0, -.42, 0, { rz: PI / 4 });
    // руки: короткие рукава, деревянные предплечья, шарниры, обрезанные нити на запястьях
    p.la = piv(g, -.29, H + .55, 0); p.ra = piv(g, .29, H + .55, 0);
    for (const [A, s] of [[p.la, -1], [p.ra, 1]]) {
      MM.box(A, .15, .4, .16, suit, 0, -.19, 0);
      const F = piv(A, 0, -.41, 0); MM.box(F, .13, .045, .14, shirt, 0, 0, 0);                           // локоть: манжета торчит из короткого рукава
      MM.box(F, .095, .2, .095, wood, 0, -.12, 0); MM.sph(F, .056, woodD, 0, -.24, 0, { seg: 8, seg2: 6 }); MM.box(F, .1, .15, .065, wood, 0, -.355, .01);
      const st = piv(F, 0, -.25, -.045); MM.cyl(st, .006, .006, .52, str, 0, -.26, 0, { seg: 4 }); MM.box(st, .022, .035, .022, '#b0a894', 0, -.53, 0);
      if (s < 0) { p.lf = F; p.sl = st; } else { p.rf = F; p.sr = st; }
    }
    // шея-шпенёк и голова с нарисованным лицом, челюсть щелкунчика
    MM.cyl(g, .055, .065, .12, wood, 0, H + .64, 0, { seg: 8 });
    p.head = piv(g, 0, H + .68, 0); p.headH = H + .68;
    MM.box(p.head, .4, .36, .38, wood, 0, .27, 0);
    p.jaw = piv(p.head, 0, .1, -.08); MM.box(p.jaw, .34, .1, .34, jawC, 0, -.055, .09);
    MM.box(p.head, .42, .11, .4, hair, 0, .47, -.005); MM.box(p.head, .42, .07, .05, hair, 0, .41, .175); MM.box(p.head, .015, .012, .3, '#7a5232', .09, .527, .02);
    for (const s of [-1, 1]) {
      MM.cyl(p.head, .056, .056, .01, '#f6f2e8', s * .088, .3, .19, { rx: PI / 2, seg: 14 });       // нарисованные глаза навыкате
      MM.cyl(p.head, .022, .022, .01, ink, s * .088, .296, .197, { rx: PI / 2, seg: 10 });
      MM.box(p.head, .085, .014, .01, ink, s * .09, .374, .193, { rz: s * .16 });                  // брови дугой
      MM.cyl(p.head, .038, .038, .008, '#d4505a', s * .14, .19, .191, { rx: PI / 2, seg: 10 });   // румяна
      MM.box(p.head, .06, .024, .01, red, s * .105, .15, .192, { rz: s * .55 });                   // уголки улыбки
      MM.box(p.head, .012, .07, .01, ink, s * .135, .12, .193);                                     // прорези челюсти
      MM.box(p.jaw, .012, .085, .01, ink, s * .135, -.05, .182);
    }
    MM.box(p.head, .17, .026, .01, red, 0, .125, .192); MM.box(p.head, .05, .075, .05, '#c08a52', 0, .225, .205);
    MM.sph(p.head, .02, '#9a9a9a', 0, .535, 0, { seg: 6, seg2: 4 }); MM.cyl(p.head, .004, .004, .3, str, .02, .68, 0, { rz: .15, seg: 4 });
    // поза по умолчанию (лобби/скример): руки чуть приподняты, будто держат нити, голова набок
    p.la.rotation.set(-.3, 0, -.22); p.ra.rotation.set(-.3, 0, .22); p.lf.rotation.x = -.35; p.rf.rotation.x = -.35; p.head.rotation.z = .16; hangStrings(p, g);
    return g;
  }

  INMATES.def({
    key: 'george', num: '460', name: 'МАРИОНЕТКА ДЖОРДЖ', en: 'GEORGE THE PUPPET', cls: 'ДНЕВНОЙ', hp: 900, speed: SPEED, chase: CHASE, color: '#6b4426',
    difficulty: 2, minNight: 2, eye: 1.75, directive: 'NO_HIDE',
    alert: ['ОЧЕВИДЦЫ ОПИСЫВАЮТ ДЕРЕВЯННУЮ МАРИОНЕТКУ В ЧЕЛОВЕЧЕСКИЙ РОСТ В ТЕСНОМ КОРИЧНЕВОМ КОСТЮМЕ И КРАСНОМ ГАЛСТУКЕ. ЕГО ПРИБЛИЖЕНИЕ ВЫДАЁТ СУХОЕ ЩЁЛКАНЬЕ СУСТАВОВ.',
      'СУБЪЕКТ ТЕРПЕЛИВ. УКРЫТИЯ БУДУТ ПОД НАБЛЮДЕНИЕМ: ОН ВСТАНЕТ У ВАШЕЙ ДВЕРЦЫ И ДОЖДЁТСЯ ВАС.',
      'НЕ ПРЯЧЬТЕСЬ. ДВИГАЙТЕСЬ И ЗАЩИЩАЙТЕ СВОЙ ДОМ.'],
    tip: 'Не прячься: он встанет у шкафа, поправит галстук и вытащит тебя. Води его кругами по дому — бегом он не догонит. Друг может отвлечь его от шкафа.',
    model,
    spawn(m) { patchNav(m); enter(m); m.mem.g = null; },
    tick: think,
    anim(m, dt, moving) {
      const p = m.model.userData.parts, c = m.cl || (m.cl = { hx: 0, hz: 0, ht: 0, aT: 0 }), M = m.model, t = m.t, a = m.a;
      if (a !== c.a) { c.a = a; c.aT = 0; } c.aT += dt;
      for (const k of ['ll', 'rl', 'la', 'ra', 'lf', 'rf']) p[k].rotation.set(0, 0, 0);
      p.jaw.rotation.x = 0; p.tie.rotation.set(0, 0, 0);
      // резкие «кукольные» повороты головы
      if ((c.ht -= dt) <= 0) { c.ht = .45 + Math.random() * 1.1; c.hx = (Math.random() - .5) * .3; c.hz = (Math.random() - .5) * .55; }
      let lean = 0, roll = 0, bob = 0, hx = c.hx, hz = c.hz;
      if (a === 2) {            // обмяк: будто нити перерезали
        lean = .3; bob = -.1; roll = .1; p.la.rotation.set(.2, 0, -.06); p.ra.rotation.set(.12, 0, .1); p.lf.rotation.x = .15; p.ll.rotation.x = -.4; p.rl.rotation.x = .2; hx = .7; hz = .35; p.jaw.rotation.x = .35;
      } else if (a === 3) {     // поправляет галстук: правая рука у узла, левая держит конец
        const tug = Math.sin(t * 5.2) > .55 ? 1 : 0;
        p.ra.rotation.set(-.8 - tug * .06, 0, -.17); p.rf.rotation.set(.52 + tug * .1, 0, -2.41 + tug * .06);
        p.la.rotation.set(-.3 + Math.sin(t * 2.1) * .04, 0, -.25); p.lf.rotation.set(.4, 0, 1.79 - tug * .05);
        p.tie.rotation.z = Math.sin(t * 5.2) * .06; p.tie.rotation.x = -tug * .1; hx = .26; hz = Math.sin(t * .7) * .38 + (Math.sin(t * 1.9) > .97 ? .3 : 0);
      } else if (a === 4) {     // хватается за дверцы и рвёт на себя
        const k = clamp(c.aT / .35, 0, 1), back = c.aT > .4 ? clamp((c.aT - .4) / .2, 0, 1) : 0;
        for (const [A, F, s] of [[p.la, p.lf, -1], [p.ra, p.rf, 1]]) { A.rotation.set(-1.6 * k + back * .4, 0, s * (.22 - back * .1)); F.rotation.x = -.25 * k - back * .7; }
        lean = .12 * k - .26 * back; p.ll.rotation.x = -.25 * back; p.rl.rotation.x = .35 * back; hx = -.1; hz = 0; p.jaw.rotation.x = back * .4;
      } else {                  // походка марионетки: резкие махи прямых ног, болтающиеся руки, подпрыгивание на «нитях»
        const run = a === 1, s = Math.sin(m.walkT), q = Math.sign(s) * Math.pow(Math.abs(s), .45) * (moving ? (run ? .72 : .5) : 0);
        p.ll.rotation.x = q; p.rl.rotation.x = -q; bob = moving ? Math.abs(Math.cos(m.walkT)) * .06 : 0; roll = moving ? s * .05 : 0;
        if (run) { lean = .12; p.la.rotation.set(-1.4 + Math.sin(t * 13) * .14, 0, -.14); p.ra.rotation.set(-1.4 + Math.cos(t * 11) * .14, 0, .14); p.lf.rotation.x = -.2; p.rf.rotation.x = -.2; p.jaw.rotation.x = Math.sin(t * 12) > 0 ? .32 : 0; hx = -.05; }
        else { p.la.rotation.set(-q * .7 + .05, 0, -.1 - Math.abs(q) * .1); p.ra.rotation.set(q * .7 + .05, 0, .1 + Math.abs(q) * .1); p.lf.rotation.x = -.25 - Math.max(0, q) * .5; p.rf.rotation.x = -.25 - Math.max(0, -q) * .5; }
      }
      M.rotation.x = lean; M.rotation.z = roll; M.position.y += bob;
      p.head.rotation.x = damp(p.head.rotation.x, hx, 16, dt); p.head.rotation.z = damp(p.head.rotation.z, hz, 16, dt);
      hangStrings(p, M, t);   // обрезанные нити висят вниз и покачиваются
    },
    sound(m, dt) {
      if (!AU.ctx || m.vis === 0 || m.p.y < -50) return;
      const c = m.cs || (m.cs = { cr: 4 + Math.random() * 6 }), feet = m.p.clone().add(new V3(0, .25, 0)), head = m.p.clone().add(new V3(0, 1.7, 0)), a = m.a;
      const ph = Math.floor(m.walkT / PI); if (ph !== c.ph) { c.ph = ph; clack(feet, a === 1 ? .17 : .11); }   // каждый шаг — двойной щелчок
      if (a !== c.a) { if (a === 3) creak(head, .07); else if (a === 4) { creak(head, .12); clack(head, .2, 3); } else if (a === 2) clatter(head); c.a = a; }
      if (a === 3 && (c.tie = (c.tie ?? .5) - dt) < 0) { c.tie = 1 + Math.random() * .8; rustle(head.clone().setY(head.y - .3), .05); if (Math.random() < .5) clack(head, .05, 1); }
      if (a === 1 && (c.jaw = (c.jaw ?? 0) - dt) < 0) { c.jaw = .3 + Math.random() * .2; clack(head, .08, 1); }
      if ((c.cr -= dt) < 0) { c.cr = 5 + Math.random() * 8; if (a !== 2) creak(head, .045); }
    },
  });
})();
