/* ================= ДИРЕКТИВЫ ТРАНСЛЯЦИИ И «ТЕЛЕВЕДУЩИЙ» (THE BROADCASTER, 3.0) =================
   Каждое оповещение несёт одну проверяемую директиву. Ночью (после 20 с форы) хост раз в секунду
   проверяет каждого живого игрока: нарушение +4 к «помехам», подчинение −2. На 100 за игроком
   приходит Телеведущий: неуязвимый, идёт следом из комнаты в комнату и исчезает, если 15 с подряд
   слушаться директиву и не попадаться ему на глаза. */
const DIRECTIVES = {
  LIGHTS_OFF: { text: 'ПОГАСИТЕ СВЕТ', hint: 'не стой в освещённой комнате и не свети фонарём рядом с ним' },
  LIGHTS_ON: { text: 'НЕ ВЫКЛЮЧАЙТЕ СВЕТ', hint: 'не стой в тёмной комнате, пока есть электричество' },
  STAY_STILL: { text: 'НЕ ДВИГАЙТЕСЬ', hint: 'не бегай и не ходи в одной комнате с ним' },
  NO_DOOR: { text: 'НЕ ОТКРЫВАЙТЕ ДВЕРЬ', hint: 'входные двери ночью не открывать' },
  NO_LOOK: { text: 'НЕ СМОТРИТЕ НА НЕГО', hint: 'не смотри прямо на заключённого при свете' },
  STAY_INDOORS: { text: 'ОСТАВАЙТЕСЬ В ДОМЕ', hint: 'не выходи на улицу и во двор' },
  DONT_APPROACH: { text: 'НЕ ПРИБЛИЖАЙТЕСЬ', hint: 'держись дальше 4 м от него' },
  BREAK_LOS: { text: 'НЕ ПОПАДАЙТЕСЬ НА ГЛАЗА', hint: 'не оставайся у него на виду дольше 3 с' },
  NO_HIDE: { text: 'НЕ ПРЯЧЬТЕСЬ', hint: 'не сиди в укрытии дольше 5 с' },
  FUSE_WATCH: { text: 'СЛЕДИТЕ ЗА ЩИТКОМ', hint: 'не оставляйте дом без света дольше 30 с' },
  NONE: null,
};
// директивы заключённых, у которых они не заданы в самом типе
const DIRECTIVE_OF = { seeker: 'STAY_STILL', doll: 'NO_LOOK', tara: 'LIGHTS_ON', dancer: 'LIGHTS_OFF', wyrm: 'STAY_INDOORS', gladys: 'NO_DOOR', bellringer: 'BREAK_LOS', giftcrawler: 'DONT_APPROACH', george: 'NO_HIDE', sunstar: 'FUSE_WATCH', pianist: 'LIGHTS_OFF', deadcircus: 'LIGHTS_OFF' };
const BROADCAST_NONCOMP = 'ЭТА СТАНЦИЯ ОБНАРУЖИЛА НЕПОДЧИНЕНИЕ В ВАШЕМ ДОМЕ. ВЕРНИТЕСЬ К ПОРЯДКУ. ОСТАВАЙТЕСЬ НА СВЯЗИ.';

const DIRECTIVE = {
  acc: 0, prevDoors: {}, nextTarget: null,
  pick(T, unknown) { if (unknown) return 'STAY_INDOORS'; const d = T.directive || DIRECTIVE_OF[T.key] || 'NONE'; return DIRECTIVES[d] !== undefined ? d : 'NONE'; },
  // нарушает ли игрок директиву прямо сейчас (хост)
  violates(code, P) {
    const p = P.pose, pos = new V3(p.x, p.y + 1, p.z), room = GAME.roomAt(pos), main = INM.filter(m => m.type !== 'broadcaster' && !m.gone);
    const near = (r) => main.some(m => m.p.distanceTo(pos) < r);
    switch (code) {
      case 'LIGHTS_OFF': return !p.hid && ((room && GAME.power() && WS['L_' + room] && WS['L_' + room].on) || (p.l && near(12)));
      case 'LIGHTS_ON': return !p.hid && GAME.power() && !!room && !(WS['L_' + room] && WS['L_' + room].on);
      case 'STAY_STILL': return !p.hid && (p.sp > 5 || (p.sp > .5 && main.some(m => m.p.distanceTo(pos) < 9 && GAME.roomAt(m.p.clone().setY(m.p.y + 1)) === room)));
      case 'NO_LOOK': {
        if (p.hid) return false; const e = new V3(p.x, p.y + (p.cr ? .95 : 1.55), p.z), f = new V3(0, 0, -1).applyQuaternion(new THREE.Quaternion().setFromEuler(new THREE.Euler(p.pitch, p.yaw, 0, 'YXZ')));
        return main.some(m => { const c = m.p.clone().add(new V3(0, .8, 0)), to = c.clone().sub(e), d = to.length(); return d < 16 && to.normalize().dot(f) > .93 && (GAME.litAt(c) || p.l) && WORLD.coll.los(e, c, b => !b.door || !(WS[b.door] && (WS[b.door].o || WS[b.door].b))); });
      }
      case 'STAY_INDOORS': return !room;
      case 'DONT_APPROACH': return near(4);
      case 'BREAK_LOS': { P.losT = main.some(m => m.canSee(p, 18)) ? (P.losT || 0) + 1 : 0; return P.losT > 3; }
      case 'NO_HIDE': { P.hideT2 = p.hid ? (P.hideT2 || 0) + 1 : 0; return P.hideT2 > 5; }
      case 'FUSE_WATCH': { this.darkT = GAME.power() ? 0 : (this.darkT || 0) + 1 / Math.max(1, GAME.alivePlayers().length); return this.darkT > 30; }
    }
    return false;
  },
  hostTick(dt) {
    const st = GAME.st, code = st.directive; if (!DIRECTIVES[code] || SETTINGS.directives === false) return;
    // открытая ночью входная дверь — сразу +40 тому, кто ближе всех
    if (code === 'NO_DOOR') for (const id of ['D_front', 'D_back']) { const o = WS[id] && WS[id].o ? 1 : 0; if (o && !this.prevDoors[id] && st.nightT > 2) { const d = WORLD.doors.find(q => q.id === id); if (!d) continue; let best = null, bd = 4; for (const P of Object.values(GAME.players)) { if (!P.alive) continue; const dd = Math.hypot(P.pose.x - d.x, P.pose.z - d.z); if (dd < bd) { bd = dd; best = P; } } if (best) this.bump(best, 40); } this.prevDoors[id] = o; }
    this.acc += dt; if (this.acc < 1) return; this.acc -= 1;
    if ((st.nightT || 0) < 20) return;
    for (const P of Object.values(GAME.players)) {
      if (!P.alive) continue;
      const bad = this.violates(code, P); P.compliant = !bad;
      const before = P.static || 0; P.static = clamp(before + (bad ? 4 : -2), 0, 100);
      if (Math.round(before) !== Math.round(P.static)) GAME.pinfoDirty = true;
      if (bad && before < 60 && P.static >= 60) GAME.sendTo(P.id, { t: 'fx', k: 'static', d: .5, v: .25 });
      if (P.static >= 100) this.summon(P);
    }
  },
  bump(P, n) { P.static = clamp((P.static || 0) + n, 0, 100); GAME.pinfoDirty = true; GAME.sendTo(P.id, { t: 'fx', k: 'static', d: .6, v: .3 }); if (P.static >= 100) this.summon(P); },
  summon(P) {
    if (INM.some(m => m.type === 'broadcaster' && m.target === P.id)) return;
    this.nextTarget = P.id; const m = GAME.spawnInmate('broadcaster'); this.nextTarget = null;
    GAME.sendTo(P.id, { t: 'fx', k: 'say', text: BROADCAST_NONCOMP, p: null });
    GAME.fxAll('static', null, { d: 1.2, v: .35 });
    return m;
  },
};

/* ---- Телеведущий ---- */
// общий «экран» головы-телевизора (статика + карточка EAS), рисуется у каждого клиента
const BCTV = { canvas: null, tex: null, t: 0 };
function bcScreen() {
  if (!BCTV.canvas) { BCTV.canvas = document.createElement('canvas'); BCTV.canvas.width = 128; BCTV.canvas.height = 96; BCTV.tex = new THREE.CanvasTexture(BCTV.canvas); BCTV.tex.colorSpace = THREE.SRGBColorSpace; }
  return BCTV.tex;
}
function bcDraw(dt) {
  if (!BCTV.canvas || (BCTV.t += dt) < .07) return; BCTV.t = 0;
  const g = BCTV.canvas.getContext('2d'), W = 128, H = 96, ph = (now() * .5) % 3;
  if (ph < 1.6) { const im = g.createImageData(W, H); for (let i = 0; i < im.data.length; i += 4) { const v = Math.random() * 230; im.data[i] = im.data[i + 1] = im.data[i + 2] = v; im.data[i + 3] = 255; } g.putImageData(im, 0, 0); }
  else { g.fillStyle = '#06070c'; g.fillRect(0, 0, W, H); g.fillStyle = '#c4121a'; g.fillRect(0, 0, W, 22); g.fillStyle = '#fff'; g.font = '900 13px Arial'; g.textAlign = 'center'; g.fillText('EMERGENCY', W / 2, 16); g.font = '700 10px monospace'; g.fillText('НЕПОДЧИНЕНИЕ', W / 2, 44); g.fillText('ОСТАВАЙТЕСЬ', W / 2, 60); g.fillText('НА СВЯЗИ', W / 2, 74); g.fillStyle = '#ffb000'; g.fillRect(0, H - 12, W, 12); }
  BCTV.tex.needsUpdate = true;
}
INMATES.def({
  key: 'broadcaster', num: '000', name: 'ТЕЛЕВЕДУЩИЙ', en: 'THE BROADCASTER', cls: 'ТРАНСЛЯЦИЯ', hp: 9999, speed: 3.0, chase: 3.0, color: '#8a8c90', difficulty: 1,
  special: true, immortal: true, stagger: 2, directive: 'NONE', eye: 1.9,
  alert: ['ЭТА СТАНЦИЯ СЛЕДИТ ЗА ВЫПОЛНЕНИЕМ УКАЗАНИЙ.', 'ГРАЖДАНЕ, НАРУШАЮЩИЕ ДИРЕКТИВЫ ЭКСТРЕННОГО ОПОВЕЩЕНИЯ, БУДУТ ПОСЕЩЕНЫ.', 'ВЕРНИТЕСЬ К ПОРЯДКУ. ОСТАВАЙТЕСЬ НА СВЯЗИ.'],
  tip: 'Приходит к тому, кто не слушается ТВ. Убить нельзя. Выполняй директиву 15 с и уйди с его глаз — исчезнет.',
  model() {
    const p = MM.humanoid({ shirt: '#7d8086', sleeve: '#7d8086', pants: '#6a6d72', s: 1.12, leg: .98, torso: .8 }); const g = p.g; g.userData.parts = p;
    // рубашка, галстук, лацканы
    MM.box(g, .2, .5, .02, '#e8e6e0', 0, p.headH - .3, .17); MM.box(g, .07, .42, .025, '#7a1418', 0, p.headH - .33, .185);
    for (const s of [-1, 1]) MM.box(g, .1, .5, .03, '#5d6066', s * .14, p.headH - .3, .17, { rz: s * .15 });
    // голова-телевизор в деревянном корпусе
    MM.box(p.head, .66, .52, .54, '#6a4426', 0, .3, 0); MM.box(p.head, .58, .44, .02, '#1a1a1a', 0, .3, .275);
    const scr = new THREE.Mesh(new THREE.PlaneGeometry(.5, .37), new THREE.MeshBasicMaterial({ map: bcScreen(), toneMapped: false })); scr.position.set(0, .3, .29); p.head.add(scr);
    for (const s of [-1, 1]) MM.cyl(p.head, .012, .012, .45, '#bbb', s * .1, .7, -.05, { rz: s * .5 });
    MM.sph(p.head, .035, '#ccc', .24, .12, .28); MM.sph(p.head, .035, '#ccc', .24, .2, .28);
    // кабель из шеи
    for (let i = 0; i < 6; i++) MM.cyl(g, .025, .025, .3, '#111', -.05 - i * .02, p.headH - .05 - i * .27, -.2 - i * .05, { rx: .3 });
    return g;
  },
  spawn(m) {
    m.target = DIRECTIVE.nextTarget; m.state = 'arrive'; m.vis = 0; m.arriveT = 0; m.okT = 0; m.relocT = 0;
    const P = GAME.players[m.target]; if (!P) { m.p.set(0, -60, 0); return; }
    this.placeIn(m, P);
  },
  // встать в узел навигации той же комнаты, подальше от игрока (появление в дверном проёме)
  placeIn(m, P) {
    const pos = new V3(P.pose.x, P.pose.y, P.pose.z), room = GAME.roomAt(pos.clone().setY(pos.y + 1));
    let best = null, bd = -1;
    for (const k in WORLD.nav) { const n = WORLD.nav[k]; if (Math.abs(n.p.y - pos.y) > 1.5) continue; const d = n.p.distanceTo(pos); const same = room ? n.room === room : n.room === 'out'; if (same && d > bd && d < 12) { bd = d; best = n; } }
    if (!best) { const k = m.nodeNear(pos); best = WORLD.nav[k]; }
    m.p.copy(best.p); m.path = []; m.room = room;
  },
  tick(m, dt) {
    const P = GAME.players[m.target];
    if (!P || !P.alive) { GAME.removeInmate(m); return; }
    const pos = new V3(P.pose.x, P.pose.y, P.pose.z);
    if (m.state === 'arrive') { m.arriveT += dt; m.vis = 0; m.speedNow = 0; if (m.arriveT > 3) { m.state = 'stalk'; m.vis = 1; GAME.fxAll('static', m.p, { d: .8, v: .4 }); } return; }
    // исчезает, если игрок 15 с подряд слушается и не на виду
    const seen = m.canSee(P.pose, 20);
    m.okT = P.compliant !== false && !seen ? m.okT + dt : 0;
    if (m.okT > 15) { P.static = 40; GAME.pinfoDirty = true; GAME.fxAll('static', m.p, { d: .6, v: .3 }); GAME.sendTo(P.id, { t: 'toast', text: '📺 Сигнал восстановлен. Телеведущий ушёл.' }); GAME.removeInmate(m); return; }
    // сменил комнату — через 4 с он уже там
    const room = GAME.roomAt(pos.clone().setY(pos.y + 1));
    if (room !== m.room && !P.pose.hid) { m.relocT += dt; if (m.relocT > 4) { m.relocT = 0; m.vis = 0; this.placeIn(m, P); m.state = 'arrive'; m.arriveT = 1.6; return; } } else m.relocT = 0;
    if (m.stun > 0) { m.stun -= dt; m.speedNow = 0; m.a = 2; return; }
    m.a = 1;
    if (Math.abs(pos.y - m.p.y) < 1.2 && m.p.distanceTo(pos) < 6 && seen) { m.path = []; m.stepTo(pos, dt, m.T.speed); }
    else { if (!m.path.length || (m.t % 1.2) < dt) m.goNode(m.nodeNear(pos)); m.follow(dt, m.T.speed); }
    // трогает только «своего» игрока; укрытие не спасает от трансляции
    if (Math.hypot(pos.x - m.p.x, pos.z - m.p.z) < 1.0 && Math.abs(pos.y - m.p.y) < 1.4) {
      if (P.pose.hid) { const h = WORLD.hides.find(q => WS[q.id] && WS[q.id].by === P.id); if (h) GAME.toggleHide(P.id, h); }
      GAME.killPlayer(P.id, m);
    }
  },
  anim(m, dt, moving) { const p = m.model.userData.parts; MM.walk(p, m.walkT, moving ? .45 : 0); p.head.rotation.z = m.a === 2 ? Math.sin(m.t * 30) * .2 : Math.sin(m.t * 1.3) * .05; bcDraw(dt); },
  sound(m, dt) {
    if (!AU.ctx || m.vis === 0 || m.p.y < -40) return; m.hum = (m.hum || 0) - dt;
    if (m.hum < 0) { m.hum = 1.6 + Math.random(); AU.play('static', m.p, { d: .35, v: .18 }); if (Math.random() < .4) AU.play('buzz', m.p, { d: .25 }); }
  },
});
