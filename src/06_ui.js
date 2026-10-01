/* ================= ИНТЕРФЕЙС: диалоги, выбор, затемнения, HUD, меню ================= */
let DLG = null, SPK = null, CHOICE = null, FADE = { a: 0, to: 0, sp: 0, col: '#000', r: null }, TOAST = null, MENU = null, CARD = null;
const NAME2ID = { 'Морти': 'morty', 'Рик': 'rick', 'Бет': 'beth', 'Джерри': 'jerry', 'Саммер': 'summer', 'Злой Морти': 'evil', 'Президент Морти': 'evil', 'Джессика': 'jessica', 'Итан': 'ethan',
  'Мистер Голденфолд': 'gold', 'Директор': 'principal', 'Брэд': 'brad', 'Мистер Мисикс': 'mees', 'Мисикс': 'mees', 'Огурчик-Рик': 'pickle', 'Робот': 'robot', 'Робот-надзиратель': 'robot',
  'Страж холодильника': 'robot', 'Рик-охранник': 'crick4', 'Морти-охранник': 'cmorty3', 'Мясной рулет': 'slime', 'Тэмми': 'tammy' };
const NAMECOL = { 'Рик': '#7fe3f5', 'Морти': '#ffe14a', 'Бет': '#ffb58a', 'Джерри': '#a8d080', 'Саммер': '#ff9ad0', 'Злой Морти': '#e2e86c', 'Президент Морти': '#e2e86c', 'Джессика': '#ff9a7a', 'Итан': '#7fe0a0', 'Мистер Мисикс': '#8fd0f3', 'Огурчик-Рик': '#9bd468' };

function normLines(lines) {
  if (typeof lines === 'string') lines = [lines];
  return lines.map(l => typeof l === 'string' ? { who: '', text: l, emo: null } : { who: l[0], text: l[1], emo: l[2] || null, pose: l[3] || null });
}
async function say(lines) {
  await until(() => !DLG && !CHOICE);
  return new Promise(r => {
    const L = normLines(lines);
    // разбиваем длинные реплики на страницы по 3 строки
    const out = [];
    for (const l of L) { const id = NAME2ID[l.who], w = id ? 470 : 570, ws = wrap(l.text, w, 15); for (let i = 0; i < ws.length; i += 3) out.push(Object.assign({}, l, { ls: ws.slice(i, i + 3), n: ws.slice(i, i + 3).join(' ').length })); }
    DLG = { lines: out, i: 0, c: 0, res: r, t: 0 };
  });
}
async function choose(opts, q) { await until(() => !DLG && !CHOICE); return new Promise(r => { CHOICE = { opts, q, i: 0, res: r, t: 0 }; }); }
function fadeOut(n = 20, col = '#000') { return new Promise(r => { FADE = { a: FADE.a, to: 1, sp: 1 / n, col, r }; }); }
function fadeIn(n = 20) { return new Promise(r => { FADE = { a: FADE.a, to: 0, sp: 1 / n, col: FADE.col, r }; }); }
function toast(t, n = 140) { TOAST = { t, n, k: 0 }; }
function showCard(title, sub, n = 150) { return new Promise(r => { CARD = { title, sub, t: 0, n, r }; }); }
function uiWantsMove() { return !DLG && !CHOICE && !MENU && !CARD && (typeof S === 'undefined' || S === 'world' || (S === 'battle' && B && B.ph === 'dodge')); }
function uiAllowsMenu() { return typeof S !== 'undefined' && S === 'world' && !DLG && !CHOICE && !CUT && !CARD; }

function updateUI() {
  // затемнение
  if (FADE.a !== FADE.to) { FADE.a = FADE.to > FADE.a ? Math.min(FADE.to, FADE.a + FADE.sp * f) : Math.max(FADE.to, FADE.a - FADE.sp * f); if (FADE.a === FADE.to && FADE.r) { const r = FADE.r; FADE.r = null; r(); } }
  if (TOAST) { TOAST.k += f; if (TOAST.k > TOAST.n) TOAST = null; }
  if (CARD) { CARD.t += f; if ((CARD.t > CARD.n || (CARD.t > 40 && (inp.a || inp.tap))) && CARD.r) { inp.a = 0; inp.tap = null; const r = CARD.r; CARD.r = null; CARD.done = CARD.t; r(); } if (!CARD.r && CARD.t > (CARD.done || 0) + 1) CARD = null; return true; }
  if (CHOICE && !DLG) {
    const c = CHOICE; c.t += f; const d = navDir();
    if (d) { c.i = (c.i + d + c.opts.length) % c.opts.length; sfx('sel'); }
    if (inp.jy && abs(inp.jy) > .6 && c.t > 12) { c.i = (c.i + (inp.jy > 0 ? 1 : -1) + c.opts.length) % c.opts.length; c.t = 0; sfx('sel'); }
    let pick_ = -1;
    if (inp.tap) { const rs = choiceRects(); rs.forEach((r, i) => { if (inp.tap.x > r[0] && inp.tap.x < r[0] + r[2] && inp.tap.y > r[1] && inp.tap.y < r[1] + r[3]) pick_ = i; }); }
    if (inp.a && c.t > 8) pick_ = c.i;
    if (pick_ >= 0) { inp.a = 0; inp.tap = null; sfx('ok'); CHOICE = null; c.res(pick_); }
    return true;
  }
  if (DLG) {
    const d = DLG, l = d.lines[d.i]; d.t += f;
    const o = d.c | 0; d.c = Math.min(l.n, d.c + .75 * f);
    const all = l.ls.join(' ');
    SPK = l.who && d.c < l.n ? NAME2ID[l.who] || null : null;
    if ((d.c | 0) > o && all[o] && all[o] !== ' ' && (o % 2 === 0)) sfx('blip', VOICE[NAME2ID[l.who]] ? NAME2ID[l.who] : l.who ? 'student' : 'narr');
    if (inp.b && d.c < l.n) d.c = l.n;
    if ((inp.a || inp.tap) && d.t > 6) {
      inp.a = 0; inp.tap = null;
      if (d.c < l.n) d.c = l.n;
      else { d.i++; d.c = 0; d.t = 0; if (d.i >= d.lines.length) { DLG = null; SPK = null; d.res(); } }
    }
    return true;
  }
  SPK = null;
  return false;
}
function choiceRects() {
  const c = CHOICE, n = c.opts.length, top = c.q ? 290 : 262, h = n > 2 ? 24 : 30;
  if (n <= 2) return c.opts.map((o, i) => [40 + i * 290, top + (c.q ? 0 : 20), 270, 40]);
  return c.opts.map((o, i) => [60 + (i % 2) * 280, top + ((i / 2) | 0) * 30 - (c.q ? 4 : 0), 260, 26]);
}
function dlgBox(y, h) {
  R(10, y, W - 20, h, 'rgba(0,0,0,.92)', null);
  x.strokeStyle = '#fff'; x.lineWidth = 3; x.strokeRect(12, y + 2, W - 24, h - 4);
  x.strokeStyle = 'rgba(255,255,255,.35)'; x.lineWidth = 1; x.strokeRect(17, y + 7, W - 34, h - 14);
}
function heart(X, Y, s, fl) { x.fillStyle = fl; x.beginPath(); x.moveTo(X, Y + s * .9); x.bezierCurveTo(X - s * 1.6, Y - s * .2, X - s * .8, Y - s * 1.3, X, Y - s * .5); x.bezierCurveTo(X + s * .8, Y - s * 1.3, X + s * 1.6, Y - s * .2, X, Y + s * .9); x.fill(); }
function drawDialog() {
  const d = DLG; if (!d) return; const l = d.lines[d.i];
  const top = (typeof S !== 'undefined' && ((S === 'world' && PL.y - CAM.y > 250) || S === 'battle')) || d.top;
  const y = top ? 10 : 252, h = 98, id = NAME2ID[l.who];
  dlgBox(y, h);
  let tx0 = 34;
  if (id && CH[id]) {
    R(24, y + 12, 76, 74, '#14141c', '#fff', 1);
    portrait(id, 62, y + 49, 74, { emo: l.emo || undefined, talk: d.c < l.n, pose: l.pose || undefined });
    tx0 = 114;
  }
  if (l.who) { const c = NAMECOL[l.who] || '#fff'; font(13, 700); const tw = x.measureText(l.who).width; R(tx0 - 4, y - 9, tw + 14, 18, '#000', '#fff', 2); tx(l.who, tx0 + 3, y + 5, 13, c, 'left'); }
  font(15, 400); x.fillStyle = '#fff'; x.textAlign = 'left';
  let n = d.c | 0;
  l.ls.forEach((s, i) => { if (n > 0) x.fillText(s.slice(0, n), tx0, y + 34 + i * 21); n -= s.length + 1; });
  if (d.c >= l.n) { const yy = y + h - 16 + sin(T / 6) * 2; PG([W - 38, yy, W - 28, yy, W - 33, yy + 6], '#fff', null); }
}
function drawChoice() {
  const c = CHOICE; if (!c || DLG) return;
  dlgBox(252, 98);
  if (c.q) { const ws = wrap(c.q, 560, 15); tx(ws[0], 34, 282, 15, '#fff', 'left', 400); }
  choiceRects().forEach((r, i) => {
    const on = i === c.i;
    tx(c.opts[i], r[0] + 24, r[1] + r[3] / 2 + 5, 15, on ? '#ffe14a' : '#fff', 'left');
    if (on) heart(r[0] + 10, r[1] + r[3] / 2, 5.5, '#ff2a4d');
  });
}
function drawFade() { if (FADE.a > 0) { x.globalAlpha = FADE.a; x.fillStyle = FADE.col; x.fillRect(0, 0, W, H); x.globalAlpha = 1; } }
function drawCard() {
  if (!CARD) return; const k = Math.min(1, CARD.t / 20);
  x.fillStyle = '#000'; x.fillRect(0, 0, W, H);
  x.globalAlpha = k; glow('#7dff5a', 14, () => tx(CARD.title, W / 2, 160, 30, '#fff'));
  if (CARD.sub) tx(CARD.sub, W / 2, 198, 15, '#7dff5a', 'center', 400);
  if (CARD.t > 40 && ((T / 30) | 0) % 2) tx('▼', W / 2, 300, 12, '#888');
  x.globalAlpha = 1;
}
let areaNameT = 0;
function drawHUD() {
  if (DLG || CHOICE || CARD) return;
  if (AR && areaT < 160) { const a = areaT < 20 ? areaT / 20 : areaT > 130 ? (160 - areaT) / 30 : 1; x.globalAlpha = a; txo(AR.name, 16, 26, 14, '#fff', 'left', '#000', 3); x.globalAlpha = 1; }
  if (G.obj && !CUT) { font(12, 700); const w = x.measureText('Цель: ' + G.obj).width; const X0 = W / 2 - w / 2; RR(X0 - 12, 334 - 13, w + 24, 20, 10, 'rgba(0,0,0,.55)', null); tx('Цель: ', X0, 338, 12, '#7dff5a', 'left'); tx(G.obj, X0 + x.measureText('Цель: ').width, 338, 12, '#fff', 'left'); }
  // часы
  const ic = { morning: 'утро', day: 'день', evening: 'вечер', night: 'ночь' }[G.time];
  txo('День ' + G.day + ' · ' + ic, W - 40, 24, 12, '#fff', 'right', '#000', 3);
  if (touchUI) {
    E(BTN_M.x, BTN_M.y, BTN_M.r, BTN_M.r, 'rgba(0,0,0,.35)', 'rgba(255,255,255,.6)', 1.5); for (let i = -1; i <= 1; i++) LN(BTN_M.x - 6, BTN_M.y + i * 4, BTN_M.x + 6, BTN_M.y + i * 4, '#fff', 1.6);
    E(BTN_A.x, BTN_A.y, BTN_A.r, BTN_A.r, NEAR ? 'rgba(125,255,90,.35)' : 'rgba(255,255,255,.18)', 'rgba(255,255,255,.7)', 2); tx(NEAR ? '!' : 'A', BTN_A.x, BTN_A.y + 7, 20, '#fff');
  } else if (T < 1200 && G.day === 1) tx('Стрелки/WASD — ходить · Z/Enter — действие · X — бег · C — меню', W / 2, 352, 10, 'rgba(255,255,255,.6)', 'center', 400);
}
function drawStick() {
  if (inp.sid == null || !inp.so) return;
  x.globalAlpha = .3; E(inp.so.x, inp.so.y, 36, 36, null, '#fff', 3); x.globalAlpha = .45; E(inp.so.x + inp.jx * 34, inp.so.y + inp.jy * 34, 15, 15, '#fff', null); x.globalAlpha = 1;
}
function drawToast() { if (!TOAST) return; const a = Math.min(1, TOAST.k / 10, (TOAST.n - TOAST.k) / 15); x.globalAlpha = a; font(13, 700); const w = x.measureText(TOAST.t).width; RR(W / 2 - w / 2 - 14, 40, w + 28, 26, 13, 'rgba(0,0,0,.75)', '#7dff5a', 1.5); tx(TOAST.t, W / 2, 58, 13, '#fff'); x.globalAlpha = 1; }

/* ---------- меню паузы ---------- */
function openMenu() { MENU = { i: 0, t: 0 }; sfx('ok'); }
function menuItems() { return ['Продолжить', 'Музыка: ' + Math.round(VOL.mus * 100) + '%', 'Звуки: ' + Math.round(VOL.sfx * 100) + '%', 'Сохранить игру', 'Выйти в главное меню']; }
function updateMenu() {
  const m = MENU; m.t += f; const items = menuItems(); const d = navDir();
  if (d) { m.i = (m.i + d + items.length) % items.length; sfx('sel'); }
  let sel = -1;
  if (inp.tap) { items.forEach((s, i) => { const yy = 132 + i * 34; if (inp.tap.y > yy - 20 && inp.tap.y < yy + 10 && inp.tap.x > 180 && inp.tap.x < 460) sel = i; }); if (sel < 0 && (inp.tap.x < 150 || inp.tap.x > 490)) sel = 0; }
  if (inp.a && m.t > 5) sel = m.i;
  if (inp.b || inp.menu) { inp.b = inp.menu = 0; MENU = null; sfx('back'); return; }
  if (sel < 0) return; inp.a = 0; inp.tap = null; m.i = sel;
  if (sel === 0) { MENU = null; sfx('back'); }
  else if (sel === 1) { VOL.mus = VOL.mus >= 1 ? 0 : Math.round((VOL.mus + .2) * 10) / 10; setVol(); saveSettings(); sfx('sel'); }
  else if (sel === 2) { VOL.sfx = VOL.sfx >= 1 ? 0 : Math.round((VOL.sfx + .2) * 10) / 10; setVol(); saveSettings(); sfx('sel'); }
  else if (sel === 3) { saveGame(); toast('Игра сохранена'); MENU = null; sfx('save'); }
  else if (sel === 4) { MENU = null; saveGame(); toTitle(); }
}
function drawMenu() {
  if (!MENU) return;
  x.fillStyle = 'rgba(0,0,0,.6)'; x.fillRect(0, 0, W, H);
  dlgBox(60, 250);
  tx('День ' + G.day + ' · ' + dayName() + ' · ' + { morning: 'утро', day: 'день', evening: 'вечер', night: 'ночь' }[G.time], W / 2, 92, 14, '#7dff5a');
  if (G.obj) tx('Цель: ' + G.obj, W / 2, 112, 12, '#ccc', 'center', 400);
  menuItems().forEach((s, i) => { const yy = 146 + i * 34, on = i === MENU.i; tx(s, W / 2, yy, 16, on ? '#ffe14a' : '#fff'); if (on) heart(W / 2 - 120, yy - 5, 6, '#ff2a4d'); });
}
