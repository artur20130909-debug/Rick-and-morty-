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

  console.log(`\nИтого: ${passed} прошло, ${failed} упало`);
  process.exit(failed ? 1 : 0);
})();
