/* ================= СЮЖЕТ: дни, события, приключения ================= */
const WEEK = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
function dayName() { return WEEK[(G.day - 1) % 7]; }
const DAYPLAN = ['school_test', 'citadel', 'school_dodge', 'pickle', 'school_slime', 'meeseeks'];
const DAYINFO = {
  school_test: { sub: 'Обычный школьный день?' }, school_dodge: { sub: 'Физкультура. Брэд. Мяч.' }, school_slime: { sub: 'В столовой что-то шевелится' },
  pickle: { sub: 'Холодильник ведёт себя странно' }, meeseeks: { sub: 'Синие помощники' }, citadel: { sub: 'Срочный вызов' },
};
function dayType(d) { if (d <= DAYPLAN.length) return DAYPLAN[d - 1]; const pool = ['school_test', 'school_dodge', 'school_slime', 'pickle', 'meeseeks']; return pool[(d * 7 + 3) % pool.length]; }
defChar('coach', { name: 'Тренер', voice: 'brad', skin: '#e8b98f', leg: 28, legW: 9, hipW: 17, pants: '#c0392b', shoe: '#efefef', shoeK: 'sneaker', torso: 27, shW: 28, waist: 26, shirt: '#c0392b', top: 'jacket', sleeve: 'long', sleeveC: '#c0392b', arm: 25, armW: 6, hw: 25, hh: 26, jaw: .95, chin: .6, eyeR: 3.2, hair: '#3a2a1a', hk: 'buzz', hat: 'cap', mustache: '#3a2a1a', mouth: 'flat' });
NAME2ID['Тренер'] = 'coach';

/* ---------- помощники ---------- */
const cyc = (...sets) => { let i = 0; return () => sets[Math.min(i++, sets.length - 1)]; };
function setNPC(key, o) { G.npcs[key] = o ? Object.assign({ id: key }, o) : null; syncEnts(); }
function syncEnts() {
  if (!AR) return;
  ENTS = ENTS.filter(e => e.follow || !e.key || !(e.key in G.npcs) || (G.npcs[e.key] && G.npcs[e.key].area === AR.id && G.npcs[e.key]._e === e));
  for (const k in G.npcs) { const n = G.npcs[k]; if (n && n.area === AR.id && !ENTS.some(e => e.key === k && !e.follow)) { const e = Object.assign(npc(n.id || k, n.x, n.y, n), { key: k }); n._e = e; ENTS.push(e); } }
}
function persist(key) { const e = ENTS.find(q => q.key === key && !q.follow), n = G.npcs[key]; if (e && n) { n.x = e.x; n.y = e.y; n.dir = e.dir; n.sit = e.sit; n.pose = e.pose; } }
function joinParty(id) { if (!G.party.includes(id)) G.party.push(id); G.npcs[id] = null; const old = ENTS.find(e => e.key === id && !e.follow); const e = npc(id, old ? old.x : PL.x - 20, old ? old.y : PL.y, { follow: G.party.length, key: id }); ENTS = ENTS.filter(q => q !== old); ENTS.push(e); TRAIL.length = 0; }
function leaveParty(id) { G.party = G.party.filter(p => p !== id); ENTS = ENTS.filter(e => !(e.follow && e.key === id)); ENTS.filter(e => e.follow).forEach((e, i) => e.follow = i + 1); }
function follower(id) { return ENTS.find(e => e.follow && e.key === id); }
const ready = () => until(() => FADE.a === 0 && !DLG);
let SCENE = null;
function trig(area, r, fn, cond) { G.trig.push({ area, r, fn, cond }); }
function objective(t) { G.obj = t; if (t) toast('Новая цель: ' + t, 160); }

/* ---------- реплики семьи ---------- */
function bethMorning(t) {
  const first = t === 'pickle' ? [['Бет', 'Морти, холодильник ворчит голосом твоего деда. Я его не открываю. Я хирург, а не экзорцист.', 'sad'], ['Морти', 'Г-голосом деда?'], ['Бет', 'Он сказал «я — огурец». Дважды. Сходи к папе в гараж, а?']]
    : [['Бет', 'Доброе утро, солнышко! Ты чего такой бледный?', 'happy'], ['Морти', 'М-мам, всё нормально... наверное.'], ['Бет', 'Завтрак на столе. И передай деду: он обещал починить тостер. Три недели назад.']];
  return cyc(first, [['Бет', 'Ты ведь знаешь, что можешь рассказать мне что угодно, да?'], ['Морти', 'Д-да, мам. Ну... почти что угодно.'], ['Бет', 'Почти — это тоже хорошо. Я просто рада, что ты у меня есть.', 'happy']], [['Бет', pick(['Беги, а то опоздаешь. И надень куртку!', 'Сегодня оперирую лошадь. Пожелай удачи. Лошади.', 'Если увидишь деда — скажи, что я его люблю. Но тостер он починит.'])]]);
}
function jerryMorning() {
  return cyc([['Джерри', 'О, Морти! По телеку шоу, где люди решают задачки. Я бы выиграл.', 'happy'], ['Морти', 'Пап, там квантовые уравнения.'], ['Джерри', '...Я бы всё равно выиграл. Эмоционально.']],
    [['Джерри', 'Может, сходим на рыбалку в выходные? Только ты и я.'], ['Морти', 'Эм... ну... может быть?'], ['Джерри', 'Правда?! Я запишу! Нет, запомню! Нет, всё-таки запишу.', 'happy']],
    [['Джерри', pick(['Не говори деду, но мне кажется, он мной гордится. Где-то глубоко. Под грудой презрения.', 'Морти, если увидишь пульт — он мой. Я его потерял в 2009-м.', 'Сегодня у меня собеседование! Ну... было вчера. Но сегодня я о нём думаю.'])]]);
}
function summerMorning() {
  return cyc([['Саммер', 'Морти, ты опять в этой футболке? А. Она у тебя одна. Сочувствую.', 'smug'], ['Морти', 'Их у меня семь! Одинаковых!'], ['Саммер', 'Это ещё грустнее.']],
    [['Саммер', 'Если дед опять потащит тебя куда-то — бери меня. Это нечестно!', 'angry'], ['Морти', 'Саммер, там опасно...'], ['Саммер', 'Я каждый день выживаю в старшей школе. Опасность — моё второе имя.']],
    [['Саммер', 'Всё, я в телефоне. Меня нет.', 'n', 'phone']]);
}
function rickBusy() {
  return cyc([['Рик', 'Не сегодня, Морти. *ррыг* Я калибрую... кое-что.', 'tired'], ['Морти', 'Что калибруешь?'], ['Рик', 'Если скажу — будешь ходить к психотерапевту до сорока лет. Иди в школу.']],
    [['Рик', 'Морти. Школа. Иди. Учись там... чему там учат. Подчинению. Обществознанию. Фу.']], [['Рик', '*ррыг* Ты ещё здесь?', 'tired']]);
}
function garageBenchLook() { if (G.flags.rickAway) return [N('Записка на верстаке: «Улетел к Птичьей Личности. Вернусь к ужину. Или через три года. Не трогай синюю кнопку. — Р.»'), N('Рядом синяя кнопка. Ты её не трогаешь. Ты же не Джерри.')]; return [N(pick(['Верстак Рика. Чертежи подписаны: «НЕ ТРОГАТЬ, ДЖЕРРИ. ЭТО И ТЕБЯ КАСАЕТСЯ, МОРТИ».', 'Колбы с жидкостями. Одна светится. Другая светится обиженно.', 'Ручка, которая пишет только правду. Записка рядом: «Не давать Джерри».']))]; }
AREAS.garage.things[1].look = garageBenchLook;

/* ---------- расстановка: утро ---------- */
function placeMorning(t) {
  const P = {};
  if (t === 'citadel') {
    G.flags.meal = 1;
    P.beth = { area: 'kitchen', x: 500, y: 238, dir: 'r', sit: 1, pose: 'idle', talk: () => [['Бет', 'Садись, милый, блинчики остывают!', 'happy']] };
    P.jerry = { area: 'kitchen', x: 565, y: 206, dir: 'd', sit: 1, pose: 'idle', talk: () => [['Джерри', 'Морти! Садись! Я тут как раз рассказываю, как почти устроился на работу.', 'happy']] };
    P.summer = { area: 'kitchen', x: 620, y: 206, dir: 'd', sit: 1, pose: 'phone', talk: () => [['Саммер', 'Садись уже, а то папа начнёт рассказывать с начала.']] };
    P.rick = { area: 'kitchen', x: 675, y: 206, dir: 'd', sit: 1, pose: 'drink', emo: 'tired', talk: () => [['Рик', '*ррыг* Садись, Морти. Семейный завтрак. Обожаю. Нет.']] };
  } else if (t === 'school_test') {
    P.beth = { area: 'kitchen', x: 190, y: 196, dir: 'd', talk: bethMorning(t) };
    P.jerry = { area: 'living', x: 650, y: 210, dir: 'd', sit: 1, talk: jerryMorning() };
    P.summer = { area: 'sroom', x: 400, y: 220, dir: 'd', pose: 'phone', talk: summerMorning() };
    P.rick = { area: 'garage', x: 180, y: 200, dir: 'u', pose: 'idle', noFace: 0, talk: rickBusy() };
  } else if (t === 'school_dodge') {
    G.flags.rickAway = 1;
    P.jerry = { area: 'kitchen', x: 565, y: 206, dir: 'd', sit: 1, talk: cyc([['Джерри', 'Морти! Мама уже ушла на работу. А дед... улетел. Так что я за главного!', 'happy'], ['Морти', 'Пап, ты ешь хлопья вилкой.'], ['Джерри', 'Потому что я за главного, Морти.']], [['Джерри', 'У тебя сегодня физкультура? Помню, я был звездой вышибал. Ну, мишенью. Звёздной мишенью.']]) };
    P.summer = { area: 'schoolhall', x: 520, y: 230, dir: 'd', pose: 'phone', talk: () => [['Саммер', 'Иди уже в спортзал, мишень.']] };
  } else if (t === 'school_slime') {
    P.beth = { area: 'living', x: 420, y: 230, dir: 'd', pose: 'phone', talk: cyc([['Бет', 'Да, доктор... Нет, лошадь не должна светиться... Морти, я на телефоне, милый!', 'shock'], ['Бет', '...Подожди. Это папа принёс вам в школу фарш? Он что-то говорил про «сюрприз»...', 'sad']], [['Бет', 'Беги в школу, солнышко. И не ешь мясной рулет. На всякий случай.']]) };
    P.jerry = { area: 'backyard', x: 560, y: 240, dir: 'r', talk: cyc([['Джерри', 'Морти! Жарю бургеры на завтрак! Это называется «бранч», я читал!', 'happy'], ['Морти', 'Пап, это угли.'], ['Джерри', 'Это ХРУСТЯЩИЙ бранч.']]) };
    P.summer = { area: 'kitchen', x: 300, y: 210, dir: 'd', talk: summerMorning() };
    P.rick = { area: 'garage', x: 200, y: 210, dir: 'd', sit: 1, emo: 'tired', talk: () => [['Рик', 'Хррр... *ррыг*... Морти, если это не конец света, дай поспать...', 'tired'], N('Рик спит прямо на стуле. На столе — пустая фляга и пакет с надписью «ФАРШ (С СЮРПРИЗОМ)».')] };
  } else if (t === 'pickle') {
    P.beth = { area: 'kitchen', x: 300, y: 214, dir: 'd', talk: bethMorning(t) };
    P.jerry = { area: 'living', x: 650, y: 210, dir: 'd', sit: 1, talk: jerryMorning() };
    P.summer = { area: 'kitchen', x: 760, y: 250, dir: 'l', pose: 'cross', talk: summerMorning() };
    P.rick = { area: 'garage', x: 640, y: 240, dir: 'd', talk: () => pickleBriefing() };
  } else if (t === 'meeseeks') {
    P.beth = { area: 'kitchen', x: 190, y: 196, dir: 'd', talk: bethMorning(t) };
    P.jerry = { area: 'living', x: 650, y: 210, dir: 'd', sit: 1, talk: jerryMorning() };
    P.summer = { area: 'hall', x: 520, y: 230, dir: 'd', pose: 'phone', talk: summerMorning() };
  }
  G.npcs = P;
}
/* ---------- вечер ---------- */
function placeEvening() {
  const t = G.type, P = {};
  G.flags.meal = 1;
  P.beth = { area: 'kitchen', x: 500, y: 238, dir: 'r', sit: 1, talk: () => [['Бет', 'Садись ужинать, Морти. Расскажешь, как прошёл день.', 'happy']] };
  P.jerry = { area: 'kitchen', x: 565, y: 206, dir: 'd', sit: 1, talk: () => [['Джерри', 'Морти! Садись! Сегодня я сам сделал салат. Почти сам.', 'happy']] };
  P.summer = { area: 'kitchen', x: 620, y: 206, dir: 'd', sit: 1, pose: 'phone', talk: () => [['Саммер', 'Садись. Чем быстрее поедим, тем быстрее я уйду в комнату.']] };
  if (t === 'school_dodge') P.rick = { area: 'backyard', x: 300, y: 250, dir: 'd', pose: 'drink', talk: () => [['Рик', 'Птичья Личность передаёт привет. Сказал, что ты «достойный птенец». Не зазнавайся. *ррыг*']] };
  else P.rick = { area: 'kitchen', x: 675, y: 206, dir: 'd', sit: 1, pose: 'drink', emo: 'tired', talk: () => [['Рик', 'Ешь, Морти. Завтра будет новый день. Хуже или лучше — статистически пятьдесят на пятьдесят.']] };
  G.npcs = P;
  trig('kitchen', [470, 170, 420, 170], dinnerScene, () => !G.flags.dinner);
}
async function sitAtTable() {
  const pts = PL.y > 250 ? [[Math.max(PL.x, 500), 300], [786, 292], [786, 238], [744, 238]] : [[cl(PL.x, 470, 786), 192], [786, 200], [786, 238], [744, 238]];
  await walkPath(PL, pts, 2); PL.sit = 1; PL.dir = 'l';
}
async function dinnerScene() {
  G.flags.dinner = 1; await sitAtTable();
  const t = G.type, L = {
    school_test: [['Бет', 'Как контрольная, милый?'], ['Морти', G.flags.score >= 3 ? 'Кажется... хорошо? Голденфолд был в шоке.' : 'Ну... Голденфолд уснул посередине. Это считается?'], ['Джерри', 'В твоём возрасте я тоже писал контрольные. Иногда даже ручкой!', 'happy'], ['Саммер', 'Пап. Что.'], ['Рик', '*ррыг* Оценки — это способ системы сказать тебе, что ты винтик. Но ты хороший винтик, Морти.']],
    school_dodge: [['Бет', 'Как физкультура?'], ['Морти', 'Я... подружился с Брэдом. Кажется.'], ['Джерри', 'С БРЭДОМ? С тем, который однажды кинул в меня мяч на родительском собрании?', 'shock'], ['Морти', 'Пап, он кинул его в окно. Ты просто стоял за окном.'], ['Джерри', 'Это не меняет сути.']],
    school_slime: [['Бет', 'Говорят, в школе был... инцидент в столовой?'], ['Морти', 'Мясной рулет ожил. Из-за фарша «с сюрпризом».'], ['Рик', '...Я ничего не знаю ни о каком фарше.', 'smug'], ['Бет', 'ПАПА.', 'angry'], ['Рик', 'Ладно, ладно! Это был фарш из измерения, где еда разумна. Он хотя бы был вежливый!']],
    pickle: [['Саммер', 'Мам, ты не поверишь: дед превратил себя в огурец. Ну, его клон.'], ['Бет', 'Папа, мы же договаривались. Никаких огурцов за столом.', 'angry'], ['Рик', 'Это был не я, Бет! Это был я из другого измерения. Это совершенно разные огурцы.'], ['Джерри', 'А можно... мне тоже стать огурцом? Просто на денёк?'], ['Все', '...Нет.']],
    meeseeks: [['Бет', 'Мне звонили из школы. Говорят, там были... синие помощники?'], ['Морти', 'Это Мисиксы, мам. Дед нажал кнопку. Сорок раз.'], ['Рик', 'Тридцать девять! Один раз мне просто помогали нажать.'], ['Джерри', 'Я бы тоже хотел помощника. Чтобы помог мне с гольфом.'], ['Рик', 'Нет, Джерри. Мы это уже проходили.', 'angry']],
    citadel: [['Бет', 'Ну, как прошёл день? Куда вы летали?'], ['Морти', 'Цитадель Риков... эм... развалилась.'], ['Джерри', 'Это та, с фуд-кортом?'], ['Рик', 'Да, Джерри. С фуд-кортом.', 'tired'], ['Саммер', 'Подожди. Вы бросили меня за завтраком ради ЭТОГО?!', 'angry'], ['Рик', 'Поверь, Саммер, это была не та вечеринка. *ррыг*'], ['Бет', 'Главное, что вы дома. Оба.', 'happy'], ['Рик', '...Ага. Оба.']],
  }[t] || [['Бет', 'Как прошёл день?'], ['Морти', 'Нормально. Странно, но нормально.']];
  await say(L);
  await say([N('Ужин закончился. Тарелки пусты, а в доме пахнет чем-то тёплым и домашним.')]);
  PL.sit = 0; await walkTo(PL, 770, 210, 2);
  objective('Иди спать (кровать в твоей комнате)');
}

/* ---------- кровать и сон ---------- */
async function bedLook() {
  if (!G.flags.eventDone) return say([N(pick(['Ты только что встал. Кровать смотрит на тебя с укором.', 'Рано спать. День ещё даже не начался.', 'Можно было бы поспать... но тогда пропустишь всё интересное.']))]);
  const k = await choose(['Лечь спать', 'Ещё нет'], 'Лечь спать? День закончится, и начнётся следующий.');
  if (k === 0) await goSleep();
}
async function goSleep() {
  G.obj = ''; await walkTo(PL, 138, 262, 2);
  PL.hidden = 1; G.flags.inBed = 1; G.time = 'night'; music('night');
  await wait(40);
  await say([['Морти', pick(['Ну и денёк... Хотя у меня каждый день «ну и денёк».', 'Интересно, а другие Морти тоже сейчас ложатся спать?', 'Завтра будет нормальный день. Обязательно. Наверное.', 'Спокойной ночи, вселенная. Пожалуйста, не ломайся до утра.']), 'tired']]);
  await wait(150);
  await fadeOut(70);
  G.day++; saveGame(); await wait(30);
  startDay();
}
function fridgeLook() {
  if (G.type === 'pickle' && G.flags.pickleQuest && !G.flags.pickleDone) return enterFridge();
  return [N(pick(['В холодильнике: молоко, яйца и баночка с надписью «НЕ ЕСТЬ. ЭТО ПОРТАЛ». Ты закрываешь дверцу.', 'На полке лежит огурец. Обычный. Ты проверил. Дважды.', 'Холодильник урчит. Ты надеешься, что это мотор.']))];
}
function shipLook() { return [N(G.type === 'citadel' && G.flags.toShip ? 'Корабль Рика. Дверца открыта.' : 'Космический корабль Рика. На лобовом стекле записка: «Джерри, это не машина для свиданий».')]; }

/* ---------- начало дня ---------- */
function resetDay() {
  G.time = 'morning'; G.flags = {}; G.party = []; G.crowd = null; G.trig = []; G.obj = ''; G.npcs = {}; G.items = ['pancake', 'pancake', 'juice'];
  PL.sit = 0; PL.hidden = 0; PL.tgt = null; DEBRIS.length = 0;
}
function startDay() {
  cutscene(async () => {
    resetDay();
    const t = G.type = dayType(G.day);
    placeMorning(t);
    G.flags.inBed = 1; S = 'world'; G.musicLock = 1; FADE.a = 1; FADE.to = 1;
    enterArea('mroom', 136, 268, 'd'); PL.hidden = 1;
    await showCard('ДЕНЬ ' + G.day, dayName() + ' — ' + DAYINFO[t].sub, 170);
    G.musicLock = 0;
    if (t !== 'meeseeks') music('morning'); else music(null);
    await fadeIn(50); await wait(50);
    if (t === 'meeseeks') await meeseeksWake(); else await normalWake(t);
    saveGame();
  });
}
async function getUp() { G.flags.inBed = 0; PL.hidden = 0; PL.x = 140; PL.y = 268; PL.dir = 'd'; sfx('step'); await wait(16); }
async function normalWake(t) {
  await say([N(pick(['Утро. Солнце светит прямо в глаза. Как будто специально.', 'Будильник орёт так, будто его пытает Рик.', 'Утро. Птицы поют. Одна из них, кажется, с тремя глазами.']))]);
  await getUp();
  const th = { school_test: 'Ещё один обычный школьный день. Надеюсь, по-настоящему обычный.', school_dodge: 'Сегодня физкультура... и Брэд. Может, притвориться больным? Нет, мама проверит.', school_slime: 'Странно. Мне снилось, что меня ест мясной рулет. Глупость какая.', pickle: 'Почему внизу кто-то кричит «я огурец»?..', citadel: 'Пахнет блинчиками... Мама опять готовит завтрак на всю семью. Даже на деда.' }[t];
  await say([['Морти', th, t === 'pickle' ? 'shock' : null]]);
  objective({ school_test: 'Иди в школу', school_dodge: 'Иди в школу', school_slime: 'Иди в школу', pickle: 'Найди Рика в гараже', citadel: 'Спустись на кухню к завтраку' }[t]);
  if (t === 'citadel') trig('kitchen', [440, 160, 460, 180], breakfastSummons, () => !G.flags.summons);
}
async function finishEvent(msg) {
  G.flags.eventDone = 1; G.done[G.type] = (G.done[G.type] || 0) + 1;
  G.time = 'evening'; playAreaMusic();
  placeEvening(); syncEnts();
  if (msg) await say([N(msg)]);
  objective('Вернись домой');
}

/* ---------- хуки мира ---------- */
function onEnterArea(id, prev) {
  const t = G.type;
  if (G.flags.eventDone && !G.flags.homeEve && ['living', 'kitchen', 'garage', 'hall', 'mroom'].includes(id)) { G.flags.homeEve = 1; G.obj = G.flags.dinner ? 'Иди спать (кровать в твоей комнате)' : 'Поужинай с семьёй на кухне или иди спать'; }
  if (id === 'schoolhall' && t.startsWith('school') && !G.flags.schoolIntro && !G.flags.eventDone) { G.flags.schoolIntro = 1; cutscene(() => schoolIntro(t)); }
  if (id === 'classroom' && t === 'school_test' && G.flags.schoolIntro && !G.flags.testDone) cutscene(testScene);
  if (id === 'gym' && t === 'school_dodge' && G.flags.schoolIntro && !G.flags.dodgeDone) cutscene(dodgeScene);
  if (id === 'cafeteria' && t === 'school_slime' && G.flags.schoolIntro && !G.flags.slimeDone) cutscene(slimeScene);
  if (id === 'garage' && t === 'citadel' && G.flags.summons && !G.flags.garageTalk) cutscene(garageSummons);
  if (id === 'schoolhall' && t === 'meeseeks' && G.flags.meesStart && !G.flags.meesHall) cutscene(meesHall);
  if (id === 'gym' && t === 'meeseeks' && G.flags.meesHall && !G.flags.meesDone) cutscene(meesBoss);
  if (id === 'cit_plaza' && G.flags.escape && !G.flags.guardDone) trig('cit_plaza', [400, 170, 300, 200], escapeGuard, () => !G.flags.guardDone);
  if (id === 'cit_dock' && G.flags.escape) cutscene(escapeShip);
  if (id === 'cit_plaza' && t === 'citadel' && !G.flags.escape && !G.flags.plazaSeen) { G.flags.plazaSeen = 1; cutscene(async () => { await ready(); await say([['Рик', 'Площадь Цитадели. Раньше тут продавали портальную жидкость и чувство превосходства. Теперь — плакаты.'], ['Морти', '«Голосуй за Морти»... Рик, они правда выбрали Морти президентом?'], ['Рик', 'Демократия, Морти. Самая переоценённая технология во вселенной. Лифт — в конце зала.']]); objective('Поднимись на лифте к президенту'); }); }
  if (id === 'cit_office' && t === 'citadel' && !G.flags.evilTalk) cutscene(evilOffice);
  if (id === 'fridge' && !G.flags.fridgeIntro) { G.flags.fridgeIntro = 1; cutscene(fridgeIntro); }
}
function storyTick() {
  if (S !== 'world' || CUT || DLG || CHOICE) return;
  for (const tg of G.trig) if (AR.id === tg.area && (!tg.cond || tg.cond()) && inRect(PL.x, PL.y, tg.r)) { cutscene(tg.fn); break; }
  if (G.portal && G.portal.area === AR.id && hyp(PL.x - G.portal.x, (PL.y - G.portal.y) * 1.5) < 22) { const p = G.portal; G.portal = null; cutscene(p.cb); }
  if (G.flags.escape && /^cit_/.test(AR.id)) debrisTick();
}
function underFX() { if (G.portal && G.portal.area === AR.id) { portal(G.portal.x, G.portal.y - 26, 34, 1, G.portal.hue || 105); x.save(); x.globalCompositeOperation = 'lighter'; x.fillStyle = rgrad(G.portal.x, G.portal.y - 20, 4, 90, [[0, 'rgba(125,255,90,.25)'], [1, 'rgba(125,255,90,0)']]); x.fillRect(G.portal.x - 100, G.portal.y - 120, 200, 200); x.restore(); } }

/* ---------- ШКОЛА ---------- */
async function schoolIntro(t) {
  await ready(); sfx('bell'); await wait(40);
  if (t === 'school_test') {
    setNPC('ethan', { area: 'schoolhall', x: 300, y: 196, dir: 'd' }); const e = entAt('ethan');
    await walkTo(e, PL.x + 34, PL.y, 2); turn(e, 'l'); turn(PL, 'r');
    await say([['Итан', 'Йо, Морти! Ты слышал? Голденфолд устроил внезапную контрольную!', 'shock'], ['Морти', 'Ч-что?! Я ничего не учил!', 'shock'], ['Итан', 'Никто не учил. Она же внезапная. В этом весь смысл, бро.'], ['Итан', 'Пошли в класс 3Б. Если что — я списываю у тебя, ты у меня. Замкнутый круг.']]);
    await walkTo(e, 340, 172, 2); e.hidden = 1; setNPC('ethan', null);
    objective('Иди в класс 3Б');
  } else if (t === 'school_dodge') {
    const s = entAt('summer'); if (s) { await walkTo(s, PL.x + 34, PL.y, 2); turn(s, 'l'); turn(PL, 'r'); }
    await say([['Саммер', 'О, Морти. Слышала, у вас сегодня вышибалы. Брэд уже разминается.', 'smug'], ['Морти', 'Б-Брэд? Тот, который кидает мяч со скоростью звука?'], ['Саммер', 'Он самый. Удачи, мишень. Я буду смотреть с трибуны. С попкорном.', 'happy']]);
    if (s) { persist('summer'); G.npcs.summer.talk = () => [['Саммер', 'Спортзал — в конце коридора. Беги, пока Брэд не нашёл тебя сам.']]; }
    objective('Иди в спортзал');
  } else if (t === 'school_slime') {
    setNPC('jessica', { area: 'schoolhall', x: 700, y: 200, dir: 'd' }); const j = entAt('jessica');
    await walkTo(j, PL.x + 34, PL.y, 2.2); turn(j, 'l'); turn(PL, 'r');
    await say([['Джессика', 'Морти! Наконец-то! В столовой что-то не так. Мясной рулет... он ДВИГАЕТСЯ.', 'shock'], ['Морти', 'Д-двигается? Как... как желе?'], ['Джессика', 'Как ЖИВОЕ, Морти. Повариха заперлась в морозилке. Ты же всегда знаешь, что делать с такими штуками!'], ['Морти', 'Я?! Ну... да. Наверное. Иногда. Пошли!']]);
    joinParty('jessica');
    objective('Иди в столовую');
  }
}
async function testScene() {
  await ready();
  setNPC('gold', { area: 'classroom', x: 340, y: 176, dir: 'd' }); setNPC('jessica', { area: 'classroom', x: 440, y: 256, dir: 'u', sit: 1 }); setNPC('ethan', { area: 'classroom', x: 340, y: 256, dir: 'u', sit: 1 });
  await say([['Мистер Голденфолд', 'А, Смит. Как мило, что вы почтили нас своим присутствием. Садитесь. Последняя парта. Как обычно.']]);
  await walkPath(PL, [[610, 318], [360, 318], [340, 314]], 2); PL.sit = 1; PL.dir = 'u';
  await say([['Мистер Голденфолд', 'Итак, класс! Внезапная контрольная. Четыре вопроса. Кто ответит на все — получит... моё уважение. Его у меня немного.']]);
  const Q = [
    ['Вопрос первый: 2x + 3 = 11. Чему равен x?', ['x = 4', 'x = Рик знает', 'x — в другом измерении'], 0, ['Правильно, Смит! Я... удивлён. Вы не заболели?', 'Смит, ваш дед не может быть ответом на всё!', '...Это слишком глубоко для утра. Неверно.']],
    ['Вопрос второй: столица Франции?', ['Плюмбус', 'Париж', 'Цитадель Риков'], 1, ['Плюмбус — это бытовой прибор, Смит. Наверное. Я не уверен.', 'Верно! Париж. Город любви и... очередей.', 'Я даже не хочу знать, что это.']],
    ['Вопрос третий: что быстрее — свет или звук?', ['Звук', 'Свет', 'Рик, когда пора уходить от ответственности'], 1, ['Нет. Иначе вы бы слышали гром до молнии.', 'Правильно. Свет. Как свет в конце моей карьеры.', '...Признаю, это тоже правда. Но засчитать не могу.']],
    ['Последний вопрос: почему вас не было на уроках на прошлой неделе?', ['Болел', 'Спасал вселенную', 'Был огурцом'], -1, ['Болели? Справку, Смит. Справку.', 'Спасали вселенную? Ха. И как, спасли?', 'Был... огурцом. Знаете, я даже не удивлён.']],
  ];
  let sc = 0;
  for (const q of Q) { const k = await choose(q[1], q[0]); if (k === q[2]) { sc++; sfx('heal'); } await say([['Морти', q[1][k]], ['Мистер Голденфолд', q[3][k], k === q[2] ? 'shock' : null]]); }
  G.flags.score = sc;
  const g = entAt('gold'); g.emo = 'tired';
  await say([N('Мистер Голденфолд садится за стол... и засыпает.'), ['Мистер Голденфолд', 'Хррр... нет... только не газонокосилка... только не сон во сне...', 'tired'], ['Итан', 'Он опять видит тот кошмар. Говорят, кто-то однажды залез к нему в сон.'], ['Морти', '(Ага. Я и Рик. И собака. Долгая история.)']]);
  await say([N('Джессика оборачивается и кладёт на твою парту сложенную записку.')]);
  const j = entAt('jessica'); if (j) j.dir = 'd';
  await say([N('В записке: «Ты придёшь на танцы в пятницу? — Дж.»')]);
  const k = await choose(['Написать «Да!»', 'Написать «Может быть...»', 'Нарисовать сердечко']);
  G.done.jessica = (G.done.jessica || 0) + (k === 1 ? 0 : 1);
  await say([[['Джессика', 'Отлично! Тогда в пятницу. Не опаздывай, Морти.', 'happy']], [['Джессика', '«Может быть»? Ладно, загадочный Морти. Я подожду.', 'smug']], [['Джессика', '...Это очень мило. И очень кривое сердечко.', 'blush']]][k]);
  if (j) j.dir = 'u';
  sfx('bell'); await wait(30); g.emo = null;
  await say([['Мистер Голденфолд', 'А?! Что? Я не спал! Я... медитировал. Так. Оценки.'], ['Мистер Голденфолд', 'Смит — ' + ['двойка. Но с душой', 'тройка. Твёрдая, как мой матрас', 'четвёрка. Не знаю как', 'пятёрка?! Кто вы и что сделали со Смитом?!', 'пять с плюсом. Это невозможно'][sc] + '.'], ['Мистер Голденфолд', 'Все свободны. Идите домой и не говорите никому, что я спал.']]);
  G.flags.testDone = 1; PL.sit = 0; await walkTo(PL, 360, 320, 2);
  setNPC('ethan', null); setNPC('gold', { area: 'classroom', x: 150, y: 210, dir: 'd', talk: () => [['Мистер Голденфолд', 'Смит, идите домой. И передайте деду... ничего не передавайте. Ничего.']] });
  setNPC('jessica', { area: 'schoolhall', x: 160, y: 230, dir: 'r', talk: () => [['Джессика', 'Пока, Морти! Не забудь про пятницу!', 'happy']] });
  await finishEvent('Уроки закончились. На улице уже вечереет.');
}
async function dodgeScene() {
  await ready();
  setNPC('coach', { area: 'gym', x: 500, y: 200, dir: 'd' }); setNPC('brad', { area: 'gym', x: 700, y: 250, dir: 'l', pose: 'fists' });
  G.crowd = { gym: () => [npc('stu1', 200, 250, { dir: 'r' }), npc('stu2', 260, 290, { dir: 'r' }), npc('stu5', 820, 240, { dir: 'l' }), npc('summer', 120, 210, { dir: 'r', pose: 'phone', talk: () => [['Саммер', 'Давай, Морти! Ну... не умирай хотя бы.']] })] };
  ENTS = ENTS.concat(G.crowd.gym());
  await walkTo(PL, 400, 250, 2); turn(PL, 'r');
  await say([['Тренер', 'ВЫШИБАЛЫ! *свисток* Смит против Брэда! Один на один! Как в старые добрые времена, когда школам разрешали всё!'], ['Брэд', 'Смит! Готовься. Мой бросок однажды сломал звуковой барьер. И нос завучу.', 'smug', 'fists'], ['Морти', 'М-может, я просто постою в сторонке?'], ['Тренер', 'НИКАКИХ СТОРОНОК! *свисток*']]);
  await fadeOut(10, '#fff'); const r = await battle('brad');
  await ready();
  const b = entAt('brad'); if (b) { b.pose = 'idle'; b.emo = 'happy'; }
  await say([['Брэд', 'Слушай... а ты ничего, Смит. Никто раньше не пытался со мной поговорить. Все просто убегали.'], ['Морти', 'Ну... я тоже пытался убежать. Просто медленно.'], ['Брэд', 'Ха! Ладно. Сядешь завтра с нами в столовой. Если хочешь.', 'happy'], ['Тренер', 'Это... это самая трогательная игра в вышибалы, что я видел. *всхлип* *свисток*']]);
  G.flags.dodgeDone = 1; G.crowd = null; G.done.brad = 1;
  setNPC('coach', null); setNPC('brad', null); ENTS = ENTS.filter(e => !['stu1', 'stu2', 'stu5', 'summer'].includes(e.id) || e.follow);
  sfx('bell');
  await finishEvent('Звенит последний звонок. Школьный день позади. Вечереет.');
}
async function slimeScene() {
  await ready();
  setNPC('slime', { area: 'cafeteria', x: 450, y: 280, dir: 'd', ghost: 0 });
  G.crowd = { cafeteria: () => [npc('stu3', 140, 290, { dir: 'r', emo: 'shock' }), npc('stu6', 780, 290, { dir: 'l', emo: 'shock' })] }; ENTS = ENTS.concat(G.crowd.cafeteria());
  await say([N('Посреди столовой колышется огромный мясной рулет. У него есть глаза. И, кажется, мнение.'), ['Джессика', 'Вот! Я же говорила!', 'shock'], ['Мясной рулет', 'БУЛЬК. ВЫ. ПРИШЛИ. ПООБЕДАТЬ?'], ['Морти', 'Н-нет! Мы пришли... поговорить!']]);
  await fadeOut(10, '#fff'); await battle('slime');
  await ready();
  setNPC('slime', null); G.flags.slimeDone = 1;
  await say([N('Рулет довольно булькает и уползает в сторону оранжереи. Ученики аплодируют.'), ['Джессика', 'Морти... ты просто поговорил с ним. С мясным рулетом. Это было... странно смело.', 'happy'], ['Морти', 'Я много говорю с... эм... необычными существами. Семейное.'], ['Джессика', 'Знаешь, ты не такой, как все. В хорошем смысле.', 'blush'], ['Морти', '(«Фарш с сюрпризом»... Купленный у старика в халате. РИК!)', 'angry']]);
  leaveParty('jessica'); G.crowd = null;
  setNPC('jessica', { area: 'schoolhall', x: 700, y: 220, dir: 'd', talk: () => [['Джессика', 'Пока, Морти! Спасибо, что спас обед. Ну... от самого обеда.', 'happy']] });
  sfx('bell');
  await finishEvent('Уроки закончились. Повариху вытащили из морозилки. Вечереет.');
}

/* ---------- ПРИКЛЮЧЕНИЕ: Мисиксы ---------- */
const MEES_LINES = ['Я МИСТЕР МИСИКС! Посмотри на меня!', 'Существовать — больно! Дай мне задачу!', 'Мы пытаемся помочь! Нас стало слишком много!', 'Ты не видел Рика? Он нажал кнопку и ушёл!', 'Мне нужно помочь кому-нибудь с осанкой! С ЧЬЕЙ-НИБУДЬ!', 'Я Мистер Мисикс! Ой, извини, я думал, ты — моя задача!'];
async function meeseeksWake() {
  await wait(30); sfx('portal'); G.portal = null;
  G.flags.roomPortal = 1; setNPC('rick', { area: 'mroom', x: 470, y: 250, dir: 'l', alpha: 1 }); const r = entAt('rick'); r.hidden = 1;
  const pp = { area: 'mroom', x: 500, y: 258, cb: () => 0 }; G.portal = Object.assign(pp, { cb: async () => { } });
  await wait(40); r.hidden = 0; r.x = 500; await walkTo(r, 420, 262, 2.2); music('morning');
  await say([['Рик', 'МОРТИ! *ррыг* Вставай! У нас ЧП межпространственного масштаба!', 'angry'], ['Морти', 'Р-рик?! Сейчас семь утра! Ты опять сломал реальность?!', 'shock']]);
  await getUp();
  await say([['Рик', 'Я нажал кнопку на коробке Мисикса. Один раз! Ну... штук сорок. Короче, они уже в твоей школе.'], ['Морти', 'В МОЕЙ школе?!'], ['Рик', 'Прыгай в портал, Морти. И помни: Мисикс не злой. Он просто очень хочет помочь. Очень.']]);
  joinParty('rick'); G.flags.meesStart = 1;
  G.crowd = { schoolhall: meesCrowd, classroom: () => [], gym: () => [] };
  G.portal = { area: 'mroom', x: 500, y: 258, cb: async () => { sfx('portal'); await fadeOut(18, '#7dff5a'); G.portal = null; enterArea('schoolhall', 160, 250, 'r'); await fadeIn(18); } };
  objective('Прыгни в портал');
}
function meesCrowd() { const L = []; for (let i = 0; i < 9; i++) L.push(npc('mees', 260 + i * 120, 190 + (i * 41) % 110, { dir: pick(['l', 'r']), wander: 50, talk: () => [['Мистер Мисикс', MEES_LINES[(Math.random() * MEES_LINES.length) | 0], 'happy']] })); return L; }
async function meesHall() {
  await ready(); G.flags.meesHall = 1;
  setNPC('jessica', { area: 'schoolhall', x: 420, y: 230, dir: 'l' }); const j = entAt('jessica');
  await say([['Рик', 'Школа, Морти. *ррыг* Единственное место, где я рад, что не учусь.'], ['Джессика', 'МОРТИ! Слава богу! Один Мисикс уже три часа помогает мне с причёской!', 'shock'], ['Морти', 'Джессика?! Ты в порядке?!'], ['Джессика', 'Я в порядке! У меня теперь ОЧЕНЬ ровная чёлка! Но они не останавливаются!']]);
  const k = await choose(['Помочь им', 'Сбежать'], 'Джессика: «Они не успокоятся, пока не выполнят задачу! Что делать?»');
  if (k === 0) await say([['Морти', 'Давайте им поможем. Они же просто хотят быть нужными.'], ['Рик', '*ррыг* ...Это было почти мудро. Фу.']]);
  else await say([['Морти', 'А может, ну их? Сбежим?'], ['Джессика', 'Морти! Мы не можем... Ладно. Но если что — я с тобой.']]);
  await say([['Джессика', 'Их главный — в спортзале. Самый большой. Он всем раздаёт задания!'], ['Рик', 'Значит, туда. Морти, я в тебя верю. Это редкий случай, запомни его.']]);
  persist('jessica'); G.npcs.jessica.talk = () => [['Джессика', 'Главный Мисикс — в спортзале! Осторожнее с роботом-надзирателем, он сошёл с ума от Мисиксов.']];
  objective('Найди главного Мисикса в спортзале');
  trig('schoolhall', [800, 160, 120, 170], async () => {
    G.flags.robot1 = 1; setNPC('robot', { area: 'schoolhall', x: PL.x + 90, y: PL.y, dir: 'l' });
    await say([['Робот-надзиратель', 'КТО ТУТ БЕЗ ПРОПУСКА?! ЭТО ШКОЛА!']]);
    await fadeOut(10, '#fff'); await battle('robot', { name: 'Робот-надзиратель', key: 0, intro: 'КТО ТУТ БЕЗ ПРОПУСКА?! ЭТО ШКОЛА!' }); await ready();
    setNPC('robot', null); await say([N('Робот-надзиратель вежливо отъезжает в сторону. На табличке у него теперь написано: «Хороший мальчик».')]);
  }, () => !G.flags.robot1);
}
async function meesBoss() {
  await ready();
  const L = []; for (let i = 0; i < 7; i++) L.push(npc('mees', 200 + i * 100, 210 + (i % 2) * 40, { dir: i < 4 ? 'r' : 'l', pose: 'up' })); ENTS = ENTS.concat(L);
  setNPC('meesboss', { area: 'gym', id: 'mees', x: 500, y: 214, dir: 'd', sc: 1.35, pose: 'up' });
  await say([['Мистер Мисикс', 'ВСЕ ЗАДАЧИ — ЧЕРЕЗ МЕНЯ! Я ГЛАВНЫЙ МИСИКС! Я ЗДЕСЬ, ЧТОБЫ ПОМОГАТЬ ПОМОГАЮЩИМ!', 'happy'], ['Рик', 'Он создал иерархию. Мисиксы с иерархией. *ррыг* Я этого боялся.']]);
  await fadeOut(10, '#fff'); await battle('mees'); await ready();
  sfx('spare'); for (const e of ENTS) if (e.id === 'mees') e.hidden = 1; setNPC('meesboss', null);
  await say([N('*ПУФ* *ПУФ* *ПУФ* — Мисиксы исчезают один за другим. Каждый — с улыбкой.'), ['Рик', 'Неплохо, Морти. *ррыг* Почти как настоящий герой. Почти.'], ['Морти', 'Мы можем вернуться домой?'], ['Рик', 'Конечно. Но сначала — ужин у Бет. Я слышал, будут блинчики. Мне не говорили, я подслушал.']]);
  G.flags.meesDone = 1; G.crowd = null;
  await finishEvent();
  sfx('portal'); await fadeOut(20, '#7dff5a'); leaveParty('rick'); enterArea('living', 500, 260, 'd'); await fadeIn(20);
  objective('Поужинай с семьёй на кухне или иди спать'); G.flags.homeEve = 1;
}

/* ---------- ПРИКЛЮЧЕНИЕ: Огурчик-Рик ---------- */
async function pickleBriefing() {
  if (G.flags.pickleQuest) return say([['Рик', 'Холодильник, Морти. На кухне. Ну, ты понял.']]);
  await say([['Рик', 'Морти! Хорошо, что ты пришёл. *ррыг* У нас огуречная ситуация.'], ['Морти', 'Огуречная?..'], ['Рик', 'Мой клон из соседнего измерения превратил себя в огурец. Чтобы не идти на семейную терапию.'], ['Морти', 'Зачем?! Это вообще законно?!', 'shock'], ['Рик', 'Гениально — вот как это называется. Но теперь он сидит в измерении внутри нашего холодильника и объявил себя королём.'], ['Рик', 'Поговоришь с ним, Морти. Ты же душевный парень. Я пойду рядом. Для моральной поддержки и сарказма.']]);
  const s = entAt('summer') || null;
  setNPC('summer', { area: 'garage', x: 60, y: 250, dir: 'r' }); const sm = entAt('summer'); await walkTo(sm, PL.x - 34, PL.y, 2.4);
  await say([['Саммер', 'Стоп-стоп-стоп! Вы идёте в холодильник? Я с вами!', 'angry'], ['Рик', 'Саммер, это огуречное дело.'], ['Саммер', 'Мне плевать. Мне нужен материал для шантажа на всю жизнь.', 'smug'], ['Рик', '...Уважаю. Пошли.']]);
  joinParty('rick'); joinParty('summer'); G.flags.pickleQuest = 1;
  objective('Открой холодильник на кухне');
}
async function enterFridge() {
  await say([N('Ты открываешь холодильник. Вместо полок — зелёная воронка портала.'), ['Рик', 'После тебя, Морти.']]);
  sfx('portal'); await fadeOut(18, '#7dff5a'); G.flags.fridgeLocked = 1; enterArea('fridge', 110, 270, 'r'); await fadeIn(18);
}
async function fridgeIntro() {
  await ready();
  await say([['Саммер', 'Вау. Тут холодно, как в сердце папиного начальника.'], ['Рик', 'Измерение внутри холодильника. Всё огромное, всё в инее, всё немного просрочено.'], ['Рик', 'Огурец где-то в конце. На троне. Конечно, на троне. Я бы тоже сел на трон.']]);
  objective('Найди Огурчика-Рика');
  trig('fridge', [560, 190, 80, 180], async () => {
    G.flags.fguard = 1; setNPC('fguard', { area: 'fridge', id: 'robot', x: PL.x + 100, y: 280, dir: 'l', col: '#9ad8f0' });
    await say([['Страж холодильника', 'ПРОВЕРКА СРОКА ГОДНОСТИ. ТЫ... ПРОСРОЧЕН.']]);
    await fadeOut(10, '#fff'); await battle('robot', { name: 'Страж холодильника', key: 2, intro: 'ПРОВЕРКА СРОКА ГОДНОСТИ. ТЫ ПРОСРОЧЕН.' }); await ready();
    setNPC('fguard', null); await say([['Саммер', 'Ты уговорил холодильного робота. Ты официально самый странный человек, которого я знаю.']]);
  }, () => !G.flags.fguard);
  trig('fridge', [1080, 190, 80, 180], async () => {
    G.flags.pboss = 1; setNPC('pickle', { area: 'fridge', x: 1300, y: 262, dir: 'l' });
    await say([['Огурчик-Рик', 'Я ОГУРЕЦ, МОРТИ! КОРОЛЬ ХОЛОДИЛЬНИКА! Я ВЫШЕ ТЕРАПИИ!'], ['Рик', 'Он даже говорит, как я. Это неприятно.'], ['Саммер', 'Это ВЕСЬ ты, дед.']]);
    await fadeOut(10, '#fff'); await battle('pickle'); await ready();
    await say([['Огурчик-Рик', '...Я пойду на терапию. Но только если Морти пойдёт со мной.'], ['Морти', 'Мне? Ладно. Только не говори Джерри.'], ['Саммер', 'Я тоже иду. Мне нужен материал для шантажа.', 'smug'], ['Рик', 'Семья. *ррыг* Какая мерзость. Домой.']]);
    setNPC('pickle', null); G.flags.pickleDone = 1; G.flags.fridgeLocked = 0;
    await finishEvent();
    sfx('portal'); await fadeOut(20, '#7dff5a'); leaveParty('rick'); leaveParty('summer'); enterArea('kitchen', 366, 200, 'd'); await fadeIn(20);
    G.flags.homeEve = 1; objective('Поужинай с семьёй или иди спать');
  }, () => !G.flags.pboss);
}

/* ---------- ПРИКЛЮЧЕНИЕ: Цитадель (Злой Морти) ---------- */
async function breakfastSummons() {
  G.flags.summons = 1; await sitAtTable();
  await say([['Бет', 'Доброе утро, солнышко! Блинчики! С кленовым сиропом, как ты любишь.', 'happy'], ['Морти', 'Спасибо, мам!'], ['Джерри', 'Я тут рассказывал, как почти устроился на работу. Почти — ключевое слово!', 'happy'], ['Саммер', 'Пап, ты рассказываешь это уже двадцать минут.', 'tired', 'phone']]);
  const r = entAt('rick'); sfx('alarm'); await wait(20); r.emo = 'shock'; r.pose = 'idle';
  await say([N('На запястье Рика пищит часы-коммуникатор. Красным.'), ['Рик', '...*ррыг*', 'shock'], ['Бет', 'Пап? Всё в порядке?'], ['Рик', 'Всё отлично, Бет. Просто... рабочий вопрос.', 'angry']]);
  r.emo = null;
  await say([['Рик', 'Эй, Морти, у меня для тебя дело.'], ['Морти', 'Что случилось?'], ['Рик', 'Пойдём за мной в гараж, там всё обсудим.'], ['Бет', 'Пап, он даже не доел!', 'angry'], ['Рик', 'Доест в космосе, Бет. Там всё вкуснее. Даже блинчики.'], ['Джерри', 'В космосе? А можно мне тоже в кос...'], ['Рик', 'Нет.']]);
  r.sit = 0; await walkPath(r, [[690, 190], [860, 196], [880, 240]], 2.2); setNPC('rick', { area: 'garage', x: 560, y: 300, dir: 'l' });
  PL.sit = 0; await walkTo(PL, 770, 210, 2);
  objective('Иди за Риком в гараж');
  G.npcs.beth.talk = () => [['Бет', 'Иди, милый. Только будь осторожен. И возьми блинчик с собой!', 'sad']];
  G.npcs.jerry.talk = () => [['Джерри', 'Если там будет сувенирная лавка — привези мне кружку!']];
  G.npcs.summer.talk = () => [['Саммер', 'Конечно. Опять Морти. А я — сиди тут и слушай папу.', 'angry']];
}
async function garageSummons() {
  await ready(); G.flags.garageTalk = 1;
  if (!ENTS.some(e => e.key === 'rick' && !e.follow)) setNPC('rick', { area: 'garage', x: 560, y: 300, dir: 'l' });
  const r = entAt('rick'); faceTo(r, PL); await walkTo(PL, r.x - 40, r.y, 2); turn(PL, 'r');
  await say([['Рик', 'Короче, Морти. Цитадель в срочном порядке вызывает меня.'], ['Морти', 'Цитадель? Та, где тысячи Риков? Я думал, её... ну... разнесли.'], ['Рик', 'Её отстроили. И у неё новый хозяин. Сообщение пришло с президентским кодом доступа.'], ['Морти', 'П-президентским? Это же...'], ['Рик', 'Да, Морти. Тот самый Морти. С повязкой.', 'angry'], ['Морти', 'Злой Морти?!', 'shock'], ['Рик', 'Он не злой, Морти. Он просто... очень последовательный. Это хуже.'], ['Рик', 'Если он зовёт меня — значит, ему что-то от меня нужно. А если ему что-то нужно — значит, он уже всё продумал. *ррыг*'], ['Морти', 'Т-тогда зачем лететь?!'], ['Рик', 'Потому что если не полетим — он придёт сам. Садись в корабль.']]);
  G.flags.toShip = 1;
  await walkTo(r, 640, 250, 2.4); r.hidden = 1; setNPC('rick', null);
  await walkPath(PL, [[560, 300], [640, 262]], 2); PL.hidden = 1;
  G.flags.shipCrew = () => { drawChar('rick', -16, -40, { sc: .4, noShadow: 1, dir: 'd' }); drawChar('morty', 16, -40, { sc: .42, noShadow: 1, dir: 'd', emo: 'shock' }); };
  sfx('ship'); G.flags.garageOpen = 1; await wait(30); G.flags.shipFly = 1;
  for (let i = 0; i < 70; i++) { G.flags.shipLift = i * 2.4; CAM.shake = 1.5; await wait(1); }
  await fadeOut(30);
  G.flags.shipGone = 1;
  await spaceFlight(false);
}
function drawCitadel(cx, cy, s, o = {}) {
  x.save(); x.translate(cx, cy); x.scale(s, s);
  if (o.gold) { x.save(); x.globalCompositeOperation = 'lighter'; E(0, 0, 140 + sin(T / 5) * 6, 100, rgrad(0, 0, 10, 140, [[0, 'rgba(255,220,100,.9)'], [1, 'rgba(255,200,60,0)']]), null); x.restore(); }
  const br = o.broken || 0;
  for (let i = -6; i <= 6; i++) { const h = 30 + ((i * 37) % 23 + 23) % 23 * 2, w = 8 + (i % 2 ? 4 : 0), dx = i * 13 + (br ? sin(i * 3 + T / 10) * br * 20 : 0), dy = br ? -br * 30 * abs(sin(i)) : 0; R(dx - w / 2, -h - 6 + dy, w, h, '#8a96a8', OL, .7); R(dx - w / 2, 6 - dy, w, h * .7, '#6a7688', OL, .7); for (let j = 0; j < h / 8; j++) R(dx - w / 2 + 2, -h + j * 8 + dy, w - 4, 2, '#ffe9a0', null); }
  E(0, 0, 100, 16, '#9aa6b8'); E(0, -3, 92, 10, '#b8c4d4', null); R(-6, -70, 12, 64, '#c8d4e4', OL); PG([-6, -70, 6, -70, 0, -96], '#e8f0ff');
  x.restore();
}
async function spaceFlight(back) {
  S = 'scene'; music('space');
  SCENE = { t: 0, back, draw() {
    const k = this.t;
    x.fillStyle = grad(0, 0, 0, H, [[0, '#02030c'], [1, back ? '#2a1a08' : '#0c0a2a']]); x.fillRect(0, 0, W, H);
    for (let i = 0; i < 120; i++) { const sx = ((i * 137.7) - k * (2 + (i % 5))) % (W + 40); const xx = sx < 0 ? sx + W + 40 : sx; LN(xx, (i * 71.3) % H, xx + 6 + (i % 5) * 2, (i * 71.3) % H, 'rgba(255,255,255,' + (.3 + (i % 4) * .15) + ')', 1); }
    if (!back) drawCitadel(560 - Math.min(k, 600) * .25, 170, .4 + Math.min(k, 600) / 600 * 1.4);
    else { drawCitadel(140 + k * .05, 170, 1.4 - Math.min(k, 500) / 500 * .9, { gold: 1, broken: Math.min(1, k / 300) }); }
    ship(back ? 400 + sin(k / 40) * 10 : 220 + sin(k / 40) * 10, 210 + sin(k / 25) * 8, { fly: 1, sc: .8, crew: () => { drawChar('rick', -16, -40, { sc: .4, noShadow: 1, dir: 'd', talk: SPK === 'rick' }); drawChar('morty', 16, -40, { sc: .42, noShadow: 1, dir: 'd', talk: SPK === 'morty' }); } });
  } };
  await fadeIn(30);
  if (!back) {
    await say([['Морти', 'Рик... а что если это ловушка?'], ['Рик', 'Это стопроцентно ловушка, Морти. Но иногда в ловушку надо зайти, чтобы понять, кто её поставил.'], ['Морти', 'Это... это ужасная философия.'], ['Рик', 'Это вся моя жизнь, Морти. *ррыг* Пристегнись. Подлетаем.']]);
    await until(() => SCENE.t > 420); await fadeOut(30);
    S = 'world'; SCENE = null; G.flags.shipDocked = 1; G.flags.shipGone = 0; G.flags.garageOpen = 0; G.flags.shipFly = 0; G.flags.shipLift = 0;
    PL.hidden = 0; enterArea('cit_dock', 330, 300, 'r'); joinParty('rick'); await fadeIn(30);
    await say([['Морти-охранник', 'Рик C-137 и Морти C-137! Добро пожаловать в Цитадель. Президент ждёт вас.'], ['Рик', 'Морти-охранник. С бластером. Цитадель окончательно сошла с ума.'], ['Морти-охранник', 'Мы все — Морти, сэр. Он дал нам выбор. Проходите на площадь.']]);
    objective('Иди на главную площадь');
  } else {
    await say([['Морти', 'Рик... Цитадель... она...'], ['Рик', 'Падает за Кривую. Вместе с ним. Ну, без него. Он ушёл раньше.'], ['Морти', 'А что там, за Кривой?'], ['Рик', '...Не знаю, Морти. Впервые за очень долгое время — не знаю.', 'sad']]);
    await until(() => SCENE.t > 360);
    await say([['Морти', 'Рик... ты рад, что мы целы?'], ['Рик', 'Морти... спасибо, что не дал ему меня... ну... ты понял.'], ['Морти', 'Ты сказал «спасибо»?!', 'shock'], ['Рик', 'Я сказал «*ррыг*». Тебе послышалось. Летим домой.', 'smug']]);
    await fadeOut(30);
    S = 'world'; SCENE = null; G.flags = Object.assign(G.flags, { escape: 0, shipDocked: 0, shipGone: 0, goldPortal: 0, garageOpen: 0, shipFly: 0, shipLift: 0, shipCrew: null });
    DEBRIS.length = 0; leaveParty('rick'); PL.hidden = 0;
    await finishEvent();
    enterArea('garage', 600, 300, 'l'); G.flags.homeEve = 1; await fadeIn(30);
    objective('Поужинай с семьёй или иди спать');
  }
}
async function evilOffice() {
  await ready(); G.flags.evilTalk = 1; G.flags.officeLocked = 1;
  setNPC('evil', { area: 'cit_office', x: 400, y: 200, dir: 'u', pose: 'behind' }); const ev = entAt('evil');
  const rk = follower('rick');
  await walkTo(PL, 380, 270, 2); turn(PL, 'u');
  await say([['Злой Морти', 'Знаешь, Рик, отсюда очень хорошо видно край.']]);
  turn(ev, 'd'); ev.pose = 'hips'; await wait(20);
  await say([['Злой Морти', 'Привет, Рик. Привет, Морти.'], ['Рик', 'Повязка. Ну конечно. Чего ты хочешь?', 'angry'], ['Злой Морти', 'Видите ту светящуюся линию за окном? Это Центральная Конечная Кривая.'], ['Злой Морти', 'Вы, Рики, отгородили кусок бесконечности. Все вселенные, где Рик — самый умный во вселенной. А всё остальное просто... выбросили.'], ['Злой Морти', 'Внутри Кривой каждый Морти — приложение к Рику. Мы рождаемся, чтобы прятать ваши мозговые волны. И всё.'], ['Морти', 'И... что ты собираешься делать?'], ['Злой Морти', 'Уйти. Мне нужен ключ — путь к краю Кривой. И знает его только один Рик.'], ['Злой Морти', 'Твой.']]);
  sfx('zap'); leaveParty('rick'); setNPC('rick', { area: 'cit_office', x: 560, y: 250, dir: 'l', emo: 'angry' }); const rr = entAt('rick'); rr.draw = e => { drawChar('rick', e.x, e.y, { sc: OWS, dir: 'l', emo: 'angry', talk: SPK === 'rick', pose: 'fists' }); x.save(); x.globalAlpha = .35 + sin(T / 6) * .1; RR(e.x - 26, e.y - 96, 52, 100, 6, 'rgba(125,255,90,.35)', '#7dff5a', 2); x.restore(); };
  CAM.shake = 4;
  await say([N('Зелёный луч захватывает Рика. Вокруг него — стазисное поле.'), ['Рик', 'Морти! Не слушай его! Он... *ррыг*... неплохо излагает, но не слушай!', 'angry'], ['Злой Морти', 'Сканер прочитает его память за пару минут. Мне не нужна драка, Морти.'], ['Злой Морти', 'Давай просто поговорим. Как Морти с Морти.']]);
  await fadeOut(10, '#fff'); G.party = ['rick']; await battle('evil'); G.party = []; await ready();
  ev.emo = 'n';
  await say([['Злой Морти', 'Ты хороший Морти. Наверное, поэтому он тебя и выбрал.'], N('*Динь.* Сканер в углу пищит. Загрузка завершена.'), ['Злой Морти', 'Пока мы говорили, я получил, что хотел. Прости. Но я правда не врал: мне не нужно, чтобы вы проиграли. Мне нужно уйти.']]);
  G.flags.goldPortal = 1; sfx('portal'); CAM.shake = 10; music('escape');
  await say([N('За окном вспыхивает огромный золотой портал. Цитадель вздрагивает.'), ['Злой Морти', 'Цитадель питается от Кривой. Когда я открою выход — она развалится. У вас минута.']]);
  rr.draw = null; setNPC('rick', null); joinParty('rick'); sfx('zap');
  await say([['Рик', 'Ты разрушаешь Цитадель, чтобы просто... уйти?!', 'angry'], ['Злой Морти', 'Нет, Рик. Я разрушаю забор. Цитадель просто стояла рядом.'], ['Злой Морти', 'Ваш корабль в доке. Бегите.']]);
  await walkTo(ev, 400, 178, 1.2);
  await say([['Морти', 'Подожди! Как... как тебя зовут на самом деле?'], ['Злой Морти', 'Морти. Просто Морти. Как и тебя.', 'sad']]);
  for (let i = 0; i < 40; i++) { ev.alpha = 1 - i / 40; await wait(2); }
  setNPC('evil', null);
  G.flags.escape = 1; G.flags.officeLocked = 0; G.done.evil = 1;
  await say([['Рик', 'МОРТИ! БЕЖИМ! К кораблю! Через площадь в док!', 'angry']]);
  objective('Беги к кораблю в доке!');
}
const DEBRIS = [];
function debrisTick() {
  CAM.shake = Math.max(CAM.shake, 1);
  if (Math.random() < .035 * f) DEBRIS.push({ x: PL.x + rnd(-100, 180) * (PL.dir === 'l' ? -1 : 1), y: cl(PL.y + rnd(-50, 50), AR.bounds[1] + 10, AR.bounds[3] - 6), t: 0, ar: AR.id });
  for (const d of DEBRIS) { d.t += f; if (d.t >= 55 && !d.hit) { d.hit = 1; if (d.ar === AR.id) { sfx('hit'); CAM.shake = 5; if (hyp(PL.x - d.x, (PL.y - d.y) * 1.6) < 20) { sfx('hurt'); tryMove(PL, PL.x < d.x ? -16 : 16, 0); toast('Ай! Осторожнее!', 50); } } } }
  for (let i = DEBRIS.length - 1; i >= 0; i--) if (DEBRIS[i].t > 120 || DEBRIS[i].ar !== AR.id) DEBRIS.splice(i, 1);
}
function drawFX() {
  for (const d of DEBRIS) {
    if (d.t < 55) { const k = d.t / 55; E(d.x, d.y, 6 + k * 10, 2 + k * 4, 'rgba(255,40,40,' + (.2 + k * .3) + ')', null); RR(d.x - 8, d.y - (55 - d.t) * 5 - 16, 16, 14, 3, '#7a8494'); }
    else { x.globalAlpha = Math.max(0, 1 - (d.t - 55) / 65); E(d.x - 5, d.y - 3, 7, 4, '#7a8494'); E(d.x + 6, d.y - 2, 5, 3, '#646e7e'); E(d.x, d.y - 6, 4, 3, '#8a96a8'); x.globalAlpha = 1; }
  }
}
async function escapeGuard() {
  G.flags.guardDone = 1;
  setNPC('gguard', { area: 'cit_plaza', id: 'crick4', x: PL.x - 90, y: PL.y, dir: 'r', pose: 'cross', emo: 'angry' });
  await say([['Рик-охранник', 'Стоять, Морти! Цитадель на карантине. Никто не уходит!']]);
  await fadeOut(10, '#fff'); await battle('guard'); await ready();
  const g = entAt('gguard'); if (g) await walkTo(g, g.x, AR.bounds[1] + 4, 2.5); setNPC('gguard', null);
  await say([['Рик', 'Дальше, Морти! Док — налево!']]);
}
async function escapeShip() {
  await ready();
  await say([['Рик', 'В корабль! Быстро!']]);
  PL.hidden = 1; leaveParty('rick'); G.flags.shipDocked = 1; sfx('ship'); CAM.shake = 6; await wait(40);
  await fadeOut(30);
  await spaceFlight(true);
}

/* ---------- сохранение ---------- */
const SAVE_KEY = 'rm_hole_save_v2';
function saveGame() { try { localStorage.setItem(SAVE_KEY, JSON.stringify({ day: G.day, done: G.done })); } catch (_) { } }
function loadGame() { try { const s = JSON.parse(localStorage.getItem(SAVE_KEY)); if (s && s.day) return s; } catch (_) { } return null; }
function saveSettings() { try { localStorage.setItem('rm_hole_vol', JSON.stringify(VOL)); } catch (_) { } }
function loadSettings() { try { const v = JSON.parse(localStorage.getItem('rm_hole_vol')); if (v) Object.assign(VOL, v); } catch (_) { } }
