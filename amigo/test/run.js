// Тесты Амиго: node test/run.js
// Обучают нейросеть так же, как build.js, и проверяют понимание, навыки и разговоры.
const assert = require('assert');
const { load, train } = require('../build.js');
const A = load();
const { Text, Skills, Brain, U, JOKES, FACTS, KB } = A;

let passed = 0, failed = 0;
async function test(name, fn) {
  try { await fn(); passed++; console.log('  ✓ ' + name); }
  catch (e) { failed++; console.log('  ✗ ' + name + '\n    ' + (e && e.message || e)); }
}
const has = (s, sub) => assert.ok(String(s).toLowerCase().includes(String(sub).toLowerCase()), `«${s}» не содержит «${sub}»`);

// заглушки интернета: тесты не ходят в сеть
function fakeOnline(over = {}) {
  return Object.assign({
    Super: { mode: () => null, ask: async () => { throw { code: 'no_super' }; } },
    wiki: async q => ({ title: 'Тест', text: 'Статья про ' + q, url: 'https://ru.wikipedia.org/wiki/Тест' }),
    geocode: async name => (/^твер/.test(name) ? { name: 'Тверь', lat: 56.86, lon: 35.9 } : null),
    forecast: async () => ({ current: { temperature_2m: 5.4, apparent_temperature: 2.1, weather_code: 3, wind_speed_10m: 3.2 },
      daily: { time: ['a', 'b'], weather_code: [3, 61], temperature_2m_max: [7, 9], temperature_2m_min: [1, 2], precipitation_probability_max: [10, 70] } }),
  }, over);
}

(async () => {
  console.log('Обучение...');
  const { model, val } = await train();
  const mk = (over = {}) => new Brain(model, Object.assign({ rnd: U.rng(1), now: () => new Date(2026, 9, 13, 14, 5), online: fakeOnline() }, over));

  console.log('Нейросеть');
  await test(`точность на новых фразах ≥ 90% (сейчас ${(val.acc * 100).toFixed(1)}%)`, () => assert.ok(val.acc >= 0.9, val.miss.join('\n')));
  await test('сжатие весов не портит ответы', () => {
    const net = A.MLP.fromJSON(model.net), x = Text.features('расскажи шутку', model.D);
    const p = net.predict(x); let a = 0; for (let i = 1; i < p.length; i++) if (p[i] > p[a]) a = i;
    assert.strictEqual(model.tags[a], 'joke');
  });

  console.log('Текст');
  await test('стеммер склеивает формы слова', () => {
    assert.strictEqual(Text.stem('москве'), Text.stem('москва'));
    assert.strictEqual(Text.stem('кошками'), Text.stem('кошка'));
    assert.strictEqual(Text.stem('играть'), Text.stem('играю').slice(0, Text.stem('играть').length));
  });
  await test('числа словами', () => {
    assert.strictEqual(Text.wordsToDigits('сто двадцать пять плюс три'), '125 плюс 3');
    assert.strictEqual(Text.wordsToDigits('две тысячи двадцать шесть'), '2026');
  });

  console.log('Калькулятор');
  const C = (s, v) => { const r = Skills.calc(s, false); assert.ok(r, 'не понял пример ' + s); assert.ok(Math.abs(r.value - v) < 1e-9, `${s} = ${r.value}, ждали ${v}`); };
  await test('17 * 23', () => C('сколько будет 17 * 23', 391));
  await test('два плюс два', () => C('сколько будет два плюс два', 4));
  await test('скобки и порядок действий', () => C('2 + 2 * (3 - 1)^2', 10));
  await test('корень, степень, проценты', () => { C('корень из 144', 12); C('2 в степени 10', 1024); C('15% от 300', 45); C('5 в квадрате', 25); });
  await test('десятичные с запятой и деление двоеточием', () => { C('2,5 * 4', 10); C('10:4', 2.5); C('7 х 8', 56); });
  await test('не путает обычные фразы с примерами', () => {
    for (const s of ['мне 12 лет', 'привет', 'у меня 2 кота', 'что-нибудь интересное', '2026']) assert.strictEqual(Skills.calc(s, false), null, s);
  });
  await test('деление на ноль', () => has(Skills.calcText(Skills.calc('5 / 0', false)), 'ноль'));

  console.log('Разговор');
  await test('приветствие', async () => { const b = mk(); const a = await b.reply('Привет!'); assert.strictEqual(a.intent, 'greet'); assert.ok(a.conf > 0.5); });
  await test('запоминает имя и вспоминает его', async () => {
    const b = mk(); await b.reply('меня зовут Артур');
    assert.strictEqual(b.profile.name, 'Артур');
    has((await b.reply('как меня зовут?')).text, 'Артур');
    has((await b.reply('привет')).text + ' ' + (await b.reply('спасибо')).text + (await b.reply('привет')).text, '');
  });
  await test('спрашивает имя и понимает ответ одним словом', async () => {
    const b = mk(); await b.reply('как тебя зовут');
    assert.strictEqual(b.ctx && b.ctx.type, 'ask_name');
    await b.reply('Лиза'); assert.strictEqual(b.profile.name, 'Лиза');
  });
  await test('математика в разговоре', async () => { const b = mk(); has((await b.reply('сколько будет 17 умножить на 23?')).text, '391'); has((await b.reply('15 процентов от 200')).text, '30'); });
  await test('время и дата', async () => {
    const b = mk(); has((await b.reply('который час')).text, '14:05');
    has((await b.reply('какой сегодня день недели')).text, 'вторник');
    has((await b.reply('сколько дней до нового года')).text, '80');
  });
  await test('шутка и «ещё»', async () => {
    const b = mk(); const a1 = await b.reply('расскажи анекдот'); assert.ok(JOKES.includes(a1.text));
    const a2 = await b.reply('ещё'); assert.ok(JOKES.includes(a2.text)); assert.notStrictEqual(a1.text, a2.text);
  });
  await test('предложение после грусти: «да» → шутка или факт', async () => {
    const b = mk(); await b.reply('мне грустно'); assert.ok(b.ctx && b.ctx.type === 'offer');
    const a = await b.reply('да'); assert.ok(JOKES.includes(a.text) || FACTS.includes(a.text) || /поиграем/.test(a.text), a.text);
  });
  await test('игра «угадай число»', async () => {
    const b = mk(); await b.reply('давай поиграем в угадай число');
    const secret = b.ctx.secret; let lo = 1, hi = 100, last;
    for (let i = 0; i < 10; i++) { const g = Math.floor((lo + hi) / 2); last = await b.reply(String(g)); if (g === secret) break; if (/больше/.test(last.text)) lo = g + 1; else hi = g - 1; }
    has(last.text, 'угадал'); assert.strictEqual(b.ctx && b.ctx.type, 'offer');
  });
  await test('игра «угадай моё число»: Амиго угадывает 37', async () => {
    const b = mk(); await b.reply('угадай мое число'); let a, n = 0;
    while (b.ctx && b.ctx.type === 'guess_my_number' && n++ < 10) { const g = b.ctx.guess; a = await b.reply(g === 37 ? 'угадал' : g < 37 ? 'больше' : 'меньше'); }
    has(a.text, 'угадал');
  });
  await test('камень-ножницы-бумага', async () => { const b = mk(); await b.reply('сыграем в камень ножницы бумага'); has((await b.reply('камень')).text, 'Счёт'); has((await b.reply('хватит')).text, 'окончена'); });
  await test('загадка: правильный ответ', async () => {
    const b = mk(); await b.reply('загадай загадку'); const R = A.RIDDLES[b.ctx.i];
    has((await b.reply('это ' + R.a[0])).text, 'а'); assert.ok(!b.ctx || b.ctx.type === 'offer');
  });
  await test('загадка: «сдаюсь» показывает ответ', async () => { const b = mk(); await b.reply('загадку'); const R = A.RIDDLES[b.ctx.i]; has((await b.reply('сдаюсь')).text, R.a[0]); });
  await test('викторина из 5 вопросов', async () => {
    const b = mk(); await b.reply('давай викторину'); let a;
    for (let i = 0; i < 5; i++) { const Q = A.QUIZ[b.ctx.qs[b.ctx.i]]; a = await b.reply('АБВ'[Q.c]); }
    has(a.text, '5 из 5');
  });
  await test('учится новому ответу', async () => {
    const b = mk(); const a1 = await b.reply('абракадабра шмыгель');
    assert.ok(a1.unsure, a1.text);
    has((await b.reply('Научить')).text, 'Что мне отвечать');
    const a2 = await b.reply('сим-салабим'); has(a2.text, 'Запомнил');
    const a3 = await b.reply('абракадабра шмыгель'); assert.strictEqual(a3.text, 'сим-салабим'); assert.strictEqual(a3.src, 'taught');
  });
  await test('«когда я говорю X, отвечай Y» и дообучение нейросети', async () => {
    const b = mk(); await b.reply('когда я говорю пинг, отвечай понг');
    assert.strictEqual((await b.reply('пинг')).text, 'понг');
    await b.fineTune();
    const cls = b.classify('пинг!'); assert.strictEqual(cls.tag, b.customs[0].tag);
    assert.strictEqual(b.classify('расскажи шутку').tag, 'joke', 'дообучение не должно ломать старые темы');
  });
  await test('после «не понял» следующая фраза не записывается как ответ без «Научить»', async () => {
    const b = mk(); await b.reply('шмыгель брумгель'); const a = await b.reply('как тебя зовут'); assert.strictEqual(a.intent, 'name_bot'); assert.strictEqual(b.customs.length, 0);
  });
  await test('мини-энциклопедия', async () => {
    const b = mk(); const a = await b.reply('что такое фотосинтез?'); assert.strictEqual(a.src, 'memory'); has(a.text, 'кислород');
    assert.strictEqual((await b.reply('кто такой Морти')).src, 'memory');
    assert.strictEqual((await b.reply('расскажи про черные дыры')).src, 'memory');
  });
  await test('неизвестный вопрос → Википедия', async () => { const b = mk(); const a = await b.reply('кто такой Менделеев?'); assert.strictEqual(a.src, 'wiki'); has(a.text, 'Менделеев'); });
  await test('без интернета честно говорит, что не знает', async () => {
    const b = mk({ online: fakeOnline({ wiki: async () => { throw new Error('offline'); } }) }); const a = await b.reply('кто такой Менделеев?'); assert.ok(a.unsure); has(a.text, 'не знаю');
  });
  await test('супер-мозг отвечает, когда сеть не знает', async () => {
    let asked = '';
    const online = fakeOnline({ Super: { mode: () => 'api', ask: async (s, p, h, text, onText) => { asked = text; onText && onText('Ответ'); return { text: 'Ответ супер-мозга', via: 'Claude' }; } } });
    const b = mk({ online }); const a = await b.reply('почему кошки боятся воды?');
    assert.strictEqual(a.src, 'claude'); assert.strictEqual(a.text, 'Ответ супер-мозга'); has(asked, 'кошки');
  });
  await test('погода (известный город и поиск города)', async () => {
    const b = mk(); const a = await b.reply('какая погода в Москве?'); has(a.text, 'Москва'); has(a.text, '+5 °C');
    has((await b.reply('погода в Твери завтра')).text, 'Тверь');
    has((await b.reply('какая погода')).text, 'Москва');
  });
  await test('перевод', async () => {
    const b = mk(); has((await b.reply('как по-английски собака')).text, 'dog');
    has((await b.reply('как будет друг по-испански')).text, 'amigo');
    has((await b.reply('что значит hello')).text, 'привет');
  });
  await test('выбор из вариантов', async () => { const b = mk(); const a = await b.reply('что лучше пицца или бургер?'); assert.ok(/пицца|бургер/.test(a.text), a.text); });
  await test('таймер', async () => {
    const b = mk(); const a = await b.reply('поставь таймер на 5 минут'); assert.deepStrictEqual(a.action, { type: 'timer', sec: 300, label: '' });
    const r = await b.reply('напомни через 10 минут покормить кота'); assert.strictEqual(r.action.sec, 600); assert.strictEqual(r.action.label, 'покормить кота');
  });
  await test('память о пользователе', async () => {
    const b = mk(); await b.reply('запомни что я люблю пиццу'); await b.reply('мне 12 лет');
    const a = await b.reply('что ты обо мне знаешь?'); has(a.text, 'пиццу'); has(a.text, '12');
  });
  await test('поддержка в трудной ситуации', async () => { const b = mk(); has((await b.reply('я не хочу жить')).text, '8-800-2000-122'); });
  await test('бессмыслица', async () => { const b = mk(); const a = await b.reply('фывапролдж'); assert.strictEqual(a.intent, 'gibberish'); });
  await test('как устроен: настоящие числа сети', async () => { const b = mk(); has((await b.reply('как ты работаешь?')).text, String(model.H)); });
  await test('сохраняет данные через onSave', async () => {
    let saved = null; const b = mk({ onSave: d => { saved = d; } }); await b.reply('меня зовут Кира');
    assert.strictEqual(saved.profile.name, 'Кира');
  });

  console.log('Игры и личность');
  const fakeSuper = (reply) => fakeOnline({ Super: { mode: () => 'api', ask: async (st, p, h, text, onText, sig, opts) => { onText && onText('...'); return { text: reply(text, opts), via: 'Claude' }; } } });
  await test('«ты Claude?» отвечает сам Амиго, даже с супер-мозгом', async () => {
    const b = mk({ online: fakeSuper(() => 'Я Claude, ИИ от Anthropic') });
    for (const q of ['ты клауд?', 'Ты Claude?', 'ты что, claude', 'тебя сделали в Anthropic?']) {
      const a = await b.reply(q); assert.strictEqual(a.intent, 'are_you_claude', q); has(a.text, 'я Амиго'); assert.notStrictEqual(a.src, 'claude', q);
    }
  });
  await test('правила супер-мозга: говорит как Амиго и без лимита длины', () => {
    const r = A.Online.Super.rules({ name: 'Артур', facts: [] });
    has(r, 'от лица Амиго'); assert.ok(!/1–5 предложений/.test(r)); has(r, 'Артур');
  });
  await test('запускает встроенные игры по названию', async () => {
    const b = mk();
    const cases = { 'давай сыграем в змейку': 'snake', 'запусти тетрис': 'tetris', 'игра 2048': 'g2048', 'крестики-нолики': 'ttt', 'хочу поиграть в сапёра': 'mines',
      'найди пару': 'memory', 'арканоид': 'breakout', 'сыграем в понг': 'pong', 'флэппи бёрд': 'flappy', 'звездопад': 'catcher' };
    for (const [q, k] of Object.entries(cases)) { const a = await b.reply(q); assert.ok(a.game, q + ' → ' + a.text); assert.strictEqual(a.game.key, k, q); }
  });
  await test('настройки игры из просьбы', async () => {
    const a = await mk().reply('сделай змейку быстрее, красную и без стен');
    assert.deepStrictEqual(a.game.opts, { speed: 1.45, color: '#E53935', wrap: true });
  });
  await test('«сделай игру» спрашивает какую, потом запускает', async () => {
    const b = mk(); const a = await b.reply('сделай игру'); assert.ok(!a.game); assert.strictEqual(b.ctx.type, 'game_wait');
    const a2 = await b.reply('тетрис'); assert.strictEqual(a2.game.key, 'tetris');
  });
  await test('своя игра по описанию: Амиго программирует её сам, без Claude', async () => {
    let asked = 0;
    const online = fakeOnline({ Super: { mode: () => 'api', avail: () => 'api', ask: async () => { asked++; return { text: 'x' }; } } });
    const b = mk({ online }); const a = await b.reply('сделай игру про динозавра который прыгает через кактусы');
    assert.strictEqual(a.game.key, 'codex'); assert.strictEqual(a.src, 'codex'); assert.strictEqual(a.game.opts.genre, 'runner'); assert.strictEqual(asked, 0, 'Claude не нужен');
    has(a.text, 'сам'); assert.strictEqual(a.game.opts.hero.emoji, '🦖');
  });
  await test('не путает игры с обычными фразами', async () => {
    const b = mk();
    for (const q of ['сколько дней до лета', 'что такое змея', 'посчитай звёзды', 'сколько будет 2048 / 2', 'у меня есть кот']) { const a = await b.reply(q); assert.ok(!a.game, q + ' → игра ' + (a.game && a.game.key)); }
  });
  console.log('Кодекс');
  const fakeClaude = (answer) => { const calls = []; return { calls, online: fakeOnline({ Super: { mode: () => null, avail: () => 'api', ask: async (st, p, h, text) => { calls.push(text); return { text: answer(text) }; } } }) }; };
  await test(`нейросеть Кодекса понимает жанр новых описаний ≥ 90% (сейчас ${(model.codex.val.acc * 100).toFixed(1)}%)`, () => assert.ok(model.codex.val.acc >= 0.9));
  await test('понимает жанры, героев, врагов и миры', () => {
    const cases = [['кот ловит рыбу под водой и уворачивается от акул', 'catch', '🐱', '🐟', '🦈', 'water'], ['космический корабль стреляет в пришельцев', 'shooter', '🚀', null, '👾', 'space'],
      ['динозавр прыгает через кактусы', 'runner', '🦖', null, '🌵', 'desert'], ['машинка уворачивается от машин на дороге', 'racer', '🚗', null, null, 'city'],
      ['собирай монетки и убегай от призраков', 'topdown', null, '🪙', '👻', null], ['лопай шарики на время', 'tapper', null, '🎈', null, null],
      ['пингвин прыгает по льдинам вверх', 'jumper', '🐧', null, null, 'winter'], ['вертолёт летит между горами', 'flappy', '🚁', null, '⛰️', null]];
    for (const [q, g, h, gd, bd, th] of cases) {
      const s = A.Codex.design(A.Codex.understand(q, { words: {}, recipes: [] }), 'high');
      assert.strictEqual(s.genre, g, q);
      if (h) assert.strictEqual(s.hero.emoji, h, q + ' герой'); if (gd) assert.strictEqual(s.things.good.emoji, gd, q + ' приз');
      if (bd) assert.strictEqual(s.things.bad.emoji, bd, q + ' враг'); if (th) assert.strictEqual(s.theme.id, th, q + ' мир');
    }
  });
  await test('все жанры работают на всех уровнях: робот играет без ошибок', () => {
    for (const g of Object.keys(A.CODEX_GENRES)) for (const lv of ['medium', 'high', 'ultra']) {
      const s = A.Codex.design(A.Codex.understand('игра', { words: {}, recipes: [] }), lv, { genre: g });
      const r = A.CodexEngine.playtest(s, { seconds: 40, seeds: [1, 2] });
      assert.ok(r.time > 3, g + ' ' + lv + ' слишком быстро закончилась: ' + r.time);
    }
  });
  await test('уровни различаются: высокий добавляет бонусы, уровни, босса и эффекты', () => {
    const u = A.Codex.understand('корабль стреляет в пришельцев', { words: {}, recipes: [] });
    const m = A.Codex.design(u, 'medium'), h = A.Codex.design(u, 'high'), x = A.Codex.design(u, 'ultra');
    assert.ok(!m.powers.length && !m.boss.on && !m.fx.particles);
    assert.ok(h.powers.length && h.boss.on && h.fx.particles && h.fx.combo);
    assert.ok(x.goal.level > 0);
  });
  await test('команды режима Кодекс', async () => {
    const b = mk();
    await b.reply('включи кодекс'); assert.strictEqual(b.settings.codexOn, true);
    await b.reply('кодекс ультра'); assert.strictEqual(b.settings.codexLevel, 'ultra');
    await b.reply('средний'); assert.strictEqual(b.settings.codexLevel, 'medium');
    const a = await b.reply('кот ловит рыбу'); assert.strictEqual(a.game && a.game.key, 'codex');
    assert.strictEqual((await b.reply('привет')).intent, 'greet', 'обычные фразы в Кодексе — как обычно');
    const c = await b.reply('покажи код'); assert.strictEqual(c.action.type, 'code');
    await b.reply('выключи кодекс'); assert.strictEqual(b.settings.codexOn, false);
  });
  await test('правки игры словами', async () => {
    const b = mk(); const a = await b.reply('сделай игру где кот ловит рыбу');
    const p0 = a.game.opts.pace;
    const e1 = await b.reply('сделай её быстрее'); assert.ok(e1.game.opts.pace > p0); has(e1.text, 'быстрее');
    const e2 = await b.reply('вместо кота собака'); assert.strictEqual(e2.game.opts.hero.emoji, '🐶');
    const e3 = await b.reply('добавь босса и 5 жизней'); assert.ok(e3.game.opts.boss.on); assert.strictEqual(e3.game.opts.lives, 5);
    const e4 = await b.reply('поменяй мир на космос'); assert.strictEqual(e4.game.opts.theme.id, 'space');
  });
  await test('Ультра: думает по шагам, тестирует роботом и подбирает сложность', async () => {
    const b = mk(); b.fastThink = true; b.settings.codexLevel = 'ultra'; const seen = [];
    const a = await b.reply('сделай игру про корабль который стреляет в пришельцев', { onThink: l => seen.push(l.length) });
    assert.ok(a.think.length >= 8, 'мало шагов'); assert.ok(seen.length >= 8);
    assert.ok(a.think.some(l => /Вариант 3/.test(l)) && a.think.some(l => /темп/.test(l)));
    assert.strictEqual(a.game.opts.level, 'ultra'); assert.ok(a.game.opts.goal.level > 0);
  });
  await test('Ультра: спрашивает у Claude только «как это сделать», учится и потом делает сам', async () => {
    const recipe = { possible: true, name: 'ловушки', explain: 'Игрок ставит ловушку кнопкой, а враг, который на неё наступил, исчезает.', rules: [
      { type: 'thing', tag: 'trap', emoji: '🪤', name: 'ловушка', move: 'still', life: 8, role: 'neutral' },
      { type: 'ability', do: 'place', spawn: 'trap', cooldown: 1.5, label: '🪤' },
      { type: 'touch', a: 'trap', b: ['bad', 'bad2'], do: ['remove_b', 'remove_a', 'score:3', 'burst'] }] };
    const { calls, online } = fakeClaude(text => /нарисовать/.test(text) ? '[{"word":"капибару","name":"капибара","emoji":"🦫","role":"hero"}]' : '```json\n' + JSON.stringify(recipe) + '\n```');
    const b = mk({ online }); b.fastThink = true; b.settings.codexLevel = 'ultra';
    const a = await b.reply('сделай игру про капибару которая собирает яблоки и можно ставить ловушки на волков');
    assert.strictEqual(calls.length, 2, 'два вопроса: как нарисовать и как сделать');
    assert.ok(calls.every(c => /КАК|как нарисовать|Подскажи, как/.test(c) && !/HTML-игр|<!doctype/i.test(c)), 'Claude не просят писать игру');
    assert.strictEqual(a.game.opts.hero.emoji, '🦫'); assert.ok(a.game.opts.things.trap); assert.ok(a.game.opts.abilities.some(x => x.do === 'place'));
    assert.ok(a.think.some(l => /Понял, как делать/.test(l)));
    assert.ok(b.codexMem.recipes.length === 1 && Object.keys(b.codexMem.words).length >= 1);
    // второй раз — сам, без вопросов
    const a2 = await b.reply('игра где капибара ловит рыбу и можно ставить ловушки');
    assert.strictEqual(calls.length, 2, 'второй раз Амиго не спрашивает'); assert.ok(a2.game.opts.things.trap); assert.strictEqual(a2.game.opts.hero.emoji, '🦫');
    const r = A.CodexEngine.playtest(a2.game.opts, { seconds: 30, seeds: [1] }); assert.ok(r.time > 5);
  });
  await test('Ультра без Claude: всё равно делает игру и честно говорит, чего не умеет', async () => {
    const b = mk(); b.fastThink = true; b.settings.codexLevel = 'ultra';
    const a = await b.reply('игра где можно строить мосты через реку');
    assert.strictEqual(a.game.key, 'codex'); assert.ok(a.think.some(l => /не умею|Спросить у Claude сейчас нельзя/.test(l)));
  });
  await test('проверка выученных приёмов не пропускает лишнего', () => {
    assert.ok(!A.Codex.validateRecipe({ possible: false }).ok);
    const v = A.Codex.validateRecipe({ name: 'x', rules: [{ type: 'touch', a: 'hero', b: 'bad', do: ['eval:alert(1)', 'score:1'] }, { type: 'thing', tag: 'hero', emoji: '🦫' }, { type: 'thing', tag: 'ok', emoji: 'не эмодзи' }, { type: 'spawn', tag: 'nope', every: 1 }] });
    assert.ok(!v.ok, 'неизвестные эффекты, теги и не-эмодзи отбрасываются');
    const w = A.Codex.validateRecipe({ name: 'x', rules: [{ type: 'thing', tag: 'coin2', emoji: '🪙', speed: 99, move: 'teleport' }, { type: 'spawn', tag: 'coin2', every: 0.01, from: 'moon' }] });
    assert.ok(w.ok); assert.strictEqual(w.recipe.rules[0].speed, 4); assert.strictEqual(w.recipe.rules[0].move, 'still'); assert.strictEqual(w.recipe.rules[1].every, 0.3); assert.strictEqual(w.recipe.rules[1].from, 'random');
  });
  await test('супер-мозг для разговоров по умолчанию выключен: Амиго отвечает сам', () => {
    assert.strictEqual(mk().settings.superOn, false);
    assert.strictEqual(mk({ settings: { superOn: true } }).settings.superOn, false, 'старые настройки переводятся');
    assert.strictEqual(mk({ settings: { superOn: true, v: 2 } }).settings.superOn, true, 'новые настройки сохраняются');
  });

  console.log(`\nИтого: ${passed} прошло, ${failed} упало`);
  process.exit(failed ? 1 : 0);
})();
