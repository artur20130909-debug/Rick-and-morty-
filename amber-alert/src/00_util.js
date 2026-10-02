'use strict';
/* ================= УТИЛИТЫ ================= */
const V3 = THREE.Vector3;
const PI = Math.PI, TAU = PI * 2;
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;
const damp = (a, b, k, dt) => lerp(a, b, 1 - Math.exp(-k * dt));
const angDiff = (a, b) => { let d = (b - a) % TAU; if (d > PI) d -= TAU; if (d < -PI) d += TAU; return d; };
const dist2 = (ax, az, bx, bz) => Math.hypot(ax - bx, az - bz);
const pick = a => a[(Math.random() * a.length) | 0];
const now = () => performance.now() / 1000;
const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];
function el(tag, attrs = {}, ...kids) {
  const e = document.createElement(tag);
  for (const k in attrs) { if (k === 'style') Object.assign(e.style, attrs[k]); else if (k.startsWith('on')) e.addEventListener(k.slice(2), attrs[k]); else if (k === 'html') e.innerHTML = attrs[k]; else e.setAttribute(k, attrs[k]); }
  for (const c of kids) if (c != null) e.append(c.nodeType ? c : document.createTextNode(c));
  return e;
}
// детерминированный ГСЧ (общий для хоста и клиентов, если нужен одинаковый мир)
function rng(seed) { let s = seed >>> 0 || 1; return () => { s ^= s << 13; s >>>= 0; s ^= s >> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; }; }
const IS_TOUCH = matchMedia('(pointer: coarse)').matches || 'ontouchstart' in window;
const QS = new URLSearchParams(location.search);

/* ---------- процедурные текстуры (холст) ---------- */
const TEXCACHE = {};
function canvasTex(key, w, h, draw, rep) {
  if (TEXCACHE[key]) return TEXCACHE[key];
  const c = document.createElement('canvas'); c.width = w; c.height = h; const g = c.getContext('2d'); draw(g, w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4;
  if (rep) { t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(rep[0], rep[1]); }
  return (TEXCACHE[key] = t);
}
function noiseFill(g, w, h, base, amp, n = w * h / 6) { g.fillStyle = base; g.fillRect(0, 0, w, h); for (let i = 0; i < n; i++) { const v = (Math.random() - .5) * amp; g.fillStyle = v > 0 ? `rgba(255,255,255,${v})` : `rgba(0,0,0,${-v})`; g.fillRect(Math.random() * w, Math.random() * h, 1 + Math.random() * 2, 1 + Math.random() * 2); } }
// материалы с кэшем
const MATCACHE = {};
function mat(color, o = {}) {
  const key = color + JSON.stringify(o, (k, v) => v && v.isTexture ? v.uuid : v);
  if (MATCACHE[key]) return MATCACHE[key];
  const m = o.basic ? new THREE.MeshBasicMaterial(Object.assign({ color }, o, { basic: undefined })) : new THREE.MeshLambertMaterial(Object.assign({ color }, o));
  delete m.basic;
  return (MATCACHE[key] = m);
}
// текстовая табличка/спрайт
function textCanvas(lines, o = {}) {
  const fs = o.size || 48, pad = o.pad ?? 16, font = `${o.weight || 800} ${fs}px ${o.font || 'Arial Black, Arial, sans-serif'}`;
  const c = document.createElement('canvas'), g = c.getContext('2d'); g.font = font;
  const ls = Array.isArray(lines) ? lines : [lines];
  const w = Math.ceil(Math.max(...ls.map(l => g.measureText(l).width)) + pad * 2), h = Math.ceil(ls.length * fs * 1.2 + pad * 2);
  c.width = o.w || w; c.height = o.h || h; g.font = font;
  if (o.bg) { g.fillStyle = o.bg; if (o.radius) { g.beginPath(); g.roundRect(0, 0, c.width, c.height, o.radius); g.fill(); } else g.fillRect(0, 0, c.width, c.height); }
  g.textAlign = 'center'; g.textBaseline = 'middle';
  ls.forEach((l, i) => { const y = c.height / 2 + (i - (ls.length - 1) / 2) * fs * 1.2; if (o.stroke) { g.lineWidth = o.strokeW || 8; g.strokeStyle = o.stroke; g.lineJoin = 'round'; g.strokeText(l, c.width / 2, y); } g.fillStyle = o.color || '#fff'; g.fillText(l, c.width / 2, y); });
  return c;
}
function textSprite(lines, o = {}) {
  const c = textCanvas(lines, o), t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: t, depthTest: o.depthTest ?? true, transparent: true, fog: false }));
  const k = o.scale || .005; s.scale.set(c.width * k, c.height * k, 1); s.renderOrder = o.renderOrder || 0; return s;
}
function textPlane(lines, w, o = {}) {
  const c = textCanvas(lines, o), t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  const m = new THREE.Mesh(new THREE.PlaneGeometry(w, w * c.height / c.width), new THREE.MeshBasicMaterial({ map: t, transparent: !!o.transparent, fog: o.fog ?? true, toneMapped: false }));
  return m;
}
