/* ================= ПИКСЕЛЬ-АРТ: спрайты в стиле Undertale/Deltarune, нарисованные кодом, как билборды в 3D =================
   PXC   — маленький холст пиксель-арта (рисование по пикселям, контур, тени, зеркало, «светящиеся» пиксели).
   PXSheet — лист спрайтов персонажа: анимации × направления (f — лицом, b — спиной, s — боком вправо) × кадры.
   PXActor — объект сцены: плоскость всегда повёрнута к камере, кадр выбирается по углу взгляда (отдельно для каждой
             камеры — работает и при разделённом экране), под ногами мягкая тень. */
const PX_CACHE = {};
function pxRGB(c) { let v = PX_CACHE[c]; if (v) return v; const t = new THREE.Color(c); v = PX_CACHE[c] = [Math.round(t.r * 255), Math.round(t.g * 255), Math.round(t.b * 255)]; return v; }
function pxShade(c, k) { const [r, g, b] = pxRGB(c), f = v => Math.max(0, Math.min(255, Math.round(k < 0 ? v * (1 + k) : v + (255 - v) * k))); return '#' + [f(r), f(g), f(b)].map(v => v.toString(16).padStart(2, '0')).join(''); }

class PXC {
  constructor(w, h) { this.w = w; this.h = h; this.c = new Array(w * h).fill(null); this.gl = new Array(w * h).fill(null); }
  ok(x, y) { return x >= 0 && y >= 0 && x < this.w && y < this.h; }
  // пиксель; glow — светится в темноте (своим цветом или заданным)
  p(x, y, col, glow) { x |= 0; y |= 0; if (!this.ok(x, y)) return this; const i = y * this.w + x; this.c[i] = col; this.gl[i] = glow ? (glow === true ? col : glow) : null; return this; }
  at(x, y) { return this.ok(x | 0, y | 0) ? this.c[(y | 0) * this.w + (x | 0)] : null; }
  r(x, y, w, h, col, glow) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.p(x + i, y + j, col, glow); return this; }
  // прямоугольник со скруглёнными углами (срезаны угловые пиксели)
  rr(x, y, w, h, col, k = 1) { this.r(x, y, w, h, col); for (let i = 0; i < k; i++) for (let j = 0; j < k - i; j++) { this.p(x + i, y + j, null); this.p(x + w - 1 - i, y + j, null); this.p(x + i, y + h - 1 - j, null); this.p(x + w - 1 - i, y + h - 1 - j, null); } return this; }
  o(cx, cy, rx, ry, col, glow) { for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) { const dx = (x + .5 - cx) / (rx + .01), dy = (y + .5 - cy) / (ry + .01); if (dx * dx + dy * dy <= 1) this.p(x, y, col, glow); } return this; }
  l(x0, y0, x1, y1, col, glow) { x0 |= 0; y0 |= 0; x1 |= 0; y1 |= 0; const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1; let e = dx + dy; for (; ;) { this.p(x0, y0, col, glow); if (x0 === x1 && y0 === y1) break; const e2 = 2 * e; if (e2 >= dy) { e += dy; x0 += sx; } if (e2 <= dx) { e += dx; y0 += sy; } } return this; }
  // толстая линия (кисть w×w)
  L(x0, y0, x1, y1, col, w = 2) { const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0), 1); for (let i = 0; i <= n; i++) { const x = Math.round(x0 + (x1 - x0) * i / n), y = Math.round(y0 + (y1 - y0) * i / n); this.r(x - (w >> 1), y - (w >> 1), w, w, col); } return this; }
  // строки-картинка: ['..aa..', '.abba.'], pal: {a:'#fff', b:'#000', A:['#f00',true]} — заглавные можно сделать светящимися
  map(x, y, rows, pal) { rows.forEach((row, j) => { for (let i = 0; i < row.length; i++) { const k = row[i]; if (k === '.' || k === ' ') continue; const v = pal[k]; if (v === undefined) continue; if (Array.isArray(v)) this.p(x + i, y + j, v[0], v[1]); else this.p(x + i, y + j, v); } }); return this; }
  // заменить цвет (палитровые свапы)
  swap(a, b) { for (let i = 0; i < this.c.length; i++) if (this.c[i] === a) this.c[i] = b; return this; }
  // мягкое затенение: пиксели у нижней/правой границы фигуры темнее, у верхней/левой — светлее
  shade(k = .18, skip) {
    const src = this.c.slice();
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) { const i = y * this.w + x, v = src[i]; if (!v || (skip && skip(v)) || this.gl[i]) continue;
      const empty = (a, b) => !this.ok(a, b) || !src[b * this.w + a] || src[b * this.w + a] !== v;
      if (empty(x + 1, y) || empty(x, y + 1)) this.c[i] = pxShade(v, -k); else if (empty(x - 1, y) || empty(x, y - 1)) this.c[i] = pxShade(v, k * .6); }
    return this;
  }
  // контур в 1 пиксель вокруг фигуры (как в Undertale)
  out(col = '#0d0b10', diag = false) {
    const src = this.c.slice(), W = this.w;
    for (let y = 0; y < this.h; y++) for (let x = 0; x < W; x++) { if (src[y * W + x]) continue; let n = false;
      for (const [a, b] of diag ? [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]] : [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const xx = x + a, yy = y + b; if (xx >= 0 && yy >= 0 && xx < W && yy < this.h && src[yy * W + xx] && src[yy * W + xx] !== col) { n = true; break; } }
      if (n) this.c[y * W + x] = col; }
    return this;
  }
  flipX() { const W = this.w; for (let y = 0; y < this.h; y++) for (let x = 0; x < W >> 1; x++) { const a = y * W + x, b = y * W + W - 1 - x; [this.c[a], this.c[b]] = [this.c[b], this.c[a]]; [this.gl[a], this.gl[b]] = [this.gl[b], this.gl[a]]; } return this; }
  shift(dx, dy) { const c = this.c.slice(), g = this.gl.slice(); this.c.fill(null); this.gl.fill(null); for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) { const i = y * this.w + x; if (c[i]) this.p(x + dx, y + dy, c[i], g[i]); } return this; }
  // нарисовать в контекст 2D (glowOnly — карта свечения: светящиеся пиксели цветом, остальное чёрное)
  blit(g, ox, oy, glowOnly) {
    const img = g.createImageData(this.w, this.h), d = img.data;
    for (let i = 0; i < this.c.length; i++) { const v = glowOnly ? (this.gl[i] || (this.c[i] ? '#000000' : null)) : this.c[i]; if (!v) continue; const [r, gg, b] = pxRGB(v); d[i * 4] = r; d[i * 4 + 1] = gg; d[i * 4 + 2] = b; d[i * 4 + 3] = 255; }
    g.putImageData(img, ox, oy);
  }
  hasGlow() { return this.gl.some(Boolean); }
}

/* ---- лист спрайтов ---- */
// def: { key, w, h, ppm (пикселей на метр), anims: { idle:{n,fps}, walk:{n,fps}, ... }, dirs:['f','b','s'] (по умолчанию все),
//        draw(p, anim, dir, frame, n) — рисует один кадр (dir 's' — лицом вправо; влево получается зеркалом), post(p) — общий пост-процесс }
const PX_SHEETS = {};
class PXSheet {
  constructor(def) {
    this.def = def; this.w = def.w; this.h = def.h; const dirs = def.dirs || ['f', 'b', 's']; this.dirs = dirs;
    const names = Object.keys(def.anims); this.rows = {}; let row = 0, cols = 1;
    for (const a of names) { cols = Math.max(cols, def.anims[a].n || 1); this.rows[a] = {}; for (const d of dirs) this.rows[a][d] = row++; }
    this.cols = cols; this.nrows = row;
    const cv = document.createElement('canvas'); cv.width = cols * this.w; cv.height = row * this.h; const g = cv.getContext('2d');
    const gc = document.createElement('canvas'); gc.width = cv.width; gc.height = cv.height; const gg = gc.getContext('2d'); gg.fillStyle = '#000'; gg.fillRect(0, 0, gc.width, gc.height);
    let glow = false;
    for (const a of names) { const n = def.anims[a].n || 1; for (const d of dirs) for (let f = 0; f < n; f++) {
      const p = new PXC(this.w, this.h); def.draw(p, a, d, f, n); if (def.post) def.post(p, a, d, f); else { p.shade(.16); p.out(def.outline || '#0d0b10'); }
      p.blit(g, f * this.w, this.rows[a][d] * this.h); if (p.hasGlow()) { glow = true; p.blit(gg, f * this.w, this.rows[a][d] * this.h, true); } } }
    this.canvas = cv; this.glowCanvas = glow ? gc : null;
    const mk = c => { const t = new THREE.CanvasTexture(c); t.magFilter = THREE.NearestFilter; t.minFilter = THREE.NearestFilter; t.generateMipmaps = false; t.colorSpace = THREE.SRGBColorSpace; t.repeat.set(1 / cols, 1 / row); return t; };
    this.tex = mk(cv); this.glowTex = glow ? mk(gc) : null;
    const ppm = def.ppm || 26, W = this.w / ppm, H = this.h / ppm; this.size = [W, H];
    this.geo = new THREE.PlaneGeometry(W, H); this.geo.translate(0, H / 2 - (def.foot || 0) / ppm, 0);
  }
  static get(def) { return PX_SHEETS[def.key] || (PX_SHEETS[def.key] = new PXSheet(def)); }
}
// мягкая круглая тень под ногами
const PX_SHADOW = { tex: null };
function pxShadowTex() { return PX_SHADOW.tex || (PX_SHADOW.tex = canvasTex('pxshadow', 32, 32, g => { const r = g.createRadialGradient(16, 16, 2, 16, 16, 16); r.addColorStop(0, 'rgba(0,0,0,.55)'); r.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = r; g.fillRect(0, 0, 32, 32); })); }

class PXActor extends THREE.Object3D {
  constructor(sheetOrDef, o = {}) {
    super(); const S = this.sheet = sheetOrDef instanceof PXSheet ? sheetOrDef : PXSheet.get(sheetOrDef);
    this.anim = Object.keys(S.def.anims)[0]; this.t = 0; this.frame = 0; this.speed = 1; this.lit = o.lit !== false; this.lockDir = null;
    const map = S.tex.clone(); map.needsUpdate = true; this.map = map;
    const mo = { map, alphaTest: .5, side: THREE.DoubleSide };
    if (S.glowTex) { this.gmap = S.glowTex.clone(); this.gmap.needsUpdate = true; Object.assign(mo, { emissive: new THREE.Color('#ffffff'), emissiveMap: this.gmap }); }
    this.mat = this.lit ? new THREE.MeshLambertMaterial(mo) : new THREE.MeshBasicMaterial(mo);
    const m = this.mesh = new THREE.Mesh(S.geo, this.mat); m.frustumCulled = false; this.add(m);
    m.onBeforeRender = (r, sc, cam) => this.faceCam(cam);
    if (o.shadow !== false) { const sh = this.shadow = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ map: pxShadowTex(), transparent: true, depthWrite: false })); sh.rotation.x = -PI / 2; sh.position.y = .015; const s = (o.shadowSize || S.size[0] * .7); sh.scale.set(s, s * .6, 1); sh.renderOrder = -1; this.add(sh); }
    this._p = new V3(); this._q = new THREE.Quaternion(); this._s = new V3(); this._e = new THREE.Euler();
  }
  play(anim, speed = 1) { if (!this.sheet.rows[anim]) return this; if (anim !== this.anim) { this.anim = anim; this.t = 0; } this.speed = speed; return this; }
  update(dt) { const A = this.sheet.def.anims[this.anim] || { n: 1, fps: 6 }; this.t += dt * (A.fps || 6) * this.speed; this.frame = A.loop === false ? Math.min(A.n - 1, this.t | 0) : (this.t | 0) % (A.n || 1); }
  // перед отрисовкой для конкретной камеры: повернуться к ней и выбрать направление
  faceCam(cam) {
    const S = this.sheet, m = this.mesh;
    this.matrixWorld.decompose(this._p, this._q, this._s);
    const yaw = this._e.setFromQuaternion(this._q, 'YXZ').y;
    const cp = cam.getWorldPosition ? cam.matrixWorld.elements : null, cx = cp[12], cz = cp[14];
    const a = Math.atan2(cx - this._p.x, cz - this._p.z), rel = angDiff(yaw, a);
    let dir = 'f', mirror = false;
    if (this.lockDir) dir = this.lockDir;
    else if (S.dirs.length > 1) { const ar = Math.abs(rel); if (ar < PI * .27) dir = 'f'; else if (ar > PI * .73 && S.dirs.includes('b')) dir = 'b'; else if (S.dirs.includes('s')) { dir = 's'; mirror = Math.sin(yaw - a) < 0; } }
    const row = S.rows[this.anim] ? S.rows[this.anim][dir] ?? S.rows[this.anim][S.dirs[0]] : 0;
    const ox = this.frame / S.cols, oy = 1 - (row + 1) / S.nrows;
    this.map.offset.set(ox, oy); if (this.gmap) this.gmap.offset.set(ox, oy);
    const sx = this._s.x * (mirror ? -1 : 1);
    m.matrixWorld.compose(this._p, this._q.setFromAxisAngle(PXActor.UP, a), this._s.set(sx, this._s.y, this._s.z));
  }
}
PXActor.UP = new V3(0, 1, 0);
