/* ================= КОНСТРУКТОР МИРА: стены, проёмы, двери, окна, свет, мебель, интерактивы ================= */
// Мир состоит из «уровня» (лобби или дом). Всё интерактивное имеет id и состояние,
// которое хост меняет и рассылает (WS = world state).
const WORLD = {
  group: null, coll: new CollisionWorld(), inter: new Map(), lamps: [], hides: [], windows: [], doors: [], rooms: [], ticks: [], nav: null, spawn: [], level: '',
  reset() {
    if (this.group) R.scene.remove(this.group);
    this.group = new THREE.Group(); R.scene.add(this.group);
    this.coll.clear(); this.inter.clear(); for (const k in PLACED) delete PLACED[k]; this.lamps = []; this.hides = []; this.windows = []; this.doors = []; this.rooms = []; this.ticks = []; this.nav = null; this.spawn = [];
    R.pool.setLamps([]);
  },
  add(o) { this.group.add(o); return o; },
};
const WS = {};                          // состояние интерактивов: id -> объект
function wsSet(id, patch, silent) {     // только хост
  WS[id] = Object.assign(WS[id] || {}, patch); const it = WORLD.inter.get(id); if (it && it.apply) it.apply(WS[id]);
  if (!silent && NET.role === 'host') GAME.queueWS(id);
}
function wsApply(id, st) { WS[id] = st; const it = WORLD.inter.get(id); if (it && it.apply) it.apply(st); else if (/^(TRAP|ML)_/.test(id)) placedVisual(id, st); }
// поставленные предметы: капкан и лампа с датчиком
const PLACED = {};
function placedVisual(id, st) {
  let v = PLACED[id];
  if (!v) {
    const g = new THREE.Group(); g.position.set(st.p[0], st.p[1], st.p[2]); WORLD.add(g); v = PLACED[id] = { g };
    if (st.k === 'beartrap') { const ring = new THREE.Mesh(new THREE.TorusGeometry(.3, .04, 6, 16), mat('#6a6a70')); ring.rotation.x = PI / 2; ring.position.y = .05; g.add(ring); for (let i = 0; i < 10; i++) { const t = new THREE.Mesh(new THREE.ConeGeometry(.04, .14, 4), mat('#9a9aa0')); const a = i / 10 * TAU; t.position.set(Math.cos(a) * .27, .12, Math.sin(a) * .27); g.add(t); } v.ring = ring; }
    else { const base = new THREE.Mesh(new THREE.CylinderGeometry(.12, .15, .5, 8), mat('#2a2a30')); base.position.y = .25; g.add(base); const bulb = new THREE.Mesh(new THREE.SphereGeometry(.14, 8, 6), new THREE.MeshBasicMaterial({ color: '#555' })); bulb.position.y = .6; g.add(bulb); v.bulb = bulb;
      v.lamp = { pos: new V3(st.p[0], st.p[1] + 1.2, st.p[2]), on: () => WS[id] && WS[id].lit, color: '#fff8e0', power: 9, range: 7, room: 'ml' }; WORLD.lamps.push(v.lamp); R.pool.setLamps(WORLD.lamps); }
  }
  if (v.ring) v.g.scale.y = st.on ? 1 : .4;
  if (v.bulb) v.bulb.material.color.set(st.lit ? '#fffbe0' : '#555');
}

/* ---- текстуры 90-х ---- */
const TX = {
  wallpaper: (c1, c2, key) => canvasTex('wp' + key, 128, 128, g => { g.fillStyle = c1; g.fillRect(0, 0, 128, 128); g.fillStyle = c2; for (let x = 0; x < 128; x += 32) g.fillRect(x, 0, 10, 128); g.globalAlpha = .5; for (let y = 16; y < 128; y += 32) for (let x = 21; x < 128; x += 32) { g.beginPath(); g.arc(x, y, 4, 0, TAU); g.fill(); } g.globalAlpha = 1; noiseFill(g, 0, 0, 'rgba(0,0,0,0)', .06, 300); }, [1, 1]),
  floral: (c1, c2, key) => canvasTex('fl' + key, 128, 128, g => { g.fillStyle = c1; g.fillRect(0, 0, 128, 128); g.fillStyle = c2; for (let i = 0; i < 6; i++) { const x = (i * 47) % 128, y = (i * 71) % 128; for (let k = 0; k < 5; k++) { g.beginPath(); g.ellipse(x + Math.cos(k * 1.256) * 6, y + Math.sin(k * 1.256) * 6, 4, 2.5, k * 1.256, 0, TAU); g.fill(); } } }, [1, 1]),
  panel: () => canvasTex('panel', 128, 128, g => { g.fillStyle = '#6b4a2e'; g.fillRect(0, 0, 128, 128); for (let x = 0; x < 128; x += 16) { g.fillStyle = x % 32 ? '#5e3f26' : '#74512f'; g.fillRect(x, 0, 15, 128); g.fillStyle = 'rgba(0,0,0,.35)'; g.fillRect(x + 15, 0, 1, 128); } for (let i = 0; i < 60; i++) { g.fillStyle = 'rgba(30,15,5,.25)'; g.fillRect(Math.random() * 128, Math.random() * 128, 1, 6 + Math.random() * 14); } }),
  carpet: (c, key) => canvasTex('cp' + key, 128, 128, g => noiseFill(g, 128, 128, c, .18, 4000)),
  wood: () => canvasTex('wood', 128, 128, g => { g.fillStyle = '#8a5e3a'; g.fillRect(0, 0, 128, 128); for (let y = 0; y < 128; y += 16) { g.fillStyle = (y / 16) % 2 ? '#7d5434' : '#93663f'; g.fillRect(0, y, 128, 15); g.fillStyle = 'rgba(0,0,0,.4)'; g.fillRect(0, y + 15, 128, 1); g.fillRect(((y * 37) % 100) + 10, y, 1, 15); } }),
  lino: () => canvasTex('lino', 128, 128, g => { for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) { g.fillStyle = (x + y) % 2 ? '#d8d0b8' : '#7a8a6a'; g.fillRect(x * 32, y * 32, 32, 32); } noiseFill(g, 0, 0, 'rgba(0,0,0,0)', .1, 600); }),
  tile: () => canvasTex('tile', 128, 128, g => { g.fillStyle = '#cfe0e0'; g.fillRect(0, 0, 128, 128); g.strokeStyle = '#8aa'; g.lineWidth = 2; for (let i = 0; i <= 128; i += 21.3) { g.beginPath(); g.moveTo(i, 0); g.lineTo(i, 128); g.moveTo(0, i); g.lineTo(128, i); g.stroke(); } }),
  siding: () => canvasTex('siding', 128, 128, g => { for (let y = 0; y < 128; y += 16) { g.fillStyle = '#d9d3c0'; g.fillRect(0, y, 128, 16); g.fillStyle = 'rgba(0,0,0,.25)'; g.fillRect(0, y + 14, 128, 2); } }),
  shingle: () => canvasTex('shingle', 128, 128, g => { g.fillStyle = '#3a3330'; g.fillRect(0, 0, 128, 128); for (let y = 0; y < 128; y += 16) for (let x = (y / 16) % 2 ? 0 : 12; x < 128; x += 24) { g.fillStyle = `rgb(${50 + Math.random() * 20},${44 + Math.random() * 15},${40 + Math.random() * 12})`; g.fillRect(x, y, 22, 14); } }),
  grass: () => canvasTex('grass', 128, 128, g => noiseFill(g, 128, 128, '#2f4a24', .25, 5000)),
  concrete: () => canvasTex('concrete', 128, 128, g => noiseFill(g, 128, 128, '#6e6e6a', .14, 3500)),
  brick: () => canvasTex('brick', 128, 128, g => { g.fillStyle = '#5a5550'; g.fillRect(0, 0, 128, 128); for (let y = 0; y < 128; y += 16) for (let x = (y / 16) % 2 ? -16 : 0; x < 128; x += 32) { g.fillStyle = `rgb(${105 + Math.random() * 25},${50 + Math.random() * 15},${40 + Math.random() * 10})`; g.fillRect(x + 1, y + 1, 30, 14); } }),
  asylum: () => canvasTex('asylum', 128, 128, g => { noiseFill(g, 128, 128, '#8c8f86', .2, 3000); g.fillStyle = 'rgba(40,50,40,.35)'; for (let i = 0; i < 6; i++) g.fillRect(Math.random() * 128, 0, 3 + Math.random() * 6, 40 + Math.random() * 80); }),
  metal: () => canvasTex('metal', 128, 128, g => { noiseFill(g, 128, 128, '#4a4f55', .15, 2000); g.fillStyle = 'rgba(0,0,0,.4)'; for (const p of [[8, 8], [120, 8], [8, 120], [120, 120], [64, 8], [64, 120]]) { g.beginPath(); g.arc(p[0], p[1], 3, 0, TAU); g.fill(); } }),
};
function texMat(t, rx, ry, color = '#ffffff') { const tt = t.clone(); tt.needsUpdate = true; tt.wrapS = tt.wrapT = THREE.RepeatWrapping; tt.repeat.set(rx, ry); return new THREE.MeshLambertMaterial({ color, map: tt }); }

/* ---- примитивы с коллизией ---- */
function bx(x, y, z, sx, sy, sz, m, o = {}) { // центр по x,z; y — НИЗ коробки
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, sz), m); mesh.position.set(x, y + sy / 2, z); if (o.ry) mesh.rotation.y = o.ry;
  (o.parent || WORLD.group).add(mesh);
  if (o.coll !== false) { const c = WORLD.coll.addBox(x, y + sy / 2, z, o.ry && Math.abs(Math.sin(o.ry)) > .7 ? sz : sx, sy, o.ry && Math.abs(Math.sin(o.ry)) > .7 ? sx : sz, o.tag); mesh.userData.coll = c; }
  return mesh;
}
function cyl(x, y, z, r, h, m, o = {}) { const mesh = new THREE.Mesh(new THREE.CylinderGeometry(o.r2 ?? r, r, h, o.seg || 10), m); mesh.position.set(x, y + h / 2, z); (o.parent || WORLD.group).add(mesh); if (o.coll !== false) WORLD.coll.addBox(x, y + h / 2, z, r * 1.6, h, r * 1.6); return mesh; }
// стена вдоль X или Z с проёмами: holes [{c:центр вдоль стены, w, y0, y1}]
function wall(x0, z0, x1, z1, y, h, m, holes = [], th = .16, mOut) {
  const alongX = Math.abs(z1 - z0) < 1e-6, L = alongX ? x1 - x0 : z1 - z0, s0 = alongX ? x0 : z0;
  const pieces = []; let cur = 0; const hs = holes.map(o => ({ a: o.c - o.w / 2 - s0, b: o.c + o.w / 2 - s0, y0: o.y0 ?? 0, y1: o.y1 ?? 2.1 })).sort((a, b) => a.a - b.a);
  for (const o of hs) { if (o.a > cur) pieces.push([cur, o.a, 0, h]); if (o.y0 > 0) pieces.push([o.a, o.b, 0, o.y0]); if (o.y1 < h) pieces.push([o.a, o.b, o.y1, h]); cur = o.b; }
  if (cur < L) pieces.push([cur, L, 0, h]);
  for (const [a, b, ya, yb] of pieces) {
    const len = b - a; if (len < .01 || yb - ya < .01) continue; const c = s0 + (a + b) / 2;
    const mats = mOut ? (alongX ? [m, m, m, m, m, mOut] : [m, mOut, m, m, m, m]) : m;
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(alongX ? len : th, yb - ya, alongX ? th : len), mats);
    // повтор текстуры по длине
    mesh.position.set(alongX ? c : x0, y + (ya + yb) / 2, alongX ? z0 : c); WORLD.group.add(mesh);
    WORLD.coll.addBox(mesh.position.x, mesh.position.y, mesh.position.z, alongX ? len : th, yb - ya, alongX ? th : len);
  }
}
function slab(x0, z0, x1, z1, y, th, m, coll = true) { const mesh = new THREE.Mesh(new THREE.BoxGeometry(x1 - x0, th, z1 - z0), m); mesh.position.set((x0 + x1) / 2, y - th / 2, (z0 + z1) / 2); WORLD.group.add(mesh); if (coll) WORLD.coll.addBox(mesh.position.x, mesh.position.y, mesh.position.z, x1 - x0, th, z1 - z0); return mesh; }
// лестница: от (x,z) вдоль dir ('+x','-x','+z','-z'), ширина w, подъём H, ступеней n
function stairs(x, z, dir, w, y0, H, n, m) {
  const run = .3, rise = H / n;
  for (let i = 0; i < n; i++) {
    const d = run * (i + .5), top = y0 + rise * (i + 1);
    const px = dir === '+x' ? x + d : dir === '-x' ? x - d : x, pz = dir === '+z' ? z + d : dir === '-z' ? z - d : z;
    const sx = dir.endsWith('x') ? run : w, sz = dir.endsWith('x') ? w : run;
    bx(px, y0, pz, sx, top - y0, sz, m);
  }
  return run * n;
}

/* ---- интерактивы ---- */
// def: {id, mesh(es), pos, label:()=>str, use:(pid)=>void (на хосте), apply:(st)=>void (у всех), hold:сек, cond:(pid)=>bool, range}
function interactable(def) { def.meshes = [].concat(def.mesh || []); def.meshes.forEach(m => m.traverse(o => { o.userData.inter = def.id; })); WORLD.inter.set(def.id, def); if (def.init) wsSet(def.id, def.init, true); return def; }
const _ray = new THREE.Raycaster();
function aimInteract(cam, range = 2.6) {
  _ray.setFromCamera(new THREE.Vector2(0, 0), cam); _ray.far = range + 1;
  const list = []; for (const it of WORLD.inter.values()) if (!it.hidden) for (const m of it.meshes) list.push(m);
  const hits = _ray.intersectObjects(list, true);
  for (const h of hits) { const id = h.object.userData.inter; const it = WORLD.inter.get(id); if (!it) continue; if (h.distance > (it.range || range)) break;
    // не сквозь стены
    const o = cam.position, d = _ray.ray.direction; if (WORLD.coll.ray(o.x, o.y, o.z, d.x, d.y, d.z, h.distance, b => !b.door) < h.distance - .15) break;
    return it; }
  return null;
}

/* ---- двери ---- */
// дверь в проёме стены. axis: 'x' — полотно вдоль X; hinge — смещение петель (-1/1); opensTo — ±1
function door(id, x, z, axis, y, o = {}) {
  const w = o.w || 1, h = o.h || 2.1, th = .06, col = o.color || '#c9b38a';
  const pivot = new THREE.Group(), hs = o.hinge || -1; pivot.position.set(axis === 'x' ? x + hs * w / 2 : x, y, axis === 'x' ? z : z + hs * w / 2); WORLD.add(pivot);
  const leaf = new THREE.Mesh(new THREE.BoxGeometry(axis === 'x' ? w - .04 : th, h - .02, axis === 'x' ? th : w - .04), mat(col)); leaf.position.set(axis === 'x' ? -hs * (w / 2) : 0, h / 2, axis === 'x' ? 0 : -hs * (w / 2)); pivot.add(leaf);
  const knob = new THREE.Mesh(new THREE.SphereGeometry(.045, 8, 6), mat('#d4b04a')); knob.position.set(axis === 'x' ? -hs * (w - .15) : (o.out || 1) * .06, 1, axis === 'x' ? (o.out || 1) * .06 : -hs * (w - .15)); pivot.add(knob);
  const k2 = knob.clone(); k2.position.multiply(new V3(axis === 'x' ? 1 : -1, 1, axis === 'x' ? -1 : 1)); pivot.add(k2);
  if (o.panels) for (const py of [.55, 1.45]) { const p = new THREE.Mesh(new THREE.BoxGeometry(axis === 'x' ? w * .6 : th + .02, .6, axis === 'x' ? th + .02 : w * .6), mat(shadeHex(col, -.12))); p.position.set(leaf.position.x, py, leaf.position.z); pivot.add(p); }
  const c = WORLD.coll.addBox(x, y + h / 2, z, axis === 'x' ? w : .14, h, axis === 'x' ? .14 : w); c.door = id;
  const d = { id, x, z, y, axis, w, pivot, coll: c, front: !!o.front, lockable: o.lockable !== false, open: 0, target: 0, sign: o.opensTo || 1, hs };
  WORLD.doors.push(d);
  WORLD.ticks.push(dt => { d.open = damp(d.open, d.target, 9, dt); pivot.rotation.y = d.open * d.sign * hs * 1.6; });
  interactable({ id, mesh: leaf, pos: new V3(x, y + 1, z), init: { o: 0, l: 0, b: 0 },
    label: () => { const s = WS[id]; if (s.b) return 'Дверь выбита'; return s.o ? 'Закрыть дверь' : s.l ? 'Дверь заперта — открыть замок' : 'Открыть дверь'; },
    alt: () => { const s = WS[id]; return d.lockable && !s.o && !s.b ? (s.l ? '' : 'Запереть (держи)') : ''; },
    use: (pid, hold) => { const s = WS[id]; if (s.b) return; if (hold && d.lockable && !s.o) { wsSet(id, { l: s.l ? 0 : 1 }); GAME.sfxAt('lock', d); return; } if (s.l) { wsSet(id, { l: 0 }); GAME.sfxAt('lock', d); return; } wsSet(id, { o: s.o ? 0 : 1 }); GAME.sfxAt(s.o ? 'doorClose' : 'doorOpen', d); },
    apply: s => { d.target = s.o || s.b ? 1 : 0; c.on = !(s.o || s.b); if (s.b) leaf.material = mat('#5a4030'); } });
  return d;
}
function shadeHex(hex, k) { const c = new THREE.Color(hex); if (k < 0) c.multiplyScalar(1 + k); else c.lerp(new THREE.Color('#fff'), k); return '#' + c.getHexString(); }

/* ---- окна со шторами ---- */
function windowW(id, x, z, axis, y, o = {}) {
  const w = o.w || 1.2, h = o.h || 1.1, y0 = y + (o.sill ?? .95), frame = mat('#e8e2d0');
  const g = new THREE.Group(); g.position.set(x, y0, z); if (axis === 'z') g.rotation.y = PI / 2; WORLD.add(g);
  const glass = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshLambertMaterial({ color: '#7a92b8', transparent: true, opacity: .28, side: THREE.DoubleSide, emissive: '#0a1428' })); glass.position.y = h / 2; g.add(glass);
  for (const [px, py, sx, sy] of [[0, 0, w + .1, .08], [0, h, w + .1, .08], [-w / 2, h / 2, .08, h], [w / 2, h / 2, .08, h], [0, h / 2, .05, h]]) { const f = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, .1), frame); f.position.set(px, py, 0); g.add(f); }
  const side = o.inside || 1; // где комната
  const cur = []; for (const s of [-1, 1]) { const c = new THREE.Mesh(new THREE.BoxGeometry(w / 2 + .1, h + .4, .04), mat(o.curtain || '#7a2f2f')); c.position.set(s * w / 4, h / 2 + .1, side * .12); g.add(c); cur.push(c); }
  const rod = new THREE.Mesh(new THREE.CylinderGeometry(.02, .02, w + .5, 6), mat('#8a7a5a')); rod.rotation.z = PI / 2; rod.position.set(0, h + .32, side * .12); g.add(rod);
  const shards = new THREE.Group(); shards.visible = false; g.add(shards); for (let i = 0; i < 6; i++) { const s = new THREE.Mesh(new THREE.PlaneGeometry(.2 + Math.random() * .2, .2 + Math.random() * .3), glass.material); s.position.set((Math.random() - .5) * w, Math.random() * .3, (Math.random() - .5) * .1); s.rotation.z = Math.random() * 3; shards.add(s); }
  const inPt = new V3(axis === 'x' ? x : x + side * .9, y, axis === 'x' ? z + side * .9 : z), outPt = new V3(axis === 'x' ? x : x - side * 1.4, y, axis === 'x' ? z - side * 1.4 : z);
  if (axis === 'z') { inPt.set(x + side * .9, y, z); outPt.set(x - side * 1.4, y, z); }
  const win = { id, x, z, y, pos: new V3(x, y0 + h / 2, z), inPt, outPt, axis, glass, room: o.room };
  WORLD.windows.push(win);
  interactable({ id, mesh: [cur[0], cur[1], glass], pos: win.pos, init: { c: 0, b: 0 },
    label: () => WS[id].b ? 'Окно разбито' : WS[id].c ? 'Открыть шторы' : 'Задёрнуть шторы',
    use: () => { if (WS[id].b) return; wsSet(id, { c: WS[id].c ? 0 : 1 }); GAME.sfxAt('curtain', win.pos); },
    apply: s => { cur.forEach((c, i) => { c.scale.x = s.c ? 1 : .32; c.position.x = (i ? 1 : -1) * (s.c ? w / 4 : w / 2 - .02); }); glass.visible = !s.b; shards.visible = !!s.b; } });
  return win;
}

/* ---- свет: комнатная лампа + выключатель ---- */
function roomLight(room, pos, o = {}) {
  const bulb = new THREE.Mesh(new THREE.SphereGeometry(.12, 10, 8), new THREE.MeshBasicMaterial({ color: '#fff2c8' })); bulb.position.copy(pos); WORLD.add(bulb);
  const shade = new THREE.Mesh(new THREE.CylinderGeometry(.18, .32, .22, 12, 1, true), mat(o.shade || '#d8c49a', { side: THREE.DoubleSide })); shade.position.copy(pos).add(new V3(0, .08, 0)); WORLD.add(shade);
  const L = { pos: pos.clone().add(new V3(0, -.15, 0)), room, color: o.color || '#ffd9a0', power: o.power || 7, range: o.range || 9, on: () => WS['L_' + room] && WS['L_' + room].on && GAME.power(), bulb, flicker: false };
  WORLD.lamps.push(L); R.pool.setLamps(WORLD.lamps);
  WORLD.ticks.push(() => { const on = L.on(); bulb.material.color.set(on ? (L.flicker && Math.random() < .3 ? '#554' : '#fff2c8') : '#333'); });
  return L;
}
function lightSwitch(room, x, y, z, ry, roomName) {
  const id = 'L_' + room, plate = new THREE.Mesh(new THREE.BoxGeometry(.12, .18, .03), mat('#efe8d4')); plate.position.set(x, y + 1.25, z); plate.rotation.y = ry; WORLD.add(plate);
  const tog = new THREE.Mesh(new THREE.BoxGeometry(.03, .06, .03), mat('#fff')); tog.position.set(0, 0, .025); plate.add(tog);
  return interactable({ id, mesh: plate, pos: plate.position.clone(), init: { on: 1 }, range: 2.2,
    label: () => (WS[id].on ? 'Выключить свет' : 'Включить свет') + (roomName ? ' (' + roomName + ')' : ''),
    use: () => { wsSet(id, { on: WS[id].on ? 0 : 1 }); GAME.sfxAt('switch', plate.position); },
    apply: s => { tog.position.y = s.on ? .02 : -.02; } });
}
/* ---- укрытия (шкафы) ---- */
function hideSpot(id, pos, yaw, mesh, label = 'Спрятаться в шкаф') {
  const h = { id, pos: pos.clone(), eye: pos.clone().add(new V3(0, 1.45, 0)), yaw, out: pos.clone().add(new V3(Math.sin(yaw) * -.9, 0, Math.cos(yaw) * -.9)), mesh, by: null };
  WORLD.hides.push(h);
  interactable({ id, mesh, pos: h.eye, init: { by: '' }, range: 2.4,
    label: () => WS[id].by ? 'Здесь кто-то прячется' : label,
    cond: pid => !WS[id].by || WS[id].by === pid,
    use: pid => GAME.toggleHide(pid, h) });
  return h;
}
