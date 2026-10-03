/* ================= КАРТА «ДОМ 1990»: двухэтажный пригородный дом, двор с яблонями ================= */
// Оси: X — восток, Z — юг (улица на +Z, задний двор на -Z). Первый этаж y=0, второй y=3.
const H1 = 2.8, F2 = 3.0, H2 = 2.8;
const HOUSE = { tv: null, fuse: null, shop: null, trees: [], clocks: [], navNodes: null, entries: [], treeSpots: [] };

function buildHouse() {
  WORLD.reset(); WORLD.level = 'house';
  const g = WORLD.group;
  // ---- материалы ----
  const mWP1 = texMat(TX.floral('#b9b08a', '#8a7a52', 'a'), 3, 1.2), mWP2 = texMat(TX.wallpaper('#7d8a6a', '#6a7656', 'b'), 3, 1.2), mWP3 = texMat(TX.wallpaper('#a8b6c6', '#93a3b6', 'c'), 3, 1.2), mWP4 = texMat(TX.floral('#c9a7a0', '#9a6a66', 'd'), 3, 1.2);
  const mPanel = texMat(TX.panel(), 4, 1), mTile = texMat(TX.tile(), 3, 2), mSiding = texMat(TX.siding(), 4, 2), mConc = texMat(TX.concrete(), 3, 3);
  const mCarpet = texMat(TX.carpet('#6a3a32', 'r'), 6, 6), mCarpet2 = texMat(TX.carpet('#4a5a7a', 'b'), 6, 6), mWood = texMat(TX.wood(), 3, 3), mLino = texMat(TX.lino(), 4, 4), mCeil = mat('#d8d2c2');
  // ---- земля, улица ----
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(140, 140), texMat(TX.grass(), 40, 40)); ground.rotation.x = -PI / 2; ground.position.y = -.01; g.add(ground);
  WORLD.coll.add({ x0: -70, x1: 70, y0: -1, y1: 0, z0: -70, z1: 70 });
  const road = new THREE.Mesh(new THREE.PlaneGeometry(140, 8), mat('#2a2a2c')); road.rotation.x = -PI / 2; road.position.set(0, .01, 21); g.add(road);
  for (let x = -66; x < 70; x += 6) { const l = new THREE.Mesh(new THREE.PlaneGeometry(2.4, .15), mat('#c9b24a')); l.rotation.x = -PI / 2; l.position.set(x, .02, 21); g.add(l); }
  slab(-70, 15.5, 70, 17, .12, .12, mConc); slab(-8, 6, -3, 15.5, .05, .05, mConc); slab(-1.6, 8, -.4, 15.5, .06, .06, mConc);
  // крыльцо
  slab(-3.2, 6, 1.2, 8, .25, .25, mat('#7a6a5a')); bx(-1, 0, 8.2, 1.6, .12, .4, mat('#6a5a4a'));
  for (const px of [-3, 1]) cyl(px, .25, 7.8, .08, 2.6, mat('#e8e2d0'));
  bx(-1, 2.85, 7, 4.6, .12, 2.2, mat('#4a4240'), { coll: false });
  // почтовый ящик, фонарь, соседи
  bx(.6, 0, 15.2, .1, 1, .1, mat('#5a4a3a')); bx(.6, 1, 15.2, .45, .3, .25, mat('#2a4a8a'));
  cyl(-12, 0, 16.2, .08, 5, mat('#2a2a2e')); const sl = new THREE.Mesh(new THREE.SphereGeometry(.25, 10, 8), new THREE.MeshBasicMaterial({ color: '#ffe0a0' })); sl.position.set(-12, 5, 16.2); g.add(sl);
  WORLD.lamps.push({ pos: new V3(-12, 4.6, 16.2), on: () => true, color: '#ffcf80', power: 14, range: 16, room: 'street' });
  for (const [x, z, c] of [[-30, 2, '#4a4a52'], [28, 0, '#3e4048'], [-30, 34, '#454a50'], [10, 36, '#3a3e46'], [-8, 36, '#40403e']]) { bx(x, 0, z, 12, 6, 10, mat(c)); const rf = new THREE.Mesh(new THREE.ConeGeometry(9, 3.5, 4), mat('#262426')); rf.position.set(x, 7.7, z); rf.rotation.y = PI / 4; g.add(rf); for (const wx of [-3, 3]) { const w = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 1.2), new THREE.MeshBasicMaterial({ color: Math.random() < .4 ? '#ffcf70' : '#111318' })); w.position.set(x + wx, 3.6, z + (z > 10 ? -5.01 : 5.01)); if (z > 10) w.rotation.y = PI; g.add(w); } }
  // ---- задний двор: забор, яблони ----
  const fence = mat('#8a6a4a');
  const fenceLine = (x0, z0, x1, z1) => { const L = Math.hypot(x1 - x0, z1 - z0), n = Math.round(L / .5); for (let i = 0; i <= n; i++) { const t = i / n; bx(x0 + (x1 - x0) * t, 0, z0 + (z1 - z0) * t, .12, 1.6, .12, fence, { coll: false }); } bx((x0 + x1) / 2, 1.1, (z0 + z1) / 2, Math.abs(x1 - x0) + .1, .1, Math.abs(z1 - z0) + .1, fence, { coll: false }); WORLD.coll.addBox((x0 + x1) / 2, .9, (z0 + z1) / 2, Math.abs(x1 - x0) + .2, 1.8, Math.abs(z1 - z0) + .2); };
  fenceLine(-14, -24, 14, -24); fenceLine(-14, -24, -14, -6); fenceLine(14, -24, 14, -6); fenceLine(-14, -6, -9.9, -6); fenceLine(9.9, -6, 14, -6); // проходы у углов дома (калитки)
  // невидимые границы мира
  for (const [x, z, sx, sz] of [[0, -40, 140, 2], [0, 40, 140, 2], [-40, 0, 2, 140], [40, 0, 2, 140]]) WORLD.coll.addBox(x, 2, z, sx, 4, sz);
  HOUSE.trees = []; HOUSE.treeSpots = [[-7, -12], [0, -16], [7, -11], [-9, -20], [9, -20], [3, -21]];
  for (let i = 0; i < 6; i++) appleTree(i, HOUSE.treeSpots[i][0], HOUSE.treeSpots[i][1], i < 3);
  bx(-11, 0, -21, 2.4, 2.2, 2, mat('#5a4434')); const shr = new THREE.Mesh(new THREE.ConeGeometry(1.9, 1, 4), mat('#3a2a22')); shr.position.set(-11, 2.7, -21); shr.rotation.y = PI / 4; g.add(shr);

  // ---- наружные стены дома ----
  const X0 = -8, X1 = 8, Z0 = -6, Z1 = 6, wallH = H1 + .2 + H2;
  // фасад (z=6): входная дверь x=-1, ворота гаража x=-5.5, окна гостиной и спален
  wall(X0, Z1, X1, Z1, 0, F2, mWP2, [{ c: -1, w: 1.1, y0: 0, y1: 2.15 }, { c: -5.5, w: 3.2, y0: 0, y1: 2.4 }, { c: 4.5, w: 1.4, y0: .95, y1: 2.05 }], .2, mSiding);
  wall(X0, Z1, X1, Z1, F2, H2, mWP4, [{ c: 4.5, w: 1.4, y0: .95, y1: 2.05 }, { c: -5.5, w: 1.2, y0: .95, y1: 2.05 }], .2, mSiding);
  // задняя стена (z=-6): задняя дверь кухни x=6.5, окна
  wall(X0, Z0, X1, Z0, 0, F2, mWP1, [{ c: 6.5, w: 1.2, y0: 0, y1: 2.1 }, { c: 3.6, w: 1.2, y0: 1.0, y1: 2.0 }, { c: -5.5, w: 1.2, y0: .95, y1: 2.05 }], .2, mSiding);
  wall(X0, Z0, X1, Z0, F2, H2, mWP3, [{ c: 4.5, w: 1.2, y0: .95, y1: 2.05 }, { c: -5.5, w: .9, y0: 1.2, y1: 2.0 }], .2, mSiding);
  // боковые стены
  wall(X1, Z0, X1, Z1, 0, F2, mWP2, [{ c: 4.8, w: 1.2, y0: .95, y1: 2.05 }, { c: -3, w: 1.2, y0: 1.0, y1: 2.0 }], .2, mSiding);
  wall(X1, Z0, X1, Z1, F2, H2, mWP4, [{ c: 3, w: 1.2, y0: .95, y1: 2.05 }, { c: -3, w: 1.2, y0: .95, y1: 2.05 }], .2, mSiding);
  wall(X0, Z0, X0, Z1, 0, F2, mPanel, [{ c: -3.5, w: 1.2, y0: .95, y1: 2.05 }], .2, mSiding);
  wall(X0, Z0, X0, Z1, F2, H2, mWP3, [{ c: 3, w: 1.2, y0: .95, y1: 2.05 }], .2, mSiding);
  // крыша
  const roofG = new THREE.Group(); g.add(roofG); const shm = texMat(TX.shingle(), 8, 3);
  for (const s of [-1, 1]) { const p = new THREE.Mesh(new THREE.BoxGeometry(17.4, .15, 7.6), shm); p.position.set(0, 7.0, s * 3.3); p.rotation.x = s * .48; roofG.add(p); }
  const gable = new THREE.Shape(); gable.moveTo(-6.4, 0); gable.lineTo(6.4, 0); gable.lineTo(0, 2.9); gable.closePath();
  for (const s of [-1, 1]) { const m = new THREE.Mesh(new THREE.ShapeGeometry(gable), mat('#cfc9b4', { side: THREE.DoubleSide })); m.position.set(s * 8.05, 5.8, 0); m.rotation.y = PI / 2; roofG.add(m); }
  // ---- полы и потолки ----
  slab(-3, -6, 1, 6, .02, .02, mWood, false); // прихожая/холл
  slab(1, 0, 8, 6, .02, .02, mCarpet, false); slab(1, -6, 8, 0, .02, .02, mLino, false); slab(-8, -1, -3, 6, .02, .02, mConc, false); slab(-8, -6, -3, -1, .02, .02, mWood, false);
  // перекрытие (с проёмом под лестницу x[-3,-1.9] z[-3.3,0.2])
  const fl2 = (x0, z0, x1, z1, m) => { slab(x0, z0, x1, z1, F2, .2, m); const c = new THREE.Mesh(new THREE.PlaneGeometry(x1 - x0, z1 - z0), mCeil); c.rotation.x = PI / 2; c.position.set((x0 + x1) / 2, H1 - .012, (z0 + z1) / 2); g.add(c); };
  fl2(1, -6, 8, 0, mCarpet2); fl2(1, 0, 8, 6, mCarpet); fl2(-8, -6, -3, 0, mTile); fl2(-8, 0, -3, 6, mCarpet2);
  fl2(-1.9, -6, 1, 6, mWood); fl2(-3, .2, -1.9, 6, mWood); fl2(-3, -6, -1.9, -3.3, mWood);
  const ceil2 = new THREE.Mesh(new THREE.PlaneGeometry(16, 12), mCeil); ceil2.rotation.x = PI / 2; ceil2.position.set(0, F2 + H2, 0); g.add(ceil2);
  WORLD.coll.addBox(0, F2 + H2 + .1, 0, 16, .2, 12);
  // ---- внутренние стены 1 этаж ----
  wall(-3, -6, -3, 6, 0, H1, mPanel, [{ c: 3.5, w: 1.0 }, { c: -4.5, w: 1.0 }]);       // холл | гараж/столовая
  wall(1, -6, 1, 6, 0, H1, mWP2, [{ c: 3.5, w: 1.6, y1: 2.3 }, { c: -2.5, w: 1.4, y1: 2.3 }]); // холл | гостиная/кухня
  wall(1, 0, 8, 0, 0, H1, mWP1, [{ c: 6.7, w: 1.6, y1: 2.3 }]);                        // гостиная | кухня
  wall(-8, -1, -3, -1, 0, H1, mPanel, [{ c: -6.6, w: 1.0 }]);                            // гараж | столовая
  // ---- внутренние стены 2 этаж ----
  wall(-3, -6, -3, 6, F2, H2, mWP3, [{ c: 3, w: 1.0 }, { c: -4.5, w: 1.0 }]);
  wall(1, -6, 1, 6, F2, H2, mWP4, [{ c: 3, w: 1.0 }, { c: -3, w: 1.0 }]);
  wall(1, 0, 8, 0, F2, H2, mWP4); wall(-8, 0, -3, 0, F2, H2, mWP3);
  // лестница (ступени вдоль -Z, от z=0 вверх до z=-3) + перила
  stairs(-2.45, .15, '-z', 1.1, 0, F2, 10, mat('#7a5232'));
  slab(-3, -3.32, -1.9, -2.83, F2, .2, mWood);
  bx(-1.88, F2, -1.6, .06, 1, 3.4, mat('#5a3a22')); bx(-2.45, F2, .25, 1.2, 1, .06, mat('#5a3a22'));
  bx(-1.9, 0, -1.5, .08, 1.0, 3.2, mat('#5a3a22'), { coll: false });
  // ---- двери ----
  const dOut = door('D_front', -1, 6, 'x', 0, { w: 1.1, color: '#7a2a22', front: true, panels: true, opensTo: -1 });
  door('D_back', 6.5, -6, 'x', 0, { w: 1.2, color: '#d8d0b8', front: true, panels: true, opensTo: 1 });
  door('D_garage', -3, 3.5, 'z', 0, { w: 1.0, color: '#c9b38a' }); door('D_dining', -3, -4.5, 'z', 0, { w: 1.0, color: '#c9b38a' }); door('D_gd', -6.6, -1, 'x', 0, { w: 1.0, color: '#c9b38a', lockable: false });
  door('D_bed1', 1, 3, 'z', F2, { w: 1.0, color: '#d8ccb0', opensTo: -1 }); door('D_bed2', 1, -3, 'z', F2, { w: 1.0, color: '#d8ccb0', opensTo: -1 }); door('D_bed3', -3, 3, 'z', F2, { w: 1.0, color: '#d8ccb0' }); door('D_bath', -3, -4.5, 'z', F2, { w: 1.0, color: '#e8e8e8' });
  // ворота гаража (закрыты, декоративные)
  bx(-5.5, 0, 6, 3.2, 2.4, .1, texMat(TX.siding(), 1, 2, '#e8e8e8'));
  // ---- окна (id, позиция, комната, куда смотрит комната) ----
  windowW('W_liv1', 4.5, 6, 'x', 0, { w: 1.4, inside: -1, room: 'living' }); windowW('W_liv2', 8, 4.8, 'z', 0, { inside: -1, room: 'living' });
  windowW('W_kit', 3.6, -6, 'x', 0, { w: 1.2, h: 1, sill: 1.0, inside: 1, room: 'kitchen', curtain: '#c9a24a' }); windowW('W_kit2', 8, -3, 'z', 0, { h: 1, sill: 1.0, inside: -1, room: 'kitchen', curtain: '#c9a24a' });
  windowW('W_din', -8, -3.5, 'z', 0, { inside: 1, room: 'dining', curtain: '#2a4a6a' }); windowW('W_din2', -5.5, -6, 'x', 0, { inside: 1, room: 'dining', curtain: '#2a4a6a' });
  windowW('W_b1a', 4.5, 6, 'x', F2, { w: 1.4, inside: -1, room: 'bed1', curtain: '#6a3a6a' }); windowW('W_b1b', 8, 3, 'z', F2, { inside: -1, room: 'bed1', curtain: '#6a3a6a' });
  windowW('W_b2a', 4.5, -6, 'x', F2, { inside: 1, room: 'bed2', curtain: '#3a6a8a' }); windowW('W_b2b', 8, -3, 'z', F2, { inside: -1, room: 'bed2', curtain: '#3a6a8a' });
  windowW('W_b3a', -5.5, 6, 'x', F2, { inside: -1, room: 'bed3', curtain: '#4a6a3a' }); windowW('W_b3b', -8, 3, 'z', F2, { inside: 1, room: 'bed3', curtain: '#4a6a3a' });
  windowW('W_bath', -5.5, -6, 'x', F2, { w: .9, h: .8, sill: 1.2, inside: 1, room: 'bath', curtain: '#e8e8e8' });
  // ---- комнаты, свет, выключатели ----
  const rooms = [
    ['hall', 'Прихожая', new V3(-1, H1 - .2, 3.5), [-1.1, 0, 5.85, PI]], ['hall2', 'Холл', new V3(-.4, H1 - .2, -3.8), [.9, 0, -1.2, -PI / 2]],
    ['living', 'Гостиная', new V3(4.5, H1 - .2, 3), [1.12, 0, 5, PI / 2]], ['kitchen', 'Кухня', new V3(4.5, H1 - .2, -3), [1.12, 0, -1.4, PI / 2]],
    ['garage', 'Гараж', new V3(-5.5, H1 - .2, 2.5), [-3.12, 0, 4.6, -PI / 2]], ['dining', 'Столовая', new V3(-5.5, H1 - .2, -3.5), [-3.12, 0, -3.4, -PI / 2]],
    ['hallU', 'Коридор 2 эт.', new V3(-.4, F2 + H2 - .2, 2), [.9, F2, 1.5, -PI / 2]], ['bed1', 'Спальня', new V3(4.5, F2 + H2 - .2, 3), [1.12, F2, 4.1, PI / 2]],
    ['bed2', 'Детская', new V3(4.5, F2 + H2 - .2, -3), [1.12, F2, -1.9, PI / 2]], ['bed3', 'Кабинет', new V3(-5.5, F2 + H2 - .2, 3), [-3.12, F2, 4.1, -PI / 2]], ['bath', 'Ванная', new V3(-5.5, F2 + H2 - .2, -3), [-3.12, F2, -3.4, -PI / 2]],
  ];
  for (const [id, name, lp, sw] of rooms) { roomLight(id, lp, { color: id === 'garage' ? '#e8f0ff' : id === 'bath' ? '#f0f4ff' : '#ffd9a0' }); lightSwitch(id, sw[0], sw[1], sw[2], sw[3], name); WORLD.rooms.push({ id, name, c: lp.clone().setY(lp.y > 3 ? F2 : 0) }); }
  // ---- мебель ----
  furnishHouse();
  // ---- навигация для заключённых ----
  buildHouseNav();
  WORLD.spawn = [new V3(-1, 0, 4.2), new V3(-.2, 0, 3.6), new V3(-1.8, 0, 3.2), new V3(-.5, 0, 2.6), new V3(-1.4, 0, 1.6), new V3(.2, 0, 1.4), new V3(-2, 0, 2), new V3(-1, 0, 1)];
  HOUSE.entries = [{ kind: 'door', id: 'D_front', out: new V3(-1, 0, 8.6), in: new V3(-1, 0, 4.6) }, { kind: 'door', id: 'D_back', out: new V3(6.5, 0, -8), in: new V3(6.5, 0, -4.8) }, ...WORLD.windows.filter(w => w.y < 1).map(w => ({ kind: 'window', id: w.id, out: w.outPt, in: w.inPt }))];
}
/* ---- яблоня ---- */
function appleTree(i, x, z, active) {
  const id = 'T_' + i, gT = new THREE.Group(); gT.position.set(x, 0, z); WORLD.add(gT);
  const trunk = new THREE.Mesh(new THREE.CylinderGeometry(.22, .3, 2.2, 8), mat('#5a3e2a')); trunk.position.y = 1.1; gT.add(trunk);
  const crown = new THREE.Group(); gT.add(crown);
  for (const [cx, cy, cz, r] of [[0, 2.9, 0, 1.5], [.8, 2.5, .3, 1], [-.7, 2.6, -.4, 1.1], [.2, 3.6, -.2, 1]]) { const b = new THREE.Mesh(new THREE.IcosahedronGeometry(r, 1), mat('#2f5a26', { flatShading: true })); b.position.set(cx, cy, cz); crown.add(b); }
  const apples = []; for (let k = 0; k < 4; k++) { const a = new THREE.Mesh(new THREE.SphereGeometry(.13, 8, 6), mat('#c81e1e')); const an = k * 1.7 + i; a.position.set(Math.cos(an) * 1.25, 2.1 + (k % 2) * .5, Math.sin(an) * 1.25); gT.add(a); apples.push(a); }
  const coll = WORLD.coll.addBox(x, 1.1, z, .5, 2.2, .5); coll.on = active;
  const t = { id, x, z, group: gT, apples, coll }; HOUSE.trees.push(t);
  interactable({ id, mesh: [trunk, crown], pos: new V3(x, 1.2, z), init: { n: active ? 2 : 0, on: active ? 1 : 0 }, hold: .8, range: 3.2,
    label: () => !WS[id].on ? '' : WS[id].n > 0 ? 'Сорвать яблоко (держи) — ' + WS[id].n + ' шт.' : 'Яблок пока нет',
    cond: () => WS[id].on && WS[id].n > 0,
    use: pid => GAME.pickApple(pid, id),
    apply: s => { gT.visible = !!s.on; coll.on = !!s.on; apples.forEach((a, k) => a.visible = k < s.n); } });
}
/* ---- мебель и интерактивы дома ---- */
function furnishHouse() {
  const g = WORLD.group;
  // гостиная: ЭЛТ-телевизор, диван, кресло, столик, ковёр, часы
  const tvG = new THREE.Group(); tvG.position.set(7.35, 0, 2.6); tvG.rotation.y = -PI / 2; g.add(tvG);
  const stand = new THREE.Mesh(new THREE.BoxGeometry(1.4, .55, .6), mat('#4a3424')); stand.position.y = .275; tvG.add(stand);
  const tvBody = new THREE.Mesh(new THREE.BoxGeometry(1.05, .85, .75), mat('#2a2826')); tvBody.position.set(0, .98, -.02); tvG.add(tvBody);
  const scrC = document.createElement('canvas'); scrC.width = 320; scrC.height = 240; const scrT = new THREE.CanvasTexture(scrC); scrT.colorSpace = THREE.SRGBColorSpace;
  const screen = new THREE.Mesh(new THREE.PlaneGeometry(.82, .62), new THREE.MeshBasicMaterial({ map: scrT, toneMapped: false })); screen.position.set(-.06, .99, .36); tvG.add(screen);
  for (const s of [-1, 1]) { const k = new THREE.Mesh(new THREE.CylinderGeometry(.035, .035, .03, 8), mat('#888')); k.rotation.x = PI / 2; k.position.set(.42, .9 + s * .12, .37); tvG.add(k); }
  const ant = new THREE.Mesh(new THREE.CylinderGeometry(.01, .01, .7, 4), mat('#aaa')); ant.position.set(.15, 1.6, 0); ant.rotation.z = .5; tvG.add(ant); const ant2 = ant.clone(); ant2.rotation.z = -.5; ant2.position.x = -.15; tvG.add(ant2);
  WORLD.coll.addBox(7.35, .7, 2.6, .7, 1.4, 1.4);
  const tvGlow = { pos: new V3(6.6, 1.1, 2.6), on: () => HOUSE.tv && HOUSE.tv.on, color: '#7aa8ff', power: 3.5, range: 6, room: 'living', flicker: true };
  WORLD.lamps.push(tvGlow);
  HOUSE.tv = { canvas: scrC, tex: scrT, screen, on: true, mode: 'show', pos: new V3(7, 1, 2.6), glow: tvGlow };
  interactable({ id: 'TV', mesh: [tvBody, screen], pos: HOUSE.tv.pos, init: { on: 1 }, range: 3,
    label: () => GAME.alertActive() ? 'Смотреть экстренное оповещение' : (WS.TV.on ? 'Выключить телевизор' : 'Включить телевизор'),
    use: pid => GAME.useTV(pid), apply: s => { HOUSE.tv.on = !!s.on; } });
  sofa(4.4, 2.6, PI / 2, '#6a4a3a'); sofa(3.1, 5.2, PI, '#5a5a3a', 1.2);
  bx(5.6, 0, 2.6, .9, .42, 1.2, mat('#5a3a22')); // журнальный столик
  rug(4.6, 2.8, 3.4, 3, '#6a2a2a');
  clock(1.1, 2.1, 1.3, PI / 2); clock(7.9, 1.9, -4.5, -PI / 2);
  plant(1.5, 5.5); plant(7.5, .5); lamp(7.4, 5.4);
  // кухня
  const counter = mat('#d8cfb8'), cab = mat('#8a6a42');
  // столешницы не загораживают заднюю дверь (x 6..7): свободный проход ~1.7 м
  bx(7.55, 0, -3.2, .8, .9, 3.4, cab); bx(7.55, .9, -3.2, .85, .05, 3.4, counter);
  bx(3.8, 0, -5.55, 3.2, .9, .8, cab); bx(3.8, .9, -5.55, 3.2, .05, .85, counter);
  bx(7.55, 0, -.9, .8, 1.9, .8, mat('#e8e8e2')); // холодильник
  bx(4.6, .95, -5.6, .6, .02, .45, mat('#8a9aa2'), { coll: false });
  table(4.2, -2.6, 1.6, 1, '#9a7a52'); for (const [cx, cz] of [[3.3, -2.6], [5.1, -2.6], [4.2, -3.3], [4.2, -1.9]]) chair(cx, cz, '#7a5a3a');
  const radio = bx(7.5, .95, -4.6, .5, .3, .3, mat('#3a2a1a'), { coll: false });
  // кладовка-укрытие
  const pantry = wardrobe(1.75, -5.45, 0, 0, '#9a7a4a', 1.2); hideSpot('H_pantry', new V3(1.75, 0, -5.45), 0, pantry, 'Спрятаться в кладовке');
  // гараж: щиток, прилавок продавца, стеллажи, верстак
  const fuseBox = bx(-7.85, 1.2, 1.2, .14, .6, .45, mat('#6a6a70'));
  const fuseLamp = new THREE.Mesh(new THREE.SphereGeometry(.04, 6, 4), new THREE.MeshBasicMaterial({ color: '#3f3' })); fuseLamp.position.set(-7.76, 1.7, 1.2); g.add(fuseLamp);
  HOUSE.fuse = { mesh: fuseBox, lamp: fuseLamp, pos: new V3(-7.6, 1.5, 1.2) };
  interactable({ id: 'FUSE', mesh: fuseBox, pos: HOUSE.fuse.pos, init: { on: 1 }, hold: .6, range: 2.4,
    label: () => WS.FUSE.on ? 'Выключить электричество (щиток)' : 'Включить электричество (держи)', use: pid => GAME.useFuse(pid),
    apply: s => fuseLamp.material.color.set(s.on ? '#3f3' : '#f33') });
  const counterTop = bx(-5.6, 0, .1, 2.6, 1.0, .7, mat('#7a5a3a')); bx(-5.6, 1, .1, 2.7, .06, .8, mat('#a88a5a'));
  textSignMesh(['ЯБЛОКИ ✦ МАГАЗИН'], -5.8, 2.15, -.35, 0, 2.4, '#3a1a0a', '#ffd06a');
  HOUSE.shop = { pos: new V3(-5.8, 0, -.5), npc: null };
  for (const sx of [-7.6, -3.6]) { bx(sx, 0, 5.2, .5, 2, 1.4, mat('#5a5a5e')); }
  bx(-4.3, 0, -.6, .6, 1.8, .4, mat('#5a5a5e'), { coll: true });
  // столовая
  table(-5.5, -3.6, 2, 1.1, '#6a4a2a'); for (const [cx, cz] of [[-6.4, -3.6], [-4.6, -3.6], [-5.5, -4.4], [-5.5, -2.8]]) chair(cx, cz, '#5a3a22');
  const china = wardrobe(-7.5, -5.4, PI / 2, 0, '#5a3a22', 1.4, true);
  clock(-7.88, 2.0, -2.2, PI / 2);
  // прихожая: шкаф для одежды-укрытие, коврик
  const coat = wardrobe(-2.45, 5.55, 0, 0, '#8a6a4a', 1.0); hideSpot('H_coat', new V3(-2.45, 0, 5.4), 0, coat, 'Спрятаться в шкаф с куртками');
  rug(-1, 4.6, 1.4, 2.2, '#4a2a3a');
  // спальня 1 (родители)
  bed(5.4, 4.6, PI, '#7a4a6a', 1.6); const w1 = wardrobe(7.55, 1, -PI / 2, F2, '#6a4a2a'); hideSpot('H_bed1', new V3(7.4, F2, 1), -PI / 2, w1);
  bx(2, F2, 5.6, 1, .8, .5, mat('#6a4a2a')); lamp(2.1, 5.6, F2 + .8, true); rug(4.5, 3, 3, 2.4, '#4a3a5a', F2);
  // спальня 2 (детская)
  bed(6.4, -4.8, 0, '#3a6a9a', 1.0); const w2 = wardrobe(1.6, -.5, PI, F2, '#9a6a3a'); hideSpot('H_bed2', new V3(1.6, F2, -.65), PI, w2);
  bx(4, F2, -.5, .8, .5, .5, mat('#c03a2a')); for (let k = 0; k < 4; k++) bx(2.5 + k * .3, F2, -4.6 + (k % 2) * .4, .25, .25, .25, mat(['#e84a3a', '#3a8ae8', '#e8c83a', '#3ac85a'][k]), { coll: false });
  // кабинет: кровать, стол с компьютером, кладовка
  bed(-6.6, 1.2, PI / 2, '#5a6a4a', 1.0); bx(-4, F2, 5.55, 1.6, .75, .7, mat('#5a4030')); bx(-4, F2 + .75, 5.55, .5, .45, .45, mat('#d8d0b8'), { coll: false });
  const w3 = wardrobe(-7.55, 4.6, PI / 2, F2, '#7a5a3a'); hideSpot('H_bed3', new V3(-7.4, F2, 4.6), PI / 2, w3);
  // ванная
  bx(-6.6, F2, -5.2, 2.2, .55, .9, mat('#f0f0f0')); bx(-4, F2, -5.6, .45, .45, .6, mat('#f4f4f4')); bx(-3.6, F2, -1, .55, .85, .45, mat('#e8e8e8'));
  const mirror = new THREE.Mesh(new THREE.PlaneGeometry(.6, .8), new THREE.MeshLambertMaterial({ color: '#9ab0c0', emissive: '#101820' })); mirror.position.set(-3.6, F2 + 1.5, -.79); mirror.rotation.y = PI; g.add(mirror);
  // коридор 2 эт.: бельевой шкаф-укрытие
  const lin = wardrobe(-.4, 5.55, 0, F2, '#d8ccb0', 1.0); hideSpot('H_linen', new V3(-.4, F2, 5.4), 0, lin, 'Спрятаться в бельевой шкаф');
  // ---- продавец яблок ----
  const npcA = new Avatar({ skin: 1, shirt: 3, pants: 1, hat: 'cap', face: 'grin', hatColor: '#c4281c' }); // вывеска над прилавком вместо таблички с именем
  npcA.root.position.set(-5.8, 0, -.45); npcA.root.rotation.y = 0; g.add(npcA.root); HOUSE.shop.npc = npcA;
  WORLD.coll.addBox(-5.8, .9, -.45, .7, 1.8, .5);
  interactable({ id: 'SHOP', mesh: [npcA.actor.mesh, counterTop], pos: new V3(-5.8, 1.3, .1), range: 3,
    label: () => GAME.shopOpen() ? 'Магазин: продать яблоки и купить вещи' : 'Магазин закрыт до утра', use: pid => GAME.openShop(pid) });
}
function textSignMesh(lines, x, y, z, ry, w, bg, fg) { const p = textPlane(lines, w, { bg, color: fg, size: 52, pad: 18, radius: 12 }); p.position.set(x, y, z); p.rotation.y = ry; WORLD.add(p); return p; }
function sofa(x, z, ry, c, len = 2.2) { const gr = new THREE.Group(); gr.position.set(x, 0, z); gr.rotation.y = ry; WORLD.add(gr); const m = mat(c); const seat = new THREE.Mesh(new THREE.BoxGeometry(len, .45, .9), m); seat.position.y = .25; gr.add(seat); const back = new THREE.Mesh(new THREE.BoxGeometry(len, .55, .25), m); back.position.set(0, .7, -.33); gr.add(back); for (const s of [-1, 1]) { const arm = new THREE.Mesh(new THREE.BoxGeometry(.22, .62, .9), m); arm.position.set(s * (len / 2 - .11), .32, 0); gr.add(arm); } const sw = Math.abs(Math.sin(ry)) > .7; WORLD.coll.addBox(x, .4, z, sw ? .95 : len, .8, sw ? len : .95); }
function table(x, z, sx, sz, c, y = 0) { const m = mat(c); const top = new THREE.Mesh(new THREE.BoxGeometry(sx, .06, sz), m); top.position.set(x, y + .76, z); WORLD.add(top); for (const a of [-1, 1]) for (const b of [-1, 1]) { const l = new THREE.Mesh(new THREE.BoxGeometry(.06, .76, .06), m); l.position.set(x + a * (sx / 2 - .08), y + .38, z + b * (sz / 2 - .08)); WORLD.add(l); } WORLD.coll.addBox(x, y + .4, z, sx, .8, sz); }
function chair(x, z, c, y = 0) { const m = mat(c); bx(x, y, z, .42, .46, .42, m, { coll: false }); bx(x, y + .46, z + .18, .42, .5, .05, m, { coll: false }); WORLD.coll.addBox(x, y + .25, z, .4, .5, .4); }
function bed(x, z, ry, c, w = 1.4, y) { y = y ?? F2; const gr = new THREE.Group(); gr.position.set(x, y, z); gr.rotation.y = ry; WORLD.add(gr); const fr = new THREE.Mesh(new THREE.BoxGeometry(w, .35, 2.1), mat('#5a3a22')); fr.position.y = .2; gr.add(fr); const mt = new THREE.Mesh(new THREE.BoxGeometry(w - .06, .2, 2), mat('#e8e2d4')); mt.position.y = .45; gr.add(mt); const bl = new THREE.Mesh(new THREE.BoxGeometry(w - .02, .08, 1.4), mat(c)); bl.position.set(0, .58, .3); gr.add(bl); const pl = new THREE.Mesh(new THREE.BoxGeometry(w * .7, .12, .4), mat('#f4f0e8')); pl.position.set(0, .6, -.75); gr.add(pl); const hb = new THREE.Mesh(new THREE.BoxGeometry(w, .9, .08), mat('#5a3a22')); hb.position.set(0, .6, -1.05); gr.add(hb); const sw = Math.abs(Math.sin(ry)) > .7; WORLD.coll.addBox(x, y + .3, z, sw ? 2.1 : w, .6, sw ? w : 2.1); }
function wardrobe(x, z, ry, y, c, w = 1.2, glass) {
  const gr = new THREE.Group(); gr.position.set(x, y, z); gr.rotation.y = ry; WORLD.add(gr);
  const body = new THREE.Mesh(new THREE.BoxGeometry(w, 2.1, .62), mat(c)); body.position.y = 1.05; gr.add(body);
  for (const s of [-1, 1]) { const d = new THREE.Mesh(new THREE.BoxGeometry(w / 2 - .04, 1.95, .03), mat(glass ? '#8aa0b0' : shadeHex(c, -.1))); d.position.set(s * w / 4, 1.05, .32); gr.add(d); const h = new THREE.Mesh(new THREE.BoxGeometry(.03, .18, .04), mat('#d4b04a')); h.position.set(s * .06, 1.1, .35); gr.add(h); }
  const sw = Math.abs(Math.sin(ry)) > .7; WORLD.coll.addBox(x, y + 1.05, z, sw ? .62 : w, 2.1, sw ? w : .62);
  return body;
}
function rug(x, z, sx, sz, c, y = 0) { const r = new THREE.Mesh(new THREE.PlaneGeometry(sx, sz), texMat(TX.carpet(c, c), 2, 2)); r.rotation.x = -PI / 2; r.position.set(x, y + .03, z); WORLD.add(r); }
function plant(x, z, y = 0) { cyl(x, y, z, .18, .35, mat('#8a4a2a'), { r2: .22 }); for (let i = 0; i < 5; i++) { const l = new THREE.Mesh(new THREE.ConeGeometry(.12, .7, 5), mat('#2f6a2a')); l.position.set(x + Math.cos(i * 1.3) * .1, y + .7, z + Math.sin(i * 1.3) * .1); l.rotation.set(Math.cos(i) * .4, 0, Math.sin(i * 1.3) * .4); WORLD.add(l); } }
function lamp(x, z, y = 0, small) { if (!small) cyl(x, y, z, .04, 1.5, mat('#3a3a3a'), { coll: false }); const sh = new THREE.Mesh(new THREE.CylinderGeometry(.15, .25, .3, 10, 1, true), mat('#e8d8a8', { side: THREE.DoubleSide, emissive: '#3a2a10' })); sh.position.set(x, y + (small ? .3 : 1.55), z); WORLD.add(sh); }
function clock(x, y, z, ry) {
  const c = document.createElement('canvas'); c.width = c.height = 128; const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  const m = new THREE.Mesh(new THREE.CircleGeometry(.28, 24), new THREE.MeshLambertMaterial({ map: t })); m.position.set(x, y, z); m.rotation.y = ry; WORLD.add(m);
  const rim = new THREE.Mesh(new THREE.TorusGeometry(.28, .03, 6, 24), mat('#3a2a1a')); rim.position.copy(m.position); rim.rotation.y = ry; WORLD.add(rim);
  HOUSE.clocks.push({ c, t, last: -1 });
}
function drawClocks(hours) {
  const k = Math.floor(hours * 12); for (const cl of HOUSE.clocks) { if (cl.last === k) continue; cl.last = k; const g = cl.c.getContext('2d');
    g.fillStyle = '#f4ecd8'; g.fillRect(0, 0, 128, 128); g.strokeStyle = '#222'; g.lineCap = 'round';
    for (let i = 0; i < 12; i++) { const a = i / 12 * TAU; g.lineWidth = 3; g.beginPath(); g.moveTo(64 + Math.sin(a) * 50, 64 - Math.cos(a) * 50); g.lineTo(64 + Math.sin(a) * 58, 64 - Math.cos(a) * 58); g.stroke(); }
    const h = hours % 12, mnt = (hours % 1) * 60, ah = h / 12 * TAU, am = mnt / 60 * TAU;
    g.lineWidth = 6; g.beginPath(); g.moveTo(64, 64); g.lineTo(64 + Math.sin(ah) * 30, 64 - Math.cos(ah) * 30); g.stroke(); g.lineWidth = 3; g.beginPath(); g.moveTo(64, 64); g.lineTo(64 + Math.sin(am) * 46, 64 - Math.cos(am) * 46); g.stroke();
    cl.t.needsUpdate = true; }
}
/* ---- граф навигации ---- */
function buildHouseNav() {
  const N = {}, E = [], add = (id, x, y, z, room) => N[id] = { id, p: new V3(x, y, z), room, nb: [] };
  const link = (a, b, door) => { N[a].nb.push({ to: b, door }); N[b].nb.push({ to: a, door }); };
  // снаружи
  const O = 'out'; add('street', -1, 0, 14, O); add('porch', -1, 0, 8.6, O); add('frontL', -9.5, 0, 8, O); add('frontR', 9.5, 0, 8, O); add('sideL', -9.5, 0, -3, O); add('sideR', 9.5, 0, -3, O); add('backL', -8, 0, -8, O); add('backR', 6.5, 0, -8, O); add('yard', 0, 0, -13, O); add('yard2', -8, 0, -16, O); add('yard3', 8, 0, -16, O);
  link('street', 'porch'); link('porch', 'frontL'); link('porch', 'frontR'); link('frontL', 'sideL'); link('frontR', 'sideR'); add('cornerL', -9.1, 0, -7.2, O); add('cornerR', 9.1, 0, -7.2, O); link('sideL', 'cornerL'); link('cornerL', 'backL'); link('sideR', 'cornerR'); link('cornerR', 'backR'); link('backL', 'yard'); link('backR', 'yard'); link('yard', 'yard2'); link('yard', 'yard3'); link('backL', 'backR');
  // 1 этаж
  add('foyer', -1, 0, 4.4, 'hall'); add('hallM', -.6, 0, 1.6, 'hall'); add('hallS', -.4, 0, -4.4, 'hall2'); add('stairB', -2.45, 0, .9, 'hall');
  add('livD', 1, 0, 3.5); add('liv', 4, 0, 3.6, 'living'); add('liv2', 6, 0, 1.2, 'living'); add('arch', 6.7, 0, 0);
  add('kitD', 1, 0, -2.5); add('kit', 4.3, 0, -1.2, 'kitchen'); add('kit2', 6.2, 0, -4.6, 'kitchen'); add('backIn', 6.5, 0, -4.9, 'kitchen');
  add('garD', -3, 0, 3.5); add('gar', -5.2, 0, 3.2, 'garage'); add('gar2', -6.4, 0, 1.6, 'garage'); add('gdD', -6.6, 0, -1);
  add('dinD', -3, 0, -4.5); add('din', -5.5, 0, -2.4, 'dining'); add('din2', -6.6, 0, -1.9, 'dining');
  link('porch', 'foyer', 'D_front'); link('foyer', 'hallM'); link('hallM', 'stairB'); link('hallM', 'hallS'); link('hallM', 'livD'); link('foyer', 'livD'); link('livD', 'liv'); link('liv', 'liv2'); link('liv2', 'arch'); link('arch', 'kit');
  link('hallS', 'kitD'); link('hallM', 'kitD'); link('kitD', 'kit'); link('kit', 'kit2'); link('kit2', 'backIn'); link('backIn', 'backR', 'D_back');
  link('foyer', 'garD'); link('hallM', 'garD'); link('garD', 'gar', 'D_garage'); add('garBk', -7.55, 0, .1, 'garage'); link('gar', 'gar2'); link('gar2', 'garBk'); link('garBk', 'gdD'); link('gdD', 'din2', 'D_gd'); link('din2', 'din');
  link('hallS', 'dinD'); link('dinD', 'din', 'D_dining');
  // лестница и 2 этаж
  add('stairT', -2.45, F2, -3.7, 'hallU'); add('hallU1', -1, F2, -4.4, 'hallU'); add('hallU2', -.4, F2, .6, 'hallU'); add('hallU3', -.6, F2, 4.4, 'hallU');
  link('stairB', 'stairT'); link('stairT', 'hallU1'); link('hallU1', 'hallU2'); link('hallU2', 'hallU3');
  add('b1D', 1, F2, 3); add('b1', 4.2, F2, 2.4, 'bed1'); add('b1b', 6.2, F2, 1.2, 'bed1'); link('hallU3', 'b1D'); link('hallU2', 'b1D'); link('b1D', 'b1', 'D_bed1'); link('b1', 'b1b');
  add('b2D', 1, F2, -3); add('b2', 4.2, F2, -2.4, 'bed2'); add('b2b', 4.6, F2, -4.6, 'bed2'); link('hallU1', 'b2D'); link('hallU2', 'b2D'); link('b2D', 'b2', 'D_bed2'); link('b2', 'b2b');
  add('b3D', -3, F2, 3); add('b3', -5, F2, 3.6, 'bed3'); add('b3b', -5.5, F2, 1, 'bed3'); link('hallU3', 'b3D'); link('hallU2', 'b3D'); link('b3D', 'b3', 'D_bed3'); link('b3', 'b3b');
  add('baD', -3, F2, -4.5); add('ba', -5.2, F2, -3, 'bath'); link('hallU1', 'baD'); link('baD', 'ba', 'D_bath');
  // окна первого этажа — проходы для взлома
  // ближайший обычный узел с прямой видимостью (узлы окон не считаются — иначе окно ссылается само на себя)
  const nearest = (p, inside) => { const c = []; for (const k in N) { const n = N[k]; if (n.win || !n.room || (inside ? n.room === 'out' : n.room !== 'out')) continue; if (Math.abs(n.p.y - p.y) > 1) continue; c.push([n.p.distanceTo(p), k]); } c.sort((a, b) => a[0] - b[0]);
    for (const [, k] of c) if (WORLD.coll.los({ x: p.x, y: p.y + 1, z: p.z }, { x: N[k].p.x, y: N[k].p.y + 1, z: N[k].p.z }, b => !b.door)) return k; return c.length ? c[0][1] : null; };
  for (const w of WORLD.windows) { if (w.y > 1) continue; const a = 'wi_' + w.id, b = 'wo_' + w.id; add(a, w.inPt.x, 0, w.inPt.z, w.room); add(b, w.outPt.x, 0, w.outPt.z, 'out'); N[a].win = w.id; N[b].win = w.id; link(a, b, 'win:' + w.id); link(a, nearest(w.inPt, true)); link(b, nearest(w.outPt, false)); }
  WORLD.nav = N;
}
