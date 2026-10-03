/* ================= ЗАКЛЮЧЁННЫЙ 388: ВИСЯЩИЙ (THE HANGER) — дремлющий потолочный хищник ================= */
// Истощённая жёлто-серая фигура с двухметровыми паучьими конечностями и волосами, свисающими на метр вниз.
// Пробирается в дом (чаще через окно), заползает на потолок и ползёт к одной из потолочных «засад» (прихожая, лестничный
// пролёт, холл у кухни, кухня, площадка 2 этажа, коридор 2 этажа). Там ждёт: капает, скрипит потолок, видны пряди волос,
// на полу под ним — мокрое пятно, в темноте поблёскивают глаза.
// Кто ИДЁТ в полный рост прямо под ним (≤0.9 м по горизонтали) — тот получает падение сверху и умирает. Пригнувшись можно проскользнуть.
// Луч фонарика на нём 0.35 с → шипит и уползает к другой засаде. Попадание из дробовика → срывается, визжит и
// удирает из дома через ближайшее окно до конца ночи (удаляется). На рассвете уходит сам (общая логика рассвета).
// Промахнулся при падении — 4 с бросается на ближайшего видимого (6 м/с), потом снова лезет на потолок.
// Высота: на потолке m.p.y = потолок − HANG (тогда m.p + 1 м — его тело: туда целится дробовик), на полу m.p.y = пол.
// m.a: 0 — идёт по полу (вход), 1 — ползёт по потолку, 2 — оглушён, 3 — ждёт в засаде, 4 — шипит (фонарь),
//      5 — падает на жертву, 6 — сидит на полу после падения, 7 — сорван выстрелом, 8 — бег по полу (бросок/бегство).
(() => {
  const HANG = 1.3, V_WALK = 2.6, V_CRAWL = 2.4, V_FAST = 6, UNDER = .9, LAND_R = 1.25, T_DROP = .32, T_SETTLE = 1.5, T_TORCH = .35;
  // засады: узел графа (куда ползти) и точка под потолком
  const ANCHORS = [
    { id: 'foyer', node: 'foyer', x: -1, y: 0, z: 4.3 },
    { id: 'stair', node: 'stairB', x: -2.45, y: 0, z: -1.05 },
    { id: 'hallS', node: 'hallS', x: -.45, y: 0, z: -4.3 },
    { id: 'kitchen', node: 'kit', x: 4.3, y: 0, z: -1.2 },
    { id: 'landing', node: 'hallU1', x: -.9, y: F2, z: -4.35 },
    { id: 'upper', node: 'hallU2', x: -.4, y: F2, z: .6 },
  ];
  const losF = b => !b.door || !(WS[b.door] && (WS[b.door].o || WS[b.door].b));

  /* ---------- навигация (хост) ---------- */
  function regularNear(p, inside) {
    const N = WORLD.nav; let best = null, bd = 1e9;
    for (const k in N) { const n = N[k]; if (n.win || (n.room === 'out') === inside || Math.abs(n.p.y - p.y) > 1.5) continue; const d = Math.hypot(n.p.x - p.x, n.p.z - p.z) + Math.abs(n.p.y - p.y) * 2; if (d < bd) { bd = d; best = k; } }
    return best;
  }
  function fixNode(k) { const n = WORLD.nav[k]; return n && n.win ? regularNear(n.p, n.room !== 'out') || k : k; }
  function goSafe(m, node) {
    node = fixNode(node); if (!node) return; m.goNode(node); if (m.path.length) return;
    const from = m.nodeNear(m.p); if (!from || from === node) return;
    const alt = fixNode(from); if (alt !== from) m.path = [{ node: alt }];
  }
  const inHouse = p => !!GAME.roomAt(new V3(p.x, p.y + 1, p.z));
  // высота пола и потолка (хост: через m.fixY из stepTo). На потолке p.y плавно тянется к H.ty в tick.
  function fixY(hint) {
    const H = this.hg;
    if (!H) { const g = WORLD.coll.groundAt(this.p.x, this.p.z, .2, this.p.y + .5); this.p.y = g > -40 ? g : hint; return; }
    const g = WORLD.coll.groundAt(this.p.x, this.p.z, .2, H.fy + .5); H.fy = g > -40 ? g : (hint !== undefined ? hint : H.fy);
    const c = WORLD.coll.ceilingAt(this.p.x, this.p.z, .25, H.fy + .6);
    H.ty = H.up && c - H.fy < 7 ? c - HANG : H.fy;
    if (!H.up) this.p.y = H.fy;
  }
  function watchdog(m, dt) {
    const W = m.hg.wd; W.t += dt; W.mv += m.speedNow > 0 ? dt : 0; if (W.t < 3) return;
    const d = Math.hypot(m.p.x - W.x, m.p.z - W.z);
    if (W.mv > 1.5 && d < .3) { m.path = []; W.n++; if (W.n >= 3) { const k = fixNode(m.nodeNear(m.p)); if (k) { const n = WORLD.nav[k].p; m.p.x = n.x; m.p.z = n.z; m.hg.fy = n.y; m.fixY(n.y); } W.n = 0; } } else if (d >= .3) W.n = 0;
    W.t = 0; W.mv = 0; W.x = m.p.x; W.z = m.p.z;
  }
  const plDist = (a, pl) => Math.hypot(pl.x - a.x, pl.z - a.z) + Math.abs(pl.y - a.y) * 3;
  function pickAnchor(m, not) {
    const pls = GAME.alivePlayers().filter(pl => !pl.hid);
    let c = ANCHORS.filter(a => a !== not && WORLD.nav[a.node]);
    const safe = c.filter(a => !pls.some(pl => plDist(a, pl) < 3)); if (safe.length) c = safe;   // не появляется прямо над игроком
    if (pls.length && Math.random() < .5) { const pl = pick(pls); return c.sort((a, b) => plDist(a, pl) - plDist(b, pl))[0]; }
    return pick(c);
  }
  function goAnchor(m, a, fast) { const H = m.hg; H.anchor = a; H.fast = fast; m.state = 'crawl'; m.path = []; goSafe(m, a.node); H.idle = 0; H.torch = 0; }
  function settle(m, dt) { const H = m.hg; m.p.y = damp(m.p.y, H.ty, 7, dt); }

  /* ---------- восприятие (хост) ---------- */
  const body = m => new V3(m.p.x, m.p.y + HANG - .22, m.p.z);
  // кто идёт прямо под ним в полный рост
  function walkerBelow(m) {
    const H = m.hg, b = body(m);
    for (const pl of GAME.alivePlayers()) {
      if (pl.hid || pl.cr || !(pl.sp > .3)) continue;
      if (Math.hypot(pl.x - m.p.x, pl.z - m.p.z) > UNDER) continue;
      if (pl.y > m.p.y - .3 || pl.y < H.fy - 1.6) continue;
      if (WORLD.coll.los(b, new V3(pl.x, pl.y + 1.4, pl.z), losF)) return pl;
    }
    return null;
  }
  function nearestSeen(m, maxD) {
    const e = new V3(m.p.x, m.p.y + 1, m.p.z); let best = null;
    for (const pl of GAME.alivePlayers()) {
      if (pl.hid) continue; const pp = new V3(pl.x, pl.y + 1, pl.z), d = e.distanceTo(pp); if (d > maxD) continue;
      if (!(pl.l || GAME.litAt(pp)) && d > 5) continue;
      if (!WORLD.coll.los(e, pp, losF)) continue; if (!best || d < best.d) best = { pl, d };
    }
    return best && best.pl;
  }

  /* ---------- события (хост) ---------- */
  function startDrop(m, pl) { const H = m.hg; m.state = 'drop'; m.a = 5; H.ft = 0; H.y0 = m.p.y; H.up = 0; m.path = []; H.prey = pl.id; if (pl) m.yaw = Math.atan2(pl.x - m.p.x, pl.z - m.p.z); }
  function land(m) {
    const H = m.hg; let hit = false;
    GAME.fxAll('bang', new V3(m.p.x, m.p.y + .3, m.p.z)); CAMSHAKE(m.p, 1);
    for (const pl of GAME.alivePlayers()) { if (pl.hid) continue; if (Math.hypot(pl.x - m.p.x, pl.z - m.p.z) < LAND_R && Math.abs(pl.y - m.p.y) < 1.2) { GAME.killPlayer(pl.id, m); hit = true; } }
    H.t = 0; if (hit) { m.state = 'floor'; m.a = 6; } else { m.state = 'lunge'; m.a = 8; H.tgt = null; }
  }
  function startFall(m) {
    const H = m.hg; m.stun = 0; m.state = 'fall'; m.a = 7; H.ft = 0; H.y0 = m.p.y; H.up = 0; m.path = [];
    GAME.fxAll('scream', body(m));
  }
  // бегство из дома через ближайшее окно 1 этажа
  function startFlee(m) {
    const H = m.hg; m.state = 'flee'; m.a = 8; H.t = 0; H.up = 0; m.path = [];
    const wins = HOUSE.entries.filter(e => e.kind === 'window' && WORLD.nav['wi_' + e.id] && WORLD.nav['wo_' + e.id]);
    if (!wins.length) return;
    const e = wins.sort((a, b) => a.in.distanceTo(m.p) - b.in.distanceTo(m.p))[0]; H.win = e.id;
    goSafe(m, regularNear(e.in, true)); m.path.push({ node: 'wi_' + e.id }, { node: 'wo_' + e.id, via: 'win:' + e.id });
  }
  function gone(m) { if (m.gone) return; GAME.toastAll(m.T.name + ' сорвался с потолка и сбежал из дома!'); GAME.removeInmate(m); }

  /* ---------- модель ---------- */
  const SKIN = '#bdb68c', SKIN2 = '#a39c74', BONE = '#8c8564';
  function seg(g, w, h, d, c, y) { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), typeof c === 'string' ? mat(c) : c); m.position.y = y; g.add(m); return m; }
  // конечность из двух звеньев: плечо/бедро (группа) → локоть/колено (группа) → кисть/стопа с пальцами
  function limb2(parent, x, y, z, l1, l2, w, claw) {
    const a = new THREE.Group(); a.position.set(x, y, z); parent.add(a);
    seg(a, w, l1, w, SKIN2, -l1 / 2);
    const b = new THREE.Group(); b.position.y = -l1; a.add(b); a.userData.j = b;
    seg(b, w * .85, l2, w * .85, SKIN, -l2 / 2); MM.sph(b, w * .75, BONE, 0, 0, 0, { seg: 6, seg2: 5 });   // сустав
    if (claw) for (const s of [-1, 0, 1]) MM.box(b, .025, .22, .025, BONE, s * .035, -l2 - .1, .01, { rz: s * .25 });
    else MM.box(b, .1, .05, .2, SKIN2, 0, -l2 - .02, .06);
    return a;
  }

  INMATES.def({
    key: 'hanger', num: '388', name: 'ВИСЯЩИЙ', en: 'THE HANGER', cls: 'ДРЕМЛЮЩИЙ',
    hp: 300, speed: V_CRAWL, chase: V_FAST, color: '#bdb68c', difficulty: 1, minNight: 3, eye: 2.25, darkSight: 5, canHear: false, directive: 'LIGHTS_ON',
    alert: [
      'ПЕРСОНАЛ ЛЕЧЕБНИЦЫ СООБЩАЕТ: ЗАКЛЮЧЁННЫЙ 388 СНОВА И СНОВА ПИСАЛ НА СТЕНЕ КАМЕРЫ ОДНУ ФРАЗУ — «ПОЛ НЕБЕЗОПАСЕН».',
      'СУБЪЕКТ ЦЕПЛЯЕТСЯ ЗА ПОТОЛОК В КОРИДОРАХ И НА ЛЕСТНИЦАХ. ЕСЛИ ВЫ СЛЫШИТЕ НАД ГОЛОВОЙ КАПАНЬЕ ИЛИ СКРИП — ОСТАНОВИТЕСЬ.',
      'НЕ ПРОХОДИТЕ ПОД ТЕМ, ЧЕГО НЕ МОЖЕТЕ ЧЁТКО РАЗГЛЯДЕТЬ. ДЕРЖИТЕ СВЕТ ВКЛЮЧЁННЫМ. СМОТРИТЕ ВВЕРХ.',
    ],
    tip: 'Капает и скрипит сверху — посвети фонарём на потолок или обойди. Пригнувшись можно проскользнуть. Выстрел сгоняет его до утра.',
    model() {
      const g = new THREE.Group(), p = { g }; g.userData.parts = p; g.rotation.order = 'YXZ';
      // всё тело — в «риге» с началом в центре туловища: на потолке риг поворачивается лицом вниз
      const rig = new THREE.Group(); rig.rotation.order = 'YXZ'; g.add(rig); p.rig = rig;
      const TC = 1.67;                                          // центр туловища над полом в стойке
      rig.position.y = TC;
      seg(rig, .3, .6, .15, SKIN, 0);                           // впалая грудь
      for (const y of [.12, .02, -.08, -.18]) MM.box(rig, .26, .025, .02, BONE, 0, y, .078);   // рёбра
      MM.box(rig, .05, .5, .03, BONE, 0, 0, -.078);             // позвоночник
      seg(rig, .24, .14, .14, SKIN2, -.37);                     // таз
      MM.box(rig, .2, .1, .16, '#5a5244', 0, -.36, 0);          // грязная повязка
      MM.box(rig, .07, .24, .07, SKIN2, 0, .41, .02);           // длинная шея
      const h = p.head = new THREE.Group(); h.position.set(0, .52, .03); rig.add(h);
      MM.box(h, .24, .3, .25, SKIN, 0, .13, 0);
      MM.box(h, .26, .12, .27, '#121010', 0, .26, -.01);       // макушка в волосах
      const eyeM = new THREE.MeshBasicMaterial({ color: '#f2ecc0' });
      for (const s of [-1, 1]) { MM.box(h, .07, .045, .02, '#2a2418', s * .055, .14, .125); MM.sph(h, .019, '', s * .055, .14, .13, { mat: eyeM, seg: 6, seg2: 5 }); }
      MM.box(h, .09, .12, .02, '#1a0c08', 0, .0, .127);         // разинутый рот
      // волосы: группа, которая всегда висит вертикально вниз (компенсирует наклон рига и головы)
      const hair = new THREE.Group(); hair.position.set(0, .2, 0); h.add(hair); p.hair = hair;
      const HM = mat('#141212'), HM2 = mat('#221e1c');
      [-2.75, -2.2, -1.6, -1.05, -.62, .1, .62, 1.05, 1.6, 2.2, 2.75, PI].forEach((an, i) => {
        const L = .85 + ((i * 37) % 10) / 30, w = .045 + (i % 3) * .012, r = Math.abs(an) < .7 ? .15 : .14;
        MM.box(hair, w, L, .03, '', Math.sin(an) * r, -L / 2 + .02, Math.cos(an) * r, { mat: i % 2 ? HM : HM2, ry: an });
      });
      // паучьи руки и ноги (два звена, по ~1 м)
      p.la = limb2(rig, -.2, .26, 0, .62, .64, .075, true); p.ra = limb2(rig, .2, .26, 0, .62, .64, .075, true);
      p.ll = limb2(rig, -.1, -.42, 0, .62, .62, .085, false); p.rl = limb2(rig, .1, -.42, 0, .62, .62, .085, false);
      // капли и мокрое пятно (видны только в засаде)
      const dm = new THREE.MeshBasicMaterial({ color: '#b8c4b0' });
      p.drips = [0, 1].map(() => { const d = MM.sph(g, .028, '', 0, 0, 0, { mat: dm, seg: 6, seg2: 5, sy: 1.6 }); d.visible = false; return d; });
      const pd = new THREE.Mesh(new THREE.CircleGeometry(.38, 14), new THREE.MeshLambertMaterial({ color: '#2b2a1c', transparent: true, opacity: .75, emissive: '#06060a' }));
      pd.rotation.x = -PI / 2; pd.visible = false; g.add(pd); p.puddle = pd;
      p.TC = TC; pose(p, 0, -1, 0, false, 0);
      return g;
    },
    spawn(m) {
      const wins = HOUSE.entries.filter(e => e.kind === 'window' && WORLD.nav['wo_' + e.id] && WORLD.nav['wi_' + e.id]);
      const e = wins.length && Math.random() < .7 ? pick(wins) : pick(HOUSE.entries.filter(q => q.kind === 'door')) || pick(HOUSE.entries);
      m.entry = e; m.p.copy(e.out); m.state = 'enter'; m.yaw = 0;
      m.hg = { up: 0, fy: e.out.y, ty: e.out.y, t: 0, hp: m.hp, anchor: null, idle: 0, idleMax: 50, torch: 0, ft: 0, y0: 0, wd: { t: 0, x: m.p.x, z: m.p.z, n: 0, mv: 0 } };
      if (e.kind === 'window') m.path = [{ node: 'wo_' + e.id }, { node: 'wi_' + e.id, via: 'win:' + e.id }, { node: regularNear(e.in, true) }];
      else m.goNode(m.nodeNear(e.in));
    },
    tick(m, dt) {
      const H = m.hg; if (!H || m.gone) return; H.t += dt; m.speedNow = 0;
      // попадание (дробовик): срывается и бежит из дома
      if (m.hp < H.hp - .01 && m.state !== 'fall' && m.state !== 'flee') startFall(m);
      H.hp = m.hp;
      if (m.state === 'fall') {
        m.stun = 0; m.a = 7; H.ft += dt; const k = Math.min(1, H.ft / .4); m.p.y = lerp(H.y0, H.fy, k * k);
        if (H.ft > 1.1) startFlee(m); return;
      }
      if (m.state === 'flee') {
        m.stun = 0; m.a = 8;
        const st = m.path[0]; if (st && st.via && st.via.startsWith('win:')) { const id = st.via.slice(4); if (WS[id] && !WS[id].b) { wsSet(id, { b: 1, c: 0 }); GAME.fxAll('glass', m.p.clone().add(new V3(0, 1, 0))); } }
        if (m.follow(dt, V_FAST) || H.t > 14) gone(m); else { watchdog(m, dt); m.tryKill(.8); }
        return;
      }
      if (m.stun > 0) { m.stun -= dt; m.a = 2; if (H.up) settle(m, dt); if (m.state === 'drop') { m.state = 'climb'; H.up = 1; } return; }
      const S = m.state;
      if (S === 'enter') {
        m.a = 0; const done = m.follow(dt, V_WALK); watchdog(m, dt);
        if (inHouse(m.p) && m.p.distanceTo(m.entry.in) < 3 || (done && inHouse(m.p))) { m.state = 'climb'; H.up = 1; m.path = []; m.fixY(m.p.y); }
        else if (done) goSafe(m, 'foyer');
        m.tryKill(.9); return;
      }
      if (S === 'climb') { m.a = 1; H.up = 1; m.fixY(H.fy); settle(m, dt); if (Math.abs(m.p.y - H.ty) < .08) goAnchor(m, pickAnchor(m, H.anchor), false); return; }
      if (S === 'crawl') {
        m.a = 1; const v = H.fast ? V_CRAWL * 1.45 : V_CRAWL, a = H.anchor;
        if (m.follow(dt, v)) { if (m.stepTo(new V3(a.x, a.y, a.z), dt, v)) { m.state = 'settle'; H.t = 0; m.a = 3; } }
        settle(m, dt); watchdog(m, dt); return;
      }
      if (S === 'settle' || S === 'wait') {
        m.a = 3; settle(m, dt); m.yaw += Math.sin(H.t * .4) * dt * .15;
        if (GAME.torchOn(body(m))) H.torch += dt; else H.torch = Math.max(0, H.torch - dt * .5);
        if (H.torch > T_TORCH) { m.state = 'hiss'; H.t = 0; m.a = 4; return; }
        if (S === 'settle') { if (H.t > T_SETTLE) { m.state = 'wait'; H.idle = 0; H.idleMax = 45 + Math.random() * 30; } return; }
        const pl = walkerBelow(m); if (pl) { startDrop(m, pl); return; }
        H.idle += dt; if (H.idle > H.idleMax) goAnchor(m, pickAnchor(m, H.anchor), false);
        return;
      }
      if (S === 'hiss') { m.a = 4; settle(m, dt); if (H.t > .8) goAnchor(m, pickAnchor(m, H.anchor), true); return; }
      if (S === 'drop') { m.a = 5; H.ft += dt; const k = Math.min(1, H.ft / T_DROP); m.p.y = lerp(H.y0, H.fy, k * k); if (H.ft >= T_DROP) land(m); return; }
      if (S === 'floor') { m.a = 6; if (H.t > 1.4) { m.state = 'climb'; H.up = 1; } return; }
      if (S === 'lunge') {
        m.a = 8; if (H.t < .45) return;                         // короткая пауза после промаха — шанс убежать
        const tp = H.tgt && GAME.alivePlayers().find(q => q.id === H.tgt && !q.hid) || nearestSeen(m, 14);
        if (!tp || H.t > 4.5) { m.state = 'climb'; H.up = 1; m.path = []; return; }
        H.tgt = tp.id; const t = new V3(tp.x, tp.y, tp.z), dh = Math.hypot(t.x - m.p.x, t.z - m.p.z);
        if (dh < 7 && Math.abs(t.y - m.p.y) < 1.2 && WORLD.coll.los(new V3(m.p.x, m.p.y + 1, m.p.z), new V3(t.x, m.p.y + 1, t.z), losF)) { m.path = []; m.stepTo(t, dt, V_FAST); }
        else { if (!m.path.length || (H.t % .8) < dt) goSafe(m, m.nodeNear(t)); m.follow(dt, V_FAST); }
        m.tryKill(1); return;
      }
      m.state = 'climb'; H.up = 1;
    },
    init(m) { m.fixY = fixY; const U = m.hgC = { fy: 0, cy: 99, k: 0, chk: 0, a: -1, ct: 1, dt: .8, bt: 4, st: 0, drip: [0, .55], lp: m.p.clone(), v: 0 }; },
    anim(m, dt, moving) {
      const g = m.model, p = g.userData.parts, U = m.hgC, a = m.a, t = m.t;
      U.chk -= dt; if (U.chk <= 0) { U.chk = .12; const fy = WORLD.coll.groundAt(m.p.x, m.p.z, .2, m.p.y + .3); U.fy = fy > -40 ? fy : m.p.y; U.cy = WORLD.coll.ceilingAt(m.p.x, m.p.z, .25, U.fy + .6); }
      const k = U.cy - U.fy < 7 ? clamp((m.p.y - U.fy) / Math.max(.3, U.cy - HANG - U.fy), 0, 1) : 0;
      U.k = damp(U.k, k, 14, dt);
      pose(p, U.k, a, t, moving, m.walkT);
      // капли с волос и лужа под засадой
      const wait = a === 3 && U.k > .9, tipY = HANG - .22 - .95, floorY = U.fy - m.p.y + .01, hz = .7;
      p.puddle.visible = wait; if (wait) p.puddle.position.set(0, floorY, hz);
      p.drips.forEach((d, i) => {
        d.visible = wait; if (!wait) return;
        U.drip[i] += dt / 1.7; if (U.drip[i] >= 1) { U.drip[i] -= 1; if (i === 0) U.dripHit = 1; }
        const f = U.drip[i], fall = Math.max(0, (f - .45) / .55);
        d.position.set(i ? .05 : -.04, lerp(tipY, floorY, fall * fall), hz + (i ? .02 : -.03)); d.scale.setScalar(f < .45 ? .4 + f * 1.3 : 1);
      });
    },
    sound(m, dt) {
      if (!AU.ctx) return;
      const U = m.hgC, a = m.a, b = new V3(m.p.x, m.p.y + HANG - .22, m.p.z);
      const sp = m.p.distanceTo(U.lp) / Math.max(dt, 1e-3); U.lp.copy(m.p); U.v = damp(U.v, Math.min(sp, 10), 6, dt);
      if (a !== U.a) {
        if (a === 4) hiss(b, .32);
        if (a === 5) { shriek(b, .4); }
        if (a === 8 && U.a === 5) rasp(b, .3);
        U.a = a;
      }
      if (m.vis === 0 || m.p.y < -50) return;
      let ld = 1e9; for (const lp of LOCALS) ld = Math.min(ld, lp.cam.position.distanceTo(b)); if (ld > 30) return;
      if (a === 1) { U.ct -= dt; if (U.ct <= 0) { creak(b, .16); U.ct = .55 + Math.random() * .5; } U.st -= dt; if (U.st <= 0 && U.v > .3) { tap(b, .06); U.st = .16 + Math.random() * .08; } }
      else if (a === 3) {
        if (U.dripHit) { U.dripHit = 0; if (U.k > .9) drip(new V3(m.p.x + .7 * Math.sin(m.yaw), U.fy + .05, m.p.z + .7 * Math.cos(m.yaw)), .12); }
        U.ct -= dt; if (U.ct <= 0) { creak(b, .1); U.ct = 4 + Math.random() * 5; }
        U.bt -= dt; if (U.bt <= 0) { AU.play('breath', b); U.bt = 7 + Math.random() * 5; }
      } else if (a === 8 || a === 0) { U.st -= dt; if (U.st <= 0 && U.v > .3) { AU.play('step', new V3(m.p.x, m.p.y, m.p.z), { v: a === 8 ? .16 : .08 }); tap(b, .05); U.st = a === 8 ? .11 : .3; } }
    },
  });

  /* ---------- поза (у всех клиентов): k=0 — стоит/бежит по полу, k=1 — распластан на потолке лицом вниз ---------- */
  function pose(p, k, a, t, moving, wt) {
    const rig = p.rig, st = 1 - k;
    // стойка: сутулый, длинные руки висят; бег — почти на четвереньках
    let hunch = .22, ry = p.TC, la = [-.15, 0, -.25], lae = .2, la2 = [-.15, 0, .25], ll = [0, 0, -.06], lle = .1, ll2 = [0, 0, .06];
    if (a === 8 || a === 6) { hunch = a === 6 ? 1.05 : .95; ry = a === 6 ? .95 : 1.25; }
    if (a === -1) { la = [-.55, 0, -.35]; la2 = [-.75, 0, .3]; lae = .55; }   // поза для камеры/скримера: тянется вперёд
    const sw = moving ? Math.sin(wt) : 0;
    // потолок: спина к потолку, лицо вниз; руки раскинуты вперёд-в-стороны, ноги назад-в-стороны, суставы согнуты
    const cr = a === 1 && moving ? Math.sin(t * 9) : 0, tw = a === 4 ? Math.sin(t * 40) * .12 : a === 2 ? Math.sin(t * 25) * .1 : 0;
    const fl = (a === 5 || a === 7) ? Math.sin(t * 30) * .5 : 0;
    rig.position.y = lerp(ry, HANG - .22, k);
    rig.rotation.x = lerp(hunch, PI / 2, k) + tw * .3;
    rig.rotation.z = k * cr * .06;
    const arm = (P, s, ph) => {
      const c = s < 0 ? la : la2, swing = (a === 8 ? 1.1 : .6) * sw * s * (a === 6 ? 0 : 1);
      P.rotation.x = lerp(c[0] + swing + fl, .25 + ph * .25, k);
      P.rotation.z = lerp(c[2], s * (2.25 + ph * .18), k) + fl * s * .3;
      P.rotation.y = 0;
      P.userData.j.rotation.x = lerp(-lae - (a === 8 ? .5 : 0), -.2, k); P.userData.j.rotation.z = lerp(0, -s * 1.15, k);
    };
    const leg = (P, s, ph) => {
      const c = s < 0 ? ll : ll2, swing = (a === 8 ? .9 : .55) * sw * -s;
      P.rotation.x = lerp(c[0] + swing - hunch * (a === 8 ? .55 : 1) - (a === 6 ? .3 : 0), -.2 + ph * .2, k);
      P.rotation.z = lerp(c[2], s * (.75 + ph * .15), k) + fl * s * .3;
      P.userData.j.rotation.x = lerp(lle + (a === 6 ? 1.6 : Math.max(0, swing) * .8), .3, k); P.userData.j.rotation.z = lerp(0, s * .9, k);
    };
    arm(p.la, -1, cr); arm(p.ra, 1, -cr); leg(p.ll, -1, -cr); leg(p.rl, 1, cr);
    // голова: в засаде медленно поворачивается, при шипении задирается к свету
    const hx = a === 4 ? -.5 : a === 3 ? Math.sin(t * .7) * .12 : a === -1 ? .35 : .25 * st;
    p.head.rotation.set(hx + tw, a === 3 ? Math.sin(t * .45) * .5 * k : 0, tw);
    // волосы всегда висят вертикально вниз
    p.hair.rotation.set(-(rig.rotation.x + p.head.rotation.x), 0, 0);
    p.hair.rotation.z = Math.sin(t * 1.3) * .03 + (a === 1 ? cr * .05 : 0);
  }

  /* ---------- звуки (синтез, у всех клиентов) ---------- */
  function lpf(dest, f, type = 'lowpass', q = 1) { const b = AU.ctx.createBiquadFilter(); b.type = type; b.frequency.value = f; b.Q.value = q; b.connect(dest); return b; }
  function creak(pos, v) { // скрип потолочных досок: «прилипающая» пила через полосовой фильтр
    const out = AU.at(pos), t = AU.t(), d = .3 + Math.random() * .4, o = AU.osc('sawtooth', 70, t, t + d + .05, lpf(AU.env(out, t, v, .05, d), 480 + Math.random() * 500, 'bandpass', 4));
    for (let i = 0; i <= 7; i++) o.frequency.setValueAtTime(48 + Math.random() * 70, t + i * d / 7);
    AU.nz(out, t, d, v * .25, 'bandpass', 1500, 3, .04);
  }
  function tap(pos, v) { const out = AU.at(pos), t = AU.t(); AU.nz(out, t, .025, v, 'bandpass', 2200 + Math.random() * 1500, 5, .001); }
  function drip(pos, v) { const out = AU.at(pos), t = AU.t(), f = 850 + Math.random() * 600, o = AU.osc('sine', f, t, t + .14, AU.env(out, t, v, .002, .11)); o.frequency.exponentialRampToValueAtTime(f * 2.3, t + .07); AU.nz(out, t, .02, v * .4, 'highpass', 4500, 1, .001); }
  function hiss(pos, v) { const out = AU.at(pos), t = AU.t(), n = AU.nz(out, t, .85, v, 'highpass', 2200, .8, .02); n.f.frequency.linearRampToValueAtTime(5200, t + .8); const o = AU.osc('sawtooth', 150, t, t + .8, lpf(AU.env(out, t, v * .35, .02, .7), 800)); o.frequency.linearRampToValueAtTime(95, t + .7); }
  function shriek(pos, v) { const out = AU.at(pos), t = AU.t(); const o = AU.osc('sawtooth', 900, t, t + .7, lpf(AU.env(out, t, v, .01, .65), 2600, 'bandpass', 1.5)); o.frequency.linearRampToValueAtTime(1700, t + .15); o.frequency.linearRampToValueAtTime(700, t + .65); AU.nz(out, t, .5, v * .6, 'highpass', 3000, .7, .005); }
  function rasp(pos, v) { const out = AU.at(pos), t = AU.t(); for (let i = 0; i < 3; i++) AU.nz(out, t + i * .18, .14, v, 'bandpass', 900 + i * 300, 2, .01); }
})();
