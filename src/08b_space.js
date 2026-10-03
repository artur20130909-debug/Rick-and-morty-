/* ================= КОСМОС: Цитадель Риков и сцены полёта (прилёт / побег) =================
   drawSpaceScene(k, back, crew) рисует ВЕСЬ кадр полёта: k — кадр сцены (60 в секунду), back=false — прилёт, true — побег;
   crew — функция, рисующая экипаж в кабине корабля (передаётся в ship(..., { crew })).
   SPACE_LEN.in / SPACE_LEN.out — сколько кадров длится полёт до затемнения (сюжет ждёт SCENE.t > SPACE_LEN.*).
   Если диалог затянулся (k > LEN), сцена «досматривается»: прилёт зависает над городом у ворот-причала, побег — Цитадель
   продолжает разваливаться на фоне золотого разрыва. Когда сюжет начинает затемнение — камера ныряет в ворота / корабль уносится.
   Цитадель один раз рисуется в большие холсты (с мип-уровнями, чтобы чисто уменьшаться), каждый кадр — только масштаб. */
const xe = (cx, cy, rx, ry, rot, a0, a1, ccw) => x.ellipse(cx, cy, Math.max(0, rx), Math.max(0, ry), rot, a0, a1, ccw);   // эллипс без ошибок на нулевом радиусе
const SPACE_LEN = { in: 450, out: 360 };
const sst = (a, b, v) => { const t = cl((v - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };   // плавная ступенька

/* ---------- спрайты: холст + мип-цепочка ---------- */
function spMip(c) {
  const m = [c];
  for (let p = c; p.width > 6 && p.height > 6;) { const q = document.createElement('canvas'); q.width = Math.ceil(p.width / 2); q.height = Math.ceil(p.height / 2); const g = q.getContext('2d'); g.imageSmoothingEnabled = true; g.imageSmoothingQuality = 'high'; g.drawImage(p, 0, 0, q.width, q.height); m.push(p = q); }
  return m;
}
// нарисовать fn в модельных координатах прямоугольника [x0..x1]×[y0..y1] с плотностью P пикселей на единицу
function spSprite(x0, y0, x1, y1, P, fn) {
  const c = document.createElement('canvas'); c.width = Math.max(1, Math.ceil((x1 - x0) * P)); c.height = Math.max(1, Math.ceil((y1 - y0) * P));
  const old = x; x = c.getContext('2d'); x.setTransform(P, 0, 0, P, -x0 * P, -y0 * P); x.lineJoin = 'round';
  try { fn(); } catch (e) { console.error(e); } finally { x = old; }
  return { m: spMip(c), x0, y0, w: c.width / P, h: c.height / P };
}
// вывести спрайт в текущих (модельных) координатах: уровень мипа выбирается по реальному масштабу
function spDraw(s) { const t = x.getTransform(); let k = Math.hypot(t.a, t.b) * s.w / s.m[0].width, i = 0; while (k < .5 && i < s.m.length - 1) { k *= 2; i++; } x.drawImage(s.m[i], s.x0, s.y0, s.w, s.h); }

/* ---------- палитры металла: обычная (холодный свет звезды слева) и «золотая» (контровой свет разрыва, обесточенные окна) ---------- */
const CPAL = {
  n: { hi: '#f4f8fd', l: '#c4d0e2', m: '#909db8', d: '#5f6a88', dd: '#3f4868', k: '#181c34', face: '#8390ad', face2: '#68759a', win: ['#ffe9a6', '#ffd36b', '#fff4cf', '#ffe2a0', '#9ff0ff'], off: '#323a5e', bay: '#8dfff0', on: .6 },
  g: { hi: '#ffd47a', l: '#a08a80', m: '#6e6068', d: '#4b3e50', dd: '#33283a', k: '#140c16', face: '#655660', face2: '#4f4250', win: ['#ffb04a', '#ff8a3a', '#ffd56b', '#ff5a32', '#ffb04a'], off: '#271c26', bay: '#ffb04a', on: .3 },
};
const CRX = 200, CRY = .18;                      // радиус диска Цитадели и наклон взгляда (полуось эллипса = r·CRY)
const cBT = t => 44 + 142 * t, cBR = t => Math.max(.01, 170 * Math.pow(Math.max(0, 1 - Math.pow(t, 1.7)), .8));   // профиль нижней чаши
// цилиндрическая заливка «полосами» (2–3 тона + блик), свет слева
function cylG(cx, w, p) { const a = cx - w / 2; return grad(a, 0, a + w, 0, [[0, p.m], [.08, p.m], [.08, p.l], [.2, p.l], [.2, p.hi], [.3, p.hi], [.3, p.l], [.48, p.l], [.48, p.m], [.7, p.m], [.7, p.d], [.88, p.d], [.88, p.dd], [1, p.dd]]); }
function bandG(r, p, dark) { return grad(-r, 0, r, 0, dark ? [[0, p.d], [.25, p.dd], [.7, p.dd], [1, p.k]] : [[0, p.m], [.05, p.l], [.15, p.l], [.15, p.hi], [.21, p.hi], [.21, p.l], [.4, p.l], [.4, p.m], [.66, p.m], [.66, p.d], [.86, p.d], [.86, p.dd], [1, p.dd]]); }

/* ---------- детали башен (модельные единицы; верх — минус y) ---------- */
function cBody(cx, y0, y1, w, p, r, win = 1) {      // цилиндр от y0 (верх) до y1 (низ) с окнами
  const a = cx - w / 2, ry = w * .2;
  path(() => { x.moveTo(a, y0); x.lineTo(a, y1); xe(cx, y1, w / 2, ry, 0, PI, 0, true); x.lineTo(a + w, y0); x.closePath(); }, cylG(cx, w, p), p.k, .5);
  if (win && w > 4) {
    const cols = Math.max(2, Math.round(w / 3)), ww = w / cols * .55, hue = r() < .18 ? 4 : (r() * 3 | 0);
    for (let yy = y0 + 2.6; yy < y1 - 2; yy += 3.4) { const row = r() < .7; for (let j = 0; j < cols; j++) { const ph = -1.2 + 2.4 * (j + .5) / cols, xx = cx + sin(ph) * w * .41, sw = Math.max(.5, cos(ph) * ww), lit = row && r() < p.on + .3; R(xx - sw / 2, yy, sw, 1.5, lit ? p.win[r() < .85 ? hue : (r() * 4 | 0)] : (ph > .45 ? p.dd : p.off), null); } }
  }
  E(cx, y0, w / 2, ry, p.m, p.k, .5); E(cx - w * .07, y0 - ry * .1, w * .33, ry * .58, p.l, null);
}
function cRing(cx, y, w, p) {                        // фланец-кольцо
  const a = cx - w / 2 - 1, rx = w / 2 + 1, ry = (w + 2) * .2;
  path(() => { x.moveTo(a, y - 1); x.lineTo(a, y + 1); xe(cx, y + 1, rx, ry, 0, PI, 0, true); x.lineTo(a + w + 2, y - 1); xe(cx, y - 1, rx, ry, 0, 0, PI); x.closePath(); }, cylG(cx, w + 2, p), p.k, .45);
  path(() => xe(cx, y - 1, rx, ry, 0, .35, PI - .35), null, p.hi, .4);
}
function cDome(cx, y, w, hh, p) {
  path(() => { x.moveTo(cx - w / 2, y); xe(cx, y, w / 2, hh, 0, PI, TAU); xe(cx, y, w / 2, w * .2, 0, 0, PI); x.closePath(); }, cylG(cx, w, p), p.k, .5);
  E(cx - w * .18, y - hh * .55, w * .12, hh * .2, p.hi, null);
}
function cPod(cx, y, rw, rh, p, r) {                  // широкая «тарелка» на башне
  E(cx, y, rw, rh, cylG(cx, rw * 2, p), p.k, .5);
  path(() => xe(cx, y + rh * .1, rw * .98, rh * .85, 0, .12, PI - .12), 'rgba(14,12,36,.38)', null);
  path(() => xe(cx, y - rh * .05, rw * .99, rh * .45, 0, .25, PI - .25), null, p.hi, .4);
  for (let j = 0; j < 11; j++) { const ph = -1.3 + 2.6 * j / 10; R(cx + sin(ph) * rw * .86 - .45, y + rh * .2 + cos(ph) * rh * .3, .9, .9, p.win[(j + (r() * 2 | 0)) % 3], null); }
}
function cAnt(cx, y, L, p, bc) { LN(cx, y, cx, y - L, p.d, .9); LN(cx - .25, y, cx - .25, y - L * .9, p.l, .35); R(cx - 1, y - L * .55, 2, .9, p.m, null); E(cx, y - L, 1, 1, p.hi, null); if (bc) bc.push([cx, y - L]); }
// башня: t = {x,y (основание), w, h, k (0 купол, 1 «тарелка», 2 ступени, 3 игла, 4 площадка, 8 ворота-причал, 9 центральный шпиль), seed}
function cTower(t, p, bc) {
  const r = SR(t.seed), { x: bx, y: by, w, h } = t, top = by - h;
  if (t.k === 9) return cSpire(t, p, r, bc);
  if (t.k === 8) return cGate(bx, by, p, bc);
  E(bx + w * .2, by + w * .06, w * .78, w * .22, 'rgba(8,8,28,.4)', null);   // тень на площадке
  const rings = () => { const n = r() * 3 | 0; for (let i = 0; i < n; i++) cRing(bx, by - h * (.25 + r() * .4), w, p); };
  if (t.k === 2) {
    let y = by, ww = w; const fr = [.5, .3, .2];
    for (let i = 0; i < 3; i++) { const hh = h * fr[i]; cBody(bx, y - hh, y, ww, p, r); y -= hh; if (i < 2) cRing(bx, y + 1, ww, p); ww *= .68; }
    if (r() < .55) cAnt(bx, y, 7 + r() * 12, p, bc); else cDome(bx, y, ww / .68, ww * .5, p);
  } else if (t.k === 1) {
    const py = top + h * .2;
    cBody(bx, top + w * .3, py, w * .42, p, r, 0); cBody(bx, py, by, w, p, r); rings(); cPod(bx, py, w * .98, w * .36, p, r);
    cDome(bx, top + w * .3, w * .42, w * .3, p); cAnt(bx, top + w * .05, 6 + r() * 10, p, bc);
  } else if (t.k === 3) {
    cBody(bx, top + h * .32, by, w, p, r); rings(); cBody(bx, top + h * .12, top + h * .32, w * .56, p, r, 0);
    PG([bx - w * .28, top + h * .12, bx + w * .28, top + h * .12, bx, top - 6], cylG(bx, w * .56, p), p.k, .5); if (bc) bc.push([bx, top - 6]);
  } else if (t.k === 4) {
    cBody(bx, top + 3, by, w, p, r); rings(); cPod(bx, top + 3, w * 1.18, w * .2, p, r); E(bx, top + 1.6, w * .7, w * .1, p.l, null);
    if (r() < .5) { E(bx + w * .2, top, w * .32, w * .1, '#b8c0c8', p.k, .4); E(bx + w * .2, top - w * .07, w * .14, w * .09, 'rgba(160,220,240,.8)', null); }
  } else {
    const dh = w * .5; cBody(bx, top + dh, by, w, p, r); rings(); cDome(bx, top + dh, w, dh, p); if (r() < .5) cAnt(bx, top, 5 + r() * 12, p, bc);
  }
}
// центральный шпиль с парящим кольцом-гало
function cSpire(t, p, r, bc) {
  const { x: bx, y: by } = t, hy = by - 176;
  E(bx + 6, by + 2, 26, 7, 'rgba(8,8,28,.45)', null);
  cBody(bx, by - 72, by, 36, p, r); cRing(bx, by - 30, 36, p); cRing(bx, by - 72, 36, p);
  cBody(bx, by - 150, by - 72, 22, p, r); cRing(bx, by - 112, 22, p);
  path(() => xe(bx, hy, 50, 9, 0, PI, TAU), null, p.k, 4.2); path(() => xe(bx, hy, 50, 9, 0, PI, TAU), null, p.d, 2.6);
  cPod(bx, by - 150, 30, 9, p, r);
  cBody(bx, by - 224, by - 150, 12, p, r); cRing(bx, by - 196, 12, p);
  PG([bx - 6, by - 224, bx + 6, by - 224, bx, by - 290], cylG(bx, 12, p), p.k, .5); cAnt(bx, by - 288, 10, p, bc);
  path(() => xe(bx, hy, 50, 9, 0, 0, PI), null, p.k, 4.2); path(() => xe(bx, hy, 50, 9, 0, 0, PI), null, p.l, 2.6); path(() => xe(bx, hy - .9, 50, 9, 0, .5, PI - .5), null, p.hi, .7);
  for (let j = 0; j < 14; j++) { const a = .15 + j / 13 * (PI - .3); R(bx + cos(a) * 50 - .6, hy + sin(a) * 9 - .2, 1.2, 1.2, p.win[j % 2 ? 4 : 0], null); }
}
// ворота-причал на площади: кольцо, повёрнутое к камере (в него и «ныряем» при посадке)
function cGate(gx, gy, p, bc) {
  const cy = gy - 20;
  E(gx + 4, gy + 1, 26, 5, 'rgba(8,8,28,.45)', null);
  cBody(gx - 19, cy + 4, gy, 6, p, SR(5), 0); cBody(gx + 19, cy + 4, gy, 6, p, SR(6), 0);
  path(() => { x.arc(gx, cy, 18, 0, TAU); x.moveTo(gx + 12.5, cy); x.arc(gx, cy, 12.5, 0, TAU, true); }, grad(gx - 18, cy - 18, gx + 14, cy + 18, [[0, p.hi], [.25, p.l], [.55, p.m], [.8, p.d], [1, p.dd]]), p.k, .6);
  path(() => x.arc(gx, cy, 12.5, 0, TAU), null, p.bay, .9); path(() => x.arc(gx, cy, 16.6, PI * 1.05, PI * 1.6), null, p.hi, .6);
  for (let j = 0; j < 12; j++) { const a = j / 12 * TAU; R(gx + cos(a) * 15.3 - .6, cy + sin(a) * 15.3 - .6, 1.2, 1.2, j % 3 ? p.win[0] : p.bay, null); }
  if (bc) bc.push([gx, cy - 18]);
}
// подвесной шпиль снизу чаши: s = {x,y (верх), L, w}
function cHang(s, p, r, bc) {
  const { x: sx, y: sy, L, w } = s, yb = sy + L * .58;
  cBody(sx, sy, yb, w, p, r); cRing(sx, sy + L * .18, w, p); cPod(sx, sy + L * .4, w * .95, w * .34, p, r);
  path(() => { x.moveTo(sx - w / 2, yb); xe(sx, yb, w / 2, w * .2, 0, PI, 0, true); x.lineTo(sx + w * .1, sy + L - 3); x.lineTo(sx, sy + L); x.lineTo(sx - w * .1, sy + L - 3); x.closePath(); }, cylG(sx, w, p), p.k, .5);
  E(sx, sy + L, 1.1, 1.1, p.hi, null); if (bc) bc.push([sx, sy + L + 1]);
}
// корпус: чаша с рёбрами, подвесные шпили (если переданы), слоистый обод с огнями и доками, верхняя площадка города
function cBodyDraw(p, hs, bc) {
  const bowl = () => { for (let i = 0; i <= 44; i++) { const t = i / 44, rr = cBR(t), yy = cBT(t); x.moveTo(rr, yy); xe(0, yy, rr, rr * CRY, 0, 0, TAU); } };
  path(bowl, null, p.k, 1.8);
  path(bowl, grad(-170, 0, 170, 0, [[0, p.d], [.08, p.m], [.2, p.l], [.3, p.m], [.55, p.d], [.8, p.dd], [1, p.k]]), null);
  path(bowl, grad(0, 50, 0, 196, [[0, 'rgba(10,8,30,0)'], [.5, 'rgba(10,8,30,.22)'], [1, 'rgba(10,8,30,.55)']]), null);
  for (let i = 1; i < 18; i++) {                                // рёбра (меридианы) со светлой гранью
    const th = i / 18 * PI, line = (dth, col, lw) => { x.beginPath(); for (let j = 0; j <= 22; j++) { const t = j / 22 * .97, rr = cBR(t), px = rr * cos(th + dth), py = cBT(t) + rr * CRY * sin(th + dth); j ? x.lineTo(px, py) : x.moveTo(px, py); } x.strokeStyle = col; x.lineWidth = lw; x.stroke(); };
    line(0, p.dd, 1); if (th > PI * .35) line(-.035, p.l, .45);
  }
  for (const t of [.18, .4, .62, .8]) {                         // кольца-«широты» с огнями
    const rr = cBR(t), yy = cBT(t);
    path(() => xe(0, yy, rr, rr * CRY, 0, .04, PI - .04), null, p.k, 1.6); path(() => xe(0, yy - 1, rr, rr * CRY, 0, .3, PI - .3), null, p.l, .5);
    const n = Math.round(rr / 5); for (let j = 1; j < n; j++) { const th = j / n * PI; R(rr * cos(th) - .7, yy + rr * CRY * sin(th) + .5, 1.4, 1, (j + (t * 10 | 0)) % 4 ? p.win[j % 3] : p.bay, null); }
  }
  E(0, cBT(1) - 2, 5, 3, p.m, p.k, .6);
  if (hs) for (const s of hs) cHang(s, p, SR(s.seed), bc);
  // обод: снизу вверх, верхние слои шире и нависают
  const band = (rr, y0, y1, fill) => path(() => { x.moveTo(rr, y0); xe(0, y0, rr, rr * CRY, 0, 0, PI); x.lineTo(-rr, y1); xe(0, y1, rr, rr * CRY, 0, PI, 0, true); x.closePath(); }, fill, p.k, .9);
  const arcPt = (rr, y, th) => [rr * cos(th), y + rr * CRY * sin(th)];
  band(170, 38, 46, bandG(170, p, 1));
  band(184, 27, 38, bandG(184, p));
  for (let j = 1; j < 36; j++) { const th = j / 36 * PI, [px, py] = arcPt(184, 30, th), ww = 2.4 * sin(th) + .3; R(px - ww / 2, py, ww, 2, (j % 5 === 2) ? p.bay : p.win[j % 3], null); LN(...arcPt(184, 27.5, th + PI / 72), ...arcPt(184, 37.5, th + PI / 72), p.d, .45); }
  band(192, 22, 27, bandG(192, p, 1));
  band(200, 6, 22, bandG(200, p));
  const bays = [.24, .41, .59, .76];
  for (let j = 1; j < 60; j++) { const th = j / 60 * PI; if (bays.some(b => abs(th / PI - b) < .045)) continue; const ww = 2.2 * sin(th) + .3; for (const yy of [9, 15.5]) { const [px, py] = arcPt(200, yy, th); R(px - ww / 2, py, ww, 2.2, (j * 7 + yy | 0) % 5 ? p.win[(j + (yy | 0)) % 4] : p.off, null); } }
  for (const b of bays) {                                       // доки: проёмы с подсветкой
    const t0 = (b - .035) * PI, t1 = (b + .035) * PI, q = [...arcPt(200, 8, t1), ...arcPt(200, 8, t0), ...arcPt(200, 20.5, t0), ...arcPt(200, 20.5, t1)];
    PG(q, p.k, p.hi, .6); const [cx, cy] = arcPt(200, 14.5, b * PI); E(cx, cy + 2, 6 * sin(b * PI), 3, p.bay, null); E(cx, cy + 2.4, 3.5 * sin(b * PI), 1.6, '#ffffff', null);
  }
  band(200, 0, 6, bandG(200, p));
  path(() => xe(0, .6, 200, 36, 0, .05, PI - .05), null, p.hi, 1);
  // верх: площадка города — кольцевые проспекты с фонарями, площадь у шпиля, аллея к воротам
  E(0, 0, 200, 36, p.face, p.k, 1);
  path(() => xe(-40, -6, 150, 26, 0, 0, TAU), 'rgba(255,255,255,.06)', null);
  for (const rr of [64, 112, 160]) { path(() => xe(0, 0, rr, rr * CRY, 0, 0, TAU), null, p.face2, 2.4); const n = rr / 4 | 0; for (let j = 0; j < n; j++) { const th = j / n * TAU; R(rr * cos(th) - .5, rr * CRY * sin(th) - .5, 1, 1, j % 2 ? p.win[0] : p.win[4], null); } }
  PG([-16, 36, 16, 36, 12, 10, -12, 10], p.face2, null); for (let y = 12; y < 36; y += 4) { R(-14 - y * .08, y, 1, 1, p.win[0], null); R(13 + y * .08, y, 1, 1, p.win[0], null); }
  E(0, 6, 40, 8, p.face2, null); E(0, 6, 30, 5.6, null, p.bay, .5);
}

/* ---------- раскладка города (детерминированная) + разломы для побега ---------- */
const CSP = [[.3, .14, 42, 6], [.48, .27, 80, 8], [.62, .4, 58, 7], [.66, .6, 68, 7], [.5, .73, 88, 8], [.32, .86, 48, 6], [.15, .05, 28, 5], [.15, .95, 32, 5], [.82, .3, 54, 6], [.84, .7, 58, 6], [1, .5, 116, 10]];
const PIECE_MOT = [{ brk: 150, v: [-.3, -.07], w: -.0018, pv: [-150, 10] }, { brk: 245, v: [-.1, .1], w: .0011, pv: [-56, 10] }, { brk: 205, v: [.12, -.12], w: -.0009, pv: [42, 10] }, { brk: 100, v: [.33, .06], w: .002, pv: [150, 10] }, { brk: 64, v: [.03, .3], w: .0024, pv: [0, 150] }];
let CIT_GEO = null, CIT_N = null, CIT_G = null;
function citGeo() {
  if (CIT_GEO) return CIT_GEO;
  const r = SR(4242), tw = [{ x: 0, y: -3, w: 36, h: 290, k: 9, seed: 7 }, { x: 0, y: 27, w: 38, h: 40, k: 8, seed: 9 }];
  for (const [rho, n] of [[.22, 7], [.35, 10], [.49, 13], [.63, 16], [.76, 19], [.88, 23]]) for (let i = 0; i < n; i++) {
    const a = (i + .2 + r() * .6) / n * TAU + rho * 2.3, rr = rho + (r() - .5) * .05, sa = sin(a), ca = cos(a);
    const w = 8 + r() * 9 - rr * 2, h = (30 + 165 * Math.pow(1 - rr, 1.5)) * (.55 + r() * .55) * (sa > .4 ? .72 : 1), k = r() < .12 ? 3 : (r() * 5 | 0), seed = r() * 1e6 | 0;
    if (sa > 0 && abs(ca) * rr * CRX < 23 + w / 2) continue;   // проспект от края к воротам и шпилю
    tw.push({ x: ca * rr * CRX, y: sa * rr * CRX * CRY, w, h, k, seed });
  }
  tw.sort((a, b) => a.y - b.y);
  const hs = CSP.map(([t, th, L, w], i) => { const rr = cBR(t); return { x: rr * cos(th * PI), y: cBT(t) + rr * CRY * sin(th * PI) - 1.5, L, w, seed: 100 + i }; });
  // разломы: три зубчатые вертикальные трещины + горизонтальная (отваливается низ чаши)
  const hq = SR(88), hcut = []; for (let X = -420; X <= 420; X += 14) hcut.push([X, 114 + (hq() - .5) * 18]);
  const hY = X => { for (let i = 1; i < hcut.length; i++) if (hcut[i][0] >= X) { const a = hcut[i - 1], b = hcut[i]; return lerp(a[1], b[1], (X - a[0]) / (b[0] - a[0])); } return 114; };
  const cuts = [-104, -8, 92].map((cx, i) => { const q = SR(60 + i * 7), c = [[cx, -420]]; for (let y = -44; y <= 100; y += 12) c.push([cx + (q() - .5) * 24, y]); const l = c[c.length - 1]; c.push([l[0], hY(l[0])]); return c; });
  const Lb = [[[-420, -420], [-420, hY(-420)]], ...cuts], Rb = [...cuts, [[420, -420], [420, hY(420)]]], pieces = [];
  for (let i = 0; i < 4; i++) { const a = Lb[i], b = Rb[i], xa = a[a.length - 1][0], xb = b[b.length - 1][0]; pieces.push(Object.assign({ poly: [...a, ...hcut.filter(q => q[0] > xa && q[0] < xb), ...b.slice().reverse()] }, PIECE_MOT[i])); }
  pieces.push(Object.assign({ poly: [...hcut, [420, 420], [-420, 420]] }, PIECE_MOT[4]));
  const cutX = (c, Y) => { for (let i = 1; i < c.length; i++) if (c[i][1] >= Y) { const a = c[i - 1], b = c[i]; return lerp(a[0], b[0], (Y - a[1]) / ((b[1] - a[1]) || 1)); } return c[c.length - 1][0]; };
  const pieceOf = (X, Y) => Y > hY(X) ? 4 : cuts.filter(c => cutX(c, Y) < X).length;
  // какие башни/шпили отрываются при побеге, когда и куда летят
  for (const t of tw) { const q = SR(t.seed + 5); t.pc = pieceOf(t.x, t.y); t.det = t.k === 8 ? 0 : t.k === 9 ? 1 : (q() < (t.h > 95 ? .55 : .3) ? 1 : 0); t.brk = t.k === 9 ? 285 : 22 + q() * 560; t.v = t.k === 9 ? [.07, -.15] : [t.x / 200 * .3 + (q() - .5) * .22, -.1 - q() * .26]; t.av = t.k === 9 ? .0032 : (q() - .5) * .014; }
  for (const s of hs) { const q = SR(s.seed + 9); s.pc = pieceOf(s.x, s.y); s.det = q() < .6 ? 1 : 0; s.brk = 40 + q() * 480; s.v = [(q() - .5) * .14, .14 + q() * .22]; s.av = (q() - .5) * .012; }
  // где светятся трещины: только там, где есть корпус
  const inBody = (X, Y) => Y < 0 ? (X / 200) ** 2 + (Y / 36) ** 2 < .96 : Y < 44 ? abs(X) < 197 - Math.max(0, Y - 22) * 1.3 : (Y - 44) / 142 < 1 && abs(X) < cBR((Y - 44) / 142) * .96;
  const seg = pts => { const out = []; let cur = []; for (const q of pts) { if (inBody(q[0], q[1])) cur.push(q); else if (cur.length) { if (cur.length > 1) out.push(cur); cur = []; } } if (cur.length > 1) out.push(cur); return out; };
  const fine = c => { const o = []; for (let i = 1; i < c.length; i++) for (let j = 0; j < 4; j++) o.push([lerp(c[i - 1][0], c[i][0], j / 4), lerp(c[i - 1][1], c[i][1], j / 4)]); o.push(c[c.length - 1]); return o; };
  const cracks = [];
  cuts.forEach((c, i) => cracks.push({ a: i, b: i + 1, segs: seg(fine(c)) }));
  const ends = [-420, ...cuts.map(c => c[c.length - 1][0]), 420];
  for (let i = 0; i < 4; i++) cracks.push({ a: i, b: 4, segs: seg(fine(hcut.filter(q => q[0] >= ends[i] - 14 && q[0] <= ends[i + 1] + 14))) });
  for (const c of cracks) c.brk = Math.min(PIECE_MOT[c.a].brk, PIECE_MOT[c.b].brk);
  // события-взрывы: отрыв башен/шпилей и раскол кусков
  const ev = [];
  for (const t of tw) if (t.det) ev.push({ t: t.brk, pc: t.pc, X: t.x, Y: t.y - 3, R: t.w * .8 + 5, big: t.k === 9 });
  for (const s of hs) if (s.det) ev.push({ t: s.brk, pc: s.pc, X: s.x, Y: s.y + 3, R: s.w * .9 + 4 });
  for (const c of cracks) for (const sg of c.segs) for (let j = 0; j < sg.length; j += 9) ev.push({ t: c.brk - 4 + j * .6, pc: c.a, X: sg[j][0], Y: sg[j][1], R: 13, big: j === 0 });
  ev.sort((a, b) => a.t - b.t);
  return CIT_GEO = { tw, hs, pieces, cracks, ev, pieceOf, inBody };
}
// обычная Цитадель (прилёт): всё в одном холсте
function citBuildN() { const g = citGeo(), p = CPAL.n, bc = [], s = spSprite(-224, -306, 224, 316, 2.5, () => { cBodyDraw(p, g.hs, bc); for (const t of g.tw) cTower(t, p, bc); }); s.bc = bc; return s; }
// золотая (побег): корпус, каждая башня и каждый подвесной шпиль — отдельно, чтобы разлетаться
function citBuildG() {
  const g = citGeo(), p = CPAL.g, P = 1.6;
  const body = spSprite(-214, -42, 214, 194, P, () => cBodyDraw(p, null, null));
  const tw = g.tw.map(t => { const bc = [], e = t.k === 9 ? 56 : t.w * 1.25 + 4, sp = spSprite(t.x - e, t.y - t.h - 30, t.x + e, t.y + t.w * .3 + 4, P, () => cTower(t, p, bc)); return { t, sp, bc }; });
  const hs = g.hs.map(s => ({ s, sp: spSprite(s.x - s.w - 2, s.y - 4, s.x + s.w + 2, s.y + s.L + 3, P, () => cHang(s, p, SR(s.seed), null)) }));
  return { body, tw, hs };
}

/* ---------- фон: туманность с дизерингом, звёзды, галактики, планета (один раз, в разрешении арта) ---------- */
const SP_BG = {};
function spHash(i, j, s) { let n = Math.imul(i, 374761393) + Math.imul(j, 668265263) + Math.imul(s, 1442695041); n = Math.imul(n ^ (n >>> 13), 1274126177); return ((n ^ (n >>> 16)) >>> 0) / 4294967296; }
function spNoise(X, Y, s) { const i = Math.floor(X), j = Math.floor(Y), u = X - i, v = Y - j, a = u * u * (3 - 2 * u), b = v * v * (3 - 2 * v); return lerp(lerp(spHash(i, j, s), spHash(i + 1, j, s), a), lerp(spHash(i, j + 1, s), spHash(i + 1, j + 1, s), a), b); }
function spFbm(X, Y, s) { return spNoise(X, Y, s) * .5 + spNoise(X * 2.03, Y * 2.03, s + 1) * .26 + spNoise(X * 4.1, Y * 4.1, s + 2) * .15 + spNoise(X * 8.3, Y * 8.3, s + 3) * .09; }
const BAYER4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
const hexRGB = h => { const n = parseInt(h.slice(1), 16); return [n >> 16, (n >> 8) & 255, n & 255]; };
function spBg(gold) {
  const key = gold ? 'g' : 'n'; if (SP_BG[key]) return SP_BG[key];
  const w = 360, h = 210, c = document.createElement('canvas'); c.width = w; c.height = h; const g = c.getContext('2d'), im = g.createImageData(w, h), d = im.data;
  const top = hexRGB(gold ? '#07040c' : '#03041a'), bot = hexRGB(gold ? '#1e0a10' : '#0e0a30');
  const rA = (gold ? ['#2a0c18', '#46121c', '#6e2220', '#9a4020', '#d27a30'] : ['#160e3a', '#26135a', '#3a186c', '#55227e', '#843a94']).map(hexRGB);
  const rB = (gold ? ['#1c0c28', '#2e143e', '#45194e', '#5f2458'] : ['#0b2044', '#11385c', '#1a5470', '#2a7c8c', '#58b2b0']).map(hexRGB);
  const lA = gold ? [0, h * .2, w, h * .75] : [w * .05, h * .95, w, h * .05], lenA = Math.hypot(lA[2] - lA[0], lA[3] - lA[1]);
  const bB = gold ? [w * .78, h * .2, h * .55] : [w * .8, h * .26, h * .5];
  for (let y = 0; y < h; y++) for (let X = 0; X < w; X++) {
    const i = (y * w + X) * 4, ty = y / h, th = BAYER4[(y & 3) * 4 + (X & 3)] / 16;
    let col = [lerp(top[0], bot[0], ty), lerp(top[1], bot[1], ty), lerp(top[2], bot[2], ty)];
    const dist = abs((X - lA[0]) * (lA[3] - lA[1]) - (y - lA[1]) * (lA[2] - lA[0])) / lenA, mA = Math.exp(-((dist / (h * .26)) ** 2));
    const vA = mA * (spFbm(X / 46, y / 46, gold ? 31 : 11) * 1.75 - .42), lvA = Math.floor(vA * rA.length + th) - 1;
    if (lvA >= 0) col = rA[Math.min(lvA, rA.length - 1)];
    const mB = Math.exp(-(((X - bB[0]) ** 2 + (y - bB[1]) ** 2) / (bB[2] ** 2))), vB = mB * (spFbm(X / 34 + 50, y / 34, gold ? 41 : 23) * 1.9 - .5), lvB = Math.floor(vB * rB.length + th) - 1;
    if (lvB >= 0) col = rB[Math.min(lvB, rB.length - 1)];
    d[i] = col[0]; d[i + 1] = col[1]; d[i + 2] = col[2]; d[i + 3] = 255;
  }
  g.putImageData(im, 0, 0);
  const r = SR(gold ? 77 : 55), old = x; x = g;
  try {
    for (let i = 0; i < 300; i++) { const X = r() * w | 0, Y = r() * h | 0, b = r(); x.globalAlpha = .25 + b * .75; R(X, Y, 1, 1, ['#ffffff', '#cfe0ff', '#ffe9c0', '#ffd0d8'][r() * 4 | 0]); }
    x.globalAlpha = 1;
    for (let i = 0; i < 14; i++) { const X = r() * w | 0, Y = r() * h | 0, col = ['#ffffff', '#d8e6ff', '#fff0c8'][i % 3]; x.globalAlpha = .35; R(X - 1, Y, 3, 1, col); R(X, Y - 1, 1, 3, col); x.globalAlpha = 1; R(X, Y, 1, 1, col); }
    for (const [gx, gy, gr, ga] of gold ? [[300, 150, 9, .5], [40, 30, 6, -.4]] : [[250, 36, 11, .45], [320, 160, 7, -.6], [130, 18, 5, .2]]) {   // далёкие спиральные галактики
      x.save(); x.translate(gx, gy); x.rotate(ga); x.globalAlpha = .22; E(0, 0, gr, gr * .32, gold ? '#e0a070' : '#b0a8ff', null); x.globalAlpha = .3; for (let a = 0; a < 2; a++) { x.rotate(PI); path(() => { x.moveTo(-gr * .1, 0); x.quadraticCurveTo(gr * .5, -gr * .45, gr * 1.05, -gr * .05); }, null, gold ? '#ffc890' : '#d8d0ff', 1); }
      x.globalAlpha = .7; E(0, 0, gr * .3, gr * .14, '#fff4dc', null); x.restore();
    }
    if (!gold) {                                                // окольцованная планета слева вверху и спутник
      const px = 44, py = 40, pr = 27;
      x.save(); x.translate(px, py); x.rotate(-.32);
      path(() => xe(0, 0, pr * 1.85, pr * .42, 0, PI, TAU), null, '#7a6a58', 3.2); path(() => xe(0, 0, pr * 1.85, pr * .42, 0, PI, TAU), null, '#d8c08e', 1.4);
      x.restore();
      x.save(); x.beginPath(); x.arc(px, py, pr, 0, TAU); x.clip();
      R(px - pr, py - pr, pr * 2, pr * 2, '#3f8f86');
      for (let i = -6; i < 7; i++) { const yy = py + i * pr / 6.5; R(px - pr, yy, pr * 2, pr / 13 * (1 + (i * 7 & 3) * .6), ['#5aae96', '#2f756e', '#78c2a2', '#346f80'][(i + 8) % 4]); }
      E(px - 8, py + 8, 5, 3, '#c26a4a', null);
      E(px + pr * .55, py + pr * .5, pr * 1.25, pr * 1.25, 'rgba(6,10,30,.72)', null); E(px + pr * .35, py + pr * .3, pr * 1.15, pr * 1.15, 'rgba(6,10,30,.3)', null);
      x.restore();
      path(() => x.arc(px, py, pr - .5, PI * .9, PI * 1.75), null, 'rgba(190,255,240,.55)', 1);
      x.save(); x.translate(px, py); x.rotate(-.32); path(() => xe(0, 0, pr * 1.85, pr * .42, 0, 0, PI), null, '#5a4c40', 3.2); path(() => xe(0, 0, pr * 1.85, pr * .42, 0, .2, PI - .2), null, '#e8d4a4', 1.4); x.restore();
      E(102, 22, 6, 6, '#a8a4b4', null); E(100, 20, 1.6, 1.4, '#86829a', null); E(104, 24, 1.2, 1, '#86829a', null); path(() => x.arc(102, 22, 6, -.6, 2.2), null, 'rgba(10,10,30,.55)', 2.2);
    }
  } finally { x = old; x.globalAlpha = 1; }
  return SP_BG[key] = c;
}
// мерцающие звёзды поверх фона (средний слой параллакса)
const SP_STARS = (() => { const r = SR(91), a = []; for (let i = 0; i < 48; i++) a.push([r() * 700, r() * 250, r() * TAU, .03 + r() * .07, r() < .3 ? 2 : 1, ['#ffffff', '#cfe0ff', '#ffe9c0'][r() * 3 | 0]]); return a; })();
function spTwinkle(ox, gold) {
  for (const [sx, sy, ph, sp, sz, col] of SP_STARS) {
    const b = .5 + .5 * sin(T * sp + ph); if (b < .2) continue;
    const X = Math.round((((sx - ox) % 700) + 700) % 700 / 2) * 2 - 30, Y = Math.round(sy / 2) * 2, c = gold && col === '#cfe0ff' ? '#ffe0b0' : col;
    x.globalAlpha = b; R(X, Y, 2, 2, c); if (sz > 1 && b > .72) { x.globalAlpha = (b - .7) * 2.4; R(X - 4, Y, 10, 2, c); R(X, Y - 4, 2, 10, c); }
  }
  x.globalAlpha = 1;
}
// «пыль»: точки летят из точки схода (прилёт) или в неё (побег); D — пройденный путь
function spDust(vx, vy, D, dir, col, n = 64) {
  const r = SR(17); x.lineCap = 'butt';
  for (let i = 0; i < n; i++) {
    const a = r() * TAU, rr = .35 + r() * .65, z0 = r(), fr = (((z0 + D * dir) % 1) + 1) % 1, z = .05 + (dir > 0 ? 1 - fr : fr) * .95, z2 = Math.min(1.05, z + .035);
    const u = cos(a) * rr * 30, v = sin(a) * rr * 22, X1 = vx + u / z, Y1 = vy + v / z, X2 = vx + u / z2, Y2 = vy + v / z2;
    if (X1 < -10 || X1 > W + 10 || Y1 < -10 || Y1 > H + 10) continue;
    x.globalAlpha = Math.min(.55, (1 - z) * .7); LN(X2, Y2, X1, Y1, col, z < .2 ? 2 : 1.4);
  }
  x.globalAlpha = 1;
}
// маленький корабль Рика (трафик вокруг Цитадели): S — ширина в лог. пикселях, (vx,vy) — направление полёта
function spMini(X, Y, S, vx, vy, gold, i = 0) {
  S = Math.max(5, S); const m = Math.hypot(vx, vy) || 1;
  LN(X - vx / m * S * .4, Y - vy / m * S * .4 + S * .08, X - vx / m * S * 1.6, Y - vy / m * S * 1.6 + S * .08, gold ? 'rgba(255,170,90,.55)' : 'rgba(130,255,150,.5)', Math.max(1.5, S * .2));
  E(X, Y, S / 2, S * .2, '#b8c0c8', '#141828', Math.max(.6, S * .06)); E(X, Y + S * .06, S * .44, S * .09, '#7c848e', null);
  E(X, Y - S * .14, S * .2, S * .16, gold ? '#ffd890' : '#9fe0ff', null);
  if (((T / 9 + i) | 0) % 2) R(X - S * .5, Y - 1, 2, 2, '#ff5a5a');
}
// Центральная Конечная Кривая: огромная дуга через небо, проходящая через точку (X,Y) под углом ang
function spCurve(X, Y, ang, a, rad = 1500) {
  const cx = X + sin(ang) * rad, cy = Y - cos(ang) * rad, a0 = Math.atan2(Y - cy, X - cx);
  x.save(); x.globalCompositeOperation = 'lighter';
  path(() => x.arc(cx, cy, rad, a0 - .5, a0 + .5), null, 'rgba(255,200,110,' + (.12 * a) + ')', 9);
  path(() => x.arc(cx, cy, rad, a0 - .5, a0 + .5), null, 'rgba(255,220,150,' + (.28 * a) + ')', 4);
  path(() => x.arc(cx, cy, rad, a0 - .5, a0 + .5), null, 'rgba(255,245,210,' + (.3 * a) + ')', 1.2);   // мягкая светящаяся полоса, а не «царапина»
  x.restore();
}
// разрыв в Кривой: золотая «линза» с лучами, вихрем и затягиваемыми искрами
function spRift(X, Y, sc, k, ang) {
  const op = .55 + .45 * sst(0, 220, k) + sin(T / 9) * .03;
  x.save(); x.globalCompositeOperation = 'lighter';
  x.fillStyle = rgrad(X, Y, 0, 360 * sc, [[0, 'rgba(255,236,170,.6)'], [.2, 'rgba(255,200,90,.38)'], [.55, 'rgba(210,110,40,.14)'], [1, 'rgba(120,40,20,0)']]); x.fillRect(0, 0, W, H);
  for (let i = 0; i < 16; i++) { const a = i / 16 * TAU + k * .0016 * (i % 2 ? 1 : -1) + i, L = (230 + 70 * sin(i * 1.7 + T / 30)) * sc, da = .045 + (i % 3) * .02; PG([X, Y, X + cos(a - da) * L, Y + sin(a - da) * L, X + cos(a + da) * L, Y + sin(a + da) * L], 'rgba(255,214,130,' + (.07 + (i % 4) * .015) + ')', null); }
  x.restore();
  x.save(); x.translate(X, Y); x.rotate(ang);
  const hw = 26 * sc * op, hh = 92 * sc * (.75 + .25 * op);
  const lens = (k2, col) => { const j = sin(T / 5 + k2 * 9) * 1.5; path(() => { x.moveTo(0, -hh * k2); x.quadraticCurveTo(hw * 2.1 * k2 + j, 0, 0, hh * k2); x.quadraticCurveTo(-hw * 2.1 * k2 - j, 0, 0, -hh * k2); }, col, null); };
  lens(1.12, 'rgba(160,50,20,.55)'); lens(1, '#c8501e'); lens(.86, '#f08a2a'); lens(.7, '#ffc04a'); lens(.52, '#ffe8a0'); lens(.3, '#fffbe8');
  x.globalCompositeOperation = 'lighter';
  for (let i = 0; i < 6; i++) { const a = T / 22 + i * 1.05, rr = hw * (.5 + (i % 3) * .3); path(() => xe(0, 0, rr, hh * (.4 + (i % 3) * .18), 0, a, a + 1.6), null, 'rgba(255,240,190,.35)', 1.6); }
  x.restore();
  const r = SR(33);
  for (let i = 0; i < 46; i++) { const a0 = r() * TAU, sp = .006 + r() * .01, fr = ((k * sp * .4 + r()) % 1), rr = (1 - fr) * (170 + r() * 160) * sc, a = a0 + fr * 3.2; x.globalAlpha = .4 + fr * .6; R(Math.round((X + cos(a) * rr) / 2) * 2, Math.round((Y + sin(a) * rr * .8) / 2) * 2, 2, 2, fr > .7 ? '#fff4c8' : '#ffb84a'); }
  x.globalAlpha = 1;
}
function spGlow(X, Y, r, rgb, a) { x.save(); x.globalCompositeOperation = 'lighter'; x.fillStyle = rgrad(X, Y, 0, r, [[0, 'rgba(' + rgb + ',' + a + ')'], [.45, 'rgba(' + rgb + ',' + (a * .35) + ')'], [1, 'rgba(' + rgb + ',0)']]); x.fillRect(X - r, Y - r, r * 2, r * 2); x.restore(); }
function spVignette(a) { x.fillStyle = rgrad(W / 2, H * .42, H * .4, W * .62, [[0, 'rgba(0,0,0,0)'], [1, 'rgba(0,0,8,' + a + ')']]); x.fillRect(0, 0, W, H); }
// взрыв в экранных координатах: R — радиус, a — возраст в кадрах
function spBoom(X, Y, Rr, a, seed) {
  const r = SR(seed * 7 + 3), L = 48, e = a / L; if (e >= 1) return;
  if (a < 5) { spGlow(X, Y, Rr * 4, '255,230,170', .7 * (1 - a / 5)); E(X, Y, Rr * (.5 + a * .16), Rr * (.5 + a * .16), '#fffbe8', null); for (let i = 0; i < 4; i++) { const an = i * PI / 2 + seed; LN(X + cos(an) * Rr * .6, Y + sin(an) * Rr * .6, X + cos(an) * Rr * (1.6 + a * .3), Y + sin(an) * Rr * (1.6 + a * .3), '#fff4c8', Math.max(1.5, Rr * .16)); } return; }
  for (let i = 0; i < 5; i++) { const an = r() * TAU, d = Rr * (.3 + e * 1.3) * r(), rr = Rr * (.35 + e * .95) * (.6 + r() * .5); if (a > 9) { x.globalAlpha = .8 * (1 - e); E(X + cos(an) * d, Y + sin(an) * d - e * Rr * .5, rr, rr, i % 2 ? '#3a2830' : '#4e3638', null); } }
  x.globalAlpha = 1;
  const fb = Rr * (a < 12 ? .75 + a / 28 : Math.max(0, 1.18 - (a - 12) / 30)), c0 = a < 14 ? '#ff9a3a' : a < 24 ? '#e0582a' : '#9a3020', c1 = a < 14 ? '#ffe9a0' : a < 24 ? '#ffb04a' : '#e0682a', c2 = a < 12 ? '#fffbe8' : '#ffe39a';
  if (fb > .5) { for (let i = 0; i < 4; i++) { const an = r() * TAU, d = Rr * .4 * r(), rr = fb * (.55 + r() * .4); E(X + cos(an) * d, Y + sin(an) * d, rr, rr * .92, i < 2 ? c0 : c1, null); } if (a < 26) E(X, Y, fb * .42, fb * .4, c2, null); }
  for (let i = 0; i < 8; i++) { const an = r() * TAU, d = Rr * (.6 + e * 2.8) * (.6 + r() * .6); if (e < .6) R(Math.round((X + cos(an) * d) / 2) * 2, Math.round((Y + sin(an) * d) / 2) * 2, 2, 2, i % 2 ? '#ffe9a0' : '#ff8a3a'); }
}
// пламя (мерцает) — экранные координаты
function spFire(X, Y, s, ph) { const f1 = sin(T / 3 + ph) * .25 + 1, f2 = sin(T / 4.3 + ph * 2) * .2 + 1; E(X, Y - s * .3 * f1, s * .7, s * .9 * f1, 'rgba(230,80,30,.9)', null); E(X - s * .1, Y - s * .25 * f2, s * .45, s * .6 * f2, '#ffa040', null); E(X, Y - s * .1, s * .22, s * .3, '#fff0b0', null); }

/* ---------- ПРИЛЁТ ---------- */
function drawArrival(k, crew) {
  const o = typeof FADE !== 'undefined' && FADE.to === 1 && typeof S !== 'undefined' && S === 'scene' ? cl(FADE.a, 0, 1) : 0;   // затемнение уже идёт — ныряем
  const a = sst(0, 300, k), dv = sst(285, SPACE_LEN.in, k), hold = k > SPACE_LEN.in ? 1 - Math.exp(-(k - SPACE_LEN.in) / 420) : 0;
  const s = .2 * Math.pow(.62 / .2, Math.min(k, 300) / 300) * Math.pow(3.05 / .62, dv) * (1 + .2 * hold) * (1 + 4 * o * o);
  const Fy = lerp(lerp(26, -18, a), 6, dv), Ax = lerp(lerp(450, 420, a), 410, dv) + sin(k / 140) * 4 * (1 - dv), Ay = lerp(lerp(116, 130, a), 148, dv) + sin(k / 110) * 3;
  const P = (mx, my) => [Ax + s * mx, Ay + s * (my - Fy)];
  // фон и звёзды (медленный параллакс), дальняя Кривая, пыль навстречу
  const bo = 24 + 46 * (1 - Math.exp(-k / 700));
  x.drawImage(spBg(0), -Math.round(bo / 2) * 2, -Math.round((26 - bo * .25) / 2) * 2, 720, 420);
  spTwinkle(bo * 1.8, 0);
  spCurve(560, 40, -.35, .55);
  const D = .0034 * k + .03 * sst(260, 460, k) * (k - 260) / 200 + .004 * Math.max(0, k - 460) * .5 + o * .2;
  const [vx, vy] = P(0, -10); spDust(vx, vy, D, 1, 'rgba(210,225,255,1)', 60 + (dv * 30 | 0));
  // ореол и трафик позади
  const C = citBuildN.c || (citBuildN.c = citBuildN());
  spGlow(...P(0, 0), 330 * s, '110,170,255', .32);
  const traffic = front => {
    for (let i = 0; i < 12; i++) { const r = SR(300 + i), Rx = 225 + r() * 95, Ry = 24 + r() * 40, y0 = -170 + r() * 230, w = (r() < .5 ? -1 : 1) * (.004 + r() * .005), an = r() * TAU + k * w; if ((sin(an) > 0) !== front) continue; const [X, Y] = P(Rx * cos(an), y0 + Ry * sin(an)); spMini(X, Y, 11 * s, -sin(an) * w * Rx, cos(an) * w * Ry, 0, i); }
    if (!front) return;
    [.24, .41, .59, .76].forEach((b, i) => { const r = SR(400 + i), per = 200 + r() * 90, t = ((k + r() * per) % per) / per, th = b * PI, dx = cos(th) * .9 + (r() - .5) * .4, dy = .35 + r() * .3, d = Math.pow(t, 1.5) * 300; const [X, Y] = P(200 * cos(th) + dx * d, 14 + 36 * sin(th) + dy * d); spMini(X, Y, 11 * s * (1 + t * 1.5), dx, dy, 0, i); });
    for (let i = 0; i < 3; i++) { const per = 130, t = ((k + i * 47) % per) / per, sd = i % 2 ? 1 : -1, mx = lerp(sd * 150, 0, t), my = lerp(-70 - i * 30, -14, t * t); const [X, Y] = P(mx, my); x.globalAlpha = Math.min(1, (1 - t) * 4); spMini(X, Y, 10 * s * (1 - t * .7), -sd, .4 + t, 0, i); x.globalAlpha = 1; }
  };
  traffic(false);
  // сама Цитадель
  x.save(); x.translate(Ax, Ay); x.scale(s, s); x.translate(0, -Fy); spDraw(C);
  const bs = Math.max(1.6, 2.2 / s);
  C.bc.forEach(([bx, by], i) => { if (sin(T * .07 + i * 1.9) > .45) R(bx - bs / 2, by - bs / 2, bs, bs, i % 3 ? '#ff5a5a' : '#9dff6a'); });
  // доки и ворота светятся
  [.24, .41, .59, .76].forEach((b, i) => { const th = b * PI; x.globalAlpha = .5 + .3 * sin(T / 13 + i); E(200 * cos(th), 16.5 + 36 * sin(th), 5 * sin(th) + 1, 2.4, '#d8fff8', null); });
  x.globalAlpha = 1; x.restore();
  const [gx, gy] = P(0, 7), gr = 12.5 * s;
  if (gr > 2) {
    spGlow(gx, gy, gr * 2.4, '120,255,190', .35 + .1 * sin(T / 10));
    x.save(); x.beginPath(); x.arc(gx, gy, gr, 0, TAU); x.clip(); x.globalCompositeOperation = 'lighter';
    x.fillStyle = rgrad(gx, gy, 0, gr, [[0, 'rgba(220,255,230,.9)'], [.5, 'rgba(110,255,160,.45)'], [1, 'rgba(60,200,140,.15)']]); x.fillRect(gx - gr, gy - gr, gr * 2, gr * 2);
    for (let i = 0; i < 5; i++) { const an = T / 14 + i * 1.26, rr = gr * (.35 + i * .13); path(() => x.arc(gx, gy, rr, an, an + 2.2), null, 'rgba(200,255,210,.55)', Math.max(1.5, gr * .07)); }
    x.restore();
  }
  traffic(true);
  // корабли Риков проносятся рядом (глубина), затем один улетает к Цитадели впереди нас
  if (k > 70 && k < 230) { const t = (k - 70) / 160; ship(lerp(760, -140, t), lerp(54, 86, t) + 30, { fly: 1, lift: 30, sc: .42 }); }
  if (k > 200 && k < 380) { const t = (k - 200) / 180, [tx2, ty2] = P(-60, -40); ship(lerp(40, tx2, t * t), lerp(120, ty2, t) + 30, { fly: 1, lift: 30, sc: .5 * (1 - t) + .03 }); }
  // наш корабль: слегка к городу во время пике, при затемнении — уходит в ворота
  let X = 172 + 40 * dv + sin(k / 60) * 6, Y = 190 + sin(k / 47) * 6 - 10 * dv, sc = .8;
  if (o > 0) { X = lerp(X, gx, o * .8); Y = lerp(Y, gy + 10, o * .8); sc *= 1 - o * .75; }
  ship(X, Y + 30, { fly: 1, lift: 30, sc, crew });
  spVignette(.35);
}

/* ---------- ПОБЕГ: Цитадель разваливается на фоне золотого разрыва в Кривой ---------- */
function citPieceXf(pc, k) {
  const t = Math.max(0, k - pc.brk), e = 1 - Math.exp(-t / 260), d = 260 * e + t * .12;
  return { dx: pc.v[0] * d, dy: pc.v[1] * d, a: pc.w * (300 * (1 - Math.exp(-t / 300)) + t * .15) + (k < pc.brk ? sin(k * .9 + pc.brk) * .006 * sst(pc.brk - 90, pc.brk, k) : 0) };
}
function citPieceApply(pc, f_, X, Y) { const c = cos(f_.a), s_ = sin(f_.a), u = X - pc.pv[0], v = Y - pc.pv[1]; return [pc.pv[0] + f_.dx + u * c - v * s_, pc.pv[1] + f_.dy + u * s_ + v * c]; }
// золотая Цитадель в момент k: куски корпуса, подвесные шпили, башни (отрываются и кувыркаются), трещины, пожары и взрывы
function citDrawG(k, cx, cy, s) {
  const G = CIT_G || (CIT_G = citBuildG()), geo = citGeo(), xf = geo.pieces.map(pc => citPieceXf(pc, k));
  const scr = (X, Y) => [cx + X * s, cy + Y * s];
  const inP = (i, fn) => { const pc = geo.pieces[i], f_ = xf[i]; x.save(); x.translate(pc.pv[0] + f_.dx, pc.pv[1] + f_.dy); x.rotate(f_.a); x.translate(-pc.pv[0], -pc.pv[1]); fn(); x.restore(); };
  // где окажется оторванная деталь (башня/шпиль): позиция в момент отрыва + полёт
  const flyXf = (d, age) => { const pc = geo.pieces[d.pc], f0 = citPieceXf(pc, d.brk), [bx, by] = citPieceApply(pc, f0, d.x, d.y), m = 200 * (1 - Math.exp(-age / 200)) + age * .3; return { X: bx + d.v[0] * m, Y: by + d.v[1] * m, a: f0.a + d.av * age }; };
  const fires = [], smokes = [];
  x.save(); x.translate(cx, cy); x.scale(s, s);
  for (const i of [4, 0, 3, 1, 2]) inP(i, () => { const pl = geo.pieces[i].poly; x.save(); x.beginPath(); x.moveTo(pl[0][0], pl[0][1]); for (const q of pl) x.lineTo(q[0], q[1]); x.closePath(); x.clip(); spDraw(G.body); x.restore(); });
  // трещины: сначала тлеют, в момент раскола вспыхивают, потом остаются раскалёнными краями
  x.save(); x.globalCompositeOperation = 'lighter'; x.lineJoin = 'round'; x.lineCap = 'round';
  for (const c of geo.cracks) {
    const pre = sst(c.brk - 110, c.brk, k), post = k > c.brk ? .45 + .55 * Math.exp(-(k - c.brk) / 70) : pre, g = post * (.85 + .15 * sin(T / 4 + c.brk));
    if (g < .02) continue;
    for (const side of [c.a, c.b]) inP(side, () => { for (const sg of c.segs) { const ln = (col, lw) => { x.beginPath(); sg.forEach((q, j) => j ? x.lineTo(q[0], q[1]) : x.moveTo(q[0], q[1])); x.strokeStyle = col; x.lineWidth = lw; x.stroke(); }; ln('rgba(255,140,50,' + (.3 * g) + ')', Math.max(7, 9 / s)); ln('rgba(255,210,110,' + (.7 * g) + ')', Math.max(2.4, 3.2 / s)); ln('rgba(255,250,220,' + g + ')', Math.max(1, 1.6 / s)); } });
    if (k > c.brk) for (const sg of c.segs) for (let j = 2; j < sg.length; j += 7) fires.push([c.a, sg[j][0], sg[j][1], j + c.brk]);
  }
  x.restore();
  // подвесные шпили и башни (по глубине)
  const part = (d, sp) => {
    if (d.det && k > d.brk) { const age = k - d.brk, f_ = flyXf(d, age); x.save(); x.translate(f_.X, f_.Y); x.rotate(f_.a); x.translate(-d.x, -d.y); spDraw(sp); x.restore(); smokes.push([f_.X, f_.Y, age, d.seed]); if (d.seed % 2) fires.push([-1, f_.X, f_.Y, d.seed]); }
    else inP(d.pc, () => spDraw(sp));
  };
  for (const h of G.hs) part(h.s, h.sp);
  for (const t of G.tw) part(t.t, t.sp);
  x.restore();
  // огонь на изломах и местах отрыва
  for (const t of geo.tw) if (t.det && k > t.brk && t.seed % 3 === 0) fires.push([t.pc, t.x, t.y - 2, t.seed]);
  const fs = Math.max(3, 7 * s);
  for (const [pi, X, Y, ph] of fires) { const [px, py] = pi < 0 ? [X, Y] : citPieceApply(geo.pieces[pi], xf[pi], X, Y), [sx, sy] = scr(px, py); spFire(sx, sy, fs * (.7 + (ph % 5) * .12), ph); }
  // дымные хвосты за летящими обломками
  for (const [X, Y, age, sd] of smokes) for (let j = 1; j < 4; j++) { const [sx, sy] = scr(X, Y), aa = Math.max(0, .5 - j * .12) * Math.min(1, age / 20); if (aa <= 0) continue; x.globalAlpha = aa; E(sx - j * 5 * s - j * 2, sy + j * 3 * s, (3 + j * 2.4) * Math.max(.6, s), (3 + j * 2.4) * Math.max(.6, s), '#3a2a32', null); }
  x.globalAlpha = 1;
  // взрывы: события (отрыв, раскол) + постоянный «фон» мелких взрывов
  let flash = 0;
  for (const ev of geo.ev) { const a = k - ev.t; if (a < 0) break; if (a > 50) continue; const [px, py] = citPieceApply(geo.pieces[ev.pc], xf[ev.pc], ev.X, ev.Y), [sx, sy] = scr(px, py); spBoom(sx, sy, Math.max(4, ev.R * s * (ev.big ? 1.8 : 1)), a, (ev.t * 13 | 0)); if (ev.big) flash = Math.max(flash, 1 - a / 22); }
  const per = 6, dens = k < 420 ? .85 : .5;
  for (let j = Math.max(0, Math.floor((k - 50) / per)); j <= k / per; j++) {
    const q = SR(j * 13 + 5), t0 = j * per + q() * per, a = k - t0, use = q() < dens, X = (q() - .5) * 380, Y = -34 + q() * 96, tw = geo.tw[q() * geo.tw.length | 0], th = q();
    if (a < 0 || a >= 48 || !use) continue;
    let px, py;
    if (j % 3 === 0 && !(tw.det && k > tw.brk)) [px, py] = citPieceApply(geo.pieces[tw.pc], xf[tw.pc], tw.x, tw.y - tw.h * th);
    else { if (!geo.inBody(X, Y)) continue; const pi = geo.pieceOf(X, Y); [px, py] = citPieceApply(geo.pieces[pi], xf[pi], X, Y); }
    const [sx, sy] = scr(px, py); spBoom(sx, sy, Math.max(3.5, (6 + th * 9) * s), a, j);
  }
  return flash;
}
// обломки, летящие на камеру (из точки (cx,cy))
function spDebris(k, cx, cy, near, avoid) {
  for (let j = Math.max(0, Math.floor((k - 95) / 9)); j <= k / 9; j++) {
    const r = SR(j * 11 + 1), t0 = j * 9 + r() * 7, a = k - t0, L = 80 + r() * 30; if (a < 0 || a > L) continue;
    const z = 1 - a / L * .94, an = r() * TAU, d0 = 12 + r() * 40, X = cx + cos(an) * d0 / z, Y = cy + sin(an) * d0 * .8 / z, sz = (1.4 + r() * 2.6) / z, rot = r() * TAU + a * (r() - .5) * .2, burn = r() < .35, n = 4 + (r() * 3 | 0);
    if ((z < .32) !== near) continue;
    if (near && avoid && X > avoid[0] && X < avoid[2] && Y > avoid[1] && Y < avoid[3]) continue;
    if (X < -60 || X > W + 60 || Y < -60 || Y > H + 60) continue;
    if (burn) for (let i = 1; i < 4; i++) { const z2 = Math.min(1, z + i * .05); x.globalAlpha = .35 - i * .08; E(cx + cos(an) * d0 / z2, cy + sin(an) * d0 * .8 / z2, sz * (.5 + i * .25), sz * (.5 + i * .25), '#3a2a30', null); }
    x.globalAlpha = 1;
    const pts = []; for (let i = 0; i < n; i++) { const aa = rot + i / n * TAU, rr = sz * (.6 + r() * .5); pts.push(X + cos(aa) * rr, Y + sin(aa) * rr); }
    PG(pts, '#6e6068', '#140c16', Math.max(.8, sz * .12)); PG(pts.slice(0, 6).concat([X, Y]), '#a08a80', null);
    if (sz > 6) R(X - sz * .15, Y - sz * .15, sz * .3, sz * .2, '#ffd47a');
    if (burn) spFire(X, Y, sz * .6, j);
  }
}
function drawEscape(k, crew) {
  const o = typeof FADE !== 'undefined' && FADE.to === 1 && typeof S !== 'undefined' && S === 'scene' ? cl(FADE.a, 0, 1) : 0;   // затемнение — корабль уносится
  const e = 1 - Math.exp(-k / 320), s = .44 + .5 * Math.exp(-k / 230), cx = lerp(236, 214, e), cy = lerp(146, 118, e);
  x.drawImage(spBg(1), -Math.round((20 + k * .02 % 60) / 2) * 2, -20, 720, 420);
  spTwinkle(k * .3, 1);
  const rx = cx - 34 * s - 6, ry = cy - 80 * s - 4;
  spCurve(rx, ry, .5, 1.2); spRift(rx, ry, .65 + s * .5, k, .5);
  spDust(cx, cy - 20, .003 * k + o * .15, -1, 'rgba(255,214,150,1)', 46);
  const flash = citDrawG(k, cx, cy, s);
  const shake = 1.2 + flash * 4 + o * 2, sx = sin(k * 1.7) * shake + sin(k * 3.1) * shake * .5, sy = cos(k * 2.3) * shake * .8;
  const shX = 470 + sin(k / 70) * 10 + sx + o * 60, shY = 186 + sin(k / 41) * 5 + sy + o * 30, sc = .8 + o * .55;
  spDebris(k, cx, cy, false);
  ship(shX, shY + 30, { fly: 1, lift: 30, sc, crew });
  spDebris(k, cx, cy, true, [shX - 100 * sc, shY - 90 * sc, shX + 100 * sc, shY + 20 * sc]);
  if (flash > 0) { x.save(); x.globalCompositeOperation = 'lighter'; x.fillStyle = 'rgba(255,220,150,' + (flash * .45) + ')'; x.fillRect(0, 0, W, H); x.restore(); }
  spVignette(.45);
}
function drawSpaceScene(k, back, crew) { x.save(); if (back) drawEscape(k, crew); else drawArrival(k, crew); x.restore(); }
// совместимость: Цитадель целиком в точке (cx,cy); s=1 — ширина диска ≈200 лог. пикселей; o.gold/o.broken — золотая/разваливающаяся
function drawCitadel(cx, cy, s, o = {}) {
  if (o.gold || o.broken) { if (o.gold) spGlow(cx, cy, 160 * s, '255,200,90', .5); citDrawG(o.broken ? o.broken * 400 : -999, cx, cy, s * .5); return; }
  const C = citBuildN.c || (citBuildN.c = citBuildN()); x.save(); x.translate(cx, cy); x.scale(s * .5, s * .5); spDraw(C); x.restore();
}

/* ---------- силуэт города Цитадели для окон/фонов локаций ----------
   citadelSkyline(X,Y,w,h,o): прямоугольник [X,Y,w,h] в координатах фона; o.gold — золотое сияние разрыва (побег), o.alarm — красная тревога.
   Статичная часть рисуется один раз в холст разрешения арта (кэш по размеру и флагам), поверх — живые огни, кораблики, тревога/сияние. */
const SKY_CACHE = {};
function skyBuild(w, h, o) {
  const cw = Math.ceil(w / 2), ch = Math.ceil(h / 2), c = document.createElement('canvas'); c.width = cw; c.height = ch;
  const r = SR(cw * 7 + ch * 131 + (o.gold ? 3 : 0) + (o.alarm ? 5 : 0)), bc = [], old = x; x = c.getContext('2d');
  const gold = !!o.gold, alarm = !!o.alarm, U = ch / 60;
  const pal = gold ? { hi: '#ffd47a', l: '#6e5260', m: '#4c3a4c', d: '#38283c', dd: '#26192c', far: '#4a2a30', farW: '#a8582a' } : { hi: '#c8d4ec', l: '#8693b8', m: '#5e6a94', d: '#424b76', dd: '#2c3358', far: '#232a5a', farW: '#5a68a8' };
  const wins = alarm ? ['#ff4a4a', '#ff7a5a', '#ff3030'] : gold ? ['#ffb04a', '#ff8a3a', '#ffd56b'] : ['#ffe39a', '#ffd06a', '#fff2c8', '#9feaff'];
  try {
    R(0, 0, cw, ch, grad(0, 0, 0, ch, gold ? [[0, '#160810'], [.4, '#4a1e1a'], [.75, '#a85a1e'], [1, '#e89a3c']] : [[0, '#03051a'], [.5, '#0e1140'], [1, '#2a2c6e']]));
    x.globalAlpha = .18; for (let i = 0; i < 3; i++) E(r() * cw, ch * (.15 + r() * .4), ch * (1 + r()), ch * (.25 + r() * .2), gold ? '#ff8a3a' : ['#6a2a8a', '#1e6a8a', '#4a2a7a'][i], null); x.globalAlpha = 1;
    for (let i = 0; i < cw * ch / 40; i++) { x.globalAlpha = .3 + r() * .7; R(r() * cw | 0, r() * ch * .8 | 0, 1, 1, gold ? '#ffe8c0' : ['#ffffff', '#cfe0ff', '#ffe9c0'][i % 3]); } x.globalAlpha = 1;
    // Кривая — тонкая светящаяся дуга; при побеге — разрыв с огромным сиянием
    const Rr = cw * 1.4 + 160, ccx = cw * .55, ccy = ch * .28 + Rr;
    x.save(); x.globalCompositeOperation = 'lighter';
    if (gold) { x.fillStyle = rgrad(cw * .5, ch * .25, 0, ch * 1.6, [[0, 'rgba(255,240,180,.9)'], [.25, 'rgba(255,200,90,.5)'], [1, 'rgba(255,140,40,0)']]); x.fillRect(0, 0, cw, ch); }
    path(() => x.arc(ccx, ccy, Rr, -PI / 2 - 1.2, -PI / 2 + 1.2), null, gold ? 'rgba(255,220,140,.5)' : 'rgba(255,215,140,.18)', gold ? 4 : 3);
    path(() => x.arc(ccx, ccy, Rr, -PI / 2 - 1.2, -PI / 2 + 1.2), null, gold ? '#fff4d0' : 'rgba(255,240,200,.65)', 1);
    x.restore();
    if (gold) { x.save(); x.translate(cw * .5, ch * .25); for (const [kk, col] of [[1, '#e07a2a'], [.7, '#ffc04a'], [.45, '#fff0b0'], [.22, '#ffffff']]) path(() => { x.moveTo(0, -ch * .3 * kk); x.quadraticCurveTo(ch * .16 * kk, 0, 0, ch * .3 * kk); x.quadraticCurveTo(-ch * .16 * kk, 0, 0, -ch * .3 * kk); }, col, null); x.restore(); }
    // дальний слой: дымка, тонкие силуэты с редкими огнями
    const hz = Math.round(ch * .86);
    R(0, hz, cw, ch - hz, pal.far);
    for (let X = -3; X < cw + 3;) { const w2 = Math.max(2, Math.round((3 + r() * 4) * U)), h2 = Math.round(ch * (.16 + r() * .36)); R(X, ch - h2, w2, h2, pal.far); if (r() < .4) R(X + (w2 >> 1), ch - h2 - Math.round(3 * U), 1, Math.round(3 * U), pal.far); for (let yy = ch - h2 + 2; yy < ch - 2; yy += 3) for (let xx = X + 1; xx < X + w2 - 1; xx += 2) if (r() < .25) R(xx, yy, 1, 1, pal.farW); X += w2 + Math.round(r() * 3 * U); }
    x.fillStyle = grad(0, ch * .5, 0, ch, [[0, 'rgba(0,0,0,0)'], [1, gold ? 'rgba(255,170,80,.25)' : 'rgba(110,130,230,.22)']]); x.fillRect(0, 0, cw, ch);
    // средний слой: цилиндрические башни с куполами, «тарелками», шпилями, окнами и маячками
    const mids = [];
    for (let X = -4; X < cw + 4;) { const w2 = Math.max(4, Math.round((5 + r() * 7) * U)), h2 = Math.round(ch * (.3 + r() * .5)); mids.push([X, w2, h2, r() * 5 | 0, r()]); X += w2 + Math.round((2 + r() * 8) * U); }
    for (const [X, w2, h2, kind, q] of mids) {
      const top = ch - h2, cx2 = X + w2 / 2, rr = SR(X * 31 + h2);
      R(X, top, w2, h2, pal.m); R(X + 1, top, Math.max(1, w2 * .3 | 0), h2, pal.l); R(X, top, 1, h2, gold ? pal.hi : pal.m); R(X + w2 - Math.max(1, w2 * .3 | 0), top, Math.max(1, w2 * .3 | 0), h2, pal.d); R(X + w2 - 1, top, 1, h2, pal.dd);
      for (let yy = top + 3; yy < ch - 1; yy += 3) { const row = rr() < .65; for (let xx = X + 1; xx < X + w2 - 1; xx += 2) if (row && rr() < (alarm ? .45 : gold ? .3 : .6)) R(xx, yy, 1, 1, wins[rr() * wins.length | 0]); }
      if (rr() < .5) { const fy = top + Math.round(h2 * (.2 + rr() * .3)); R(X - 1, fy, w2 + 2, 1, pal.l); R(X - 1, fy + 1, w2 + 2, 1, pal.dd); }
      if (kind === 0) { path(() => xe(cx2, top, w2 / 2, w2 * .45, 0, PI, TAU), pal.l, null); R(Math.round(cx2 - w2 * .25), Math.round(top - w2 * .3), 1, 1, pal.hi); }
      else if (kind === 1) { const pw = Math.round(w2 * .8); E(cx2, top + 1, pw, Math.max(1.2, w2 * .28), pal.m, null); R(Math.round(cx2 - pw), top + 1, pw * 2, 1, pal.l); for (let j = -pw + 1; j < pw; j += 2) R(Math.round(cx2 + j), top + 2, 1, 1, wins[0]); R(Math.round(cx2 - w2 * .15), top - Math.round(w2 * .7), Math.max(1, Math.round(w2 * .3)), Math.round(w2 * .7), pal.l); }
      else if (kind === 2) PG([X, top, X + w2, top, cx2, top - w2 * 1.6], pal.l, null);
      else if (kind === 3) { R(Math.round(X + w2 * .2), top - Math.round(h2 * .14), Math.max(1, Math.round(w2 * .6)), Math.round(h2 * .14), pal.m); R(Math.round(X + w2 * .2), top - Math.round(h2 * .14), 1, Math.round(h2 * .14), pal.l); }
      if (kind === 4 || q < .35) { const al = Math.round((3 + q * 6) * U), ax = Math.round(cx2); R(ax, top - al - (kind === 2 ? Math.round(w2 * 1.6) : kind === 1 ? Math.round(w2 * .7) : 0), 1, al, pal.l); bc.push([ax, top - al - (kind === 2 ? Math.round(w2 * 1.6) : kind === 1 ? Math.round(w2 * .7) : 0)]); }
    }
    // трубы-переходы между башнями
    for (let i = 1; i < mids.length - 1; i++) if (r() < .22) { const a = mids[i], b = mids[i + 1], yy = Math.round(ch * (.55 + r() * .25)); if (ch - a[2] < yy && ch - b[2] < yy) { R(a[0] + a[1], yy, b[0] - a[0] - a[1], 2, pal.l); R(a[0] + a[1], yy + 1, b[0] - a[0] - a[1], 1, pal.d); for (let xx = a[0] + a[1] + 1; xx < b[0]; xx += 3) R(xx, yy, 1, 1, wins[0]); } }
    // ближний слой: редкие большие тёмные башни по краям кадра
    if (cw > ch * 1.4) for (let X = Math.round(r() * ch * .8) - Math.round(ch * .2); X < cw; X += Math.round(ch * (1.8 + r() * 1.8))) {
      const w2 = Math.round(ch * (.16 + r() * .1)), top = Math.round(ch * (.12 + r() * .3));
      R(X, top, w2, ch - top, pal.dd); R(X, top, 1, ch - top, gold ? pal.hi : pal.l); R(X + 1, top, Math.max(1, w2 * .25 | 0), ch - top, pal.d);
      path(() => xe(X + w2 / 2, top, w2 / 2, w2 * .3, 0, PI, TAU), pal.d, null); R(X + 1, top - 1, Math.max(1, w2 * .3 | 0), 1, gold ? pal.hi : pal.l);
      for (let yy = top + 3; yy < ch - 1; yy += 4) for (let xx = X + 2; xx < X + w2 - 1; xx += 3) if (r() < (alarm ? .4 : .5)) R(xx, yy, 2, 1, wins[r() * wins.length | 0]);
      bc.push([X + (w2 >> 1), top - Math.round(w2 * .3)]);
    }
    x.fillStyle = grad(0, ch * .7, 0, ch, [[0, 'rgba(0,0,0,0)'], [1, alarm ? 'rgba(255,40,40,.3)' : gold ? 'rgba(255,190,90,.3)' : 'rgba(120,160,255,.2)']]); x.fillRect(0, 0, cw, ch);
  } catch (e) { console.error(e); } finally { x = old; }
  return { cv: c, bc };
}
function citadelSkyline(X, Y, w, h, o = {}) {
  if (!(w > 2 && h > 2)) return;
  const key = Math.round(w) + 'x' + Math.round(h) + (o.gold ? 'g' : '') + (o.alarm ? 'a' : ''), c = SKY_CACHE[key] || (SKY_CACHE[key] = skyBuild(Math.round(w), Math.round(h), o));
  x.save(); x.beginPath(); x.rect(X, Y, w, h); x.clip();
  x.imageSmoothingEnabled = false; x.drawImage(c.cv, X, Y, c.cv.width * 2, c.cv.height * 2); x.imageSmoothingEnabled = true;
  // живое: маячки, кораблики, сияние/тревога
  c.bc.forEach(([bx, by], i) => { if (sin(T * .06 + i * 2.3) > .3) R(X + bx * 2, Y + by * 2 - 2, 2, 2, o.alarm ? '#ff3a3a' : o.gold ? '#ffd06a' : (i % 3 ? '#ff5a5a' : '#9dff6a')); });
  const n = Math.max(2, Math.round(w / 240));
  for (let i = 0; i < n; i++) { const d = i % 2 ? 1 : -1, sp = .3 + (i % 3) * .14, yy = Y + Math.round(h * (.12 + ((i * .37) % 1) * .4) / 2) * 2, xx = X + Math.round((((i * w * .618 + T * sp * d) % (w + 40)) + w + 40) % (w + 40) / 2) * 2 - 20; R(xx - d * 12, yy + 2, 8, 2, o.gold ? 'rgba(255,170,90,.4)' : 'rgba(130,255,150,.4)'); R(xx - 4, yy, 8, 4, '#c0c8d2'); R(xx - 2, yy - 2, 4, 2, o.gold ? '#ffd890' : '#9fe8ff'); if (((T / 9 + i) | 0) % 2) R(xx + d * 4, yy, 2, 2, '#ff5a5a'); }
  if (o.gold) { x.save(); x.globalCompositeOperation = 'lighter'; x.fillStyle = rgrad(X + w * .5, Y + h * .25, 0, h * 1.5, [[0, 'rgba(255,210,110,' + (.18 + .08 * sin(T / 9)) + ')'], [1, 'rgba(255,180,60,0)']]); x.fillRect(X, Y, w, h); x.restore(); }
  if (o.alarm) { R(X, Y, w, h, 'rgba(255,24,24,' + (.08 + .07 * sin(T / 7)) + ')'); }
  x.restore();
}
