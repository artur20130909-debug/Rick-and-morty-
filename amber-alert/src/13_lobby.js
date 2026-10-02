/* ================= ЛОББИ: ночная площадь, киоски, магазин, порталы, лечебница, кабинки ================= */
const LOBBY = { booths: [], cells: [], tv: null, boards: [] };
function buildLobby() {
  WORLD.reset(); WORLD.level = 'lobby'; LOBBY.booths = []; LOBBY.cells = []; LOBBY.boards = [];
  const g = WORLD.group;
  // земля: асфальт площади и трава
  const grass = new THREE.Mesh(new THREE.PlaneGeometry(160, 160), texMat(TX.grass(), 40, 40)); grass.rotation.x = -PI / 2; grass.position.y = -.02; g.add(grass);
  WORLD.coll.add({ x0: -80, x1: 80, y0: -1, y1: 0, z0: -80, z1: 80 });
  const plaza = new THREE.Mesh(new THREE.CircleGeometry(24, 48), texMat(TX.concrete(), 10, 10, '#8a8a90')); plaza.rotation.x = -PI / 2; plaza.position.set(0, .01, 0); g.add(plaza);
  const ring = new THREE.Mesh(new THREE.RingGeometry(23.4, 24, 64), mat('#c9a24a')); ring.rotation.x = -PI / 2; ring.position.y = .02; g.add(ring);
  const path = new THREE.Mesh(new THREE.PlaneGeometry(8, 22), texMat(TX.concrete(), 3, 8, '#7a7a80')); path.rotation.x = -PI / 2; path.position.set(0, .015, -28); g.add(path);
  // точка появления
  const pad = new THREE.Mesh(new THREE.CylinderGeometry(3, 3.2, .2, 32), mat('#2a2e38')); pad.position.set(0, .1, 10); g.add(pad); WORLD.coll.addBox(0, .1, 10, 5.6, .2, 5.6);
  const padRing = new THREE.Mesh(new THREE.TorusGeometry(2.6, .06, 6, 40), new THREE.MeshBasicMaterial({ color: '#ffb000' })); padRing.rotation.x = PI / 2; padRing.position.set(0, .22, 10); g.add(padRing);
  WORLD.ticks.push(dt => padRing.material.color.setHSL(.11, 1, .45 + Math.sin(now() * 2) * .1));
  WORLD.spawn = [0, 1, 2, 3, 4, 5, 6, 7].map(i => new V3(Math.cos(i * .8) * 1.4, .2, 10 + Math.sin(i * .8) * 1.4));
  // ---- экран оповещения над площадью ----
  const tvC = document.createElement('canvas'); tvC.width = 512; tvC.height = 288; const tvT = new THREE.CanvasTexture(tvC); tvT.colorSpace = THREE.SRGBColorSpace;
  const bb = new THREE.Group(); bb.position.set(0, 0, 21); bb.rotation.y = PI; g.add(bb);
  for (const s of [-1, 1]) { const post = new THREE.Mesh(new THREE.BoxGeometry(.3, 6, .3), mat('#2a2a30')); post.position.set(s * 3.5, 3, 0); bb.add(post); }
  const frame = new THREE.Mesh(new THREE.BoxGeometry(8.4, 4.9, .4), mat('#1a1a1e')); frame.position.y = 5.6; bb.add(frame);
  const scr = new THREE.Mesh(new THREE.PlaneGeometry(8, 4.5), new THREE.MeshBasicMaterial({ map: tvT, toneMapped: false })); scr.position.set(0, 5.6, .21); bb.add(scr);
  WORLD.coll.addBox(0, 3, 21, 8, 6, .5);
  LOBBY.tv = { canvas: tvC, tex: tvT }; WORLD.lamps.push({ pos: new V3(0, 5, 19.5), on: () => true, color: '#ff8a40', power: 6, range: 12 });
  // ---- киоски ----
  kiosk('K_QUESTS', -11, 4, .55, 'ЗАДАНИЯ', '#3a7ad8', { skin: 2, shirt: 4, pants: 1, hat: 'cap', face: 'smile', hatColor: '#3a7ad8' }, 'Задания');
  kiosk('K_CLASSES', -6, -1, .25, 'КЛАССЫ', '#36a85a', { skin: 3, shirt: 2, pants: 3, hat: 'beanie', face: 'cool', hatColor: '#36a85a' }, 'Классы');
  kiosk('K_SKINS', 6, -1, -.25, 'СКИНЫ', '#d8489a', { skin: 1, shirt: 7, pants: 6, hat: 'headphones', face: 'grin', hatColor: '#d8489a' }, 'Скины');
  kiosk('K_CODES', 11, 4, -.55, 'КОДЫ', '#8a5ad8', { skin: 0, shirt: 4, pants: 1, hat: 'hood', face: 'worried' }, 'Коды');
  // ---- центральный магазин (3.0) ----
  const shop = new THREE.Group(); shop.position.set(0, 0, -8); g.add(shop);
  const sb = new THREE.Mesh(new THREE.BoxGeometry(9, 4.2, 5), texMat(TX.brick(), 3, 1.5, '#d8c8b8')); sb.position.y = 2.1; shop.add(sb);
  const roofS = new THREE.Mesh(new THREE.BoxGeometry(10, .4, 6), mat('#2a2a30')); roofS.position.y = 4.4; shop.add(roofS);
  const glassS = new THREE.Mesh(new THREE.PlaneGeometry(6, 2.2), new THREE.MeshBasicMaterial({ color: '#ffcf70' })); glassS.position.set(0, 1.6, 2.51); shop.add(glassS);
  for (let i = 0; i < 7; i++) { const st = new THREE.Mesh(new THREE.BoxGeometry(1.4, .1, 1.3), mat(i % 2 ? '#ffb000' : '#f4f0e8')); st.position.set(-4.2 + i * 1.4, 3.3, 3.1); st.rotation.x = .35; shop.add(st); }
  const sign = textPlane(['AMBER SHOP'], 6, { bg: '#1a1208', color: '#ffb000', size: 70, pad: 18, radius: 14, fog: false }); sign.position.set(0, 4.95, 2.6); shop.add(sign);
  WORLD.coll.addBox(0, 2.1, -8, 9, 4.2, 5);
  const npcS = new Avatar({ skin: 1, shirt: 6, pants: 1, hat: 'cap', face: 'grin', hatColor: '#ffb000' }); npcS.setName('Торговец Amber', '#ffb000'); npcS.root.position.set(0, 0, -4.7); npcS.root.rotation.y = 0; g.add(npcS.root); WORLD.coll.addBox(0, .9, -4.7, .7, 1.8, .5);
  const cnt = bx(0, 0, -4.1, 4, 1, .6, mat('#6a4a2a'));
  interactable({ id: 'K_SHOP', mesh: [cnt, npcS.torso.children[0], npcS.head, glassS], pos: new V3(0, 1.3, -4), range: 3.4, label: () => 'Amber-магазин: классы и скины', use: () => UI.openLobbyPanel('shop') });
  WORLD.lamps.push({ pos: new V3(0, 3, -4), on: () => true, color: '#ffcf70', power: 8, range: 10 });
  const rsg = textPlane(['REVIVES', 'возрождения · ящики'], 1.3, { bg: '#1a0a0a', color: '#ff5a5a', size: 46, pad: 12, radius: 10, fog: false }); rsg.position.set(1.35, 1.42, -3.95); rsg.rotation.y = -.2; g.add(rsg); bx(1.35, 1.0, -4.0, .06, .12, .06, mat('#2a2a30'), { coll: false });
  // ---- порталы за магазином ----
  portalGate('P_LEGACY', -4.5, -14.5, 'LEGACY', '#3ad8ff', 'sunny');
  portalGate('P_20', 4.5, -14.5, '2.0', '#ff4ad8', 'rain');
  // ---- лечебница Black Ridge ----
  buildAsylum();
  // ---- кабинки запуска ----
  const boothDefs = [['house1990', 'normal'], ['sunny', 'easy'], ['rain', 'hard'], ['house1990', 'endless']];
  boothDefs.forEach((b, i) => booth(i, 17.5, 9 - i * 5.2, b[0], b[1]));
  const bsign = textPlane(['ВЫБЕРИ КАБИНКУ', 'И ЗАЙДИТЕ ВСЕЙ КОМАНДОЙ'], 6, { bg: '#0d1018', color: '#ffb000', size: 40, pad: 16, radius: 12, fog: false }); bsign.position.set(21.4, 4.4, 1.2); bsign.rotation.y = -PI / 2; g.add(bsign);
  // ---- доска рекордов ----
  const lbC = document.createElement('canvas'); lbC.width = 512; lbC.height = 384; const lbT = new THREE.CanvasTexture(lbC); lbT.colorSpace = THREE.SRGBColorSpace;
  const lb = new THREE.Mesh(new THREE.PlaneGeometry(4.4, 3.3), new THREE.MeshBasicMaterial({ map: lbT, toneMapped: false })); lb.position.set(-19.6, 2.6, 4); lb.rotation.y = PI / 2; g.add(lb); bx(-19.85, 0, 4, .3, 4.6, 4.8, mat('#1a1a20'));
  LOBBY.boards.push({ canvas: lbC, tex: lbT, kind: 'leader' });
  // ---- фонари, деревья, скамейки, забор ----
  for (let i = 0; i < 10; i++) { const a = i / 10 * TAU + .3, r = 22.5; streetLamp(Math.cos(a) * r, Math.sin(a) * r); }
  for (let i = 0; i < 26; i++) { const a = i / 26 * TAU, r = 31 + (i % 3) * 4; if (Math.sin(a) < -.55) continue; pine(Math.cos(a) * r, Math.sin(a) * r + 4); }
  for (const [x, z, ry] of [[-7, 9, PI / 2], [7, 9, -PI / 2], [-14, -4, .8], [14, -4, -.8]]) bench(x, z, ry);
  for (const [x, z, sx, sz] of [[0, -62, 120, 2], [0, 52, 120, 2], [-52, 0, 2, 120], [52, 0, 2, 120]]) WORLD.coll.addBox(x, 2, z, sx, 4, sz);
}
function streetLamp(x, z) { cyl(x, 0, z, .1, 4.4, mat('#222428')); const h = new THREE.Mesh(new THREE.BoxGeometry(.5, .2, .5), new THREE.MeshBasicMaterial({ color: '#ffbf60' })); h.position.set(x, 4.5, z); WORLD.add(h); WORLD.lamps.push({ pos: new V3(x, 4.2, z), on: () => true, color: '#ffae50', power: 9, range: 13 }); }
function pine(x, z) { const s = .8 + ((x * 13 + z * 7) % 5 + 5) % 5 * .12; cyl(x, 0, z, .25 * s, 1.4 * s, mat('#3a2a1e')); for (let k = 0; k < 3; k++) { const c = new THREE.Mesh(new THREE.ConeGeometry((2.2 - k * .55) * s, 2.2 * s, 8), mat('#1e3a26')); c.position.set(x, (1.8 + k * 1.3) * s, z); WORLD.add(c); } }
function bench(x, z, ry) { const gr = new THREE.Group(); gr.position.set(x, 0, z); gr.rotation.y = ry; WORLD.add(gr); const m = mat('#6a4a2a'); for (const [px, py, pz, sx, sy, sz] of [[0, .45, 0, 1.8, .08, .5], [0, .8, -.22, 1.8, .4, .06], [-.8, .22, 0, .08, .45, .45], [.8, .22, 0, .08, .45, .45]]) { const b = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, sz), m); b.position.set(px, py, pz); gr.add(b); } WORLD.coll.addBox(x, .4, z, 1.6, .8, 1.6); }
function kiosk(id, x, z, ry, title, color, npcLook, panel) {
  const gr = new THREE.Group(); gr.position.set(x, 0, z); gr.rotation.y = ry; WORLD.add(gr);
  const base = new THREE.Mesh(new THREE.BoxGeometry(3.2, 1.1, 1.2), mat('#4a3a2e')); base.position.y = .55; gr.add(base);
  const top = new THREE.Mesh(new THREE.BoxGeometry(3.4, .08, 1.4), mat(color)); top.position.y = 1.12; gr.add(top);
  for (const s of [-1, 1]) { const p = new THREE.Mesh(new THREE.BoxGeometry(.12, 2.6, .12), mat('#2a2420')); p.position.set(s * 1.55, 1.3, -.9); gr.add(p); }
  for (let i = 0; i < 6; i++) { const a = new THREE.Mesh(new THREE.BoxGeometry(.58, .08, 1.8), mat(i % 2 ? color : '#f4f0e8')); a.position.set(-1.45 + i * .58, 2.75, -.3); a.rotation.x = .3; gr.add(a); }
  const sg = textPlane([title], 3, { bg: '#11141c', color, size: 60, pad: 14, radius: 10, fog: false }); sg.position.set(0, 3.25, .45); gr.add(sg);
  const npc = new Avatar(npcLook); npc.root.position.set(0, 0, -.95); gr.add(npc.root);
  const lampP = new V3(0, 2.2, .6).applyAxisAngle(new V3(0, 1, 0), ry).add(new V3(x, 0, z));
  WORLD.lamps.push({ pos: lampP, on: () => true, color, power: 5, range: 6 });
  const cs = Math.abs(Math.cos(ry)), sn = Math.abs(Math.sin(ry)); WORLD.coll.addBox(x, .6, z, 3.2 * cs + 1.6 * sn, 1.2, 1.6 * cs + 3.2 * sn);
  interactable({ id, mesh: [base, top, npc.torso.children[0], npc.head], pos: new V3(x, 1.2, z), range: 3.4, label: () => panel, use: () => UI.openLobbyPanel(id) });
}
function portalGate(id, x, z, label, color, map) {
  const gr = new THREE.Group(); gr.position.set(x, 0, z); WORLD.add(gr);
  for (const s of [-1, 1]) { const p = new THREE.Mesh(new THREE.BoxGeometry(.5, 4, .5), mat('#2a2a34')); p.position.set(s * 1.6, 2, 0); gr.add(p); WORLD.coll.addBox(x + s * 1.6, 2, z, .5, 4, .5); }
  const top = new THREE.Mesh(new THREE.BoxGeometry(3.7, .5, .5), mat('#2a2a34')); top.position.y = 4.2; gr.add(top);
  const sw = new THREE.Mesh(new THREE.PlaneGeometry(2.7, 3.9), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: .55, side: THREE.DoubleSide })); sw.position.y = 2; gr.add(sw);
  const sg = textPlane([label], 2.4, { bg: '#0a0a10', color, size: 64, pad: 12, radius: 10, fog: false }); sg.position.set(0, 4.9, .3); gr.add(sg);
  WORLD.ticks.push(() => { sw.material.opacity = .45 + Math.sin(now() * 3 + x) * .15; sw.rotation.y = Math.sin(now() * .7) * .05; });
  WORLD.lamps.push({ pos: new V3(x, 2, z + 1), on: () => true, color, power: 7, range: 8 });
  interactable({ id, mesh: sw, pos: new V3(x, 2, z), range: 3, label: () => 'Портал «' + label + '»: ' + MAPS[map].name + ' (' + DIFFS[MAPS[map].diff].name + ')', use: () => UI.toast('Карта «' + MAPS[map].name + '» — заходите в кабинку справа на площади!') });
}
function booth(i, x, z, map, diff) {
  const gr = new THREE.Group(); gr.position.set(x, 0, z); WORLD.add(gr);
  const W = 3.6, D = 3.8, glassM = new THREE.MeshLambertMaterial({ color: '#9ad0ff', transparent: true, opacity: .18, side: THREE.DoubleSide });
  const fl = new THREE.Mesh(new THREE.BoxGeometry(W, .12, D), mat('#22262e')); fl.position.y = .06; gr.add(fl);
  const back = new THREE.Mesh(new THREE.BoxGeometry(.15, 3, D), mat('#2e3440')); back.position.set(W / 2, 1.5, 0); gr.add(back); WORLD.coll.addBox(x + W / 2, 1.5, z, .15, 3, D);
  for (const s of [-1, 1]) { const sd = new THREE.Mesh(new THREE.BoxGeometry(W, 3, .1), glassM); sd.position.set(0, 1.5, s * D / 2); gr.add(sd); WORLD.coll.addBox(x, 1.5, z + s * D / 2, W, 3, .1); }
  const roof = new THREE.Mesh(new THREE.BoxGeometry(W + .3, .25, D + .3), mat('#2e3440')); roof.position.y = 3.1; gr.add(roof);
  const light = new THREE.Mesh(new THREE.BoxGeometry(W - .4, .06, .4), new THREE.MeshBasicMaterial({ color: '#ffb000' })); light.position.set(0, 3, 0); gr.add(light);
  const c = document.createElement('canvas'); c.width = 512; c.height = 320; const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  const panel = new THREE.Mesh(new THREE.PlaneGeometry(2.6, 1.62), new THREE.MeshBasicMaterial({ map: t, toneMapped: false })); panel.position.set(W / 2 - .09, 1.9, 0); panel.rotation.y = -PI / 2; gr.add(panel);
  const b = { i, x, z, w: W - .3, d: D - .3, map, diff, canvas: c, tex: t, light, last: '' };
  LOBBY.booths.push(b);
}
function drawBoothPanels() {
  const st = GAME.st, bs = st.booth || {};
  for (const b of LOBBY.booths) {
    const here = bs.idx === b.i ? bs.inside || 0 : (bs.counts && bs.counts[b.i]) || 0, total = bs.total || 1, cd = bs.idx === b.i && bs.cd > 0 ? Math.ceil(bs.cd) : 0;
    const key = here + '|' + total + '|' + cd; if (key === b.last) continue; b.last = key;
    const g = b.canvas.getContext('2d'); g.fillStyle = '#0b0e15'; g.fillRect(0, 0, 512, 320);
    g.fillStyle = MAPS[b.map].tag === 'LEGACY' ? '#3ad8ff' : MAPS[b.map].tag === '2.0' ? '#ff4ad8' : '#ffb000'; g.fillRect(0, 0, 512, 54);
    g.fillStyle = '#0b0e15'; g.font = '900 34px Arial Black, Arial'; g.textAlign = 'center'; g.fillText(MAPS[b.map].name.toUpperCase(), 256, 40);
    g.fillStyle = '#fff'; g.font = '800 30px Arial'; g.fillText('Сложность: ' + DIFFS[b.diff].name, 256, 104);
    g.fillStyle = '#9aa3b2'; g.font = '700 24px Arial'; g.fillText(DIFFS[b.diff].endless ? 'Ночи без конца' : 'Ночей: ' + DIFFS[b.diff].nights, 256, 142);
    g.fillStyle = here ? '#36d16b' : '#fff'; g.font = '900 52px Arial Black, Arial'; g.fillText('ИГРОКИ ' + here + '/' + total, 256, 214);
    g.fillStyle = cd ? '#ffb000' : '#666'; g.font = '800 32px Arial'; g.fillText(cd ? 'СТАРТ ЧЕРЕЗ ' + cd : 'Все внутрь — старт через 10 с', 256, 280);
    b.tex.needsUpdate = true; b.light.material.color.set(here ? '#36d16b' : '#ffb000');
  }
}
/* ---- лечебница с камерами заключённых ---- */
function buildAsylum() {
  const types = INMATES.list.filter(t => !t.lobbyOnly && !t.companion), n = Math.min(18, types.length), cw = 3.4;
  const HW = Math.max(24, Math.ceil(n * cw / 2) + 1);
  const g = WORLD.group, Z0 = -22, Z1 = -40, X0 = -HW, X1 = HW, mA = texMat(TX.asylum(), 8, 2), mIn = texMat(TX.asylum(), 4, 1, '#b8bcb0');
  // фасад с 4 входами, 2 этажа
  const ents = [-15, -5, 5, 15];
  wall(X0, Z0, X1, Z0, 0, 8.5, mIn, [...ents.map(c => ({ c, w: 2.2, y0: 0, y1: 2.8 })), ...[-19, -10, 0, 10, 19].map(c => ({ c, w: 1.6, y0: 4.6, y1: 6.4 }))], .4, mA);
  wall(X0, Z1, X1, Z1, 0, 8.5, mIn, [], .4, mA); wall(X0, Z1, X0, Z0, 0, 8.5, mIn, [], .4, mA); wall(X1, Z1, X1, Z0, 0, 8.5, mIn, [], .4, mA);
  slab(X0, Z1, X1, Z0, 4.2, .3, mat('#5a5e58')); slab(X0 - .5, Z1 - .5, X1 + .5, Z0 + .5, 8.8, .4, mat('#2a2a2e'), false);
  const fl = new THREE.Mesh(new THREE.PlaneGeometry(X1 - X0, Z0 - Z1), texMat(TX.lino(), 12, 5, '#9a9a90')); fl.rotation.x = -PI / 2; fl.position.set(0, .02, (Z0 + Z1) / 2); g.add(fl);
  const sign = textPlane(['BLACK RIDGE ASYLUM'], 16, { bg: '#0a0c0a', color: '#c8d0c0', size: 80, pad: 20, fog: false }); sign.position.set(0, 7.6, Z0 + .25); g.add(sign);
  for (const c of ents) { const lt = new THREE.Mesh(new THREE.BoxGeometry(.6, .2, .3), new THREE.MeshBasicMaterial({ color: '#ff3a3a' })); lt.position.set(c, 3.1, Z0 + .3); g.add(lt); }
  for (let i = -4; i <= 4; i++) { const w = new THREE.Mesh(new THREE.PlaneGeometry(1.5, 1.7), new THREE.MeshBasicMaterial({ color: i % 3 ? '#1a221a' : '#8aa070' })); w.position.set(i * 5, 5.5, Z0 + .22); g.add(w); }
  // коридор и камеры вдоль задней стены
  const startX = -(n * cw) / 2;
  wall(X0, -29, startX, -29, 0, 4.2, mIn, [], .25); wall(startX + n * cw, -29, X1, -29, 0, 4.2, mIn, [], .25);
  wall(startX, -29, startX + n * cw, -29, 0, 4.2, mIn, types.slice(0, n).map((t, i) => ({ c: startX + cw * (i + .5), w: 2.4, y0: 0, y1: 2.9 })), .25);
  for (let i = 0; i <= n; i++) { const x = startX + i * cw; wall(x, Z1, x, -29, 0, 4.2, mIn, [], .25); }
  for (let i = 0; i < n; i++) {
    const T = types[i], cx = startX + cw * (i + .5);
    // решётка
    for (let k = -5; k <= 5; k++) { const bar = new THREE.Mesh(new THREE.CylinderGeometry(.03, .03, 2.9, 6), mat('#3a3e44')); bar.position.set(cx + k * .22, 1.45, -29); g.add(bar); }
    WORLD.coll.addBox(cx, 1.45, -29, 2.4, 2.9, .1);
    // кровать справа, стальная дверь сзади, номер над дверью
    bx(cx + 1.05, 0, -37.5, .9, .5, 2, mat('#6a6e70')); bx(cx + 1.05, .5, -36.9, .7, .12, .5, mat('#e8e8e0'), { coll: false });
    bx(cx, 0, -39.7, 1.4, 2.4, .2, texMat(TX.metal(), 1, 1)); const num = textPlane([T.num], 1.1, { bg: '#111', color: '#ffb000', size: 64, pad: 10, fog: false }); num.position.set(cx, 2.85, -39.55); g.add(num);
    // модель заключённого в камере
    const m = T.model(); m.position.set(cx - .2, 0, -33); m.rotation.y = 0; g.add(m); m.userData.T = T;
    { const bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new V3()); let k = T.key === 'doll' ? 1.4 : 1; if (sz.x * k > 2.6) k = 2.6 / sz.x; if (sz.z * k > 7) k = 7 / sz.z; if (sz.y * k > 3.9) k = 3.9 / sz.y; m.scale.setScalar(k); }
    // планшет с лампочкой
    const tx = cx - cw / 2, tab = bx(tx, 1.1, -28.8, .44, .62, .08, mat('#22262e'), { coll: false }); const scr = new THREE.Mesh(new THREE.PlaneGeometry(.36, .48), new THREE.MeshBasicMaterial({ color: '#0a1a22' })); scr.position.set(tx, 1.43, -28.75); g.add(scr);
    const led = new THREE.Mesh(new THREE.SphereGeometry(.05, 8, 6), new THREE.MeshBasicMaterial({ color: '#f33' })); led.position.set(tx, 1.8, -28.74); g.add(led);
    const cell = { T, led, model: m }; LOBBY.cells.push(cell);
    interactable({ id: 'CELL_' + T.key, mesh: [tab, scr], pos: new V3(tx, 1.4, -28.8), range: 2.6, label: () => 'Досье: заключённый ' + T.num + ' — ' + T.name, use: () => UI.dossier(T) });
    if (i % 2 === 0) WORLD.lamps.push({ pos: new V3(cx + cw / 2, 3.6, -32), on: () => true, color: '#c8ffd0', power: 4, range: 7, flicker: i % 4 === 2 });
  }
  for (const x of [-16, -6, 4, 14]) WORLD.lamps.push({ pos: new V3(x, 3.6, -25.5), on: () => true, color: '#d8ffe0', power: 4, range: 9, flicker: x === -6 });
}
function lobbyFrame(dt) {
  if (WORLD.level !== 'lobby') return;
  drawBoothPanels();
  // экран площади: циклический слайд оповещения
  const tv = LOBBY.tv; if (tv && (tv.t = (tv.t || 0) + dt) > .12) { tv.t = 0; drawEAS(tv.canvas, ['ЭКСТРЕННОЕ ОПОВЕЩЕНИЕ', 'ЛЕЧЕБНИЦА BLACK RIDGE СООБЩАЕТ О ПОБЕГЕ ЗАКЛЮЧЁННЫХ.', 'ОСТАВАЙТЕСЬ ДОМА. СЛЕДУЙТЕ УКАЗАНИЯМ ТЕЛЕВИЗОРА.', 'ВЫБЕРИТЕ КАБИНКУ СПРАВА, ЧТОБЫ НАЧАТЬ.'], now()); tv.tex.needsUpdate = true; }
  for (const c of LOBBY.cells) { const seen = LOCALS.some(l => l.prof && l.prof.seen.includes(c.T.key)); c.led.material.color.set(seen ? '#3f3' : '#f33'); if (c.T.anim) { } }
  for (const b of LOBBY.boards) if (b.kind === 'leader' && !b.drawn) { b.drawn = 1; const g = b.canvas.getContext('2d'); g.fillStyle = '#05070a'; g.fillRect(0, 0, 512, 384); g.fillStyle = '#ffb000'; g.font = '900 34px Arial Black, Arial'; g.textAlign = 'center'; g.fillText('ЛУЧШИЕ ВЫЖИВШИЕ', 256, 46); g.font = '700 26px Consolas, monospace'; g.textAlign = 'left'; const rows = [...LOCALS.map(l => [l.prof.name || l.name, l.prof.best, l.prof.wins])]; rows.push(['TEZ_Fan', 12, 3], ['Survivor_99', 9, 1], ['noob1990', 4, 0]); rows.sort((a, b) => b[1] - a[1]); rows.slice(0, 8).forEach((r, i) => { g.fillStyle = i === 0 ? '#ffd860' : '#e8e8e8'; g.fillText((i + 1) + '. ' + String(r[0]).slice(0, 14), 24, 100 + i * 36); g.textAlign = 'right'; g.fillText(r[1] + ' ночей', 488, 100 + i * 36); g.textAlign = 'left'; }); b.tex.needsUpdate = true; }
}
// слайд экстренного оповещения (общий для лобби и ТВ в доме)
function drawEAS(c, lines, t, o = {}) {
  const g = c.getContext('2d'), W = c.width, H = c.height;
  g.fillStyle = o.bg || '#06070c'; g.fillRect(0, 0, W, H);
  g.fillStyle = '#c4121a'; g.fillRect(0, 0, W, H * .2); g.fillStyle = '#fff'; g.font = `900 ${H * .1 | 0}px Arial Black, Arial`; g.textAlign = 'center'; g.fillText(lines[0], W / 2, H * .14);
  g.font = `700 ${H * .062 | 0}px Consolas, monospace`; g.textAlign = 'left';
  const body = lines.slice(1).join('  ★  '), maxW = W - 30, rows = []; let cur = '';
  for (const w of body.split(' ')) { const nx = cur ? cur + ' ' + w : w; if (g.measureText(nx).width > maxW && cur) { rows.push(cur); cur = w; } else cur = nx; }
  if (cur) rows.push(cur);
  const off = Math.floor(t * 1.2) % Math.max(1, rows.length);
  for (let i = 0; i < Math.min(5, rows.length); i++) { const r = rows[(rows.length > 5 ? off + i : i) % rows.length]; if (r) { g.fillStyle = '#f2f2f2'; g.fillText(r, 15, H * .32 + i * H * .1); } }
  g.fillStyle = '#ffb000'; g.fillRect(0, H * .86, W, H * .14); g.fillStyle = '#000'; g.font = `900 ${H * .07 | 0}px Arial`; g.textAlign = 'center'; g.fillText(o.foot || 'AMBER ALERT  •  BLACK RIDGE ASYLUM', W / 2, H * .955);
  for (let i = 0; i < 40; i++) { g.fillStyle = `rgba(255,255,255,${Math.random() * .08})`; g.fillRect(0, Math.random() * H, W, 1 + Math.random() * 2); }
}
