/* ================= НАБОР ПИКСЕЛЬНЫХ ПЕРСОНАЖЕЙ: человечек 32×48 в духе Deltarune (игроки, продавцы, многие заключённые) =================
   PXK.person(p, o, dir, frame, anim) рисует фигуру и возвращает «якоря» (голова, руки) для доп. деталей.
   o: { skin, hair, hairStyle: short|long|bald|spiky|bob|ponytail|messy, shirt, shirt2, pants, shoes,
        hat: none|cap|beanie|headphones|hood|tophat, hatColor, face: smile|grin|worried|cool|blank|creepy|stitched|none,
        eye ('#1a1020'), tall (доп. пиксели роста ног), torsoH, armsUp, armsOut, noArms, bob }  */
const PXK = {
  OUT: '#0d0b10',
  // фаза шага: 0 — стоит, 1 — левая вперёд, 2 — стоит, 3 — правая вперёд
  step(anim, f) { return anim === 'walk' || anim === 'run' || anim === 'chase' ? [0, 1, 0, -1][f % 4] : 0; },
  person(p, o, dir, f, anim) {
    const sk = o.skin || '#f2c9a0', sh = o.shirt || '#3a6ad8', pa = o.pants || '#2a2f45', so = o.shoes || '#ece8e0', hr = o.hair || '#4a2e1c', sole = o.sole || '#8a8478';
    const st = this.step(anim, f), tall = o.tall || 0, bob = o.bob === false ? 0 : (st !== 0 ? -1 : 0);
    const T = o.torsoH || 10, legH = 7 + tall;               // торс и ноги (до обуви)
    const feetY = 46, shoeTop = feetY - 2, legTop = shoeTop - legH, torsoTop = legTop - T, headBot = torsoTop, headTop = headBot - 13;
    const Y = v => v + bob, A = { headTop: Y(headTop), headBot: Y(headBot), cx: 16, torsoTop: Y(torsoTop), legTop, feetY, T };
    if (dir === 'f' || dir === 'b') {
      // ноги: шагающая нога чуть короче (приподнята), обувь светлая с подошвой
      for (const [s, x] of [[1, 12], [-1, 17]]) { const lift = st === s ? 1 : 0; p.r(x, legTop, 3, legH - lift, pa); p.r(x - (s > 0 ? 1 : 0), shoeTop - lift, 4, 1, so); p.r(x - (s > 0 ? 1 : 0), shoeTop + 1 - lift, 4, 1, sole); }
      p.r(15, legTop, 2, 2, pa);
      // торс с ремнём/низом
      p.rr(11, Y(torsoTop), 10, T, sh, 1); p.r(11, Y(torsoTop + T - 1), 10, 1, o.belt || pxShade(pa, -.15));
      if (o.shirt2) { if (dir === 'f') p.r(15, Y(torsoTop + 1), 2, T - 2, o.shirt2); p.r(11, Y(torsoTop), 10, 1, o.shirt2); }
      // руки: 2 пикселя, кисть кожей; ходьба — взмах на 1 пиксель
      if (!o.noArms) for (const [s, x] of [[1, 9], [-1, 21]]) { const sw = o.armsUp ? -7 : (st === -s ? -1 : st === s ? 1 : 0), ax = o.armsOut ? x + (s > 0 ? -1 : 1) : x;
        p.r(ax, Y(torsoTop + 1 + sw), 2, T - 3, o.sleeve || sh); p.r(ax, Y(torsoTop + T - 2 + sw), 2, 2, o.sleeveSkin === false ? (o.sleeve || sh) : (o.hand || sk)); A['hand' + (s > 0 ? 'L' : 'R')] = [ax, Y(torsoTop + T - 1 + sw)]; }
      // голова: большая, скруглённая
      p.rr(9, Y(headTop), 14, 13, sk, 3); p.r(8, Y(headTop + 5), 1, 4, sk); p.r(23, Y(headTop + 5), 1, 4, sk);
      this.hair(p, o, dir, Y(headTop), hr);
      if (dir === 'f') this.face(p, o, Y(headTop));
      this.hat(p, o, dir, Y(headTop));
    } else { // бок, лицом вправо
      const fw = st === 1 ? 2 : st === -1 ? -2 : 0;
      // дальняя нога (темнее), ближняя нога
      p.r(15 - fw, legTop, 3, legH, pxShade(pa, -.2)); p.r(15 - fw, shoeTop, 5, 1, pxShade(so, -.2)); p.r(15 - fw, shoeTop + 1, 5, 1, sole);
      p.r(14 + fw, legTop, 3, legH, pa); p.r(14 + fw, shoeTop, 5, 1, so); p.r(14 + fw, shoeTop + 1, 5, 1, sole);
      p.rr(12, Y(torsoTop), 8, T, sh, 1); p.r(12, Y(torsoTop + T - 1), 8, 1, o.belt || pxShade(pa, -.15));
      p.rr(10, Y(headTop), 13, 13, sk, 3); p.p(23, Y(headTop + 7), sk);
      this.hair(p, o, 's', Y(headTop), hr);
      if (o.face !== 'none') { const e = o.eye || '#1a1020'; if (o.face === 'cool') p.r(18, Y(headTop + 6), 5, 2, '#15151a'); else { p.r(19, Y(headTop + 6), 2, 2, e); p.p(19, Y(headTop + 6), o.face === 'creepy' ? (o.eyeGlow || '#ffffff') : '#ffffff', o.face === 'creepy' && !!o.eyeGlow); }
        if (o.face === 'creepy') p.r(16, Y(headTop + 10), 7, 1, '#3a0505'); else if (o.face !== 'blank') p.r(20, Y(headTop + 10), 2, 1, pxShade(sk, -.4)); }
      this.hat(p, o, 's', Y(headTop));
      if (!o.noArms) { const sw = o.armsUp ? -7 : 0, sx = o.armsUp ? 0 : -fw; p.r(15 + sx, Y(torsoTop + 1 + sw), 2, T - 3, pxShade(o.sleeve || sh, .1)); p.r(15 + sx, Y(torsoTop + T - 2 + sw), 2, 2, o.sleeveSkin === false ? (o.sleeve || sh) : (o.hand || sk)); A.handR = A.handL = [16 + sx, Y(torsoTop + T - 1 + sw)]; }
    }
    if (o.extra) o.extra(p, dir, f, anim, A);
    return A;
  },
  hair(p, o, dir, ht, hr) {
    const s = o.hairStyle || 'short'; if (s === 'bald' || o.hat === 'hood') return; const dk = pxShade(hr, -.25);
    if (dir === 'b') { p.rr(9, ht - 1, 14, s === 'long' || s === 'bob' ? 15 : 11, hr, 3); if (s === 'long') p.r(9, ht + 10, 14, 8, hr); if (s === 'ponytail') p.r(14, ht + 9, 4, 7, hr); for (let i = 0; i < 4; i++) p.p(11 + i * 3, ht + 2 + (i % 2), dk); return; }
    if (dir === 's') { p.rr(10, ht - 1, 12, 5, hr, 2); p.r(10, ht + 3, 6, s === 'long' ? 13 : s === 'bob' ? 9 : 5, hr); p.p(16, ht + 4, hr); if (s === 'spiky') for (let i = 0; i < 4; i++) p.p(11 + i * 3, ht - 2 - (i % 2), hr); if (s === 'ponytail') p.r(7, ht + 4, 3, 7, hr); p.p(13, ht + 1, dk); return; }
    p.rr(8, ht - 1, 16, 5, hr, 3);
    if (s === 'short' || s === 'messy') { p.r(8, ht + 3, 2, 4, hr); p.r(22, ht + 3, 2, 4, hr); p.r(10, ht + 4, 4, 1, hr); p.p(17, ht + 4, hr); if (s === 'messy') { p.p(19, ht + 5, hr); p.p(12, ht + 5, hr); } }
    if (s === 'long' || s === 'bob') { p.r(7, ht + 1, 3, s === 'long' ? 16 : 11, hr); p.r(22, ht + 1, 3, s === 'long' ? 16 : 11, hr); p.r(10, ht + 4, 12, 1, hr); }
    if (s === 'spiky') { for (let i = 0; i < 6; i++) { p.p(9 + i * 3, ht - 2, hr); p.p(9 + i * 3, ht - 3 + (i % 2), hr); } p.r(8, ht + 3, 2, 3, hr); p.r(22, ht + 3, 2, 3, hr); }
    if (s === 'ponytail') { p.r(8, ht + 3, 2, 4, hr); p.r(22, ht + 3, 2, 4, hr); p.r(10, ht + 4, 12, 1, hr); }
    for (let i = 0; i < 4; i++) p.p(11 + i * 3, ht + 1, dk);
  },
  face(p, o, ht) {
    const k = o.face || 'smile', e = o.eye || '#1a1020', sk = o.skin || '#f2c9a0', y = ht + 6;
    if (k === 'none') return;
    const blush = pxShade(sk, -.12);
    if (k === 'cool') { p.r(10, y, 12, 2, '#15151a'); p.p(11, y, '#5a6a8a'); p.p(18, y, '#5a6a8a'); p.p(16, y, '#15151a'); }
    else if (k === 'worried') { p.r(12, y, 2, 3, e); p.r(18, y, 2, 3, e); p.p(12, y, '#ffffff'); p.p(18, y, '#ffffff'); p.l(11, y - 2, 13, y - 3, e); p.l(20, y - 2, 18, y - 3, e); }
    else if (k === 'blank') { p.r(12, y, 2, 2, e); p.r(18, y, 2, 2, e); }
    else if (k === 'creepy') { p.r(12, y, 2, 2, e); p.r(18, y, 2, 2, e); p.p(12, y, o.eyeGlow || '#ffffff', !!o.eyeGlow); p.p(19, y, o.eyeGlow || '#ffffff', !!o.eyeGlow); }
    else { p.r(12, y, 2, 3, e); p.r(18, y, 2, 3, e); p.p(12, y, '#ffffff'); p.p(18, y, '#ffffff'); p.p(11, y + 3, blush); p.p(20, y + 3, blush); }
    const m = pxShade(sk, -.45), my = ht + 10;
    if (k === 'smile' || k === 'cool') { p.p(14, my - 1, m); p.r(15, my, 2, 1, m); p.p(17, my - 1, m); }
    else if (k === 'grin') { p.r(13, my - 1, 6, 2, '#ffffff'); p.r(14, my + 1, 4, 1, m); p.p(12, my - 1, m); p.p(19, my - 1, m); }
    else if (k === 'worried') { p.r(15, my, 2, 1, m); p.p(14, my + 1, m); p.p(17, my + 1, m); }
    else if (k === 'blank') p.r(15, my, 2, 1, m);
    else if (k === 'creepy') { p.r(10, my - 1, 12, 1, '#3a0505'); p.p(9, my - 2, '#3a0505'); p.p(22, my - 2, '#3a0505'); for (let i = 0; i < 6; i++) p.p(11 + i * 2, my - 1, '#e8e2d0'); }
    else if (k === 'stitched') { p.r(12, my, 8, 1, m); for (let i = 0; i < 4; i++) p.p(13 + i * 2, my - 1, m); }
  },
  hat(p, o, dir, ht) {
    const k = o.hat || 'none', c = o.hatColor || '#c4281c'; if (k === 'none') return; const dk = pxShade(c, -.28), lt = pxShade(c, .35);
    if (k === 'cap') { if (dir === 's') { p.rr(10, ht - 2, 13, 5, c, 2); p.r(21, ht + 3, 5, 1, dk); p.p(15, ht - 1, lt); } else { p.rr(8, ht - 2, 16, 5, c, 3); if (dir === 'f') p.r(8, ht + 3, 16, 1, dk); p.p(15, ht - 1, lt); p.p(16, ht - 1, lt); } }
    else if (k === 'beanie') { p.rr(8, ht - 3, 16, 7, c, 3); p.r(8, ht + 3, 16, 1, dk); for (let i = 0; i < 5; i++) p.p(10 + i * 3, ht + 3, lt); p.o(16, ht - 4, 2, 2, '#f2f2f2'); }
    else if (k === 'headphones') { p.r(9, ht - 2, 14, 1, '#222'); if (dir === 's') p.rr(14, ht + 4, 4, 5, c, 1); else { p.rr(6, ht + 4, 3, 6, c, 1); p.rr(23, ht + 4, 3, 6, c, 1); } }
    else if (k === 'hood') { const hc = o.shirt || c, hd = pxShade(hc, -.2); if (dir === 'b') p.rr(8, ht - 2, 16, 16, hc, 4); else if (dir === 's') { p.rr(8, ht - 2, 11, 16, hc, 4); p.r(18, ht - 2, 4, 2, hc); } else { p.rr(7, ht - 2, 18, 5, hc, 3); p.r(7, ht + 2, 3, 12, hc); p.r(22, ht + 2, 3, 12, hc); p.r(10, ht + 2, 1, 10, hd); p.r(21, ht + 2, 1, 10, hd); } }
    else if (k === 'tophat') { p.r(dir === 's' ? 12 : 11, ht - 8, 10, 8, c); p.r(dir === 's' ? 10 : 7, ht - 1, dir === 's' ? 15 : 18, 2, c); p.r(dir === 's' ? 12 : 11, ht - 3, 10, 1, '#8a1010'); }
  },
};

/* ---- игроки и NPC: лист спрайтов по облику (кэш по облику) ---- */
const PX_HAIR = ['#4a2e1c', '#1a1414', '#c89a4a', '#8a3a1a', '#d8d0c8', '#3a2a5a'];
function lookSheetDef(look) {
  const l = Object.assign({}, DEFAULT_LOOK, look), key = 'look_' + JSON.stringify(l);
  const hairStyle = l.hat === 'hair' ? 'messy' : (['short', 'spiky', 'bob', 'ponytail', 'long'][((l.skin * 7 + l.shirt * 3) | 0) % 5]);
  const o = { skin: SKINS[l.skin] || SKINS[0], shirt: SHIRTS[l.shirt] || SHIRTS[0], pants: PANTS[l.pants] || PANTS[0], shoes: ['#ece8e0', '#c4281c', '#2a2a30', '#3a6ad8'][(l.shirt + l.pants) % 4], hat: l.hat === 'hair' ? 'none' : l.hat, hatColor: l.hatColor, face: l.face || 'smile', hairStyle, hair: PX_HAIR[(l.skin + l.pants) % PX_HAIR.length] };
  return { key, w: 32, h: 48, ppm: 21, anims: { idle: { n: 1 }, walk: { n: 4, fps: 7 }, torch: { n: 4, fps: 7 }, crouch: { n: 1 }, dead: { n: 1, dirs: ['f'] }, wave: { n: 2, fps: 4 } },
    draw(p, a, d, f) {
      if (a === 'dead') { PXK.person(p, Object.assign({}, o, { face: 'blank' }), 'f', 0, 'idle'); const q = new PXC(32, 48); for (let y = 0; y < 48; y++) for (let x = 0; x < 32; x++) { const v = p.at(x, y); if (v) q.p(Math.round((47 - y) * .66), 40 + Math.round((x - 16) * .3), v); } p.c = q.c; p.gl = q.gl; for (const [x, y] of [[8, 38], [10, 39]]) p.p(x, y, '#ff3333'); return; }
      const anim = a === 'torch' ? 'walk' : a === 'crouch' ? 'idle' : a === 'wave' ? 'idle' : a;
      PXK.person(p, Object.assign({}, o, { armsUp: a === 'wave' && f === 1 }), d, f, anim);
      if (a === 'torch' && d !== 'b') { const hx = d === 's' ? 18 : 21, hy = 34; p.r(hx, hy, 3, 2, '#2a2a2e'); p.p(hx + 2, hy, '#fff6c8', true); }
      if (a === 'crouch') p.shift(0, 6);
    } };
}
// Пиксельный аватар игрока/NPC — тот же интерфейс, что был у блочного Avatar
class Avatar {
  constructor(look = DEFAULT_LOOK, name = '') {
    this.root = new THREE.Group(); this.look = null; this.tag = null; this.walkT = 0;
    this.torchLens = { material: { color: { set() { } } } };   // совместимость со старым кодом фонарика
    this.setLook(look); if (name) this.setName(name);
  }
  setLook(l) { l = Object.assign({}, DEFAULT_LOOK, l); const k = JSON.stringify(l); if (this.lookKey === k) return; this.lookKey = k; this.look = l;
    if (this.actor) this.root.remove(this.actor); this.actor = new PXActor(lookSheetDef(l)); this.actor.userData.avatar = this; this.root.add(this.actor);
    this.actor.traverse(o => { o.userData.avatar = this; if (this.layer !== undefined) o.layers.set(this.layer); }); }
  setLayer(n) { this.layer = n; this.root.traverse(o => o.layers.set(n)); }
  setName(name, color = '#fff') {
    if (this.tag) { this.root.remove(this.tag); this.tag.material.map.dispose(); }
    this.tag = textSprite(name, { size: 40, stroke: '#000', strokeW: 7, color, scale: .0065, depthTest: true }); this.tag.position.y = 2.0; this.root.add(this.tag);
    if (this.layer !== undefined) this.tag.layers.set(this.layer);
  }
  anim(dt, speed, o = {}) {
    const a = o.dead ? 'dead' : o.crouch ? 'crouch' : o.wave ? 'wave' : speed > .2 ? (o.torch ? 'torch' : 'walk') : (o.torch ? 'torch' : 'idle');
    this.actor.play(a, speed > .2 ? Math.max(.6, speed / 3.6) : (a === 'torch' ? 0 : 1)); this.actor.update(dt);
    if (a === 'torch' && speed <= .2) this.actor.frame = 0;
    if (this.tag) this.tag.visible = !o.hide;
  }
  setPitch() { }
}
