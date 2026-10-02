/* ================= АВАТАРЫ: блочные фигурки в стиле классического Roblox (R6) ================= */
const SKINS = ['#f5cd30', '#ffcc99', '#e8b08a', '#c68a5a', '#8d5a3a', '#5a3825', '#f2f2f2'];
const SHIRTS = ['#0d69ac', '#c4281c', '#287f47', '#6b327b', '#1b2a35', '#e8e8e8', '#d9a400', '#ff6fb5', '#55a5ff', '#7a4a2a'];
const PANTS = ['#a4bd47', '#1b2a35', '#3a4a8a', '#5a5a5a', '#7a4a2a', '#c4281c', '#e8e8e8'];
const HATS = ['none', 'cap', 'beanie', 'headphones', 'hair', 'hood'];
const FACES = ['smile', 'grin', 'worried', 'cool'];
const DEFAULT_LOOK = { skin: 0, shirt: 0, pants: 0, hat: 'none', face: 'smile', hatColor: '#c4281c' };
function randomLook() { return { skin: (Math.random() * SKINS.length) | 0, shirt: (Math.random() * SHIRTS.length) | 0, pants: (Math.random() * PANTS.length) | 0, hat: pick(HATS), face: pick(FACES), hatColor: pick(SHIRTS) }; }

function faceTex(kind) {
  return canvasTex('face_' + kind, 128, 128, g => {
    g.clearRect(0, 0, 128, 128); g.fillStyle = '#111';
    const eye = (x, y, w, h) => { g.beginPath(); g.ellipse(x, y, w, h, 0, 0, TAU); g.fill(); };
    if (kind === 'cool') { g.fillRect(26, 44, 76, 16); g.fillRect(60, 44, 8, 8); }
    else { eye(46, 52, 6, kind === 'worried' ? 9 : 11); eye(82, 52, 6, kind === 'worried' ? 9 : 11); }
    g.lineWidth = 6; g.lineCap = 'round'; g.strokeStyle = '#111'; g.beginPath();
    if (kind === 'worried') { g.arc(64, 98, 16, PI * 1.15, PI * 1.85); g.stroke(); g.lineWidth = 4; g.beginPath(); g.moveTo(36, 36); g.lineTo(52, 32); g.moveTo(92, 36); g.lineTo(76, 32); }
    else if (kind === 'grin') { g.arc(64, 70, 24, .15 * PI, .85 * PI); g.closePath(); g.fillStyle = '#fff'; g.fill(); }
    else g.arc(64, 68, 24, .2 * PI, .8 * PI);
    g.stroke();
  });
}
class Avatar {
  constructor(look = DEFAULT_LOOK, name = '') {
    this.root = new THREE.Group(); this.body = new THREE.Group(); this.root.add(this.body);
    const S = .82; this.body.scale.setScalar(S); this.S = S;
    const part = (w, h, d, c, px, py, pz, pivotY) => { const g = new THREE.Group(); g.position.set(px, py, pz); const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat(c)); m.position.y = pivotY; g.add(m); this.body.add(g); return g; };
    this.ll = part(.4, .8, .4, '#a4bd47', -.2, .8, 0, -.4); this.rl = part(.4, .8, .4, '#a4bd47', .2, .8, 0, -.4);
    this.torso = part(.8, .8, .4, '#0d69ac', 0, .8, 0, .4);
    this.la = part(.4, .8, .4, '#f5cd30', -.6, 1.55, 0, -.35); this.ra = part(.4, .8, .4, '#f5cd30', .6, 1.55, 0, -.35);
    this.headG = new THREE.Group(); this.headG.position.set(0, 1.6, 0); this.body.add(this.headG);
    this.head = new THREE.Mesh(new THREE.CylinderGeometry(.3, .3, .5, 16), mat('#f5cd30')); this.head.position.y = .25; this.headG.add(this.head);
    const cap = new THREE.Mesh(new THREE.SphereGeometry(.3, 16, 8, 0, TAU, 0, PI / 2), mat('#f5cd30')); cap.scale.y = .25; cap.position.y = .25; this.head.add(cap); this.cap1 = cap;
    const cap2 = cap.clone(); cap2.rotation.x = PI; cap2.position.y = -.25; this.head.add(cap2); this.cap2 = cap2;
    this.face = new THREE.Mesh(new THREE.PlaneGeometry(.5, .5), new THREE.MeshLambertMaterial({ map: faceTex('smile'), transparent: true })); this.face.position.set(0, .26, .301); this.headG.add(this.face);
    this.hat = new THREE.Group(); this.headG.add(this.hat);
    // фонарик в правой руке
    this.torch = new THREE.Group(); const tb = new THREE.Mesh(new THREE.CylinderGeometry(.07, .09, .42, 8), mat('#2a2a2e')); tb.rotation.x = PI / 2; this.torch.add(tb);
    const lens = new THREE.Mesh(new THREE.CircleGeometry(.085, 10), mat('#fff6c8', { basic: true })); lens.position.z = .215; this.torch.add(lens); this.torchLens = lens;
    this.torch.position.set(0, -.72, .22); this.ra.add(this.torch); this.torch.visible = false;
    this.tag = null; this.walkT = 0; this.look = null;
    this.setLook(look); if (name) this.setName(name);
    this.root.traverse(o => { if (o.isMesh) { o.castShadow = false; o.userData.avatar = this; } });
  }
  setLook(l) {
    l = Object.assign({}, DEFAULT_LOOK, l); this.look = l;
    const skin = SKINS[l.skin] || SKINS[0], shirt = SHIRTS[l.shirt] || SHIRTS[0], pants = PANTS[l.pants] || PANTS[0];
    this.head.material = this.cap1.material = this.cap2.material = mat(skin);
    this.la.children[0].material = this.ra.children[0].material = mat(skin);
    this.torso.children[0].material = mat(shirt); this.ll.children[0].material = this.rl.children[0].material = mat(pants);
    this.face.material.map = faceTex(l.face || 'smile'); this.face.material.needsUpdate = true;
    this.hat.clear(); const hc = l.hatColor || '#c4281c';
    if (l.hat === 'cap') { const c = new THREE.Mesh(new THREE.SphereGeometry(.32, 16, 8, 0, TAU, 0, PI / 2), mat(hc)); c.position.y = .42; c.scale.y = .7; this.hat.add(c); const b = new THREE.Mesh(new THREE.BoxGeometry(.4, .04, .3), mat(hc)); b.position.set(0, .43, .38); this.hat.add(b); }
    else if (l.hat === 'beanie') { const c = new THREE.Mesh(new THREE.SphereGeometry(.33, 16, 10, 0, TAU, 0, PI / 2), mat(hc)); c.position.y = .38; this.hat.add(c); const p = new THREE.Mesh(new THREE.SphereGeometry(.08, 8, 6), mat('#eee')); p.position.y = .72; this.hat.add(p); }
    else if (l.hat === 'headphones') { const band = new THREE.Mesh(new THREE.TorusGeometry(.33, .035, 6, 16, PI), mat('#222')); band.position.y = .3; this.hat.add(band); for (const s of [-1, 1]) { const e = new THREE.Mesh(new THREE.CylinderGeometry(.12, .12, .1, 12), mat(hc)); e.rotation.z = PI / 2; e.position.set(s * .33, .26, 0); this.hat.add(e); } }
    else if (l.hat === 'hair') { const h = new THREE.Mesh(new THREE.SphereGeometry(.335, 16, 10, 0, TAU, 0, PI * .55), mat(hc === '#e8e8e8' ? '#3a2a1a' : '#3a2a1a')); h.position.y = .3; h.scale.y = .9; this.hat.add(h); }
    else if (l.hat === 'hood') { const h = new THREE.Mesh(new THREE.SphereGeometry(.38, 16, 10, PI * .2, PI * 1.6, 0, PI * .7), mat(shirt)); h.position.y = .28; h.rotation.y = PI; this.hat.add(h); }
  }
  setName(name, color = '#fff') {
    if (this.tag) { this.root.remove(this.tag); this.tag.material.map.dispose(); }
    this.tag = textSprite(name, { size: 40, stroke: '#000', strokeW: 7, color, scale: .0065, depthTest: true });
    this.tag.position.y = 2.25; this.root.add(this.tag);
  }
  // анимация: speed — горизонтальная скорость, o: {crouch, torch, hide, dead, wave}
  anim(dt, speed, o = {}) {
    const run = speed > 5;
    this.walkT += dt * (speed > .2 ? 4 + speed * 1.6 : 0);
    const sw = speed > .2 ? Math.sin(this.walkT) * Math.min(1, speed / 3) * (run ? .95 : .7) : 0;
    this.ll.rotation.x = sw; this.rl.rotation.x = -sw;
    this.la.rotation.x = -sw * .9; this.ra.rotation.x = o.torch ? -1.35 : sw * .9;
    this.la.rotation.z = 0; this.ra.rotation.z = 0;
    if (o.wave) { this.la.rotation.z = -2.6 + Math.sin(now() * 10) * .3; this.la.rotation.x = 0; }
    this.torch.visible = !!o.torch;
    const crouch = o.crouch ? 1 : 0;
    this.body.position.y = -crouch * .35 * this.S; this.ll.rotation.x += crouch * -.9; this.rl.rotation.x += crouch * -.9;
    this.body.rotation.x = o.dead ? -PI / 2 : 0; this.body.position.z = o.dead ? -.9 : 0; if (o.dead) this.body.position.y = .2;
    if (this.tag) this.tag.visible = !o.hide;
  }
  setPitch(p) { this.headG.rotation.x = clamp(-p, -.5, .5); }
}
