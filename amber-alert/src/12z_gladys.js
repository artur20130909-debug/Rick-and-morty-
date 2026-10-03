/* ================= ЗАКЛЮЧЁННАЯ 330: ГЛЭДИС (GLADYS) — незваная гостья ================= */
// Старушка в мешковатом полосатом цирковом комбинезоне, с седыми кудрями, румянами и крошечным велосипедом со звонком.
// Приезжает к крыльцу: звонок, смех, стук и мольбы субтитрами («Я ЗАБЛУДИЛАСЬ, ДОРОГУША… ВПУСТИ МЕНЯ?»).
// Открыли входную дверь — врывается сразу и охотится на открывшего (ближайший к двери). Не открыли — через ~60 с
// обходит дом и выбивает окно первого этажа. Внутри весь домашний свет зеленеет (только у клиентов, восстанавливается в cleanup),
// шаги — мокрое хлюпанье. Каждые ~15 с свет мигает и на 4 с становится КРАСНЫМ: кто ДВИЖЕТСЯ у неё на виду — цель погони.
// В зелёной фазе она замечает только тех, кто шевелится совсем рядом, и слышит бег. Касание — смерть (укрытия спасают).
// Состояние для клиентов: WS['GLADYS_<id>'] = { ph: 0 снаружи | 1 зелёный | 2 предупреждение | 3 красный, park: велосипед оставлен у крыльца }.
// m.a: 0 — бродит, 1 — погоня, 2 — оглушена, 3 — ждёт у двери, 4 — стучит, 5 — катит велосипед, 6 — смеётся,
//      7 — звонит в звонок, 8 — выбивает окно, 9 — красная фаза: замерла и высматривает.
(() => {
  const PORCH_T = 60, RED_EVERY = 15, WARN = .9, RED_DUR = 4, RED_GRACE = .6, FIRST_RED = 11;
  const V_ROAM = 3.0, V_CHASE = 4.6, REACH = 1.05;
  const GREEN = '#6dff8c', RED = '#ff2a2a';
  const SPOT = new V3(-.45, 0, 6.85);                 // у входной двери на крыльце
  const DOOR = new V3(-1, 1.1, 6.1);
  const BIKE_PARK = [-2.05, 7.05, .5];               // где она бросает велосипед (x, z, поворот)
  const keyW = m => 'GLADYS_' + m.id;
  const setW = (m, patch) => wsSet(keyW(m), patch);
  const PLEAS = [
    'Я ЗАБЛУДИЛАСЬ, ДОРОГУША… ВПУСТИ МЕНЯ?',
    'ТУК-ТУК! ЕСТЬ КТО ДОМА? Я ЖЕ СЛЫШУ, ЧТО ЕСТЬ…',
    'НА УЛИЦЕ ТАК ХОЛОДНО… ОТКРОЙ БАБУЛЕ ДВЕРЬ!',
    'Я ПРИНЕСЛА ВАМ ПЕЧЕНЬЕ, СОЛНЫШКО. ХИ-ХИ-ХИ!',
    'НУ ЖЕ, ДОРОГУША… Я ВСЕГО ЛИШЬ СТАРУШКА.',
    'КАК ЖЕ МНЕ НАЙТИ ДОРОГУ ДОМОЙ?.. ПУСТИ ПОГРЕТЬСЯ!',
  ];
  const PLEA_LIT = 'У ВАС ТАК УЮТНО ГОРИТ СВЕТ… ВПУСТИ МЕНЯ, ДОРОГУША!';
  const PLEA_FINAL = 'НЕ ХОЧЕШЬ ОТКРЫВАТЬ?.. НИЧЕГО, БАБУЛЯ ЗАЙДЁТ САМА!';
  const OPENED = 'ОЙ, СПАСИБО, ДОРОГУША! ХИ-ХИ-ХИ-ХИ!';
  const SPOTTED = ['ВИЖУ ТЕБЯ, ДОРОГУША!', 'КТО ЭТО ТАМ ШЕВЕЛИТСЯ?', 'НЕ УБЕГАЙ ОТ БАБУЛИ!', 'ПОПАЛСЯ, СОЛНЫШКО!'];
  const SEQ = ['bell', 'knock', 'say', 'laugh', 'knock', 'say', 'bell', 'say', 'laugh', 'knock', 'say'];
  const losF = b => !b.door || !(WS[b.door] && (WS[b.door].o || WS[b.door].b));

  /* ---------- навигация (хост) ---------- */
  // узлы окон в WORLD.nav — тупики, поэтому вместо них берём ближайший обычный узел той же стороны
  function regularNear(p, inside) {
    const N = WORLD.nav; let best = null, bd = 1e9;
    for (const k in N) { const n = N[k]; if (n.win || (n.room === 'out') === inside || Math.abs(n.p.y - p.y) > 1) continue; const d = Math.hypot(n.p.x - p.x, n.p.z - p.z); if (d < bd) { bd = d; best = k; } }
    return best;
  }
  function fixNode(k) { const n = WORLD.nav[k]; return n && n.win ? regularNear(n.p, n.room !== 'out') || k : k; }
  function goSafe(m, node) {
    node = fixNode(node); if (!node) return; m.goNode(node); if (m.path.length) return;
    const from = m.nodeNear(m.p); if (!from || from === node) return;
    const alt = fixNode(from); if (alt !== from) m.path = [{ node: alt }];
  }
  const insideNodes = () => Object.values(WORLD.nav).filter(n => n.room && n.room !== 'out' && !n.win);
  const inHouse = p => !!GAME.roomAt(new V3(p.x, p.y + 1, p.z));
  const moving = pl => pl.n > .05 || pl.sp > .3;
  // сторож: «идёт», но за 3 с не сдвинулась — сбросить путь, после трёх раз встать на ближайший узел
  function watchdog(m, dt) {
    const W = m.gl.wd; W.t += dt; W.mv += m.speedNow > 0 ? dt : 0; if (W.t < 3) return;
    const d = Math.hypot(m.p.x - W.x, m.p.z - W.z);
    if (W.mv > 1.5 && d < .3) { m.path = []; W.n++; if (W.n >= 3) { const k = fixNode(m.nodeNear(m.p)); if (k) m.p.copy(WORLD.nav[k].p); W.n = 0; } } else if (d >= .3) W.n = 0;
    W.t = 0; W.mv = 0; W.x = m.p.x; W.z = m.p.z;
  }

  /* ---------- поведение (хост) ---------- */
  function startChase(m, pl, lock, text) {
    const G = m.gl; m.state = 'chase'; m.chaseId = pl.id; G.lock = lock; m.lastSeen = new V3(pl.x, pl.y, pl.z); m.lostT = 0; m.path = []; G.rp = 0;
    if (!G.park) { G.park = 1; setW(m, { park: 1 }); }
    if (text) GAME.fxAll('say', m.p.clone().add(new V3(0, 1.5, 0)), { text, voice: 'gladys' });
  }
  // кто-то открыл (или выбил) входную дверь — врывается к ближайшему к двери
  function rush(m) {
    let best = null, bd = 1e9;
    for (const pl of GAME.alivePlayers()) { if (pl.hid) continue; const d = Math.hypot(pl.x - DOOR.x, pl.z - DOOR.z) + Math.abs(pl.y) * 2; if (d < bd) { bd = d; best = pl; } }
    if (best) startChase(m, best, 9, OPENED);
    else { GAME.fxAll('say', m.p.clone().add(new V3(0, 1.5, 0)), { text: OPENED, voice: 'gladys' }); m.state = 'roam'; m.path = []; if (!m.gl.park) { m.gl.park = 1; setW(m, { park: 1 }); } }
  }
  function seenOutside(m) {
    let best = null;
    for (const pl of GAME.alivePlayers()) { if (pl.hid || inHouse(new V3(pl.x, pl.y, pl.z))) continue; if (!m.canSee(pl, 14)) continue; const d = Math.hypot(pl.x - m.p.x, pl.z - m.p.z); if (!best || d < best.d) best = { pl, d }; }
    return best && best.pl;
  }
  function nextPlea(G) {
    const lit = GAME.power() && ((WS.L_hall && WS.L_hall.on) || (WS.L_living && WS.L_living.on));
    if (lit && !G.litSaid && G.k > 3) { G.litSaid = 1; return PLEA_LIT; }
    return PLEAS[(G.pi++) % PLEAS.length];
  }
  function porch(m, dt) {
    const G = m.gl; m.yaw = PI;
    if (G.aT > 0) { G.aT -= dt; if (G.aT <= 0) m.a = 3; } else m.a = 3;
    if (G.t >= G.next && G.t < PORCH_T - 5) {
      const ev = SEQ[G.k++ % SEQ.length]; G.next = G.t + 2.6 + Math.random() * 1.8;
      if (ev === 'bell') { m.a = 7; G.aT = 1.1; }
      else if (ev === 'knock') { m.a = 4; G.aT = 1.1; GAME.fxAll('knock', DOOR, { n: 3 }); }
      else if (ev === 'laugh') { m.a = 6; G.aT = 1.4; }
      else { GAME.fxAll('say', m.p.clone().add(new V3(0, 1.5, 0)), { text: nextPlea(G), voice: 'gladys' }); G.next += 1.6; }
    }
    if (G.t > PORCH_T - 4 && !G.fin) { G.fin = 1; GAME.fxAll('say', m.p.clone().add(new V3(0, 1.5, 0)), { text: PLEA_FINAL, voice: 'gladys' }); m.a = 6; G.aT = 1.8; }
    if (G.t > PORCH_T) { m.state = 'toWin'; m.path = [{ node: 'porch' }]; G.wphase = 0; G.park = 1; setW(m, { park: 1 }); }
  }
  // обход дома к окну первого этажа: крыльцо → внешний узел у окна → окно (взлом) → ближайший узел внутри
  function toWindow(m, dt) {
    const G = m.gl;
    if (G.wphase === 0) {
      m.a = 0; if (!m.follow(dt, V_ROAM)) return;
      const wins = HOUSE.entries.filter(e => e.kind === 'window' && WORLD.nav['wo_' + e.id] && WORLD.nav['wi_' + e.id]);
      if (!wins.length) { m.state = 'roam'; m.path = []; goSafe(m, 'foyer'); return; }
      const e = pick(wins.sort((a, b) => a.out.distanceTo(m.p) - b.out.distanceTo(m.p)).slice(0, 4)); G.win = e.id;
      m.goNode(regularNear(e.out, false)); m.path.push({ node: 'wo_' + e.id }, { node: 'wi_' + e.id, via: 'win:' + e.id }, { node: regularNear(e.in, true) });
      G.wphase = 1; return;
    }
    const st = m.path[0], breaking = st && st.via && WS[G.win] && !WS[G.win].b && m.p.distanceTo(WORLD.nav['wo_' + G.win].p) < .4;
    if (breaking && !G.brSaid) { G.brSaid = 1; GAME.fxAll('say', m.p.clone().add(new V3(0, 1.5, 0)), { text: 'ХИ-ХИ… БАБУЛЯ УЖЕ ИДЁТ!', voice: 'gladys' }); }
    m.a = breaking ? 8 : 0;
    if (m.follow(dt, V_ROAM)) { m.state = 'roam'; m.path = []; }
  }
  function chase(m, dt) {
    const G = m.gl, pl = GAME.alivePlayers().find(q => q.id === m.chaseId);
    if (!pl || pl.hid) { if (pl) m.lastSeen = new V3(pl.x, pl.y, pl.z); m.state = pl ? 'investigate' : 'roam'; m.path = []; return; }
    G.lock -= dt; const vis = m.canSee(pl, 22);
    if (vis || G.lock > 0) { m.lastSeen.set(pl.x, pl.y, pl.z); m.lostT = 0; } else m.lostT += dt;
    m.a = 1; const tp = m.lastSeen, sp = V_CHASE * (G.lock > 0 ? 1.08 : 1);
    const dh = Math.hypot(tp.x - m.p.x, tp.z - m.p.z);
    const direct = vis && dh < 8 && Math.abs(tp.y - m.p.y) < 1.2 && WORLD.coll.los(new V3(m.p.x, m.p.y + 1, m.p.z), new V3(tp.x, m.p.y + 1, tp.z), losF);
    if (direct) { m.path = []; m.stepTo(tp, dt, sp); }
    else { G.rp -= dt; if (!m.path.length || G.rp <= 0) { goSafe(m, m.nodeNear(tp)); G.rp = .8; } if (m.follow(dt, sp) && dh < 3) m.stepTo(tp, dt, sp); }
    if (m.lostT > 5) { m.state = 'investigate'; m.path = []; }
  }
  function inside(m, dt) {
    const G = m.gl;
    // цикл света: зелёный → предупреждение → КРАСНЫЙ 4 с → зелёный
    if (G.in) {
      G.cyc += dt; let ph = G.ph;
      if (ph === 1 && G.cyc > G.green - WARN) ph = 2;
      if (ph === 2 && G.cyc > G.green) { ph = 3; G.cyc = 0; }
      if (ph === 3 && G.cyc > RED_DUR) { ph = 1; G.cyc = 0; G.green = RED_EVERY; }
      if (ph !== G.ph) { G.ph = ph; setW(m, { ph }); }
    } else if (inHouse(m.p)) { G.in = 1; G.ph = 1; G.cyc = 0; G.green = FIRST_RED; setW(m, { ph: 1 }); }
    const red = G.ph === 3;
    // восприятие
    if (red && G.cyc > RED_GRACE) {
      let best = null; for (const pl of GAME.alivePlayers()) { if (pl.hid || !moving(pl) || !m.canSee(pl, 20)) continue; const d = Math.hypot(pl.x - m.p.x, pl.z - m.p.z); if (!best || d < best.d) best = { pl, d }; }
      if (best && (m.state !== 'chase' || m.chaseId !== best.pl.id)) { const cur = m.state === 'chase' && GAME.alivePlayers().find(q => q.id === m.chaseId); if (!cur || Math.hypot(cur.x - m.p.x, cur.z - m.p.z) > best.d) startChase(m, best.pl, 2, pick(SPOTTED)); }
    } else if (m.state !== 'chase') {
      for (const pl of GAME.alivePlayers()) {
        if (pl.hid) continue; const d = Math.hypot(pl.x - m.p.x, pl.z - m.p.z);
        if ((moving(pl) && d < 5.5 || d < 2.3) && m.canSee(pl, 6)) { startChase(m, pl, 0, null); break; }
        if (m.hears(pl) && m.state !== 'investigate') { m.state = 'investigate'; m.lastSeen = new V3(pl.x, pl.y, pl.z); m.path = []; }
      }
    }
    if (m.state === 'chase') chase(m, dt);
    else if (red) { m.a = 9; m.speedNow = 0; m.yaw += dt * 1.2; }        // замерла и оглядывается
    else if (m.state === 'investigate' && m.lastSeen) { m.a = 0; if (!m.path.length) goSafe(m, m.nodeNear(m.lastSeen)); if (m.follow(dt, V_ROAM * 1.15)) { m.state = 'roam'; m.path = []; } }
    else { m.state = 'roam'; m.a = 0; if (!m.path.length) goSafe(m, pick(insideNodes()).id); m.follow(dt, V_ROAM); }
    watchdog(m, dt);
    m.tryKill(REACH);
  }

  /* ---------- модель ---------- */
  let SM = null;
  const stripeMat = () => SM || (SM = new THREE.MeshLambertMaterial({ map: canvasTex('gl_stripe', 64, 64, g => { for (let i = 0; i < 8; i++) { g.fillStyle = i % 2 ? '#efe2c4' : '#b8283c'; g.fillRect(i * 8, 0, 8, 64); } }) }));
  function limb(g, w, h, d, m, x, y, z) { const p = new THREE.Group(); p.position.set(x, y, z); const b = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m); b.position.y = -h / 2; p.add(b); g.add(p); return p; }
  // крошечный детский велосипед (вдоль +Z), колёса r=.2; руль спереди на высоте ~.7
  function bike() {
    const b = new THREE.Group(), fr = mat('#2f8fd8'), tire = mat('#1a1a1a'), chrome = mat('#c8ccd2', { emissive: '#151515' });
    for (const z of [-.3, .32]) { const w = new THREE.Mesh(new THREE.TorusGeometry(.19, .035, 6, 16), tire); w.position.set(0, .2, z); w.rotation.y = PI / 2; b.add(w); }
    MM.box(b, .05, .05, .56, '', 0, .44, 0, { mat: fr, rx: .12 });              // рама
    MM.box(b, .05, .34, .05, '', 0, .3, -.12, { mat: fr, rx: -.35 });            // подседельная
    MM.box(b, .05, .5, .05, '', 0, .44, .3, { mat: fr, rx: .25 });               // вилка
    MM.box(b, .13, .05, .22, '#6a1a2a', 0, .53, -.2);                            // седло
    MM.box(b, .44, .04, .04, '', 0, .7, .36, { mat: chrome });                   // руль
    MM.cyl(b, .045, .045, .05, '', .15, .73, .36, { mat: mat('#e8c64a', { emissive: '#2a2000' }) }); // звонок
    MM.box(b, .22, .14, .16, '#d8c8a0', 0, .62, .5);                             // корзинка
    return b;
  }

  INMATES.def({
    key: 'gladys', num: '330', name: 'ГЛЭДИС', en: 'GLADYS', cls: 'НЕЗВАНАЯ ГОСТЬЯ',
    hp: 400, speed: V_ROAM, chase: V_CHASE, color: '#4dd870', difficulty: 1, minNight: 1, eye: 1.5, darkSight: 4, canHear: true, directive: 'NO_DOOR',
    alert: [
      'ОЧЕВИДЦЫ ОПИСЫВАЮТ ПОЖИЛУЮ ЖЕНЩИНУ В МЕШКОВАТОМ ЦИРКОВОМ КОСТЮМЕ, БРОДЯЩУЮ ПО ЗАДНИМ ДВОРАМ, — ЗАКЛЮЧЁННАЯ 330.',
      'ЕСЛИ ВЫ СЛЫШИТЕ ВЕЛОСИПЕДНЫЙ ЗВОНОК ИЛИ ПРОНЗИТЕЛЬНЫЙ СМЕХ У СВОЕГО КРЫЛЬЦА — ПОГАСИТЕ ВЕСЬ СВЕТ И СПРЯЧЬТЕСЬ.',
      'НЕ ОТКРЫВАЙТЕ ДВЕРЬ ТОМУ, КТО ГОВОРИТ, ЧТО ЗАБЛУДИЛСЯ.',
    ],
    tip: 'Не открывай ей дверь. Свет стал красным — замри: она видит только тех, кто двигается.',
    model() {
      const g = new THREE.Group(), p = { g }; g.userData.parts = p; g.rotation.order = 'YXZ';
      const SK = '#ecd0b8', ST = stripeMat(), legH = .66, torH = .64, W = .66, top = legH + torH;
      // мешковатые полосатые штанины и огромные красные туфли
      p.ll = limb(g, .28, legH, .3, ST, -.16, legH, 0); p.rl = limb(g, .28, legH, .3, ST, .16, legH, 0);
      for (const l of [p.ll, p.rl]) MM.box(l, .24, .13, .42, '#b01e2a', 0, -legH + .02, .07);
      // туловище-комбинезон с животиком, пуговицы-помпоны, жабо
      p.torso = MM.box(g, W, torH, .42, '', 0, legH + torH / 2, 0, { mat: ST });
      MM.box(g, W + .06, .26, .46, '', 0, legH + .1, .01, { mat: ST });
      [['#ffd23a', .46], ['#3a8aff', .3], ['#3ac85a', .14]].forEach(([c, y]) => MM.sph(g, .055, c, 0, legH + y, .225, { seg: 8, seg2: 6 }));
      MM.cyl(g, .36, .4, .07, '#f6f2ea', 0, top - .01, 0, { seg: 12 });
      MM.cyl(g, .3, .33, .06, '#f2b8c8', 0, top + .04, 0, { seg: 12 });
      // руки в полосатых рукавах, белые перчатки
      p.la = limb(g, .17, .58, .19, ST, -(W / 2 + .09), top - .06, 0); p.ra = limb(g, .17, .58, .19, ST, W / 2 + .09, top - .06, 0);
      for (const a of [p.la, p.ra]) MM.box(a, .15, .15, .16, '#f4f4f0', 0, -.64, 0);
      // голова
      const h = p.head = new THREE.Group(); h.position.set(0, top + .03, 0); g.add(h); p.headH = top;
      MM.box(h, .44, .44, .42, SK, 0, .23, 0);
      MM.box(h, .06, .09, .07, '#dcb49a', 0, .2, .23);                                   // нос
      for (const s of [-1, 1]) MM.sph(h, .072, '#ee5472', s * .155, .155, .2, { sz: .35, seg: 10, seg2: 8 });          // румяна
      const eyeW = mat('#fbfbf4');
      for (const s of [-1, 1]) { MM.sph(h, .058, '', s * .1, .29, .2, { mat: eyeW, seg: 8, seg2: 6, sz: .5 }); MM.sph(h, .027, '#141414', s * .1, .29, .23, { seg: 6, seg2: 5 }); }
      const glassM = mat('#3a2a1a');
      for (const s of [-1, 1]) { const r = new THREE.Mesh(new THREE.TorusGeometry(.078, .013, 5, 14), glassM); r.position.set(s * .1, .29, .235); h.add(r); }
      MM.box(h, .06, .015, .015, '', 0, .3, .24, { mat: glassM });
      MM.box(h, .2, .04, .02, '#f4efe0', 0, .085, .214);                                 // зубы
      for (let i = -2; i <= 2; i++) MM.box(h, .062, .034, .03, '#8a0c1e', i * .052, .055 + i * i * .011, .216, { rz: i * .28 }); // широкая накрашенная улыбка
      MM.box(h, .12, .02, .02, '#9a9a96', -.1, .37, .215, { rz: .15 }); MM.box(h, .12, .02, .02, '#9a9a96', .1, .37, .215, { rz: -.15 }); // брови
      // седые кудри (пушистая копна)
      const HA = mat('#c9c9c2'), HB = mat('#a9a9a2');
      for (const [x, y, z, r, k] of [[0, .5, -.02, .2, 0], [-.2, .43, .02, .15, 1], [.2, .43, .02, .15, 1], [-.26, .27, -.05, .14, 0], [.26, .27, -.05, .14, 0], [0, .38, -.2, .19, 1], [-.15, .52, -.13, .14, 0], [.15, .52, -.13, .14, 1], [-.25, .1, -.1, .12, 1], [.25, .1, -.1, .12, 0], [0, .22, -.24, .17, 0]])
        MM.sph(h, r, '', x, y, z, { mat: k ? HB : HA, seg: 7, seg2: 6 });
      // велосипед справа: правая рука на руле
      const bk = bike(); bk.position.set(.52, 0, .05); g.add(bk); p.ra.rotation.x = -.42; p.ra.rotation.z = .08;
      g.userData.gl = { bike: bk };
      return g;
    },
    spawn(m) {
      m.state = 'arrive'; m.p.copy(WORLD.nav.street.p).add(new V3(.4, 0, 1.5)); m.yaw = PI; m.goNode('porch');
      m.gl = { t: 0, k: 0, pi: 0, next: .5, aT: 0, park: 0, in: 0, ph: 0, cyc: 0, green: FIRST_RED, lock: 0, rp: 0, wd: { t: 0, x: m.p.x, z: m.p.z, n: 0, mv: 0 } };
      setW(m, { ph: 0, park: 0 });
    },
    tick(m, dt) {
      const G = m.gl; if (!G || m.gone) return; G.t += dt; m.speedNow = 0;
      if (m.stun > 0) { m.stun -= dt; m.a = 2; return; }
      const S = m.state;
      if (S === 'arrive' || S === 'porch' || S === 'toWin') {
        const d = WS.D_front; if (d && (d.o || d.b)) { rush(m); return; }
        const o = seenOutside(m); if (o) { startChase(m, o, 2, 'КТО ЭТО ТУТ ГУЛЯЕТ ПО НОЧАМ?..'); return; }
        if (S === 'arrive') { m.a = 5; if (m.path.length) m.follow(dt, 2.4); else if (m.stepTo(SPOT, dt, 1.6)) { m.state = 'porch'; G.t = 0; G.next = .4; m.yaw = PI; } }
        else if (S === 'porch') porch(m, dt);
        else { toWindow(m, dt); watchdog(m, dt); }
        m.tryKill(REACH); return;
      }
      inside(m, dt);
    },
    init(m) {
      m.glL = new Map(); m.glCol = null; m.glS = { a: -1, ph: 0, st: 0, lp: m.p.clone(), v: 0, gig: 6 + Math.random() * 6 };
      const b = m.glBike = bike(); b.position.set(BIKE_PARK[0], .25, BIKE_PARK[1]); b.rotation.set(0, BIKE_PARK[2], .35); b.visible = false; R.scene.add(b);
    },
    cleanup(m) {
      tint(m, null);
      if (m.glO) { m.glO.remove(); m.glO = null; }
      if (m.glBike) { R.scene.remove(m.glBike); m.glBike = null; }
    },
    anim(m, dt, moving) {
      const g = m.model, p = g.userData.parts, U = g.userData.gl, a = m.a, t = m.t;
      // свет в доме и красная вспышка — у каждого клиента
      const w = WS[keyW(m)], ph = w ? w.ph | 0 : 0;
      const col = ph === 3 ? RED : ph === 2 ? ((t * 9 | 0) % 2 ? RED : GREEN) : ph === 1 ? GREEN : null;
      if (col !== m.glCol) { tint(m, col); m.glCol = col; }
      overlay(m, ph === 3 ? 1 : ph === 2 ? .45 : 0);
      if (m.glBike) m.glBike.visible = !!(w && w.park);
      // поза
      const bikeOn = a >= 3 && a <= 7; U.bike.visible = bikeOn;
      MM.walk(p, m.walkT, moving ? (a === 1 ? .85 : .45) : 0);
      g.rotation.x = 0; g.rotation.z = moving ? Math.sin(m.walkT) * .06 : 0;      // переваливается с ноги на ногу
      p.head.rotation.set(0, 0, Math.sin(t * 1.6) * .1); p.la.rotation.z = -.1; p.ra.rotation.z = .1;
      if (bikeOn) { p.ra.rotation.x = -.42; p.ra.rotation.z = .08; }
      if (a === 1) { g.rotation.x = .16; p.la.rotation.x = p.ra.rotation.x = -1.45; p.la.rotation.z = .1; p.ra.rotation.z = -.1; p.head.rotation.set(-.15, 0, Math.sin(t * 9) * .12); }
      else if (a === 2) { g.rotation.z = Math.sin(t * 3) * .14; p.head.rotation.set(.3, 0, .4); p.la.rotation.x = Math.sin(t * 4) * .4; p.ra.rotation.x = -Math.sin(t * 4) * .4; }
      else if (a === 3) { p.head.rotation.set(0, 0, .25 + Math.sin(t * 1.2) * .1); p.la.rotation.x = -.2; }
      else if (a === 4) { p.la.rotation.x = -1.75 + Math.abs(Math.sin(t * 10)) * .35; p.la.rotation.z = .25; p.head.rotation.set(-.05, 0, .15); }
      else if (a === 6) { p.head.rotation.set(-.45 + Math.sin(t * 22) * .06, 0, Math.sin(t * 11) * .1); p.la.rotation.x = -.7; p.la.rotation.z = .5; g.rotation.x = -.06 + Math.sin(t * 22) * .03; }
      else if (a === 7) { p.ra.rotation.z = .08 + Math.sin(t * 30) * .08; p.head.rotation.set(.1, 0, .2); p.la.rotation.x = -.3; }
      else if (a === 8) { p.la.rotation.x = -2.1 + Math.sin(t * 9) * .55; p.ra.rotation.x = -2.1 - Math.sin(t * 9) * .55; g.rotation.x = .1; }
      else if (a === 9) { p.head.rotation.set(-.08, Math.sin(t * 1.8) * .9, 0); p.la.rotation.x = p.ra.rotation.x = 0; }
    },
    sound(m, dt) {
      if (!AU.ctx) return;
      const C = m.glS, a = m.a, head = new V3(m.p.x, m.p.y + 1.45, m.p.z), feet = new V3(m.p.x, m.p.y + .1, m.p.z);
      const sp = m.p.distanceTo(C.lp) / Math.max(dt, 1e-3); C.lp.copy(m.p); C.v = damp(C.v, Math.min(sp, 10), 6, dt);
      if (a !== C.a) { if (a === 7) bellSnd(head, .09); if (a === 6) laugh(head, .5); if (a === 8 && C.a !== 8) laugh(head, .4); C.a = a; }
      const w = WS[keyW(m)], ph = w ? w.ph | 0 : 0;
      if (ph !== C.ph) { if (ph === 2) warnCue(); if (ph === 3) redCue(); if (ph === 1 && C.ph === 0) laugh(head, .55); C.ph = ph; }
      if (m.vis === 0 || m.p.y < -50) return;
      if (C.v > .3) {
        C.st -= dt;
        if (C.st <= 0) { if (a === 5) { AU.play('clock', feet); C.st = .12; } else { squish(feet, a === 1 ? .32 : .22); C.st = a === 1 ? .27 : .44; } }
      }
      // изредка хихикает, пока бродит по дому
      if (ph && (a === 0 || a === 9)) { C.gig -= dt; if (C.gig <= 0) { laugh(head, .3); C.gig = 9 + Math.random() * 9; } }
    },
  });

  /* ---------- свет и экран (у всех клиентов; всё возвращается в cleanup) ---------- */
  function tint(m, col) {
    const S = m.glL; if (!S) return;
    if (col) for (const L of WORLD.lamps) {
      if (!L || !L.bulb || S.has(L)) continue;
      const s = { color: L.color, mat0: L.bulb.material, cur: col }, bm = s.mat0.clone(), set0 = THREE.Color.prototype.set;
      bm.color.set = function (v) { return set0.call(this, s.cur && v === '#fff2c8' ? s.cur : v); };
      L.bulb.material = bm; s.bm = bm; S.set(L, s);
    }
    for (const [L, s] of S) {
      if (col) { s.cur = col; L.color = col; continue; }
      L.color = s.color; if (L.bulb && L.bulb.material === s.bm) L.bulb.material = s.mat0; s.bm.dispose();
    }
    if (!col) S.clear();
  }
  function overlay(m, k) {
    if (!k && !m.glO) return;
    let d = m.glO; if (!d) { d = m.glO = document.createElement('div'); d.style.cssText = 'position:fixed;inset:0;pointer-events:none;z-index:3;opacity:0;transition:opacity .2s;background:rgba(255,0,0,.07);box-shadow:inset 0 0 180px 50px rgba(255,16,16,.6)'; document.body.append(d); }
    const o = String(k); if (d.style.opacity !== o) d.style.opacity = o;
  }

  /* ---------- звуки (синтез, у всех клиентов) ---------- */
  function bellSnd(pos, v) { // «дзынь-дзынь» велосипедного звонка: две трели быстрых ударов
    const out = AU.at(pos), t0 = AU.t();
    for (let r = 0; r < 2; r++) for (let i = 0; i < 6; i++) {
      const t = t0 + r * .4 + i * .04, g = AU.env(out, t, v * (1 - i * .1), .001, .32);
      for (const [k, a] of [[1, 1], [1.48, .45], [2.7, .2]]) { const og = AU.ctx.createGain(); og.gain.value = a; og.connect(g); AU.osc('sine', 2180 * k, t, t + .36, og); }
    }
  }
  function laugh(pos, v) { // старческое «хи-хи-хи»: пила через две форманты + придыхание
    const c = AU.ctx, out = AU.at(pos), t0 = AU.t(), n = 6 + (Math.random() * 3 | 0), f0 = 560 + Math.random() * 120;
    for (let i = 0; i < n; i++) {
      const t = t0 + i * .145, f = f0 - i * 20 + Math.random() * 30, g = AU.env(out, t, v, .012, .1);
      const b1 = c.createBiquadFilter(); b1.type = 'bandpass'; b1.frequency.value = 2500; b1.Q.value = 3; b1.connect(g);
      const b2 = c.createBiquadFilter(); b2.type = 'bandpass'; b2.frequency.value = 900; b2.Q.value = 2; b2.connect(g);
      const o = AU.osc('sawtooth', f, t, t + .14, b1); o.connect(b2); o.frequency.linearRampToValueAtTime(f * .86, t + .12);
      AU.nz(out, t, .035, v * .35, 'highpass', 3200, 1, .004);
    }
  }
  function squish(pos, v) { // мокрый хлюп: всасывающий шум со сдвигом фильтра + «чпок»
    const out = AU.at(pos), t = AU.t(), n = AU.nz(out, t, .17, v, 'lowpass', 260, 4, .01); n.f.frequency.linearRampToValueAtTime(1500, t + .13);
    AU.nz(out, t + .07, .07, v * .55, 'bandpass', 1000 + Math.random() * 600, 7, .003);
    const o = AU.osc('sine', 200, t, t + .13, AU.env(out, t, v * .45, .004, .11)); o.frequency.exponentialRampToValueAtTime(75, t + .12);
  }
  function warnCue() { const t = AU.t(); const o = AU.osc('sawtooth', 220, t, t + .85, lp(AU.env(AU.sfx, t, .05, .5, .35), 900)); o.frequency.linearRampToValueAtTime(420, t + .8); }
  function redCue() { // красная вспышка: короткий диссонансный «гудок» (не позиционный — мигает весь дом)
    const t = AU.t(), d = lp(AU.env(AU.sfx, t, .08, .01, 1.1), 1400);
    for (const f of [311, 330, 466]) AU.osc('square', f, t, t + 1.2, d);
    AU.osc('sine', 62, t, t + .5, AU.env(AU.sfx, t, .25, .005, .45));
  }
  function lp(dest, f) { const b = AU.ctx.createBiquadFilter(); b.type = 'lowpass'; b.frequency.value = f; b.connect(dest); return b; }
})();
