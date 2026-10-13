// Интерфейс Амиго: чат, аватар, голос, таймеры, панель «Мозг» и настройки.
const STORE_KEY = 'amigo.v1', CHAT_KEY = 'amigo.chat.v1', UI_KEY = 'amigo.ui.v1';
const DEFAULT_CHIPS = ['Что ты умеешь?', 'Расскажи шутку', 'Сколько будет 17 × 23?', 'Загадай загадку', 'Что такое чёрная дыра?', 'Как ты работаешь?', 'Сыграем в угадай число', 'Интересный факт', 'Викторина', 'Какой сегодня день?'];
const SRC_LABEL = { memory: 'из моей памяти', wiki: 'Википедия', claude: 'супер-мозг Claude', web: 'интернет', taught: 'ты научил' };

class App {
  constructor(brain) {
    this.brain = brain;
    this.el = id => document.getElementById(id);
    this.log = [];
    this.busy = false;
    this.timers = [];
    this.lossHistory = brain.model.history.slice();
    this.uiState = U.store.get(UI_KEY, {});
  }

  start() {
    const $ = this.el;
    this.logEl = $('log'); this.input = $('input'); this.avatar = $('avatar');
    $('composer').addEventListener('submit', e => { e.preventDefault(); this.send(this.input.value); });
    this.input.addEventListener('keydown', e => { if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); this.send(this.input.value); } });
    this.input.addEventListener('input', () => this.autosize());
    $('btnBrain').addEventListener('click', () => this.toggleBrain());
    $('btnBrainClose').addEventListener('click', () => this.toggleBrain(false));
    $('btnSettings').addEventListener('click', () => this.openSettings(true));
    $('btnSetClose').addEventListener('click', () => this.openSettings(false));
    $('backdrop').addEventListener('click', () => this.openSettings(false));
    $('btnVoice').addEventListener('click', () => this.setVoice(!this.brain.settings.voice, true));
    $('btnRetrain').addEventListener('click', () => this.retrain());
    document.addEventListener('keydown', e => {
      if (e.key !== 'Escape') return;
      if (!$('settings').hidden) this.openSettings(false);
      else if (!$('brain').hidden && window.innerWidth < 1000) this.toggleBrain(false);
    });
    this.bindSettings();
    this.initMic();
    if (!('speechSynthesis' in window)) $('btnVoice').hidden = true;

    // перерисовать схемы при смене темы и размера
    const redraw = () => this.drawAll();
    try { window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', redraw); } catch (e) { /* старый браузер */ }
    try { new MutationObserver(redraw).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme', 'class'] }); } catch (e) { /* нет */ }
    let rt = 0; window.addEventListener('resize', () => { clearTimeout(rt); rt = setTimeout(redraw, 120); });
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(redraw);

    Online.Super.onChange = () => this.renderSettings();
    Online.Super.init();

    const wide = window.innerWidth >= 1000;
    this.toggleBrain(this.uiState.brain == null ? wide : this.uiState.brain && wide, false);
    this.renderStats(); this.renderTaught(); this.setVoice(this.brain.settings.voice, false);
    this.restore();
    this.setStatus();
    if (this.brain.needsTuning) this.tune();
  }

  // ---------- сообщения ----------
  restore() {
    const saved = U.store.get(CHAT_KEY, []);
    if (Array.isArray(saved) && saved.length) {
      for (const m of saved) this.addMsg(m.who, m.text, m.meta || {}, { restore: true });
      this.brain.history = saved.slice(-20).map(m => ({ role: m.who === 'me' ? 'user' : 'assistant', content: m.text }));
      this.chips(null);
      this.scroll(true);
    } else this.greet();
  }
  greet() {
    const n = this.brain.profile.name;
    const text = n ? `С возвращением, ${n}! 😊 Чем займёмся?`
      : 'Хола! 👋 Я **Амиго** — нейросеть, которая живёт прямо в твоём браузере. Я умею болтать, считать, играть, шутить и учиться новому.\n\nКак тебя зовут?';
    if (!n) this.brain.ctx = { type: 'ask_name' };
    this.addMsg('bot', text, { src: 'rule' });
    this.brain.history.push({ role: 'assistant', content: text });
    this.chips(n ? null : ['Что ты умеешь?', 'Расскажи шутку', 'Как ты работаешь?']);
  }
  renderText(el, text) {
    const esc = s => s.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    let h = esc(String(text));
    h = h.replace(/^#{1,4}\s+(.+)$/gm, '<strong>$1</strong>')
      .replace(/^\s*[-*]\s+/gm, '• ')
      .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
      .replace(/(^|[\s(])\*([^*\n]+)\*(?=[\s.,!?)]|$)/g, '$1<em>$2</em>')
      .replace(/`([^`\n]+)`/g, '<code>$1</code>')
      .replace(/\n/g, '<br>');
    el.innerHTML = h;
  }
  addMsg(who, text, meta = {}, opt = {}) {
    const wrap = document.createElement('div');
    wrap.className = 'msg ' + who;
    const b = document.createElement('div');
    b.className = 'bubble';
    this.renderText(b, text);
    wrap.appendChild(b);
    if (who === 'bot') { const m = this.metaEl(meta); if (m) wrap.appendChild(m); }
    this.logEl.appendChild(wrap);
    if (!opt.restore && !opt.live) { this.log.push({ who, text, meta, ts: Date.now() }); this.saveChat(); }
    else if (opt.restore) this.log.push({ who, text, meta, ts: Date.now() });
    if (!opt.restore) this.scroll();
    wrap.bubble = b;
    return wrap;
  }
  metaEl(meta) {
    const parts = [];
    let label = '';
    if (meta.src === 'net' || (meta.src === 'skill' && meta.conf != null)) label = `нейросеть · ${meta.title || 'тема'} · ${Math.round((meta.conf || 0) * 100)}%`;
    else if (meta.src === 'skill') label = 'навык';
    else if (SRC_LABEL[meta.src]) label = SRC_LABEL[meta.src];
    if (label) { const s = document.createElement('span'); s.className = 'src ' + meta.src; s.textContent = label; parts.push(s); }
    if (meta.link && /^https:\/\//.test(meta.link.url)) {
      const a = document.createElement('a'); a.href = meta.link.url; a.target = '_blank'; a.rel = 'noopener noreferrer'; a.textContent = 'статья: ' + meta.link.title; parts.push(a);
    }
    if (meta.phrase && (meta.conf != null || ['memory', 'taught', 'wiki', 'claude'].includes(meta.src)) && meta.src !== 'rule' && !meta.unsure) {
      const btn = document.createElement('button'); btn.type = 'button'; btn.className = 'link-btn'; btn.textContent = 'Не то';
      btn.title = 'Научить Амиго другому ответу';
      btn.addEventListener('click', () => this.teachFix(meta.phrase));
      parts.push(btn);
    }
    if (!parts.length) return null;
    const m = document.createElement('div'); m.className = 'meta';
    parts.forEach(p => m.appendChild(p));
    return m;
  }
  teachFix(phrase) {
    const text = this.brain.startTeach(phrase);
    this.addMsg('bot', text, { src: 'rule' });
    this.brain.history.push({ role: 'assistant', content: text });
    this.chips(['Отмена']);
    this.mood('learn', 2000);
    this.input.focus();
  }
  showTyping() {
    const w = document.createElement('div'); w.className = 'msg bot typing';
    w.innerHTML = '<div class="bubble" aria-label="Амиго печатает"><i></i><i></i><i></i></div>';
    this.logEl.appendChild(w); this.scroll();
    return w;
  }
  scroll(force) {
    const l = this.logEl;
    requestAnimationFrame(() => { l.scrollTop = l.scrollHeight; });
  }
  autosize() { const t = this.input; t.style.height = 'auto'; t.style.height = Math.min(t.scrollHeight, 140) + 'px'; }
  saveChat() { U.store.set(CHAT_KEY, this.log.slice(-80)); }
  clearChat() { this.log = []; this.logEl.innerHTML = ''; this.saveChat(); this.brain.history = []; }

  chips(list) {
    const box = this.el('chips');
    box.innerHTML = '';
    const items = list && list.length ? list : U.shuffle(DEFAULT_CHIPS.slice()).slice(0, 4);
    for (const c of items) {
      const b = document.createElement('button'); b.type = 'button'; b.className = 'chip'; b.textContent = c;
      b.addEventListener('click', () => {
        if (c === 'Показать мозг') return this.toggleBrain(true);
        if (c === 'Настройки') return this.openSettings(true);
        this.send(c);
      });
      box.appendChild(b);
    }
    box.scrollLeft = 0;
  }

  async send(raw) {
    const text = String(raw || '').trim();
    if (!text || this.busy) return;
    this.unlockAudio();
    this.input.value = ''; this.autosize();
    this.addMsg('me', text);
    this.busy = true; this.el('btnSend').disabled = true;
    this.setStatus('думаю…', true); this.mood('think');
    const typing = this.showTyping();
    let live = null;
    const io = {
      onThinking: k => this.setStatus(k === 'super' ? 'спрашиваю супер-мозг…' : k === 'wiki' ? 'ищу в Википедии…' : 'смотрю в интернете…', true),
      onStream: t => {
        if (!t) return;
        if (!live) { typing.remove(); live = this.addMsg('bot', t, {}, { live: true }); this.mood('think'); }
        else this.renderText(live.bubble, t);
        this.scroll();
      },
    };
    const t0 = Date.now();
    let a;
    try { a = await this.brain.reply(text, io); }
    catch (e) { a = { text: 'Ой, что-то сломалось 😵 Попробуй ещё раз.', src: 'rule' }; }
    if (!live) { const wait = 250 + Math.min(450, a.text.length * 3) - (Date.now() - t0); if (wait > 0) await new Promise(r => setTimeout(r, wait)); }
    typing.remove();
    const meta = { src: a.src, conf: a.conf, title: this.titleOf(a), link: a.link, phrase: text, unsure: a.unsure };
    if (live) live.remove();
    this.addMsg('bot', a.text, meta);
    this.busy = false; this.el('btnSend').disabled = false;
    this.setStatus();
    this.mood(a.mood || 'idle', 2600);
    this.chips(a.chips);
    this.apply(a.action);
    this.speak(a.text);
    this.showThought(text, a);
  }
  titleOf(a) {
    if (!a.intent) return '';
    const it = this.brain.byTag.get(a.intent);
    return it ? it.t : a.intent;
  }
  apply(act) {
    if (!act) return;
    if (act.type === 'timer') this.startTimer(act.sec, act.label);
    else if (act.type === 'timer_cancel') this.cancelTimers();
    else if (act.type === 'clear') { const last = this.log[this.log.length - 1]; this.clearChat(); if (last) this.addMsg('bot', last.text, last.meta); }
    else if (act.type === 'voice') this.setVoice(act.on, false);
    else if (act.type === 'dance') this.mood('dance', 3200);
    else if (act.type === 'learned') { this.renderTaught(); this.tune(); }
  }

  // ---------- статус и настроение ----------
  setStatus(text, busy) {
    const s = this.el('status');
    if (text) { s.textContent = text; s.classList.toggle('busy', !!busy); return; }
    if (this.tuning) { s.textContent = 'учусь новому…'; s.classList.add('busy'); return; }
    const net = this.brain.net;
    s.textContent = `нейросеть · ${net.C} ${U.plural(net.C, 'тема', 'темы', 'тем')}`;
    const more = document.createElement('span'); more.className = 'wide'; more.textContent = ` · ${Math.round(net.params / 1000)} тыс. параметров`;
    s.appendChild(more);
    s.classList.remove('busy');
  }
  mood(m, ms) {
    clearTimeout(this.moodT);
    this.avatar.dataset.mood = m;
    if (ms) this.moodT = setTimeout(() => { this.avatar.dataset.mood = 'idle'; }, ms);
  }

  // ---------- голос ----------
  setVoice(on, announce) {
    this.brain.settings.voice = !!on; this.brain.save();
    this.el('btnVoice').setAttribute('aria-pressed', on ? 'true' : 'false');
    const sv = this.el('setVoice'); if (sv) sv.checked = !!on;
    if (!on && 'speechSynthesis' in window) speechSynthesis.cancel();
    if (announce) this.toast(on ? 'Буду читать ответы вслух 🔊' : 'Голос выключен 🔇');
  }
  speak(text) {
    if (!this.brain.settings.voice || !('speechSynthesis' in window)) return;
    const plain = String(text).replace(/\*\*|`/g, '').replace(/[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]/gu, '').replace(/[•→]/g, ',').replace(/\s+/g, ' ').trim();
    if (!plain) return;
    try {
      speechSynthesis.cancel();
      const u = new SpeechSynthesisUtterance(plain);
      u.lang = 'ru-RU'; u.rate = this.brain.settings.rate || 1; u.pitch = 1.15;
      const v = speechSynthesis.getVoices().find(v => /^ru/i.test(v.lang));
      if (v) u.voice = v;
      u.onstart = () => this.avatar.classList.add('talk');
      u.onend = u.onerror = () => this.avatar.classList.remove('talk');
      speechSynthesis.speak(u);
    } catch (e) { /* речь недоступна */ }
  }
  initMic() {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    const btn = this.el('btnMic');
    if (!SR) return;
    btn.hidden = false;
    btn.addEventListener('click', () => {
      if (this.rec) { this.rec.stop(); return; }
      let rec;
      try { rec = new SR(); } catch (e) { btn.hidden = true; return; }
      rec.lang = 'ru-RU'; rec.interimResults = true; rec.maxAlternatives = 1;
      let finalText = '';
      rec.onresult = e => {
        let s = ''; finalText = '';
        for (const r of e.results) { s += r[0].transcript; if (r.isFinal) finalText += r[0].transcript; }
        this.input.value = s; this.autosize();
      };
      rec.onerror = e => {
        if (e.error === 'not-allowed' || e.error === 'service-not-allowed') { this.toast('Микрофон здесь недоступен. Можно писать текстом 🙂'); btn.hidden = true; }
        else if (e.error === 'no-speech') this.toast('Я ничего не услышал. Попробуй ещё раз!');
      };
      rec.onend = () => { this.rec = null; btn.classList.remove('listening'); const t = (finalText || this.input.value).trim(); if (t) this.send(t); };
      try { rec.start(); this.rec = rec; btn.classList.add('listening'); this.toast('Говори, я слушаю 👂'); } catch (e) { this.toast('Не получилось включить микрофон'); }
    });
  }

  // ---------- таймеры ----------
  unlockAudio() {
    try { if (!this.audio) { const AC = window.AudioContext || window.webkitAudioContext; if (AC) this.audio = new AC(); } if (this.audio && this.audio.state === 'suspended') this.audio.resume(); } catch (e) { /* без звука */ }
  }
  beep() {
    const ac = this.audio; if (!ac) return;
    try {
      [0, 0.25, 0.5].forEach((d, i) => {
        const o = ac.createOscillator(), g = ac.createGain();
        o.type = 'sine'; o.frequency.value = i === 2 ? 1046 : 784;
        g.gain.setValueAtTime(0.0001, ac.currentTime + d); g.gain.exponentialRampToValueAtTime(0.25, ac.currentTime + d + 0.02); g.gain.exponentialRampToValueAtTime(0.0001, ac.currentTime + d + 0.22);
        o.connect(g).connect(ac.destination); o.start(ac.currentTime + d); o.stop(ac.currentTime + d + 0.25);
      });
    } catch (e) { /* без звука */ }
  }
  startTimer(sec, label) {
    const t = { id: Date.now() + Math.random(), end: Date.now() + sec * 1000, label };
    this.timers.push(t);
    try { if ('Notification' in window && Notification.permission === 'default') Notification.requestPermission().catch(() => {}); } catch (e) { /* нет уведомлений */ }
    if (!this.timerTick) this.timerTick = setInterval(() => this.renderTimers(), 500);
    this.renderTimers();
  }
  cancelTimers() { this.timers = []; this.renderTimers(); }
  renderTimers() {
    const box = this.el('timers'), now = Date.now();
    for (const t of this.timers.filter(t => t.end <= now)) {
      this.timers = this.timers.filter(x => x !== t);
      const text = this.brain.timerDone(t.label);
      this.addMsg('bot', text, { src: 'skill' });
      this.brain.history.push({ role: 'assistant', content: text });
      this.beep(); this.mood('wow', 3000); this.speak(text);
      try { if ('Notification' in window && Notification.permission === 'granted' && document.hidden) new Notification('Амиго', { body: text.replace(/\*\*/g, '') }); } catch (e) { /* нет уведомлений */ }
    }
    box.innerHTML = '';
    for (const t of this.timers) {
      const s = Math.max(0, Math.ceil((t.end - now) / 1000)), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
      const b = document.createElement('button'); b.type = 'button'; b.className = 'timer-pill';
      b.textContent = '⏱ ' + (h ? h + ':' + String(m).padStart(2, '0') : m) + ':' + String(sec).padStart(2, '0');
      b.title = 'Отменить таймер' + (t.label ? ': ' + t.label : '');
      b.addEventListener('click', () => { this.timers = this.timers.filter(x => x !== t); this.renderTimers(); this.toast('Таймер отменён'); });
      box.appendChild(b);
    }
    if (!this.timers.length && this.timerTick) { clearInterval(this.timerTick); this.timerTick = 0; }
  }

  // ---------- обучение ----------
  progress(on, frac, text) {
    this.el('trainProgress').hidden = !on;
    if (on) { this.el('trainBar').style.width = Math.round(frac * 100) + '%'; this.el('trainText').textContent = text; }
  }
  async tune() {
    if (this.tuning) { this.tuneAgain = true; return; }
    this.tuning = true; this.setStatus(); this.mood('learn');
    const E = 8;
    this.progress(true, 0, 'Дообучаюсь на твоих фразах…');
    try {
      await this.brain.fineTune({ epochs: E, tick: U.tick, onEpoch: r => this.progress(true, r.epoch / E, `Дообучение: эпоха ${r.epoch} из ${E}, точность ${Math.round(r.acc * 100)}%`) });
    } catch (e) { console.error(e); }
    this.tuning = false; this.progress(false);
    this.setStatus(); this.mood('happy', 1500);
    this.renderStats(); this.renderTaught();
    if (this.tuneAgain) { this.tuneAgain = false; this.tune(); }
  }
  async retrain() {
    if (this.tuning) return;
    const btn = this.el('btnRetrain');
    btn.disabled = true; this.tuning = true; this.setStatus(); this.mood('learn');
    const E = this.brain.model.epochs || 20, hist = [];
    this.lossHistory = hist;
    this.progress(true, 0, 'Готовлю примеры…');
    await U.tick();
    const t0 = Date.now();
    try {
      await this.brain.retrain({ tick: U.tick, yieldEvery: 12, onEpoch: r => { hist.push([r.loss, r.acc]); this.drawLoss(); this.progress(true, r.epoch / E, `Эпоха ${r.epoch} из ${E}: ошибка ${r.loss.toFixed(2)}, точность ${Math.round(r.acc * 100)}%`); } });
      this.toast(`Готово за ${Math.round((Date.now() - t0) / 1000)} с! Точность на обучении ${Math.round(hist[hist.length - 1][1] * 100)}%`);
    } catch (e) { console.error(e); this.toast('Не получилось переобучиться'); }
    this.tuning = false; btn.disabled = false; this.progress(false);
    this.setStatus(); this.mood('happy', 1500); this.renderStats(); this.drawLoss();
  }

  // ---------- панель «Мозг» ----------
  toggleBrain(open, remember = true) {
    const $ = this.el, b = $('brain');
    if (open == null) open = b.hidden;
    b.hidden = !open;
    $('app').classList.toggle('brain-open', open);
    $('btnBrain').setAttribute('aria-expanded', open ? 'true' : 'false');
    if (remember) { this.uiState.brain = open; U.store.set(UI_KEY, this.uiState); }
    if (open) requestAnimationFrame(() => this.drawAll());
  }
  drawAll() { if (this.el('brain').hidden) return; this.drawNet(this.lastCls); this.drawLoss(); }
  colors() {
    const cs = getComputedStyle(document.documentElement), v = n => cs.getPropertyValue(n).trim();
    return { ink: v('--ink'), muted: v('--muted'), line: v('--line'), coral: v('--coral'), teal: v('--teal'), accent: v('--accent'), surface: v('--surface'), s2: v('--surface-2'), mono: v('--f-mono') };
  }
  canvas(id) {
    const cv = this.el(id), dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = cv.clientWidth, h = cv.clientHeight;
    if (!w || !h) return null;
    if (cv.width !== Math.round(w * dpr) || cv.height !== Math.round(h * dpr)) { cv.width = Math.round(w * dpr); cv.height = Math.round(h * dpr); }
    const ctx = cv.getContext('2d'); ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.clearRect(0, 0, w, h);
    return { ctx, w, h };
  }
  showThought(text, a) {
    const cls = this.brain.lastCls;
    if (!cls || cls.text !== text) return;
    this.lastCls = cls;
    const said = this.el('said'), t0 = cls.top[0];
    const route = { claude: 'ответ дал супер-мозг Claude', wiki: 'ответ нашёлся в Википедии', memory: 'ответ из моей памяти', taught: 'ответ, которому ты меня научил', web: 'данные из интернета', skill: 'ответ построил навык', rule: 'сработало особое правило' }[a.src];
    said.textContent = '';
    const q = document.createElement('span'); q.textContent = `«${text.length > 60 ? text.slice(0, 59) + '…' : text}» → `;
    const b = document.createElement('b'); b.textContent = `${t0.title} (${Math.round(t0.p * 100)}%)`;
    said.append(q, b);
    if (route || a.unsure) said.append(document.createTextNode(a.unsure ? ' · я не уверен' : ' · ' + route));
    const bars = this.el('bars'); bars.innerHTML = '';
    for (const t of cls.top) {
      const li = document.createElement('li');
      li.innerHTML = '<span class="bar-label"></span><span class="bar-track"><span class="bar-fill"></span></span><span class="bar-val"></span>';
      li.children[0].textContent = t.title; li.children[0].title = t.title;
      li.children[2].textContent = Math.round(t.p * 100) + '%';
      bars.appendChild(li);
      requestAnimationFrame(() => { li.querySelector('.bar-fill').style.width = Math.max(1, t.p * 100) + '%'; });
    }
    this.animateNet(cls);
  }
  animateNet(cls) {
    if (this.el('brain').hidden) return;
    const reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduce) return this.drawNet(cls, 1);
    const t0 = performance.now(), dur = 900;
    cancelAnimationFrame(this.netAnim);
    const step = now => { const k = Math.min(1, (now - t0) / dur); this.drawNet(cls, k); if (k < 1) this.netAnim = requestAnimationFrame(step); };
    this.netAnim = requestAnimationFrame(step);
  }
  featLabel(key) {
    if (!key) return '?';
    const k = key.slice(2);
    if (key[0] === 'w') return k;
    if (key[0] === 'b') return k.replace(' ', '+');
    return k.replace('<', '‹').replace('>', '›');
  }
  drawNet(cls, k = 1) {
    const c = this.canvas('netCanvas'); if (!c) return;
    const { ctx, w, h } = c, col = this.colors(), net = this.brain.net, H = net.H, C = net.C;
    const font = sz => `${sz}px ${col.mono || 'monospace'}`;
    const xIn = w * 0.27, xHid = w * 0.46, xOut = w * 0.61, top = 30, bottom = h - 26;
    ctx.font = font(10); ctx.fillStyle = col.muted; ctx.textBaseline = 'middle';
    ctx.textAlign = 'right'; ctx.fillText('признаки', xIn + 4, 14);
    ctx.textAlign = 'center'; ctx.fillText('нейроны', xHid, 14);
    ctx.textAlign = 'left'; ctx.fillText('темы', xOut - 4, 14);
    const ys = (n, i) => n === 1 ? (top + bottom) / 2 : top + (bottom - top) * i / (n - 1);
    if (!cls) {
      ctx.strokeStyle = col.line; ctx.lineWidth = 1;
      const A = [7, 10, 5], X = [xIn, xHid, xOut];
      for (let l = 0; l < 2; l++) for (let i = 0; i < A[l]; i++) for (let j = 0; j < A[l + 1]; j++) { ctx.beginPath(); ctx.moveTo(X[l], ys(A[l], i)); ctx.lineTo(X[l + 1], ys(A[l + 1], j)); ctx.stroke(); }
      for (let l = 0; l < 3; l++) for (let i = 0; i < A[l]; i++) { ctx.beginPath(); ctx.arc(X[l], ys(A[l], i), 5, 0, 7); ctx.fillStyle = col.surface; ctx.fill(); ctx.strokeStyle = col.muted; ctx.stroke(); }
      return;
    }
    // самые важные признаки фразы
    const x = cls.x, feats = [];
    for (let i = 0; i < x.idx.length; i++) {
      const row = x.idx[i] * H; let n = 0;
      for (let j = 0; j < H; j++) n += Math.abs(net.W1[row + j]);
      feats.push({ i: x.idx[i], v: x.val[i], s: x.val[i] * n, key: x.keys ? x.keys.get(x.idx[i]) : '' });
    }
    feats.sort((a, b) => b.s - a.s);
    const F = feats.slice(0, 8);
    const hidOrder = Array.from(cls.hid.keys()).sort((a, b) => cls.hid[b] - cls.hid[a]).slice(0, 10);
    const maxHid = cls.hid[hidOrder[0]] || 1;
    const outs = cls.top.map(t => ({ t, c: this.brain.tags.indexOf(t.tag) })).filter(o => o.c >= 0);
    // связи
    const edges = [];
    F.forEach((f, a) => hidOrder.forEach((hh, b) => edges.push({ l: 0, a, b, w: net.W1[f.i * H + hh] * f.v })));
    hidOrder.forEach((hh, a) => outs.forEach((o, b) => edges.push({ l: 1, a, b, w: (o.c < C ? net.W2[hh * C + o.c] : 0) * cls.hid[hh] })));
    const mx = [0, 0]; for (const e of edges) mx[e.l] = Math.max(mx[e.l], Math.abs(e.w));
    for (const e of edges) {
      const prog = e.l === 0 ? Math.min(1, k * 2) : Math.max(0, k * 2 - 1);
      const s = Math.abs(e.w) / (mx[e.l] || 1);
      if (s < 0.06 || !prog) continue;
      const x1 = e.l ? xHid : xIn, y1 = e.l ? ys(hidOrder.length, e.a) : ys(F.length, e.a);
      const x2 = e.l ? xOut : xHid, y2 = e.l ? ys(outs.length, e.b) : ys(hidOrder.length, e.b);
      ctx.globalAlpha = Math.min(0.9, 0.12 + s * 0.8) * prog;
      ctx.strokeStyle = e.w > 0 ? col.coral : col.teal; ctx.lineWidth = 0.6 + s * 2.4;
      ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x1 + (x2 - x1) * prog, y1 + (y2 - y1) * prog); ctx.stroke();
    }
    ctx.globalAlpha = 1;
    // узлы и подписи
    const node = (cx, cy, r, fill, a) => { ctx.beginPath(); ctx.arc(cx, cy, r, 0, 7); ctx.fillStyle = col.surface; ctx.fill(); ctx.globalAlpha = a; ctx.fillStyle = fill; ctx.fill(); ctx.globalAlpha = 1; ctx.lineWidth = 1.2; ctx.strokeStyle = col.ink; ctx.stroke(); };
    const fit = (s, maxW) => { if (ctx.measureText(s).width <= maxW) return s; while (s.length > 1 && ctx.measureText(s + '…').width > maxW) s = s.slice(0, -1); return s + '…'; };
    ctx.font = font(11); ctx.textAlign = 'right';
    const fmax = F.length ? F[0].s : 1;
    F.forEach((f, i) => { const y = ys(F.length, i); node(xIn, y, 5, col.accent, 0.25 + 0.75 * f.s / fmax); ctx.fillStyle = col.ink; ctx.fillText(fit(this.featLabel(f.key), xIn - 14), xIn - 10, y); });
    hidOrder.forEach((hh, i) => { const y = ys(hidOrder.length, i); node(xHid, y, 4.5, col.coral, Math.max(0.08, cls.hid[hh] / maxHid) * Math.min(1, k * 2)); });
    ctx.textAlign = 'left';
    outs.forEach((o, i) => {
      const y = ys(outs.length, i), a = Math.max(0, k * 2 - 1);
      node(xOut, y, 4 + 6 * o.t.p, col.accent, (0.15 + 0.85 * o.t.p) * a + 0.05);
      ctx.fillStyle = i === 0 ? col.ink : col.muted; ctx.font = font(i === 0 ? 11.5 : 11);
      const pct = Math.round(o.t.p * 100) + '%';
      const room = w - (xOut + 14) - 4 - ctx.measureText(' ' + pct).width;
      ctx.fillText(fit(o.t.title, room) + ' ' + pct, xOut + 14, y);
    });
    ctx.fillStyle = col.muted; ctx.font = font(9.5); ctx.textAlign = 'center';
    ctx.fillText(`${hidOrder.length} из ${H}`, xHid, h - 10);
  }
  drawLoss() {
    const c = this.canvas('lossCanvas'); if (!c) return;
    const { ctx, w, h } = c, col = this.colors(), H = this.lossHistory;
    const l = 10, r = w - 46, t = 12, b = h - 22;
    ctx.strokeStyle = col.line; ctx.lineWidth = 1; ctx.font = `10px ${col.mono || 'monospace'}`; ctx.fillStyle = col.muted; ctx.textBaseline = 'middle';
    for (let i = 0; i <= 4; i++) { const y = t + (b - t) * i / 4; ctx.beginPath(); ctx.moveTo(l, y); ctx.lineTo(r, y); ctx.stroke(); }
    ctx.textAlign = 'left'; ctx.fillText('100%', r + 6, t); ctx.fillText('0', r + 6, b);
    const E = this.brain.model.epochs || H.length || 1;
    ctx.textAlign = 'left'; ctx.fillText('эпоха 1', l, h - 8); ctx.textAlign = 'right'; ctx.fillText('эпоха ' + E, r, h - 8);
    if (!H.length) return;
    const maxL = Math.max(...H.map(p => p[0])) || 1;
    const X = i => E === 1 ? l : l + (r - l) * i / (E - 1);
    const line = (get, color) => {
      ctx.strokeStyle = color; ctx.lineWidth = 2.2; ctx.lineJoin = 'round'; ctx.beginPath();
      H.forEach((p, i) => { const y = b - (b - t) * get(p); if (i) ctx.lineTo(X(i), y); else ctx.moveTo(X(i), y); });
      ctx.stroke();
      const i = H.length - 1, y = b - (b - t) * get(H[i]);
      ctx.fillStyle = color; ctx.beginPath(); ctx.arc(X(i), y, 3.5, 0, 7); ctx.fill();
    };
    line(p => p[0] / maxL, col.coral);
    line(p => p[1], col.teal);
    const last = H[H.length - 1];
    this.el('lossNote').textContent = `итог: ошибка ${last[0].toFixed(2)}, точность ${Math.round(last[1] * 100)}%`;
  }
  renderStats() {
    const m = this.brain.model, net = this.brain.net;
    const rows = [['Входов', U.num(net.D)], ['Скрытых нейронов', net.H], ['Тем (выходов)', net.C], ['Параметров', U.num(net.params)],
      ['Примеров для обучения', U.num(m.examples)], ['Точность на новых фразах', Math.round(m.val.acc * 100) + '%']];
    const dl = this.el('stats'); dl.innerHTML = '';
    for (const [k, v] of rows) { const d = document.createElement('div'); const dt = document.createElement('dt'); dt.textContent = k; const dd = document.createElement('dd'); dd.textContent = v; d.append(dt, dd); dl.appendChild(d); }
  }
  renderTaught() {
    const ul = this.el('taught'); ul.innerHTML = '';
    const list = this.brain.customs;
    if (!list.length) {
      const li = document.createElement('li'); li.className = 'empty';
      li.textContent = 'Пока ничего. Напиши «когда я говорю „привет, робот“, отвечай „бип-буп“» или нажми «Не то» под моим ответом.';
      ul.appendChild(li); return;
    }
    for (const c of list) {
      const li = document.createElement('li');
      const d = document.createElement('div');
      const q = document.createElement('div'); q.className = 'tq'; q.textContent = c.p.map(p => '«' + p + '»').join(', ');
      const a = document.createElement('div'); a.className = 'ta'; a.textContent = '→ ' + c.r[0];
      d.append(q, a);
      const btn = document.createElement('button'); btn.type = 'button'; btn.className = 'btn small'; btn.textContent = 'Забыть';
      btn.addEventListener('click', () => { this.brain.forgetCustom(c.tag); this.renderTaught(); this.setStatus(); this.toast('Забыл'); if (this.brain.needsTuning) this.tune(); });
      li.append(d, btn); ul.appendChild(li);
    }
  }

  // ---------- настройки ----------
  openSettings(open) {
    this.el('settings').hidden = !open; this.el('backdrop').hidden = !open;
    if (open) { this.renderSettings(); setTimeout(() => this.el('btnSetClose').focus(), 30); }
  }
  bindSettings() {
    const $ = this.el, S = this.brain.settings, save = () => { this.brain.save(); this.renderSettings(); };
    $('setVoice').addEventListener('change', e => this.setVoice(e.target.checked, false));
    $('setRate').addEventListener('input', e => { S.rate = +e.target.value; $('rateVal').textContent = S.rate.toFixed(1); this.brain.save(); });
    $('setOnline').addEventListener('change', e => { S.online = e.target.checked; save(); });
    $('setSuper').addEventListener('change', e => { S.superOn = e.target.checked; save(); });
    $('setTier').addEventListener('change', e => { S.superTier = e.target.value; save(); });
    $('setKey').addEventListener('change', e => { S.apiKey = e.target.value.trim(); save(); if (S.apiKey) this.toast('Ключ сохранён 🔑'); });
    $('setModel').addEventListener('change', e => { S.model = e.target.value; save(); });
    $('btnClear').addEventListener('click', () => { this.clearChat(); this.openSettings(false); this.greet(); this.toast('Чат очищен'); });
    $('btnForgetAll').addEventListener('click', e => {
      const b = e.currentTarget;
      if (!b.dataset.sure) { b.dataset.sure = '1'; b.textContent = 'Точно забыть? Нажми ещё раз'; setTimeout(() => { delete b.dataset.sure; b.textContent = 'Забыть всё обо мне'; }, 4000); return; }
      delete b.dataset.sure; b.textContent = 'Забыть всё обо мне';
      this.brain.profile = { name: '', facts: [], city: null, age: 0 };
      this.brain.customs = []; this.brain.reset(); this.brain.save();
      this.clearChat(); this.renderTaught(); this.renderStats(); this.setStatus(); this.openSettings(false); this.greet();
      this.toast('Я всё забыл. Будем знакомиться заново!');
    });
  }
  renderSettings() {
    const $ = this.el, S = this.brain.settings, Sup = Online.Super;
    $('setVoice').checked = !!S.voice; $('setRate').value = S.rate || 1; $('rateVal').textContent = (S.rate || 1).toFixed(1);
    $('setOnline').checked = S.online !== false; $('setSuper').checked = !!S.superOn; $('setTier').value = S.superTier || 'quick';
    $('setKey').value = S.apiKey || ''; $('setModel').value = S.model || 'claude-opus-5-5';
    const inClaude = Sup.sampleState === 'ready';
    $('superSample').hidden = !inClaude; $('superApi').hidden = inClaude;
    $('superHint').textContent = inClaude
      ? 'Я открыт внутри Claude и могу сам спрашивать Claude о том, чего не знаю. Первый раз Claude попросит разрешение. Ответы тратят лимит твоего аккаунта Claude.'
      : Sup.sampleState === 'unknown' ? 'Проверяю, доступен ли Claude…'
        : 'Вставь ключ Anthropic API, и я буду спрашивать Claude о том, чего не знаю сам. Без ключа я всё равно работаю: у меня своя нейросеть.';
    const mode = Sup.mode(S);
    $('superBadge').textContent = mode ? 'включён' : S.superOn && !inClaude && !S.apiKey ? 'нужен ключ' : 'выключен';
  }
  toast(text) {
    const t = this.el('toast');
    t.textContent = text; t.hidden = false;
    clearTimeout(this.toastT); this.toastT = setTimeout(() => { t.hidden = true; }, 2600);
  }
}
