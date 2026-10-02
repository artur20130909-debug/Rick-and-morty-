/* ================= ИГРА: сессия, лобби, день/ночь, оповещения, экономика, смерть ================= */
const DIFFS = {
  easy: { name: 'Лёгкая', nights: 5, apple: 18, day: 150, night: 150, mul: .9, tier: 1, amber: 40 },
  normal: { name: 'Средняя', nights: 7, apple: 25, day: 140, night: 165, mul: 1, tier: 2, amber: 90 },
  hard: { name: 'Сложная', nights: 10, apple: 37, day: 130, night: 180, mul: 1.15, tier: 3, amber: 180 },
  endless: { name: 'Бесконечный', nights: 9999, apple: 30, day: 130, night: 170, mul: 1, tier: 3, amber: 0, endless: true },
};
const MAPS = {
  house1990: { name: 'Дом 1990', tag: '3.0', weather: 'clear', diff: 'normal' },
  sunny: { name: 'Солнечные дни', tag: 'LEGACY', weather: 'clear', diff: 'easy' },
  rain: { name: 'Проливной дождь', tag: '2.0', weather: 'rain', diff: 'hard' },
  xmas: { name: 'Рождество 1990', tag: 'СОБЫТИЕ', weather: 'snow', diff: 'normal' },
};
const ITEMS = {
  battery: { name: 'Батарейки', icon: '🔋', price: 25, desc: 'Полный заряд фонарика' },
  shotgun: { name: 'Дробовик', icon: '🔫', price: 260, desc: 'Урон заключённым. 4 патрона' },
  shells: { name: 'Патроны ×4', icon: '🧨', price: 45, desc: 'Для дробовика' },
  beartrap: { name: 'Капкан', icon: '🪤', price: 70, desc: 'Ставится на пол, держит заключённого 6 с' },
  pepper: { name: 'Перцовый баллончик', icon: '🧯', price: 60, desc: 'Оглушает вблизи (3 заряда)' },
  stun: { name: 'Электрошокер', icon: '⚡', price: 130, desc: 'Оглушает на 4 с, перезарядка 20 с' },
  defib: { name: 'Дефибриллятор', icon: '💓', price: 200, desc: 'Мгновенно оживить товарища' },
  medkit: { name: 'Аптечка', icon: '🩹', price: 50, desc: '+60 здоровья' },
  motion: { name: 'Лампа с датчиком', icon: '💡', price: 65, desc: 'Зажигается, когда рядом кто-то есть' },
  tree: { name: 'Яблоня', icon: '🌳', price: 150, desc: 'Ещё одно дерево во дворе', farm: true },
  sprinkler: { name: 'Разбрызгиватель', icon: '💦', price: 120, desc: 'Яблоки растут вдвое быстрее', farm: true },
};
const CLASSES = {
  novice: { name: 'Новичок', price: 0, desc: 'Фонарик. Ничего лишнего.', items: [] },
  farmer: { name: 'Фермер', price: 120, desc: 'Срывает по 2 яблока, начинает с $60', items: [], money: 60 },
  hunter: { name: 'Охотник', price: 250, desc: 'Начинает с дробовиком', items: [['shotgun', 4]] },
  medic: { name: 'Медик', price: 220, desc: 'Начинает с дефибриллятором и аптечкой', items: [['defib', 1], ['medkit', 1]] },
  electric: { name: 'Электрик', price: 160, desc: 'Фонарь горит вдвое дольше, щиток включает мгновенно', items: [['battery', 1]] },
  runner: { name: 'Бегун', price: 160, desc: 'Выносливость +60%', items: [] },
};
const RANKS = ['Recruit', 'Documented', 'Field Operative', 'Cleared Personnel', 'Containment Unit', 'Research Unit', 'Anomalous Specialist', 'Black Ridge Operator', 'Classified', 'Amber Alert'];
const ALERT_HEAD = 'ГРАЖДАНСКИЕ ВЛАСТИ ОБЪЯВИЛИ ЧРЕЗВЫЧАЙНУЮ СИТУАЦИЮ В ВАШЕМ РАЙОНЕ.';
const ALERT_LEN = 34;

/* ---- профиль (на этом устройстве) ---- */
function loadProfile(k = 'aa_profile') { let p; try { p = JSON.parse(localStorage.getItem(k)); } catch (_) { } return Object.assign({ name: '', look: randomLook(), amber: 50, xp: 0, cls: 'novice', classes: ['novice'], seen: [], quests: {}, best: 0, wins: 0 }, p || {}); }
function saveProfile(p, k = 'aa_profile') { try { localStorage.setItem(k, JSON.stringify(p)); } catch (_) { } }
function levelOf(xp) { return Math.floor(Math.sqrt(xp / 40)); }
function rankOf(lvl) { return RANKS[Math.min(RANKS.length - 1, Math.floor(lvl / 10))]; }

const GAME = {
  scene: 'menu', players: {}, remotes: {}, st: { scene: 'menu' }, wsQueue: new Set(), sendT: 0, poseT: 0, pinfoDirty: false, trapN: 0, items: {}, profiles: [], ended: false,
  isHost() { return NET.role !== 'client'; },
  power() { return !WS.FUSE || !!WS.FUSE.on; },

  /* ======== запуск сессии ======== */
  begin(role, transport, localDefs) {
    NET.start(role, transport); this.players = {}; this.remotes = {}; this.st = { scene: 'lobby', booth: { map: 'house1990', diff: 'normal', cd: -1, idx: -1 } };
    LOCALS.length = 0;
    localDefs.forEach((d, i) => { const lp = new LocalPlayer(i, d.src, { id: d.id, name: d.prof.name, look: d.prof.look }); lp.prof = d.prof; lp.profKey = d.profKey; LOCALS.push(lp); });
    if (this.isHost()) { this.setScene('lobby'); }
    for (const lp of LOCALS) NET.toHost({ t: 'hello', pid: lp.id, name: lp.name, look: lp.look, cls: lp.prof.cls, lvl: levelOf(lp.prof.xp) });
    UI.show('play');
  },
  leave() { NET.stop(); for (const id in this.remotes) this.remotes[id].dispose(); this.remotes = {}; for (const lp of LOCALS) R.scene.remove(lp.avatar.root); LOCALS.length = 0; INM.forEach(m => m.dispose()); INM.length = 0; AU.hush(); this.scene = 'menu'; buildLobby(); UI.clearZones(); UI.closeEAS(); UI.closeModal(); UI.show('menu'); AU.ambient('lobby'); },
  peerJoined(peer) { },
  peerLeft(peer) { for (const id in this.players) if (this.players[id].peer === peer) { const nm = this.players[id].name; delete this.players[id]; this.toastAll(nm + ' вышел'); } this.pinfoDirty = true; },
  lostHost() { UI.toast('Связь с хостом потеряна'); setTimeout(() => this.leave(), 1500); },

  /* ======== сообщения: на хосте ======== */
  hostMsg(m, peer) {
    const P = this.players[m.pid];
    if (m.t !== 'hello' && (!P || (P.peer !== peer))) return;
    switch (m.t) {
      case 'hello': {
        const sp = this.spawnPoint(Object.keys(this.players).length);
        this.players[m.pid] = { id: m.pid, peer, name: String(m.name || 'Игрок').slice(0, 16), look: m.look, cls: m.cls || 'novice', lvl: m.lvl | 0, alive: true, hp: 100, money: 0, apples: 0, items: [], pose: { x: sp.x, y: sp.y, z: sp.z, yaw: 0, pitch: 0, sp: 0, cr: 0, l: 0, hid: 0, n: 0 }, votes: 0 };
        if (this.st.scene === 'house') { this.giveStart(this.players[m.pid]); if (this.st.phase === 'night') { this.players[m.pid].alive = false; this.players[m.pid].hp = 0; } } // вошёл посреди ночи — наблюдает до рассвета
        NET.toPeer(peer, { t: 'welcome', pid: m.pid, st: this.st, ws: WS, players: this.pinfoList(), spawn: [sp.x, sp.y, sp.z], inm: INM.map(i => [i.id, i.type]) });
        this.pinfoDirty = true; if (peer) this.toastAll(this.players[m.pid].name + ' присоединился');
        break; }
      case 'pose': P.pose = m.p; break;
      case 'use': { const it = WORLD.inter.get(m.id); if (!it || !it.use) return; if (it.cond && !it.cond(m.pid)) return; if (!P.alive) return; it.use(m.pid, m.hold); break; }
      case 'buy': this.buy(P, m.k); break;
      case 'sell': this.sell(P); break;
      case 'item': this.useItem(P, m); break;
      case 'vote': if (this.st.phase === 'alert' && !P.voted) { P.voted = 1; this.st.votes = (this.st.votes || 0) + 1; } break;
      case 'chat': NET.toAll({ t: 'chat', name: P.name, text: String(m.text).slice(0, 120) }); break;
      case 'look': P.look = m.look; P.cls = m.cls || P.cls; P.name = String(m.name || P.name).slice(0, 16); this.pinfoDirty = true; break;
      case 'booth': if (P.id === this.hostPid() || !this.st.booth.lockHost) { if (m.map) this.st.booth.map = m.map; if (m.diff) this.st.booth.diff = m.diff; } break;
      case 'unhide': { const h = WORLD.hides.find(q => WS[q.id] && WS[q.id].by === m.pid); if (h) this.toggleHide(m.pid, h); break; }
      case 'ready': break;
      case 'tolobby': if (P.id === this.hostPid()) this.setScene('lobby'); break;
    }
  },
  hostPid() { return LOCALS[0] ? LOCALS[0].id : null; },
  spawnPoint(i) { const s = WORLD.spawn; return s.length ? s[i % s.length].clone() : new V3(0, 0, 0); },
  pinfoList() { return Object.values(this.players).map(p => ({ id: p.id, name: p.name, look: p.look, cls: p.cls, lvl: p.lvl, alive: p.alive, hp: p.hp, money: p.money, apples: p.apples, items: p.items, stat: Math.round(p.static || 0) })); },
  alivePlayers() { return Object.values(this.players).filter(p => p.alive).map(p => Object.assign({ id: p.id }, p.pose)); },

  /* ======== сообщения: у клиента (и у хоста как «зрителя») ======== */
  clientMsg(m) {
    switch (m.t) {
      case 'welcome': {
        const lp = LOCALS.find(l => l.id === m.pid); if (!lp) return;
        if (!this.isHost()) { this.st = m.st; this.applyScene(m.st, m.ws); m.inm.forEach(([id, type]) => this.spawnInmateLocal(id, type)); }
        lp.setPose(m.spawn[0], m.spawn[1], m.spawn[2], 0); this.applyPlayers(m.players); break; }
      case 'players': this.applyPlayers(m.list); break;
      case 'snap': this.applySnap(m); break;
      case 'ws': for (const id in m.d) wsApply(id, m.d[id]); break;
      case 'scene': if (!this.isHost()) { this.st = m.st; this.applyScene(m.st, m.ws); } for (const lp of LOCALS) { const sp = m.spawns && m.spawns[lp.id]; if (sp) lp.setPose(sp[0], sp[1], sp[2], sp[3] || 0); lp.alive = true; lp.hidden = null; lp.spectate = null; } UI.sceneChanged(m.st.scene); break;
      case 'alert': UI.alert(m); break;
      case 'phase': if (!this.isHost()) Object.assign(this.st, m.st); UI.phase(m); this.onPhaseLocal(m); break;
      case 'fx': this.fxLocal(m); break;
      case 'kill': this.onKilled(m); break;
      case 'revive': { const lp = LOCALS.find(l => l.id === m.pid); if (lp) { lp.alive = true; lp.spectate = null; if (m.pos) lp.setPose(m.pos[0], m.pos[1], m.pos[2], lp.body.yaw); UI.toast('Тебя оживили!'); AU.play('heal'); } break; }
      case 'hidden': { const lp = LOCALS.find(l => l.id === m.pid); if (!lp) return; if (m.id) { const h = WORLD.hides.find(q => q.id === m.id); lp.hidden = h; lp.hideT = 0; lp.qte = null; AU.play('doorClose', h.pos); } else { const h = lp.hidden; lp.hidden = null; if (h) lp.setPose(h.out.x, h.out.y, h.out.z, h.yaw); AU.play('doorOpen'); } break; }
      case 'inm': if (!this.isHost()) { if (m.add) this.spawnInmateLocal(m.add, m.type); if (m.del) { const i = INM.findIndex(q => q.id === m.del); if (i >= 0) { INM[i].dispose(); INM.splice(i, 1); } } } break;
      case 'toast': UI.toast(m.text); break;
      case 'chat': UI.chat(m.name, m.text); break;
      case 'shopres': UI.shopResult(m); break;
      case 'end': UI.results(m); this.awardLocal(m); break;
    }
  },
  applyPlayers(list) {
    const me = new Set(LOCALS.map(l => l.id));
    for (const p of list) {
      if (me.has(p.id)) { const lp = LOCALS.find(l => l.id === p.id); lp.info = p; if (lp.alive && !p.alive) { } lp.alive = p.alive; continue; }
      let r = this.remotes[p.id]; if (!r) r = this.remotes[p.id] = new RemotePlayer(p);
      r.alive = p.alive; r.info = p; if (JSON.stringify(r.look) !== JSON.stringify(p.look)) { r.look = p.look; r.avatar.setLook(p.look); }
      if (r.name !== p.name) { r.name = p.name; }
      const tag = '[Lv ' + (p.lvl | 0) + ' · ' + rankOf(p.lvl | 0).toUpperCase() + '] ' + p.name, col = p.alive ? '#fff' : '#f55';
      if (r.tagKey !== tag + col) { r.tagKey = tag + col; r.avatar.setName(tag, col); }
    }
    for (const id in this.remotes) if (!list.find(p => p.id === id)) { this.remotes[id].dispose(); delete this.remotes[id]; }
    this.plist = list; UI.players(list);
  },
  applySnap(m) {
    if (!this.isHost()) { Object.assign(this.st, m.st); }
    for (const s of m.ps) { const r = this.remotes[s[0]]; if (r) r.setPose({ x: s[1], y: s[2], z: s[3], yaw: s[4], pitch: s[5], sp: s[6], cr: s[7], l: s[8], hid: s[9] }); }
    if (!this.isHost()) for (const e of m.en) { const i = INM.find(q => q.id === e[0]); if (i) i.applySnap(e); }
  },
  applyScene(st, ws) {
    if (st.scene === 'house') { buildHouse(); this.scene = 'house'; setWeather(MAPS[st.map].weather); }
    else { buildLobby(); this.scene = 'lobby'; setWeather('none'); }
    for (const id in WS) delete WS[id];
    for (const it of WORLD.inter.values()) if (it.init) wsApply(it.id, Object.assign({}, it.init));
    if (ws) for (const id in ws) wsApply(id, ws[id]);
    INM.forEach(m => m.dispose()); INM.length = 0;
  },

  /* ======== смена сцены (хост) ======== */
  setScene(scene, opt = {}) {
    const st = this.st; INM.forEach(m => m.dispose()); INM.length = 0;
    if (scene === 'lobby') { Object.assign(st, { scene: 'lobby', phase: null, booth: Object.assign(st.booth || {}, { cd: -1, idx: -1, counts: [] }), clock: 0 }); }
    else { const d = DIFFS[opt.diff]; Object.assign(st, { scene: 'house', map: opt.map, diff: opt.diff, phase: 'day', clock: 7, night: 1, nights: d.nights, votes: 0, alertT: 0, inmate: null, killed: 0, seed: (Math.random() * 1e9) | 0, used: [] }); }
    this.applyScene(st, null);
    const spawns = {}; let i = 0;
    for (const id in this.players) { const p = this.players[id], sp = this.spawnPoint(i++); p.alive = true; p.hp = 100; p.pose = Object.assign(p.pose, { x: sp.x, y: sp.y, z: sp.z, hid: 0 }); spawns[id] = [sp.x, sp.y, sp.z, 0]; p.static = 0; if (scene === 'house') { p.money = 0; p.apples = 0; p.items = []; this.giveStart(p); } }
    NET.toAll({ t: 'scene', st, ws: WS, spawns }, false);
    this.clientMsg({ t: 'scene', st, spawns });
    this.pinfoDirty = true;
    if (scene === 'house') this.toastAll('День 1. Собирай яблоки и готовься к ночи!');
  },
  giveStart(p) { const c = CLASSES[p.cls] || CLASSES.novice; p.money = c.money || 0; for (const [k, n] of c.items) this.addItem(p, k, n); },
  addItem(p, k, n = 1) { const s = p.items.find(i => i.k === k); if (s) s.n += n; else p.items.push({ k, n }); this.pinfoDirty = true; },
  takeItem(p, k, n = 1) { const s = p.items.find(i => i.k === k); if (!s || s.n < n) return false; s.n -= n; if (s.n <= 0 && k !== 'shotgun') p.items.splice(p.items.indexOf(s), 1); this.pinfoDirty = true; return true; },

  /* ======== главный такт хоста ======== */
  hostTick(dt) {
    const st = this.st;
    // позы своих локальных игроков
    for (const lp of LOCALS) { const P = this.players[lp.id]; if (P) P.pose = lp.pose(); }
    // у хоста аватары клиентов двигаются по их присланным позам (снимки он сам себе не шлёт)
    for (const id in this.remotes) { const P = this.players[id]; if (P && P.pose) this.remotes[id].setPose(P.pose); }
    if (st.scene === 'lobby') this.tickLobby(dt); else if (st.scene === 'house') this.tickMatch(dt);
    // рассылка
    this.sendT += dt;
    if (this.sendT > .08) {
      this.sendT = 0;
      const ps = Object.values(this.players).map(p => [p.id, p.pose.x, p.pose.y, p.pose.z, p.pose.yaw, p.pose.pitch, p.pose.sp, p.pose.cr, p.pose.l, p.pose.hid]);
      const en = INM.map(m => [m.id, m.type, +m.p.x.toFixed(2), +m.p.y.toFixed(2), +m.p.z.toFixed(2), +m.yaw.toFixed(2), m.a, Math.max(0, Math.round(m.hp)), m.vis === 0 ? 0 : 1]);
      const sst = { scene: st.scene, phase: st.phase, clock: +(st.clock || 0).toFixed(3), night: st.night, nights: st.nights, votes: st.votes, booth: st.booth, map: st.map, diff: st.diff, inmate: st.inmate, directive: st.directive };
      if (NET.t) NET.t.broadcast({ t: 'snap', st: sst, ps, en });
      if (this.wsQueue.size) { const d = {}; for (const id of this.wsQueue) d[id] = WS[id]; this.wsQueue.clear(); if (NET.t) NET.t.broadcast({ t: 'ws', d }); }
      if (this.pinfoDirty) { this.pinfoDirty = false; NET.toAll({ t: 'players', list: this.pinfoList() }); }
    }
  },
  queueWS(id) { this.wsQueue.add(id); },

  /* ======== лобби: кабинки запуска ======== */
  tickLobby(dt) {
    const b = this.st.booth, ids = Object.keys(this.players); if (!ids.length) return;
    const counts = LOBBY.booths.map(() => 0), where = {};
    for (const id of ids) { const p = this.players[id].pose; for (const bo of LOBBY.booths) if (Math.abs(p.x - bo.x) < bo.w / 2 && Math.abs(p.z - bo.z) < bo.d / 2 && p.y < 1) { counts[bo.i]++; where[id] = bo.i; } }
    // кабинка, в которой больше всего игроков (при равенстве — та, где уже идёт отсчёт)
    let idx = -1; counts.forEach((c, i) => { if (c && (idx < 0 || c > counts[idx] || (c === counts[idx] && i === b.idx))) idx = i; });
    b.counts = counts; b.total = ids.length; b.inside = idx >= 0 ? counts[idx] : 0;
    if (idx !== b.idx) { b.idx = idx; b.cd = -1; }
    if (idx < 0) { b.cd = -1; return; }
    const bo = LOBBY.booths[idx]; b.map = bo.map; b.diff = bo.diff;
    if (counts[idx] === ids.length) { if (b.cd < 0) { b.cd = QS.get('fast') ? 2 : 10; this.fxAll('ui2', null); } b.cd -= dt; if (b.cd <= 0) { b.cd = -1; b.idx = -1; this.startMatch(bo.map, bo.diff); } }
    else b.cd = -1;
  },
  startMatch(map, diff) { this.fxAll('sting', null); this.setScene('house', { map, diff }); },

  /* ======== матч ======== */
  tickMatch(dt) {
    const st = this.st, D = DIFFS[st.diff];
    if (st.phase === 'day') {
      st.clock += 14 / D.day * dt * (QS.get('fast') ? 6 : 1);
      this.growApples(dt);
      if (st.clock >= 21) this.startAlert();
    } else if (st.phase === 'alert') {
      st.alertT += dt; const alive = Object.values(this.players).length;
      if (st.alertT > ALERT_LEN || (st.votes >= Math.ceil(alive / 2) && st.alertT > 4)) this.startNight();
    } else if (st.phase === 'night') {
      st.clock += 10 / D.night * dt * (QS.get('fast') ? 4 : 1); st.nightT += dt;
      for (const m of INM.slice()) { if (m.gone) continue; (m.T.tick ? m.T.tick(m, dt) : m.hunt(dt)); }
      if (typeof DIRECTIVE !== 'undefined') DIRECTIVE.hostTick(dt);
      this.growApples(dt);
      if (st.clock >= 31) this.dawn();
      else if (!Object.values(this.players).some(p => p.alive)) this.endMatch(false);
    } else if (st.phase === 'dawn') {
      st.dawnT += dt; if (st.dawnT > 7) { if (st.night >= st.nights) this.endMatch(true); else { st.night++; st.phase = 'day'; st.clock = 7; this.phaseAll('day'); } }
    }
    // лампы с датчиком движения
    for (const id in WS) if (id.startsWith('ML_')) { const w = WS[id], p = new V3(w.p[0], w.p[1], w.p[2]); const near = INM.some(m => m.p.distanceTo(p) < 4) || Object.values(this.players).some(q => q.alive && Math.hypot(q.pose.x - p.x, q.pose.z - p.z) < 3 && q.pose.sp > .5); if (!!w.lit !== near) wsSet(id, { lit: near ? 1 : 0 }); }
    // ловушки
    for (const tr of (this.traps || [])) if (WS[tr.id] && WS[tr.id].on) for (const m of INM) if (m.p.distanceTo(tr.pos) < .7) { m.stun = Math.max(m.stun, 6); wsSet(tr.id, { on: 0, hit: 1 }); this.fxAll('lock', tr.pos); this.toastAll('Капкан сработал!'); }
  },
  growApples(dt) {
    this.appleT = (this.appleT || 0) + dt * (this.st.sprinkler ? 2 : 1);
    if (this.appleT > 18) { this.appleT = 0; for (const t of HOUSE.trees) { const s = WS[t.id]; if (s && s.on && s.n < 4) wsSet(t.id, { n: s.n + 1 }); } }
  },
  pickApple(pid, id) { const P = this.players[pid], s = WS[id]; if (!P || !s || s.n <= 0) return; const max = 14; if (P.apples >= max) { this.toastTo(pid, 'Руки заняты! Продай яблоки в гараже.'); return; } wsSet(id, { n: s.n - 1 }); P.apples += P.cls === 'farmer' ? 2 : 1; P.apples = Math.min(max, P.apples); this.pinfoDirty = true; this.fxTo(pid, 'apple'); },
  shopOpen() { return this.st.scene === 'house' && this.st.phase === 'day'; },
  openShop(pid) { if (!this.shopOpen()) { this.toastTo(pid, 'Магазин закрыт до утра'); return; } this.sendTo(pid, { t: 'shopres', open: 1 }); },
  sell(P) { if (!this.shopOpen() || !P.apples) return; const v = P.apples * DIFFS[this.st.diff].apple; P.money += v; this.sendTo(P.id, { t: 'shopres', msg: 'Продано ' + P.apples + ' 🍎 за $' + v }); P.apples = 0; this.pinfoDirty = true; this.fxTo(P.id, 'coin'); },
  buy(P, k) {
    const it = ITEMS[k]; if (!it || !this.shopOpen()) return;
    if (P.money < it.price) { this.sendTo(P.id, { t: 'shopres', msg: 'Не хватает денег' }); return; }
    if (k === 'tree') { const t = HOUSE.trees.find(t => !WS[t.id].on); if (!t) { this.sendTo(P.id, { t: 'shopres', msg: 'Во дворе больше нет места' }); return; } wsSet(t.id, { on: 1, n: 1 }); }
    else if (k === 'sprinkler') { if (this.st.sprinkler) { this.sendTo(P.id, { t: 'shopres', msg: 'Уже куплено' }); return; } this.st.sprinkler = 1; }
    else if (k === 'shells') this.addItem(P, 'shotgun', 4) || this.pinfoDirty;
    else if (k === 'shotgun') { if (P.items.find(i => i.k === 'shotgun')) { this.addItem(P, 'shotgun', 4); } else this.addItem(P, 'shotgun', 4); }
    else this.addItem(P, k, k === 'pepper' ? 3 : 1);
    P.money -= it.price; this.pinfoDirty = true; this.sendTo(P.id, { t: 'shopres', msg: 'Куплено: ' + it.name }); this.fxTo(P.id, 'coin');
  },
  alertActive() { return this.st.phase === 'alert'; },
  useTV(pid) { if (this.alertActive()) { this.sendTo(pid, { t: 'alert', again: 1, lines: this.st.alertLines }); return; } wsSet('TV', { on: WS.TV.on ? 0 : 1 }); this.sfxAt('click', HOUSE.tv.pos); },
  useFuse(pid) { const on = WS.FUSE.on ? 0 : 1; wsSet('FUSE', { on }); this.fxAll(on ? 'powerup' : 'powerdown', HOUSE.fuse.pos); },

  /* ---- оповещение ---- */
  chooseInmate() {
    const st = this.st, D = DIFFS[st.diff], tier = Math.min(3, D.tier + (st.night > 4 ? 1 : 0));
    const n = Object.keys(this.players).length, last = !D.endless && st.night >= st.nights;
    // последняя ночь — босс (если есть), иначе боссы не выпадают
    const ok = t => t.difficulty <= tier && !t.lobbyOnly && !t.companion && !t.special && (t.minNight || 1) <= st.night && (!t.coopOnly || n > 1) && (!t.finalNight || last);
    const boss = last && INMATES.list.filter(t => t.finalNight && !t.companion); if (boss && boss.length && !QS.get('inmate')) { const B = pick(boss); st.used.push(B.key); return B; }
    let pool = INMATES.list.filter(t => ok(t) && !st.used.includes(t.key));
    if (!pool.length) { st.used = st.used.slice(-1); pool = INMATES.list.filter(t => ok(t) && !st.used.includes(t.key)); }
    if (!pool.length) pool = INMATES.list.filter(ok);
    const forced = QS.get('inmate'); const T = forced && INMATES.types[forced] ? INMATES.types[forced] : pick(pool);
    st.used.push(T.key); return T;
  },
  startAlert() {
    const st = this.st; st.phase = 'alert'; st.alertT = 0; st.votes = 0; for (const id in this.players) this.players[id].voted = 0;
    const T = this.chooseInmate(); st.inmate = T.key; st.unknown = T.unknownAlert || (st.diff !== 'easy' && Math.random() < .12);
    st.directive = typeof DIRECTIVE !== 'undefined' ? DIRECTIVE.pick(T, st.unknown) : 'NONE';
    const lines = st.unknown ? [ALERT_HEAD, 'МЫ ПОЛУЧАЕМ СООБЩЕНИЯ О НАРУШЕНИИ ПЕРИМЕТРА В ЛЕЧЕБНИЦЕ BLACK RIDGE.', 'ОДИН ЗАКЛЮЧЁННЫЙ НЕ НАЙДЕН. ЕГО ИМЯ, КЛАССИФИКАЦИЯ И УРОВЕНЬ УГРОЗЫ — НЕИЗВЕСТНЫ. СИЛЬНАЯ ПОТЕРЯ СИГНАЛА.', 'ГРАЖДАНАМ РЕКОМЕНДУЕТСЯ ОСТАВАТЬСЯ В ПОМЕЩЕНИИ ДО ПОЛУЧЕНИЯ НОВОЙ ИНФОРМАЦИИ.']
      : [ALERT_HEAD, 'ЗАКЛЮЧЁННЫЙ ' + T.num + ' — «' + T.en + '» (' + T.name + '), КЛАСС: ' + T.cls + '.', ...T.alert];
    st.alertLines = lines;
    // всех к телевизору
    const spawns = {}; let i = 0;
    for (const id in this.players) { const p = this.players[id]; if (!p.alive) continue; const sp = [2.9 - Math.floor(i / 4) * .9, 0, 1.2 + (i % 4) * 1.0]; i++; p.pose.x = sp[0]; p.pose.y = 0; p.pose.z = sp[2]; spawns[id] = [sp[0], 0, sp[2], -PI / 2]; }
    // вышедшие из шкафов
    for (const h of WORLD.hides) if (WS[h.id].by) { const pid = WS[h.id].by; wsSet(h.id, { by: '' }); const P = this.players[pid]; if (P) P.pose.hid = 0; this.sendTo(pid, { t: 'hidden', pid, id: 0 }); }
    if (!WS.TV.on) wsSet('TV', { on: 1 });
    NET.toAll({ t: 'phase', ph: 'alert', st: { phase: 'alert', inmate: st.inmate, unknown: st.unknown, alertLines: lines, directive: st.directive }, spawns, lines, dur: ALERT_LEN, night: st.night });
  },
  startNight() {
    const st = this.st, D = DIFFS[st.diff]; st.phase = 'night'; st.nightT = 0;
    const boss = INMATES.types[st.inmate] && INMATES.types[st.inmate].finalNight;
    const n = !boss && ((D.endless && st.night > 6) || (st.diff === 'hard' && st.night >= 8)) ? 2 : 1;
    this.spawnInmate(st.inmate); if (n > 1) { const T2 = this.chooseInmate(); this.spawnInmate(T2.key); }
    this.phaseAll('night');
  },
  spawnInmate(type) {
    const id = ++INM_ID, m = new Inmate(type, id); INM.push(m); const T = m.T; m.hp *= DIFFS[this.st.diff].mul; m.maxHp = m.hp;
    if (T.spawn) T.spawn(m); else { const ents = HOUSE.entries, e = Math.random() < .5 ? ents[0] : pick(ents); m.entry = e; m.p.copy(e.out); m.state = 'enter'; m.goNode(m.nodeNear(e.in)); }
    if (NET.t) NET.t.broadcast({ t: 'inm', add: id, type });
    return m;
  },
  spawnInmateLocal(id, type) { if (INM.find(q => q.id === id) || !INMATES.types[type]) return; INM.push(new Inmate(type, id)); },
  removeInmate(m) { m.dispose(); INM.splice(INM.indexOf(m), 1); if (NET.t) NET.t.broadcast({ t: 'inm', del: m.id }); },
  inmateDied(m, by) {
    this.fxAll('scream', m.p); this.removeInmate(m); this.st.killed++;
    const P = by && this.players[by]; if (P) { P.money += 120; this.sendTo(P.id, { t: 'fx', k: 'killq' }); this.pinfoDirty = true; }
    this.toastAll('Заключённый обезврежен!'); if (!INM.length && this.st.phase === 'night') { this.st.clock = Math.max(this.st.clock, 30.4); }
  },
  dawn() {
    const st = this.st; st.phase = 'dawn'; st.dawnT = 0; st.clock = 31;
    while (INM.length) this.removeInmate(INM[0]);
    const anyAlive = Object.values(this.players).some(p => p.alive);
    if (!anyAlive) return this.endMatch(false);
    const spawns = {}; let i = 0;
    for (const id in this.players) { const p = this.players[id]; p.money += 40; p.static = 0; if (!p.alive) { p.alive = true; p.hp = 100; const sp = this.spawnPoint(i++); p.pose.x = sp.x; p.pose.y = sp.y; p.pose.z = sp.z; spawns[id] = [sp.x, sp.y, sp.z]; this.sendTo(id, { t: 'revive', pid: id, pos: [sp.x, sp.y, sp.z] }); } }
    this.pinfoDirty = true; this.phaseAll('dawn');
  },
  endMatch(win) {
    const st = this.st; if (st.phase === 'end') return; st.phase = 'end';
    const nightsDone = win ? st.nights : st.night - 1;
    NET.toAll({ t: 'end', win, nights: nightsDone, diff: st.diff, map: st.map, killed: st.killed, endless: DIFFS[st.diff].endless });
    setTimeout(() => { if (this.st.phase === 'end' && this.isHost() && this.st.scene === 'house') this.setScene('lobby'); }, 25000);
  },
  phaseAll(ph) { const st = this.st; NET.toAll({ t: 'phase', ph, st: { phase: st.phase, night: st.night, clock: st.clock } }); },
  awardLocal(m) {
    const D = DIFFS[m.diff]; const amber = m.nights * 12 + (m.win ? D.amber : 0) + m.killed * 15, xp = m.nights * 30 + (m.win ? 120 : 0);
    for (const lp of LOCALS) { const p = lp.prof; p.amber += amber; p.xp += xp; if (m.win) p.wins++; p.best = Math.max(p.best, m.nights); questAdd(p, 'nights', m.nights); if (m.win) questAdd(p, 'win', 1); saveProfile(p, lp.profKey); }
    m.amber = amber; m.xp = xp;
  },

  /* ======== укрытия ======== */
  toggleHide(pid, h) {
    const s = WS[h.id], P = this.players[pid]; if (!P) return;
    if (s.by === pid) { wsSet(h.id, { by: '' }); P.pose.hid = 0; this.sendTo(pid, { t: 'hidden', pid, id: 0 }); }
    else if (!s.by) { if (WORLD.hides.some(q => WS[q.id].by === pid)) return; wsSet(h.id, { by: pid }); P.pose.hid = h.id; this.sendTo(pid, { t: 'hidden', pid, id: h.id }); }
  },
  /* ======== предметы ======== */
  useItem(P, m) {
    if (!P.alive) return; const k = m.k, eye = new V3(m.o[0], m.o[1], m.o[2]), dir = new V3(m.d[0], m.d[1], m.d[2]).normalize();
    if (k === 'shotgun') {
      if (!this.takeItem(P, 'shotgun')) { this.sendTo(P.id, { t: 'toast', text: 'Нет патронов' }); return; }
      this.fxAll('shot', eye, { pid: P.id });
      let best = null, bd = 18;
      for (const im of INM) { const c = im.p.clone().add(new V3(0, 1, 0)), to = c.clone().sub(eye), d = to.length(); if (d > bd) continue; const cos = to.normalize().dot(dir); if (cos < .93 && !(d < 2.5 && cos > .6)) continue; if (!WORLD.coll.los(eye, c, b => !b.door || !(WS[b.door] && (WS[b.door].o || WS[b.door].b)))) continue; best = im; bd = d; }
      if (best) { best.damage(Math.round(60 * (1.1 - bd / 22)), P.id); best.stun = Math.max(best.stun, .8); this.fxAll('hit', best.p); }
    } else if (k === 'pepper' || k === 'stun') {
      if (k === 'stun' && (P.stunCd || 0) > now()) { this.sendTo(P.id, { t: 'toast', text: 'Шокер заряжается…' }); return; }
      if (k === 'pepper' && !this.takeItem(P, 'pepper')) return;
      if (k === 'stun') P.stunCd = now() + 20;
      this.fxAll(k === 'stun' ? 'zap' : 'spray', eye);
      for (const im of INM) { const d = im.p.clone().add(new V3(0, 1, 0)).sub(eye); if (d.length() < (k === 'stun' ? 2.6 : 3.4) && d.normalize().dot(dir) > .6) { im.stun = Math.max(im.stun, k === 'stun' ? 4 : 3); this.toastTo(P.id, 'Попал! Заключённый оглушён'); } }
    } else if (k === 'beartrap' || k === 'motion') {
      const t = WORLD.coll.ray(eye.x, eye.y, eye.z, dir.x, dir.y, dir.z, 3.5); const p = eye.clone().add(dir.clone().multiplyScalar(Math.min(t, 3) - .05)); p.y = WORLD.coll.groundAt(p.x, p.z, .1, p.y + .3);
      if (!this.takeItem(P, k)) return;
      const id = (k === 'beartrap' ? 'TRAP_' : 'ML_') + (++this.trapN);
      if (k === 'beartrap') { (this.traps = this.traps || []).push({ id, pos: p }); }
      wsSet(id, { k, p: [p.x, p.y, p.z], on: 1 });
    } else if (k === 'defib') {
      let tgt = null; for (const q of Object.values(this.players)) if (!q.alive && Math.hypot(q.pose.x - eye.x, q.pose.z - eye.z) < 3) tgt = q;
      if (!tgt) { this.toastTo(P.id, 'Подойди к павшему товарищу'); return; }
      if (!this.takeItem(P, 'defib')) return; tgt.alive = true; tgt.hp = 60; this.sendTo(tgt.id, { t: 'revive', pid: tgt.id }); this.toastAll(P.name + ' оживил ' + tgt.name + '!'); this.fxAll('heal', eye); this.pinfoDirty = true; this.sendTo(P.id, { t: 'fx', k: 'reviveq' });
    } else if (k === 'medkit') { if (P.hp >= 100 || !this.takeItem(P, 'medkit')) return; P.hp = Math.min(100, P.hp + 60); this.fxTo(P.id, 'heal'); }
    else if (k === 'battery') { if (this.takeItem(P, 'battery')) this.sendTo(P.id, { t: 'fx', k: 'battery', pid: P.id }); }
  },
  /* ======== смерть ======== */
  killPlayer(pid, m) {
    const P = this.players[pid]; if (!P || !P.alive) return; if ((P.godUntil || 0) > now()) return;
    P.hp -= m.T.damage || 100; if (P.hp > 0) { P.godUntil = now() + 1.2; this.sendTo(pid, { t: 'fx', k: 'hurt', pid }); this.pinfoDirty = true; return; }
    P.alive = false; P.hp = 0; const h = WORLD.hides.find(q => WS[q.id].by === pid); if (h) wsSet(h.id, { by: '' }); P.pose.hid = 0;
    NET.toAll({ t: 'kill', pid, by: m.type, pos: [m.p.x, m.p.y, m.p.z] }); this.pinfoDirty = true;
    if (!Object.values(this.players).some(p => p.alive)) setTimeout(() => this.endMatch(false), 3500);
  },
  onKilled(m) {
    const lp = LOCALS.find(l => l.id === m.pid);
    if (lp) { lp.alive = false; lp.hidden = null; UI.jumpscare(m.by, lp); }
    else { const r = this.remotes[m.pid]; if (r) { r.alive = false; AU.play('scream', r.p); } }
  },
  /* ======== свет и взгляды (хост, для ИИ) ======== */
  roomAt(p) { const rr = HOUSE_ROOMS; const up = p.y > 2.4; for (const k in rr) { const r = rr[k]; if (r[4] === up && p.x >= r[0] && p.x <= r[2] && p.z >= r[1] && p.z <= r[3]) return k; } return null; },
  litAt(p) {
    if (this.st.scene !== 'house') return true;
    const room = this.roomAt(p);
    if (!room) { if (this.st.phase === 'day' || this.st.phase === 'dawn') return true; return Math.hypot(p.x + 12, p.z - 16.2) < 7; }
    if (this.power() && WS['L_' + room] && WS['L_' + room].on) return true;
    if (room === 'living' && WS.TV && WS.TV.on && this.power() && p.distanceTo(HOUSE.tv.pos) < 4) return true;
    for (const id in WS) if (id.startsWith('ML_') && WS[id].lit && Math.hypot(WS[id].p[0] - p.x, WS[id].p[2] - p.z) < 3.5) return true;
    return false;
  },
  torchOn(p) {
    for (const P of Object.values(this.players)) { if (!P.alive || !P.pose.l) continue; const e = new V3(P.pose.x, P.pose.y + 1.5, P.pose.z), to = p.clone().sub(e), d = to.length(); if (d > 14) continue;
      const q = new THREE.Quaternion().setFromEuler(new THREE.Euler(P.pose.pitch, P.pose.yaw, 0, 'YXZ')), f = new V3(0, 0, -1).applyQuaternion(q);
      if (to.normalize().dot(f) > .9 && WORLD.coll.los(e, p)) return true; }
    return false;
  },
  anyoneWatching(p, maxD = 20) {
    for (const P of Object.values(this.players)) { if (!P.alive || P.pose.hid) continue; const e = new V3(P.pose.x, P.pose.y + (P.pose.cr ? .95 : 1.55), P.pose.z), to = p.clone().sub(e), d = to.length(); if (d > maxD) continue;
      const q = new THREE.Quaternion().setFromEuler(new THREE.Euler(P.pose.pitch, P.pose.yaw, 0, 'YXZ')), f = new V3(0, 0, -1).applyQuaternion(q);
      if (to.normalize().dot(f) < .62) continue; if (!(d < 7 || this.litAt(p) || P.pose.l)) continue;
      if (WORLD.coll.los(e, p, b => !b.door || !(WS[b.door] && (WS[b.door].o || WS[b.door].b)))) return true; }
    return false;
  },
  /* ======== эффекты и сообщения ======== */
  fxAll(k, pos, extra = {}) { NET.toAll(Object.assign({ t: 'fx', k, p: pos ? [+pos.x.toFixed(2), +pos.y.toFixed(2), +pos.z.toFixed(2)] : null }, extra)); },
  sfxAt(k, o) { const p = o.isVector3 ? o : o.pos || new V3(o.x, (o.y || 0) + 1, o.z); this.fxAll(k, p); },
  fxTo(pid, k) { this.sendTo(pid, { t: 'fx', k, p: null }); },
  sendTo(pid, m) { const P = this.players[pid]; if (!P) return; m.pid = m.pid || pid; NET.toPeer(P.peer, m); },
  toastTo(pid, text) { this.sendTo(pid, { t: 'toast', text }); },
  toastAll(text) { NET.toAll({ t: 'toast', text }); },
  fxLocal(m) {
    const p = m.p ? new V3(m.p[0], m.p[1], m.p[2]) : null;
    if (m.pid && !LOCALS.find(l => l.id === m.pid) && ['coin', 'hurt', 'battery', 'apple', 'killq', 'reviveq'].includes(m.k)) return;
    switch (m.k) {
      case 'say': UI.subtitle(m.text); AU.speak(m.text.toLowerCase(), { pitch: .3, rate: .8 }); if (p) AU.play('whisper', p); break;
      case 'powerdown': AU.play('buzz', p, { d: 1 }); AU.play('switch', p); UI.toast('⚡ Электричество отключилось!'); break;
      case 'powerup': AU.play('switch', p); AU.play('buzz', p, { d: .3 }); break;
      case 'shot': AU.play('bang', p); AU.play('static', p, { d: .15, v: .5 }); { const lp = LOCALS.find(l => l.id === m.pid); if (lp) { lp.shake = 1.2; UI.flash('#fff3', 80); } } break;
      case 'hit': AU.play('stepHeavy', p, { v: .8 }); break;
      case 'spray': AU.play('static', p, { d: .6, v: .3 }); break;
      case 'zap': AU.play('buzz', p, { d: .3 }); AU.play('switch', p); break;
      case 'hurt': UI.flash('#f004', 300); AU.play('heart'); { const lp = LOCALS.find(l => l.id === m.pid); if (lp) lp.shake = 1; } break;
      case 'battery': { const lp = LOCALS.find(l => l.id === m.pid); if (lp) { lp.battery = 1; UI.toast('Фонарик заряжен'); } AU.play('click'); break; }
      case 'heal': AU.play('chime', p); break;
      case 'apple': AU.play('coin'); questAdd(null, 'apples', 1, m.pid); break;
      case 'killq': AU.play('coin'); UI.toast('Заключённый обезврежен! +$120'); questAdd(null, 'kill', 1, m.pid); break;
      case 'reviveq': questAdd(null, 'revive', 1, m.pid); break;
      default: AU.play(m.k, p, m);
    }
  },
  onPhaseLocal(m) {
    if (m.spawns) for (const lp of LOCALS) { const s = m.spawns[lp.id]; if (s && lp.alive) { lp.setPose(s[0], s[1], s[2], s[3] !== undefined ? s[3] : lp.body.yaw); lp.hidden = null; } }
    if (m.ph === 'night') { AU.ambient('night'); AU.play('sting'); }
    if (m.ph === 'dawn') { AU.ambient('dawn'); AU.play('rooster'); AU.play('chime'); questAddAll('nights', 0); }
    if (m.ph === 'day') AU.ambient('dawn');
    if (m.ph === 'alert') AU.ambient('tense');
  },
  /* ======== локальный такт (у всех) ======== */
  localTick(dt) {
    // свои игроки
    for (const lp of LOCALS) {
      const s = lp.update(dt, WORLD.coll); lp.syncAvatar(dt);
      if (!this.localControls(lp, s, dt)) { }
      // отправка позы
      if (NET.role === 'client') { lp.poseT = (lp.poseT || 0) + dt; if (lp.poseT > .066) { lp.poseT = 0; NET.toHost({ t: 'pose', pid: lp.id, p: lp.pose() }); } }
    }
    for (const id in this.remotes) this.remotes[id].update(dt);
    for (const m of INM) m.render(dt, this.isHost());
    for (const f of WORLD.ticks) f(dt);
    // камера наблюдения для погибших
    for (const lp of LOCALS) if (!lp.alive) { const others = Object.values(this.remotes).filter(r => r.alive); const lo = LOCALS.filter(l => l !== lp && l.alive); const t = lo[0] ? lo[0].body.p : others[0] ? others[0].p : null; lp.spectate = t; }
  },
  localControls(lp, s, dt) {
    if (UI.modal) return false;
    // прицел на интерактив
    lp.focus = lp.alive && !lp.hidden ? aimInteract(lp.cam) : null;
    if (lp.hidden) { // в шкафу: выход и концентрация
      lp.hideT += dt;
      if (this.st.scene === 'house' && this.st.phase === 'night' && lp.hideT > 10) { if (!lp.qte) { lp.qteNext = lp.qteNext || 0; if (lp.hideT > 10 + lp.qteNext) { lp.qte = { t: 0, win: 1.7 }; AU.play('heart'); } } else { lp.qte.t += dt; if (s.press.use) { lp.qte = null; lp.qteNext = lp.hideT - 10 + 5 + Math.random() * 4; AU.play('ui'); } else if (lp.qte.t > lp.qte.win) { lp.qte = null; UI.toast('Не удалось сосредоточиться — тебя выдало дыхание!'); NET.toHost({ t: 'unhide', pid: lp.id }); } } }
      else if (s.press.use) NET.toHost({ t: 'unhide', pid: lp.id });
      return true;
    }
    if (!lp.alive) return true;
    // взаимодействие (держать для некоторых)
    const it = lp.focus;
    if (it && (s.press.use || (lp.holding && lp.holding.id === it.id))) {
      const needHold = it.hold || (it.alt && it.alt() && (KEYS.KeyE || lp.src.btn && lp.src.btn.use) && false);
      if (it.hold) { if (!lp.holding || lp.holding.id !== it.id) lp.holding = { id: it.id, t: 0 }; }
      else if (s.press.use) { if (it.cond && !it.cond(lp.id)) { } else NET.toHost({ t: 'use', pid: lp.id, id: it.id }); AU.play('ui'); }
    }
    if (lp.holding) { const held = (lp.src instanceof KBMouse ? anyKey(lp.src.b.use) : lp.src instanceof Touch ? lp.src.useHeld : true); const cur = lp.focus;
      if (!held || !cur || cur.id !== lp.holding.id) lp.holding = null;
      else { lp.holding.t += dt; const need = WORLD.inter.get(lp.holding.id).hold || .6; if (lp.holding.t >= need) { NET.toHost({ t: 'use', pid: lp.id, id: lp.holding.id, hold: 1 }); lp.holding = null; } } }
    // запереть дверь: удержание на двери 0.7с
    if (it && it.alt && it.alt()) { const held = lp.src instanceof KBMouse ? anyKey(lp.src.b.use) : lp.src instanceof Touch ? lp.src.useHeld : false; if (held) { lp.lockT = (lp.lockT || 0) + dt; if (lp.lockT > .7) { lp.lockT = -99; NET.toHost({ t: 'use', pid: lp.id, id: it.id, hold: 1 }); } } else lp.lockT = 0; }
    // предметы
    const info = lp.info; if (info && info.items) {
      const n = info.items.length; if (lp.slot >= n) lp.slot = Math.max(0, n - 1);
      for (let i = 0; i < 9; i++) if (lp.i === 0 && PRESSED.has('Digit' + (i + 1)) && i < n) { lp.slot = i; AU.play('ui'); }
      if (s.press.slot) { lp.slot = n ? (lp.slot + 1) % n : 0; }
      const fire = (lp.i === 0 && PRESSED.has('Mouse0')) || s.press.item;
      if (fire && n) { const k = info.items[lp.slot].k; const d = new V3(0, 0, -1).applyQuaternion(lp.cam.quaternion); const o = lp.cam.position;
        if (k === 'battery') { } NET.toHost({ t: 'item', pid: lp.id, k, o: [o.x, o.y, o.z], d: [d.x, d.y, d.z] }); if (k === 'shotgun') lp.recoil = 1; }
    }
    return true;
  },
};
const HOUSE_ROOMS = { hall: [-3, 1, 1, 6.2, false], hall2: [-3, -6, 1, 1, false], living: [1, 0, 8, 6, false], kitchen: [1, -6, 8, 0, false], garage: [-8, -1, -3, 6, false], dining: [-8, -6, -3, -1, false], hallU: [-3, -6, 1, 6, true], bed1: [1, 0, 8, 6, true], bed2: [1, -6, 8, 0, true], bed3: [-8, 0, -3, 6, true], bath: [-8, -6, -3, 0, true] };

/* ---- задания (Quests) ---- */
const QUESTS = [
  { id: 'apples', name: 'Собери 25 яблок', goal: 25, reward: 40 },
  { id: 'nights', name: 'Переживи 5 ночей', goal: 5, reward: 60 },
  { id: 'win', name: 'Выиграй матч', goal: 1, reward: 100 },
  { id: 'kill', name: 'Обезвредь 3 заключённых', goal: 3, reward: 80 },
  { id: 'revive', name: 'Оживи товарища', goal: 1, reward: 50 },
];
function questAdd(p, id, n, pid) {
  const targets = p ? [p] : LOCALS.filter(l => !pid || l.id === pid).map(l => l.prof);
  for (const pr of targets) { const q = pr.quests[id] || (pr.quests[id] = { n: 0, done: 0 }); if (q.done) continue; q.n += n; const Q = QUESTS.find(x => x.id === id); if (Q && q.n >= Q.goal) { q.done = 1; pr.amber += Q.reward; UI.toast('Задание выполнено: ' + Q.name + ' (+' + Q.reward + ' Amber)'); AU.play('coin'); } }
  for (const lp of LOCALS) saveProfile(lp.prof, lp.profKey);
}
function questAddAll(id, n) { if (n) questAdd(null, id, n); }
