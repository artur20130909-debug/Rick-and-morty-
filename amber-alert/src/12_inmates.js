/* ================= ЗАКЛЮЧЁННЫЕ: каркас ИИ + реестр. Каждый тип — отдельная запись INMATES.def({...}) ================= */
// Контракт типа заключённого:
//  key, num ('114'), name ('ТАНЦОВЩИЦА'), en ('THE DANCER'), cls (класс угрозы), hp, speed, chase, color
//  alert: [строки трансляции] — текст экстренного оповещения (первая строка добавляется автоматически)
//  tip: короткая подсказка «как выжить» (для HUD и камеры в лечебнице)
//  model(): THREE.Group — модель (ноги на y=0, смотрит в +Z)
//  spawn(m): необязательно — что делать при появлении (по умолчанию взлом через вход)
//  tick(m, dt): поведение на хосте каждый кадр (по умолчанию m.hunt(dt))
//  anim(m, dt): анимация модели у всех (по умолчанию шаги/покачивание), m.a — номер анимации из снимка
//  sound: функция (m) => звуковые подсказки (у всех клиентов, раз в кадр, по желанию)
//  difficulty: 1..3 (с какой сложности появляется), canHear (слышит шаги), lightFreeze...
const INMATES = {
  types: {}, list: [],
  def(t) { t.speed = t.speed || 2.6; t.chase = t.chase || 4.6; t.hp = t.hp || 200; t.difficulty = t.difficulty || 1; this.types[t.key] = t; this.list.push(t); return t; },
};
const INM = [];   // активные заключённые (у всех клиентов)
let INM_ID = 0;

/* ---- модельные помощники ---- */
const MM = {
  box(g, w, h, d, c, x, y, z, o = {}) { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), o.mat || mat(c, o.emissive ? { emissive: o.emissive } : {})); m.position.set(x, y, z); if (o.rx) m.rotation.x = o.rx; if (o.rz) m.rotation.z = o.rz; if (o.ry) m.rotation.y = o.ry; g.add(m); return m; },
  sph(g, r, c, x, y, z, o = {}) { const m = new THREE.Mesh(new THREE.SphereGeometry(r, o.seg || 12, o.seg2 || 10), o.mat || mat(c, o.emissive ? { emissive: o.emissive } : {})); m.position.set(x, y, z); if (o.sy) m.scale.y = o.sy; if (o.sx) m.scale.x = o.sx; if (o.sz) m.scale.z = o.sz; g.add(m); return m; },
  cyl(g, r1, r2, h, c, x, y, z, o = {}) { const m = new THREE.Mesh(new THREE.CylinderGeometry(r1, r2, h, o.seg || 10), o.mat || mat(c)); m.position.set(x, y, z); if (o.rx) m.rotation.x = o.rx; if (o.rz) m.rotation.z = o.rz; g.add(m); return m; },
  limb(g, w, h, c, x, y, z) { const p = new THREE.Group(); p.position.set(x, y, z); const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, w), mat(c)); m.position.y = -h / 2; p.add(m); g.add(p); return p; },
  // гуманоид: голова/торс/руки/ноги; возвращает части для анимации
  humanoid(o = {}) {
    const g = new THREE.Group(), s = o.s || 1, legH = (o.leg || .9) * s, torH = (o.torso || .75) * s, w = (o.w || .55) * s;
    const parts = { g };
    parts.ll = MM.limb(g, .2 * s, legH, o.pants || '#333', -.13 * s, legH, 0); parts.rl = MM.limb(g, .2 * s, legH, o.pants || '#333', .13 * s, legH, 0);
    parts.torso = MM.box(g, w, torH, .3 * s, o.shirt || '#555', 0, legH + torH / 2, 0);
    parts.la = MM.limb(g, .16 * s, (o.arm || .85) * s, o.sleeve || o.shirt || '#555', -(w / 2 + .1 * s), legH + torH - .05 * s, 0); parts.ra = MM.limb(g, .16 * s, (o.arm || .85) * s, o.sleeve || o.shirt || '#555', (w / 2 + .1 * s), legH + torH - .05 * s, 0);
    parts.head = new THREE.Group(); parts.head.position.set(0, legH + torH, 0); g.add(parts.head);
    parts.headH = legH + torH; return parts;
  },
  eyes(g, x, y, z, gap, r, c = '#fff', glow) { for (const s of [-1, 1]) { const e = new THREE.Mesh(new THREE.SphereGeometry(r, 8, 6), glow ? new THREE.MeshBasicMaterial({ color: c }) : mat(c)); e.position.set(x + s * gap, y, z); g.add(e); } },
  walk(p, t, amp = .7) { if (!p.ll) return; const s = Math.sin(t) * amp; p.ll.rotation.x = s; p.rl.rotation.x = -s; if (p.la) p.la.rotation.x = -s * .8; if (p.ra) p.ra.rotation.x = s * .8; },
};

/* ---- экземпляр заключённого ---- */
class Inmate {
  constructor(type, id) {
    this.id = id; this.type = type; this.T = INMATES.types[type]; this.p = new V3(0, -60, 0); this.yaw = 0; this.a = 0; this.hp = this.T.hp; this.maxHp = this.T.hp;
    this.model = this.T.model(); this.model.traverse(o => { if (o.isMesh) o.userData.inmate = this; }); R.scene.add(this.model);
    this.walkT = 0; this.state = 'enter'; this.path = []; this.target = null; this.stun = 0; this.t = 0; this.tp = new V3().copy(this.p); this.speedNow = 0; this.mem = {}; this.gone = false;
  }
  dispose() { R.scene.remove(this.model); this.gone = true; }
  // ---- навигация (хост) ----
  nodeNear(p) { const N = WORLD.nav; let best = null, bd = 1e9; for (const k in N) { const n = N[k]; const d = n.p.distanceTo(p) + Math.abs(n.p.y - p.y) * 3; if (d < bd && (bd > 2 || WORLD.coll.los({ x: p.x, y: p.y + 1, z: p.z }, { x: n.p.x, y: n.p.y + 1, z: n.p.z }, b => !b.door))) { bd = d; best = k; } } return best; }
  route(toNode) {
    const N = WORLD.nav, from = this.nodeNear(this.p); if (!from || !toNode) return [];
    const dist = { [from]: 0 }, prev = {}, Q = new Set([from]);
    while (Q.size) { let u = null, ud = 1e9; for (const q of Q) if (dist[q] < ud) { ud = dist[q]; u = q; } Q.delete(u); if (u === toNode) break;
      for (const e of N[u].nb) { const d = ud + N[u].p.distanceTo(N[e.to].p) + (e.door && WS[e.door] && WS[e.door].l && !WS[e.door].b ? 6 : 0); if (dist[e.to] === undefined || d < dist[e.to]) { dist[e.to] = d; prev[e.to] = { u, e }; Q.add(e.to); } } }
    if (dist[toNode] === undefined) return [];
    const path = []; let c = toNode; while (c !== from) { const pr = prev[c]; path.unshift({ node: c, via: pr.e.door }); c = pr.u; } return path;
  }
  goNode(node) { this.path = this.route(node); this.goal = node; }
  // шаг по пути; возвращает true, если дошёл
  follow(dt, speed) {
    if (this.stun > 0) return false;
    const st = this.path[0]; if (!st) return true;
    // проход через дверь или окно
    if (st.via && !this.passVia(st.via, dt)) { this.speedNow = 0; return false; }
    const tgt = WORLD.nav[st.node].p; return this.stepTo(tgt, dt, speed) && (this.path.shift(), this.path.length === 0);
  }
  stepTo(tgt, dt, speed) {
    const dx = tgt.x - this.p.x, dz = tgt.z - this.p.z, d = Math.hypot(dx, dz);
    if (d < .25) { this.p.x = tgt.x; this.p.z = tgt.z; this.fixY(tgt.y); return true; }
    const s = Math.min(d, speed * dt); this.p.x += dx / d * s; this.p.z += dz / d * s; this.yaw = Math.atan2(dx, dz); this.speedNow = speed; this.fixY(tgt.y); return false;
  }
  fixY(hint) { const g = WORLD.coll.groundAt(this.p.x, this.p.z, .2, this.p.y + .5); this.p.y = g > -40 ? g : hint; }
  passVia(via, dt) {
    if (via.startsWith('win:')) { const id = via.slice(4); if (WS[id] && !WS[id].b) { this.mem.breakT = (this.mem.breakT || 0) + dt; if (this.mem.breakT > 1.6) { this.mem.breakT = 0; wsSet(id, { b: 1, c: 0 }); GAME.fxAll('glass', this.p); } return false; } return true; }
    const s = WS[via]; if (!s || s.o || s.b) return true;
    this.mem.doorT = (this.mem.doorT || 0) + dt;
    if (s.l) { if (this.mem.doorT > (this.T.doorTime || 1.1)) { this.mem.doorT = 0; this.mem.bangs = (this.mem.bangs || 0) + 1; GAME.fxAll('bang', this.p); CAMSHAKE(this.p, .6); if (this.mem.bangs >= (this.T.bangs || 4)) { this.mem.bangs = 0; wsSet(via, { b: 1, l: 0, o: 1 }); GAME.fxAll('doorClose', this.p); } } return false; }
    if (this.mem.doorT > .45) { this.mem.doorT = 0; wsSet(via, { o: 1 }); GAME.fxAll('doorOpen', this.p); return true; } return false;
  }
  // ---- восприятие (хост) ----
  headPos() { return new V3(this.p.x, this.p.y + (this.T.eye || 1.6), this.p.z); }
  canSee(pl, maxD = 22) {
    const pp = new V3(pl.x, pl.y + (pl.cr ? .9 : 1.4), pl.z), h = this.headPos(), d = h.distanceTo(pp); if (d > maxD) return false;
    if (pl.hid) return false;
    // в темноте видно ближе (если игрок без фонаря и свет в комнате выключен)
    const lit = pl.l || GAME.litAt(pp); if (!lit && d > (this.T.darkSight || 5)) return false;
    return WORLD.coll.los(h, pp, b => !b.door || !(WS[b.door] && (WS[b.door].o || WS[b.door].b)));
  }
  hears(pl) { if (!this.T.canHear && this.T.canHear !== undefined) return false; const d = this.p.distanceTo(new V3(pl.x, pl.y, pl.z)); return pl.n * 14 > d; }
  nearestAlive(filter) { let best = null, bd = 1e9; for (const pl of GAME.alivePlayers()) { if (filter && !filter(pl)) continue; const d = this.p.distanceTo(new V3(pl.x, pl.y, pl.z)) + Math.abs(pl.y - this.p.y) * 4; if (d < bd) { bd = d; best = pl; } } return best ? { pl: best, d: bd } : null; }
  // ---- стандартная охота: войти → бродить по комнатам → услышал/увидел → погоня → атака ----
  hunt(dt, o = {}) {
    if (this.stun > 0) { this.stun -= dt; this.speedNow = 0; this.a = 2; return; }
    const T = this.T; let seen = null;
    for (const pl of GAME.alivePlayers()) if (this.canSee(pl, o.sight || 22)) { const d = this.p.distanceTo(new V3(pl.x, pl.y, pl.z)); if (!seen || d < seen.d) seen = { pl, d }; }
    if (seen && this.state !== 'enter') { this.state = 'chase'; this.chaseId = seen.pl.id; this.lastSeen = new V3(seen.pl.x, seen.pl.y, seen.pl.z); this.lostT = 0; }
    else if (T.canHear !== false && this.state !== 'enter') for (const pl of GAME.alivePlayers()) if (this.hears(pl)) { this.state = 'investigate'; this.lastSeen = new V3(pl.x, pl.y, pl.z); break; }
    if (this.state === 'enter') { this.a = 0; if (!this.path.length && this.entry) this.goNode(this.nodeNear(this.entry.in)); if (this.follow(dt, o.speed || T.speed)) this.state = 'roam'; this.tryKill(o.reach || 1.1); return; }
    if (this.state === 'chase') {
      const pl = GAME.alivePlayers().find(q => q.id === this.chaseId); this.a = 1;
      if (!pl) { this.state = 'roam'; this.path = []; return; }
      if (seen && seen.pl.id === this.chaseId) { const tp = new V3(pl.x, pl.y, pl.z); if (Math.abs(tp.y - this.p.y) < 1.2 && seen.d < 9) { this.path = []; this.stepTo(tp, dt, o.chase || T.chase); } else { if (!this.path.length || (this.t % 1) < dt) this.goNode(this.nodeNear(tp)); this.follow(dt, o.chase || T.chase); } }
      else { this.lostT += dt; if (!this.path.length) this.goNode(this.nodeNear(this.lastSeen)); this.follow(dt, (o.chase || T.chase) * .85); if (this.lostT > 6) { this.state = 'roam'; this.path = []; } }
    } else if (this.state === 'investigate') { this.a = 0; if (!this.path.length) this.goNode(this.nodeNear(this.lastSeen)); if (this.follow(dt, (o.speed || T.speed) * 1.2)) this.state = 'roam'; }
    else { this.a = 0; if (!this.path.length) { const rooms = Object.values(WORLD.nav).filter(n => n.room && n.room !== 'out'); this.goNode(pick(rooms).id); } this.follow(dt, o.speed || T.speed); }
    this.tryKill(o.reach || 1.1);
  }
  tryKill(reach) { for (const pl of GAME.alivePlayers()) { if (pl.hid && !this.T.pullsHidden) continue; const d = Math.hypot(pl.x - this.p.x, pl.z - this.p.z); if (d < reach && Math.abs(pl.y - this.p.y) < 1.4) GAME.killPlayer(pl.id, this); } }
  // ---- урон (хост) ----
  damage(n, by) { if (this.T.immortal) { GAME.toastAll(this.T.name + ' не берёт урон!'); return; } this.hp -= n; this.stun = Math.max(this.stun, .4); if (this.hp <= 0) GAME.inmateDied(this, by); }
  // ---- клиентская сторона ----
  applySnap(s) { this.tp.set(s[2], s[3], s[4]); this.tyaw = s[5]; this.a = s[6]; this.hp = s[7]; this.vis = s[8]; if (this.p.y < -50) { this.p.copy(this.tp); this.yaw = this.tyaw; } }
  render(dt, isHost) {
    if (!isHost) { this.p.lerp(this.tp, 1 - Math.exp(-10 * dt)); this.yaw += angDiff(this.yaw, this.tyaw || 0) * (1 - Math.exp(-10 * dt)); }
    const m = this.model; m.position.copy(this.p); m.rotation.y = this.yaw; m.visible = this.vis !== 0 && this.p.y > -50;
    const moving = isHost ? this.speedNow > .1 : this.p.distanceToSquared(this.tp) > .0004 || this.a === 1;
    this.walkT += dt * (moving ? (this.a === 1 ? 11 : 6) : 0);
    if (this.T.anim) this.T.anim(this, dt, moving); else if (m.userData.parts) MM.walk(m.userData.parts, this.walkT, moving ? .7 : 0);
    if (this.T.sound) this.T.sound(this, dt);
    this.t += dt;
  }
}
function CAMSHAKE(pos, k) { for (const lp of LOCALS) { const d = lp.cam.position.distanceTo(pos); if (d < 10) lp.shake = Math.max(lp.shake, k * (1 - d / 10)); } }

/* ================= ОБРАЗЦЫ ================= */
INMATES.def({
  key: 'seeker', num: '404', name: 'ИСКАТЕЛЬ', en: 'THE SEEKER', cls: 'ИГРОК В ПРЯТКИ', hp: 260, speed: 2.4, chase: 5.0, color: '#e8e2d8', difficulty: 1,
  alert: ['ТАКТИЧЕСКОЕ СКАНИРОВАНИЕ ЗАФИКСИРОВАЛО МАНЕРУ ОХОТЫ СУБЪЕКТА «ИСКАТЕЛЬ» — ЗАКЛЮЧЁННЫЙ 404.', 'СУБЪЕКТ ВЕДЁТ ОБРАТНЫЙ ОТСЧЁТ У ГЛАВНОГО ВХОДА, ПОСЛЕ ЧЕГО НАЧИНАЕТ ПОИСК. ОН ОТСЛЕЖИВАЕТ ЗВУК И СВЕТ.', 'ПОГАСИТЕ ВЕСЬ СВЕТ И СОХРАНЯЙТЕ ПОЛНУЮ НЕПОДВИЖНОСТЬ. НЕ ОТВЕЧАЙТЕ ЕМУ.'],
  tip: 'Свет выключен + не двигаться = он тебя не найдёт. Шкафы тоже спасают.',
  model() {
    const p = MM.humanoid({ shirt: '#e8e2d8', sleeve: '#e8e2d8', pants: '#d8d2c8', s: 1.08 }); const g = p.g; g.userData.parts = p;
    MM.box(p.head, .42, .5, .42, '#f4efe8', 0, .25, 0); MM.eyes(p.head, 0, .3, .21, .09, .05, '#111');
    const smile = MM.box(p.head, .26, .05, .02, '#7a1010', 0, .14, .215); MM.box(p.head, .44, .12, .44, '#2a2420', 0, .52, 0);
    for (const s of [-1, 1]) MM.box(g, .62, .06, .34, '#b8b0a2', 0, p.headH - .2 - (s + 1) * .12, 0); // ремни смирительной рубашки
    p.la.rotation.z = .1; return g;
  },
  spawn(m) { m.state = 'walkin'; m.count = 10; m.ct = 0; m.p.copy(WORLD.nav.street.p); m.goNode('foyer'); },
  tick(m, dt) {
    if (m.state === 'walkin') { m.a = 0; if (m.follow(dt, 2.2)) { m.state = 'count'; m.ct = 0; } return; }
    if (m.state === 'count') { m.a = 3; m.ct += dt; if (m.ct > 1.1) { m.ct = 0; GAME.fxAll('say', m.p, { text: ['ДЕСЯТЬ', 'ДЕВЯТЬ', 'ВОСЕМЬ', 'СЕМЬ', 'ШЕСТЬ', 'ПЯТЬ', 'ЧЕТЫРЕ', 'ТРИ', 'ДВА', 'ОДИН'][10 - m.count] + '…', voice: 'seeker' }); m.count--; if (m.count <= 0) { m.state = 'roam'; GAME.fxAll('say', m.p, { text: 'КТО НЕ СПРЯТАЛСЯ — Я НЕ ВИНОВАТ!', voice: 'seeker' }); } } return; }
    // видит только тех, кто светится или двигается
    const prey = GAME.alivePlayers().filter(pl => !pl.hid && (pl.n > .05 || pl.l || GAME.litAt(new V3(pl.x, pl.y + 1, pl.z))));
    if (prey.length) { const t = prey.reduce((a, b) => (Math.hypot(a.x - m.p.x, a.z - m.p.z) < Math.hypot(b.x - m.p.x, b.z - m.p.z) ? a : b)); m.a = 1; const tp = new V3(t.x, t.y, t.z); if ((m.t % .8) < dt || !m.path.length) m.goNode(m.nodeNear(tp)); if (m.path.length) m.follow(dt, m.T.chase); else m.stepTo(tp, dt, m.T.chase); }
    else { m.a = 0; if (!m.path.length) m.goNode(pick(Object.values(WORLD.nav).filter(n => n.room && n.room !== 'out')).id); m.follow(dt, m.T.speed); }
    for (const pl of GAME.alivePlayers()) if (!pl.hid && Math.hypot(pl.x - m.p.x, pl.z - m.p.z) < 1.1 && Math.abs(pl.y - m.p.y) < 1.4 && (pl.n > .05 || pl.l || GAME.litAt(new V3(pl.x, pl.y + 1, pl.z)))) GAME.killPlayer(pl.id, m);
  },
  anim(m, dt, moving) { const p = m.model.userData.parts; MM.walk(p, m.walkT, moving ? .6 : 0); if (m.a === 3) { p.la.rotation.x = p.ra.rotation.x = -2.3; p.la.rotation.z = -.3; p.ra.rotation.z = .3; } },
});
INMATES.def({
  key: 'doll', num: '042', name: 'ФАРФОРОВАЯ КУКЛА «ЛЮСИ»', en: 'THE PORCELAIN DOLL', cls: 'ДЕМОНИЧЕСКИЙ', hp: 120, speed: 0, chase: 0, color: '#f2e8e0', difficulty: 1, eye: .6,
  alert: ['ОЧЕВИДЦЫ ОПИСЫВАЮТ СТАРИННУЮ МАЛЕНЬКУЮ ФАРФОРОВУЮ КУКЛУ. ОНА КАЖЕТСЯ МИЛОЙ И БЕЗОБИДНОЙ И ЧАСТО СТОИТ В КОРИДОРАХ, СЛОВНО ЗАБЫТАЯ ИГРУШКА.', 'В ДВИЖЕНИИ ОНА ПЕРЕМЕЩАЕТСЯ С НЕВЕРОЯТНОЙ СКОРОСТЬЮ.', 'ЕСЛИ ВЫ ЗАМЕТИЛИ ЕЁ — НЕ ПОВОРАЧИВАЙТЕСЬ СПИНОЙ. ДЕРЖИТЕ ЕЁ В ПОЛЕ ЗРЕНИЯ И МЕДЛЕННО ОТСТУПАЙТЕ.'],
  tip: 'Пока на неё кто-то смотрит — она не двигается. Отвернёшься — рывок.',
  model() {
    const g = new THREE.Group(), p = { g }; g.userData.parts = p;
    MM.cyl(g, .12, .3, .5, '#f6e6ee', 0, .25, 0); MM.box(g, .26, .25, .16, '#e8b8c8', 0, .55, 0);
    p.head = new THREE.Group(); p.head.position.y = .68; g.add(p.head); MM.sph(p.head, .16, '#f4ece4', 0, .1, 0);
    MM.eyes(p.head, 0, .13, .13, .055, .035, '#151515'); MM.sph(p.head, .03, '#c86a7a', 0, .04, .15);
    for (const s of [-1, 1]) { MM.cyl(p.head, .05, .03, .32, '#e8c06a', s * .13, -.04, -.03); }
    MM.sph(p.head, .18, '#e8c06a', 0, .17, -.03, { sy: .6 });
    for (const s of [-1, 1]) { const a = MM.limb(g, .06, .3, '#f4ece4', s * .17, .64, 0); a.rotation.z = s * .2; }
    return g;
  },
  spawn(m) { const halls = ['hallM', 'hallS', 'hallU1', 'hallU2', 'hallU3', 'foyer']; m.p.copy(WORLD.nav[pick(halls)].p); m.state = 'still'; m.dash = 0; },
  tick(m, dt) {
    m.a = 0; const watched = GAME.anyoneWatching(m.p.clone().add(new V3(0, .5, 0)), 24);
    if (watched) { m.dash = 0; m.speedNow = 0; return; }
    const t = m.nearestAlive(pl => !pl.hid); if (!t) return;
    m.dash += dt; if (m.dash < .35) return;
    const tp = new V3(t.pl.x, t.pl.y, t.pl.z);
    if (!m.path.length || (m.t % .6) < dt) m.goNode(m.nodeNear(tp));
    if (m.path.length > 0 && t.d > 2.5) m.follow(dt, 9); else m.stepTo(tp, dt, 9);
    m.tryKill(.9);
  },
  anim(m, dt, moving) { m.model.rotation.z = moving ? Math.sin(m.t * 40) * .08 : 0; },
});
INMATES.def({
  key: 'tara', num: '901', name: 'I FEEL FANTASTIC («ТАРА»)', en: 'I FEEL FANTASTIC', cls: 'АНДРОИД', hp: 240, speed: 1.5, chase: 2.3, color: '#d8c8b8', difficulty: 1, lightFreeze: true,
  alert: ['ПОСТУПАЮТ СООБЩЕНИЯ О НЕИСПРАВНОМ ДОМАШНЕМ АНДРОИДЕ. ПЕРЕД ПОЯВЛЕНИЕМ ОНА СТУЧИТ В ДВЕРЬ И ОТКЛЮЧАЕТ ЭЛЕКТРИЧЕСТВО.', 'СУБЪЕКТ ПЕРЕДВИГАЕТСЯ ТОЛЬКО В ТЕМНОТЕ. ПОД ПРЯМЫМ СВЕТОМ ОНА НЕ МОЖЕТ ДВИГАТЬСЯ.', 'ВОССТАНОВИТЕ ПИТАНИЕ НА ЩИТКЕ И ДЕРЖИТЕ ЕЁ НА СВЕТУ. КОНТАКТ — СМЕРТЕЛЕН.'],
  tip: 'Включи щиток в гараже и свети на неё фонарём — на свету она замирает.',
  model() {
    const p = MM.humanoid({ shirt: '#b8a8d8', sleeve: '#d8c8b8', pants: '#8a7aa8', s: 1.05 }); const g = p.g; g.userData.parts = p;
    MM.box(p.head, .36, .44, .36, '#e8d8c8', 0, .22, 0); MM.eyes(p.head, 0, .28, .19, .085, .045, '#30d0ff', true);
    MM.box(p.head, .42, .2, .42, '#5a3a22', 0, .48, -.02); MM.box(p.head, .42, .5, .1, '#5a3a22', 0, .2, -.2);
    MM.box(p.head, .02, .2, .02, '#222', .1, .12, .185, { rz: .4 }); return g;
  },
  spawn(m) { m.state = 'knock'; m.kt = 0; m.p.copy(WORLD.nav.porch.p); },
  tick(m, dt) {
    if (m.state === 'knock') { m.kt += dt; m.a = 3; if (m.kt > .2 && !m.knocked) { m.knocked = 1; GAME.fxAll('knock', m.p, { n: 4 }); } if (m.kt > 5) { m.state = 'roam'; wsSet('FUSE', { on: 0 }); GAME.fxAll('powerdown', m.p); } return; }
    // на свету — замирает
    const head = m.p.clone().add(new V3(0, 1.2, 0)); if (GAME.litAt(head) || GAME.torchOn(head)) { m.a = 2; m.speedNow = 0; m.vis = 1; return; }
    if (m.t % 14 < dt && WS.FUSE.on && Math.random() < .5) { wsSet('FUSE', { on: 0 }); GAME.fxAll('powerdown', m.p); }
    m.hunt(dt, { sight: 30 });
  },
  anim(m, dt, moving) { const p = m.model.userData.parts; MM.walk(p, m.walkT, moving ? .5 : 0); p.head.rotation.z = m.a === 2 ? .35 : Math.sin(m.t * 3) * .08; if (m.a === 3) p.ra.rotation.x = -1.7 + Math.sin(m.t * 12) * .3; },
  sound(m, dt) { if (m.a !== 2 && m.speedNow !== 0 && Math.random() < dt * .6) AU.play('buzz', m.p, { d: .2 }); },
});
