/* ================= МИР: локации, мебель, коллизии, камера, NPC ================= */
const AREAS = {};
const OWS = .9;                 // масштаб персонажей в мире
const G = {                      // глобальное состояние игры (сохраняется)
  day: 1, time: 'morning', type: 'school_test', phase: '', obj: '', party: [], flags: {}, done: {}, npcs: {}, seen: {},
};
let AR = null, ENTS = [], PL = { x: 140, y: 230, dir: 'd', ph: 0, mov: 0, id: 'morty', spd: 1.9 };
const CAM = { x: 0, y: 0, shake: 0 };
const TRAIL = [];
function area(id, d) { d.id = id; d.props = d.props || []; d.solids = d.solids || []; d.exits = d.exits || []; d.things = d.things || []; AREAS[id] = d; }

/* ---------- палитра неба ---------- */
function skyCols() {
  return { morning: ['#7fb6e8', '#ffd7a8'], day: ['#5aa8e8', '#bfe4ff'], evening: ['#3a3a7a', '#ff9a6a'], night: ['#060a20', '#1c2458'] }[G.time] || ['#5aa8e8', '#bfe4ff'];
}
function skyRect(X, Y, w, h) {
  const c = skyCols(); R(X, Y, w, h, grad(0, Y, 0, Y + h, [[0, c[0]], [1, c[1]]]));
  if (G.time === 'night') { for (let i = 0; i < w * h / 600; i++) E(X + (i * 97.3) % w, Y + (i * 53.7) % h, .7, .7, '#fff', null); E(X + w * .75, Y + h * .3, Math.min(8, h * .15), Math.min(8, h * .15), '#f6f0d0', null); }
  else if (G.time !== 'evening') for (let i = 0; i < 2; i++) { const cx = X + w * (.25 + i * .45), cy = Y + h * (.3 + i * .15); E(cx, cy, w * .12, h * .06, 'rgba(255,255,255,.75)', null); E(cx + w * .07, cy - h * .03, w * .08, h * .06, 'rgba(255,255,255,.75)', null); }
  else E(X + w * .3, Y + h * .85, h * .25, h * .25, '#ffcf6a', null);
}

/* ---------- комната (вид 3/4) ---------- */
function roomShell(o) {
  const { L, Rr, WT, FT, FB } = o;
  R(L, WT, Rr - L, FT - WT, o.wall);
  if (o.wall2) { R(L, FT - (o.wh2 || 34), Rr - L, (o.wh2 || 34), o.wall2); R(L, FT - (o.wh2 || 34) - 3, Rr - L, 3, o.trim || shade(o.wall2, -.2)); }
  if (o.stripes) for (let xx = L + 8; xx < Rr; xx += o.stripes) R(xx, WT, 2, FT - WT - (o.wall2 ? (o.wh2 || 34) + 3 : 0), 'rgba(0,0,0,.05)');
  R(L, FT - 6, Rr - L, 6, o.base || shade(o.wall, -.35));
  floor(L, FT, Rr - L, FB - FT, o.floor, o.fc, o.fc2);
  R(L, WT - 6, Rr - L, 6, shade(o.wall, -.45));
  // боковые стены
  PG([L, WT - 6, L - 16, WT + 4, L - 16, FB + 8, L, FB], shade(o.wall, -.55), null);
  PG([Rr, WT - 6, Rr + 16, WT + 4, Rr + 16, FB + 8, Rr, FB], shade(o.wall, -.55), null);
  R(L - 16, FB, Rr - L + 32, 10, '#141018');
  LN(L, FT, L, FB, 'rgba(0,0,0,.4)', 2); LN(Rr, FT, Rr, FB, 'rgba(0,0,0,.4)', 2);
  R(L, FT, Rr - L, 10, grad(0, FT, 0, FT + 10, [[0, 'rgba(0,0,0,.22)'], [1, 'rgba(0,0,0,0)']]));
}
function floor(X, Y, w, h, kind, c1, c2) {
  R(X, Y, w, h, c1);
  x.save(); x.beginPath(); x.rect(X, Y, w, h); x.clip();
  if (kind === 'wood') { for (let yy = Y, r = 0; yy < Y + h; yy += 13, r++) { R(X, yy, w, 1.2, c2); for (let xx = X + (r % 3) * 37; xx < X + w; xx += 110) R(xx, yy, 1.2, 13, c2); } }
  else if (kind === 'tile') { const s = 26; for (let yy = Y; yy < Y + h; yy += s) for (let xx = X; xx < X + w; xx += s) if (((xx - X) / s + (yy - Y) / s | 0) % 2) R(xx, yy, s, s, c2); }
  else if (kind === 'carpet') { for (let i = 0; i < w * h / 90; i++) R(X + (i * 37.7) % w, Y + (i * 23.3) % h, 1.4, 1.4, c2); }
  else if (kind === 'concrete') { for (let i = 0; i < 9; i++) E(X + (i * 173) % w, Y + 20 + (i * 61) % (h - 30), 18 + i % 3 * 9, 6 + i % 2 * 3, c2, null); for (let i = 0; i < 6; i++) QL(X + (i * 211) % w, Y + (i * 47) % h, X + (i * 211) % w + 20, Y + (i * 47) % h + 8, X + (i * 211) % w + 34, Y + (i * 47) % h + 4, 'rgba(0,0,0,.15)', 1); }
  else if (kind === 'metal') { for (let yy = Y; yy < Y + h; yy += 40) for (let xx = X; xx < X + w; xx += 60) { RR(xx + 1, yy + 1, 58, 38, 3, null, c2, 1.2); for (const [a, b] of [[5, 5], [53, 5], [5, 33], [53, 33]]) E(xx + a, yy + b, 1.2, 1.2, c2, null); } }
  else if (kind === 'court') { for (let yy = Y, r = 0; yy < Y + h; yy += 11, r++) R(X, yy, w, .8, c2); }
  else if (kind === 'ice') { for (let i = 0; i < 30; i++) LN(X + (i * 89) % w, Y + (i * 31) % h, X + (i * 89) % w + 30, Y + (i * 31) % h + 6, 'rgba(255,255,255,.35)', 1); }
  x.restore();
}
function grassFloor(X, Y, w, h) {
  const ev = G.time === 'evening' || G.time === 'night';
  R(X, Y, w, h, ev ? '#4a7a3a' : '#6cb04a');
  for (let i = 0; i < w * h / 160; i++) { const gx = X + (i * 53.3) % w, gy = Y + (i * 29.7) % h; LN(gx, gy, gx - 1.5, gy - 4, ev ? '#3a6a2a' : '#5a9a3a', 1); LN(gx + 2, gy, gx + 3, gy - 3.5, ev ? '#5a8a4a' : '#7cc05a', 1); }
}
/* ---------- мебель и детали ---------- */
function box(X, Y, w, d, h, top, front, ol = OL) { R(X, Y - h - d, w, d, top, ol); R(X, Y - h, w, h, front, ol); }
function door(X, yb, w = 38, h = 72, col = '#8a5a3a', sign) {
  R(X - 3, yb - h - 3, w + 6, h + 3, shade(col, -.3), OL); R(X, yb - h, w, h, col, OL);
  RR(X + 5, yb - h + 6, w - 10, h * .38, 2, shade(col, .08), OL, .8); RR(X + 5, yb - h * .5, w - 10, h * .42, 2, shade(col, .08), OL, .8);
  E(X + w - 7, yb - h * .48, 2, 2, '#e9c25a');
  if (sign) { RR(X + 2, yb - h - 18, w - 4, 12, 2, '#f4efe0', OL, .8); tx(sign, X + w / 2, yb - h - 9, 7, '#333'); }
}
function windowW(X, Y, w, h, frame = '#f2ead8', curt) {
  R(X - 3, Y - 3, w + 6, h + 6, frame, OL); x.save(); x.beginPath(); x.rect(X, Y, w, h); x.clip(); skyRect(X, Y, w, h);
  if (G.time === 'day' || G.time === 'morning') { x.globalAlpha = .25; PG([X + w * .2, Y, X + w * .35, Y, X + w * .05, Y + h, X - w * .1, Y + h], '#fff', null); x.globalAlpha = 1; }
  x.restore(); R(X, Y, w, h, null, OL); LN(X + w / 2, Y, X + w / 2, Y + h, frame, 3); LN(X, Y + h / 2, X + w, Y + h / 2, frame, 3);
  R(X - 6, Y + h + 2, w + 12, 4, shade(frame, -.1), OL);
  if (curt) { PG([X - 8, Y - 6, X + w * .22, Y - 6, X + w * .12, Y + h * .5, X + w * .16, Y + h + 4, X - 8, Y + h + 4], curt); PG([X + w + 8, Y - 6, X + w * .78, Y - 6, X + w * .88, Y + h * .5, X + w * .84, Y + h + 4, X + w + 8, Y + h + 4], curt); }
}
function frameP(X, Y, w, h, inner) { R(X - 2, Y - 2, w + 4, h + 4, '#8a6a3a', OL); R(X, Y, w, h, '#f4efe0', OL, .8); x.save(); x.beginPath(); x.rect(X, Y, w, h); x.clip(); inner(X, Y, w, h); x.restore(); }
function poster(X, Y, w, h, col, t, tc = '#fff') { R(X, Y, w, h, col, OL); if (t) tx(t, X + w / 2, Y + h - 6, Math.min(9, w / 4.5), tc); }
function plant(X, Y, s = 1) { shadow(X, Y, 10 * s, 3 * s); RR(X - 7 * s, Y - 14 * s, 14 * s, 14 * s, 2, '#b06a3a'); for (let i = 0; i < 6; i++) Er(X + (i - 2.5) * 3 * s, Y - 20 * s - (i % 2) * 6 * s, 3.5 * s, 9 * s, (i - 2.5) * .3, i % 2 ? '#3f8a3a' : '#57a84a'); }
function lampFloor(X, Y) { shadow(X, Y, 8, 2.5); LN(X, Y, X, Y - 56, '#555', 2); E(X, Y, 6, 2, '#444'); PG([X - 10, Y - 54, X + 10, Y - 54, X + 6, Y - 68, X - 6, Y - 68], '#f4e2b0'); if (G.time === 'evening' || G.time === 'night') { x.save(); x.globalCompositeOperation = 'lighter'; E(X, Y - 50, 40, 30, rgrad(X, Y - 50, 2, 40, [[0, 'rgba(255,210,140,.35)'], [1, 'rgba(255,210,140,0)']]), null); x.restore(); } }
function bookshelf(X, yb, w, h) { box(X, yb, w, 12, h, '#7a4a2a', '#8a5a3a'); for (let r = 0; r < 3; r++) { const y = yb - h + 8 + r * (h - 10) / 3; R(X + 3, y + (h - 10) / 3 - 3, w - 6, 2, '#5a3a1a'); for (let i = 0; i < (w - 8) / 5; i++) R(X + 4 + i * 5, y + 2 + (i % 3), 4, (h - 10) / 3 - 6 - (i % 3), ['#c0392b', '#2980b9', '#27ae60', '#f39c12', '#8e44ad'][(i + r) % 5], OL, .5); } }
function rug(X, Y, rx, ry, c1, c2) { E(X, Y, rx, ry, c1, OL); E(X, Y, rx * .78, ry * .72, null, c2, 2); E(X, Y, rx * .45, ry * .4, c2, null); }
function chair(X, Y, dir, col = '#8a5a3a') { // Y — пол
  shadow(X, Y, 10, 3);
  if (dir === 'd') { R(X - 9, Y - 34, 18, 20, col, OL); R(X - 10, Y - 16, 20, 5, shade(col, .1), OL); LN(X - 8, Y - 11, X - 8, Y, OL, 2); LN(X + 8, Y - 11, X + 8, Y, OL, 2); }
  else if (dir === 'u') { R(X - 10, Y - 16, 20, 5, shade(col, .1), OL); LN(X - 8, Y - 11, X - 8, Y, OL, 2); LN(X + 8, Y - 11, X + 8, Y, OL, 2); R(X - 9, Y - 34, 18, 18, shade(col, -.1), OL); }
  else { const s = dir === 'l' ? 1 : -1; R(X - 10, Y - 16, 20, 5, shade(col, .1), OL); LN(X - 8, Y - 11, X - 8, Y, OL, 2); LN(X + 8, Y - 11, X + 8, Y, OL, 2); R(X + s * 8 - 2, Y - 36, 4, 22, col, OL); }
}
function skyGlowOverlay() { }

/* ---------- корабль Рика ---------- */
function ship(X, Y, o = {}) {
  const b = o.fly ? sin(T / 8) * 2 : 0, yy = Y + b - (o.lift || 0);
  if (!o.fly || (o.lift || 0) < 30) shadow(X, Y, 80 - (o.lift || 0) * .6, 12, .3);
  x.save(); x.translate(X, yy); if (o.sc) x.scale(o.sc, o.sc);
  // корпус
  path(() => { x.moveTo(-86, -18); x.bezierCurveTo(-90, -40, -40, -48, 0, -48); x.bezierCurveTo(40, -48, 92, -40, 88, -18); x.bezierCurveTo(84, -2, 40, 4, 0, 4); x.bezierCurveTo(-40, 4, -82, -2, -86, -18); }, '#b8c0c8');
  path(() => { x.moveTo(-84, -16); x.bezierCurveTo(-60, -6, 60, -6, 86, -16); x.bezierCurveTo(84, -2, 40, 4, 0, 4); x.bezierCurveTo(-40, 4, -82, -2, -84, -16); }, '#8a929c', null);
  R(-80, -24, 166, 5, '#c0392b', OL, .8);
  // кабина: экипаж под стеклом
  const dome = () => { x.moveTo(-44, -46); x.bezierCurveTo(-40, -82, 36, -84, 46, -46); x.closePath(); };
  path(dome, 'rgba(40,60,80,.55)', null);
  if (o.crew) { x.save(); x.beginPath(); dome(); x.clip(); o.crew(); x.restore(); }
  path(dome, 'rgba(160,220,240,.35)');
  QL(-30, -52, -24, -74, -6, -78, 'rgba(255,255,255,.7)', 2);
  // фары, сопла
  for (let i = -2; i <= 2; i++) E(i * 30, -6, 4, 2.4, (T / 10 + i | 0) % 2 ? '#ffe36a' : '#ffb24a');
  PG([86, -24, 104, -36, 104, -14, 88, -12], '#9aa2ac'); PG([-86, -24, -104, -36, -104, -14, -88, -12], '#9aa2ac');
  if (o.fly) { x.save(); x.globalCompositeOperation = 'lighter'; E(0, 10, 30, 8 + sin(T / 2) * 2, 'rgba(120,255,140,.5)', null); E(0, 12, 14, 5, 'rgba(220,255,220,.8)', null); x.restore(); }
  x.restore();
}
/* ---------- портал ---------- */
function portal(X, Y, s, a = 1, hue = 105) {
  x.save(); x.globalAlpha = a; x.shadowColor = 'hsl(' + hue + ',90%,55%)'; x.shadowBlur = 16;
  for (let i = 0; i < 10; i++) { const k = i / 10, r = s * (1 - k * .75); x.strokeStyle = 'hsl(' + (hue + k * 40) + ',90%,' + (38 + k * 38) + '%)'; x.lineWidth = 3; x.beginPath(); x.ellipse(X, Y, r * .62, r, 0, T / 18 + i * .7, T / 18 + i * .7 + 4.2); x.stroke(); }
  E(X, Y, s * .14, s * .2, 'hsl(' + hue + ',100%,90%)', null); x.restore();
}

/* ---------- сущности ---------- */
function npc(id, x0, y0, o = {}) { return Object.assign({ id, x: x0, y: y0, dir: 'd', ph: 0, mov: 0, spd: 1.5 }, o); }
function entAt(id) { return ENTS.find(e => e.key === id || e.id === id); }
function walkTo(e, tx_, ty_, spd) { return new Promise(r => { e.tgt = { x: tx_, y: ty_, r }; if (spd) e.spd = spd; }); }
async function walkPath(e, pts, spd) { for (const p of pts) await walkTo(e, p[0], p[1], spd); }
function turn(e, d) { e.dir = d; }
function faceTo(e, t) { const dx = t.x - e.x, dy = t.y - e.y; e.dir = abs(dx) > abs(dy) ? (dx > 0 ? 'r' : 'l') : (dy > 0 ? 'd' : 'u'); }
function moveEnt(e) {
  if (!e.tgt) { e.mov = 0; return; }
  const dx = e.tgt.x - e.x, dy = e.tgt.y - e.y, m = hyp(dx, dy), s = e.spd * f;
  if (m <= s) { e.x = e.tgt.x; e.y = e.tgt.y; const r = e.tgt.r; e.tgt = null; e.mov = 0; r && r(); return; }
  e.x += dx / m * s; e.y += dy / m * s; e.mov = 1; e.ph += .2 * f * e.spd / 1.5;
  e.dir = abs(dx) > abs(dy) ? (dx > 0 ? 'r' : 'l') : (dy > 0 ? 'd' : 'u');
}

/* ---------- кэш фона ---------- */
function bgCache(a) {
  const key = G.time + '|' + SC + '|' + (a.cacheKey ? a.cacheKey() : '');
  if (a.cache && a.cacheK === key) return a.cache;
  const s = Math.min(SC, 7000 / a.w, 3000 / a.h), c = document.createElement('canvas');
  c.width = Math.ceil(a.w * s); c.height = Math.ceil(a.h * s);
  const old = x; const cx = c.getContext('2d');
  x = cx; x.setTransform(s, 0, 0, s, 0, 0); x.fillStyle = '#05050a'; x.fillRect(0, 0, a.w, a.h);
  try { a.bg(); } catch (e) { console.error(e); }
  x = old; a.cache = c; a.cacheK = key; a.cacheS = s; return c;
}

/* ---------- вход в локацию ---------- */
let areaT = 0;
function enterArea(id, X, Y, dir) {
  const prev = AR ? AR.id : null;
  AR = AREAS[id]; PL.x = X; PL.y = Y; if (dir) PL.dir = dir; areaT = 0; if (window.PILOT) { window.PILOT = null; inp.jx = inp.jy = 0; }
  TRAIL.length = 0;
  ENTS = [];
  for (const k in G.npcs) { const n = G.npcs[k]; if (n && n.area === id) ENTS.push(Object.assign(npc(n.id || k, n.x, n.y, n), { key: k })); }
  if (AR.crowd) for (const c of AR.crowd()) ENTS.push(c);
  // спутники
  G.party.forEach((p, i) => ENTS.push(npc(p, X - (dir === 'r' ? 20 : dir === 'l' ? -20 : 0) * (i + 1), Y + (dir === 'd' ? -14 : dir === 'u' ? 14 : 0) * (i + 1), { follow: i + 1, dir, key: p })));
  updCam(true);
  playAreaMusic();
  if (typeof onEnterArea === 'function') onEnterArea(id, prev);
}
function playAreaMusic() { if (!AR) return; const m = typeof AR.music === 'function' ? AR.music() : AR.music; if (G.musicLock) return; music(m); }
function homeMusic() { return G.time === 'morning' ? 'morning' : G.time === 'night' ? 'night' : G.time === 'day' ? 'morning' : 'evening'; }

/* ---------- коллизии ---------- */
function solidAt(px, py, self) {
  const a = AR, b = a.bounds;
  if (px < b[0] || px > b[2] || py < b[1] || py > b[3]) return true;
  for (const s of a.solids) if (px > s[0] && px < s[0] + s[2] && py > s[1] && py < s[1] + s[3]) return true;
  for (const p of a.props) if (p.solid) { const s = p.solid; if (px > s[0] && px < s[0] + s[2] && py > s[1] && py < s[1] + s[3]) return true; }
  for (const e of ENTS) if (e !== self && !e.follow && !e.ghost && !e.hidden && abs(px - e.x) < 9 && abs(py - e.y) < 5) return true;
  return false;
}
function tryMove(e, dx, dy) {
  const fx2 = [-6, 6];
  const ok = (nx, ny) => fx2.every(o => !solidAt(nx + o, ny, e)) && !solidAt(nx, ny - 3, e);
  if (dx && ok(e.x + dx, e.y)) e.x += dx;
  if (dy && ok(e.x, e.y + dy)) e.y += dy;
}
function inRect(px, py, r) { return px >= r[0] && px <= r[0] + r[2] && py >= r[1] && py <= r[1] + r[3]; }

/* ---------- обновление мира ---------- */
let NEAR = null;
function updateWorld(canMove) {
  areaT += f;
  const [ax, ay, am] = canMove ? mv() : [0, 0, 0];
  if (canMove && !PL.tgt) {
    const run = am > .95 && (inp.sid != null || K.x || K.shift) ? 1.45 : 1;
    const sp = PL.spd * run * f;
    const ox = PL.x, oy = PL.y;
    if (am > .12) {
      tryMove(PL, ax * sp, ay * sp);
      PL.dir = abs(ax) > abs(ay) * 1.1 ? (ax > 0 ? 'r' : 'l') : (ay > 0 ? 'd' : 'u');
      const moved = hyp(PL.x - ox, PL.y - oy); PL.mov = moved > .05; PL.ph += moved * .16;
      // выходы
      for (const ex of AR.exits) if ((inRect(PL.x, PL.y, ex.r) || inRect(PL.x + ax * 12, PL.y + ay * 10, ex.r)) && dirMatch(ex.dir, ax, ay)) { useExit(ex); break; }
    } else PL.mov = 0;
  } else if (PL.tgt) moveEnt(PL); else PL.mov = 0;
  if (PL.mov || PL.tgt) { TRAIL.unshift([PL.x, PL.y, PL.dir]); if (TRAIL.length > 200) TRAIL.pop(); }
  for (const e of ENTS) {
    if (e.follow) {
      const tr = TRAIL[e.follow * 16];
      if (tr && (PL.mov || PL.tgt)) { const dx = tr[0] - e.x, dy = tr[1] - e.y; e.x = tr[0]; e.y = tr[1]; e.dir = tr[2]; e.mov = hyp(dx, dy) > .05; if (e.mov) e.ph += hyp(dx, dy) * .16; }
      else if (!e.tgt) e.mov = 0;
      if (e.tgt) moveEnt(e);
    } else {
      moveEnt(e);
      if (e.wander && !e.tgt && Math.random() < .004 * f) { const w = e.wander; walkTo(e, cl(e.x + rnd(-w, w), AR.bounds[0] + 10, AR.bounds[2] - 10), cl(e.y + rnd(-w / 3, w / 3), AR.bounds[1] + 6, AR.bounds[3] - 4)); }
    }
  }
  // что рядом (для подсказки и взаимодействия)
  NEAR = null;
  if (canMove) {
    const dv = { u: [0, -1], d: [0, 1], l: [-1, 0], r: [1, 0] }[PL.dir], px = PL.x + dv[0] * 16, py = PL.y + dv[1] * 12;
    let best = 1e9;
    for (const e of ENTS) { if (e.follow || e.hidden || !e.talk) continue; const dd = Math.min(hyp(e.x - px, (e.y - py) * 1.4), hyp(e.x - PL.x, (e.y - PL.y) * 1.4) + 6); if (dd < 32 && dd < best) { best = dd; NEAR = { ent: e }; } }
    if (!NEAR) for (const t of AR.things) { if (t.cond && !t.cond()) continue; const r = t.r; if (inRect(px, py, [r[0] - 4, r[1] - 4, r[2] + 8, r[3] + 8]) || inRect(PL.x, PL.y - 4, r)) { NEAR = { thing: t }; break; } }
    if (inp.a && NEAR) { inp.a = 0; interact(NEAR); }
  }
  updCam(false);
}
function dirMatch(d, ax, ay) { return !d || (d === 'u' && ay < -.2) || (d === 'd' && ay > .2) || (d === 'l' && ax < -.2) || (d === 'r' && ax > .2); }
function useExit(ex) {
  if (ex.cond && !ex.cond()) { if (ex.msg) { PL.y -= ex.dir === 'u' ? -4 : ex.dir === 'd' ? 4 : 0; PL.x -= ex.dir === 'l' ? -4 : ex.dir === 'r' ? 4 : 0; cutscene(async () => { await say(typeof ex.msg === 'function' ? ex.msg() : ex.msg); }); } return; }
  if (typeof onExit === 'function' && onExit(ex) === false) return;
  if (ex.door) sfx('door');
  cutscene(async () => { await fadeOut(12); enterArea(ex.to, ex.at[0], ex.at[1], ex.face || ex.dir); await fadeIn(12); });
}
function interact(n) {
  if (n.ent) { const e = n.ent; if (!e.noFace) faceTo(e, PL); faceTo(PL, e); cutscene(async () => { const r = typeof e.talk === 'function' ? e.talk(e) : e.talk; if (r && r.then) await r; else if (r) await say(r); }); }
  else { const t = n.thing; cutscene(async () => { const r = typeof t.look === 'function' ? t.look(t) : t.look; if (r && r.then) await r; else if (r) await say(r); }); }
}
function updCam(snap) {
  const a = AR, tx_ = a.w <= W ? (a.w - W) / 2 : cl(PL.x - W / 2, 0, a.w - W), ty_ = a.h <= H ? (a.h - H) / 2 : cl(PL.y - 40 - H / 2, 0, a.h - H);
  if (snap) { CAM.x = tx_; CAM.y = ty_; } else { CAM.x += (tx_ - CAM.x) * Math.min(1, .15 * f); CAM.y += (ty_ - CAM.y) * Math.min(1, .15 * f); }
  if (CAM.focus) { const fx_ = a.w <= W ? (a.w - W) / 2 : cl(CAM.focus.x - W / 2, 0, a.w - W); CAM.x += (fx_ - CAM.x) * .08 * f; }
}

/* ---------- отрисовка мира ---------- */
const TINT = { morning: ['#fff1de', .0], day: [null, 0], evening: ['#e9a978', 1], night: ['#5560a8', 1] };
function drawWorld() {
  const a = AR, c = bgCache(a), s = a.cacheS;
  let sx = CAM.x, sy = CAM.y;
  if (CAM.shake > 0) { sx += rnd(-CAM.shake, CAM.shake); sy += rnd(-CAM.shake, CAM.shake); CAM.shake = Math.max(0, CAM.shake - .3 * f); }
  x.fillStyle = '#05050a'; x.fillRect(0, 0, W, H);
  const ox = Math.max(0, sx), oy = Math.max(0, sy);
  x.drawImage(c, ox * s, oy * s, Math.min(W, a.w - ox) * s, Math.min(H, a.h - oy) * s, ox - sx, oy - sy, Math.min(W, a.w - ox), Math.min(H, a.h - oy));
  x.save(); x.translate(-Math.round(sx * SC) / SC, -Math.round(sy * SC) / SC);
  if (a.under) a.under();
  if (typeof underFX === 'function') underFX();
  const list = [];
  for (const p of a.props) if (!p.hide || !p.hide()) list.push([p.y, () => p.draw(p)]);
  for (const e of ENTS) if (!e.hidden) list.push([e.y + (e.zb || 0), () => drawEnt(e)]);
  if (!PL.hidden) list.push([PL.y, () => drawEnt(PL)]);
  list.sort((p, q) => p[0] - q[0]); for (const l of list) l[1]();
  if (a.fg) a.fg();
  if (typeof drawFX === 'function') drawFX();
  // подсказка «!»
  if (NEAR && !DLG && !CUT) { const t = NEAR.ent ? [NEAR.ent.x, NEAR.ent.y - entH(NEAR.ent) - 10] : [NEAR.thing.r[0] + NEAR.thing.r[2] / 2, NEAR.thing.r[1] - 8]; const bb = sin(T / 7) * 2; RR(t[0] - 7, t[1] - 18 + bb, 14, 15, 4, '#fff', OL); tx(NEAR.ent ? '…' : '?', t[0], t[1] - 7 + bb, 11, '#2b2220'); PG([t[0] - 3, t[1] - 3.5 + bb, t[0] + 3, t[1] - 3.5 + bb, t[0], t[1] + bb], '#fff', null); }
  x.restore();
  // время суток
  const tt = a.indoor ? TINT[G.time] : TINT[G.time];
  if (tt[0] && !a.noTint) { x.save(); x.globalCompositeOperation = 'multiply'; x.globalAlpha = a.indoor && G.time === 'evening' ? .7 : 1; x.fillStyle = tt[0]; x.fillRect(0, 0, W, H); x.restore(); }
  if (G.time === 'morning' && !a.noTint) { x.save(); x.globalCompositeOperation = 'soft-light'; x.fillStyle = 'rgba(255,200,140,.25)'; x.fillRect(0, 0, W, H); x.restore(); }
  if (a.light) a.light();
  // виньетка
  x.fillStyle = rgrad(W / 2, H / 2, H * .45, W * .65, [[0, 'rgba(0,0,0,0)'], [1, 'rgba(0,0,0,.42)']]); x.fillRect(0, 0, W, H);
}
function entH(e) { const d = CH[e.id]; if (!d) return 60; if (d.draw) return e.id === 'pickle' ? 70 : 72 * OWS; return (d.leg + d.torso + d.neck + d.hh + d.shoeH) * OWS; }
function drawEnt(e) {
  if (e.draw) return e.draw(e);
  // говорящий персонаж показывает эмоцию и позу реплики, а в покое — жестикулирует
  const ln = DLG && DLG.lines[DLG.i], me = ln && NAME2ID[ln.who] === e.id && (e === PL || !e.follow || e.id !== 'morty');
  let pose = e.mov ? null : e.pose, emo = e.emo;
  if (me) { if (ln.emo) emo = ln.emo; if (ln.pose) pose = ln.pose; else if (!e.sit && !e.mov && (!pose || pose === 'idle') && CH[e.id] && !CH[e.id].draw && (CH[e.id].pose === 'idle' || pose === 'idle')) pose = 'gesture'; }
  drawChar(e.id, e.x, e.y, { dir: e.dir, mov: e.mov, ph: e.ph, sc: (e.sc || 1) * OWS, pose, emo, talk: SPK && SPK === e.id, sit: e.sit, look: e.look, alpha: e.alpha, col: e.col });
}
