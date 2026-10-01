'use strict';
/* ================= ЯДРО: холст, утилиты, рисование, ввод, корутины ================= */
const W = 640, H = 360;
const cv = document.getElementById('c'); let x = cv.getContext('2d');
let SC = 2, T = 0, f = 1;
const PI = Math.PI, TAU = PI * 2;
const cl = (v, a, b) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;
const rnd = (a = 1, b) => b === undefined ? Math.random() * a : a + Math.random() * (b - a);
const pick = a => a[(Math.random() * a.length) | 0];
const sin = Math.sin, cos = Math.cos, abs = Math.abs, hyp = Math.hypot;
const FONT = '"Pix","Trebuchet MS","Verdana",sans-serif';

if (!CanvasRenderingContext2D.prototype.roundRect) {
  CanvasRenderingContext2D.prototype.roundRect = function (X, Y, w, h, r) {
    r = Math.min(typeof r === 'number' ? r : (r && r[0]) || 0, abs(w) / 2, abs(h) / 2);
    this.moveTo(X + r, Y); this.arcTo(X + w, Y, X + w, Y + h, r); this.arcTo(X + w, Y + h, X, Y + h, r);
    this.arcTo(X, Y + h, X, Y, r); this.arcTo(X, Y, X + w, Y, r); this.closePath();
  };
}

function resize() {
  const dpr = window.devicePixelRatio || 1, s = Math.min(innerWidth / W, innerHeight / H);
  SC = cl(s * dpr, 1, 2.6);
  cv.width = Math.round(W * SC); cv.height = Math.round(H * SC);
  if (typeof AREAS !== 'undefined') for (const k in AREAS) AREAS[k].cache = null;
}
addEventListener('resize', resize);

/* ---------- примитивы ---------- */
const OL = '#2b2220';
let LW = 1.15;
function path(fn, fill, stroke = OL, lw = LW) {
  x.beginPath(); fn();
  if (fill) { x.fillStyle = fill; x.fill(); }
  if (stroke) { x.strokeStyle = stroke; x.lineWidth = lw; x.stroke(); }
}
const E = (X, Y, a, b, fl, st = OL, lw = LW) => path(() => x.ellipse(X, Y, abs(a), abs(b), 0, 0, TAU), fl, st, lw);
const Er = (X, Y, a, b, r, fl, st = OL, lw = LW) => path(() => x.ellipse(X, Y, abs(a), abs(b), r, 0, TAU), fl, st, lw);
const R = (X, Y, w, h, fl, st = null, lw = LW) => path(() => x.rect(X, Y, w, h), fl, st, lw);
const RR = (X, Y, w, h, r, fl, st = OL, lw = LW) => path(() => x.roundRect(X, Y, w, h, r), fl, st, lw);
function PG(pts, fl, st = OL, lw = LW, close = true) {
  path(() => { x.moveTo(pts[0], pts[1]); for (let i = 2; i < pts.length; i += 2) x.lineTo(pts[i], pts[i + 1]); if (close) x.closePath(); }, fl, st, lw);
}
function LN(a, b, c, d, col = OL, lw = LW) { x.strokeStyle = col; x.lineWidth = lw; x.lineCap = 'round'; x.beginPath(); x.moveTo(a, b); x.lineTo(c, d); x.stroke(); }
function QL(a, b, cx, cy, c, d, col = OL, lw = LW) { x.strokeStyle = col; x.lineWidth = lw; x.lineCap = 'round'; x.beginPath(); x.moveTo(a, b); x.quadraticCurveTo(cx, cy, c, d); x.stroke(); }
function limb(pts, w, col, ol = OL) {
  x.lineCap = 'round'; x.lineJoin = 'round'; x.beginPath(); x.moveTo(pts[0], pts[1]);
  for (let i = 2; i < pts.length; i += 2) x.lineTo(pts[i], pts[i + 1]);
  if (ol) { x.strokeStyle = ol; x.lineWidth = w + LW * 2; x.stroke(); }
  x.strokeStyle = col; x.lineWidth = w; x.stroke();
}
function glow(col, blur, fn) { x.save(); x.shadowColor = col; x.shadowBlur = blur; fn(); x.restore(); }
function grad(x0, y0, x1, y1, stops) { const g = x.createLinearGradient(x0, y0, x1, y1); stops.forEach((s, i) => g.addColorStop(s[0], s[1])); return g; }
function rgrad(X, Y, r0, r1, stops) { const g = x.createRadialGradient(X, Y, r0, X, Y, r1); stops.forEach(s => g.addColorStop(s[0], s[1])); return g; }
function shade(hex, k) { // k<0 темнее, k>0 светлее
  const n = parseInt(hex.slice(1), 16); let r = n >> 16, g = (n >> 8) & 255, b = n & 255;
  if (k < 0) { r *= 1 + k; g *= 1 + k; b *= 1 + k; } else { r += (255 - r) * k; g += (255 - g) * k; b += (255 - b) * k; }
  return '#' + ((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1).padStart(6, '0').slice(-6);
}
function shadow(X, Y, rx, ry = rx * .3, a = .28) { E(X, Y, rx, ry, 'rgba(0,0,0,' + a + ')', null); }

/* ---------- текст ---------- */
function font(s, b = 400) { x.font = b + ' ' + s + 'px ' + FONT; }
// в шрифте у заглавной «К» есть лишний штрих — подменяем на латинскую K того же шрифта
const fixK = t => String(t).replace(/К/g, 'K');
function tx(t, X, Y, s, fl = '#fff', al = 'center', b = 700) { font(s, b); x.fillStyle = fl; x.textAlign = al; x.textBaseline = 'alphabetic'; x.fillText(fixK(t), X, Y); }
function txo(t, X, Y, s, fl = '#fff', al = 'center', o = '#000', ow = 3) { t = fixK(t); font(s, 700); x.textAlign = al; x.lineJoin = 'round'; x.strokeStyle = o; x.lineWidth = ow; x.strokeText(t, X, Y); x.fillStyle = fl; x.fillText(t, X, Y); }
function wrap(t, w, s) {
  font(s); const out = [];
  for (const para of fixK(t).split('\n')) {
    let l = '';
    for (const wd of para.split(' ')) { const q = l ? l + ' ' + wd : wd; if (x.measureText(q).width > w && l) { out.push(l); l = wd; } else l = q; }
    out.push(l);
  }
  return out;
}

/* ---------- ввод ---------- */
const K = {};
const inp = { a: 0, b: 0, menu: 0, tap: null, jx: 0, jy: 0, sid: null, so: null, sp: null, any: 0 };
function pp(e) {
  const r = cv.getBoundingClientRect(), s = Math.min(r.width / W, r.height / H);
  return { x: (e.clientX - r.left - (r.width - W * s) / 2) / s, y: (e.clientY - r.top - (r.height - H * s) / 2) / s };
}
// экранные кнопки (сенсор)
const BTN_A = { x: 588, y: 300, r: 30 }, BTN_B = { x: 528, y: 326, r: 20 }, BTN_M = { x: 612, y: 26, r: 16 };
let touchUI = false;
function inBtn(p, b) { return hyp(p.x - b.x, p.y - b.y) < b.r + 8; }
addEventListener('pointerdown', e => {
  if (typeof initAudio === 'function') initAudio();
  if (e.pointerType === 'touch') touchUI = true;
  const p = pp(e); inp.any = 1;
  if (typeof onFirstTap === 'function') onFirstTap();
  if (touchUI && inBtn(p, BTN_M) && uiAllowsMenu()) { inp.menu = 1; return; }
  if (touchUI && inBtn(p, BTN_B) && uiWantsMove()) { inp.b = 1; return; }
  if (touchUI && inBtn(p, BTN_A) && uiWantsMove()) { inp.a = 1; return; }
  if (p.x < W * .5 && inp.sid == null && uiWantsMove()) { inp.sid = e.pointerId; inp.so = p; inp.sp = p; inp.jx = inp.jy = 0; return; }
  inp.tap = p;
});
addEventListener('pointermove', e => {
  if (e.pointerId !== inp.sid) return;
  const p = pp(e), dx = p.x - inp.so.x, dy = p.y - inp.so.y, m = hyp(dx, dy), l = Math.min(1, m / 34);
  inp.sp = p;
  if (m > 40) { inp.so.x = p.x - dx / m * 40; inp.so.y = p.y - dy / m * 40; }
  if (m > 4) { inp.jx = dx / m * l; inp.jy = dy / m * l; } else inp.jx = inp.jy = 0;
});
const pup = e => { if (e.pointerId === inp.sid) { inp.sid = null; inp.jx = inp.jy = 0; } };
addEventListener('pointerup', pup); addEventListener('pointercancel', pup);
addEventListener('keydown', e => {
  if (typeof initAudio === 'function') initAudio();
  const k = e.key.toLowerCase(); if (!K[k]) {
    if (k === 'z' || k === 'enter' || k === ' ' || k === 'я') inp.a = 1;
    if (k === 'x' || k === 'shift' || k === 'ч' || k === 'backspace') inp.b = 1;
    if (k === 'c' || k === 'escape' || k === 'с' || k === 'tab') inp.menu = 1;
  }
  K[k] = 1; inp.any = 1; touchUI = false;
  if (['arrowup', 'arrowdown', 'arrowleft', 'arrowright', ' ', 'tab'].includes(k)) e.preventDefault();
});
addEventListener('keyup', e => { K[e.key.toLowerCase()] = 0; });
addEventListener('contextmenu', e => e.preventDefault());
addEventListener('blur', () => { for (const k in K) K[k] = 0; inp.sid = null; inp.jx = inp.jy = 0; });
function mv() {
  let a = inp.jx + (K.arrowright || K.d || K['в'] ? 1 : 0) - (K.arrowleft || K.a || K['ф'] ? 1 : 0);
  let b = inp.jy + (K.arrowdown || K.s || K['ы'] ? 1 : 0) - (K.arrowup || K.w || K['ц'] ? 1 : 0);
  const m = hyp(a, b); if (m > 1) { a /= m; b /= m; }
  return [a, b, Math.min(1, m)];
}
// меню-навигация стрелками (одно нажатие)
const navPrev = {};
function navPressed(k) { const v = !!K[k]; const r = v && !navPrev[k]; navPrev[k] = v; return r; }
let navJ = 0;
function navDir() { // -1 / +1 по вертикали/горизонтали для меню
  let d = 0;
  if (navPressed('arrowup') || navPressed('w') || navPressed('arrowleft') || navPressed('a')) d = -1;
  if (navPressed('arrowdown') || navPressed('s') || navPressed('arrowright') || navPressed('d')) d = 1;
  return d;
}

/* ---------- корутины для сюжета ---------- */
const WAITS = [];
function until(cond) { return new Promise(r => WAITS.push({ cond, r })); }
function wait(n) { const t = T + n; return until(() => T >= t); }
function tickWaits() {
  for (let i = WAITS.length - 1; i >= 0; i--) { const w = WAITS[i]; if (w.cond()) { WAITS.splice(i, 1); w.r(); } }
}
let CUT = 0;
async function cutscene(fn) { CUT++; try { await fn(); } catch (e) { console.error(e); } finally { CUT--; } }
