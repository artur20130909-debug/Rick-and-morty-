/* ================= ЦИТАДЕЛЬ РИКОВ: город, Нижний ярус, технический туннель, площадь, кабинет президента =================
   Путь к президенту: посадочная площадка в центре города → ворота закрыты (нужен пропуск) → лифт в Нижний ярус →
   хакеру нужны 3 предохранителя (автомат в городе, посылка курьера, Рик-наёмник) → технический туннель с лазерами
   (три участка: мигающие лучи, решётки с проёмом, прожектор и ниши) → площадь, пароль у лифта → кабинет. */

/* ---------- персонажи Цитадели ---------- */
defChar('hacker', Object.assign({}, CH.morty, { name: 'Морти-хакер', voice: 'mortyg', shirt: '#3a6a4a', top: 'jacket', sleeve: 'long', sleeveC: '#2f5a3e', glasses: 1, hat: 'cap', pose: 'idle', mouth: 'flat' }));
defChar('courier', Object.assign({}, CH.morty, { name: 'Морти-курьер', voice: 'mortyg', shirt: '#f08a3a', hat: 'cap', pose: 'idle', mouth: 'wavy' }));
defChar('pguard', Object.assign({}, CH.morty, { name: 'Охранник-Морти', voice: 'mortyg', shirt: '#2a3a5c', pants: '#1e2a44', hat: 'helmet', pose: 'cross', emo: 'angry', mouth: 'flat' }));
defChar('attendant', Object.assign({}, CH.morty, { name: 'Морти-диспетчер', voice: 'mortyg', shirt: '#f2df55', hat: 'cap', pose: 'wave', mouth: 'wavy' }));
defChar('hunter', Object.assign({}, CH.rick, { name: 'Рик-наёмник', voice: 'guard', shirt: '#6a3a2a', top: 'armor', hair: '#d0d8de', hat: 'beret', pants: '#2e2a30', pose: 'cross', emo: 'angry' }));
defChar('statue2', Object.assign({}, CH.president, { name: 'Статуя', skin: '#c4ccd8', shirt: '#9aa4b4', tie: '#8a94a6', sleeveC: '#9aa4b4', pants: '#8e98a8', hair: '#a2acba', shoe: '#ccd4de', pose: 'hips', emo: 'smug' }));
for (const k of ['president', 'presevil']) VOICE[k] = VOICE.evil;
for (const k of ['hacker', 'courier', 'pguard', 'attendant']) VOICE[k] = VOICE.mortyg;
VOICE.hunter = VOICE.guard;

/* ---------- общие детали ---------- */
const citEsc = () => !!G.flags.escape;
// металлическая панель фасада со швами и заклёпками
function citPanel(X, Y, w, h, c) { R(X, Y, w, h, c, null); R(X, Y, w, 2, shade(c, .18), null); R(X, Y + h - 2, w, 2, shade(c, -.3), null); for (let xx = X + 24; xx < X + w - 4; xx += 24) R(xx, Y + 3, 1, h - 6, shade(c, -.18), null); for (let xx = X + 6; xx < X + w; xx += 24) { R(xx, Y + 5, 1.4, 1.4, shade(c, .3), null); R(xx, Y + h - 7, 1.4, 1.4, shade(c, .3), null); } }
// неоновая вывеска: подложка, буквы с ореолом
function neon(X, Y, w, h, text, col, sz = 9) { RR(X, Y, w, h, 3, '#14121e', OL, 1); RR(X + 2, Y + 2, w - 4, h - 4, 2, null, col, 1); x.save(); x.globalAlpha = .35; RR(X - 3, Y - 3, w + 6, h + 6, 5, null, col, 2); x.restore(); txo(text, X + w / 2, Y + h / 2 + sz * .38, sz, col, 'center', '#14121e', 2); }
// витрина магазина Цитадели: фасад, вывеска, навес-полоски, витрина с товаром, дверь
function citShop(X, w, col, name, deco) {
  const yb = 196, top = 62;
  citPanel(X, top, w, yb - top, shade(col, -.35));
  R(X, top - 6, w, 6, shade(col, -.55), OL, .8);
  neon(X + 10, top + 8, w - 20, 22, name, shade(col, .55), name.length > 14 ? 7 : 9);
  for (let i = 0; i < (w - 8) / 12; i++) PG([X + 4 + i * 12, top + 38, X + 16 + i * 12, top + 38, X + 16 + i * 12, top + 48, X + 10 + i * 12, top + 52, X + 4 + i * 12, top + 48], i % 2 ? '#f4f0e6' : col, OL, .6);
  R(X + 10, top + 58, w - 62, yb - top - 64, '#9fd8f0', OL, 1.2); R(X + 10, top + 58, w - 62, 8, 'rgba(255,255,255,.45)', null); PG([X + 18, top + 58, X + 34, top + 58, X + 22, yb - 6, X + 12, yb - 6], 'rgba(255,255,255,.22)', null);
  if (deco) deco(X + 10, top + 58, w - 62, yb - top - 64);
  R(X + w - 46, top + 62, 36, yb - top - 62, '#2a3442', OL, 1); R(X + w - 44, top + 64, 32, yb - top - 66, '#5a8aa8', null); LN(X + w - 28, top + 64, X + w - 28, yb - 2, '#2a3442', 1.5); E(X + w - 32, top + 110, 1.5, 1.5, '#ffe9a0', null);
}
function lampPost(X, Y, col = '#9dfff0') { shadow(X, Y, 8, 2.5); LN(X, Y, X, Y - 70, '#5a6476', 3); LN(X - .8, Y - 2, X - .8, Y - 68, '#8a94a6', 1); RR(X - 7, Y - 78, 14, 9, 3, '#3a4250', OL, .8); E(X, Y - 70, 5, 2.4, col, null); x.save(); x.globalAlpha = .25; E(X, Y - 66, 14, 8, col, null); x.restore(); }
function planter(X, Y) { shadow(X, Y, 16, 4); RR(X - 15, Y - 12, 30, 12, 3, '#5a6476', OL, .8); R(X - 13, Y - 11, 26, 2, '#8a94a6', null); for (let i = 0; i < 5; i++) Er(X - 10 + i * 5, Y - 18 - (i % 2) * 5, 3.2, 8, (i - 2) * .35, i % 2 ? '#3f8a6a' : '#57b08a'); E(X - 3, Y - 26, 2.4, 2.4, '#ff8ad0', null); E(X + 6, Y - 22, 2, 2, '#ffe36a', null); }
function bench(X, Y) { shadow(X, Y, 26, 4); R(X - 24, Y - 14, 48, 5, '#8a94a6', OL, .8); R(X - 24, Y - 24, 48, 4, '#6a7486', OL, .8); LN(X - 20, Y - 9, X - 20, Y, '#3a4250', 2); LN(X + 20, Y - 9, X + 20, Y, '#3a4250', 2); }
// плакат с президентом (без повязки!)
function presPoster(X, Y, w, h, motto) {
  R(X, Y, w, h, '#1a2a4a', OL, 1); R(X + 3, Y + 3, w - 6, h - 22, '#2c4a7a', null);
  const cx = X + w / 2, cy = Y + (h - 22) * .55; E(cx, cy + 10, 13, 9, '#2c2f3e', null); PG([cx - 2, cy + 3, cx + 2, cy + 3, cx + 1, cy + 14, cx - 1, cy + 14], '#c8323c', null);
  E(cx, cy - 4, 11, 10, '#f8d3b0', null); path(() => x.ellipse(cx, cy - 9, 12, 7, 0, PI, 0), '#674326', null); E(cx - 4, cy - 4, 3, 3, '#fff', null); E(cx + 4, cy - 4, 3, 3, '#fff', null); E(cx - 4, cy - 4, 1, 1, '#111', null); E(cx + 4, cy - 4, 1, 1, '#111', null); LN(cx - 3, cy + 2, cx + 3, cy + 2, '#5a2424', .8);
  tx(motto, cx, Y + h - 8, Math.min(8, w / (motto.length * .55)), '#ffe14a');
}

/* ---------- Центральный квартал (сюда садится корабль) ---------- */
area('cit_city', {
  name: 'Цитадель: Центральный квартал', w: 1800, h: 380, indoor: 1, noTint: 1, bounds: [30, 206, 1770, 360], music: () => citEsc() ? 'escape' : 'citcity',
  cacheKey: () => citEsc() ? 'e' : '',
  bg() {
    const esc = citEsc();
    citadelSkyline(0, 0, 1800, 120, { gold: esc, alarm: esc });
    // дальний ряд домов между магазинами
    for (let i = 0; i < 18; i++) { const X = i * 100 + (i * 37) % 30, h = 70 + (i * 53) % 50; citPanel(X, 120 - h + 40, 70, h + 40, '#3a4660'); for (let j = 0; j < h / 14; j++) for (let k = 0; k < 4; k++) if ((i + j * 3 + k) % 4) R(X + 8 + k * 15, 120 - h + 48 + j * 14, 8, 5, esc && (j + k) % 3 === 0 ? '#ff6a4a' : '#ffe9a6', null); }
    // площадка-«проспект»: пол, полоса движения, плитка
    R(0, 196, 1800, 184, '#5e6a7e', null); floor(0, 196, 1800, 184, 'metal', '#6a7688', '#56627a');
    R(0, 262, 1800, 34, '#7a8698', null); for (let xx = 10; xx < 1800; xx += 60) R(xx, 277, 30, 4, '#c8d4e4', null);
    R(0, 196, 1800, 10, grad(0, 196, 0, 206, [[0, 'rgba(0,0,0,.35)'], [1, 'rgba(0,0,0,0)']]));
    // посадочная площадка
    E(200, 300, 150, 48, '#4a5466', OL, 1.4); E(200, 300, 136, 42, '#566276', null); E(200, 300, 120, 36, null, '#ffd84a', 2.4);
    for (let i = 0; i < 12; i++) { const a = i / 12 * TAU; E(200 + cos(a) * 140, 300 + sin(a) * 44, 3, 1.6, i % 2 ? '#7dff5a' : '#ffd84a', null); }
    tx('C-137', 200, 334, 10, '#ffd84a'); txo('ПОСАДОЧНАЯ ПЛОЩАДКА 7', 200, 248, 8, '#cfe0ff', 'center', '#14121e', 2);
    // магазины
    citShop(380, 200, '#3aa860', 'ПОРТАЛЬНАЯ ЖИДКОСТЬ', (X, Y, w, h) => { for (let i = 0; i < 6; i++) { RR(X + 8 + i * 22, Y + h - 30, 14, 26, 3, '#7dff5a', OL, .8); R(X + 11 + i * 22, Y + h - 34, 8, 5, '#d0d8de', OL, .5); } });
    citShop(600, 200, '#e8b830', 'МОРТИ-БУРГЕР', (X, Y, w, h) => { for (let i = 0; i < 3; i++) { const bx = X + 22 + i * 46, by = Y + h - 16; E(bx, by - 10, 14, 7, '#e8a848', OL, .8); R(bx - 14, by - 7, 28, 4, '#3a8a3a', null); R(bx - 14, by - 3, 28, 5, '#7a3a1a', OL, .6); E(bx, by + 3, 14, 4, '#e8a848', OL, .8); } });
    citShop(1320, 210, '#d0508a', 'СУВЕНИРЫ «Я ♥ ЦИТАДЕЛЬ»', (X, Y, w, h) => { for (let i = 0; i < 4; i++) { RR(X + 10 + i * 36, Y + h - 26, 22, 22, 3, '#fff', OL, .8); tx('♥', X + 21 + i * 36, Y + h - 10, 11, '#e84a7a'); } });
    // лифт в Нижний ярус
    citPanel(1150, 70, 140, 126, '#2e3648'); R(1180, 112, 80, 84, '#1a1e28', OL, 1.4); R(1184, 116, 35, 80, '#7a8698', OL, .8); R(1221, 116, 35, 80, '#7a8698', OL, .8);
    neon(1160, 80, 120, 24, 'НИЖНИЙ ЯРУС ↓', '#7dfff0', 8);
    // ворота на президентскую площадь
    R(1590, 30, 210, 166, '#28304a', OL, 1.4); citPanel(1600, 40, 190, 156, '#38425e');
    R(1640, 70, 120, 126, '#121624', OL, 1.4); path(() => x.ellipse(1700, 70, 60, 26, 0, PI, 0), '#121624', OL, 1.4);
    if (!esc) { x.save(); x.globalAlpha = .55; R(1644, 62, 112, 134, grad(0, 60, 0, 196, [[0, '#6ac8ff'], [1, '#2a6aff']]), null); x.restore(); for (let i = 0; i < 6; i++) LN(1648 + i * 20, 66, 1648 + i * 20, 194, 'rgba(200,240,255,.5)', 1); }
    else { R(1644, 62, 112, 134, '#2a1a1a', null); for (let i = 0; i < 5; i++) LN(1650 + i * 24, 194, 1660 + i * 24, 120, 'rgba(255,120,60,.6)', 1.4); }
    neon(1620, 8, 160, 22, 'ПРЕЗИДЕНТСКАЯ ПЛОЩАДЬ', '#ffd84a', 8);
    presPoster(1080, 84, 52, 78, 'МОРТИ — ЗА ВСЕХ');
    presPoster(860, 84, 52, 78, 'ГОЛОСУЙ ЗА МОРТИ');
    if (esc) { for (let i = 0; i < 9; i++) { const X = 120 + i * 190, Y = 230 + (i * 47) % 110; PG([X, Y, X + 18, Y - 4, X + 26, Y + 6, X + 6, Y + 10], '#4a4a56', OL, .8); } for (let i = 0; i < 6; i++) LN(300 + i * 260, 196, 330 + i * 260, 260, '#1a1a22', 2); }
  },
  props: [
    { y: 300, hide: () => !G.flags.shipDocked, solid: [120, 266, 160, 34], draw() { ship(200, 300, { lift: 0 }); } },
    { y: 236, solid: [888, 226, 44, 12], draw() { // голограмма президента
      shadow(910, 236, 26, 6); RR(888, 222, 44, 14, 3, '#3a4250', OL, .8); E(910, 222, 22, 5, '#5a6476', OL, .8); E(910, 221, 14, 3, '#7dfff0', null);
      if (citEsc()) { if ((T / 4 | 0) % 3) return; }
      x.save(); x.globalAlpha = .55 + sin(T / 7) * .1; drawChar('president', 910, 218, { sc: 1.25, dir: 'd', noShadow: 1, pose: 'behind' }); x.restore();
      x.save(); x.globalAlpha = .25; for (let i = 0; i < 12; i++) R(886, 120 + i * 8 + (T / 2 % 8), 48, 2, '#7dfff0', null); x.restore();
    } },
    { y: 330, solid: [370, 322, 52, 10], draw() { bench(396, 330); } },
    { y: 340, solid: [990, 334, 32, 8], draw() { planter(1006, 340); } },
    { y: 340, solid: [560, 334, 32, 8], draw() { planter(576, 340); } },
    { y: 230, draw() { lampPost(360, 230); } }, { y: 230, draw() { lampPost(820, 230); } }, { y: 230, draw() { lampPost(1300, 230); } }, { y: 230, draw() { lampPost(1560, 230, '#ffd84a'); } },
    { y: 352, solid: [1180, 344, 52, 10], draw() { bench(1206, 352); } },
    { y: 218, solid: [636, 204, 36, 14], draw() { // автомат с газировкой (предохранитель №1)
      shadow(654, 218, 20, 4); R(636, 160, 36, 58, '#c0392b', OL, 1.2); R(640, 166, 20, 34, '#2a3442', OL, .8); for (let i = 0; i < 4; i++) R(642, 168 + i * 8, 16, 5, ['#7dff5a', '#ffd84a', '#6ac8ff', '#ff8ad0'][i], null);
      R(662, 170, 7, 12, '#e8e8e8', OL, .6); R(642, 204, 16, 8, '#1a1e28', OL, .6); tx('ПЛЮМБУС', 654, 158, 5, '#fff');
      if (!G.flags.fuseVend && (T / 20 | 0) % 2) E(666, 192, 1.6, 1.6, '#ff5a5a', null);
    } },
    { y: 222, hide: () => !G.flags.courierAsk || G.flags.parcel, draw() { RR(452, 208, 22, 16, 2, '#c8904a', OL, 1); LN(452, 214, 474, 214, '#8a5a2a', 1.4); tx('!', 463, 206, 8, '#ff5a5a'); } },
  ],
  under() { if (G.flags.shipDocked && !citEsc()) { x.save(); x.globalCompositeOperation = 'lighter'; E(200, 300, 130 + sin(T / 9) * 4, 38, 'rgba(255,216,74,.06)', null); x.restore(); } },
  light() { if (citEsc()) { x.save(); x.globalCompositeOperation = 'multiply'; x.globalAlpha = .5 + sin(T / 9) * .15; x.fillStyle = '#ff6a50'; x.fillRect(0, 0, W, H); x.restore(); } },
  crowd: () => citCrowd('cit_city'),
  exits: [
    { r: [1190, 204, 64, 10], to: 'cit_lower', at: [124, 214], dir: 'u', face: 'd', door: 1, cond: () => !citEsc(), msg: [['Рик', 'Морти, Цитадель разваливается! Какой, к чёрту, Нижний ярус?! К КОРАБЛЮ!', 'angry']] },
    { r: [1762, 206, 10, 154], to: 'cit_plaza', at: [60, 270], dir: 'r', cond: citEsc, msg: () => [['Охранник-Морти', 'Стоять! Президентская площадь — только по пропуску с глазным сканом.'], ['Рик', 'Морти, лобовая атака — не наш метод. Ну, сегодня. Ищем обходной путь.']] },
  ],
  things: [
    { r: [636, 196, 36, 20], look: () => vendLook() },
    { r: [452, 206, 22, 16], cond: () => G.flags.courierAsk && !G.flags.parcel, look: () => parcelLook() },
    { r: [860, 160, 52, 30], look: [N('Плакат: Президент Морти в строгом костюме. «Голосуй за Морти». Он улыбается так, будто знает о тебе что-то.')] },
    { r: [380, 150, 200, 46], look: [N('«Портальная жидкость». Ценник: «Одна вселенная — одна банка». Мелким шрифтом: «Для Мортей — только с Риком».')] },
    { r: [600, 150, 200, 40], look: [N('«Морти-бургер». Меню: бургер «Обычный Морти», бургер «Ещё один Морти» и бургер «Морти, который всё понял» (нет в наличии).')] },
    { r: [1320, 150, 210, 46], look: [N('Кружки «Я ♥ Цитадель». Джерри просил привезти такую. Тут даже есть версия «Я ♥ Джерри» — пыльная и со скидкой 99%.')] },
    { r: [888, 196, 44, 30], look: () => [N(citEsc() ? 'Голограмма президента мигает и распадается на пиксели.' : 'Голограмма Президента Морти: «Граждане! Цитадель — для каждого. Даже для Джерри».')] },
  ],
});

/* ---------- Нижний ярус: Морти-таун ---------- */
area('cit_lower', {
  name: 'Цитадель: Нижний ярус', w: 1500, h: 380, indoor: 1, noTint: 1, bounds: [30, 200, 1470, 356], music: () => citEsc() ? 'escape' : 'mortytown',
  bg() {
    R(0, 0, 1500, 200, '#1a1c28', null);
    // задняя стена: панели, трубы, ржавчина
    for (let i = 0; i < 15; i++) citPanel(i * 100, 40, 100, 156, i % 3 ? '#2a3040' : '#262b3a');
    for (let i = 0; i < 30; i++) E(30 + (i * 157) % 1460, 60 + (i * 61) % 120, 6 + i % 3 * 3, 3, 'rgba(140,80,40,.25)', null);
    for (const [Y, c, th] of [[54, '#5a6476', 10], [74, '#7a5a3a', 7], [168, '#4a5466', 9]]) { R(0, Y, 1500, th, c, OL, .8); R(0, Y + 1, 1500, 2, shade(c, .3), null); for (let xx = 40; xx < 1500; xx += 140) R(xx, Y - 2, 6, th + 4, shade(c, -.3), OL, .6); }
    for (const X of [260, 700, 1100]) { R(X, 40, 12, 156, '#5a6476', OL, .8); R(X + 2, 40, 3, 156, '#8a94a6', null); }
    // неоновые вывески
    neon(130, 92, 150, 30, 'МОРТИ-ТАУН', '#ff6ac8', 12); neon(560, 96, 110, 24, 'ЛАПША 24/7', '#6ac8ff', 8); neon(900, 92, 130, 26, 'РЕМОНТ ПОРТАЛОВ', '#7dff5a', 7);
    // лапшичная: прилавок
    R(540, 128, 150, 68, '#3a2a2a', OL, 1); for (let i = 0; i < 7; i++) PG([540 + i * 22, 128, 562 + i * 22, 128, 556 + i * 22, 140, 546 + i * 22, 140], i % 2 ? '#fff' : '#c0392b', OL, .5); R(548, 150, 134, 32, '#ffd890', null); for (let i = 0; i < 4; i++) { E(566 + i * 32, 166, 10, 5, '#e8e0d0', OL, .6); E(566 + i * 32, 164, 7, 2, '#e8c070', null); }
    // конвейер с коробками
    R(760, 150, 300, 30, '#3a4250', OL, 1); for (let i = 0; i < 15; i++) E(770 + i * 20, 176, 6, 6, '#22262e', OL, .6);
    // щиток с предохранителями (у наёмника) и служебный люк
    R(1150, 90, 70, 80, '#4a5060', OL, 1.2); R(1158, 98, 54, 56, '#22262e', OL, .8); for (let i = 0; i < 3; i++) R(1164 + i * 16, 108, 10, 36, '#3a3a3a', OL, .6); tx('⚡ 3 ПРЕДОХРАНИТЕЛЯ', 1185, 164, 6, '#ffd84a');
    R(1360, 86, 84, 110, '#2e3440', OL, 1.4); R(1368, 94, 68, 102, '#3a4250', OL, 1); for (let i = 0; i < 6; i++) PG([1368 + i * 12, 94, 1376 + i * 12, 94, 1368 + i * 12, 104], '#ffd84a', null); tx('СЛУЖЕБНЫЙ ТУННЕЛЬ', 1402, 84, 6, '#ffd84a');
    // лифт наверх
    R(80, 120, 90, 76, '#1a1e28', OL, 1.4); R(84, 124, 40, 72, '#6a7486', OL, .8); R(126, 124, 40, 72, '#6a7486', OL, .8); tx('ВВЕРХ ↑', 125, 116, 7, '#7dfff0');
    // пол: решётка, лужи с отражением неона
    R(0, 196, 1500, 184, '#2e3442', null); floor(0, 196, 1500, 184, 'metal', '#343a4a', '#262c3a');
    for (const [X, Y, c] of [[200, 300, '#ff6ac8'], [640, 330, '#6ac8ff'], [980, 260, '#7dff5a'], [1300, 320, '#ff6ac8']]) { E(X, Y, 46, 9, 'rgba(20,24,40,.8)', null); E(X - 8, Y - 1, 24, 3, c, null); }
    R(0, 196, 1500, 12, grad(0, 196, 0, 208, [[0, 'rgba(0,0,0,.5)'], [1, 'rgba(0,0,0,0)']]));
    // мусор
    for (let i = 0; i < 12; i++) { const X = 60 + (i * 131) % 1400, Y = 330 + (i * 17) % 22; RR(X, Y, 10 + i % 3 * 4, 6, 2, ['#7a6a4a', '#5a6a7a', '#8a3a3a'][i % 3], OL, .5); }
  },
  props: [
    { y: 232, solid: [380, 218, 90, 14], draw() { // логово хакера: стол с мониторами
      shadow(425, 232, 50, 6); box(380, 232, 90, 10, 18, '#4a4050', '#3a3040');
      for (let i = 0; i < 3; i++) { RR(386 + i * 28, 186, 24, 18, 2, '#1a1e28', OL, .8); R(389 + i * 28, 189, 18, 12, ['#1f6a3a', '#1f3a6a', '#4a1f6a'][i], null); for (let j = 0; j < 3; j++) R(391 + i * 28, 191 + j * 3, 6 + ((T / 9 + j * 3 + i) | 0) % 9, 1.2, '#7dff5a', null); }
    } },
    { y: 262, draw() { if (!G.flags.hunterGone) return; R(1170, 252, 12, 8, '#ffd84a', OL, .6); } },
    { y: 330, solid: [140, 322, 56, 10], draw() { box(140, 330, 56, 10, 24, '#7a6a4a', '#6a5a3a'); box(150, 306, 30, 8, 16, '#8a7a5a', '#7a6a4a'); } },
    { y: 350, solid: [860, 342, 50, 10], draw() { box(860, 350, 50, 10, 20, '#5a6a7a', '#4a5a6a'); } },
  ],
  light() { // пар из решёток и мигание неона
    x.save(); x.globalAlpha = .18; for (let i = 0; i < 6; i++) { const X = 120 + i * 250 - CAM.x, k = ((T * .6 + i * 40) % 120) / 120; E(X, 300 - k * 120, 16 + k * 26, 10 + k * 14, '#d8e0f0', null); } x.restore();
    if ((T / 37 | 0) % 7 === 0) { x.save(); x.globalAlpha = .08; x.fillStyle = '#ff6ac8'; x.fillRect(0, 0, W, H); x.restore(); }
  },
  crowd: () => citCrowd('cit_lower'),
  exits: [
    { r: [92, 198, 64, 10], to: 'cit_city', at: [1222, 222], dir: 'u', face: 'd', door: 1 },
    { r: [1372, 198, 60, 10], to: 'cit_tunnel', at: [90, 262], dir: 'u', face: 'r', door: 1, cond: () => G.flags.hatchOpen, msg: () => [N('Люк обесточен. Над ним горит надпись: «Нужно 3 предохранителя». Щиток пуст.'), ['Рик', 'Морти, похоже, наш умник в кепке знает, где их взять. Поговори с ним.']] },
  ],
  things: [
    { r: [540, 128, 150, 68], look: [N('Лапшичная. Повар-Морти варит лапшу из… лучше не спрашивать. Пахнет вкусно и тревожно.')] },
    { r: [760, 150, 300, 30], look: [N('Конвейер. По нему едут коробки с надписью «Морти. Хрупкое». Ты надеешься, что это про посуду.')] },
    { r: [1150, 90, 70, 80], look: () => [N(G.flags.hatchOpen ? 'Щиток гудит. Все три предохранителя на месте.' : 'Щиток технического туннеля. Три пустых гнезда для предохранителей.')] },
    { r: [130, 92, 150, 30], look: [N('«Морти-таун». Здесь живут Морти, которых не взяли ни в один отряд. Зато у них лучший рамен в Цитадели.')] },
  ],
});

/* ---------- Технический туннель: лазеры ---------- */
// участок A — мигающие лучи (поймать момент), B — решётки с проёмом (встать напротив проёма), C — прожектор и тёмные ниши
const TUN = { t: 0, flash: 0, hits: 0, hint: {},
  A: [330, 450, 570], B: [740, 850, 960], N: [1170, 1320], P: 150, ON: 64, WARN: 24 };
function tunA(i) { const ph = (TUN.t + i * 50) % TUN.P; return ph < TUN.ON ? 'on' : ph > TUN.P - TUN.WARN ? 'warn' : 'off'; }
function tunGap(i) { return 262 + sin(TUN.t / 46 + i * 2.1) * 50; }
function tunSpot() { return [1245 + sin(TUN.t / 74) * 165, 262 + sin(TUN.t / 41) * 46]; }
function tunSafe(px, py) { return py < 214 && TUN.N.some(n => abs(px - n) < 20); }
function tunHit() {
  const px = PL.x, py = PL.y;
  for (let i = 0; i < 3; i++) if (tunA(i) === 'on' && abs(px - TUN.A[i]) < 8) return 'A';
  for (let i = 0; i < 3; i++) if (abs(px - TUN.B[i]) < 8 && abs(py - tunGap(i)) > 19) return 'B';
  const [sx, sy] = tunSpot(); if (px > 1060 && px < 1440 && !tunSafe(px, py) && ((px - sx) / 44) ** 2 + ((py - sy) / 24) ** 2 < 1) return 'C';
  return null;
}
function tunnelTick() {
  TUN.t += f; TUN.flash = Math.max(0, TUN.flash - f);
  const seg = tunHit(); if (!seg) return;
  TUN.hits++; const cp = PL.x < 640 ? [92, 262] : PL.x < 1040 ? [630, 262] : [1040, 262];
  cutscene(async () => {
    sfx('alarm'); CAM.shake = 5; TUN.flash = 40;
    PL.x = cp[0]; PL.y = cp[1]; PL.dir = 'r'; TRAIL.length = 0; for (const e of ENTS) if (e.follow) { e.x = cp[0] - 22 * e.follow; e.y = cp[1]; e.dir = 'r'; }
    updCam(true); await wait(24);
    const h = TUN.hint;
    if (!h[seg] && (h[seg] = 1)) await say([['Рик', { A: 'Морти, лучи мигают! Подожди, пока погаснет — и вперёд. Перед включением они дрожат.', B: 'Морти, в решётках есть проём! Он ездит вверх-вниз. Встань напротив — и проходи.', C: 'Прожектор, Морти! Прячься в тёмных нишах у стены, жди, пока свет уйдёт — и беги. С бегом — «X».' }[seg], 'angry']]);
    else toast('Тревога! Назад к началу участка', 90);
  });
}
function tunBeam(X, y0, y1, a, col = '255,60,60') { x.save(); x.globalCompositeOperation = 'lighter'; R(X - 4, y0, 8, y1 - y0, 'rgba(' + col + ',' + (.18 * a) + ')', null); R(X - 1.5, y0, 3, y1 - y0, 'rgba(' + col + ',' + (.7 * a) + ')', null); R(X - .5, y0, 1, y1 - y0, 'rgba(255,230,230,' + a + ')', null); x.restore(); }
area('cit_tunnel', {
  name: 'Технический туннель', w: 1600, h: 360, indoor: 1, noTint: 1, bounds: [30, 196, 1570, 330], music: 'tunnel', tick: tunnelTick,
  bg() {
    R(0, 0, 1600, 360, '#101218', null);
    for (let i = 0; i < 16; i++) citPanel(i * 100, 60, 100, 136, i % 2 ? '#262c38' : '#222834');
    for (const [Y, c, th] of [[70, '#4a5466', 12], [92, '#6a4a3a', 6], [176, '#3a4250', 10]]) { R(0, Y, 1600, th, c, OL, .8); R(0, Y + 1, 1600, 2, shade(c, .25), null); }
    R(0, 20, 1600, 40, '#1a1e28', null); for (let xx = 0; xx < 1600; xx += 80) { R(xx, 20, 40, 40, '#22262e', null); E(xx + 20, 40, 6, 3, '#ffe9a0', null); }
    // ниши-укрытия на участке C
    for (const n of TUN.N) { R(n - 22, 120, 44, 76, '#06070a', OL, 1.2); R(n - 22, 120, 44, 6, '#2a2e38', null); tx('УКРЫТИЕ', n, 116, 5, '#7dfff0'); }
    // таблички участков
    for (const [X, t] of [[250, 'УЧАСТОК A: МИГАЮЩИЕ ЛУЧИ'], [670, 'УЧАСТОК B: РЕШЁТКИ'], [1080, 'УЧАСТОК C: ПРОЖЕКТОР']]) { RR(X - 4, 100, 150, 14, 2, '#ffd84a', OL, .8); tx(t, X + 71, 110, 6, '#2b2220'); }
    // пол
    R(0, 196, 1600, 164, '#2a303c', null); floor(0, 196, 1600, 164, 'metal', '#2e3442', '#222834');
    for (let xx = 0; xx < 1600; xx += 40) PG([xx, 330, xx + 20, 330, xx + 10, 340, xx - 10, 340], '#ffd84a', null);
    R(0, 196, 1600, 12, grad(0, 196, 0, 208, [[0, 'rgba(0,0,0,.6)'], [1, 'rgba(0,0,0,0)']]));
    // излучатели лучей сверху и снизу
    for (const X of [...TUN.A, ...TUN.B]) { RR(X - 8, 182, 16, 12, 2, '#3a4250', OL, .8); E(X, 192, 3, 2, '#ff5a5a', null); RR(X - 8, 334, 16, 8, 2, '#3a4250', OL, .8); }
    RR(1230, 26, 30, 18, 3, '#3a4250', OL, 1); E(1245, 46, 8, 5, '#ff5a5a', OL, .8);   // прожектор на потолке
    R(20, 196, 14, 134, '#3a4250', OL, .8); R(1566, 196, 14, 134, '#3a4250', OL, .8);
  },
  under() { // световое пятно прожектора на полу
    const [sx, sy] = tunSpot(); x.save(); x.globalCompositeOperation = 'lighter'; E(sx, sy, 50, 27, 'rgba(255,80,60,.18)', null); E(sx, sy, 44, 24, 'rgba(255,200,160,.22)', null); x.restore(); E(sx, sy, 44, 24, null, 'rgba(255,90,70,.7)', 1);
    x.save(); x.globalAlpha = .12; PG([1238, 46, 1252, 46, sx + 40, sy, sx - 40, sy], '#ffb0a0', null); x.restore();
  },
  fg() { // лучи — поверх персонажей
    for (let i = 0; i < 3; i++) { const s = tunA(i), X = TUN.A[i]; if (s === 'on') tunBeam(X, 192, 336, 1); else if (s === 'warn') { if ((T / 3 | 0) % 2) tunBeam(X, 192, 336, .35); } }
    for (let i = 0; i < 3; i++) { const X = TUN.B[i], g = tunGap(i); tunBeam(X, 192, g - 20, 1, '255,150,60'); tunBeam(X, g + 20, 336, 1, '255,150,60'); E(X, g - 20, 3, 2, '#ffd84a', null); E(X, g + 20, 3, 2, '#ffd84a', null); }
  },
  light() { if (TUN.flash > 0) { x.save(); x.globalAlpha = Math.min(.45, TUN.flash / 60); x.fillStyle = '#ff2020'; x.fillRect(0, 0, W, H); x.restore(); } },
  exits: [
    { r: [30, 196, 10, 134], to: 'cit_lower', at: [1402, 214], dir: 'l', face: 'd' },
    { r: [1560, 196, 10, 134], to: 'cit_plaza', at: [1250, 198], dir: 'r', face: 'd' },
  ],
  things: [{ r: [80, 100, 200, 20], look: [N('Табличка: «Техническому персоналу: лазеры безопасны. Ну, почти. Подпись: отдел кадров (был)».')] }],
});

/* ---------- Главная площадь ---------- */
area('cit_plaza', {
  name: 'Цитадель Риков: главная площадь', w: 1500, h: 380, indoor: 1, noTint: 1, bounds: [26, 182, 1474, 356], music: () => citEsc() ? 'escape' : 'citadel',
  cacheKey: () => citEsc() ? 'e' : '',
  bg() {
    const esc = citEsc();
    roomShell({ L: 20, Rr: 1480, WT: 20, FT: 170, FB: 360, wall: '#4a5a6c', wall2: '#3a4858', wh2: 30, floor: 'metal', fc: '#7a8494', fc2: '#646e7e' });
    for (let i = 0; i < 4; i++) { const sx = 60 + i * 300; R(sx, 30, 220, 96, '#101820', OL, 1.2); citadelSkyline(sx + 5, 35, 210, 86, { gold: esc, alarm: esc }); for (let k = 1; k < 3; k++) R(sx + k * 73, 35, 3, 86, '#101820', null); }
    for (let i = 0; i < 4; i++) presPoster(290 + i * 300, 40, 46, 76, 'МОРТИ НИКОГДА НЕ СДАЮТСЯ');
    if (esc) for (let i = 0; i < 4; i++) { const sx = 60 + i * 300; RR(sx + 60, 70, 100, 20, 3, '#5a1010', '#ff5a5a', 1.5); tx('⚠ ТРЕВОГА ⚠', sx + 110, 84, 10, '#ff5a5a'); }
    // лифт к президенту
    R(1370, 60, 82, 110, '#2a3644', OL, 1.2); R(1376, 66, 70, 104, '#5a6a7a', OL); LN(1411, 66, 1411, 170, OL, 1.5); neon(1366, 34, 90, 22, 'ЛИФТ', '#7dff5a', 9);
    // служебный люк из туннеля
    R(1222, 120, 56, 50, '#2e3440', OL, 1.2); R(1228, 126, 44, 44, '#3a4250', OL, .8); for (let i = 0; i < 4; i++) PG([1228 + i * 11, 126, 1234 + i * 11, 126, 1228 + i * 11, 134], '#ffd84a', null);
    // ворота в город
    R(20, 182, 10, 176, esc ? '#5a1a1a' : '#2a6aff', null); tx(esc ? 'ВОРОТА ОТКРЫТЫ' : 'ВЫХОД В ГОРОД', 90, 176, 7, esc ? '#ff8a6a' : '#9ad0ff');
    E(750, 290, 150, 40, null, '#9aa6b8', 2); E(750, 290, 120, 30, 'rgba(255,255,255,.05)', null);
  },
  props: [{ y: 280, solid: [720, 262, 60, 18], draw() { shadow(750, 280, 40, 8); box(722, 280, 56, 18, 20, '#8a96a8', '#6a7688'); drawChar('statue2', 750, 253, { sc: 1.25, noShadow: 1 }); } }],
  crowd: () => citCrowd('cit_plaza'),
  exits: [
    { r: [20, 182, 12, 176], to: 'cit_city', at: [1735, 284], dir: 'l', face: 'l', cond: citEsc, msg: [N('Ворота площади заперты снаружи. Обратно — только через служебный люк.')] },
    { r: [1222, 180, 56, 10], to: 'cit_tunnel', at: [1520, 262], dir: 'u', face: 'l', door: 1, cond: () => !citEsc(), msg: [['Рик', 'В туннель?! Там всё рушится! В ворота, Морти, в ворота!', 'angry']] },
    { r: [1380, 180, 62, 10], to: 'cit_office', at: [400, 300], dir: 'u', door: 1, cond: () => G.flags.liftOk || citEsc(), msg: [['Охранник-Морти', 'Лифт к президенту. Назовите пароль.'], ['Рик', 'Морти, поговори с ним. Пароль, пароль... Где-то я его видел.']] },
  ],
  things: [
    { r: [720, 240, 60, 40], look: [N('Статуя Президента Морти. На табличке: «Тот, кто дал нам выбор». Почему-то у статуи прищурен левый глаз.')] },
    { r: [290, 40, 46, 80], look: [N('Плакат: «МОРТИ НИКОГДА НЕ СДАЮТСЯ». Похоже, это девиз президента. Он тут на каждом шагу.')] },
  ],
});

/* ---------- Кабинет президента ---------- */
// портал Президента: стоит на полу, вид сбоку (узкий овал); сквозь его плоскость уходят «по частям»
function standPortal(X, Y, s, back) {
  if (s <= .02) return;
  const rx = 13 * s, ry = 38 * s, cy = Y - ry + 2;
  if (back) {
    x.save(); x.globalCompositeOperation = 'lighter'; E(X, cy, rx * 3.2, ry * 1.25, rgrad(X, cy, 2, ry * 1.3, [[0, 'rgba(255,220,110,.5)'], [1, 'rgba(255,200,80,0)']]), null);
    for (let i = 0; i < 6; i++) { const k = i / 6, a = T / 9 + i * 1.1; x.strokeStyle = 'hsl(' + (40 + k * 18) + ',95%,' + (45 + k * 35) + '%)'; x.lineWidth = 2.2; x.beginPath(); xEll(X, cy, rx * (1 - k * .6), ry * (1 - k * .6), a, a + 4); x.stroke(); }
    E(X, cy, rx * .3, ry * .35, 'rgba(255,250,220,.9)', null); x.restore();
    for (let i = 0; i < 8; i++) { const k = ((T * .02 + i / 8) % 1), a = i * 2.3; E(X + cos(a) * rx * 4 * (1 - k), cy + sin(a) * ry * 1.1 * (1 - k), 1.2, 1.2, '#ffe9a0', null); }
  } else { x.save(); x.globalCompositeOperation = 'lighter'; x.strokeStyle = 'rgba(255,230,140,.9)'; x.lineWidth = 2.4; x.beginPath(); xEll(X, cy, rx, ry, -PI / 2, PI / 2); x.stroke(); x.restore(); }
}
function xEll(X, Y, rx, ry, a0, a1) { x.ellipse(X, Y, Math.max(.01, rx), Math.max(.01, ry), 0, a0, a1); }
area('cit_office', {
  name: 'Кабинет президента', w: 800, h: 360, indoor: 1, noTint: 1, bounds: [44, 176, 756, 318], music: () => G.flags.goldPortal ? 'escape' : 'citadel',
  cacheKey: () => G.flags.goldPortal ? 'g' : '',
  bg() {
    roomShell({ L: 40, Rr: 760, WT: 24, FT: 166, FB: 320, wall: '#2a2236', wall2: '#1e1828', wh2: 24, floor: 'carpet', fc: '#5a2a3a', fc2: '#4a2030' });
    R(100, 34, 600, 116, '#0a0a14', OL); citadelSkyline(106, 40, 588, 104, { gold: G.flags.goldPortal });
    if (G.flags.goldPortal) { x.save(); x.shadowColor = '#ffd84a'; x.shadowBlur = 30; E(400, 70, 70, 30, null, '#ffd84a', 6); E(400, 70, 50, 22, 'rgba(255,220,90,.5)', null); x.restore(); }
    else { E(400, 66, 220, 22, null, 'rgba(160,200,255,.35)', 2); tx('ЦЕНТРАЛЬНАЯ КОНЕЧНАЯ КРИВАЯ', 400, 52, 8, 'rgba(160,200,255,.6)'); }
    for (let i = 0; i < 7; i++) R(106 + i * 98, 40, 4, 104, '#1e1828');
    for (const fx of [70, 715]) { LN(fx, 160, fx, 70, '#c9a46a', 2.5); PG([fx, 72, fx + 26, 78, fx, 96], '#e2e86c'); E(fx + 9, 84, 3, 3, '#111', null); }
    rug(400, 262, 150, 34, '#6a1a2a', '#c9a46a');
  },
  props: [{ y: 236, solid: [320, 208, 160, 28], draw() { shadow(400, 236, 90, 7); box(320, 236, 160, 26, 24, '#3a2a1a', '#2a1e12'); R(330, 182, 30, 8, '#c9a46a', OL, .6); RR(420, 176, 36, 14, 2, '#1a1a22', OL); R(424, 179, 28, 8, '#7dff5a'); } }],
  crowd: () => citCrowd('cit_office'),
  under() {
    if (G.flags.goldPortal) { x.save(); x.globalCompositeOperation = 'lighter'; x.fillStyle = rgrad(400, 120, 10, 300, [[0, 'rgba(255,210,90,' + (.25 + sin(T / 6) * .08) + ')'], [1, 'rgba(255,210,90,0)']]); x.fillRect(0, 0, 800, 360); x.restore(); }
    const p = G.flags.evPortal; if (p) standPortal(p.x, p.y, p.s, 1);
  },
  fg() { const p = G.flags.evPortal; if (p) standPortal(p.x, p.y, p.s, 0); },
  exits: [{ r: [370, 306, 60, 20], to: 'cit_plaza', at: [1411, 198], dir: 'd', face: 'd', door: 1, cond: () => !G.flags.officeLocked, msg: [N('Двери лифта заблокированы.')] }],
  things: [{ r: [100, 150, 600, 20], look: () => [N(G.flags.goldPortal ? 'Окно сияет золотом. Там, за Кривой, — что-то, чего не видел ни один Рик.' : 'За окном светится тонкая линия на краю космоса. Будто кто-то обвёл вселенную карандашом.')] }],
});

/* ---------- толпы Цитадели ---------- */
const CIT_LINES = {
  r: ['Не смотри на меня, Морти. Не твой я Рик.', 'Цитадель уже не та. Раньше хоть кто-то был главным, кроме Морти.', 'Я Рик из вселенной, где все стулья — это Рики. Не спрашивай.', 'Говорят, президент что-то задумал. Что-то... большое.', 'На площадь не пускают даже Риков. Демократия, ага.', 'В Нижнем ярусе есть умник в кепке. Чинит всё, что не прибито. И то, что прибито.'],
  m: ['Мы все — Морти. Но некоторые из нас — Морти побольше.', 'Президент дал нам выбор. Мне не нравится, что я выбрал.', 'Ты тоже чувствуешь, будто весь мир — это круг? Странно.', 'Привет! Мы, Морти, должны держаться вместе. Наверное.', 'Девиз президента: «Морти никогда не сдаются». Его даже на кружках печатают.', 'Лифт в Нижний ярус — рядом с сувенирной лавкой. Только там пахнет лапшой и отчаянием.'],
};
const CIT_PANIC = ['ВСЕ К ШАТТЛАМ!', 'Это конец! Опять!', 'Где мой портал?! ГДЕ МОЙ ПОРТАЛ?!', 'Я же говорил — не голосуйте за Морти!', 'Президент сбежал! Без нас!', 'Морти, держи меня! Нет, лучше я тебя!'];
function citCrowd(id) {
  if (G.crowd && G.crowd[id]) return G.crowd[id]();
  const L = [], esc = citEsc();
  if (esc && (id === 'cit_city' || id === 'cit_plaza')) { for (let i = 0; i < 7; i++) { const r = i % 2 === 0; L.push(npc(r ? 'crick' + (i % 4) : 'cmorty' + (i % 5), 260 + i * 190, 226 + (i * 53) % 120, { dir: 'l', pose: 'up', emo: 'shock', wander: 160, spd: 3, talk: [[r ? 'Рик' : 'Морти', CIT_PANIC[i % CIT_PANIC.length]]] })); } return L; }
  if (esc) return L;
  const walkers = (n, x0, dx, y0) => { for (let i = 0; i < n; i++) { const r = i % 2 === 0, idn = r ? 'crick' + (i / 2 % 4 | 0) : 'cmorty' + ((i * 3) % 5 === 3 ? 4 : (i * 3) % 5); L.push(npc(idn, x0 + i * dx, y0 + (i * 37) % 110, { dir: pick(['l', 'r', 'd']), wander: 50, talk: [[r ? 'Рик' : 'Морти', CIT_LINES[r ? 'r' : 'm'][(i + (id === 'cit_city' ? 0 : 3)) % 6]]] })); } };
  if (id === 'cit_city') {
    walkers(7, 480, 160, 228);
    if (!G.flags.gateOpen) { L.push(npc('pguard', 1700, 236, { dir: 'l', pose: 'cross', key: 'g1', talk: () => gateTalk() })); L.push(npc('pguard', 1700, 330, { dir: 'l', pose: 'cross', key: 'g2', talk: () => gateTalk() })); }
    L.push(npc('attendant', 390, 262, { dir: 'l', pose: 'idle', talk: () => [['Морти-диспетчер', pick(['Ваш корабль в полной безопасности! Ну, насколько вообще что-то безопасно рядом с Риком.', 'Площадка 7 — лучшая! Тут почти никогда не взрываются.'])]] }));
  }
  if (id === 'cit_lower') {
    walkers(4, 260, 260, 250);
    L.push(npc('hacker', 425, 250, { dir: 'd', pose: 'idle', key: 'hacker', talk: () => hackerTalk() }));
    L.push(npc('courier', 780, 300, { dir: 'l', pose: 'idle', key: 'courier', talk: () => courierTalk() }));
    if (!G.flags.hunterGone) L.push(npc('hunter', 1185, 262, { dir: 'l', pose: 'cross', key: 'hunter', talk: () => hunterTalk() }));
  }
  if (id === 'cit_plaza') {
    walkers(6, 160, 170, 220);
    if (!G.flags.liftOk) L.push(npc('pguard', 1411, 200, { dir: 'd', pose: 'cross', key: 'liftg', talk: () => liftTalk() }));
  }
  return L;
}
