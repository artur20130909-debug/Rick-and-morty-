/* ================= ПЕРСОНАЖИ: модели в стиле мультсериала, позы, эмоции ================= */
const CH = {};
const CHDEF = {
  skin: '#f7d2ae', shoeH: 3, leg: 24, legW: 7, hipW: 14, pants: '#3a4a6a', shoe: '#2e2a2a', shoeK: 'shoe',
  torso: 24, shW: 22, waist: 18, shirt: '#8899aa', top: 'tee', sleeve: 'short', sleeveC: null,
  arm: 21, armW: 4.8, neck: 3, neckW: 6, hw: 22, hh: 24, jaw: .72, chin: .42, cheek: 0,
  eyeR: 4, eyeGap: 4.3, eyeY: -1, pup: 1.05, hair: '#5a3a22', hk: 'short', lash: 0, brow: 'thin', nose: 'line', mouth: 'smile',
  mouthY: 8, mouthW: 5, ear: 1, pose: 'idle', emo: 'n', glasses: 0, voice: 'student', seed: 0,
};
function defChar(id, d) { CH[id] = Object.assign({}, CHDEF, d, { id, seed: Object.keys(CH).length * 1.7 + 1 }); }

defChar('morty', { name: 'Морти', voice: 'morty', skin: '#f8d3b0', leg: 22, legW: 7.4, hipW: 13, pants: '#2f4c80', shoe: '#f4f4f2', shoeK: 'sneaker',
  torso: 22, shW: 20, waist: 18, shirt: '#f2df55', arm: 20, armW: 4.8, neck: 1.5, neckW: 6, hw: 26, hh: 24.5, jaw: .78, chin: .5, cheek: -.05,
  eyeR: 4.7, eyeGap: 4.5, eyeY: -.5, pup: 1.05, hair: '#6b4424', hk: 'morty', brow: 'none', nose: 'morty', mouth: 'wavy', mouthY: 8.2, mouthW: 4 });
defChar('evil', { name: 'Злой Морти', voice: 'evil', skin: '#f8d3b0', leg: 22, legW: 7.4, hipW: 13, pants: '#25365e', shoe: '#f4f4f2', shoeK: 'sneaker',
  torso: 22, shW: 20, waist: 18, shirt: '#e2e86c', arm: 20, armW: 4.8, neck: 1.5, neckW: 6, hw: 26, hh: 24.5, jaw: .78, chin: .5, cheek: -.05,
  eyeR: 4.7, eyeGap: 4.5, eyeY: -.5, pup: 1.05, hair: '#674326', hk: 'morty', brow: 'thin', nose: 'morty', mouth: 'flat', mouthY: 8.2, mouthW: 4, pose: 'hips', emo: 'angry', patch: 1 });
defChar('rick', { name: 'Рик', voice: 'rick', skin: '#f2e2c8', leg: 34, legW: 7, hipW: 13, pants: '#7b5d3b', shoe: '#3a3534', shoeK: 'shoe',
  torso: 30, shW: 22, waist: 17, shirt: '#8fd3e6', top: 'coat', sleeve: 'long', sleeveC: '#f5f7f8', arm: 29, armW: 5, neck: 4, neckW: 5.5,
  hw: 22, hh: 26, jaw: .6, chin: .3, cheek: .05, eyeR: 4.1, eyeGap: 4.2, eyeY: -1.5, pup: .8, hair: '#a9dcea', hk: 'rick', brow: 'uni', nose: 'rick', mouth: 'rick', mouthY: 9.5, mouthW: 6, pose: 'gun', emo: 'tired' });
defChar('summer', { name: 'Саммер', voice: 'summer', skin: '#f6cfa6', leg: 32, legW: 7, hipW: 13, pants: '#f1f1ef', shoe: '#222', shoeK: 'flat',
  torso: 25, shW: 18, waist: 15, shirt: '#ec7cc8', top: 'tank', arm: 23, armW: 4.2, neck: 4, neckW: 5, hw: 22, hh: 24, jaw: .62, chin: .38,
  eyeR: 4.2, eyeGap: 4.4, eyeY: -1, pup: 1, hair: '#ea7a2e', hk: 'summer', lash: 1, brow: 'thin', nose: 'line', mouth: 'smile', mouthY: 8, mouthW: 4.2, pose: 'clasp' });
defChar('jerry', { name: 'Джерри', voice: 'jerry', skin: '#f1c9a1', leg: 31, legW: 8, hipW: 15, pants: '#93b4d6', shoe: '#3a3a3a', shoeK: 'shoe',
  torso: 27, shW: 25, waist: 22, shirt: '#5c7a37', top: 'polo', arm: 24, armW: 5, neck: 4, neckW: 7, hw: 25, hh: 27, jaw: .92, chin: .58, cheek: .05,
  eyeR: 4.5, eyeGap: 4.7, eyeY: -2, pup: .95, hair: '#7a5843', hk: 'jerry', brow: 'thin', nose: 'line', mouth: 'grin', mouthY: 9.5, mouthW: 6.5, pose: 'hips' });
defChar('beth', { name: 'Бет', voice: 'beth', skin: '#f6d6c4', leg: 33, legW: 7, hipW: 13, pants: '#2f4a92', shoe: '#efefef', shoeK: 'flat',
  torso: 25, shW: 19, waist: 15, shirt: '#ec6a50', top: 'blouse', arm: 23, armW: 4.2, neck: 5, neckW: 5, hw: 21, hh: 25, jaw: .55, chin: .3,
  eyeR: 4.2, eyeGap: 4.4, eyeY: -1.5, pup: .85, hair: '#f2cd6a', hk: 'beth', lash: 1, brow: 'arch', nose: 'line', mouth: 'lips', mouthY: 8.5, mouthW: 4.5, pose: 'behind' });
defChar('jessica', { name: 'Джессика', voice: 'jessica', skin: '#f8d8bb', leg: 26, legW: 6.8, hipW: 13, pants: '#405a9a', shoe: '#c0405a', shoeK: 'flat',
  torso: 22, shW: 18, waist: 15, shirt: '#c8a0e8', top: 'tank', arm: 21, armW: 4.2, neck: 3.5, neckW: 5, hw: 22, hh: 24, jaw: .6, chin: .36,
  eyeR: 4.2, eyeGap: 4.4, eyeY: -1, pup: 1, hair: '#d2562f', hk: 'long', lash: 1, nose: 'line', mouth: 'smile', mouthW: 4 });
defChar('ethan', { name: 'Итан', voice: 'ethan', skin: '#e8b98f', leg: 23, legW: 7.2, hipW: 13, pants: '#555b66', shoe: '#2a2a2a', shoeK: 'sneaker',
  torso: 22, shW: 21, waist: 18, shirt: '#4aa86a', arm: 20, armW: 4.8, hw: 24, hh: 24, eyeR: 4.2, hair: '#2a1a12', hk: 'curly', glasses: 1, nose: 'morty', mouth: 'smile' });
defChar('gold', { name: 'Мистер Голденфолд', voice: 'gold', skin: '#f3cfae', leg: 28, legW: 8, hipW: 15, pants: '#6e5a44', shoe: '#2a2220', shoeK: 'shoe',
  torso: 27, shW: 25, waist: 23, shirt: '#e9e3c9', top: 'shirt', tie: '#8a3a2a', sleeve: 'short', arm: 24, armW: 5, hw: 24, hh: 27, jaw: .85, chin: .5,
  eyeR: 3.6, eyeGap: 4, pup: .9, hair: '#c9a46a', hk: 'balding', nose: 'line', mouth: 'flat', mouthW: 5 });
defChar('principal', { name: 'Директор', voice: 'principal', skin: '#efc6a0', leg: 27, legW: 8, hipW: 15, pants: '#5a4634', shoe: '#2a2220',
  torso: 27, shW: 25, waist: 24, shirt: '#7a5a3a', top: 'suit', tie: '#2a4a7a', sleeve: 'long', sleeveC: '#7a5a3a', arm: 24, armW: 5.2, hw: 25, hh: 27, jaw: .9, chin: .55,
  eyeR: 3.4, eyeGap: 4.2, hair: '#7a6a5a', hk: 'bald', glasses: 1, mustache: '#6a5040', nose: 'line', mouth: 'flat' });
defChar('brad', { name: 'Брэд', voice: 'brad', skin: '#f0c49a', leg: 28, legW: 9, hipW: 17, pants: '#3a4a7a', shoe: '#efefef', shoeK: 'sneaker',
  torso: 27, shW: 30, waist: 24, shirt: '#b8302e', top: 'jacket', sleeve: 'long', sleeveC: '#efe9dc', arm: 25, armW: 6.2, neck: 4, neckW: 9, hw: 24, hh: 25, jaw: .95, chin: .65,
  eyeR: 3.4, eyeGap: 4.2, pup: 1, hair: '#e8c45a', hk: 'buzz', brow: 'thick', nose: 'line', mouth: 'smirk', mouthW: 5 });
defChar('tammy', { name: 'Тэмми', voice: 'jessica', skin: '#f8dcc4', leg: 27, legW: 6.6, hipW: 13, pants: '#2a2a3a', shoe: '#2a2a2a', shoeK: 'flat',
  torso: 22, shW: 18, waist: 15, shirt: '#f0f0f0', top: 'tee', arm: 21, armW: 4.2, hw: 22, hh: 24, eyeR: 4, lash: 1, hair: '#f2d77a', hk: 'long', mouth: 'smile' });
// безымянные ученики/граждане (генерируются)
const STU_C = { sh: ['#d9534f', '#5bc0de', '#9b59b6', '#f0ad4e', '#5cb85c', '#e67e22', '#34495e', '#e84393'], ha: ['#2a1a12', '#6b4a2a', '#e8c45a', '#b5502e', '#111', '#8a6a4a'], sk: ['#f7d2ae', '#e8b98f', '#c98e64', '#8d5a3a', '#f3cfae'], pa: ['#3a4a6a', '#555', '#2f4c80', '#6e5a44', '#222'] };
for (let i = 0; i < 10; i++) {
  const g = i % 2; defChar('stu' + i, { name: 'Ученик', voice: 'student', skin: STU_C.sk[(i * 3) % 5], leg: 22 + (i % 3) * 2, hipW: 13, pants: STU_C.pa[i % 5], shoe: '#333', shoeK: 'sneaker',
    torso: 21 + (i % 2), shW: 20, waist: 17, shirt: STU_C.sh[i % 8], top: g ? 'tank' : 'tee', arm: 20, hw: 23, hh: 24, eyeR: 4, lash: g, hair: STU_C.ha[(i * 5) % 6], hk: g ? (i % 4 === 1 ? 'pony2' : 'long') : ['short', 'curly', 'buzz', 'short', 'spiky'][i % 5], glasses: i === 4 || i === 7 ? 1 : 0, mouth: 'smile' });
}
// Рики и Морти Цитадели
const CIT_V = [['#8fd3e6', '#a9dcea', null], ['#c9a46a', '#d8d8d8', 'cowboy'], ['#5a6a8a', '#e0e0e0', 'beret'], ['#d06060', '#a9dcea', null], ['#4a4a4a', '#9ad0e0', 'helmet']];
CIT_V.forEach((v, i) => defChar('crick' + i, Object.assign({}, CH.rick, { name: 'Рик', voice: 'rick', shirt: v[0], hair: v[1], hat: v[2], pose: 'idle', emo: i % 2 ? 'n' : 'tired', top: i === 4 ? 'armor' : 'coat' })));
const CIT_M = [['#f2df55', null], ['#e88a8a', 'cap'], ['#8ad08a', null], ['#f2df55', 'helmet'], ['#9ac0f0', 'cap']];
CIT_M.forEach((v, i) => defChar('cmorty' + i, Object.assign({}, CH.morty, { name: 'Морти', voice: 'mortyg', shirt: v[0], hat: v[1], pose: 'idle', mouth: i % 2 ? 'flat' : 'wavy' })));
CH.crick4.name = 'Рик-охранник'; CH.crick4.voice = 'guard'; CH.cmorty3.name = 'Морти-охранник';

/* ---------- геометрия и части тела ---------- */
function geo(d, o) {
  const mov = !!o.mov, ph = o.ph || 0;
  const bob = d.id === 'statue' ? 0 : mov ? -abs(sin(ph)) * 1.3 : sin(T / 24 + d.seed) * .45;
  const sit = !!o.sit, legL = sit ? d.leg * .55 : d.leg;
  const hipY = -(d.shoeH + legL) + (mov ? bob * .4 : 0);
  const shY = hipY - d.torso + (mov ? bob * .6 : bob);
  const chinY = shY - d.neck + 1.5, hcy = chinY - d.hh / 2;
  return { mov, ph, bob, sit, hipY, shY, chinY, hcy };
}
const POSES = {
  idle: (d, g, s) => [s * (d.shW / 2 + 1.5), g.shY + d.arm * .5, s * (d.shW / 2 + 2.2), g.shY + d.arm * .98],
  hips: (d, g, s) => [s * (d.shW / 2 + 8), g.shY + d.arm * .48, s * (d.waist / 2 + .5), g.hipY + 1],
  behind: (d, g, s) => [s * (d.shW / 2 + 3.2), g.shY + d.arm * .5, s * (d.waist / 2 - 3.5), g.hipY - 1],
  clasp: (d, g, s) => [s * (d.shW / 2 + 1), g.shY + d.arm * .52, s * 1.2, g.hipY + 3],
  shrug: (d, g, s) => [s * (d.shW / 2 + 6), g.shY + d.arm * .5, s * (d.shW / 2 + 11), g.shY + d.arm * .2],
  up: (d, g, s) => [s * (d.shW / 2 + 6), g.shY - 2, s * (d.shW / 2 + 8 + sin(T / 4 + s) * 1.5), g.shY - d.arm * .7],
  cross: (d, g, s) => [s * (d.shW / 2 + 1.5), g.shY + d.arm * .55, -s * (d.shW / 4), g.shY + d.arm * .42],
  fists: (d, g, s) => [s * (d.shW / 2 + 3), g.shY + d.arm * .5, s * (d.shW / 2 + 3.5), g.shY + d.arm * .9],
};
// поза «на одну руку»: правая (s=+1) рука особая, левая обычная
const ONEARM = {
  gun: (d, g) => [d.shW / 2 + 6, g.shY + 3, d.shW / 2 + 6.5, g.shY - d.arm * .5],
  wave: (d, g) => [d.shW / 2 + 7, g.shY - 1, d.shW / 2 + 9 + sin(T / 5) * 3.5, g.shY - d.arm * .62],
  point: (d, g) => [d.shW / 2 + d.arm * .48, g.shY + 3, d.shW / 2 + d.arm * .98, g.shY + 1.5],
  think: (d, g) => [d.shW / 2 + 4, g.shY + d.arm * .55, 3, g.chinY + 1],
  phone: (d, g) => [d.shW / 2 + 3, g.shY + d.arm * .55, d.shW / 2 - 2, g.shY + d.arm * .25],
  drink: (d, g) => [d.shW / 2 + 4, g.shY + d.arm * .5, 4, g.chinY + 3],
};

function drawChar(id, X, Y, o = {}) {
  const d = CH[id]; if (!d) return;
  if (d.draw) return d.draw(X, Y, o);
  const sc = o.sc || 1, dir = o.dir || 'd', view = dir === 'u' ? 'u' : (dir === 'l' || dir === 'r') ? 's' : 'd';
  x.save(); x.translate(X, Y);
  if (!o.noShadow) shadow(0, 0, d.hipW * .95 * sc, 3.2 * sc, .25);
  x.scale(sc * (dir === 'l' ? -1 : 1), sc);
  if (o.alpha != null) x.globalAlpha = o.alpha;
  const g = geo(d, o), pose = o.pose || (g.mov ? 'idle' : d.pose), emo = o.emo || d.emo;
  if (view === 's') sideBody(d, g, o, pose, emo); else frontBody(d, g, o, pose, emo, view === 'u');
  x.restore();
}

/* ---------- ноги и обувь ---------- */
function shoeF(d, fx, fy) {
  const k = d.shoeK;
  if (k === 'sneaker') { RR(fx - d.legW * .78, fy - 3.4, d.legW * 1.56, 3.8, 1.8, d.shoe); LN(fx - d.legW * .6, fy - .6, fx + d.legW * .6, fy - .6, 'rgba(0,0,0,.18)', .8); }
  else if (k === 'flat') E(fx, fy - 1.3, d.legW * .62, 1.8, d.shoe);
  else E(fx, fy - 1.6, d.legW * .75, 2.3, d.shoe);
}
function legsFront(d, g, back) {
  const hx = d.hipW / 4.2, sw = g.mov ? sin(g.ph) : 0;
  if (g.sit) {
    for (const s of [-1, 1]) { const kx = s * hx * 1.15; limb([kx, g.hipY + 3, kx, -2.5], d.legW, d.pants); shoeF(d, kx, 0); E(kx, g.hipY + 2.5, d.legW * .62, 3.5, d.pants); }
    return;
  }
  for (const s of [-1, 1]) {
    const lift = g.mov ? Math.max(0, s * sw) * 3 : 0, fx = s * hx * 1.05;
    limb([s * hx, g.hipY + 1, fx, -2.6 - lift], d.legW, d.pants);
    shoeF(d, fx, -lift);
  }
  if (d.top !== 'coat') { x.save(); RR(-d.hipW / 2, g.hipY - 1, d.hipW, 5, 2, d.pants, null); x.restore(); }
  if (!back && d.top !== 'coat' && d.top !== 'blouse' && d.top !== 'jacket') LN(0, g.hipY + 2, 0, g.hipY + 5, 'rgba(0,0,0,.25)', .8);
}
function legsSide(d, g) {
  const st = d.leg * .22;
  const leg = (a, col, near) => {
    if (g.sit) { const kx = d.leg * .5; limb([0, g.hipY + 1, kx, g.hipY + 1.5, kx + 1, -2.5], d.legW, col); shoeSide(d, kx + 1, 0, col); return; }
    const fx = g.mov ? sin(a) * st : (near ? 1 : -1), lift = g.mov ? Math.max(0, cos(a)) * 2.6 : 0;
    const kx = fx * .5 + (g.mov ? 1.4 : .3), ky = g.hipY + d.leg * .5;
    limb([0, g.hipY + 1, kx, ky, fx, -2.6 - lift], d.legW * .92, col);
    shoeSide(d, fx, -lift);
  };
  leg(g.ph + PI, shade(d.pants, -.18), 0); leg(g.ph, d.pants, 1);
}
function shoeSide(d, fx, fy) {
  if (d.shoeK === 'sneaker') RR(fx - d.legW * .55, fy - 3.4, d.legW * 1.5, 3.6, [2, 2.5, 1.5, 1.5], d.shoe);
  else if (d.shoeK === 'flat') E(fx + 1.4, fy - 1.3, d.legW * .8, 1.7, d.shoe);
  else E(fx + 1.8, fy - 1.7, d.legW * .95, 2.3, d.shoe);
}

/* ---------- торс ---------- */
function torsoPath(d, g, wMul = 1) {
  const sw = d.shW / 2 * wMul, ww = d.waist / 2 * wMul, y0 = g.shY, y1 = g.hipY + 3;
  x.moveTo(-sw + 3, y0); x.quadraticCurveTo(-sw - .5, y0 + .5, -sw, y0 + 5);
  x.lineTo(-ww, y1); x.quadraticCurveTo(0, y1 + 1.2, ww, y1); x.lineTo(sw, y0 + 5);
  x.quadraticCurveTo(sw + .5, y0 + .5, sw - 3, y0); x.closePath();
}
function torsoFront(d, g, back, wMul = 1) {
  const top = d.top, y0 = g.shY;
  // шея
  RR(-d.neckW / 2, g.chinY - 3, d.neckW, y0 - g.chinY + 5, 2, d.skin);
  if (top === 'tank') { // плечи кожей, майка на бретелях
    path(() => torsoPath(d, g, wMul), d.skin);
    const sw = d.shW / 2 * wMul, ww = d.waist / 2 * wMul, y1 = g.hipY + 3;
    PG([-sw + 2.5, y0 + 6, -sw + 4, y0 + .5, -sw + 6, y0 + .5, -d.neckW / 2 - 1, y0 + (back ? 1 : 5.5), d.neckW / 2 + 1, y0 + (back ? 1 : 5.5), sw - 6, y0 + .5, sw - 4, y0 + .5, sw - 2.5, y0 + 6, ww, y1, -ww, y1], d.shirt);
    if (!back) { QL(-5, y0 + 9, -3, y0 + 11, -1, y0 + 10, 'rgba(0,0,0,.25)', .8); QL(5, y0 + 9, 3, y0 + 11, 1, y0 + 10, 'rgba(0,0,0,.25)', .8); }
    return;
  }
  if (top === 'coat') {
    path(() => torsoPath(d, g, wMul * .92), d.shirt);
    if (!back) { R(-d.waist / 2 + 2, g.hipY - 1.5, d.waist - 4, 3, '#6a4a2a', OL, .8); R(-1.6, g.hipY - 1.6, 3.2, 3.2, '#e9c25a', OL, .6); }
    return;
  }
  if (top === 'armor') { path(() => torsoPath(d, g, wMul), '#3a3f4a'); if (!back) { RR(-d.waist / 2 + 1, y0 + 4, d.waist - 2, d.torso - 8, 2, '#4a515e', OL, .8); R(-d.waist / 2, g.hipY - 1.5, d.waist, 3, '#22262e'); } return; }
  path(() => torsoPath(d, g, wMul), d.shirt);
  x.save(); x.beginPath(); torsoPath(d, g, wMul); x.clip();
  if (top === 'polo') { // полосы Джерри
    R(-20, y0 + 7.5, 40, 2.6, '#8a5a2c', OL, .7); R(-20, y0 + 10.1, 40, 2.2, '#d9b88c', OL, .7);
  }
  if (top === 'jacket') { R(-20, g.hipY - 1, 40, 4, '#efe9dc'); if (!back) { R(-1, y0, 2, d.torso, 'rgba(0,0,0,.25)'); E(-5, y0 + 8, 2.6, 3, '#efe9dc', null); txo('Х', -5, y0 + 10, 4, '#b8302e', 'center', '#efe9dc', .1); } }
  x.fillStyle = 'rgba(0,0,0,.07)'; x.fillRect(-20, g.hipY - 3, 40, 8);
  x.restore();
  if (back) return;
  if (top === 'tee') { path(() => x.ellipse(0, y0 + .2, d.neckW / 2 + 1.2, 2.6, 0, 0, PI), d.skin); }
  else if (top === 'polo') {
    path(() => x.ellipse(0, y0 + .2, d.neckW / 2 + .6, 2, 0, 0, PI), d.skin);
    PG([-d.neckW / 2 - 2.2, y0 - .4, -.4, y0 + 4.6, -2.2, y0 + 4.2, -d.neckW / 2 - 1.2, y0 + 3], d.shirt, OL, .9); PG([d.neckW / 2 + 2.2, y0 - .4, .4, y0 + 4.6, 2.2, y0 + 4.2, d.neckW / 2 + 1.2, y0 + 3], d.shirt, OL, .9);
  } else if (top === 'blouse') {
    PG([-d.neckW / 2 - .5, y0 - .5, 0, y0 + 10, d.neckW / 2 + .5, y0 - .5], d.skin, OL, .9);
    PG([-d.neckW / 2 - 2.5, y0 - .8, -1.2, y0 + 8, -3.2, y0 + 6.5, -d.neckW / 2 - 3.2, y0 + 3], d.shirt, OL, .9); PG([d.neckW / 2 + 2.5, y0 - .8, 1.2, y0 + 8, 3.2, y0 + 6.5, d.neckW / 2 + 3.2, y0 + 3], d.shirt, OL, .9);
    QL(-6, y0 + 11, -3.5, y0 + 13.5, -.8, y0 + 12, 'rgba(0,0,0,.35)', .8); QL(6, y0 + 11, 3.5, y0 + 13.5, .8, y0 + 12, 'rgba(0,0,0,.35)', .8);
    PG([-1.5, g.hipY + 3.5, 0, g.hipY - 1.5, 1.5, g.hipY + 3.5], d.skin, OL, .7);
  } else if (top === 'shirt' || top === 'suit') {
    if (top === 'suit') { PG([-d.neckW / 2 - 1, y0, 0, y0 + 12, d.neckW / 2 + 1, y0], '#f2f2f2', OL, .8); PG([-d.neckW / 2 - 1, y0, -4, y0 + 9, 0, y0 + 13], null, OL, .8); PG([d.neckW / 2 + 1, y0, 4, y0 + 9, 0, y0 + 13], null, OL, .8); }
    else { PG([-d.neckW / 2 - 1.5, y0 - .3, 0, y0 + 3.5, d.neckW / 2 + 1.5, y0 - .3], d.shirt, OL, .8); }
    if (d.tie) PG([-1.2, y0 + 2, 1.2, y0 + 2, 1.8, y0 + 12, 0, y0 + 14, -1.8, y0 + 12], d.tie, OL, .7);
  } else if (top === 'jacket') { path(() => x.ellipse(0, y0 + .2, d.neckW / 2 + 1, 2.4, 0, 0, PI), d.skin); }
}
function coatFront(d, g, back) { // халат Рика поверх тела
  const sw = d.shW / 2 + .5, y0 = g.shY, yb = g.hipY + d.leg * .58, c = d.sleeveC;
  if (back) { PG([-sw + 2, y0, sw - 2, y0, sw + .5, y0 + 5, sw + 3.5, yb, -sw - 3.5, yb, -sw - .5, y0 + 5], c); LN(0, g.hipY, 0, yb, 'rgba(0,0,0,.2)', .8); return; }
  PG([-sw + 2, y0, -d.neckW / 2 - .5, y0, -d.neckW / 2 + .8, y0 + 6, -4.5, g.hipY + 4, -5.5, yb, -sw - 3.5, yb, -sw - .5, y0 + 5], c);
  PG([sw - 2, y0, d.neckW / 2 + .5, y0, d.neckW / 2 - .8, y0 + 6, 4.5, g.hipY + 4, 5.5, yb, sw + 3.5, yb, sw + .5, y0 + 5], c);
  PG([-d.neckW / 2 - .5, y0, -d.neckW / 2 - 3.5, y0 + 2, -4, y0 + 9, -d.neckW / 2 + .8, y0 + 6], shade(c, -.06), OL, .8);
  PG([d.neckW / 2 + .5, y0, d.neckW / 2 + 3.5, y0 + 2, 4, y0 + 9, d.neckW / 2 - .8, y0 + 6], shade(c, -.06), OL, .8);
  LN(-sw + 1.5, g.hipY - 2, -sw + 5.5, g.hipY - 2, '#c9d2d8', .9); LN(sw - 1.5, g.hipY - 2, sw - 5.5, g.hipY - 2, '#c9d2d8', .9);
  PG([-5.5, yb, -sw - 3.5, yb, -sw - 3, yb - 2.5], 'rgba(200,225,215,.7)', null);
}

/* ---------- руки ---------- */
function armDraw(d, sx, sy, ex, ey, hx, hy, dark) {
  const sk = dark ? shade(d.skin, -.12) : d.skin, sl = d.sleeveC || d.shirt, slc = dark ? shade(sl, -.12) : sl;
  limb([sx, sy, ex, ey, hx, hy], d.armW, sk);
  if (d.top === 'tank') { } // голые плечи
  else if (d.sleeve === 'long') { const k = .82; limb([sx, sy, ex, ey, ex + (hx - ex) * k, ey + (hy - ey) * k], d.armW + 1.8, slc); }
  else {
    const L = hyp(ex - sx, ey - sy) || 1, ux = (ex - sx) / L, uy = (ey - sy) / L, nx = -uy, ny = ux, k = L * .5, w0 = (d.armW + 3.6) / 2, w1 = (d.armW + 2.4) / 2;
    const ax = sx - ux * 2.5, ay = sy - uy * 2.5, bx = sx + ux * k, by = sy + uy * k;
    PG([ax + nx * w0, ay + ny * w0, bx + nx * w1, by + ny * w1, bx - nx * w1, by - ny * w1, ax - nx * w0, ay - ny * w0], dark ? shade(d.shirt, -.12) : d.shirt);
  }
  E(hx, hy, d.armW * .62, d.armW * .7, sk, OL, LW * .9);
}
function frontBody(d, g, o, pose, emo, back) {
  const sy = g.shY + 3, sx = d.shW / 2 - d.armW * .35;
  const one = ONEARM[pose], two = POSES[pose] || POSES.idle;
  const armPos = s => {
    if (one && s === 1) return one(d, g);
    const p = (one ? POSES.idle : two)(d, g, s);
    if (g.mov && !back) { const k = sin(g.ph) * s * 1.6; p[1] += k * .4; p[3] += k; }
    if (g.mov && back) { const k = sin(g.ph) * s * 1.6; p[3] -= k; }
    return p;
  };
  const behind = pose === 'behind' && !back;
  if (back) {
    // сзади: волосы-хвост рисуются после
    hairBack(d, g, 'u', true);
  } else hairBack(d, g, 'd', true);
  if (behind) for (const s of [-1, 1]) { const p = armPos(s); armDraw(d, s * sx, sy, p[0], p[1], p[2], p[3], 1); }
  legsFront(d, g, back);
  torsoFront(d, g, back);
  if (d.top === 'coat' || (d.top === 'armor' && 0)) coatFront(d, g, back);
  if (!behind) {
    const order = pose === 'cross' ? [1, -1] : [-1, 1];
    for (const s of order) {
      const p = armPos(s);
      armDraw(d, s * sx, sy, p[0], p[1], p[2], p[3], 0);
      if (s === 1 && pose === 'gun' && !back) portalGun(p[2], p[3], 0);
      if (s === 1 && pose === 'phone' && !back) { RR(p[2] - 2, p[3] - 7, 4, 7, 1, '#222'); R(p[2] - 1.3, p[3] - 6.2, 2.6, 5, '#7ad0ff'); }
      if (s === 1 && pose === 'drink' && !back) { RR(p[2] - 2, p[3] - 3, 4.2, 6, 1, '#7a4a2a'); }
    }
  }
  head(d, g, back ? 'u' : 'd', o, emo);
}
function sideBody(d, g, o, pose, emo) {
  const sy = g.shY + 3, ax = 1;
  const sw = g.mov ? sin(g.ph) * .55 : 0;
  const armA = (a, bend = .25) => { const ex = ax + sin(a) * d.arm * .5, ey = sy + cos(a) * d.arm * .5, hx = ex + sin(a + bend) * d.arm * .5, hy = ey + cos(a + bend) * d.arm * .5; return [ex, ey, hx, hy]; };
  hairBack(d, g, 's', true);
  let p = armA(-sw - .05); armDraw(d, ax - 1, sy, p[0], p[1], p[2], p[3], 1);
  legsSide(d, g);
  // торс сбоку (узкий)
  const wm = .7;
  RR(-d.neckW / 2 + 1, g.chinY - 3, d.neckW, g.shY - g.chinY + 5, 2, d.skin);
  if (d.top === 'tank') { path(() => torsoPath(d, g, wm), d.skin); x.save(); x.beginPath(); torsoPath(d, g, wm); x.clip(); R(-20, g.shY + 4, 40, 40, d.shirt, OL); R(-1, g.shY - 1, 2.5, 6, d.shirt); x.restore(); path(() => torsoPath(d, g, wm), null); }
  else {
    path(() => torsoPath(d, g, wm), d.top === 'coat' ? d.shirt : d.top === 'armor' ? '#3a3f4a' : d.shirt);
    if (d.top === 'polo') { x.save(); x.beginPath(); torsoPath(d, g, wm); x.clip(); R(-20, g.shY + 7.5, 40, 2.6, '#8a5a2c', OL, .7); R(-20, g.shY + 10.1, 40, 2.2, '#d9b88c', OL, .7); x.restore(); }
    if (d.top === 'blouse') PG([2, g.shY, 6, g.shY + 7, 4.5, g.shY], d.skin, OL, .8);
    if (d.tie) PG([5, g.shY + 2, 7, g.shY + 2, 7.5, g.shY + 12, 5.5, g.shY + 13], d.tie, OL, .7);
  }
  if (d.top === 'coat') { const c = d.sleeveC, yb = g.hipY + d.leg * .58; PG([-d.shW * .36, g.shY + 1, 2, g.shY, 4.5, g.shY + 8, 6, yb - 2, 3 + sw * 3, yb, -d.shW * .36 - 4 + sw * 2, yb, -d.shW * .38, g.shY + 6], c); }
  // ближняя рука
  if (pose === 'gun') { p = [ax + 7, sy + 2, ax + 9, sy - d.arm * .45]; armDraw(d, ax, sy, p[0], p[1], p[2], p[3], 0); portalGun(p[2], p[3], 0); }
  else if (pose === 'point') { p = [ax + d.arm * .5, sy + 1, ax + d.arm, sy]; armDraw(d, ax, sy, p[0], p[1], p[2], p[3], 0); }
  else if (pose === 'phone') { p = [ax + 5, sy + d.arm * .45, ax + 7, sy + d.arm * .1]; armDraw(d, ax, sy, p[0], p[1], p[2], p[3], 0); RR(p[2] - 1, p[3] - 7, 4, 7, 1, '#222'); }
  else if (pose === 'hips') { p = [ax - 6, sy + d.arm * .45, ax - 1, g.hipY]; armDraw(d, ax, sy, p[0], p[1], p[2], p[3], 0); }
  else if (pose === 'behind' || pose === 'clasp') { p = pose === 'clasp' ? [ax + 1, sy + d.arm * .5, ax + 5, g.hipY + 2] : [ax - 2, sy + d.arm * .5, ax - 6, g.hipY]; armDraw(d, ax, sy, p[0], p[1], p[2], p[3], 0); }
  else { p = armA(sw + .05); armDraw(d, ax, sy, p[0], p[1], p[2], p[3], 0); }
  head(d, g, 's', o, emo);
}
function portalGun(hx, hy, k) {
  x.save(); x.translate(hx, hy);
  RR(-2.4, -10, 4.8, 13, 1.2, '#d6dade'); R(-2.4, -6, 4.8, 2, '#9aa3a8', OL, .6);
  glow('#7dff5a', 6, () => { RR(-1.6, -14, 3.2, 5, 1.2, '#7dff5a', OL, .7); });
  E(0, -12.2, .7, 1.2, '#eaffd8', null);
  x.restore();
}

/* ---------- голова ---------- */
function headPath(d) {
  const a = d.hw / 2, b = d.hh / 2;
  x.moveTo(0, b);
  x.bezierCurveTo(a * d.chin, b, a * d.jaw, b * .92, a * .98, b * d.cheek);
  x.bezierCurveTo(a * 1.04, -b * .62, a * .74, -b, 0, -b);
  x.bezierCurveTo(-a * .74, -b, -a * 1.04, -b * .62, -a * .98, b * d.cheek);
  x.bezierCurveTo(-a * d.jaw, b * .92, -a * d.chin, b, 0, b);
}
function head(d, g, v, o, emo) {
  x.save(); x.translate(0, g.hcy);
  const a = d.hw / 2, b = d.hh / 2;
  // уши
  if (d.ear && d.hk !== 'beth') {
    const ey = d.eyeY + 2.5;
    const ear = sx => { E(sx * (a - .5), ey, 2.6, 3.8, d.skin); QL(sx * (a - .3), ey - 1.6, sx * (a + 1.2), ey, sx * (a - .3), ey + 1.6, 'rgba(0,0,0,.3)', .8); };
    if (v === 'd' || v === 'u') { ear(-1); ear(1); } else ear(-1);
  }
  path(() => headPath(d), d.skin);
  if (v !== 'u') face(d, v, o, emo);
  hairFront(d, v, o);
  if (d.patch && v !== 'u') eyePatch(d, v);
  if (d.hat) hat(d, v);
  x.restore();
}
function eyePatch(d, v) {
  const k = v === 's' ? 1 : 0, fx = k * d.hw * .16, ex = fx - d.eyeGap * (k ? .8 : 1), ey = d.eyeY;
  LN(ex - 3, ey - 2, -d.hw / 2 + .5, ey - 3.5, '#111', 1.2); LN(ex + 2, ey - 3, d.hw * .38, -d.hh * .45, '#111', 1.2);
  Er(ex, ey + .4, d.eyeR * 1.02 * (k ? .85 : 1), d.eyeR * .92, -.15, '#151515', '#000', LW);
  E(ex - 1.2, ey - 1.2, 1.2, .6, 'rgba(255,255,255,.25)', null);
}
function hat(d, v) {
  const a = d.hw / 2, b = d.hh / 2;
  if (d.hat === 'cowboy') { E(0, -b * .55, a * 1.6, 3, '#8a5a2a'); RR(-a * .7, -b - 6, a * 1.4, 8, 3, '#9a6a3a'); }
  else if (d.hat === 'beret') E(-2, -b * .8, a * 1.05, 4.5, '#2a2a3a');
  else if (d.hat === 'cap') { path(() => x.ellipse(0, -b * .45, a * 1.02, b * .7, 0, PI, 0), '#d04040'); E(v === 's' ? a * .8 : 0, -b * .4, v === 's' ? a * .7 : a * .9, 2, '#b03030'); }
  else if (d.hat === 'helmet') { path(() => x.ellipse(0, -b * .3, a * 1.12, b * .9, 0, PI, 0), '#3a3f4a'); R(-a * 1.1, -b * .32, a * 2.2, 2.4, '#22262e'); }
}
function face(d, v, o, emo) {
  const k = v === 's' ? 1 : 0, fx = k * d.hw * .17, ey = d.eyeY, r = d.eyeR;
  const talk = o.talk && ((T / 3.4 | 0) % 2 === 0);
  const blink = d.id !== 'statue' && ((T + d.seed * 53) % 230) < 6;
  const pupR = d.pup * (emo === 'shock' ? .65 : 1);
  let lx = (k ? .38 : 0) * r + sin(T / 80 + d.seed) * .12 * r, ly = (emo === 'sad' ? .3 : 0) * r;
  if (o.look) { lx = o.look[0] * r * .45; ly = o.look[1] * r * .35; }
  const eyes = [[fx - d.eyeGap * (k ? .78 : 1), k ? .8 : 1, -1], [fx + d.eyeGap * (k ? .95 : 1), 1, 1]];
  // мешки под глазами (Рик)
  if (d.hk === 'rick') for (const [exx, wk] of eyes) { QL(exx - r * .8 * wk, ey + r * 1.05, exx, ey + r * 1.9, exx + r * .8 * wk, ey + r * 1.05, 'rgba(120,90,60,.55)', .8); }
  for (const [exx, wk, s] of eyes) {
    if (d.patch && s === -1) continue;
    const rx = r * wk;
    if (blink && emo !== 'shock') { QL(exx - rx, ey + .3, exx, ey + 1.6, exx + rx, ey + .3, OL, 1.1); continue; }
    E(exx, ey, rx, r * 1.05, '#fff');
    let pr = pupR; if (d.hk === 'rick' && s === -1) pr *= .8;
    E(exx + lx * wk, ey + ly + .3, pr, pr, '#141414', null);
    // веки
    let lid = 0, tilt = 0;
    if (emo === 'angry') { lid = .42; tilt = -s * .5; } else if (emo === 'tired') lid = .3; else if (emo === 'smug') lid = .48; else if (emo === 'sad') { lid = .25; tilt = s * .45; }
    if (lid) {
      x.save(); x.beginPath(); x.ellipse(exx, ey, rx, r * 1.05, 0, 0, TAU); x.clip();
      const yl = ey - r * 1.05 + r * 2.1 * lid;
      PG([exx - rx - 1, ey - r * 1.3, exx + rx + 1, ey - r * 1.3, exx + rx + 1, yl + tilt * r * (1), exx - rx - 1, yl - tilt * r * (1)], d.skin, null);
      LN(exx - rx, yl - tilt * r, exx + rx, yl + tilt * r, OL, 1);
      x.restore(); path(() => x.ellipse(exx, ey, rx, r * 1.05, 0, 0, TAU), null);
    }
    if (d.lash) for (let i = 0; i < 3; i++) { const an = -PI / 2 + s * (.5 + i * .35); LN(exx + cos(an) * rx * .95, ey + sin(an) * r, exx + cos(an) * (rx + 2), ey + sin(an) * (r + 1.8), OL, .8); }
  }
  if (d.glasses) for (const [exx, wk] of eyes) { x.strokeStyle = '#222'; x.lineWidth = 1.1; x.beginPath(); x.ellipse(exx, ey, r * wk + 1.2, r + 1.2, 0, 0, TAU); x.stroke(); }
  // брови
  const bc = d.hk === 'rick' ? '#8fc6d8' : shade(d.hair, -.2);
  if (d.brow === 'uni') {
    const y = ey - r - 1.6 + (emo === 'angry' ? 1.2 : 0);
    x.lineCap = 'round'; x.strokeStyle = OL; x.lineWidth = 3.6; x.beginPath(); x.moveTo(eyes[0][0] - r - 1, y + 1); x.quadraticCurveTo(eyes[0][0], y - 1.5, fx, y + (emo === 'angry' ? 1.8 : .5)); x.quadraticCurveTo(eyes[1][0], y - 1.5, eyes[1][0] + r + 1, y + 1); x.stroke();
    x.strokeStyle = bc; x.lineWidth = 2.2; x.stroke();
  } else if (d.brow !== 'none' || emo === 'angry' || emo === 'sad' || emo === 'shock') {
    for (const [exx, wk, s] of eyes) {
      if (d.patch && s === -1) continue;
      let y1 = ey - r - 2, y2 = ey - r - 2; const w = r * wk;
      if (emo === 'angry') { y1 -= 1.4 * (s === 1 ? 0 : 1); y2 = ey - r - 2 + (s === 1 ? 0 : 0); const inner = exx - s * w * .9, outer = exx + s * w; LN(inner, ey - r - .4, outer, ey - r - 2.8, OL, 1.5); continue; }
      if (emo === 'sad') { const inner = exx - s * w * .9, outer = exx + s * w; LN(inner, ey - r - 2.8, outer, ey - r - 1.2, OL, 1.3); continue; }
      if (emo === 'shock') y1 = y2 = ey - r - 3.4;
      if (d.brow === 'arch') QL(exx - w, y1 + .5, exx, y1 - 1.6, exx + w, y1 + .5, shade(d.hair, -.35), 1);
      else if (d.brow === 'thick') LN(exx - w, y1, exx + w, y2, bc, 2);
      else QL(exx - w * .9, y1 + .4, exx, y1 - .8, exx + w * .9, y2 + .4, bc, 1.1);
    }
  }
  // нос
  const ny = ey + r + .5;
  if (d.nose === 'morty') QL(fx + 1, ny, fx + 3.2, ny + 1.8, fx + .6, ny + 3.2, OL, 1);
  else if (d.nose === 'rick') { x.strokeStyle = OL; x.lineWidth = 1.05; x.beginPath(); x.moveTo(fx - .5, ey - r * .3); x.quadraticCurveTo(fx + (k ? 3.5 : 1.5), ny + 3, fx + (k ? 4.5 : 2), ny + 5.5); x.quadraticCurveTo(fx + 1, ny + 6.5, fx - 1.5, ny + 5.5); x.stroke(); }
  else { x.strokeStyle = OL; x.lineWidth = 1; x.beginPath(); x.moveTo(fx + .3, ny); x.lineTo(fx + (k ? 2.8 : 1.6), ny + 4); x.quadraticCurveTo(fx + .6, ny + 5, fx - 1, ny + 4.4); x.stroke(); }
  if (d.mustache) path(() => x.ellipse(fx, d.mouthY - 2.2, d.mouthW * .9, 1.7, 0, 0, TAU), d.mustache, OL, .8);
  // рот
  const my = d.mouthY, mw = d.mouthW, mx = fx + (k ? 1 : 0);
  if (talk) {
    const oh = 1.6 + abs(sin(T / 2.6)) * 2.2;
    path(() => { x.moveTo(mx - mw * .7, my - .3); x.quadraticCurveTo(mx, my - 1.2, mx + mw * .7, my - .3); x.quadraticCurveTo(mx + mw * .6, my + oh, mx, my + oh + .4); x.quadraticCurveTo(mx - mw * .6, my + oh, mx - mw * .7, my - .3); }, '#5a2424', OL, 1);
    if (d.mouth === 'lips') QL(mx - mw * .7, my - .4, mx, my - 1.4, mx + mw * .7, my - .4, '#c04a6a', 1.2);
    if (oh > 2.4) E(mx, my + oh - .4, mw * .32, .8, '#d86a6a', null);
  } else if (emo === 'shock') E(mx, my + 1, 1.8, 2.4, '#5a2424');
  else if (emo === 'angry' || emo === 'sad') QL(mx - mw * .6, my + 1.2, mx, my - .6, mx + mw * .6, my + 1.2, OL, 1.2);
  else if (emo === 'happy') path(() => { x.moveTo(mx - mw * .8, my - .6); x.quadraticCurveTo(mx, my + 5, mx + mw * .8, my - .6); x.closePath(); }, '#5a2424', OL, 1);
  else if (emo === 'smug' || d.mouth === 'smirk') QL(mx - mw * .6, my + .6, mx + mw * .2, my + 1.2, mx + mw * .7, my - 1, OL, 1.1);
  else if (d.mouth === 'wavy') { x.strokeStyle = OL; x.lineWidth = 1; x.beginPath(); x.moveTo(mx - mw * .6, my); x.quadraticCurveTo(mx - mw * .3, my - 1, mx, my); x.quadraticCurveTo(mx + mw * .3, my + 1, mx + mw * .6, my); x.stroke(); }
  else if (d.mouth === 'rick') { x.strokeStyle = OL; x.lineWidth = 1.1; x.beginPath(); x.moveTo(mx - mw * .8, my + .8); x.quadraticCurveTo(mx - mw * .3, my - .6, mx, my + .2); x.quadraticCurveTo(mx + mw * .4, my + .9, mx + mw * .8, my - .2); x.stroke(); LN(mx + mw * .55, my + .4, mx + mw * .55, my + 3 + sin(T / 30) * .6, 'rgba(180,230,240,.9)', .9); }
  else if (d.mouth === 'grin') path(() => { x.moveTo(mx - mw * .75, my - 1); x.quadraticCurveTo(mx, my + 3.2, mx + mw * .75, my - 1); }, null, OL, 1.15);
  else if (d.mouth === 'lips') { path(() => { x.moveTo(mx - mw * .7, my); x.quadraticCurveTo(mx - mw * .2, my - 1.3, mx, my - .6); x.quadraticCurveTo(mx + mw * .2, my - 1.3, mx + mw * .7, my); x.quadraticCurveTo(mx, my + 2.1, mx - mw * .7, my); }, '#c24a68', OL, .8); LN(mx - mw * .6, my + .1, mx + mw * .6, my + .1, '#7a2440', .7); }
  else if (d.mouth === 'flat') LN(mx - mw * .5, my + .4, mx + mw * .5, my + .4, OL, 1.1);
  else QL(mx - mw * .6, my - .3, mx, my + 1.6, mx + mw * .6, my - .3, OL, 1.1);
  // румянец
  if (emo === 'blush') { E(fx - d.eyeGap * 1.5, my - 2, 2.4, 1.2, 'rgba(255,90,110,.35)', null); E(fx + d.eyeGap * 1.5, my - 2, 2.4, 1.2, 'rgba(255,90,110,.35)', null); }
}

/* ---------- причёски ---------- */
function hairBack(d, g, v, pre) { // слой за головой/телом
  const a = d.hw / 2, b = d.hh / 2, hy = g.hcy, c = d.hair;
  x.save(); x.translate(0, hy);
  if (d.hk === 'beth') {
    if (v === 'u') { /* рисуется в hairFront целиком */ }
    else path(() => { x.moveTo(-a - 1, -b * .2); x.bezierCurveTo(-a - 4, b * .6, -a - 3, b + 6, -a - 6, b + 9); x.quadraticCurveTo(-a + 2, b + 11, -a + 3, b + 5); x.lineTo(a - 3, b + 5); x.quadraticCurveTo(a - 2, b + 11, a + 6, b + 9); x.bezierCurveTo(a + 3, b + 6, a + 4, b * .6, a + 1, -b * .2); x.closePath(); }, c);
  } else if (d.hk === 'long') {
    if (v !== 'u') path(() => { x.moveTo(-a - 1, -b * .4); x.bezierCurveTo(-a - 4, b, -a - 3, b + 12, -a + 1, b + 14); x.lineTo(a - 1, b + 14); x.bezierCurveTo(a + 3, b + 12, a + 4, b, a + 1, -b * .4); x.closePath(); }, c);
  } else if (d.hk === 'summer' && v !== 'u') { // хвостик
    const sx = v === 's' ? -1 : -1;
    path(() => { x.moveTo(sx * a * .55, -b * .75); x.bezierCurveTo(sx * (a + 9), -b * .9, sx * (a + 8), b * .4, sx * (a + 3), b * .9); x.bezierCurveTo(sx * (a + 3), b * .1, sx * (a * .6), -b * .2, sx * a * .2, -b * .6); x.closePath(); }, c);
  } else if (d.hk === 'pony2' && v !== 'u') path(() => { x.moveTo(-a * .3, -b * .8); x.bezierCurveTo(-a - 8, -b, -a - 6, b * .5, -a - 1, b); x.lineTo(-a * .2, -b * .3); x.closePath(); }, c);
  x.restore();
}
function hairFront(d, v, o) {
  const a = d.hw / 2, b = d.hh / 2, c = d.hair, hk = d.hk, k = v === 's';
  const hl = 'rgba(255,255,255,.18)';
  if (hk === 'morty') {
    if (v === 'u') { path(() => { x.moveTo(-a - .8, b * .25); x.bezierCurveTo(-a - 1.5, -b * .7, -a * .7, -b - 1.4, 0, -b - 1.3); x.bezierCurveTo(a * .7, -b - 1.4, a + 1.5, -b * .7, a + .8, b * .25); x.quadraticCurveTo(0, b * .55, -a - .8, b * .25); }, c); return; }
    path(() => {
      x.moveTo(-a - .9, -b * .05);
      x.bezierCurveTo(-a - 1.6, -b * .75, -a * .7, -b - 1.5, 0, -b - 1.4);
      x.bezierCurveTo(a * .7, -b - 1.5, a + 1.6, -b * .75, a + .9, -b * .05);
      x.quadraticCurveTo(a * .78, -b * .32, a * .55, -b * .34);
      x.quadraticCurveTo(a * .1 + (k ? 2 : 0), -b * .5, -a * .2 + (k ? 2 : 0), -b * .38);
      x.quadraticCurveTo(-a * .62, -b * .3, -a * .78, -b * .36);
      x.quadraticCurveTo(-a * .9, -b * .2, -a - .9, -b * .05); x.closePath();
    }, c);
    QL(-a * .4, -b * .85, -a * .1, -b * .95, a * .2, -b * .82, hl, 1.4);
    return;
  }
  if (hk === 'rick') {
    // шипастая шевелюра
    const n = 9, pts = [];
    const ang0 = k ? PI * 1.02 : PI * 1.02, ang1 = k ? PI * 1.85 : PI * 1.98;
    for (let i = 0; i <= n; i++) {
      const t = i / n, an = ang0 + (ang1 - ang0) * t, tip = 1.38 + (i % 2 ? .0 : .22) + (abs(t - .5) < .3 ? .05 : .12);
      const dirx = k ? -.25 : 0;
      pts.push([cos(an) * (a + 1) , sin(an) * (b + 1)]);
      if (i < n) { const am = an + (ang1 - ang0) / n / 2; pts.push([cos(am) * a * tip + dirx * 6 * (1 - abs(t - .5)), sin(am) * b * tip - 2]); }
    }
    path(() => {
      x.moveTo(-a - 1, b * .05);
      for (const p of pts) x.lineTo(p[0], p[1]);
      x.lineTo(a + 1, b * .02);
      // линия роста волос
      const hlY = -b * .42;
      x.lineTo(a * .8, -b * .25); x.lineTo(a * .55, hlY); x.lineTo(a * .25, hlY - 2.5); x.lineTo(0, hlY - .5); x.lineTo(-a * .25, hlY - 2.5); x.lineTo(-a * .55, hlY); x.lineTo(-a * .8, -b * .25);
      x.closePath();
    }, c);
    LN(-a * .3, -b * .95, -a * .05, -b * 1.25, 'rgba(255,255,255,.35)', 1.2);
    if (v === 'u') path(() => x.ellipse(0, -b * .1, a + .5, b * .9, 0, 0, TAU), c);
    return;
  }
  if (hk === 'summer') {
    if (v === 'u') { path(() => x.ellipse(0, -b * .15, a + 1, b * .95, 0, 0, TAU), c); path(() => { x.moveTo(-3, -b * .4); x.bezierCurveTo(-6, b * .5, -3, b + 4, 0, b + 6); x.bezierCurveTo(3, b + 4, 6, b * .5, 3, -b * .4); }, c); E(0, -b * .45, 2.6, 1.6, '#e85a8a'); return; }
    path(() => {
      x.moveTo(-a - 1, b * .1);
      x.bezierCurveTo(-a - 2, -b * .8, -a * .6, -b - 1.8, 0, -b - 1.6);
      x.bezierCurveTo(a * .7, -b - 1.8, a + 2, -b * .8, a + 1, b * .1);
      x.quadraticCurveTo(a * .8, -b * .3, a * .45, -b * .45);
      x.bezierCurveTo(a * .1, -b * .25, -a * .5, -b * .62, -a * .62, -b * .42);
      x.quadraticCurveTo(-a * .85, -b * .2, -a - 1, b * .1); x.closePath();
    }, c);
    QL(-a * .3, -b * .9, a * .2, -b * 1.05, a * .55, -b * .72, hl, 1.3);
    E(-a * .62, -b * .82, 1.8, 1.4, '#e85a8a', OL, .7);
    return;
  }
  if (hk === 'beth') {
    if (v === 'u') { path(() => { x.moveTo(-a - 2, -b * .4); x.bezierCurveTo(-a - 3, -b - 3, a + 3, -b - 3, a + 2, -b * .4); x.bezierCurveTo(a + 4, b * .6, a + 3, b + 6, a + 6, b + 9); x.quadraticCurveTo(0, b + 12, -a - 6, b + 9); x.bezierCurveTo(-a - 3, b + 6, -a - 4, b * .6, -a - 2, -b * .4); }, c); return; }
    path(() => {
      x.moveTo(-a - 1.5, b * .5);
      x.bezierCurveTo(-a - 3.5, -b * .5, -a * .8, -b - 2.6, 0, -b - 2.2);
      x.bezierCurveTo(a * .9, -b - 2.6, a + 3.5, -b * .5, a + 1.5, b * .5);
      x.quadraticCurveTo(a * .8, -b * .2, a * .55, -b * .55);
      x.bezierCurveTo(a * .2, -b * .7, -a * .2, -b * .5, -a * .62, -b * .2);
      x.quadraticCurveTo(-a * .6, b * .2, -a - 1.5, b * .5); x.closePath();
    }, c);
    // пряди у лица
    path(() => { x.moveTo(-a * .62, -b * .2); x.quadraticCurveTo(-a * .95, b * .4, -a - .5, b + 2); x.quadraticCurveTo(-a - 2.5, b * .5, -a - 1.5, b * .2); x.closePath(); }, c, OL, .9);
    QL(-a * .2, -b * .95, a * .3, -b * 1.05, a * .65, -b * .75, hl, 1.4);
    return;
  }
  if (hk === 'jerry') {
    if (v === 'u') { path(() => { x.moveTo(-a - .8, b * .1); x.bezierCurveTo(-a - 1.5, -b * .9, -a * .5, -b - 3, 0, -b - 2.5); x.bezierCurveTo(a * .6, -b - 3, a + 1.5, -b * .9, a + .8, b * .1); x.quadraticCurveTo(0, b * .4, -a - .8, b * .1); }, c); return; }
    path(() => {
      x.moveTo(-a - .6, -b * .12);
      x.bezierCurveTo(-a - 1.3, -b * .8, -a * .7, -b - 3.2, -a * .1, -b - 2.8);
      x.bezierCurveTo(a * .5, -b - 3.6, a + 1.6, -b * .9, a + .6, -b * .12);
      x.quadraticCurveTo(a * .85, -b * .45, a * .55, -b * .6);
      x.quadraticCurveTo(a * .1, -b * .52, -a * .3, -b * .68);
      x.quadraticCurveTo(-a * .75, -b * .55, -a - .6, -b * .12); x.closePath();
    }, c);
    QL(-a * .45, -b * .62, -a * .3, -b * .95, -a * .05, -b * 1.05, shade(c, -.25), .9);
    return;
  }
  if (hk === 'balding') { path(() => { x.moveTo(-a - .5, b * .1); x.quadraticCurveTo(-a - 1.5, -b * .6, -a * .55, -b * .7); x.lineTo(-a * .5, -b * .35); x.quadraticCurveTo(-a * .8, -b * .2, -a * .85, b * .1); x.closePath(); }, c); path(() => { x.moveTo(a + .5, b * .1); x.quadraticCurveTo(a + 1.5, -b * .6, a * .55, -b * .7); x.lineTo(a * .5, -b * .35); x.quadraticCurveTo(a * .8, -b * .2, a * .85, b * .1); x.closePath(); }, c); LN(-a * .3, -b * .98, a * .2, -b * 1.05, c, 1); return; }
  if (hk === 'bald') { path(() => { x.moveTo(-a - .5, b * .15); x.quadraticCurveTo(-a - 1.2, -b * .35, -a * .7, -b * .45); x.lineTo(-a * .75, b * .05); x.closePath(); }, c); path(() => { x.moveTo(a + .5, b * .15); x.quadraticCurveTo(a + 1.2, -b * .35, a * .7, -b * .45); x.lineTo(a * .75, b * .05); x.closePath(); }, c); E(-a * .3, -b * .75, 3, 1.4, 'rgba(255,255,255,.3)', null); return; }
  // универсальные причёски
  const cap = (yl, ext = 1.5) => path(() => {
    x.moveTo(-a - .8, -b * .02);
    x.bezierCurveTo(-a - ext, -b * .8, -a * .7, -b - ext, 0, -b - ext);
    x.bezierCurveTo(a * .7, -b - ext, a + ext, -b * .8, a + .8, -b * .02);
    x.quadraticCurveTo(a * .5, yl, 0, yl - 1); x.quadraticCurveTo(-a * .5, yl, -a - .8, -b * .02); x.closePath();
  }, c);
  if (v === 'u') { path(() => x.ellipse(0, -b * .2, a + 1.2, b * .85, 0, 0, TAU), c); if (hk === 'long' || hk === 'pony2') R(-a - 1, -b * .2, d.hw + 2, b + 12, c, OL); return; }
  if (hk === 'buzz') cap(-b * .5, .6);
  else if (hk === 'curly') { cap(-b * .4, 2.5); for (let i = -2; i <= 2; i++) E(i * a * .38, -b * .9 + abs(i) * 1.3, 3.2, 2.8, c); }
  else if (hk === 'spiky') { cap(-b * .45, 1.5); PG([-a, -b * .6, -a * .6, -b - 6, -a * .2, -b - 1, a * .1, -b - 7, a * .4, -b - 1, a * .8, -b - 5, a, -b * .6], c); }
  else if (hk === 'long' || hk === 'pony2') { cap(-b * .35, 2); path(() => { x.moveTo(-a * .9, -b * .2); x.quadraticCurveTo(-a * 1.05, b * .5, -a - .5, b * .9); x.lineTo(-a - 2, b * .1); x.closePath(); }, c, OL, .9); path(() => { x.moveTo(a * .9, -b * .2); x.quadraticCurveTo(a * 1.05, b * .5, a + .5, b * .9); x.lineTo(a + 2, b * .1); x.closePath(); }, c, OL, .9); }
  else cap(-b * .38, 1.6);
  QL(-a * .3, -b * .9, 0, -b * 1.02, a * .3, -b * .9, hl, 1.2);
}

/* ---------- неловеческие персонажи ---------- */
defChar('mees', { name: 'Мистер Мисикс', voice: 'mees', draw(X, Y, o) {
  const sc = o.sc || 1; x.save(); x.translate(X, Y); if (!o.noShadow) shadow(0, 0, 12 * sc, 3.5 * sc); x.scale(sc * (o.dir === 'l' ? -1 : 1), sc);
  const c = '#8fd0f3', dk = '#6db5de', b = o.mov ? -abs(sin(o.ph || 0)) * 1.5 : sin(T / 9 + X) * 1.2, wv = sin(T / 6 + X) * 7;
  const ph = o.ph || 0, mv = o.mov ? sin(ph) * 3 : 0;
  limb([-4, -28, -4 - mv * .5, -2], 4.2, c); limb([4, -28, 4 + mv * .5, -2], 4.2, c);
  E(-4 - mv * .5, -1.5, 3.4, 1.8, c); E(4 + mv * .5, -1.5, 3.4, 1.8, c);
  path(() => { x.moveTo(-8, -52 + b); x.quadraticCurveTo(-10, -30, -6, -26); x.lineTo(6, -26); x.quadraticCurveTo(10, -30, 8, -52 + b); x.closePath(); }, c);
  const up = o.pose === 'up' || o.talk;
  limb([-7, -49 + b, -16, up ? -62 + wv * .4 : -38, -20, up ? -76 + wv : -28], 3.6, c); limb([7, -49 + b, 16, up ? -62 - wv * .4 : -38, 20, up ? -76 - wv : -28], 3.6, c);
  E(-20, up ? -77 + wv : -27, 2.6, 2.8, c); E(20, up ? -77 - wv : -27, 2.6, 2.8, c);
  E(0, -66 + b, 13.5, 16, c); E(-10, -66 + b, 2, 3, dk, null);
  E(-4.6, -70 + b, 4.2, 4.6, '#fff'); E(4.6, -70 + b, 4.2, 4.6, '#fff');
  E(-4.2 + (o.look ? o.look[0] : 0), -69.5 + b, 1.2, 1.2, '#111', null); E(5 + (o.look ? o.look[0] : 0), -69.5 + b, 1.2, 1.2, '#111', null);
  QL(1, -65 + b, 3.5, -62 + b, .5, -61 + b, OL, 1);
  if (o.talk || o.emo === 'happy') path(() => { x.moveTo(-6, -57 + b); x.quadraticCurveTo(0, -48 + b + abs(sin(T / 3)) * 3, 6, -57 + b); x.closePath(); }, '#3a1a2a', OL, 1);
  else if (o.emo === 'angry' || o.emo === 'sad') QL(-5, -54 + b, 0, -58 + b, 5, -54 + b, OL, 1.2);
  else QL(-5, -57 + b, 0, -53 + b, 5, -57 + b, OL, 1.2);
  x.restore();
} });
defChar('pickle', { name: 'Огурчик-Рик', voice: 'pickle', draw(X, Y, o) {
  const sc = o.sc || 1; x.save(); x.translate(X, Y); if (!o.noShadow) shadow(0, 0, 18 * sc, 5 * sc); x.scale(sc, sc);
  const b = sin(T / 12) * 1.5, tilt = sin(T / 40) * .06; x.rotate(tilt);
  const c = '#74b842', dk = '#4f8a2b', lt = '#9bd468';
  path(() => { x.moveTo(0, -2); x.bezierCurveTo(16, -2, 19, -30, 17, -48 + b); x.bezierCurveTo(15, -70 + b, 7, -82 + b, 0, -82 + b); x.bezierCurveTo(-7, -82 + b, -15, -70 + b, -17, -48 + b); x.bezierCurveTo(-19, -30, -16, -2, 0, -2); }, c);
  path(() => { x.moveTo(-9, -10); x.bezierCurveTo(-13, -30, -12, -60, -6, -74 + b); }, null, lt, 3);
  for (let i = 0; i < 16; i++) { const yy = -10 - ((i * 29) % 62), xx = sin(i * 2.4) * (11 - abs(yy + 40) * .08); E(xx, yy + b * .5, 1.6, 1.2, dk, null); }
  // лицо Рика
  const fy = -58 + b;
  QL(-10, fy + 3.5, -6, fy + 6.5, -2, fy + 3.5, 'rgba(40,70,20,.6)', .9); QL(2, fy + 3.5, 6, fy + 6.5, 10, fy + 3.5, 'rgba(40,70,20,.6)', .9);
  E(-6, fy, 4.6, 5, '#fff'); E(6, fy, 4.6, 5, '#fff'); E(-5.5, fy + .5, .9, .9, '#111', null); E(6.5, fy + .3, 1.1, 1.1, '#111', null);
  x.lineCap = 'round'; x.strokeStyle = OL; x.lineWidth = 3.8; x.beginPath(); x.moveTo(-12, fy - 5); x.quadraticCurveTo(-6, fy - 9, 0, fy - 5.5 + (o.emo === 'angry' ? 1.5 : 0)); x.quadraticCurveTo(6, fy - 9, 12, fy - 5); x.stroke(); x.strokeStyle = '#7fb8c8'; x.lineWidth = 2.3; x.stroke();
  QL(0, fy + 2, 2.5, fy + 7, -1, fy + 8, OL, 1);
  const my = fy + 15;
  if (o.talk) path(() => { x.moveTo(-8, my); x.quadraticCurveTo(0, my - 2, 8, my); x.quadraticCurveTo(0, my + 3 + abs(sin(T / 2.5)) * 5, -8, my); }, '#5a2424', OL, 1);
  else { path(() => { x.moveTo(-9, my - 1); x.quadraticCurveTo(0, my + 6, 9, my - 1); x.quadraticCurveTo(0, my + 1.5, -9, my - 1); }, '#fff', OL, 1); for (let i = -2; i <= 2; i++) LN(i * 3, my, i * 3, my + 2.5, 'rgba(0,0,0,.35)', .6); }
  x.restore();
} });
defChar('robot', { name: 'Робот', voice: 'robot', draw(X, Y, o) {
  const sc = o.sc || 1; x.save(); x.translate(X, Y); if (!o.noShadow) shadow(0, 0, 16 * sc, 4 * sc); x.scale(sc, sc);
  const b = sin(T / 10) * 2, c = o.col || '#8a93a6', dk = shade(c, -.3), tk = o.talk;
  RR(-10, -18, 7, 18, 2, dk); RR(3, -18, 7, 18, 2, dk); RR(-12, -3, 10, 4, 2, '#3a3f4a'); RR(2, -3, 10, 4, 2, '#3a3f4a');
  limb([-15, -44 + b, -22, -32 + b, -21, -22 + b], 4.5, dk); limb([15, -44 + b, 22, -32 + b, 21, -22 + b], 4.5, dk);
  E(-21, -21 + b, 3.4, 3, '#555'); E(21, -21 + b, 3.4, 3, '#555');
  RR(-16, -50 + b, 32, 34, 6, c); RR(-10, -42 + b, 20, 12, 3, shade(c, -.15)); for (let i = 0; i < 3; i++) E(-6 + i * 6, -36 + b, 1.6, 1.6, ['#ff5a5a', '#ffd84a', '#7dff5a'][i], null);
  RR(-13, -72 + b, 26, 20, 6, c); RR(-10, -68 + b, 20, 10, 3, '#14182a');
  glow('#ff3b3b', 8, () => E(sin(T / 15) * 5, -63 + b, 3.2, 2.4, tk ? '#fff' : '#ff3b3b', null));
  LN(0, -72 + b, 0, -80 + b, OL, 1.4); E(0, -81 + b, 2.2, 2.2, (T / 20 | 0) % 2 ? '#ff3b3b' : '#ffaaaa');
  x.restore();
} });
defChar('slime', { name: 'Мясной рулет', voice: 'slime', draw(X, Y, o) {
  const sc = o.sc || 1; x.save(); x.translate(X, Y); if (!o.noShadow) shadow(0, 0, 22 * sc, 5 * sc); x.scale(sc, sc);
  const w = sin(T / 8) * 2, c = '#b5654a', dk = '#8a4632';
  path(() => { x.moveTo(-26, 0); x.bezierCurveTo(-30 - w, -18, -18, -44 + w, 0, -44 + w); x.bezierCurveTo(18, -44 + w, 30 + w, -18, 26, 0); x.closePath(); }, c);
  for (let i = 0; i < 6; i++) E(-15 + i * 6, -8 - (i % 3) * 8, 3, 2, dk, null);
  E(-9, -28, 5, 5.6, '#fff'); E(9, -30, 6, 6.6, '#fff'); E(-8, -27, 1.6, 1.6, '#111', null); E(10, -29, 2, 2, '#111', null);
  for (let i = 0; i < 3; i++) { const dx = -14 + i * 14; E(dx, -2 + (T / 6 + i * 7) % 10, 1.8, 2.6, '#e8a080', null); }
  if (o.talk) E(0, -15, 7, 3 + abs(sin(T / 2.5)) * 3, '#4a1a12'); else QL(-7, -16, 0, -12, 7, -16, OL, 1.2);
  E(0, -40 + w, 5, 2, '#9ad04a'); E(3, -42 + w, 2, 2.4, '#e84a4a');
  x.restore();
} });
defChar('butter', { name: 'Робот', voice: 'robot', draw(X, Y, o) {
  const sc = o.sc || 1; x.save(); x.translate(X, Y); x.scale(sc, sc);
  E(0, -2, 8, 3, '#5a5f6a'); RR(-6, -9, 12, 7, 2, '#c8ccd2'); limb([-5, -6, -10, -11, -9, -15], 1.8, '#9aa0a8'); limb([5, -6, 10, -11, 9, -15], 1.8, '#9aa0a8');
  E(-2, -6, 1.4, 1.4, '#ffd84a', null); E(2, -6, 1.4, 1.4, '#ffd84a', null); x.restore();
} });
defChar('statue', Object.assign({}, CH.evil, { name: 'Статуя', skin: '#c4ccd8', shirt: '#b0b8c6', pants: '#8e98a8', hair: '#a2acba', shoe: '#ccd4de' }));
defChar('guard', Object.assign({}, CH.crick4, { name: 'Рик-охранник', voice: 'guard', pose: 'cross', emo: 'angry' }));

// портрет для диалога: голова + плечи, крупно
function portrait(id, X, Y, sz, o = {}) {
  const d = CH[id]; if (!d) return;
  x.save(); x.beginPath(); x.rect(X - sz / 2, Y - sz / 2, sz, sz); x.clip();
  if (d.draw) { const scl = id === 'pickle' ? 1.25 : id === 'robot' ? 1.4 : id === 'slime' ? 1.6 : 1.7; d.draw(X, Y + sz * .75 + (id === 'mees' ? 60 * scl * .55 : id === 'pickle' ? 40 : id === 'robot' ? 48 : 0) - (id === 'slime' ? 10 : 0), Object.assign({ sc: scl, noShadow: 1 }, o)); }
  else {
    const g = geo(d, {}), sc = sz / (d.hh * 1.55);
    drawChar(id, X, Y - g.hcy * sc + d.hh * sc * .12, Object.assign({ sc, noShadow: 1, dir: 'd', pose: o.pose || d.pose }, o));
  }
  x.restore();
}
