/* ================= ЗАКЛЮЧЁННЫЙ 077: ЖИЛЕЦ (THE SQUATTER; у нас — «The Tenant») ================= */
// Небритый мужчина в грязной майке и клетчатых пижамных штанах, длинные сальные волосы.
// ФАЗА 1 (до 2:00): занимает одно случайное укрытие (WS.SQUATTER.h). Модели не видно (vis=0) — только два
//   отражающих глаза в щели жалюзи на дверце (у всех клиентов; ярко вспыхивают, когда на них светит фонарь
//   любого игрока, тускло — при свете в комнате или вплотную) и тихое дыхание рядом. Неуязвим.
//   Кто залезет в его шкаф — мгновенная смерть (хост: WS[h].by стал чьим-то id).
//   С 1:30 шкаф скребётся и дребезжит, дыхание тяжелеет (предупреждение).
// ФАЗА 2 (st.clock >= 26, 2:00): вырывается из шкафа (удар дверцы, «ЭТО МОЙ ДОМ!») и становится быстрым
//   охотником (обход 3.2, погоня 5.8), которого можно застрелить (450).
// На всех шкафах-укрытиях на время ночи появляются жалюзи (клиентский декор) — чтобы щель была у всех одинаковой.
// m.a: 0 — обход, 1 — погоня, 2 — оглушён, 4 — вырывается из шкафа. Общее состояние: WS.SQUATTER {h, ph, warn, k}.
(() => {
  const KEY = 'SQUATTER', SPEED = 3.2, CHASE = 5.8, BURST = 26, WARN = 25.5;
  const losF = b => !b.door || !(WS[b.door] && (WS[b.door].o || WS[b.door].b));

  /* ---------- навигация (хост): обходы багов общего графа (тупиковые узлы окон, щель у верхней ступеньки) ---------- */
  function fixNode(k) {
    const N = WORLD.nav, n = N && N[k]; if (!n || !n.win) return k; let best = null, bd = 1e9;
    for (const q in N) { const o = N[q]; if (o.win || (o.room === 'out') !== (n.room === 'out') || Math.abs(o.p.y - n.p.y) > 1) continue; const d = o.p.distanceTo(n.p); if (d < bd) { bd = d; best = q; } }
    return best || k;
  }
  function fixY(hint) { const g = WORLD.coll.groundAt(this.p.x, this.p.z, .4, this.p.y + .36); this.p.y = g > -40 ? g : hint; }
  function patchNav(m) {
    m.fixY = fixY;
    m.goNode = function (node) {
      node = fixNode(node); Inmate.prototype.goNode.call(this, node);
      if (this.path.length || !node) return;
      const from = this.nodeNear(this.p), n = from && WORLD.nav[from];
      if (n && n.win && from !== node) { const alt = fixNode(from); if (alt !== from) this.path = [{ node: alt }]; }
    };
  }
  function watchdog(m, dt) {
    const W = m.mem.wd || (m.mem.wd = { t: 0, x: m.p.x, z: m.p.z, n: 0 }); W.t += dt; if (W.t < 3) return;
    const moved = Math.hypot(m.p.x - W.x, m.p.z - W.z), wants = m.path.length > 0 && !m.path[0].via;
    if (wants && moved < .3 && m.stun <= 0) { m.path = []; if (m.state === 'investigate') m.state = 'roam'; if (++W.n >= 3) { const k = m.nodeNear(m.p); if (k) m.p.copy(WORLD.nav[fixNode(k)].p); W.n = 0; } }
    else if (moved >= .3) W.n = 0;
    W.t = 0; W.x = m.p.x; W.z = m.p.z;
  }

  /* ---------- укрытия: «перед» шкафа (сторона комнаты; hideSpot.out у части шкафов смотрит в стену) ---------- */
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
  // рамка «жалюзи» на передней грани шкафа: центр, поворот, ширина, цвет дверцы
  function faceFrame(h) {
    const gr = h.mesh && h.mesh.parent; if (!gr || !h.mesh.geometry || !h.mesh.geometry.parameters) return null;
    const f = hideFront(h), ry = gr.rotation.y, door = f.x * Math.sin(ry) + f.z * Math.cos(ry) > 0, P = h.mesh.geometry.parameters;
    const off = (door ? P.depth / 2 + .025 : P.depth / 2) + .006;
    return { pos: new V3(gr.position.x + f.x * off, gr.position.y + 1.58, gr.position.z + f.z * off), ry: Math.atan2(f.x, f.z), w: P.width, col: '#' + h.mesh.material.color.getHexString(), f };
  }

  /* ---------- ИИ (хост) ---------- */
  function hideOf(m) { return WORLD.hides.find(q => q.id === m.mem.hide); }
  function burst(m, h) {
    const mem = m.mem, f = hideFront(h); mem.ph = 2; mem.bt = 0; m.state = 'burst'; m.a = 4; m.vis = 1; m.path = [];
    m.p.set(h.pos.x + f.x * .95, h.pos.y, h.pos.z + f.z * .95); m.yaw = Math.atan2(f.x, f.z);
    wsSet(KEY, { ph: 2 });
    GAME.fxAll('bang', h.eye); GAME.fxAll('doorOpen', h.eye); GAME.fxAll('say', h.eye, { text: 'ЭТО МОЙ ДОМ!' }); CAMSHAKE(h.eye, 1);
  }
  function tick(m, dt) {
    const mem = m.mem, h = hideOf(m);
    if (mem.ph === 1) {
      m.a = 0; m.vis = 0; m.speedNow = 0; m.stun = 0;
      if (!h) { mem.ph = 2; m.vis = 1; m.state = 'roam'; m.p.copy(WORLD.nav.hallM.p); wsSet(KEY, { ph: 2 }); return; }
      const by = WS[h.id] && WS[h.id].by;
      if (by) {                                   // кто-то залез в ЕГО шкаф
        mem.k = (mem.k || 0) + 1; wsSet(KEY, { k: mem.k }); GAME.fxAll('bang', h.eye);
        GAME.killPlayer(by, m);
        if (WS[h.id].by === by) GAME.toggleHide(by, h);   // не погиб (неуязвимость после удара) — вышвырнуть
      }
      const clock = GAME.st.clock || 0;
      if (clock >= BURST) burst(m, h);
      else if (clock >= WARN && !mem.warn) { mem.warn = 1; wsSet(KEY, { warn: 1 }); GAME.toastAll('Где-то в доме кто-то тяжело дышит и скребётся изнутри шкафа…'); }
      return;
    }
    if (m.state === 'burst') {
      m.a = 4; m.speedNow = 0; mem.bt += dt; if (mem.bt > .45) m.tryKill(1.1);
      if (mem.bt > 1.3) { const t = m.nearestAlive(pl => !pl.hid); m.path = []; if (t) { m.state = 'investigate'; m.lastSeen = new V3(t.pl.x, t.pl.y, t.pl.z); } else m.state = 'roam'; }
      return;
    }
    watchdog(m, dt);
    m.hunt(dt, { speed: SPEED, chase: CHASE, sight: 22 });
  }

  /* ---------- клиент: жалюзи на всех укрытиях и глаза в щели его шкафа ---------- */
  function buildDeco(m) {
    const C = m.sq; if (C.built || WORLD.level !== 'house' || !WORLD.hides.length) return; C.built = 1;
    for (const h of WORLD.hides) {
      const F = faceFrame(h); if (!F) continue;
      const g = new THREE.Group(); g.position.copy(F.pos); g.rotation.y = F.ry; WORLD.add(g);
      MM.box(g, F.w * .72, .21, .01, '#0b0907', 0, 0, 0);
      for (const y of [-.074, .074]) MM.box(g, F.w * .76, .034, .02, shadeHex(F.col, -.25), 0, y, .006);
      C.deco.push({ h, g, F });
    }
  }
  function ensureEyes(m, hid) {
    const C = m.sq; if (C.eyes && C.eyes.hid === hid) return C.eyes; dropEyes(m);
    const D = C.deco.find(d => d.h.id === hid); if (!D) return null;
    const mat0 = new THREE.MeshBasicMaterial({ color: '#000000' }), geo = new THREE.SphereGeometry(.021, 8, 6), g = new THREE.Group(); g.position.z = .012; D.g.add(g);
    for (const s of [-1, 1]) { const e = new THREE.Mesh(geo, mat0); e.position.x = s * .056; e.scale.set(1.25, 1, .5); g.add(e); }
    C.eyes = { hid, g, mat: mat0, geo, k: 0, blink: 2 + Math.random() * 3, wp: D.F.pos.clone().addScaledVector(D.F.f, .012), D };
    return C.eyes;
  }
  function dropEyes(m) { const E = m.sq && m.sq.eyes; if (!E) return; if (E.g.parent) E.g.parent.remove(E.g); E.geo.dispose(); E.mat.dispose(); m.sq.eyes = null; }
  // насколько сильно луч фонаря попадает в точку (0..1)
  function beam(t, wp) {
    const to = wp.clone().sub(t.pos), d = to.length(); if (d > 14 || d < .05) return 0;
    const c = to.multiplyScalar(1 / d).dot(t.dir); if (c < .9) return 0;
    if (!WORLD.coll.los(t.pos, wp, losF)) return 0;
    return clamp((c - .9) / .07, 0, 1) * (1 - d / 20);
  }
  function eyesFrame(m, dt) {
    const S = WS[KEY]; if (!S || S.ph !== 1 || !S.h) { dropEyes(m); return; }
    const E = ensureEyes(m, S.h); if (!E) return;
    let lit = GAME.litAt(E.wp) ? .16 : .05;
    for (const lp of LOCALS) {
      if (!lp.alive || lp.hidden) continue;
      if (lp.light) { const b = beam(lp.torch(), E.wp); if (b > 0) lit = Math.max(lit, .35 + .65 * b); }
      const d = lp.cam.position.distanceTo(E.wp); if (d < 2.4) lit = Math.max(lit, .1 + .25 * (1 - d / 2.4));   // заглянул в щель вплотную
    }
    for (const id in GAME.remotes) { const r = GAME.remotes[id]; if (r.alive && r.l && !r.hid) { const b = beam(r.torch(), E.wp); if (b > 0) lit = Math.max(lit, .35 + .65 * b); } }
    E.k = damp(E.k, lit, 12, dt); const k = E.k;
    E.mat.color.setRGB(.96 * k, 1 * k, .62 * k);
    // моргает и косится на ближайшего
    E.blink -= dt; const closed = E.blink < 0; if (E.blink < -.13) E.blink = 2.5 + Math.random() * 4;
    for (const e of E.g.children) e.scale.y = closed ? .12 : 1;
    const lp = LOCALS.find(l => l.alive); if (lp) { const to = lp.cam.position.clone().sub(E.wp); const rx = Math.cos(E.D.F.ry), rz = -Math.sin(E.D.F.ry); E.g.position.x = damp(E.g.position.x, clamp((to.x * rx + to.z * rz) * .01, -.012, .012), 4, dt); }
  }

  /* ---------- звук (у всех клиентов) ---------- */
  function listenD(p) { let d = 1e9; for (const lp of LOCALS) d = Math.min(d, lp.cam.position.distanceTo(p)); return d; }
  function breath(pos, v, heavy) {
    const t = AU.t(), out = AU.at(pos);
    const a = AU.nz(out, t, .75, v * .8, 'bandpass', 650, 1.3, .45); a.f.frequency.linearRampToValueAtTime(1100, t + 1.1);
    const b = AU.nz(out, t + (heavy ? .75 : 1.25), heavy ? .55 : .95, v, 'bandpass', 620, 1.1, .12); b.f.frequency.linearRampToValueAtTime(360, t + 2.2);
    if (heavy) { const f = AU.ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 220; f.connect(AU.env(out, t + .75, v * 1.4, .1, .6)); AU.osc('sawtooth', 52 + Math.random() * 8, t + .75, t + 1.6, f); }
  }
  function rattle(pos, v) {
    const t = AU.t(), out = AU.at(pos);
    for (let i = 0; i < 3; i++) { const tt = t + i * (.09 + Math.random() * .05); AU.nz(out, tt, .06, v, 'lowpass', 340, 1, .002); AU.osc('sine', 85 + Math.random() * 30, tt, tt + .08, AU.env(out, tt, v * .6, .002, .06)); }
    for (let i = 0; i < 3; i++) AU.nz(out, t + .35 + i * .15, .11, v * .5, 'bandpass', 2800 + Math.random() * 1500, 4, .01);
  }
  function growl(pos, v, dur = 1) {
    const A = AU.ctx, t = AU.t(), out = AU.at(pos), f = A.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 480; f.connect(AU.env(out, t, v, .06, dur));
    const o = AU.osc('sawtooth', 120, t, t + dur + .2, f); o.frequency.linearRampToValueAtTime(68, t + dur);
    const o2 = AU.osc('square', 61, t, t + dur + .2, f); o2.frequency.linearRampToValueAtTime(44, t + dur);
    AU.nz(out, t, dur * .8, v * .5, 'bandpass', 900, 1.2, .03);
  }
  function slap(pos, v) { const t = AU.t(), out = AU.at(pos); AU.nz(out, t, .045, v, 'lowpass', 900, 1, .001); AU.osc('sine', 75, t, t + .07, AU.env(out, t, v * .5, .002, .05)); }
  function pant(pos, v) { const t = AU.t(), out = AU.at(pos); AU.nz(out, t, .16, v, 'bandpass', 1100, 1.4, .03); AU.nz(out, t + .24, .14, v * .8, 'bandpass', 800, 1.4, .03); }

  /* ---------- модель ---------- */
  let PLAID = null;
  function plaid() {
    if (PLAID) return PLAID;
    const t = canvasTex('sq_plaid', 64, 64, g => {
      g.fillStyle = '#3c4c82'; g.fillRect(0, 0, 64, 64);
      g.fillStyle = 'rgba(150,40,52,.85)'; g.fillRect(0, 6, 64, 9); g.fillRect(6, 0, 9, 64); g.fillRect(0, 38, 64, 9); g.fillRect(38, 0, 9, 64);
      g.fillStyle = 'rgba(235,225,200,.45)'; g.fillRect(0, 26, 64, 2); g.fillRect(26, 0, 2, 64); g.fillRect(0, 58, 64, 2); g.fillRect(58, 0, 2, 64);
      g.fillStyle = 'rgba(90,70,40,.35)'; g.fillRect(20, 44, 14, 10);   // пятно
    }, [1, 3]);
    return (PLAID = new THREE.MeshLambertMaterial({ map: t }));
  }
  function model() {
    const g = new THREE.Group(), p = { g }; g.userData.parts = p;
    const skin = '#c6ab92', skinD = '#a3876f', shirt = '#ddd4b8', stain = '#a68d58', stain2 = '#86683f', hair = '#251c12', stub = '#6c625a', nail = '#6e5c48';
    const piv = (par, x, y, z) => { const q = new THREE.Group(); q.position.set(x, y, z); par.add(q); return q; }, pl = { mat: plaid() };
    const H = .88;
    // клетчатые пижамные штаны, босые ноги
    p.ll = piv(g, -.12, H, 0); p.rl = piv(g, .12, H, 0);
    for (const L of [p.ll, p.rl]) { MM.box(L, .2, .8, .22, '', 0, -.4, 0, pl); MM.box(L, .13, .07, .27, skin, 0, -.845, .05); MM.box(L, .13, .02, .05, nail, 0, -.87, .17); }
    // сутулый торс в грязной майке
    p.hip = piv(g, 0, H, 0);
    MM.box(p.hip, .44, .14, .24, '', 0, .02, 0, pl);
    p.torso = MM.box(p.hip, .46, .6, .26, shirt, 0, .38, 0);
    MM.box(p.hip, .15, .12, .01, stain, -.08, .3, .131); MM.box(p.hip, .09, .17, .01, stain2, .12, .47, .131); MM.box(p.hip, .07, .06, .01, stain, .04, .17, .131);
    for (const s of [-1, 1]) MM.box(p.hip, .1, .06, .22, skin, s * .2, .66, 0);
    MM.box(p.hip, .13, .1, .13, skin, 0, .72, .03);
    // длинные худые руки до колен, грязные ногти
    p.la = piv(p.hip, -.29, .64, 0); p.ra = piv(p.hip, .29, .64, 0);
    for (const A of [p.la, p.ra]) { MM.box(A, .11, .74, .11, skin, 0, -.37, 0); MM.box(A, .12, .17, .07, skinD, 0, -.82, .01); MM.box(A, .11, .03, .075, nail, 0, -.91, .012); }
    // голова: щетина, выпученные глаза с бликом, кривая жёлтая ухмылка, сальные патлы
    p.head = piv(p.hip, 0, .75, .06);
    MM.box(p.head, .34, .38, .34, skin, 0, .19, 0); MM.box(p.head, .35, .15, .35, stub, 0, .07, .002);
    const glint = mat('#f2ffb0', { basic: true });
    for (const s of [-1, 1]) {
      MM.box(p.head, .088, .058, .01, '#efe4c8', s * .08, .23, .172); MM.box(p.head, .03, .036, .012, '#140e0c', s * .078, .228, .176);
      MM.box(p.head, .014, .014, .01, '', s * .07, .238, .182, { mat: glint });
      MM.box(p.head, .088, .02, .01, '#86625a', s * .08, .192, .172); MM.box(p.head, .1, .03, .012, hair, s * .08, .283, .173, { rz: s * .2 });
      MM.box(p.head, .05, .48, .26, hair, s * .185, .17, -.04); MM.box(p.head, .045, .32, .02, hair, s * .14, .24, .178);
    }
    MM.box(p.head, .06, .09, .06, skinD, 0, .165, .19);
    MM.box(p.head, .15, .03, .01, '#3a1a14', .012, .1, .177, { rz: .09 }); MM.box(p.head, .11, .018, .01, '#d6c46e', .012, .106, .179, { rz: .09 });
    MM.box(p.head, .36, .07, .36, hair, 0, .41, -.01); MM.box(p.head, .36, .58, .08, hair, 0, .13, -.19);
    // поза по умолчанию: сгорбился, голова вперёд, руки висят
    p.hip.rotation.x = .3; p.head.rotation.x = -.32; p.la.rotation.set(-.3, 0, -.05); p.ra.rotation.set(-.3, 0, .05);
    return g;
  }

  INMATES.def({
    key: 'squatter', num: '077', name: 'ЖИЛЕЦ', en: 'THE SQUATTER', cls: 'ДРЕМЛЮЩИЙ', hp: 450, speed: SPEED, chase: CHASE, color: '#c8b890',
    difficulty: 2, minNight: 3, eye: 1.5, darkSight: 6,
    alert: ['ПОСТУПАЮТ СООБЩЕНИЯ О НЕЗНАКОМЦЕ, КОТОРЫЙ ПРОНИКАЕТ В ДОМА И ПРЯЧЕТСЯ В ШКАФАХ И КЛАДОВЫХ. НЕБРИТЫЙ, В ГРЯЗНОЙ МАЙКЕ И ПИЖАМНЫХ ШТАНАХ.',
      'КОГДА ЖИЛЬЦЫ ЧУВСТВУЮТ СЕБЯ В БЕЗОПАСНОСТИ, КОГДА ОНИ ЧУВСТВУЮТ СЕБЯ ЗАЩИЩЁННЫМИ, — ОН ПОКИДАЕТ СВОЁ УКРЫТИЕ И НАПАДАЕТ.',
      'ПРОВЕРЯЙТЕ КАЖДОЕ УКРЫТИЕ, ПРЕЖДЕ ЧЕМ ВОЙТИ.'],
    tip: 'Перед тем как спрятаться, посвети фонарём в щель шкафа: если блеснули глаза — там Жилец, туда нельзя. В 2:00 он вырвется наружу и погонится — прячься в другой шкаф или стреляй.',
    model,
    init(m) { m.sq = { deco: [], eyes: null, built: 0 }; buildDeco(m); },
    cleanup(m) {
      const C = m.sq; if (!C) return; dropEyes(m);
      for (const d of C.deco) { if (d.g.parent) d.g.parent.remove(d.g); d.g.traverse(o => { if (o.isMesh) o.geometry.dispose(); }); }
      C.deco = []; if (!INM.some(q => q !== m && !q.gone && q.type === 'squatter')) delete WS[KEY];
    },
    spawn(m) {
      patchNav(m);
      const free = WORLD.hides.filter(h => !(WS[h.id] && WS[h.id].by)), h = pick(free.length ? free : WORLD.hides);
      Object.assign(m.mem, { hide: h.id, ph: 1, k: 0, warn: 0 }); m.vis = 0; m.state = 'lurk'; m.p.set(h.pos.x, -60, h.pos.z);
      wsSet(KEY, { h: h.id, ph: 1, warn: 0, k: 0 });
      m.damage = function (n, by) { if (this.mem.ph === 2) Inmate.prototype.damage.call(this, n, by); };   // в шкафу неуязвим
    },
    tick,
    anim(m, dt, moving) {
      if (!m.sq) m.sq = { deco: [], eyes: null, built: 0 };
      buildDeco(m); eyesFrame(m, dt);
      const p = m.model.userData.parts, M = m.model, t = m.t, a = m.a;
      for (const k of ['ll', 'rl', 'la', 'ra']) p[k].rotation.set(0, 0, 0);
      let hunch = .3, hx = -.32, bob = 0;
      if (a === 4) {            // вырывается: присел, руки вперёд-в стороны
        hunch = .62; hx = -.6; bob = -.14; p.la.rotation.set(-1.7, 0, -.45); p.ra.rotation.set(-1.7, 0, .45); p.ll.rotation.x = -.55; p.rl.rotation.x = .35;
      } else if (a === 2) {     // оглушён
        hunch = .75; hx = .35; bob = -.08; p.la.rotation.set(-.6, 0, -.1); p.ra.rotation.set(-.5, 0, .1); p.ll.rotation.x = -.25;
      } else if (a === 1) {     // погоня: размашистый бег на полусогнутых, руки болтаются
        const s = Math.sin(m.walkT); hunch = .48; hx = -.5; bob = Math.abs(Math.cos(m.walkT)) * .07;
        p.ll.rotation.x = s * .9; p.rl.rotation.x = -s * .9; p.la.rotation.set(-.5 - s * 1.0, 0, -.25); p.ra.rotation.set(-.5 + s * 1.0, 0, .25);
      } else {                  // обход: шаркающая походка, голова подёргивается
        const s = moving ? Math.sin(m.walkT) : 0; p.ll.rotation.x = s * .5; p.rl.rotation.x = -s * .5;
        p.la.rotation.set(-.3 - s * .35, 0, -.06); p.ra.rotation.set(-.3 + s * .35, 0, .06); bob = moving ? Math.abs(Math.cos(m.walkT)) * .03 : 0;
        p.head.rotation.z = Math.sin(t * .9) * .15 + (Math.sin(t * 2.7) > .95 ? .25 : 0);
      }
      p.hip.rotation.x = hunch; p.head.rotation.x = hx; M.position.y += bob;
    },
    sound(m, dt) {
      if (!AU.ctx) return; const c = m.sc || (m.sc = { br: 1 + Math.random() * 2, rt: 1 }), S = WS[KEY];
      const ph = S ? S.ph : 2;
      if (S && c.k !== undefined && S.k > c.k && m.sq && m.sq.eyes) { const p = m.sq.eyes.wp; AU.play('bang', p); growl(p, .35, 1.1); }
      if (S) c.k = S.k;
      if (ph === 1 && m.sq && m.sq.eyes) {
        const wp = m.sq.eyes.wp, d = listenD(wp), heavy = !!S.warn, v = (heavy ? .16 : .1) * clamp(1 - (d - 1) / (heavy ? 9 : 6.5), 0, 1);
        if ((c.br -= dt) < 0) { c.br = heavy ? 1.7 + Math.random() * .4 : 3.3 + Math.random() * 1.2; if (v > .004) breath(wp, v, heavy); }
        if (heavy && (c.rt -= dt) < 0) { c.rt = 1.3 + Math.random() * 1.6; rattle(wp, .22); }
      }
      if (c.ph === 1 && ph === 2) growl(m.p.clone().add(new V3(0, 1.4, 0)), .5, 1.4);   // вырвался
      c.ph = ph;
      if (ph !== 2 || m.vis === 0 || m.p.y < -50) return;
      const feet = m.p.clone().add(new V3(0, .15, 0)), head = m.p.clone().add(new V3(0, 1.45, 0));
      const st = Math.floor(m.walkT / PI); if (st !== c.st) { c.st = st; slap(feet, m.a === 1 ? .2 : .12); }
      if (m.a === 1 && (c.pt = (c.pt ?? 0) - dt) < 0) { c.pt = .55 + Math.random() * .2; pant(head, .07); }
      if ((c.mt = (c.mt ?? 6) - dt) < 0) { c.mt = 7 + Math.random() * 7; if (m.a !== 1) AU.play('whisper', head); else growl(head, .2, .6); }
    },
  });
})();
