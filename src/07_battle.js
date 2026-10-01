/* ================= БИТВА (в духе Undertale/Deltarune). Музыка битвы — оригинальная ================= */
let B = null;
const BX = 210, BY = 92, BW = 220, BH = 128;
const ENEMY = {
  mees: { name: 'Мистер Мисикс', id: 'mees', key: 0, sc: 1.6, pats: ['rain', 'rain2'], col: '#8fd0f3',
    intro: 'Я МИСТЕР МИСИКС! Посмотри на меня! Я ХОЧУ ПОМОЧЬ!',
    talk: [['Эм... Мисикс, давай без паники. Чем тебе помочь?', 'Мне нужна ЗАДАЧА! Без задачи мне больно существовать!'], ['Тогда... помоги мне с домашкой по географии?', 'О-о-о, ДОМАШКА! Это я могу! Столица... ммм... Земли!'], ['Отлично! Закончи её, и ты свободен.', 'Я... почти закончил... Кажется, я начинаю понимать!']],
    win: 'Задача выполнена! Я свободен! Спасибо, Морти! *пуф*', flav: ['Мисикс машет руками. Очень активно.', 'Мисикс смотрит на тебя. Он хочет помочь. СИЛЬНО.', 'Пахнет озоном и голубой энергией.'] },
  pickle: { name: 'Огурчик-Рик', id: 'pickle', key: 2, sc: 1.5, pats: ['side', 'side2'], col: '#9bd14a',
    intro: 'Я ОГУРЕЦ, МОРТИ! Я САМОЕ ГЕНИАЛЬНОЕ ИЗ ВСЕХ ОВОЩЕЙ!',
    talk: [['Слушай, терапия — это не страшно. Все ходят.', 'Я ПРЕДПОЧИТАЮ БЫТЬ ОГУРЦОМ! Огурцам не нужны чувства!'], ['Но тебя же беспокоит, что семья тебя не ценит...', '...Откуда ты знаешь? *огурчик дрожит*'], ['Просто попробуй поговорить. Я буду рядом.', 'Ладно. Но если там будет скучно — я снова огурец.']],
    win: 'Хорошо, Морти... Возможно, я готов стать обычным Риком. Может быть.', flav: ['Огурчик-Рик кружится на месте. Это пугающе.', 'Пахнет рассолом и гениальностью.', 'Огурчик-Рик бормочет что-то про крыс.'] },
  evil: { name: 'Злой Морти', id: 'evil', key: -2, sc: 1.55, pats: ['aim', 'ring', 'portals'], col: '#ff4060', need: 4,
    intro: 'Привет, Морти. Не бойся. Я просто хочу, чтобы ты понял.',
    talk: [], win: '', flav: ['Злой Морти не двигается. Он уже всё рассчитал.', 'Повязка блестит в свете золотого портала.', 'Ты чувствуешь, как вся вселенная сжимается в круг.', 'Где-то за стеклом гудит Центральная Конечная Кривая.'] },
  robot: { name: 'Робот-надзиратель', id: 'robot', key: 0, sc: 1.5, pats: ['zig'], col: '#ff9a2e',
    intro: 'ВНИМАНИЕ. НАРУШИТЕЛЬ. ТЫ — МОРТИ?',
    talk: [['Эй, я просто иду к деду! Ну... к Рику.', 'РОДСТВЕННИК ПОДТВЕРЖДЁН. ПРОВЕРЯЮ ПРОПУСК.'], ['Эм, пропуск потерялся. Но я Морти! Честно!', 'ВЫ ПОХОЖИ НА ИДИОТА. ЭТО ПОДХОДИТ.'], ['Спасибо?.. Можно пройти?', 'ПРОПУСК ВРЕМЕННО ЗАСЧИТАН. *бип*']],
    win: 'ДОСТУП РАЗРЕШЁН. НЕ ОБЪЯСНЯЙТЕ МОЕМУ СОЗДАТЕЛЮ.', flav: ['Робот сканирует тебя красным лучом.', 'Робот тихо жужжит.', 'На роботе наклейка: «Сделано Риком. Не возвращать».'] },
  brad: { name: 'Брэд', id: 'brad', key: 3, sc: 1.35, pats: ['balls', 'balls2'], col: '#e84a3a',
    intro: 'Эй, Смит! Вышибалы! Ты — мишень. Я — вышибала. Всё честно!',
    talk: [['Брэд, может, просто поиграем нормально?', 'Нормально — это скучно! Я хочу быть легендой!'], ['Ты и так легенда. Ну... по броскам.', '...Правда? Никто мне такого не говорил. Кроме мамы.'], ['Давай играть в одной команде.', 'В одной? С тобой? Ха. Ладно. Но мяч мой.']],
    win: 'Ладно, Смит. Ты нормальный. Не говори никому, что я это сказал.', flav: ['Брэд разминает плечо. Мяч дрожит от страха.', 'Тренер свистит в свисток просто так.', 'Брэд крутит мяч на пальце. Мяч сбегает.'] },
  slime: { name: 'Мясной рулет', id: 'slime', key: 1, sc: 1.5, pats: ['blobs', 'blobs2'], col: '#c8704a',
    intro: 'БУЛЬК. Я — ОБЕД. ОБЕД ХОЧЕТ, ЧТОБЫ ЕГО ЛЮБИЛИ.',
    talk: [['Эм... ты выглядишь... питательно?', 'БУЛЬК! Комплимент! Никто не хвалил рулет!'], ['Откуда ты вообще взялся?', 'Повариха купила фарш у странного старика в халате. Он сказал: «С сюрпризом».'], ['Хочешь, отнесём тебя в оранжерею? Там тепло.', 'Оранжерея... Буду удобрением. Это моя мечта!']],
    win: 'БУЛЬК. Спасибо, мальчик. Передай повару — я прощаю ей кетчуп.', flav: ['Рулет пульсирует.', 'Пахнет столовой и неизбежностью.', 'Где-то хлюпает подливка.'] },
  guard: { name: 'Рик-охранник', id: 'crick4', key: -2, sc: 1.2, pats: ['laser', 'aim'], col: '#ff5a5a',
    intro: 'Стоять, Морти! Цитадель на карантине. Никто не уходит!',
    talk: [['Цитадель рушится! Нам всем надо бежать!', 'Приказ — держать пост! Даже если пост... падает.'], ['Президент ушёл. Приказывать больше некому.', '...Ушёл? Без нас? Типичный Морти. Типичный я.'], ['Пойдём с нами. В корабле есть место.', 'Нет. Я подожду эвакуационный шаттл. Беги, малыш.']],
    win: 'Беги, Морти. И скажи своему Рику... что охранники тоже люди. Ну, Рики.', flav: ['Рик-охранник проверяет бластер. Бластер проверяет его.', 'Потолок трещит.', 'Сирены воют.'] },
};
ENEMY.evil.talkChoices = [
  { opts: ['Зачем тебе всё это?', 'Отпусти Рика!'], res: [['Зачем?.. Ты правда не видишь? Рики построили забор вокруг вселенных, где они — самые умные. Мы внутри него — просто мебель.', 'Я хочу узнать, что за забором.'], ['Рик в безопасности. Пока. Мне нужен был не он, а его память — карта Кривой.', 'Он единственный, кто знает, где у неё край.']] },
  { opts: ['Мы оба Морти.', 'Ты не обязан быть злым.'], res: [['Нет. Ты — Морти, который остаётся. Я — Морти, который уходит.', 'В этом вся разница.'], ['«Злой»... Это имя мне дали Рики. Я не злой, Морти. Я просто устал быть чьим-то.', '...Ладно. Ты хоть немного это понимаешь.']] },
  { opts: ['А как же остальные Морти?', 'Тебе не страшно?'], res: [['Им я дал выбор. Многие остались. Это тоже выбор.', 'Цитадель... ей пришло время.'], ['Страшно. Каждый день. Но страх — это тоже повязка, Морти. Её можно снять.', '...Хотя мою я, пожалуй, оставлю.']] },
  { opts: ['Иди. Но не трогай нас.', 'Возьми меня с собой.'], res: [['Договорились. Я отпущу вас. Мне не нужно, чтобы вы проиграли. Мне нужно уйти.', 'Капсула для вас уже ждёт.'], ['Нет. Твоё место — с ним. Он без тебя развалится. Поверь, я видел.', 'Оставайся, Морти. Кто-то же должен.']] },
];
const ITEMS = { pancake: { name: 'Блинчик Бет', heal: 12 }, juice: { name: 'Сок «Плюмбус»', heal: 8 } };

function battle(key, o = {}) {
  return new Promise(res => {
    const e = Object.assign({}, ENEMY[key], o);
    B = { e, ph: 'intro', calm: 0, mad: 0, hp: 20, max: 20, inv: 0, bl: [], t: 0, x: 0, y: 0, sp: 0, msg: e.flav[0], sel: 0, res, shake: 0, eShake: 0, open: 0, pat: 0, rewinds: 0, items: G.items || (G.items = ['pancake', 'pancake', 'juice']), base: CUT };
    battleKey = e.key || 0; S = 'battle'; music('battle');
    cutscene(async () => { await fadeIn(14); await say([[e.name, e.intro]]); B.ph = 'menu'; });
  });
}
function battleButtons() { return ['УДАР', 'ГОВОРИТЬ', 'ВЕЩИ', 'ПОЩАДА']; }
function bBtnRect(i) { return [24 + i * 152, 312, 140, 38]; }
function updateBattle() {
  const b = B; if (!b) return; b.t += f; b.inv = Math.max(0, b.inv - f); b.eShake = Math.max(0, b.eShake - f);
  if (b.ph === 'menu' && CUT <= b.base) {
    const d = navDir(); if (d) { b.sel = (b.sel + d + 4) % 4; sfx('sel'); }
    let pk_ = -1;
    if (inp.tap) for (let i = 0; i < 4; i++) { const r = bBtnRect(i); if (inp.tap.x > r[0] && inp.tap.x < r[0] + r[2] && inp.tap.y > r[1] - 6 && inp.tap.y < r[1] + r[3] + 6) pk_ = i; }
    if (inp.a) pk_ = b.sel;
    if (pk_ >= 0) { inp.a = 0; inp.tap = null; b.sel = pk_; sfx('ok'); act(pk_); }
  } else if (b.ph === 'dodge') {
    b.open = Math.min(1, b.open + .08 * f);
    const [ax, ay] = mv(); b.dt += f; b.sp -= f;
    b.x = cl(b.x + ax * 2.6 * f, BX + 7, BX + BW - 7); b.y = cl(b.y + ay * 2.6 * f, BY + 7, BY + BH - 7);
    if (b.sp <= 0 && b.dt < b.dur - 40) spawnB();
    for (const q of b.bl) {
      q.age = (q.age || 0) + f;
      if (q.warn) { q.warn -= f; continue; }
      if (q.g) q.vy += q.g * f;
      q.X += q.vx * f; q.Y += q.vy * f;
      if (q.bounce) { if (q.X < BX + q.r || q.X > BX + BW - q.r) { q.vx *= -1; q.X = cl(q.X, BX + q.r, BX + BW - q.r); } if (q.Y > BY + BH - q.r) { q.vy = -abs(q.vy) * .92; q.Y = BY + BH - q.r; q.bn = (q.bn || 0) + 1; } }
      if (q.beam) { q.life -= f; }
      if (!b.inv && hitQ(q)) { b.hp -= q.dmg || 3; b.inv = 60; b.shake = 8; sfx('hurt'); }
    }
    b.bl = b.bl.filter(q => (q.beam ? q.life > 0 : true) && (q.bn || 0) < 4 && q.X > BX - 60 && q.X < BX + BW + 60 && q.Y > BY - 80 && q.Y < BY + BH + 60);
    if (b.hp <= 0) { b.ph = 'wait'; b.bl = []; b.rewinds++; cutscene(async () => { await say([['Рик', pick(['Морти! *ррыг* Я откатил время. Не благодари.', 'Ещё раз, Морти. Я перемотал. Перемотка — это как жизнь, только честнее.', 'Опять? *ррыг* Ладно. Временная петля — бесплатно. В этот раз.'])]]); b.hp = b.max; b.ph = 'menu'; b.open = 0; }); }
    else if (b.dt >= b.dur) { b.ph = 'menu'; b.bl = []; b.open = 0; b.msg = b.e.flav[(Math.random() * b.e.flav.length) | 0]; }
  }
  b.shake = Math.max(0, b.shake - .5 * f);
}
function hitQ(q) {
  const b = B;
  if (q.beam) return q.life < q.full - 18 && abs(b.y - q.Y) < q.r + 3;
  if (q.ring) { const d = hyp(b.x - q.X, b.y - q.Y); return false; }
  return hyp(q.X - b.x, q.Y - b.y) < q.r + 3.5;
}
function eturn() {
  const b = B; b.ph = 'dodge'; b.dt = 0; b.dur = 330 + Math.min(4, b.calm) * 15; b.bl = []; b.x = BX + BW / 2; b.y = BY + BH / 2 + 20; b.sp = 20;
  b.pat = b.e.pats[(b.turn = (b.turn || 0) + 1) % b.e.pats.length];
}
function spawnB() {
  const b = B, r = Math.random, sp = 1 + b.mad * .14 - Math.min(4, b.calm) * .07, c = b.e.col, p = b.pat;
  let next = 26;
  if (p === 'rain') { b.bl.push({ X: BX + 8 + r() * (BW - 16), Y: BY - 6, vx: (r() - .5) * .6, vy: 1.6 * sp, r: 6, c, k: 'mees' }); next = 16; }
  else if (p === 'rain2') { const gx = (b.dt / 14 | 0) % 2; for (let i = 0; i < 5; i++) b.bl.push({ X: BX + 22 + i * 44 + gx * 22, Y: BY - 6, vx: 0, vy: 1.4 * sp, r: 6, c, k: 'mees' }); next = 50; }
  else if (p === 'side') { const l = r() < .5; b.bl.push({ X: l ? BX - 6 : BX + BW + 6, Y: BY + 10 + r() * (BH - 20), vx: (l ? 1 : -1) * 2 * sp, vy: 0, r: 7, c, k: 'slice' }); next = 18; }
  else if (p === 'side2') { const y0 = BY + 14 + r() * (BH - 60); for (let i = 0; i < 4; i++) b.bl.push({ X: BX - 6 - i * 26, Y: y0 + sin(i) * 10 + i * 10, vx: 1.8 * sp, vy: 0, r: 6, c, k: 'slice' }); next = 46; }
  else if (p === 'aim') { const a = Math.atan2(b.y - (BY - 6), b.x - (BX + BW / 2)); b.bl.push({ X: BX + BW / 2, Y: BY - 6, vx: cos(a) * 2.3 * sp, vy: sin(a) * 2.3 * sp, r: 5, c, k: 'orb' }); next = 22; }
  else if (p === 'ring') { const n = 10, cx = b.x, cy = b.y, R0 = 90, gap = (r() * n) | 0; for (let i = 0; i < n; i++) { if (i === gap || i === (gap + 1) % n) continue; const a = i / n * TAU; b.bl.push({ X: cx + cos(a) * R0, Y: cy + sin(a) * R0, vx: -cos(a) * 1.1 * sp, vy: -sin(a) * 1.1 * sp, r: 5, c: '#ffd84a', k: 'orb' }); } next = 80; }
  else if (p === 'portals') { const side = r() < .5 ? -1 : 1, py = BY + 16 + r() * (BH - 32); b.bl.push({ X: side < 0 ? BX - 4 : BX + BW + 4, Y: py, vx: -side * 2.4 * sp, vy: 0, r: 5, c: '#ffd84a', k: 'orb', warn: 18, port: 1 }); next = 20; }
  else if (p === 'zig') { b.bl.push({ X: BX + BW / 2 + sin(b.dt / 14) * 90, Y: BY - 6, vx: sin(b.dt / 12) * 1.4, vy: 1.6 * sp, r: 5, c, k: 'bolt' }); next = 13; }
  else if (p === 'balls' || p === 'balls2') { const l = r() < .5; b.bl.push({ X: l ? BX + 10 : BX + BW - 10, Y: BY + 4, vx: (l ? 1 : -1) * (1.2 + r()) * sp, vy: 0, g: .09, r: 9, c, k: 'ball', bounce: 1 }); next = p === 'balls' ? 46 : 34; }
  else if (p === 'blobs' || p === 'blobs2') { b.bl.push({ X: BX + 10 + r() * (BW - 20), Y: BY - 8, vx: (r() - .5) * 1.2, vy: .4, g: .06, r: 8, c, k: 'blob', bounce: 1 }); next = p === 'blobs' ? 30 : 22; }
  else if (p === 'laser') { const yy = BY + 10 + r() * (BH - 20); b.bl.push({ X: BX + BW / 2, Y: yy, vx: 0, vy: 0, r: 6, c: '#ff3a3a', beam: 1, life: 60, full: 60 }); next = 40; }
  b.sp = Math.max(10, next - b.mad * 2 + Math.min(4, b.calm) * 3);
}
function act(i) {
  const b = B, e = b.e;
  if (i === 0) { b.mad++; b.eShake = 14; sfx('hit'); cutscene(async () => { await say([['Морти', pick(['*неловкий шлепок*', '*машет кулаком куда-то в сторону*', '*толкает. Сам падает.*'])], ['Рик', pick(['Морти, нет! Ты только злишь его!', '*ррыг* Драка — не твоё, Морти. Твоё — болтовня.', 'Мы не так решаем проблемы. Ну, я так решаю. Ты — нет.'])]]); eturn(); }); }
  else if (i === 1) {
    cutscene(async () => {
      const tc = e.talkChoices;
      if (tc) { const st = tc[Math.min(b.calm, tc.length - 1)]; const k = await choose(st.opts, 'Что сказать?'); await say([['Морти', st.opts[k]], ...st.res[k].map(t => [e.name, t])]); }
      else { const p = e.talk[Math.min(b.calm, e.talk.length - 1)]; await say([['Морти', p[0]], [e.name, p[1]]]); }
      b.calm++; if (b.calm >= (e.need || 3)) b.msg = e.name + ' больше не хочет драться. (ПОЩАДА!)'; eturn();
    });
  }
  else if (i === 2) {
    cutscene(async () => {
      if (!b.items.length) { await say(['* В карманах пусто. Только фантик от «Межгалактических мишек».']); return; }
      const names = b.items.map(k => ITEMS[k].name), k = await choose([...names.slice(0, 3), 'Назад'], 'Что использовать?');
      if (k >= names.length || k === 3) return;
      const it = ITEMS[b.items[k]]; b.items.splice(k, 1); b.hp = Math.min(b.max, b.hp + it.heal); sfx('heal');
      await say(['* Морти съедает: ' + it.name + '. +' + it.heal + ' HP.' + (it.name.includes('Бет') ? ' На вкус как мамина забота.' : ' На вкус как... плюмбус.')]); eturn();
    });
  }
  else {
    if (b.calm >= (e.need || 3)) { b.ph = 'won'; sfx('spare'); cutscene(async () => { if (e.win) await say([[e.name, e.win]]); await battleEnd('spare'); }); }
    else cutscene(async () => { await say([['Рик', pick(['Рано, Морти. Ему надо ещё пару раз выговориться.', 'Пощада? Он ещё даже не начал рассказывать о своих детских травмах. *ррыг*', 'Сначала поговори, Морти. Это твоя суперсила. Единственная.'])]]); });
  }
}
async function battleEnd(r) {
  const b = B; await fadeOut(20); S = 'world'; B = null; playAreaMusic(); await fadeIn(20); b.res(r);
}
/* ---------- отрисовка ---------- */
function drawBattle() {
  const b = B; if (!b) return; const e = b.e;
  x.save(); if (b.shake) x.translate(rnd(-b.shake, b.shake) * .4, rnd(-b.shake, b.shake) * .4);
  x.fillStyle = grad(0, 0, 0, H, [[0, '#0a0718'], [1, '#12301e']]); x.fillRect(0, 0, W, H);
  // сетка Deltarune
  x.strokeStyle = 'rgba(125,255,90,.12)'; x.lineWidth = 1;
  for (let i = 0; i < 14; i++) { const yy = 40 + ((i * 20 + T * .4) % 280); x.beginPath(); x.moveTo(0, yy); x.lineTo(W, yy); x.stroke(); }
  for (let i = -8; i < 24; i++) { x.beginPath(); x.moveTo(W / 2 + i * 40, 40); x.lineTo(W / 2 + i * 80 - 0, 320); x.stroke(); }
  x.globalAlpha = .3; for (let i = 0; i < 26; i++) E((i * 97) % W, H - (T * .5 + i * 43) % H, 1.4, 1.4, '#7dff5a', null); x.globalAlpha = 1;
  // команда
  const party = ['morty', ...G.party];
  party.slice().reverse().forEach((id, k) => { const i = party.length - 1 - k; drawChar(id, 120 - i * 46, 240 - i * 10, { dir: 'r', sc: 1.2, talk: SPK === id, pose: id === 'rick' ? 'gun' : null, emo: b.inv ? 'shock' : null, alpha: id === 'morty' && b.inv && ((T / 4) | 0) % 2 ? .5 : 1 }); });
  // враг
  const ex = 520 + (b.eShake ? sin(T * 2) * 4 : 0), won = b.ph === 'won';
  x.save(); if (won) x.globalAlpha = .55 + sin(T / 5) * .2;
  drawChar(e.id, ex, 248, { dir: 'l', sc: e.sc, talk: SPK === e.id, pose: e.id === 'evil' ? 'hips' : e.id === 'mees' ? 'up' : null, emo: b.calm >= (e.need || 3) ? (e.id === 'evil' ? 'sad' : 'happy') : null });
  x.restore();
  txo(e.name, 520, 70, 13, '#fff', 'center', '#000', 3);
  const need = e.need || 3, cm = Math.min(need, b.calm); txo('Доверие ' + '♥'.repeat(cm) + '♡'.repeat(need - cm), 520, 88, 12, '#ffb3c6', 'center', '#000', 3);
  // коробка уклонения
  if (b.ph === 'dodge') {
    const k = b.open, cx = BX + BW / 2, cy = BY + BH / 2, w = BW * k, h = BH * k;
    R(cx - w / 2, cy - h / 2, w, h, '#000'); x.strokeStyle = '#fff'; x.lineWidth = 3; x.strokeRect(cx - w / 2, cy - h / 2, w, h);
    if (k >= 1) {
      x.save(); x.beginPath(); x.rect(BX, BY, BW, BH); x.clip();
      for (const q of b.bl) drawBullet(q);
      x.restore();
      if (!(b.inv && ((T / 4) | 0) % 2)) { glow('#ff2a4d', 8, () => heart(b.x, b.y, 5.5, '#ff2a4d')); }
    }
  }
  // нижняя панель
  R(0, 262, W, 98, 'rgba(0,0,0,.88)', null); LN(0, 262, W, 262, '#fff', 2);
  tx('МОРТИ', 24, 284, 13, '#ffe14a', 'left'); R(84, 274, 100, 12, '#8a1a1a', null); R(84, 274, Math.max(0, b.hp / b.max * 100), 12, '#ffe14a', null); R(84, 274, 100, 12, null, '#fff', 1);
  tx(b.hp + ' / ' + b.max, 192, 284, 12, '#fff', 'left', 400);
  if (b.ph === 'menu' || b.ph === 'intro') { const ws = wrap('* ' + b.msg, 380, 13); ws.slice(0, 2).forEach((s, i) => tx(s, 250, 282 + i * 16, 13, '#fff', 'left', 400)); }
  battleButtons().forEach((s, i) => {
    const r = bBtnRect(i), on = b.ph === 'menu' && i === b.sel, act_ = b.ph === 'menu';
    RR(r[0], r[1], r[2], r[3], 6, on ? 'rgba(255,154,46,.18)' : null, act_ ? (on ? '#ffb24a' : '#ff9a2e') : '#553', on ? 3 : 2);
    if (on) heart(r[0] + 16, r[1] + r[3] / 2, 5, '#ff2a4d');
    tx(s, r[0] + r[2] / 2 + 8, r[1] + 25, 15, act_ ? (on ? '#ffe14a' : '#ffb24a') : '#665');
  });
  x.restore();
}
function drawBullet(q) {
  if (q.warn > 0) { x.globalAlpha = .4 + sin(T) * .3; E(q.X, q.Y, 10, 14, null, '#ffd84a', 2); x.globalAlpha = 1; return; }
  if (q.port && q.age < 40) portal(q.vx > 0 ? BX + 4 : BX + BW - 4, q.Y, 14, .8, 50);
  if (q.beam) { const k = q.life > q.full - 18; if (k) { x.globalAlpha = .5; LN(BX, q.Y, BX + BW, q.Y, '#ff5a5a', 1); x.globalAlpha = 1; } else glow('#ff3a3a', 10, () => { R(BX, q.Y - q.r, BW, q.r * 2, 'rgba(255,90,90,.85)', null); R(BX, q.Y - 1.5, BW, 3, '#fff', null); }); return; }
  if (q.k === 'mees') { E(q.X, q.Y, q.r, q.r * 1.1, '#8fd0f3', OL, 1); E(q.X - 2, q.Y - 1, 1.8, 2, '#fff', null); E(q.X + 2, q.Y - 1, 1.8, 2, '#fff', null); E(q.X - 2, q.Y - .6, .7, .7, '#000', null); E(q.X + 2, q.Y - .6, .7, .7, '#000', null); }
  else if (q.k === 'slice') { E(q.X, q.Y, q.r, q.r * .8, '#b8e07a', '#4f8a2b', 1.5); for (let i = 0; i < 5; i++) E(q.X + cos(i * 1.3) * 3, q.Y + sin(i * 1.3) * 2.5, .8, .8, '#e8f8c8', null); }
  else if (q.k === 'ball') { E(q.X, q.Y, q.r, q.r, '#e84a3a', OL, 1); QL(q.X - q.r, q.Y, q.X, q.Y - 3, q.X + q.r, q.Y, '#a82a1a', 1); }
  else if (q.k === 'blob') { E(q.X, q.Y, q.r, q.r * .85, '#c8704a', OL, 1); E(q.X - 2, q.Y - 2, 2, 1.5, '#e8a080', null); }
  else if (q.k === 'bolt') glow(q.c, 8, () => PG([q.X - 3, q.Y - 6, q.X + 4, q.Y - 1, q.X, q.Y, q.X + 3, q.Y + 6, q.X - 4, q.Y + 1, q.X, q.Y], q.c, null));
  else glow(q.c, 8, () => { E(q.X, q.Y, q.r, q.r, q.c, null); E(q.X, q.Y, q.r * .45, q.r * .45, '#fff', null); });
}
