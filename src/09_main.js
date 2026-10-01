/* ================= ГЛАВНЫЙ ЦИКЛ, ТИТУЛЬНЫЙ ЭКРАН ================= */
let S = 'title';
const TITLE = { i: 0, t: 0 };
G.trig = []; G.items = ['pancake', 'pancake', 'juice'];
function titleItems() { const s = loadGame(); return s && s.day > 1 ? ['Продолжить — день ' + s.day, 'Новая игра'] : ['Новая игра']; }
function toTitle() {
  S = 'title'; DLG = null; CHOICE = null; CARD = null; MENU = null; B = null; SCENE = null; CUT = 0; WAITS.length = 0; FADE = { a: 0, to: 0, sp: 0, col: '#000', r: null };
  TITLE.t = 0; TITLE.i = 0; music('title');
}
let fsTried = false;
function onFirstTap() {
  if (S === 'title' && !fsTried && touchUI) { fsTried = true; try { const p = document.documentElement.requestFullscreen?.(); p && p.catch(() => { }); screen.orientation?.lock?.('landscape')?.catch(() => { }); } catch (_) { } }
  if (S === 'title' && !CUR && AC) music('title');
}
function titleRects() { return titleItems().map((s, i) => [W / 2 - 130, 262 + i * 34, 260, 30]); }
function updateTitle() {
  TITLE.t += f; const items = titleItems(); const d = navDir();
  if (d) { TITLE.i = (TITLE.i + d + items.length) % items.length; sfx('sel'); }
  let sel = -1;
  if (inp.tap) titleRects().forEach((r, i) => { if (inp.tap.x > r[0] && inp.tap.x < r[0] + r[2] && inp.tap.y > r[1] - 4 && inp.tap.y < r[1] + r[3] + 4) sel = i; });
  if (inp.a && TITLE.t > 20) sel = TITLE.i;
  if (sel < 0 || FADE.r) return;
  sfx('ok'); const s = loadGame(), cont = s && s.day > 1 && sel === 0;
  cutscene(async () => {
    await fadeOut(30);
    if (cont) { G.day = s.day; G.done = s.done || {}; }
    else { G.day = 1; G.done = {}; await showCard('РИК И МОРТИ', 'Фан-игра. Все персонажи принадлежат их создателям.', 140); }
    startDay();
  });
}
function drawTitle() {
  const t = TITLE.t;
  x.fillStyle = rgrad(320, 160, 20, 420, [[0, '#14402a'], [1, '#04050a']]); x.fillRect(0, 0, W, H);
  for (let i = 0; i < 60; i++) { x.globalAlpha = .3 + .4 * sin(T / 25 + i); E((i * 89.3) % W, (i * 53.7) % 240, 1.2, 1.2, '#fff', null); } x.globalAlpha = 1;
  portal(320, 168, 118, .95);
  x.save(); x.globalCompositeOperation = 'lighter'; x.fillStyle = rgrad(320, 168, 10, 260, [[0, 'rgba(125,255,90,.25)'], [1, 'rgba(125,255,90,0)']]); x.fillRect(0, 0, W, H); x.restore();
  drawChar('morty', 150, 318, { sc: 1.55, dir: 'd', emo: (T % 400) < 200 ? 'shock' : null, pose: 'idle' });
  drawChar('rick', 490, 318, { sc: 1.35, dir: 'd', pose: 'gun' });
  glow('#7dff5a', 22, () => txo('РИК И МОРТИ', 320, 62, 46, '#e4ffd0', 'center', '#0a2a12', 6));
  txo('ДЫРА В РЕАЛЬНОСТИ', 320, 92, 20, '#7dff5a', 'center', '#000', 4);
  if (innerHeight > innerWidth) txo('Поверни телефон горизонтально', 320, 122, 13, '#ffd84a', 'center', '#000', 3);
  titleItems().forEach((s, i) => { const r = titleRects()[i], on = i === TITLE.i; RR(r[0], r[1], r[2], r[3], 6, on ? 'rgba(0,0,0,.75)' : 'rgba(0,0,0,.45)', on ? '#7dff5a' : 'rgba(255,255,255,.4)', on ? 2.5 : 1.5); tx(s, W / 2 + 8, r[1] + 21, 15, on ? '#ffe14a' : '#fff'); if (on) heart(r[0] + 22, r[1] + 15, 5.5, '#ff2a4d'); });
  tx('Фан-игра. Не связана с Adult Swim', 320, H - 6, 9, '#789', 'center', 400);
  if (!AC) tx('(нажми, чтобы включить звук)', 320, 250, 10, 'rgba(255,255,255,.55)', 'center', 400);
}

/* ---------- цикл ---------- */
function update() {
  tickWaits();
  if (window.AUTO && (DLG || CHOICE || CARD) && ((T | 0) % 5 === 0)) { inp.a = 1; if (CHOICE && window.AUTO_PICK != null) CHOICE.i = window.AUTO_PICK; }
  if (window.PILOT && S === 'world' && !CUT && !DLG && !CHOICE) { const P_ = window.PILOT, dx = P_.x - PL.x, dy = P_.y - PL.y, m = hyp(dx, dy); if (m < 5 || (P_.t = (P_.t || 0) + f) > 900) { window.PILOT = null; inp.jx = inp.jy = 0; } else { inp.jx = dx / m; inp.jy = dy / m; } }
  if (window.BAUTO && S === 'battle' && B && B.ph === 'menu' && CUT <= B.base && !DLG && !CHOICE && (T | 0) % 20 === 0) { B.sel = B.calm >= (B.e.need || 3) ? 3 : 1; inp.a = 1; }
  const busy = updateUI();
  if (MENU) updateMenu();
  else if (S === 'title') { if (!busy && !CUT) updateTitle(); }
  else if (S === 'world') {
    if (inp.menu && uiAllowsMenu() && !busy) { inp.menu = 0; openMenu(); }
    else { updateWorld(!busy && !CUT && FADE.a < .05); storyTick(); }
  }
  else if (S === 'battle') updateBattle();
  else if (S === 'scene' && SCENE) SCENE.t += f;
  inp.a = inp.b = inp.menu = 0; inp.tap = null;
}
function draw() {
  x.setTransform(SC, 0, 0, SC, 0, 0);
  if (S === 'title') drawTitle();
  else if (S === 'world' && AR) { drawWorld(); drawHUD(); }
  else if (S === 'battle') drawBattle();
  else if (S === 'scene' && SCENE) SCENE.draw();
  drawDialog(); drawChoice(); drawMenu(); drawToast(); drawStick(); drawFade(); drawCard();
}
let lt = performance.now();
function loop(n) {
  f = Math.max(0, Math.min(3, (n - lt) / 16.667)); lt = n; T += f;
  try { update(); draw(); } catch (e) { console.error(e); }
  requestAnimationFrame(loop);
}
loadSettings(); resize();
if (document.fonts && document.fonts.load) { document.fonts.load('700 15px Pix'); document.fonts.load('400 15px Pix'); }
toTitle();
requestAnimationFrame(loop);
// отладка: ?day=N — начать с N-го дня
(function () { const m = /[?&]day=(\d+)/.exec(location.search); if (m) { G.day = +m[1]; G.done = {}; startDay(); } })();
window.RM = { G, startDay, enterArea, battle, AREAS, PL, get S() { return S; }, set S(v) { S = v; }, ENTS: () => ENTS, music, CH, say, inp };
