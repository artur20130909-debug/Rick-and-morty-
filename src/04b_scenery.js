/* ================= ДЕКОРАЦИИ: деревья, кусты, цветы, трава, камни (в пиксель-режиме выглядят как пиксель-арт) ================= */
// детерминированный «случай»: одно и то же дерево всегда одинаковое
function SR(seed) { let s = (Math.abs(seed * 9301 + 49297) | 0) % 233280 || 1; return () => (s = (s * 9301 + 49297) % 233280) / 233280; }
const LEAF = () => isEve() ? ['#1d4424', '#28582c', '#356c36', '#4a8444', '#6a9e56'] : ['#2a6430', '#367e38', '#4c9a44', '#6cb852', '#9bd46a'];
// крона из «облачков»: общий контур, тень снизу, блики сверху, листочки
function canopy(blobs, pal, r, specks = 18, cx, cy, R0) {
  for (const [bx, by, br] of blobs) E(bx, by, br + 1.4, br * .88 + 1.4, OL, null);
  for (const [bx, by, br] of blobs) E(bx, by, br, br * .88, pal[2], null);
  for (const [bx, by, br] of blobs) if (by > cy - R0 * .15) E(bx + br * .12, by + br * .32, br * .78, br * .5, pal[1], null);
  for (const [bx, by, br] of blobs) if (by > cy + R0 * .25) E(bx + br * .1, by + br * .5, br * .6, br * .32, pal[0], null);
  for (const [bx, by, br] of blobs) if (by < cy + R0 * .2) E(bx - br * .28, by - br * .34, br * .48, br * .34, pal[3], null);
  for (let i = 0; i < specks; i++) { const a = r() * TAU, d = Math.sqrt(r()) * R0 * .85; E(cx + cos(a) * d * 1.1, cy + sin(a) * d * .8 - R0 * .1, 1.3, 1.1, i % 3 ? pal[4] : pal[1], null); }
}
function tree(X, Y, s = 1, kind = 'oak') {
  const r = SR(X * 13 + Y * 7 + (kind === 'apple' ? 5 : 0)), H = (58 + r() * 10) * s, R0 = (34 + r() * 6) * s, cy = Y - H - R0 * .5;
  const blobs = []; for (let i = 0; i < 20; i++) { const a = r() * TAU, d = Math.sqrt(r()) * R0 * .85; blobs.push([X + cos(a) * d * 1.18, cy + sin(a) * d * .82, (11 + r() * 8) * s]); }
  blobs.push([X, cy - R0 * .55, 14 * s], [X - R0 * .7, cy + R0 * .1, 13 * s], [X + R0 * .72, cy + R0 * .05, 13 * s]);
  blobs.sort((a, b) => a[1] - b[1]);
  const fruit = []; if (kind === 'apple' || kind === 'blossom') for (let i = 0; i < 9; i++) { const a = r() * TAU, d = (.3 + r() * .6) * R0; fruit.push([X + cos(a) * d * 1.1, cy + sin(a) * d * .75]); }
  return { y: Y, solid: [X - 8 * s, Y - 10, 16 * s, 10], draw() {
    const pal = LEAF(); shadow(X, Y, 36 * s, 8 * s, .3);
    // ствол: сужается кверху, корни, кора, ветки в крону
    PG([X - 8 * s, Y, X - 13 * s, Y + 1, X - 5 * s, Y - 8 * s, X - 4.5 * s, Y - H, X + 4.5 * s, Y - H, X + 5 * s, Y - 8 * s, X + 13 * s, Y + 1, X + 8 * s, Y], '#7a5032');
    R(X + 1 * s, Y - H, 3.5 * s, H - 4 * s, '#5e3c24', null);
    for (let i = 0; i < 4; i++) LN(X - 2 * s + (i % 2) * 2 * s, Y - 10 * s - i * 11 * s, X - 2 * s + (i % 2) * 2 * s, Y - 16 * s - i * 11 * s, '#4a2e1a', 1);
    LN(X, Y - H + 6 * s, X - 16 * s, Y - H - 14 * s, '#6a4228', 3.2 * s); LN(X + 1, Y - H + 4 * s, X + 14 * s, Y - H - 18 * s, '#6a4228', 2.6 * s);
    canopy(blobs, pal, SR(X * 3 + 1), 22, X, cy, R0);
    for (const [fx, fy] of fruit) if (kind === 'apple') { E(fx, fy, 2.6, 2.6, '#d8352e', OL, .8); E(fx - .8, fy - .8, .8, .8, '#ff9a8a', null); } else { E(fx, fy, 2.2, 2.2, '#ffc8e0', null); E(fx, fy, .9, .9, '#ff7ab0', null); }
  } };
}
function pine(X, Y, s = 1) { return { y: Y, solid: [X - 6 * s, Y - 8, 12 * s, 8], draw() {
  const pal = LEAF(); shadow(X, Y, 22 * s, 6 * s, .3); R(X - 4 * s, Y - 18 * s, 8 * s, 18 * s, '#6a4228', OL, 1);
  for (let i = 0; i < 4; i++) { const w = (30 - i * 6) * s, y0 = Y - 14 * s - i * 20 * s, h = 30 * s; PG([X - w, y0, X + w, y0, X, y0 - h], pal[1 + (i % 2)], OL, 1.2); PG([X - w * .2, y0 - h * .2, X + w * .85, y0 - 1, X + w * .1, y0 - 1], pal[0], null); PG([X - w * .7, y0 - 2, X - w * .15, y0 - h * .55, X - w * .05, y0 - 2], pal[3], null); }
} }; }
function bush(X, Y, s = 1, flowers) {
  const r = SR(X * 5 + Y), blobs = []; for (let i = 0; i < 7; i++) blobs.push([X + (r() - .5) * 34 * s, Y - 8 * s - r() * 10 * s, (8 + r() * 5) * s]); blobs.sort((a, b) => a[1] - b[1]);
  const fl = []; if (flowers) for (let i = 0; i < 7; i++) fl.push([X + (r() - .5) * 32 * s, Y - 6 * s - r() * 16 * s]);
  return { y: Y, solid: [X - 14 * s, Y - 6, 28 * s, 6], draw() { const pal = LEAF(); shadow(X, Y, 22 * s, 5 * s, .28); canopy(blobs, pal, SR(X), 8, X, Y - 12 * s, 16 * s); for (const [fx, fy] of fl) { E(fx, fy, 2, 2, flowers, null); E(fx, fy, .8, .8, '#fff6a0', null); } } };
}
// мелочи для фона (рисуются в кэш фона)
function tufts(X0, X1, Y0, Y1, n, seed = 1) { const r = SR(seed * 31 + X0); const c = isEve() ? ['#2a5a2a', '#3e7a36'] : ['#3e8a36', '#7cc35a']; for (let i = 0; i < n; i++) { const tx_ = X0 + r() * (X1 - X0), ty_ = Y0 + r() * (Y1 - Y0), k = r() < .5 ? 0 : 1; LN(tx_, ty_, tx_ - 2, ty_ - 5, c[k], 1.2); LN(tx_, ty_, tx_ + .5, ty_ - 6, c[k], 1.2); LN(tx_, ty_, tx_ + 3, ty_ - 4, c[k], 1.2); } }
function flowers(X0, X1, Y0, Y1, n, seed = 1, cols = ['#ff6a8a', '#ffd84a', '#ffffff', '#b07aff', '#ff9a3a']) { const r = SR(seed * 17 + X0); for (let i = 0; i < n; i++) { const fx = X0 + r() * (X1 - X0), fy = Y0 + r() * (Y1 - Y0), c = cols[(r() * cols.length) | 0]; LN(fx, fy, fx, fy + 4, '#3e8a36', 1); for (let k = 0; k < 4; k++) E(fx + cos(k * PI / 2) * 1.6, fy + sin(k * PI / 2) * 1.6, 1.3, 1.3, c, null); E(fx, fy, .9, .9, '#ffe066', null); } }
function rock(X, Y, s = 1) { E(X, Y, 7 * s, 4.5 * s, '#8a8a86', OL, 1); E(X - 2 * s, Y - 1.5 * s, 3 * s, 1.6 * s, '#b0b0aa', null); }
// дальняя полоса леса на горизонте (два плана, с бликами)
function treeLine(w, yb, seed = 3) {
  const r = SR(seed), back = isEve() ? '#22402a' : '#4a8048', front = isEve() ? '#2c4e30' : '#5a9450', hi = isEve() ? '#3a6040' : '#78ae64';
  for (let xx = -20; xx < w + 40; xx += 26 + r() * 16) { const h = 34 + r() * 26; E(xx, yb - h * .5, 22 + r() * 10, h * .62, back, null); }
  for (let xx = -10; xx < w + 40; xx += 22 + r() * 14) { const h = 24 + r() * 18, cx = xx; E(cx, yb - h * .45, 18 + r() * 8, h * .55, front, null); E(cx - 5, yb - h * .62, 7, 5, hi, null); }
}
// аккуратная вывеска-иконка магазина (круглый значок)
function shopIcon(X, Y, kind, col) {
  E(X, Y, 15, 15, '#1a1a22', OL, 1.4); E(X, Y, 12.5, 12.5, col, null); E(X, Y, 12.5, 12.5, null, 'rgba(255,255,255,.35)', 1);
  if (kind === 'pizza') { PG([X - 7, Y - 5, X + 7, Y - 5, X, Y + 8], '#f6c85a', OL, 1); R(X - 7, Y - 7, 14, 3, '#c9893a', OL, .8); for (const [a, b] of [[-3, -2], [2, -1], [0, 3]]) E(X + a, Y + b, 1.6, 1.6, '#d33', null); }
  else if (kind === 'game') { RR(X - 8, Y - 4, 16, 9, 3, '#e8e8f0', OL, 1); LN(X - 5, Y, X - 2, Y, '#333', 1.4); LN(X - 3.5, Y - 1.5, X - 3.5, Y + 1.5, '#333', 1.4); E(X + 3, Y - 1, 1.2, 1.2, '#e33', null); E(X + 5, Y + 1, 1.2, 1.2, '#3a7aff', null); }
  else if (kind === 'coffee') { RR(X - 6, Y - 3, 10, 10, 2, '#fff', OL, 1); E(X + 5, Y + 1, 2.6, 2.6, null, OL, 1.2); R(X - 5, Y - 2, 8, 2, '#7a4a2a', null); QL(X - 3, Y - 6, X - 1, Y - 9, X - 3, Y - 12, '#fff', 1); QL(X + 1, Y - 6, X + 3, Y - 9, X + 1, Y - 12, '#fff', 1); }
  else if (kind === 'box') { R(X - 7, Y - 5, 14, 11, '#d0a050', OL, 1); LN(X - 7, Y - 1, X + 7, Y - 1, OL, 1); tx('?', X, Y + 6, 11, '#3a2a1a'); }
}
