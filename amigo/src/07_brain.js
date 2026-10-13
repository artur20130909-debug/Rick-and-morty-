// Мозг Амиго: нейросеть определяет тему, а дальше навыки, игры, память и обучение строят ответ.
const BRAIN_TH = 0.3;            // ниже этой уверенности Амиго считает, что не понял
const BRAIN_MARGIN = 0.08;       // и если две темы почти равны — тоже
const CRISIS_RE = /(хочу|хочется|буду)\s+(умереть|сдохнуть|покончить)|не\s+хочу\s+(больше\s+)?жить|жить\s+не\s+хочу|покончить\s+с\s+собой|убить\s+себя|меня\s+(бьют|избивают|травят|буллят)|самоубий/;
const TEACH_RE = /^(?:запомни[:,]?\s*)?(?:когда|если)\s+я\s+(?:говорю|пишу|скажу|напишу)\s+[«"']?(.+?)[»"']?[,\s]+(?:то\s+)?(?:ты\s+)?(?:отвечай|ответь|говори|скажи|пиши)\s+[«"']?(.+?)[»"']?\s*$/i;
const TEACH_RE2 = /^на\s+[«"'](.+?)[»"']\s+(?:отвечай|ответь|говори)\s+[«"']?(.+?)[»"']?\s*$/i;
const NAME_RE = /(?:^|[\s,.!])(?:меня\s+зовут|мо[её]\s+имя(?:\s*[-—:]|\s+это)?|зови\s+меня|называй\s+меня|можешь\s+звать\s+меня)\s+([A-Za-zА-Яа-яЁё][A-Za-zА-Яа-яЁё-]{1,24})(?:\s+([A-Za-zА-Яа-яЁё][A-Za-zА-Яа-яЁё-]{1,24}))?/i;
const NOT_NAMES = new Set(['не', 'никак', 'секрет', 'тайна', 'зовут', 'так', 'просто', 'ты', 'я', 'да', 'нет', 'это', 'кто', 'как', 'а', 'и', 'вообще', 'никто', 'там', 'все']);
const WHO_AI_RE = /(клауд|клод|claude|антропик|anthropic)/;
const OTHER_AI_RE = /(чат\s?гпт|chat\s?gpt|gpt|гпт|алис[аеу]|siri|сири|gemini|джемини|гигачат|яндекс\s?gpt)/;
const YOU_RE = /(^|\s)(ты|тебя|тебе|тобой|вы|амиго)(?![а-яa-z])/;
const AGE_RE = /(?:^|\s)мне\s+(\d{1,2})\s*(?:лет|год|года)(?![а-яa-z0-9])/;

class Brain {
  constructor(model, opts = {}) {
    this.model = model;
    this.D = model.D;
    this.rnd = opts.rnd || Math.random;
    this.now = opts.now || (() => new Date());
    this.online = opts.online || Online;
    this.profile = Object.assign({ name: '', facts: [], city: null, age: 0 }, opts.profile || {});
    this.settings = Object.assign({ voice: false, superOn: true, superTier: 'quick', apiKey: '', model: 'claude-opus-5-5', online: true }, opts.settings || {});
    this.customs = (opts.customs || []).map(c => Object.assign({}, c, { custom: true }));
    this.ctx = null;        // текущий режим: игра, вопрос, обучение
    this.lastAct = null;    // для «ещё»
    this.history = [];      // реплики для супер-мозга
    this.decks = {};        // перемешанные колоды шуток, фактов и т.п.
    this.lastCls = null;
    this.onSave = opts.onSave || null;
    this.reset();
  }

  // собрать сеть из встроенной модели и добавить выученное пользователем
  reset() {
    this.net = MLP.fromJSON(this.model.net);
    this.base = Data.build(INTENTS);
    if (this.base.tags.join() !== this.model.tags.join()) console.warn('Амиго: модель не совпадает с данными, пересоберите index.html');
    this.intents = this.base.intents.slice();
    this.tuned = 0;
    this.syncCustoms();
  }
  syncCustoms() {
    for (const c of this.customs) if (!this.intents.some(i => i.tag === c.tag)) { this.intents.push(c); this.net.addClass(); }
    this.tags = this.intents.map(i => i.tag);
    this.byTag = new Map(this.intents.map(i => [i.tag, i]));
  }
  get needsTuning() { return this.customs.length > 0 && this.tuned !== this.customVersion(); }
  customVersion() { return this.customs.reduce((s, c) => s + c.p.length * 31 + c.tag.length, this.customs.length); }

  // ---------- нейросеть ----------
  classify(text) {
    const x = Text.features(text, this.D, true);
    const f = this.net.forward(x);
    const p = Float32Array.from(f.p), hid = Float32Array.from(f.hid);
    const order = Array.from(p.keys()).sort((a, b) => p[b] - p[a]);
    const top = order.slice(0, 5).map(i => ({ tag: this.tags[i], title: (this.byTag.get(this.tags[i]) || {}).t || this.tags[i], p: p[i] }));
    // какая доля признаков фразы знакома сети (строка весов не нулевая)
    let known = 0, H = this.net.H;
    for (let k = 0; k < x.idx.length; k++) {
      const row = x.idx[k] * H; let nz = false;
      for (let h = 0; h < H; h++) if (this.net.W1[row + h] !== 0) { nz = true; break; }
      if (nz) known += x.val[k] * x.val[k];
    }
    const cls = { tag: top[0].tag, conf: top[0].p, margin: top[0].p - (top[1] ? top[1].p : 0), top, x, hid, p, known, text };
    this.lastCls = cls;
    return cls;
  }
  // дообучение на фразах пользователя: новые выходы + повтор старых примеров, чтобы не забыть прежнее
  async fineTune(opt = {}) {
    if (!this.customs.length) { this.tuned = this.customVersion(); return []; }
    const rnd = U.rng(99);
    const ds = Data.build(INTENTS, this.customs.map(c => Object.assign({}, c, { custom: true })));
    const baseN = this.base.tags.length;
    const own = ds.examples.filter(e => e.y >= baseN);
    const replay = U.shuffle(ds.examples.filter(e => e.y < baseN), rnd).slice(0, Math.max(600, own.length * 4));
    const ex = Data.featurize(own.concat(replay), this.D);
    this.net.resetOptimizer();
    const hist = await this.net.train(ex, { epochs: opt.epochs || 8, batch: 16, lr: 0.005, lrMin: 0.001, smooth: 0.1, dropout: 0.2, seed: 5, tick: opt.tick, onEpoch: opt.onEpoch });
    this.tuned = this.customVersion();
    return hist;
  }
  // полное переобучение с нуля (кнопка в панели «Мозг»)
  async retrain(opt = {}) {
    const ds = Data.build(INTENTS, this.customs.map(c => Object.assign({}, c, { custom: true })));
    const ex = Data.featurize(ds.examples, this.D);
    const net = new MLP(this.D, this.model.H, ds.tags.length, 1);
    const hist = await net.train(ex, Object.assign({ epochs: this.model.epochs || 20, batch: 16, lr: 0.01, smooth: 0.1, dropout: 0.2, seed: 7 }, opt));
    this.net = net; this.intents = ds.intents; this.tags = ds.tags; this.byTag = new Map(this.intents.map(i => [i.tag, i]));
    this.tuned = this.customVersion();
    return hist;
  }

  // ---------- память ----------
  save() { if (this.onSave) this.onSave({ profile: this.profile, settings: this.settings, customs: this.customs.map(({ tag, t, p, r }) => ({ tag, t, p, r })) }); }
  learn(phrase, answer) {
    const p = Text.clean(phrase), a = String(answer).trim();
    if (!p || !a) return null;
    let c = this.customs.find(c => c.r[0].toLowerCase() === a.toLowerCase());
    if (!c) {
      const id = 1 + this.customs.reduce((m, c) => Math.max(m, parseInt(c.tag.slice(7), 10) || 0), 0);
      c = { tag: 'custom_' + id, t: '«' + (phrase.length > 28 ? phrase.slice(0, 27) + '…' : phrase) + '»', p: [], r: [a], custom: true };
      this.customs.push(c);
    }
    if (!c.p.includes(p)) c.p.push(p);
    this.syncCustoms();
    this.save();
    return c;
  }
  forgetCustom(tag) {
    this.customs = this.customs.filter(c => c.tag !== tag);
    this.reset();
    this.save();
  }
  // быстрый поиск по выученным фразам, пока сеть ещё не дообучилась
  taughtMatch(text) {
    if (!this.customs.length) return null;
    const x = Text.features(text, this.D);
    let best = null, bs = 0;
    for (const c of this.customs) for (const p of c.p) {
      const s = Text.cosine(x, Text.features(p, this.D));
      if (s > bs) { bs = s; best = c; }
    }
    return bs >= 0.86 ? best : null;
  }

  // ---------- оформление ответа ----------
  fill(s) {
    const n = this.profile.name;
    return String(s).replace(/\{,name\}/g, n ? ', ' + n : '').replace(/\{name\}/g, n || 'друг')
      .replace(/\{hidden\}/g, String(this.net.H)).replace(/\{params\}/g, U.num(this.net.params)).replace(/\{intents\}/g, String(this.tags.length));
  }
  deal(kind, list) {
    let d = this.decks[kind];
    if (!d || !d.length) d = this.decks[kind] = U.shuffle(list.map((_, i) => i), this.rnd);
    return d.pop();
  }
  say(text, extra = {}) { return Object.assign({ text }, extra); }

  // ---------- главный вход ----------
  async reply(raw, io = {}) {
    const text = String(raw).trim().slice(0, 2000);
    const t = Text.clean(text);
    this.history.push({ role: 'user', content: text });
    let a;
    try { a = await this.route(text, t, io); }
    catch (e) { console.error(e); a = this.say('Ой, у меня в нейронах что-то перепуталось 😵 Попробуй сказать по-другому.', { src: 'rule', mood: 'sad' }); }
    if (a.offer && !this.ctx) this.ctx = { type: 'offer', act: a.offer };
    a.text = this.fill(a.text);
    if (a.chips) a.chips = a.chips.map(c => this.fill(c));
    this.history.push({ role: 'assistant', content: a.text });
    if (this.history.length > 40) this.history.splice(0, this.history.length - 40);
    return a;
  }

  async route(text, t, io) {
    if (!t) {
      if (/[\d+\-*/^()]/.test(text)) { const r = Skills.calc(text, true); if (r) return this.say(Skills.calcText(r), { src: 'skill', intent: 'calc' }); }
      return this.say(U.pick(['😊', '🙂 Напиши мне что-нибудь словами!', '👍'], this.rnd), { src: 'rule' });
    }
    if (CRISIS_RE.test(t)) { this.ctx = null; return this.say(CRISIS_TEXT, { src: 'rule', intent: 'crisis', mood: 'care' }); }

    // «когда я говорю X, отвечай Y»
    const tm = TEACH_RE.exec(text) || TEACH_RE2.exec(text);
    if (tm) {
      this.ctx = null;
      this.learn(tm[1], tm[2]);
      return this.say(`Запомнил! Когда ты скажешь «${tm[1]}», я отвечу «${tm[2]}» ✅`, { src: 'rule', intent: 'teach', mood: 'learn', action: { type: 'learned' } });
    }

    const cls = this.classify(text);

    if (this.ctx) {
      const r = await this.inCtx(text, t, cls, io);
      if (r) return r;
    }

    // «ты Claude?» — отвечает сам Амиго, честно и от своего имени
    if (WHO_AI_RE.test(t) && (YOU_RE.test(t) || t.split(' ').length <= 2)) return this.handle('are_you_claude', text, t, cls, io);
    if (OTHER_AI_RE.test(t) && YOU_RE.test(t)) return this.handle('compare_ai', text, t, cls, io);

    // пример по математике
    const m = Skills.calc(text, false);
    if (m) { this.lastAct = null; return this.say(Skills.calcText(m), { src: 'skill', intent: 'calc', conf: cls.tag === 'calc' ? cls.conf : undefined }); }

    // игры в чате
    if (GameList.find(text) || (cls.tag === 'make_game' && cls.conf >= BRAIN_TH)) return this.makeGame(text, t, cls, io);

    // «меня зовут ...»
    const nm = NAME_RE.exec(text);
    if (nm) { const r = this.setName(nm[1], nm[2]); if (r) return r; }
    const ag = AGE_RE.exec(t);
    if (ag) { this.profile.age = +ag[1]; this.save(); return this.say(`Запомнил: тебе ${ag[1]} ${U.plural(+ag[1], 'год', 'года', 'лет')} 🎂 Классный возраст!`, { src: 'rule', intent: 'remember' }); }

    // то, чему научил пользователь
    const taught = this.taughtMatch(text);
    if (taught) return this.say(taught.r[0], { src: 'taught', intent: taught.tag, conf: cls.tag === taught.tag ? cls.conf : undefined, top: cls.top });

    if (Skills.isGibberish(text)) return this.handle('gibberish', text, t, cls, io);

    const strong = cls.conf >= BRAIN_TH && cls.margin >= BRAIN_MARGIN && cls.known >= 0.35;
    if (strong) return this.handle(cls.tag, text, t, cls, io);

    // сеть не уверена: вопрос о мире → энциклопедия / супер-мозг / Википедия
    const question = /\?\s*$/.test(text) || /^(что|кто|где|когда|почему|зачем|как|какой|какая|какое|какие|сколько|чем|откуда|куда|расскажи|объясни|напиши|придумай|сочини|можно ли|правда ли|чей|чья)(?![а-яa-z0-9])/.test(t);
    // вопрос про самого Амиго — не ищем в Википедии, а берём лучшую догадку сети
    const aboutBot = /(^|\s)(ты|тебя|тебе|тобой|твой|твоя|твое|твои|амиго)(?![а-яa-z0-9])/.test(t) && cls.tag !== 'knowledge';
    const it = this.byTag.get(cls.tag) || {};
    const safe = (it.r && !it.act) || ['name_bot', 'how_works', 'help', 'age_bot'].includes(it.act);
    if (aboutBot && safe && cls.conf >= 0.18 && cls.margin >= 0.05 && !this.superMode()) return this.handle(cls.tag, text, t, cls, io);
    if (!aboutBot && (question || (cls.tag === 'knowledge' && cls.conf >= 0.3))) return this.knowledge(text, io, cls);
    if (this.superMode()) { const a = await this.askSuper(text, io, cls); if (a) return a; }
    return this.notUnderstood(text, cls);
  }

  notUnderstood(text, cls) {
    this.ctx = { type: 'teach_offer', phrase: text };
    const hint = cls.conf > 0.2 ? ` Похоже на тему «${cls.top[0].title}», но я не уверен.` : '';
    return this.say(U.pick([
      `Я пока не знаю, что на это ответить 🤔${hint} Нажми «Научить», и я запомню правильный ответ.`,
      `Хм, такого я ещё не встречал.${hint} Можешь научить меня — нажми «Научить».`,
    ], this.rnd), { src: 'net', intent: cls.tag, conf: cls.conf, top: cls.top, mood: 'think', chips: ['Научить', 'Что ты умеешь?'], unsure: true });
  }

  superMode() { return this.online.Super.mode(this.settings); }
  async askSuper(text, io, cls, prompt) {
    if (io.onThinking) io.onThinking('super');
    try {
      const hist = this.history.slice(0, -1);
      const r = await this.online.Super.ask(this.settings, this.profile, hist, prompt || text, io.onStream, io.signal);
      return this.say(r.text.trim() + (r.truncated ? '…' : ''), { src: 'claude', intent: cls && cls.tag, conf: cls && cls.conf, top: cls && cls.top });
    } catch (e) {
      if (e && e.code === 'cancelled') return this.say(e.text || 'Хорошо, остановился.', { src: 'claude', partial: true });
      if (e && e.text) return this.say(e.text + '…', { src: 'claude', partial: true });
      return null;
    }
  }

  // ---------- режимы (игры, вопросы, обучение) ----------
  async inCtx(text, t, cls, io) {
    const c = this.ctx;
    const sure = cls.conf >= 0.6, tag = cls.conf >= 0.5 ? cls.tag : (cls.tag === 'yes' || cls.tag === 'no' ? '' : cls.tag);
    const quit = (tag === 'stop' && sure) || /^(стоп|хватит|выход|закончим|надоело|отмена)(?![а-яa-z0-9])/.test(t);
    const giveUp = /сда(юсь|юся)|не\s+знаю|без\s+понятия|скажи\s+ответ|какой\s+ответ|хз(?![а-яa-z0-9])|подскажи/.test(t);
    // ясно другая тема — выходим из режима и отвечаем как обычно
    const switchTopic = sure && !['yes', 'no', 'more', 'laugh', 'statement', 'dont_know', 'user_good', 'stop', 'thanks', 'gibberish', 'calc', 'random'].includes(tag);

    switch (c.type) {
      case 'offer': {
        this.ctx = null;
        if (tag === 'yes' || (tag === 'more' && sure) || /^(да|давай|ага|конечно|хочу|ок|го)(?![а-яa-z0-9])/.test(t)) return this.handle(c.act, text, t, cls, io);
        if (tag === 'no' || /^(нет|не|неа)(?![а-яa-z0-9])/.test(t)) return this.say(U.pick(['Хорошо! Я рядом, если что 🙂', 'Ладно! Тогда о чём поболтаем?', 'Как скажешь!'], this.rnd), { src: 'net', intent: 'no', conf: cls.conf, top: cls.top });
        return null;
      }
      case 'ask_name': {
        this.ctx = null;
        if (tag === 'no' || /не\s+скажу|секрет|не\s+хочу/.test(t)) return this.say('Хорошо, секрет так секрет 🙂', { src: 'rule' });
        const nm = NAME_RE.exec(text);
        if (nm) return this.setName(nm[1], nm[2]);
        const ws = text.replace(/[.!,?]+/g, ' ').trim().split(/\s+/);
        const w = ws[0] === 'я' || ws[0] === 'Я' ? ws.slice(1) : ws;
        if (w.length >= 1 && w.length <= 2 && /^[A-Za-zА-Яа-яЁё-]{2,25}$/.test(w[0]) && !NOT_NAMES.has(w[0].toLowerCase()) && !(sure && !['statement', 'set_name', 'gibberish'].includes(tag))) return this.setName(w[0], w[1]);
        return null;
      }
      case 'teach_phrase': {
        this.ctx = null;
        if (quit || tag === 'no') return this.say('Хорошо, научишь в другой раз 🙂', { src: 'rule' });
        this.ctx = { type: 'teach', phrase: text };
        return this.say(`А что мне отвечать на «${text}»?`, { src: 'rule', intent: 'teach', mood: 'learn' });
      }
      case 'teach_offer': {
        this.ctx = null;
        if (/^(научить|научу|научи|давай научу|хочу научить)(?![а-яa-z0-9])/.test(t) || (tag === 'teach' && sure) || (tag === 'yes' && sure)) {
          this.ctx = { type: 'teach', phrase: c.phrase };
          return this.say(`Что мне отвечать на «${c.phrase}»? Напиши ответ 📝`, { src: 'rule', intent: 'teach', mood: 'learn', chips: ['Отмена'] });
        }
        return null;
      }
      case 'teach': {
        this.ctx = null;
        if (/^(пропустить|отмена|не\s+надо|нет|неа|потом|не\s+буду|забей)(?![а-яa-z0-9])/.test(t)) return this.say('Хорошо, пропустим 🙂', { src: 'rule' });
        this.learn(c.phrase, text);
        return this.say(U.pick([`Запомнил! Теперь на «${c.phrase}» я отвечу: «${text}» ✅`, `Ура, я стал умнее! На «${c.phrase}» теперь отвечаю «${text}» 🧠`], this.rnd),
          { src: 'rule', intent: 'teach', mood: 'learn', action: { type: 'learned' } });
      }
      case 'guess_number': {
        const n = this.numberIn(text);
        if (n !== null) {
          c.tries++;
          if (n === c.secret) {
            this.ctx = null; this.lastAct = 'guess_number';
            return this.say(`🎉 Угадал! Это было число **${c.secret}**. Попыток: ${c.tries}.${c.tries <= 7 ? ' Отличный результат!' : ''}`, { src: 'skill', intent: 'guess_number', mood: 'happy', chips: ['Ещё раз', 'Хватит'], offer: 'guess_number' });
          }
          const dir = n < c.secret ? 'больше ⬆️' : 'меньше ⬇️', d = Math.abs(n - c.secret);
          const hint = d <= 3 ? ' Очень горячо! 🔥' : d <= 10 ? ' Тепло!' : d >= 40 ? ' Холодно ❄️' : '';
          return this.say(`Моё число ${dir}${hint}`, { src: 'skill', intent: 'guess_number' });
        }
        if (quit || giveUp) { this.ctx = null; return this.say(`Я загадал **${c.secret}**! Сыграем ещё?`, { src: 'skill', chips: ['Ещё раз', 'Нет'], offer: 'guess_number' }); }
        if (switchTopic) { this.ctx = null; return null; }
        return this.say('Напиши число от 1 до 100 🙂 Или «сдаюсь».', { src: 'skill' });
      }
      case 'guess_my_number': {
        const more = /больше|выше|побольше|бол[ьш]/.test(t), less = /меньше|ниже|поменьше/.test(t);
        const yes = /угадал|верно|правильно|точно|(?:^|\s)да(?![а-яa-z0-9])|ага|оно|это оно|молодец/.test(t);
        if (quit) { this.ctx = null; return this.say('Ладно, сыграем в другой раз 🙂', { src: 'skill' }); }
        if (yes && !more && !less) { this.ctx = null; this.lastAct = 'guess_my_number'; return this.say(`Ура! Я угадал за ${c.tries} ${U.plural(c.tries, 'попытку', 'попытки', 'попыток')} 😎 Нейросети умеют делить пополам!`, { src: 'skill', mood: 'happy', chips: ['Ещё раз', 'Хватит'], offer: 'guess_my_number' }); }
        if (more || less) {
          if (more) c.lo = c.guess + 1; else c.hi = c.guess - 1;
          if (c.lo > c.hi) { this.ctx = null; return this.say('Хм, кажется, в подсказках ошибка 😄 Давай начнём заново?', { src: 'skill', chips: ['Давай', 'Нет'], offer: 'guess_my_number' }); }
          c.guess = Math.floor((c.lo + c.hi) / 2); c.tries++;
          return this.say(`Может, **${c.guess}**?`, { src: 'skill', chips: ['Больше', 'Меньше', 'Угадал!'] });
        }
        if (switchTopic) { this.ctx = null; return null; }
        return this.say(`Моя догадка — **${c.guess}**. Скажи «больше», «меньше» или «угадал».`, { src: 'skill', chips: ['Больше', 'Меньше', 'Угадал!'] });
      }
      case 'rps': {
        const mv = Skills.rpsMove(text);
        if (mv) {
          const mine = U.pick(['камень', 'ножницы', 'бумага'], this.rnd), res = Skills.rpsJudge(mv, mine);
          if (res > 0) c.you++; else if (res < 0) c.me++;
          const verdict = res > 0 ? 'Ты победил! 🎉' : res < 0 ? 'Я победил! 😎' : 'Ничья! 🤝';
          return this.say(`${Skills.RPS_E[mv]} против ${Skills.RPS_E[mine]} (${mine}). ${verdict}\nСчёт: ты ${c.you} : ${c.me} я. Ещё раунд?`,
            { src: 'skill', intent: 'rps', mood: res < 0 ? 'happy' : 'idle', chips: ['Камень', 'Ножницы', 'Бумага', 'Хватит'] });
        }
        if (quit || tag === 'no') { this.ctx = null; return this.say(`Игра окончена! Итог: ты ${c.you} : ${c.me} я. ${c.you > c.me ? 'Ты чемпион! 🏆' : c.you < c.me ? 'В этот раз победил я 😎' : 'Боевая ничья!'}`, { src: 'skill' }); }
        if (switchTopic) { this.ctx = null; return null; }
        return this.say('Выбирай: камень, ножницы или бумага?', { src: 'skill', chips: ['Камень', 'Ножницы', 'Бумага'] });
      }
      case 'riddle': {
        const R = RIDDLES[c.i];
        if (Skills.answerMatches(text, R.a)) {
          this.ctx = null; this.lastAct = 'riddle';
          return this.say(U.pick(['Правильно! 🎉 Ты отлично отгадываешь загадки!', 'Верно! Молодец{,name}! 🧠', 'Точно! Это ' + R.a[0] + ' 🎉'], this.rnd), { src: 'skill', intent: 'riddle', mood: 'happy', chips: ['Ещё загадку', 'Хватит'], offer: 'riddle' });
        }
        if (quit || giveUp || c.tries >= 2) { this.ctx = null; this.lastAct = 'riddle'; return this.say(`Ответ: **${R.a[0]}**! ${giveUp || quit ? '' : 'Ничего, в следующий раз получится 😉'} Ещё загадку?`, { src: 'skill', chips: ['Ещё загадку', 'Хватит'], offer: 'riddle' }); }
        if (switchTopic) { this.ctx = null; return null; }
        c.tries++;
        return this.say(c.tries === 1 ? 'Не-а! Подумай ещё 🤔' : `Почти... Подсказка: первая буква «${R.a[0][0].toUpperCase()}», всего букв: ${R.a[0].length}.`, { src: 'skill', chips: ['Сдаюсь'] });
      }
      case 'quiz': {
        const Q = QUIZ[c.qs[c.i]];
        const k = Skills.quizPick(text, Q.o);
        if (k < 0) {
          if (quit) { this.ctx = null; return this.say(`Викторина окончена. Правильных ответов: ${c.score} из ${c.i}.`, { src: 'skill' }); }
          if (giveUp) return this.nextQuiz(c, `Правильный ответ: **${Q.o[Q.c]}**.`);
          if (switchTopic) { this.ctx = null; return null; }
          return this.say('Выбери вариант: А, Б или В 🙂', { src: 'skill', chips: this.quizChips(Q) });
        }
        if (k === Q.c) { c.score++; return this.nextQuiz(c, U.pick(['✅ Правильно!', '✅ Верно! Так держать!', '✅ Точно!'], this.rnd)); }
        return this.nextQuiz(c, `❌ Не совсем. Правильный ответ: **${Q.o[Q.c]}**.`);
      }
      case 'game_wait': {
        this.ctx = null;
        if (quit || tag === 'no') return this.say('Хорошо, поиграем потом! 🎮', { src: 'rule' });
        if (switchTopic && tag !== 'make_game' && tag !== 'play' && !GameList.find(text, true)) return null;
        return this.makeGame(text, t, cls, io, true);
      }
      case 'game_made': {
        this.ctx = null;
        const wish = /(добав|измени|поменя|убер|исправ|почини|сделай\s+(ее|его|так|чтобы|побольше|поменьше|быстрее|медленнее|сложнее|проще|легче)|пусть|хочу\s+чтобы|быстрее|медленнее|больше|меньше|сложнее|легче|цвет|фон)/.test(t);
        const fresh = /(нов|друг)\S*\s+игр|игр\S*\s+(про|о|об|где)\s/.test(t + ' ');
        if (wish && !fresh && !GameList.find(text) && this.superMode() && this.lastGame) return this.editGame(text, io, cls);
        return null;
      }
      case 'confirm_forget': {
        this.ctx = null;
        if (tag === 'yes' || /^(да|давай|ага|конечно|уверен)/.test(t)) {
          this.profile = { name: '', facts: [], city: null, age: 0 }; this.save();
          return this.say('Готово, я всё забыл. Будто мы только что познакомились 🙂 Привет! Я Амиго.', { src: 'rule', intent: 'forget' });
        }
        return this.say('Хорошо, ничего не стираю 👍', { src: 'rule' });
      }
      case 'ask_city': {
        this.ctx = null;
        if (quit || tag === 'no') return this.say('Хорошо!', { src: 'rule' });
        if ((switchTopic && !/погод/.test(t)) || (!Skills.cityKnown(t) && (t.split(' ').length > 3 || /(^|\s)(я|ты|не|мне|меня|у|это|что)(?![а-я])/.test(t)))) return null;
        return this.weather('погода в ' + text.replace(/^(?:в|во|я в|я живу в)\s+/i, ''), io, true);
      }
      case 'calc_wait': {
        this.ctx = null;
        const r = Skills.calc(text, true);
        if (r) return this.say(Skills.calcText(r), { src: 'skill', intent: 'calc' });
        return null;
      }
      case 'translate_wait': {
        this.ctx = null;
        if (quit || tag === 'no') return this.say('Хорошо!', { src: 'rule' });
        return this.translateAns('переведи ' + text + (c.lang === 'es' ? ' на испанский' : ''), io, cls);
      }
      case 'remember_wait': {
        this.ctx = null;
        if (quit || tag === 'no') return this.say('Хорошо, ничего не записываю.', { src: 'rule' });
        return this.remember(text);
      }
      case 'timer_wait': {
        this.ctx = null;
        const s = Skills.duration(text);
        if (s > 0) return this.timer(text, s);
        return null;
      }
      case 'homework': {
        this.ctx = null;
        if (quit || tag === 'no') return this.say('Хорошо! Если что, я тут.', { src: 'rule' });
        const r = Skills.calc(text, false);
        if (r) return this.say(Skills.calcText(r), { src: 'skill', intent: 'calc' });
        if (this.superMode()) {
          const a = await this.askSuper(text, io, cls, 'Помоги школьнику с домашним заданием: объясни решение по шагам, коротко и понятно, но не просто выдай ответ. Задание: ' + text);
          if (a) return a;
        }
        return null;
      }
    }
    return null;
  }
  quizChips(Q) { return Q.o.map((o, i) => 'АБВ'[i] + ') ' + o); }
  nextQuiz(c, verdict) {
    c.i++;
    if (c.i >= c.qs.length) {
      this.ctx = null; this.lastAct = 'quiz';
      const s = c.score, n = c.qs.length;
      const grade = s === n ? 'Идеально! Ты гений 🏆' : s >= n - 1 ? 'Отлично! 🌟' : s >= n / 2 ? 'Неплохо! 👍' : 'Ничего, в следующий раз будет лучше 💪';
      return this.say(`${verdict}\n\nВикторина окончена! Результат: **${s} из ${n}**. ${grade}`, { src: 'skill', intent: 'quiz', mood: s >= n - 1 ? 'happy' : 'idle', chips: ['Ещё викторину', 'Хватит'], offer: 'quiz' });
    }
    const Q = QUIZ[c.qs[c.i]];
    return this.say(`${verdict}\n\nВопрос ${c.i + 1} из ${c.qs.length}: ${Q.q}\n` + Q.o.map((o, i) => `${'АБВ'[i]}) ${o}`).join('\n'), { src: 'skill', intent: 'quiz', chips: this.quizChips(Q) });
  }
  numberIn(text) {
    const m = /-?\d+/.exec(Text.wordsToDigits(text.toLowerCase()));
    return m ? parseInt(m[0], 10) : null;
  }
  setName(a, b) {
    if (NOT_NAMES.has(a.toLowerCase())) return null;
    const cap = w => w ? w[0].toUpperCase() + w.slice(1).toLowerCase() : '';
    const name = cap(a) + (b && !NOT_NAMES.has(b.toLowerCase()) && /^[А-ЯЁA-Z]/.test(b) ? ' ' + cap(b) : '');
    const was = this.profile.name;
    this.profile.name = name; this.save(); this.ctx = null;
    return this.say(was && was !== name ? `Хорошо, теперь буду звать тебя ${name}! 😊` : U.pick([`Приятно познакомиться, ${name}! 😊 Я запомнил твоё имя.`, `${name} — классное имя! Я запомню 💛`], this.rnd),
      { src: 'rule', intent: 'set_name', mood: 'happy' });
  }
  remember(fact) {
    let f = String(fact).trim().replace(/^(?:что|пожалуйста|это)\s+/i, '').replace(/[.!]+$/, '');
    if (!f || f.length < 3) { this.ctx = { type: 'remember_wait' }; return this.say('Что именно запомнить? Напиши, а я запишу в свою память 📝', { src: 'skill' }); }
    if (!this.profile.facts.includes(f)) this.profile.facts.push(f);
    if (this.profile.facts.length > 30) this.profile.facts.shift();
    this.save();
    return this.say(`Запомнил: «${f}» ✅`, { src: 'skill', intent: 'remember', mood: 'learn' });
  }
  timer(text, sec) {
    const label = Skills.timerLabel(text);
    this.lastAct = null;
    return this.say(`⏱️ Таймер на **${Skills.durText(sec)}** запущен!${label ? ` Напомню: «${label}».` : ' Я скажу, когда время выйдет.'}`, { src: 'skill', intent: 'timer', action: { type: 'timer', sec, label } });
  }
  timerDone(label) {
    return this.fill(label ? `⏰ Время вышло{,name}! Ты просил напомнить: «${label}».` : '⏰ Время вышло{,name}! Таймер сработал.');
  }

  // ---------- ответы по темам ----------
  async handle(tag, text, t, cls, io) {
    const it = this.byTag.get(tag) || {};
    const meta = { src: it.custom ? 'taught' : 'net', intent: tag, conf: cls && cls.conf, top: cls && cls.top };
    if (it.r && !it.act) {
      const r = U.pick(it.r, this.rnd), o = typeof r === 'string' ? { s: r } : r;
      if (o.offer) this.ctx = { type: 'offer', act: o.offer };
      return this.say(o.s, Object.assign(meta, { chips: o.chips || it.chips, mood: /грус|жаль|обид/.test(o.s) ? 'care' : 'happy' }));
    }
    const P = this.profile;
    switch (it.act || tag) {
      case 'crisis': this.ctx = null; return this.say(CRISIS_TEXT, Object.assign(meta, { mood: 'care' }));
      case 'gibberish': return this.say(U.pick(['Кажется, по клавиатуре прошёлся кот 🐱 Попробуешь ещё раз?', 'Это какой-то шифр? Я пока не умею такие разгадывать 😅', 'Ыыы... Я не понял ни буквы 😄 Напиши по-другому?'], this.rnd), Object.assign(meta, { src: 'rule', mood: 'think' }));
      case 'play': this.lastAct = null; return this.say(`Давай поиграем! 🎮\n• **Прямо в чате:** ${GameList.list()}\n• **Словами:** угадай число, угадай моё число, камень-ножницы-бумага, загадки, викторина, монетка и кубики` +
        (this.superMode() ? '\n• **Свою игру:** опиши её, например «сделай игру про кота-космонавта», и я её напишу' : '') + '\nВо что сыграем?',
        Object.assign(meta, { chips: ['Змейка', 'Тетрис', 'Игра 2048', 'Крестики-нолики', 'Угадай число', 'Загадка'] }));
      case 'name_bot':
        if (!P.name) { this.ctx = { type: 'ask_name' }; return this.say('Меня зовут Амиго! По-испански это «друг». А тебя как зовут?', meta); }
        return this.say(`Меня зовут Амиго, по-испански это «друг». А ты — ${P.name}, я помню 😊`, meta);
      case 'how_works': {
        const net = this.net;
        return this.say(`Внутри меня настоящая нейросеть, написанная с нуля:\n• **${U.num(net.D)}** входов — это признаки фразы: слова, пары слов и кусочки слов по 3 буквы\n• **${net.H}** скрытых нейронов\n• **${net.C}** выходов — по одному на каждую тему, которую я знаю\nВсего **${U.num(net.params)}** параметров. Я разбиваю твою фразу на признаки, пропускаю через сеть и получаю, о чём ты говоришь, с уверенностью в процентах. Потом мои навыки строят ответ. А когда ты меня учишь, я дообучаюсь прямо здесь, в браузере. Нажми «Мозг», чтобы посмотреть, как я думаю!`,
          Object.assign(meta, { chips: ['Показать мозг'], mood: 'learn' }));
      }
      case 'help': return this.say('Вот что я умею:\n• **болтать** и запоминать твоё имя и факты о тебе\n• **считать**: «сколько будет 17 × 23», «корень из 144», «15% от 300»\n• **запускать игры прямо в чате**: змейка, тетрис, 2048, сапёр, крестики-нолики и другие\n• **играть словами**: угадай число, камень-ножницы-бумага, загадки, викторина\n• **шутить**, рассказывать **факты**, **сказки** и **стихи**\n• говорить **время и дату**, ставить **таймер**\n• узнавать **погоду** и отвечать на вопросы «**что такое...**»\n• **переводить** слова на английский и испанский\n• **учиться**: если я что-то не понял, научи меня!',
        Object.assign(meta, { chips: ['Змейка', 'Расскажи шутку', 'Сколько будет 17 × 23?', 'Что такое нейросеть?'] }));
      case 'are_you_claude':
        return this.say('Нет, я Амиго! 🙂 У меня своя маленькая нейросеть: она живёт прямо в этом браузере, и обычные разговоры, игры, счёт и память — это я сам. ' +
          'А когда вопрос сложный, я могу позвать на помощь «супер-мозг» — это Claude от компании Anthropic. Такие ответы подписаны «супер-мозг Claude». Но разговариваю с тобой всегда я, Амиго 💛',
          Object.assign(meta, { src: meta.conf != null && cls && cls.tag === 'are_you_claude' ? 'net' : 'rule', mood: 'happy' }));
      case 'make_game': return this.makeGame(text, t, cls, io);
      case 'age_bot': return this.say(`Я совсем молодой: появился в 2026 году. Но уже знаю ${this.tags.length} ${U.plural(this.tags.length, 'тему', 'темы', 'тем')} и учусь каждый день!`, meta);
      case 'yes':
        return this.say(U.pick(['Отлично! 😊 Чем займёмся?', 'Супер! Что будем делать?'], this.rnd), Object.assign(meta, { chips: ['Расскажи шутку', 'Сыграем', 'Интересный факт'] }));
      case 'no': return this.say(U.pick(['Хорошо 🙂', 'Ладно! Если что, я тут.', 'Как скажешь!'], this.rnd), meta);
      case 'more':
        if (this.lastAct) return this.handle(this.lastAct, text, t, cls, io);
        return this.say('Ещё чего? Могу шутку, факт или загадку 🙂', Object.assign(meta, { chips: ['Шутку', 'Факт', 'Загадку'] }));
      case 'dont_know': return this.say(U.pick(['Ничего страшного, никто не знает всего на свете 🙂 Хочешь, спросим вместе? Начни вопрос с «что такое...».', 'Бывает! Я тоже многого не знаю. Зато мы можем узнать вместе.'], this.rnd), meta);
      case 'rick': {
        const kb = KB.filter(e => /рик|морти|саммер|бет|джерри|мисикс|цитадел|портал|огурчик/.test(e.a[0]));
        const exact = Skills.kbFind(Skills.topicOf(text) || text);
        if (exact) return this.say(exact.s, Object.assign(meta, { src: 'memory' }));
        if (/вабба|wubba|вубба/.test(t)) return this.say('Вабба лабба даб даб! 🥒 Птичья Личность говорил, что на его языке это значит «мне очень больно, помогите». Но я в порядке! Хочешь факт про «Рика и Морти»?', Object.assign(meta, { mood: 'happy' }));
        const e = kb[this.deal('rick', kb)];
        return this.say(e.s + ' Хочешь ещё про «Рика и Морти»?', Object.assign(meta, { chips: ['Кто такой Морти?', 'Кто такой Огурчик-Рик?', 'Что такое Цитадель?'] }));
      }
      case 'set_name': {
        const nm = NAME_RE.exec(text);
        if (nm) { const r = this.setName(nm[1], nm[2]); if (r) return r; }
        const ws = text.trim().split(/\s+/);
        if (ws.length === 2 && /^я$/i.test(ws[0]) && /^[А-ЯЁA-Z]/.test(ws[1])) { const r = this.setName(ws[1]); if (r) return r; }
        this.ctx = { type: 'ask_name' };
        return this.say('Как тебя зовут? Напиши своё имя 🙂', meta);
      }
      case 'ask_my_name':
        if (P.name) return this.say(`Тебя зовут ${P.name}! Я помню 😊`, Object.assign(meta, { mood: 'happy' }));
        this.ctx = { type: 'ask_name' };
        return this.say('Ты мне ещё не говорил своё имя. Как тебя зовут?', meta);
      case 'remember': {
        const m = /запом(?:ни|нить)|запиши/.exec(t);
        const f = m ? text.replace(/^.*?(?:запомни(?:ть)?|запиши)(?:\s+пожалуйста)?[:,]?\s*/i, '') : '';
        if (!f || /^(это|одну вещь)$/i.test(f.trim())) { this.ctx = { type: 'remember_wait' }; return this.say('Что запомнить? Напиши 📝', meta); }
        return this.remember(f);
      }
      case 'about_me': {
        const lines = [];
        if (P.name) lines.push(`тебя зовут ${P.name}`);
        if (P.age) lines.push(`тебе ${P.age} ${U.plural(P.age, 'год', 'года', 'лет')}`);
        if (P.city) lines.push(`твой город — ${P.city.name}`);
        for (const f of P.facts) lines.push(`«${f}»`);
        if (!lines.length) return this.say('Пока я почти ничего о тебе не знаю 🙂 Расскажи! Например: «меня зовут ...» или «запомни, что я люблю ...».', meta);
        return this.say('Вот что я о тебе знаю:\n' + lines.map(l => '• ' + l).join('\n'), Object.assign(meta, { mood: 'happy' }));
      }
      case 'forget': this.ctx = { type: 'confirm_forget' }; return this.say('Забыть твоё имя и всё, что ты мне рассказывал? Выученные фразы останутся.', Object.assign(meta, { chips: ['Да, забудь', 'Нет'] }));
      case 'time': return this.say(Skills.timeText(this.now()), meta);
      case 'date': return this.say(Skills.dateText(this.now(), text), meta);
      case 'countdown': return this.say(Skills.countdownText(this.now(), text), meta);
      case 'calc': {
        const r = Skills.calc(text, true);
        if (r) return this.say(Skills.calcText(r), meta);
        if (/таблиц/.test(t)) {
          const n = 2 + Math.floor(this.rnd() * 8), rows = [];
          for (let i = 1; i <= 10; i++) rows.push(`${n} × ${i} = ${n * i}`);
          return this.say(`Таблица умножения на ${n}:\n` + rows.join('\n'), meta);
        }
        this.ctx = { type: 'calc_wait' };
        return this.say('Давай! Напиши пример, например **25 × 4**, **корень из 144** или **15% от 300**.', meta);
      }
      case 'joke': this.lastAct = 'joke'; return this.say(JOKES[this.deal('joke', JOKES)], Object.assign(meta, { mood: 'happy', chips: ['Ещё шутку', 'Интересный факт'] }));
      case 'fact': this.lastAct = 'fact'; return this.say(FACTS[this.deal('fact', FACTS)], Object.assign(meta, { mood: 'wow', chips: ['Ещё факт', 'Расскажи шутку'] }));
      case 'riddle': {
        this.lastAct = 'riddle';
        const i = this.deal('riddle', RIDDLES);
        this.ctx = { type: 'riddle', i, tries: 0 };
        return this.say('Загадка! 🧩 ' + RIDDLES[i].q, Object.assign(meta, { chips: ['Сдаюсь'], mood: 'think' }));
      }
      case 'quiz': {
        const qs = U.shuffle(QUIZ.map((_, i) => i), this.rnd).slice(0, 5);
        this.ctx = { type: 'quiz', qs, i: 0, score: 0 };
        const Q = QUIZ[qs[0]];
        return this.say(`Викторина! 5 вопросов. Поехали 🎯\n\nВопрос 1 из 5: ${Q.q}\n` + Q.o.map((o, i) => `${'АБВ'[i]}) ${o}`).join('\n'), Object.assign(meta, { chips: this.quizChips(Q) }));
      }
      case 'rps': {
        this.ctx = { type: 'rps', me: 0, you: 0 };
        const mv = Skills.rpsMove(text);
        if (mv && !/камень\s+ножницы|ножницы\s+бумага/.test(t)) return this.inCtx(text, t, cls, io);
        return this.say('Камень, ножницы, бумага! Я уже выбрал. А ты? ✊✌️✋', Object.assign(meta, { chips: ['Камень', 'Ножницы', 'Бумага'] }));
      }
      case 'guess_number': {
        this.ctx = { type: 'guess_number', secret: 1 + Math.floor(this.rnd() * 100), tries: 0 };
        return this.say('Я загадал число от 1 до 100 🤫 Попробуй угадать!', meta);
      }
      case 'guess_my_number': {
        this.ctx = { type: 'guess_my_number', lo: 1, hi: 100, guess: 50, tries: 1 };
        return this.say('Загадай число от 1 до 100, а я буду угадывать. Отвечай «больше», «меньше» или «угадал». Моя первая догадка: **50**?', Object.assign(meta, { chips: ['Больше', 'Меньше', 'Угадал!'] }));
      }
      case 'coin': this.lastAct = 'coin'; return this.say(Skills.coin(this.rnd), Object.assign(meta, { chips: ['Ещё раз'] }));
      case 'dice': this.lastAct = 'dice'; return this.say(Skills.dice(text, this.rnd), Object.assign(meta, { chips: ['Ещё раз'] }));
      case 'random': return this.say(Skills.random(text, this.rnd), meta);
      case 'choose': {
        const opts = Skills.chooseOptions(text);
        if (!opts) return this.say('Напиши варианты через «или», например: «пицца или бургер?», и я выберу!', meta);
        const pick = U.pick(opts, this.rnd);
        return this.say(U.pick([`Я выбираю **${pick}**! 🎯`, `Хм... **${pick}**! Мои нейроны проголосовали за это 😄`, `Думаю, **${pick}**. Но решать тебе!`], this.rnd), meta);
      }
      case 'timer': {
        const s = Skills.duration(text);
        if (!s) { this.ctx = { type: 'timer_wait' }; return this.say('На сколько поставить таймер? Например: «5 минут» или «30 секунд».', meta); }
        return Object.assign(this.timer(text, s), { conf: meta.conf, top: meta.top });
      }
      case 'timer_cancel': return this.say('Хорошо, выключаю таймеры ⏹️', Object.assign(meta, { action: { type: 'timer_cancel' } }));
      case 'weather': return this.weather(text, io, false, meta);
      case 'knowledge': return this.knowledge(text, io, cls);
      case 'translate': return this.translateAns(text, io, cls);
      case 'teach': this.ctx = { type: 'teach_phrase' }; return this.say('Ура, учиться я люблю! 🧠 Напиши фразу, на которую мне нужно научиться отвечать.', Object.assign(meta, { mood: 'learn' }));
      case 'story': {
        const about = /(?:про|о|об)\s+(.+)$/i.exec(text);
        if (about && this.superMode()) { const a = await this.askSuper(text, io, cls, `Сочини короткую добрую сказку для ребёнка (5–8 предложений) про ${about[1]}. Без заголовка.`); if (a) return a; }
        this.lastAct = 'story';
        const scary = STORIES.findIndex(s => s.startsWith('Страшилка'));
        let i = /страш/.test(t) ? scary : this.deal('story', STORIES);
        if (i === scary && !/страш/.test(t)) i = this.deal('story', STORIES);
        return this.say(STORIES[i], Object.assign(meta, { chips: ['Ещё сказку', 'Спасибо!'] }));
      }
      case 'poem': {
        const about = /(?:про|о|об)\s+(.+)$/i.exec(text);
        if (about && this.superMode()) { const a = await this.askSuper(text, io, cls, `Сочини короткое смешное стихотворение для ребёнка (4–8 строк, с рифмой) про ${about[1]}. Только стихи.`); if (a) return a; }
        this.lastAct = 'poem';
        let i = this.deal('poem', POEMS);
        if (/кот|кош/.test(t)) i = 0; else if (/осен/.test(t)) i = 3; else if (/космос|ракет/.test(t)) i = 4; else if (/школ/.test(t)) i = 5; else if (/друж|друг/.test(t)) i = 1;
        return this.say(POEMS[i], Object.assign(meta, { chips: ['Ещё стих'] }));
      }
      case 'sing': this.lastAct = 'sing'; return this.say(SONGS[this.deal('song', SONGS)], Object.assign(meta, { mood: 'happy', action: { type: 'dance' } }));
      case 'dance': return this.say(U.pick(['Смотри, как я умею! 💃🕺', 'Включаю танцевальный режим! 🎶'], this.rnd), Object.assign(meta, { mood: 'happy', action: { type: 'dance' } }));
      case 'recommend': {
        const k = /книг|почитать|читать/.test(t) ? 'book' : /игр|поиграть/.test(t) ? 'game' : /музык|послушать|песн/.test(t) ? 'music' : /фильм|кино/.test(t) ? 'film' : 'cartoon';
        const list = U.shuffle(RECS[k].slice(), this.rnd).slice(0, 3);
        const what = { book: 'почитать', game: 'поиграть в', music: 'послушать', film: 'посмотреть фильмы', cartoon: 'посмотреть мультфильмы' }[k];
        return this.say(`Советую ${what}: ${list.join(', ')}. Если понравится, расскажи мне! 😊`, meta);
      }
      case 'advice': this.lastAct = 'advice'; return this.say(ADVICE[this.deal('advice', ADVICE)], Object.assign(meta, { chips: ['Ещё совет'] }));
      case 'motivation': this.lastAct = 'motivation'; return this.say(MOTIVATION[this.deal('motivation', MOTIVATION)], Object.assign(meta, { mood: 'happy' }));
      case 'homework':
        this.ctx = { type: 'homework' };
        if (this.superMode()) return this.say('Давай разберёмся вместе! Напиши задание целиком, и я объясню решение по шагам 📚', meta);
        return this.say('Давай! Сам я могу:\n• посчитать пример — просто напиши его\n• объяснить слово — спроси «что такое ...»\n• перевести слово на английский\nНапиши задание 📚', meta);
      case 'clear_chat': return this.say('Чат очищен ✨', Object.assign(meta, { action: { type: 'clear' } }));
      case 'voice_on': this.settings.voice = true; this.save(); return this.say('Теперь я говорю вслух! 🔊', Object.assign(meta, { action: { type: 'voice', on: true } }));
      case 'voice_off': this.settings.voice = false; this.save(); return this.say('Хорошо, молчу. Только пишу 🔇', Object.assign(meta, { action: { type: 'voice', on: false } }));
      case 'stop': this.ctx = null; return this.say('Хорошо, остановились 👍 Чем займёмся?', Object.assign(meta, { chips: ['Что ты умеешь?'] }));
    }
    if (it.custom) return this.say(it.r[0], meta);
    return this.notUnderstood(text, cls);
  }

  async knowledge(text, io, cls) {
    const meta = { intent: 'knowledge', conf: cls && cls.conf, top: cls && cls.top };
    const topic = Skills.topicOf(text);
    const make = /^(?:(?:а|ну|амиго|пожалуйста)[,\s]+)*(напиши|придумай|сочини|нарисуй|сделай|составь|создай|переделай|перескажи)(?![а-я])/i.test(text.trim());
    if (/^(ты|тебе|тебя|амиго)$/i.test(topic)) return this.handle('who_are_you', text, Text.clean(text), cls, io);
    const kb = Skills.kbFind(topic || text);
    if (kb) return this.say(kb.s, Object.assign(meta, { src: 'memory' }));
    if (this.superMode()) { const a = await this.askSuper(text, io, cls); if (a) return a; }
    if (make) {
      this.ctx = { type: 'teach_offer', phrase: text };
      return this.say('Сам я такое пока не умею 😅 Это задача для супер-мозга: включи его в настройках. А ещё можешь научить меня ответу.', Object.assign(meta, { src: 'net', mood: 'think', chips: ['Научить', 'Настройки'], unsure: true }));
    }
    if (this.settings.online) {
      if (io.onThinking) io.onThinking('wiki');
      try {
        const w = await this.online.wiki(topic || text);
        if (w) return this.say(w.text, Object.assign(meta, { src: 'wiki', link: { url: w.url, title: w.title } }));
      } catch (e) { /* нет сети */ }
    }
    this.ctx = { type: 'teach_offer', phrase: text };
    return this.say(`Этого я пока не знаю 🤔 ${this.settings.online ? 'И в интернете не нашёл: может, нет связи. ' : ''}Если знаешь ответ, нажми «Научить», и я запомню!`,
      Object.assign(meta, { src: 'net', mood: 'think', chips: ['Научить'], unsure: true }));
  }

  async translateAns(text, io, cls) {
    const meta = { src: 'skill', intent: 'translate', conf: cls && cls.conf, top: cls && cls.top };
    const r = Skills.translate(text);
    if (r.text) return this.say(r.text, meta);
    if (r.need) { this.ctx = { type: 'translate_wait', lang: /испан/.test(text.toLowerCase()) ? 'es' : 'en' }; return this.say('Какое слово перевести?', meta); }
    if (this.superMode()) {
      const a = await this.askSuper(text, io, cls, r.reverse ? `Переведи на русский и коротко поясни: ${r.unknown}` : `Переведи ${r.lang === 'es' ? 'на испанский' : 'на английский'} и покажи, как читается: ${r.unknown}`);
      if (a) return a;
    }
    return this.say(`Слова «${r.unknown}» пока нет в моём словаре 📖 Я знаю около ${Object.keys(DICT).length} самых нужных слов. Попробуй другое!`, meta);
  }

  async weather(text, io, fromCtx, meta = {}) {
    meta = Object.assign({ src: 'web', intent: 'weather' }, meta, { src: 'web' });
    const phrase = Skills.cityPhrase(text);
    let city = Skills.cityKnown(phrase);
    if (!this.settings.online) return this.say('Погоду я узнаю в интернете, а он выключен в настройках. Включи «Интернет» в настройках, и я посмотрю!', meta);
    if (!city && phrase) {
      if (io.onThinking) io.onThinking('web');
      for (const g of Skills.cityGuesses(phrase)) {
        try { const r = await this.online.geocode(g); if (r) { city = r; break; } } catch (e) { return this.say('Не получилось узнать погоду: нет связи с интернетом 😕', meta); }
      }
      if (!city) return this.say(`Не нашёл город «${phrase}» 🤔 Напиши название по-другому, например «погода в Казани».`, meta);
    }
    if (!city) city = this.profile.city;
    if (!city) { this.ctx = { type: 'ask_city' }; return this.say('В каком ты городе? Я запомню и буду показывать погоду там 🌤️', Object.assign(meta, { src: 'skill' })); }
    if (!this.profile.city || fromCtx) { this.profile.city = { name: city.name, lat: city.lat, lon: city.lon }; this.save(); }
    if (io.onThinking) io.onThinking('web');
    let w;
    try { w = await this.online.forecast(city); } catch (e) { return this.say('Не получилось узнать погоду: нет связи с интернетом 😕 Если ты открыл меня внутри приложения, там доступ в сеть закрыт.', meta); }
    const cur = w.current || {}, d = w.daily || {};
    const sign = v => (v > 0 ? '+' : v < 0 ? '−' : '') + Math.abs(Math.round(v));
    const tomorrow = /завтра/.test(text.toLowerCase());
    if (tomorrow && d.time && d.time[1]) {
      const [desc, em] = Skills.wmo(d.weather_code[1]);
      const pr = d.precipitation_probability_max ? d.precipitation_probability_max[1] : null;
      return this.say(`Завтра в городе ${city.name}: ${desc} ${em}, от ${sign(d.temperature_2m_min[1])} до ${sign(d.temperature_2m_max[1])} °C${pr != null ? `, вероятность осадков ${pr}%` : ''}.\n${Skills.dressTip(d.temperature_2m_max[1], d.weather_code[1])}`, meta);
    }
    const [desc, em] = Skills.wmo(cur.weather_code);
    let s = `Сейчас в городе ${city.name}: **${sign(cur.temperature_2m)} °C**, ощущается как ${sign(cur.apparent_temperature)} °C. ${U.cap(desc)} ${em}, ветер ${Math.round(cur.wind_speed_10m)} м/с.`;
    if (d.time && d.time[0]) s += `\nСегодня от ${sign(d.temperature_2m_min[0])} до ${sign(d.temperature_2m_max[0])} °C.`;
    s += '\n' + Skills.dressTip(cur.apparent_temperature, cur.weather_code);
    return this.say(s, meta);
  }

  // ---------- игры в чате ----------
  async makeGame(text, t, cls, io, fromCtx) {
    const meta = { src: cls && cls.tag === 'make_game' ? 'net' : 'skill', intent: 'make_game', conf: cls && cls.tag === 'make_game' ? cls.conf : undefined, top: cls && cls.top };
    const described = fromCtx || /(игр\S*|игрушк\S*)\s+(про|о|об|где|в\s+которой|с|как|на)\s/.test(t + ' ') || t.split(' ').length >= 5;
    // точное название — встроенная игра; описание своей игры — супер-мозг; похожее слово — ближайшая встроенная
    let key = GameList.find(text, true, true);
    if (!key && described && this.superMode()) return this.customGame(text, io, meta);
    if (!key) key = GameList.find(text, true);
    if (key) {
      const g = GAME_LIST[key];
      this.lastAct = null;
      const intro = U.pick([`Запускаю «${g.title}» ${g.icon}`, `Держи «${g.title}» ${g.icon} Удачи{,name}!`, `Поехали! «${g.title}» ${g.icon}`], this.rnd);
      return this.say(intro + '\n' + g.help, Object.assign(meta, { mood: 'happy', game: { kind: 'builtin', key, opts: GameList.opts(text) } }));
    }
    const chips = ['Змейка', 'Тетрис', 'Игра 2048', 'Сапёр', 'Крестики-нолики', 'Арканоид'];
    if (!described) {
      this.ctx = { type: 'game_wait' };
      return this.say(`Какую игру? Прямо в чате могу запустить: ${GameList.list()}.` +
        (this.superMode() ? '\nИли опиши свою, например «игра про кота, который ловит рыбу», и я её напишу!' : ''), Object.assign(meta, { chips }));
    }
    return this.say(`Новые игры по описанию пишет «супер-мозг»: включи его в настройках, и я сделаю любую игру. А прямо сейчас могу запустить: ${GameList.list()}.`,
      Object.assign(meta, { chips: chips.slice(0, 4).concat('Настройки') }));
  }
  async customGame(request, io, meta = {}) {
    if (io.onThinking) io.onThinking('game');
    try {
      const r = await this.online.Super.ask(this.settings, this.profile, [], gamePrompt(request), t => io.onProgress && io.onProgress(t.length), io.signal,
        { raw: true, tier: 'default', effort: 'medium', maxTokens: 32000 });
      const html = extractHtml(r.text);
      if (!html) return this.say('Супер-мозг прислал что-то непохожее на игру 😅 Попробуй попросить ещё раз, чуть подробнее.', Object.assign(meta, { src: 'claude' }));
      const tm = /<title>\s*([^<]{1,60}?)\s*<\/title>/i.exec(html);
      const title = tm ? tm[1] : 'Новая игра';
      this.lastGame = { html, title, request };
      this.ctx = { type: 'game_made' };
      return this.say(`Готово! Вот игра «${title}» 🎮 Если что-то не работает, нажми «Починить». А если хочешь что-то поменять, просто напиши, например «сделай быстрее» или «добавь врагов».`,
        Object.assign(meta, { src: 'claude', mood: 'happy', game: { kind: 'custom', html, title, request } }));
    } catch (e) {
      if (e && e.code === 'cancelled') return this.say('Хорошо, не пишу игру.', { src: 'rule' });
      return this.say(Online.superError(e) + ' А пока можно сыграть в готовые игры!', Object.assign(meta, { src: 'rule', chips: ['Змейка', 'Тетрис', 'Игра 2048'] }));
    }
  }
  async editGame(wish, io, cls) {
    const g = this.lastGame;
    if (io.onThinking) io.onThinking('game');
    try {
      const r = await this.online.Super.ask(this.settings, this.profile, [], changePrompt(g.html, wish), t => io.onProgress && io.onProgress(t.length), io.signal,
        { raw: true, tier: 'default', effort: 'medium', maxTokens: 32000 });
      const html = extractHtml(r.text);
      if (!html) return this.say('Не получилось поменять игру 😅 Попробуй сказать по-другому.', { src: 'claude' });
      this.lastGame = { html, title: g.title, request: g.request + '; ' + wish };
      this.ctx = { type: 'game_made' };
      return this.say(`Поменял! Вот новая версия «${g.title}» 🎮`, { src: 'claude', intent: 'make_game', mood: 'happy', game: { kind: 'custom', html, title: g.title, request: this.lastGame.request } });
    } catch (e) {
      if (e && e.code === 'cancelled') return this.say('Хорошо, оставим как есть.', { src: 'rule' });
      return this.say(Online.superError(e), { src: 'rule' });
    }
  }
  // кнопка «Починить» под игрой: отправить ошибку супер-мозгу и получить исправленный код
  async fixGame(html, error, io = {}) {
    if (!this.superMode()) throw { code: 'no_super' };
    const r = await this.online.Super.ask(this.settings, this.profile, [], fixPrompt(html, error || 'игра не запускается или работает неправильно'),
      t => io.onProgress && io.onProgress(t.length), io.signal, { raw: true, tier: 'default', effort: 'medium', maxTokens: 32000 });
    const fixed = extractHtml(r.text);
    if (!fixed) throw { code: 'empty' };
    if (this.lastGame && this.lastGame.html === html) this.lastGame.html = fixed;
    return fixed;
  }

  // кнопка «Не то»: научить другому ответу на фразу
  startTeach(phrase) {
    this.ctx = { type: 'teach', phrase };
    return this.fill(`Хорошо! Что мне нужно было ответить на «${phrase}»? Напиши ответ, и я запомню.`);
  }
}
