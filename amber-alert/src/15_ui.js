/* ================= ИНТЕРФЕЙС: меню, подключение, HUD, оповещение, магазин, итоги ================= */
const CSS2 = `
#ui .center{align-items:center;justify-content:center}
.menu{position:absolute;left:4vw;top:50%;transform:translateY(-50%);width:min(420px,92vw);max-height:94vh;overflow:auto}
.logo{font:900 54px/0.95 "Arial Black",Impact,Arial,sans-serif;letter-spacing:1px;text-shadow:0 0 24px rgba(255,176,0,.35),0 4px 0 #000}
.logo b{color:var(--amber)}.logo i{font-style:normal;color:#fff}
.sub{font-weight:700;color:var(--dim);margin:6px 0 16px;letter-spacing:.5px;font-size:13px}
.stat{display:flex;gap:10px;margin:8px 0 14px;flex-wrap:wrap}.chip{background:rgba(255,255,255,.07);border:1px solid var(--line);border-radius:999px;padding:6px 12px;font-weight:800;font-size:13px}
.chip.amber{color:var(--amber);border-color:rgba(255,176,0,.4)}
.btns{display:flex;flex-direction:column;gap:9px}
.modal{position:absolute;inset:0;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;pointer-events:auto;z-index:20}
.modal .panel{width:min(640px,94vw);max-height:90vh;overflow:auto}
.ptitle{display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;gap:10px}
.ptitle h2{font:900 22px "Arial Black",Arial;letter-spacing:.5px}
.x{width:40px;height:40px;padding:0;font-size:18px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:10px}
.card{background:rgba(255,255,255,.05);border:2px solid var(--line);border-radius:12px;padding:12px;display:flex;flex-direction:column;gap:6px}
.card .t{font-weight:900}.card .d{font-size:12px;color:var(--dim);flex:1}.card .p{font-weight:900;color:var(--amber)}
.card.sel{border-color:var(--amber);background:rgba(255,176,0,.08)}
.code{font:900 44px/1 "Consolas",monospace;letter-spacing:8px;color:var(--amber);text-align:center;padding:10px;background:#0b0d12;border-radius:12px;border:2px dashed rgba(255,176,0,.5)}
.tabs{display:flex;gap:6px;margin-bottom:12px;flex-wrap:wrap}.tabs button{flex:1;padding:10px 8px;font-size:12px}.tabs button.on{background:var(--amber);color:#1a1000}
.swatch{width:30px;height:30px;border-radius:8px;border:2px solid rgba(255,255,255,.2);cursor:pointer;pointer-events:auto}.swatch.on{border-color:#fff;box-shadow:0 0 0 2px var(--amber)}
.wrap{display:flex;flex-wrap:wrap;gap:6px}
/* HUD */
.vp{position:absolute;overflow:hidden;pointer-events:none}
.cross{position:absolute;left:50%;top:50%;width:6px;height:6px;margin:-3px 0 0 -3px;border-radius:50%;background:rgba(255,255,255,.85);box-shadow:0 0 0 2px rgba(0,0,0,.4)}
.cross.on{width:12px;height:12px;margin:-6px 0 0 -6px;background:var(--amber)}
.prompt{position:absolute;left:50%;top:calc(50% + 26px);transform:translateX(-50%);background:rgba(0,0,0,.72);border:1px solid var(--line);padding:7px 12px;border-radius:10px;font-weight:800;font-size:14px;white-space:nowrap}
.prompt kbd{background:var(--amber);color:#000;border-radius:5px;padding:1px 7px;margin-right:6px;font:900 13px Arial}
.hold{position:absolute;left:0;bottom:0;height:3px;background:var(--amber)}
.clock{position:absolute;left:50%;top:10px;transform:translateX(-50%);text-align:center;text-shadow:0 2px 0 #000}
.clock .n{font:900 26px "Arial Black",Impact,Arial;letter-spacing:2px}.clock .tm{font:800 15px Consolas,monospace;color:#cfd6e2}
.clock.night .n{color:#ff4a4a;text-shadow:0 0 12px rgba(255,0,0,.5),0 2px 0 #000}
.wallet{position:absolute;right:12px;top:10px;display:flex;gap:8px}
.wallet .chip{background:rgba(0,0,0,.6)}
.bars{position:absolute;left:50%;bottom:88px;transform:translateX(-50%);width:min(260px,60%);display:flex;flex-direction:column;gap:5px}
.bar{height:6px;background:rgba(0,0,0,.6);border-radius:4px;overflow:hidden;border:1px solid rgba(255,255,255,.15)}.bar i{display:block;height:100%;background:#fff}
.hotbar{position:absolute;left:50%;bottom:16px;transform:translateX(-50%);display:flex;gap:6px}
.slot{width:58px;height:58px;border-radius:9px;background:rgba(20,22,26,.72);border:2px solid rgba(255,255,255,.18);position:relative;display:flex;align-items:center;justify-content:center;font-size:26px;pointer-events:auto}
.slot.on{border-color:#fff;box-shadow:0 0 0 2px var(--amber)}.slot .k{position:absolute;left:4px;top:2px;font:800 11px Arial;color:#ddd}.slot .c{position:absolute;right:4px;bottom:2px;font:900 12px Arial}
.qte{position:absolute;left:50%;top:40%;transform:translate(-50%,-50%);text-align:center;font:900 26px "Arial Black",Arial;color:#ff4a4a;text-shadow:0 0 14px #f00}
.dead{position:absolute;left:0;right:0;top:34%;text-align:center;font:900 30px "Arial Black",Arial;color:#ff3a3a;text-shadow:0 3px 0 #000}
.dead small{display:block;font:700 15px Arial;color:#ddd;margin-top:8px}
.flash{position:absolute;inset:0;pointer-events:none;opacity:0;transition:opacity .25s}
.hide-vig{position:absolute;inset:0;background:linear-gradient(90deg,#000 0 14%,transparent 30% 70%,#000 86%);opacity:.9}
.hide-vig::after{content:"";position:absolute;inset:0;background:repeating-linear-gradient(90deg,rgba(0,0,0,.85) 0 3%,transparent 3% 9%)}
.plist{position:absolute;left:10px;top:10px;display:flex;flex-direction:column;gap:4px;font-weight:800;font-size:13px}
.plist div{background:rgba(0,0,0,.55);padding:4px 10px;border-radius:8px;border-left:4px solid var(--ok)}.plist div.pdead{border-left-color:#e33;color:#f88}
.roomcode{background:rgba(255,176,0,.15);border:1px solid rgba(255,176,0,.5);color:var(--amber);padding:5px 10px;border-radius:8px;font:900 14px Consolas,monospace;pointer-events:auto;cursor:pointer}
.alertbox{position:absolute;right:12px;top:58px;width:min(300px,40vw);background:rgba(10,0,0,.7);border:2px solid #c4121a;border-radius:10px;padding:8px 10px;font-size:12px;font-weight:700}
.alertbox b{color:#ff5a5a;display:block;margin-bottom:3px;font-size:13px}.alertbox .dir{display:block;margin-top:6px;padding-top:5px;border-top:1px solid #c4121a88;color:#ffb000;font-size:12px}
#tvon{position:fixed;inset:0;z-index:40;pointer-events:none;background:#000;opacity:0;display:flex;align-items:center;justify-content:center}#tvon i{display:block;width:100%;height:2px;background:#fff;box-shadow:0 0 18px #fff}
#tvon.go{animation:tvbg 1.1s ease-out forwards}#tvon.go i{animation:tvline 1.1s ease-out forwards}
@keyframes tvbg{0%{opacity:1}55%{opacity:1}100%{opacity:0}}@keyframes tvline{0%{transform:scaleX(0);height:2px}35%{transform:scaleX(1);height:2px}60%{height:100%;opacity:.9}100%{height:100%;opacity:0}}
.statm{position:absolute;left:50%;bottom:58px;transform:translateX(-50%);display:flex;align-items:center;gap:8px;font-size:11px;font-weight:900;color:#ddd;text-shadow:0 1px 2px #000}.statm div{width:120px;height:6px;background:#0008;border-radius:3px;overflow:hidden}.statm i{display:block;height:100%;width:0}
.statfx{position:absolute;inset:0;pointer-events:none;opacity:0;mix-blend-mode:screen;background:repeating-linear-gradient(0deg,#fff1 0 1px,transparent 1px 3px),radial-gradient(circle,transparent 40%,#8884 100%);animation:statj .12s steps(2) infinite}
@keyframes statj{0%{transform:translateY(0)}50%{transform:translateY(-2px)}100%{transform:translateY(1px)}}
#eas{position:absolute;inset:0;display:none;align-items:center;justify-content:center;pointer-events:auto;z-index:15;background:rgba(0,0,0,.45)}
#eas .tvx{width:min(820px,94vw);background:#05060a;border:3px solid #333;border-radius:14px;overflow:hidden;box-shadow:0 0 60px rgba(255,0,0,.25);position:relative}
#eas .hdr{background:#c4121a;color:#fff;font:900 clamp(16px,3.2vw,28px) "Arial Black",Arial;letter-spacing:2px;padding:12px 16px;text-align:center}
#eas .bd{padding:16px 20px;font:700 clamp(13px,2.2vw,18px)/1.45 Consolas,"Courier New",monospace;color:#f2f2f2;min-height:200px;max-height:52vh;overflow:auto;white-space:pre-wrap}
#eas .ft{background:var(--amber);color:#000;font:900 13px Arial;padding:8px 12px;display:flex;justify-content:space-between;align-items:center;gap:10px}
#eas .ft button{padding:8px 12px;font-size:12px;background:#000;color:var(--amber);border-color:#000}
#eas .scan{position:absolute;inset:0;pointer-events:none;background:repeating-linear-gradient(0deg,rgba(255,255,255,.04) 0 1px,transparent 1px 3px);animation:roll 6s linear infinite}
@keyframes roll{from{background-position:0 0}to{background-position:0 300px}}
.subt{position:absolute;left:50%;bottom:150px;transform:translateX(-50%);background:rgba(0,0,0,.7);padding:6px 14px;border-radius:8px;font:900 18px Arial;color:#ff6a6a;pointer-events:none;text-align:center}
.chatlog{position:absolute;left:10px;bottom:170px;width:min(360px,70vw);display:flex;flex-direction:column;gap:3px;font-size:13px;font-weight:700;pointer-events:none}
.chatlog div{background:rgba(0,0,0,.5);padding:4px 8px;border-radius:6px;transition:opacity 1s}
.chatin{position:absolute;left:10px;bottom:130px;width:min(360px,70vw);pointer-events:auto}
.jump{position:absolute;inset:0;background:radial-gradient(circle,rgba(255,0,0,.0) 30%,rgba(120,0,0,.85));pointer-events:none;animation:jsh .08s infinite}
@keyframes jsh{0%{transform:translate(3px,-2px)}50%{transform:translate(-4px,3px)}100%{transform:translate(2px,2px)}}
.results{text-align:center}.results h1{font:900 44px "Arial Black",Impact,Arial;margin-bottom:6px}
.results .big{font:900 22px Arial;margin:6px 0}
.help td{padding:4px 10px 4px 0;font-size:14px}.help td:first-child{font-weight:900;color:var(--amber);white-space:nowrap}
.dossier{display:flex;gap:16px}.dossier .num{font:900 54px Consolas,monospace;color:var(--amber)}
.lobbyhint{position:absolute;left:50%;bottom:16px;transform:translateX(-50%);background:rgba(0,0,0,.6);padding:8px 14px;border-radius:10px;font-weight:800;font-size:13px;text-align:center}
.boothbig{position:absolute;left:50%;top:30%;transform:translateX(-50%);font:900 48px "Arial Black",Arial;color:var(--amber);text-shadow:0 4px 0 #000}
.rotate{position:fixed;inset:0;background:#05060a;z-index:50;display:none;align-items:center;justify-content:center;text-align:center;font:900 22px Arial;padding:30px}
@media (orientation:portrait) and (pointer:coarse){.rotate.need{display:flex}}
`;
const UI = {
  modal: null, scr: 'menu', vps: [], toastT: 0, chatOpen: false, eas: null, alertSummary: null,
  init() {
    document.head.append(el('style', { html: CSS2 }));
    const ui = $('#ui');
    ui.append(this.menuEl = el('div', { class: 'scr', id: 's-menu' }), this.playEl = el('div', { class: 'scr', id: 's-play', style: { pointerEvents: 'none' } }));
    ui.append(this.easEl = el('div', { id: 'eas' }));
    document.body.append(this.toastEl = el('div', { class: 'toast', style: { opacity: 0 } }), this.rotEl = el('div', { class: 'rotate' + (IS_TOUCH ? ' need' : '') }, 'Поверни телефон горизонтально 📱↻'));
    this.buildMenu();
  },
  show(s) { this.scr = s; this.menuEl.classList.toggle('on', s === 'menu'); this.playEl.classList.toggle('on', s === 'play'); if (s === 'menu') this.buildMenu(); if (s === 'play') this.buildHUD(); },
  toast(t, ms = 2600) { const e = this.toastEl; e.textContent = t; e.style.opacity = 1; clearTimeout(this.toastT); this.toastT = setTimeout(() => e.style.opacity = 0, ms); },
  closeModal() { if (this.modal) { this.modal.remove(); this.modal = null; } },
  openModal(title, body, o = {}) {
    this.closeModal(); if (document.pointerLockElement) document.exitPointerLock();
    const m = el('div', { class: 'modal', onpointerdown: e => { if (e.target === m && !o.sticky) this.closeModal(); } });
    const p = el('div', { class: 'panel' }, el('div', { class: 'ptitle' }, el('h2', {}, title), o.sticky ? null : el('button', { class: 'x ghost', onclick: () => this.closeModal() }, '✕')), body);
    m.append(p); $('#ui').append(m); this.modal = m; return m;
  },

  /* ======== главное меню ======== */
  buildMenu() {
    const P = MAINPROF, lvl = levelOf(P.xp);
    this.menuEl.innerHTML = '';
    const name = el('input', { value: P.name || '', placeholder: 'Твоё имя', maxlength: 16, oninput: e => { P.name = e.target.value.trim().slice(0, 16); saveProfile(P); } });
    const b = (txt, cls, fn) => el('button', { class: cls, onclick: () => { AU.init(); AU.play('ui'); fn(); } }, txt);
    const panel = el('div', { class: 'panel menu' },
      el('div', { class: 'logo', html: '<b>AMBER</b><br><i>ALERT</i>' }),
      el('div', { class: 'sub' }, 'фан-ремейк хоррора из Roblox · 3D · можно с другом'),
      el('div', { class: 'stat' }, el('span', { class: 'chip amber' }, '◆ ' + P.amber + ' Amber'), el('span', { class: 'chip' }, 'Ур. ' + lvl + ' · ' + rankOf(lvl)), el('span', { class: 'chip' }, 'Рекорд: ' + P.best + ' ноч.')),
      el('div', { class: 'col' }, name),
      el('div', { class: 'btns', style: { marginTop: '12px' } },
        b('▶ Играть одному', 'amber', () => this.startSolo()),
        b('🌐 Играть с другом (онлайн)', 'green', () => this.onlineMenu()),
        b('🎮 Вдвоём на одном экране', '', () => this.splitMenu()),
        b('🧍 Аватар', '', () => this.avatarEditor(P, 'aa_profile')),
        b('⚙ Настройки', 'ghost', () => this.settings()),
        b('❔ Как играть', 'ghost', () => this.help())),
      el('div', { class: 'sub', style: { marginTop: '14px', marginBottom: 0, fontSize: '11px' } }, 'Фан-игра по мотивам Amber Alert (TEZ Studios). Не связана с Roblox или авторами.'));
    this.menuEl.append(panel);
  },
  needName() { if (!MAINPROF.name) { MAINPROF.name = 'Игрок' + ((Math.random() * 900 + 100) | 0); saveProfile(MAINPROF); } },
  p1src() { return IS_TOUCH ? new Touch(this.touchZone(0)) : new KBMouse(BIND.p1, true); },
  touchZone(i, n = 1) { const z = el('div', { class: 'tzone' }); if (n > 1) Object.assign(z.style, i === 0 ? { right: '50%' } : { left: '50%' }); $('#ui').append(z); (this.zones = this.zones || []).push(z); return z; },
  clearZones() { (this.zones || []).forEach(z => z.remove()); this.zones = []; },
  startSolo() { this.needName(); this.clearZones(); GAME.begin('solo', null, [{ id: 'h1', src: this.p1src(), prof: MAINPROF, profKey: 'aa_profile' }]); this.lockHint(); },
  startHostWith(t, code) { this.needName(); this.clearZones(); NET.code = code || ''; GAME.begin('host', t, [{ id: 'h1', src: this.p1src(), prof: MAINPROF, profKey: 'aa_profile' }]); this.lockHint(); },
  startClientWith(t) { this.needName(); this.clearZones(); const id = 'c' + makeRoomCode(); GAME.begin('client', t, [{ id, src: this.p1src(), prof: MAINPROF, profKey: 'aa_profile' }]); this.lockHint(); },
  lockHint() { if (!IS_TOUCH) this.toast('Кликни по экрану, чтобы управлять мышью. Esc — меню', 3500); },

  /* ---- онлайн ---- */
  onlineMenu() {
    const st = el('div', { class: 'muted', style: { minHeight: '20px', fontWeight: 700 } });
    const body = el('div', { class: 'col' });
    const tabs = el('div', { class: 'tabs' });
    const views = {
      host: () => { body.innerHTML = ''; const go = el('button', { class: 'amber' }, '🏠 Создать комнату'); body.append(el('div', { class: 'muted' }, 'Ты станешь хостом. Друг вводит код комнаты у себя — и вы оба в одном лобби. Нужен интернет у обоих.'), go, st);
        go.onclick = async () => { go.disabled = true; st.textContent = 'Создаём комнату…'; let tries = 0; while (tries++ < 4) { const code = makeRoomCode(), t = new PeerTransport(); try { await t.host(code); this.closeModal(); this.startHostWith(t, code); this.toast('Комната ' + code + ' создана! Скажи код другу', 6000); return; } catch (e) { t.close(); if (e.type !== 'unavailable-id') { st.textContent = netErrorText(e); go.disabled = false; return; } } } st.textContent = 'Не удалось создать комнату'; go.disabled = false; }; },
      join: () => { body.innerHTML = ''; const inp = el('input', { placeholder: 'КОД КОМНАТЫ', maxlength: 5, style: { textTransform: 'uppercase', fontSize: '26px', letterSpacing: '6px', textAlign: 'center', fontWeight: 900 } }); const go = el('button', { class: 'green' }, '🚪 Войти');
        body.append(el('div', { class: 'muted' }, 'Введи 5-значный код, который показал друг (он виден у него в левом верхнем углу).'), inp, go, st);
        go.onclick = async () => { const code = inp.value.trim().toUpperCase(); if (code.length < 4) { st.textContent = 'Введи код'; return; } go.disabled = true; st.textContent = 'Подключаемся…'; const t = new PeerTransport(); try { await t.join(code); this.closeModal(); NET.code = code; this.startClientWith(t); } catch (e) { t.close(); st.textContent = netErrorText(e); go.disabled = false; } }; },
      manual: () => { body.innerHTML = '';
        const a = el('textarea', { rows: 4, placeholder: 'Сюда вставь код-приглашение от друга' }), out = el('textarea', { rows: 4, readonly: '' }), b1 = el('button', { class: 'green' }, 'Получить ответный код'), cp = el('button', { class: 'ghost' }, '📋 Скопировать ответ');
        body.append(el('div', { class: 'muted' }, 'Если онлайн-комнаты не работают: друг (хост) в меню паузы нажимает «Пригласить без сервера» и присылает тебе код. Ты вставляешь его сюда и отправляешь другу ответный код.'), a, b1, out, cp, st);
        b1.onclick = async () => { st.textContent = 'Создаём ответ… (до 5 сек)'; const t = new ManualTransport(); try { const ans = await t.answer(a.value, () => { this.closeModal(); this.startClientWith(t); }); out.value = ans; st.textContent = 'Отправь этот код другу и подожди подключения…'; } catch (e) { st.textContent = netErrorText(e); } };
        cp.onclick = () => copyText(out.value); },
    };
    for (const [k, label] of [['host', 'Создать комнату'], ['join', 'Войти по коду'], ['manual', 'Без сервера']]) { const bt = el('button', { onclick: () => { $$('.tabs button').forEach(x => x.classList.remove('on')); bt.classList.add('on'); st.textContent = ''; views[k](); } }, label); tabs.append(bt); }
    this.openModal('Игра с другом', el('div', {}, tabs, body));
    tabs.firstChild.click();
  },
  splitMenu() {
    const body = el('div', { class: 'col' },
      el('div', { class: 'muted' }, 'Два игрока на одном устройстве — экран делится пополам.'),
      el('button', { class: 'amber', onclick: () => go('kb') }, '⌨ Игрок 2 на клавиатуре (IJKL + стрелки)'),
      el('button', { class: '', onclick: () => go('pad') }, '🎮 Игрок 2 на геймпаде'),
      IS_TOUCH ? el('button', { class: 'green', onclick: () => go('touch') }, '📱 Вдвоём на сенсорном экране') : null,
      el('table', { class: 'help', html: '<tr><td>Игрок 1</td><td>WASD, мышь, E, F, Shift, C, G/ЛКМ — предмет</td></tr><tr><td>Игрок 2 (клав.)</td><td>IJKL — ходить, стрелки — смотреть, O — действие, P — фонарь, Правый Shift — бег, N — присесть, ; — предмет</td></tr>' }));
    const go = kind => { this.closeModal(); this.needName(); this.clearZones(); const P2 = loadProfile('aa_profile2'); if (!P2.name) { P2.name = 'Игрок 2'; saveProfile(P2, 'aa_profile2'); }
      let s1, s2; if (kind === 'touch') { s1 = new Touch(this.touchZone(0, 2)); s2 = new Touch(this.touchZone(1, 2)); } else { s1 = IS_TOUCH ? new Touch(this.touchZone(0)) : new KBMouse(BIND.p1, true); s2 = kind === 'pad' ? new Pad(0) : new KBMouse(BIND.p2, false); }
      GAME.begin('solo', null, [{ id: 'h1', src: s1, prof: MAINPROF, profKey: 'aa_profile' }, { id: 'h2', src: s2, prof: P2, profKey: 'aa_profile2' }]); this.lockHint(); };
    this.openModal('Вдвоём на одном экране', body);
  },
  /* ---- аватар ---- */
  avatarEditor(P, key) {
    const look = P.look, body = el('div', { class: 'col' });
    const prev = el('canvas', { width: 220, height: 260, style: { background: '#0b0d12', borderRadius: '12px', alignSelf: 'center' } });
    const row = (label, arr, field, isColor = true) => { const w = el('div', { class: 'wrap' }); arr.forEach((v, i) => { const s = isColor ? el('div', { class: 'swatch' + (look[field] === i ? ' on' : ''), style: { background: v } }) : el('button', { class: 'ghost' + (look[field] === v ? ' amber' : ''), style: { padding: '8px 10px', fontSize: '12px' } }, HAT_NAMES[v] || FACE_NAMES[v] || v); s.onclick = () => { look[field] = isColor ? i : v; saveProfile(P, key); this.avatarEditor(P, key); }; w.append(s); }); return el('div', {}, el('div', { class: 'muted', style: { fontWeight: 800, margin: '6px 0' } }, label), w); };
    const owned = h => !HAT_PRICE[h] || (P.skins || []).includes(h);
    body.append(prev, row('Кожа', SKINS, 'skin'), row('Футболка', SHIRTS, 'shirt'), row('Штаны', PANTS, 'pants'), row('Лицо', FACES, 'face', false));
    const hw = el('div', { class: 'wrap' }); HATS.forEach(h => { const ok = owned(h); const bt = el('button', { class: (look.hat === h ? 'amber' : 'ghost'), style: { padding: '8px 10px', fontSize: '12px' } }, HAT_NAMES[h] + (ok ? '' : ' · ' + HAT_PRICE[h] + '◆')); bt.onclick = () => { if (!ok) { if (P.amber < HAT_PRICE[h]) { this.toast('Не хватает Amber'); return; } P.amber -= HAT_PRICE[h]; (P.skins = P.skins || []).push(h); AU.play('coin'); } look.hat = h; saveProfile(P, key); this.avatarEditor(P, key); }; hw.append(bt); });
    body.append(el('div', {}, el('div', { class: 'muted', style: { fontWeight: 800, margin: '6px 0' } }, 'Головной убор (◆ — за Amber)'), hw));
    const cw = el('div', { class: 'wrap' }); SHIRTS.forEach(c => { const s = el('div', { class: 'swatch' + (look.hatColor === c ? ' on' : ''), style: { background: c } }); s.onclick = () => { look.hatColor = c; saveProfile(P, key); this.avatarEditor(P, key); }; cw.append(s); }); body.append(el('div', {}, el('div', { class: 'muted', style: { fontWeight: 800, margin: '6px 0' } }, 'Цвет шапки'), cw));
    this.openModal('Аватар · ◆ ' + P.amber, body);
    renderAvatarPreview(prev, look);
    if (GAME.scene !== 'menu') for (const lp of LOCALS) if (lp.prof === P) { lp.look = look; lp.avatar.setLook(look); NET.toHost({ t: 'look', pid: lp.id, look, cls: P.cls, name: P.name }); }
  },
  settings() {
    const S = SETTINGS, body = el('div', { class: 'col' });
    const rng = (label, val, min, max, step, fn) => { const v = el('b', {}, String(val)); const r = el('input', { type: 'range', min, max, step, value: val, style: { padding: 0 }, oninput: e => { v.textContent = e.target.value; fn(+e.target.value); saveSettings(); } }); return el('div', {}, el('div', { class: 'row', style: { justifyContent: 'space-between', fontWeight: 800 } }, label, v), r); };
    body.append(rng('Громкость', S.volume, 0, 1, .05, v => AU.setVol(v)), rng('Чувствительность мыши', S.mouseSens, .3, 3, .1, v => { S.mouseSens = v; MOUSE_SENS = .0024 * v; }), rng('Чувствительность пальца', S.touchSens, .3, 3, .1, v => S.touchSens = v));
    const q = el('button', { class: 'ghost', onclick: () => { S.quality = S.quality === 'low' ? 'high' : 'low'; saveSettings(); q.textContent = 'Графика: ' + (S.quality === 'low' ? 'быстрая (нужен перезапуск)' : 'красивая (нужен перезапуск)'); } }, 'Графика: ' + (S.quality === 'low' ? 'быстрая' : 'красивая'));
    const tts = el('button', { class: 'ghost', onclick: () => { S.tts = S.tts === false ? true : false; saveSettings(); tts.textContent = 'Голос диктора: ' + (S.tts === false ? 'выкл' : 'вкл'); } }, 'Голос диктора: ' + (S.tts === false ? 'выкл' : 'вкл'));
    const dir = el('button', { class: 'ghost', onclick: () => { S.directives = S.directives === false ? true : false; saveSettings(); dir.textContent = 'Директивы ТВ и Телеведущий: ' + (S.directives === false ? 'выкл («дружелюбный свет»)' : 'вкл'); } }, 'Директивы ТВ и Телеведущий: ' + (S.directives === false ? 'выкл («дружелюбный свет»)' : 'вкл'));
    body.append(q, tts, dir, el('div', { class: 'muted' }, 'Директивы действуют у хоста: если хост их выключил, они выключены у всех.')); this.openModal('Настройки', body);
  },
  help() {
    this.openModal('Как играть', el('div', { class: 'col' },
      el('div', { html: '<b>Цель:</b> пережить все ночи. <b>Днём</b> (7:00–21:00) собирай яблоки во дворе и продавай Яблочнику в гараже, покупай вещи. <b>В 21:00</b> телевизор в гостиной включает экстренное оповещение — оно описывает сбежавшего заключённого и говорит, <b>что делать</b>. Слушайся! <b>Ночью</b> он вламывается в дом через дверь или окно. Прячься в шкафах, выключай свет, запирай двери (держи E) или стреляй из дробовика. Погибших товарищей оживляет рассвет или дефибриллятор. <b>Директива</b> из оповещения (внизу справа) проверяется всю ночь: за неподчинение растут «помехи» 📺, и на 100% за тобой приходит неуязвимый <b>Телеведущий</b>. Чтобы он ушёл — слушайся директиву 15 секунд и не попадайся ему на глаза.' }),
      el('table', { class: 'help', html: '<tr><td>WASD / стик</td><td>ходить</td></tr><tr><td>Мышь / палец справа</td><td>смотреть</td></tr><tr><td>E / ✋</td><td>действие (держи E на двери — запереть)</td></tr><tr><td>F / 🔦</td><td>фонарик</td></tr><tr><td>Shift / 🏃</td><td>бег (шумно!)</td></tr><tr><td>C / ⬇</td><td>присесть (тихо)</td></tr><tr><td>Q / R / 👀</td><td>выглянуть из-за угла</td></tr><tr><td>1–9, колесо, X / 🔄</td><td>выбрать предмет</td></tr><tr><td>ЛКМ, G / 🎯</td><td>использовать предмет</td></tr><tr><td>Enter / T</td><td>чат</td></tr><tr><td>Esc</td><td>меню</td></tr>' })));
  },

  /* ======== HUD ======== */
  buildHUD() {
    this.playEl.innerHTML = ''; this.vps = [];
    LOCALS.forEach((lp, i) => {
      const v = el('div', { class: 'vp' });
      v.innerHTML = `<div class="hidebox"></div><div class="flash"></div><div class="cross"></div><div class="prompt" style="display:none"><span class="pt"></span><div class="hold"></div></div>
      <div class="clock"><div class="n"></div><div class="tm"></div></div><div class="wallet"></div><div class="bars"><div class="bar st"><i></i></div><div class="bar bt"><i style="background:#ffd860"></i></div></div><div class="hotbar"></div>
      <div class="qte" style="display:none">СОСРЕДОТОЧЬСЯ! <span class="qk"></span></div><div class="dead" style="display:none"></div><div class="js"></div>
      <div class="statfx"></div><div class="statm" style="display:none"><span>📺 ПОМЕХИ</span><div><i></i></div></div>`;
      this.playEl.append(v); this.vps.push({ el: v, lp, q: s => v.querySelector(s), last: {} });
    });
    this.playEl.append(this.plistEl = el('div', { class: 'plist' }), this.alertEl = el('div', { class: 'alertbox', style: { display: 'none' } }), this.subEl = el('div', { class: 'subt', style: { display: 'none' } }), this.chatEl = el('div', { class: 'chatlog' }), this.hintEl = el('div', { class: 'lobbyhint', style: { display: 'none' } }), this.bigEl = el('div', { class: 'boothbig', style: { display: 'none' } }));
    this.players(GAME.plist || []);
  },
  layoutVPs() { const vps = R.viewports(); this.vps.forEach((v, i) => { const r = vps[i] || vps[0]; Object.assign(v.el.style, { left: r[0] + 'px', top: (R.h - r[1] - r[3]) + 'px', width: r[2] + 'px', height: r[3] + 'px' }); }); },
  frame(dt) {
    if (this.scr !== 'play') return; this.layoutVPs();
    const st = GAME.st;
    for (const v of this.vps) {
      const lp = v.lp, info = lp.info || {}, q = v.q;
      // часы
      let n = '', tm = '', night = false;
      if (st.scene === 'lobby') { n = 'ЛОББИ'; tm = NET.role === 'host' && NET.code ? 'Код комнаты: ' + NET.code : NET.role === 'client' ? 'Онлайн' : 'Одиночная игра'; }
      else if (st.scene === 'house') { const c = (st.clock || 7) % 24, hh = Math.floor(c), mm = Math.floor((c % 1) * 60); tm = String(hh).padStart(2, '0') + ':' + String(mm).padStart(2, '0'); night = st.phase === 'night' || st.phase === 'alert'; n = (night ? 'НОЧЬ ' : 'ДЕНЬ ') + (st.night || 1) + (DIFFS[st.diff] && !DIFFS[st.diff].endless ? ' / ' + st.nights : ''); if (st.phase === 'dawn') n = 'РАССВЕТ'; if (st.phase === 'end') n = 'КОНЕЦ'; }
      if (v.last.n !== n) { q('.clock .n').textContent = n; v.last.n = n; } if (v.last.tm !== tm) { q('.clock .tm').textContent = tm; v.last.tm = tm; } q('.clock').classList.toggle('night', night);
      // кошелёк
      const w = st.scene === 'house' ? `<span class="chip amber">$${info.money || 0}</span><span class="chip">🍎 ${info.apples || 0}</span><span class="chip">❤ ${info.hp ?? 100}</span>` : `<span class="chip amber">◆ ${lp.prof ? lp.prof.amber : 0}</span><span class="chip">Ур. ${lp.prof ? levelOf(lp.prof.xp) : 0}</span>`;
      if (v.last.w !== w) { q('.wallet').innerHTML = w; v.last.w = w; }
      // подсказка взаимодействия
      const it = lp.focus, pr = q('.prompt'); let lab = it && it.label ? it.label() : '';
      if (it && it.cond && !it.cond(lp.id) && it.hold) lab = it.label();
      const alt = it && it.alt ? it.alt() : '';
      if (lab) { const key = lp.src instanceof Touch ? '✋' : lp.src instanceof Pad ? 'A' : lp.i === 1 ? 'O' : 'E'; const txt = `<kbd>${key}</kbd>${lab}${alt ? ' <span class="muted">· ' + alt + '</span>' : ''}`; if (v.last.pr !== txt) { q('.pt').innerHTML = txt; v.last.pr = txt; } pr.style.display = 'block'; const h = lp.holding ? lp.holding.t / (WORLD.inter.get(lp.holding.id).hold || .6) : lp.lockT > 0 ? lp.lockT / .7 : 0; q('.hold').style.width = (clamp(h, 0, 1) * 100) + '%'; } else pr.style.display = 'none';
      q('.cross').classList.toggle('on', !!lab); q('.cross').style.display = lp.alive && !lp.hidden ? 'block' : 'none';
      // полосы
      q('.st i').style.width = (lp.stamina * 100) + '%'; q('.st i').style.background = lp.stamina < .25 ? '#ff4a4a' : '#fff'; q('.bt i').style.width = (lp.battery * 100) + '%'; q('.bars').style.display = st.scene === 'house' && lp.alive ? 'flex' : 'none';
      // хотбар
      const items = info.items || []; const hb = items.map((s, i) => `${i}:${s.k}:${s.n}:${i === lp.slot}`).join('|');
      if (v.last.hb !== hb) { v.last.hb = hb; const H = q('.hotbar'); H.innerHTML = ''; items.forEach((s, i) => { const d = el('div', { class: 'slot' + (i === lp.slot ? ' on' : ''), onpointerdown: e => { e.stopPropagation(); lp.slot = i; } }, el('span', { class: 'k' }, String(i + 1)), ITEMS[s.k] ? ITEMS[s.k].icon : '?', el('span', { class: 'c' }, s.k === 'shotgun' ? s.n + '🧨' : s.n > 1 ? '×' + s.n : '')); H.append(d); }); }
      // укрытие и концентрация
      q('.hidebox').className = lp.hidden ? 'hidebox hide-vig' : 'hidebox';
      q('.qte').style.display = lp.qte ? 'block' : 'none'; if (lp.qte) q('.qk').textContent = '[' + (lp.src instanceof Touch ? '✋' : lp.i === 1 ? 'O' : 'E') + '] ' + '▮'.repeat(Math.max(0, Math.ceil((lp.qte.win - lp.qte.t) * 4)));
      // помехи (неподчинение директиве)
      const sv = st.scene === 'house' && lp.alive ? (info.stat || 0) : 0, sm = q('.statm'); sm.style.display = sv > 0 ? 'flex' : 'none';
      if (v.last.sv !== sv) { v.last.sv = sv; q('.statm i').style.width = sv + '%'; q('.statm i').style.background = sv >= 70 ? '#ff3a3a' : '#c8c8c8'; q('.statfx').style.opacity = Math.max(0, (sv - 30) / 100); }
      const dead = q('.dead'); if (!lp.alive && st.scene === 'house') { dead.style.display = 'block'; const tx = 'ТЫ ПОГИБ<small>Наблюдаешь за товарищами. Оживление — на рассвете или дефибриллятором.</small>'; if (v.last.dead !== tx) { dead.innerHTML = tx; v.last.dead = tx; } } else dead.style.display = 'none';
    }
    // подсказки лобби
    if (st.scene === 'lobby') { const b = st.booth || {}; this.hintEl.style.display = 'block'; const t = b.cd > 0 ? 'Старт через ' + Math.ceil(b.cd) + '…' : 'Подойди к киоскам, загляни в лечебницу или зайди в кабинку справа, чтобы начать' + (Object.keys(GAME.remotes).length ? ' (всей командой)' : ''); if (this.hintEl.textContent !== t) this.hintEl.textContent = t; this.bigEl.style.display = b.cd > 0 ? 'block' : 'none'; if (b.cd > 0) this.bigEl.textContent = Math.ceil(b.cd); }
    else { this.hintEl.style.display = 'none'; this.bigEl.style.display = 'none'; }
    this.alertEl.style.display = st.scene === 'house' && (st.phase === 'night') && this.alertSummary ? 'block' : 'none';
    // чат: угасание
    for (const d of this.chatEl.children) if (now() - d.t > 9) d.style.opacity = 0;
    if (this.chatEl.children.length > 7) this.chatEl.firstChild.remove();
  },
  players(list) { if (!this.plistEl) return; this.plistEl.innerHTML = ''; if (NET.role === 'host' && NET.code) { this.plistEl.append(el('div', { class: 'roomcode', onclick: () => copyText(NET.code) }, 'КОД: ' + NET.code + ' 📋')); if (/^https?:/.test(location.protocol)) this.plistEl.append(el('div', { class: 'roomcode', onclick: () => copyText(location.origin + location.pathname + '?room=' + NET.code) }, '🔗 Скопировать ссылку-приглашение')); } for (const p of list) this.plistEl.append(el('div', { class: p.alive ? '' : 'pdead' }, (p.alive ? '● ' : '✝ ') + p.name + (GAME.st.scene === 'house' ? '  ❤' + p.hp : ''))); },
  flash(col, ms) { for (const v of this.vps) { const f = v.q('.flash'); f.style.background = col; f.style.opacity = 1; setTimeout(() => f.style.opacity = 0, ms); } },
  subtitle(t) { this.subEl.textContent = t; this.subEl.style.display = 'block'; clearTimeout(this.subT); this.subT = setTimeout(() => this.subEl.style.display = 'none', Math.max(2200, t.length * 55)); },
  chat(name, text) { const d = el('div', {}, el('b', { style: { color: 'var(--amber)' } }, name + ': '), text); d.t = now(); this.chatEl.append(d); AU.play('ui'); },
  openChat() { if (this.chatIn) return; const i = el('input', { class: 'chatin', placeholder: 'Сообщение… (Enter)', maxlength: 120 }); this.playEl.append(i); this.chatIn = i; if (document.pointerLockElement) document.exitPointerLock(); setTimeout(() => i.focus(), 10);
    i.onkeydown = e => { if (e.key === 'Enter') { const t = i.value.trim(); if (t) NET.toHost({ t: 'chat', pid: LOCALS[0].id, text: t }); i.remove(); this.chatIn = null; } else if (e.key === 'Escape') { i.remove(); this.chatIn = null; } e.stopPropagation(); }; },
  sceneChanged(s) { this.closeModal(); this.closeEAS(); this.alertSummary = null; this.tvOn(); if (s === 'house') { AU.ambient('dawn'); this.toast('Днём собирай яблоки и готовься. В 21:00 — оповещение!', 4500); setTimeout(() => { if (GAME.scene === 'house' && GAME.st.phase === 'day') this.subtitle('Яблочник (из гаража): «Доброе утро! Яблоки беру по $' + (DIFFS[GAME.st.diff] || DIFFS.normal).apple + '. Магазин закрывается ровно в девять!»'); }, 1800); } else AU.ambient('lobby'); },
  // переход «включился старый телевизор»: белая полоса раскрывается в картинку
  tvOn() { let d = $('#tvon'); if (!d) { d = el('div', { id: 'tvon' }, el('i')); document.body.append(d); } d.classList.remove('go'); void d.offsetWidth; d.classList.add('go'); AU.play('static', null, { d: .35, v: .2 }); },

  /* ======== экстренное оповещение ======== */
  phase(m) {
    if (m.ph === 'alert') this.alert(m);
    if (m.ph === 'night') { this.closeEAS(); this.toast('🌙 Ночь ' + (GAME.st.night || '') + '. Заключённый уже рядом…', 3500); }
    if (m.ph === 'dawn') { this.closeEAS(); this.alertSummary = null; this.toast('☀ Рассвет! Вы пережили ночь. +$40', 3500); }
    if (m.ph === 'day') this.toast('День ' + GAME.st.night + '. Магазин открыт.', 3000);
  },
  alert(m) {
    const lines = m.lines; if (!lines) return; AU.hush();
    const T = INMATES.types[GAME.st.inmate];
    this.alertSummary = GAME.st.unknown ? null : T; if (T) { this.alertEl.innerHTML = `<b>${T.name} · ${T.num}</b>${T.tip}`; for (const lp of LOCALS) if (lp.prof && !lp.prof.seen.includes(T.key)) { lp.prof.seen.push(T.key); saveProfile(lp.prof, lp.profKey); } } else this.alertEl.innerHTML = '<b>НЕИЗВЕСТНЫЙ СУБЪЕКТ</b>Сигнал потерян. Прячься и не шуми.';
    if (typeof DIRECTIVE !== 'undefined') { const d = DIRECTIVES[GAME.st.directive]; if (d) this.alertEl.append(el('span', { class: 'dir' }, '📺 ДИРЕКТИВА: ' + d.text + ' — ' + d.hint)); }
    if (document.pointerLockElement) document.exitPointerLock();
    const E = this.easEl; E.style.display = 'flex'; E.innerHTML = '';
    const bd = el('div', { class: 'bd' }), vote = el('button', { onclick: () => { for (const lp of LOCALS) NET.toHost({ t: 'vote', pid: lp.id }); vote.disabled = true; vote.textContent = 'Голос отдан'; } }, 'Пропустить ▶▶'), cnt = el('span', {}, '');
    const box = el('div', { class: 'tvx' }, el('div', { class: 'hdr' }, '⚠ ЭКСТРЕННОЕ ОПОВЕЩЕНИЕ ⚠'), bd, el('div', { class: 'ft' }, el('span', {}, 'AMBER ALERT · BLACK RIDGE ASYLUM'), cnt, vote), el('div', { class: 'scan' }));
    const hide = el('button', { class: 'ghost', style: { position: 'absolute', right: '12px', top: '12px' }, onclick: () => { E.style.display = 'none'; } }, 'Скрыть ✕');
    E.append(box, hide);
    const full = lines.join('\n\n'); let i = 0; this.eas = { full, i: 0, cnt, start: now(), dur: m.dur || ALERT_LEN, again: m.again };
    if (!m.again) { AU.eas(() => { if (this.eas) AU.speak(lines.join(' ')); }); }
    const typer = () => { if (!this.eas || this.easEl.style.display === 'none' && !this.eas) return; i = Math.min(full.length, i + 3); bd.textContent = full.slice(0, i) + (i < full.length ? '█' : ''); bd.scrollTop = bd.scrollHeight; if (i < full.length) this.easTimer = setTimeout(typer, m.again ? 5 : 32); };
    setTimeout(typer, m.again ? 0 : 3800);
  },
  closeEAS() { this.easEl.style.display = 'none'; this.eas = null; clearTimeout(this.easTimer); },
  easFrame() { if (!this.eas) return; const st = GAME.st; const left = Math.max(0, Math.ceil((this.eas.dur - (now() - this.eas.start)))); const tot = Object.keys(GAME.plist || {}).length || (GAME.plist ? GAME.plist.length : 1); this.eas.cnt.textContent = 'Ночь через ' + left + ' с · голосов: ' + (st.votes || 0) + '/' + Math.ceil(((GAME.plist && GAME.plist.length) || 1) / 2); if (st.phase !== 'alert') this.closeEAS(); },

  /* ======== магазин в доме ======== */
  shopResult(m) { if (m.open) this.openShop(); if (m.msg) { this.toast(m.msg); if (this.shopRefresh) setTimeout(() => this.shopRefresh(), 120); } },
  openShop() {
    const lp = LOCALS[0], body = el('div', { class: 'col' });
    const refresh = () => { const info = lp.info || {}; body.innerHTML = '';
      const price = DIFFS[GAME.st.diff] ? DIFFS[GAME.st.diff].apple : 20;
      body.append(el('div', { class: 'row', style: { justifyContent: 'space-between', flexWrap: 'wrap' } }, el('span', { class: 'chip amber', style: { fontSize: '16px' } }, 'У тебя: $' + (info.money || 0)), el('button', { class: 'green', disabled: !(info.apples > 0) ? '' : null, onclick: () => NET.toHost({ t: 'sell', pid: lp.id }) }, '🍎 Продать ' + (info.apples || 0) + ' × $' + price + ' = $' + ((info.apples || 0) * price))));
      const grid = el('div', { class: 'grid' });
      for (const k in ITEMS) { const it = ITEMS[k]; grid.append(el('div', { class: 'card' }, el('div', { class: 't' }, it.icon + ' ' + it.name), el('div', { class: 'd' }, it.desc), el('div', { class: 'row', style: { justifyContent: 'space-between' } }, el('span', { class: 'p' }, '$' + it.price), el('button', { class: 'amber', style: { padding: '8px 12px' }, disabled: (info.money || 0) < it.price ? '' : null, onclick: () => NET.toHost({ t: 'buy', pid: lp.id, k }) }, 'Купить')))); }
      body.append(grid); };
    this.shopRefresh = refresh; refresh(); this.openModal('🍎 Яблочник — магазин', body);
    const iv = setInterval(() => { if (!this.modal) { clearInterval(iv); this.shopRefresh = null; return; } if (GAME.st.phase !== 'day') { this.closeModal(); this.toast('Магазин закрылся!'); } }, 500);
  },
  /* ======== панели лобби ======== */
  openLobbyPanel(id) {
    const P = LOCALS[0] ? LOCALS[0].prof : MAINPROF, key = LOCALS[0] ? LOCALS[0].profKey : 'aa_profile';
    if (id === 'K_SKINS') return this.avatarEditor(P, key);
    if (id === 'K_QUESTS') { const b = el('div', { class: 'col' }); for (const Q of QUESTS) { const q = P.quests[Q.id] || { n: 0 }; b.append(el('div', { class: 'card' + (q.done ? ' sel' : '') }, el('div', { class: 't' }, (q.done ? '✅ ' : '◻ ') + Q.name), el('div', { class: 'bar' }, el('i', { style: { width: Math.min(100, q.n / Q.goal * 100) + '%', background: 'var(--amber)' } })), el('div', { class: 'd' }, Math.min(q.n, Q.goal) + ' / ' + Q.goal + '   ·   награда ◆ ' + Q.reward))); } return this.openModal('Задания', b); }
    if (id === 'K_CODES') { const i = el('input', { placeholder: 'Введи код', style: { textTransform: 'uppercase' } }), st = el('div', { class: 'muted' }); const go = el('button', { class: 'amber', onclick: () => { const c = i.value.trim().toUpperCase(); const R_ = CODES[c]; P.codes = P.codes || []; if (!R_) st.textContent = 'Неверный код'; else if (P.codes.includes(c)) st.textContent = 'Код уже использован'; else { P.codes.push(c); P.amber += R_; saveProfile(P, key); st.textContent = '+' + R_ + ' Amber!'; AU.play('coin'); } } }, 'Активировать'); return this.openModal('Коды', el('div', { class: 'col' }, el('div', { class: 'muted' }, 'Попробуй коды из оригинальной игры 😉 (например, ENDLESS)'), i, go, st)); }
    if (id === 'K_CLASSES' || id === 'shop' || id === 'K_SHOP') {
      const b = el('div', { class: 'col' }, el('div', { class: 'chip amber', style: { alignSelf: 'flex-start' } }, '◆ ' + P.amber + ' Amber')); const grid = el('div', { class: 'grid' });
      for (const k in CLASSES) { const C = CLASSES[k], own = P.classes.includes(k); grid.append(el('div', { class: 'card' + (P.cls === k ? ' sel' : '') }, el('div', { class: 't' }, C.name), el('div', { class: 'd' }, C.desc), el('button', { class: P.cls === k ? 'green' : own ? '' : 'amber', style: { padding: '8px' }, onclick: () => { if (!own) { if (P.amber < C.price) { this.toast('Не хватает Amber'); return; } P.amber -= C.price; P.classes.push(k); AU.play('coin'); } P.cls = k; saveProfile(P, key); for (const lp of LOCALS) if (lp.prof === P) NET.toHost({ t: 'look', pid: lp.id, look: P.look, cls: k, name: P.name }); this.openLobbyPanel(id); } }, P.cls === k ? 'Выбран' : own ? 'Выбрать' : 'Купить · ◆' + C.price))); }
      b.append(grid); if (id !== 'K_CLASSES') b.append(el('button', { onclick: () => this.avatarEditor(P, key) }, '🧍 Скины и аватар'));
      return this.openModal(id === 'K_CLASSES' ? 'Классы' : 'Amber-магазин', b);
    }
  },
  dossier(T) {
    const seen = LOCALS.some(l => l.prof && l.prof.seen.includes(T.key));
    this.openModal('Досье · Black Ridge', el('div', { class: 'dossier' }, el('div', { class: 'num' }, T.num), el('div', { class: 'col' }, el('h3', {}, T.en + ' — ' + T.name), el('div', { class: 'muted' }, 'Класс: ' + T.cls), el('div', {}, seen ? T.alert.join(' ') : '[ДАННЫЕ ЗАСЕКРЕЧЕНЫ — встреться с ним, чтобы открыть досье]'), seen ? el('div', { style: { color: 'var(--amber)', fontWeight: 800 } }, '💡 ' + T.tip) : null)));
  },
  /* ======== смерть, скример, итоги ======== */
  jumpscare(type, lp) {
    const v = this.vps[lp.i]; if (!v) return; const T = INMATES.types[type];
    AU.play('scream'); AU.play('sting');
    const js = v.q('.js'); js.className = 'js jump'; setTimeout(() => js.className = 'js', 1300);
    if (T) { const m = T.model(); m.traverse(o => o.layers.set(20 + lp.i)); lp.cam.layers.enable(20 + lp.i); R.scene.add(m); lp.scare = { m, t: 0, T }; }
  },
  results(m) {
    this.closeEAS(); const body = el('div', { class: 'results col' });
    body.append(el('h1', { style: { color: m.win ? 'var(--ok)' : '#ff3a3a' } }, m.win ? 'ВЫ ВЫЖИЛИ!' : 'ВСЕ ПОГИБЛИ'), el('div', { class: 'big' }, 'Ночей пережито: ' + m.nights), el('div', { class: 'muted' }, 'Карта: ' + MAPS[m.map].name + ' · ' + DIFFS[m.diff].name + ' · обезврежено: ' + m.killed));
    setTimeout(() => { body.append(el('div', { class: 'big', style: { color: 'var(--amber)' } }, '+' + (m.amber || 0) + ' Amber · +' + (m.xp || 0) + ' XP')); if (GAME.isHost()) body.append(el('button', { class: 'amber', onclick: () => { this.closeModal(); NET.toHost({ t: 'tolobby', pid: LOCALS[0].id }); } }, 'В лобби')); else body.append(el('div', { class: 'muted' }, 'Хост вернёт всех в лобби…')); }, 50);
    this.openModal(m.win ? '🏆 Победа' : '💀 Поражение', body, { sticky: true });
  },
  pause() {
    this.pauseT = now();
    const body = el('div', { class: 'btns' });
    body.append(el('button', { class: 'amber', onclick: () => this.closeModal() }, 'Продолжить'));
    if (NET.role === 'host' && NET.code) body.append(el('div', { class: 'code' }, NET.code), el('div', { class: 'muted', style: { textAlign: 'center' } }, 'Код комнаты — скажи другу'));
    if (NET.role !== 'client') body.append(el('button', { class: 'green', onclick: () => this.manualInvite() }, '📨 Пригласить без сервера (коды)'));
    if (NET.role === 'solo' && LOCALS.length === 1) body.append(el('button', { onclick: () => this.goOnlineFromSolo() }, '🌐 Открыть игру для друга по коду'));
    body.append(el('button', { onclick: () => this.avatarEditor(LOCALS[0].prof, LOCALS[0].profKey) }, '🧍 Аватар'), el('button', { class: 'ghost', onclick: () => this.settings() }, '⚙ Настройки'), el('button', { class: 'ghost', onclick: () => this.help() }, '❔ Управление'), el('button', { class: 'red', onclick: () => { this.closeModal(); GAME.leave(); } }, 'Выйти в главное меню'));
    this.openModal('Пауза', body);
  },
  async goOnlineFromSolo() {
    this.toast('Создаём комнату…'); let tries = 0;
    while (tries++ < 4) { const code = makeRoomCode(), t = new PeerTransport(); try { await t.host(code); NET.start('host', t); NET.code = code; this.closeModal(); this.players(GAME.plist || []); this.toast('Комната ' + code + ' открыта! Друг вводит этот код', 7000); return; } catch (e) { t.close(); if (e.type !== 'unavailable-id') { this.toast(netErrorText(e), 5000); return; } } }
  },
  async manualInvite() {
    let t = NET.t instanceof ManualTransport ? NET.t : null;
    if (!t) { if (NET.t) { this.toast('Сначала коды-приглашения работают только без онлайн-комнаты'); return; } t = new ManualTransport(); NET.start('host', t); }
    const out = el('textarea', { rows: 4, readonly: '' }), ans = el('textarea', { rows: 4, placeholder: 'Вставь сюда ответный код друга' }), st = el('div', { class: 'muted' }, 'Создаём приглашение… (до 5 сек)');
    const body = el('div', { class: 'col' }, el('div', { class: 'muted' }, '1) Скопируй код и отправь другу. 2) Друг: «Играть с другом» → «Без сервера» → вставляет код. 3) Вставь сюда его ответ.'), out, el('button', { class: 'ghost', onclick: () => copyText(out.value) }, '📋 Скопировать приглашение'), ans, el('button', { class: 'green', onclick: async () => { try { await inv.accept(ans.value); st.textContent = 'Подключаем…'; } catch (e) { st.textContent = netErrorText(e); } } }, '🔗 Подключить'), st);
    this.openModal('Пригласить без сервера', body);
    const inv = await t.invite(); out.value = inv.code; st.textContent = 'Ждём ответный код от друга…';
    t.on('peer', () => { st.textContent = 'Друг подключился!'; setTimeout(() => this.closeModal(), 800); });
  },
};
const HAT_NAMES = { none: 'Без шапки', cap: 'Кепка', beanie: 'Шапка', headphones: 'Наушники', hair: 'Причёска', hood: 'Капюшон' };
const FACE_NAMES = { smile: 'Улыбка', grin: 'Ухмылка', worried: 'Испуг', cool: 'Очки' };
const HAT_PRICE = { beanie: 30, headphones: 60, hood: 40 };
const CODES = { ENDLESS: 50, BACKROOMS: 40, MORECLASSES: 50, '20KMEMBERS': 30, AMBER: 25, TEZ: 20 };
function copyText(t) { try { navigator.clipboard.writeText(t).then(() => UI.toast('Скопировано!')); } catch (_) { const a = el('textarea', {}); a.value = t; document.body.append(a); a.select(); document.execCommand('copy'); a.remove(); UI.toast('Скопировано!'); } }
// предпросмотр аватара в отдельном маленьком рендере
let PREV = null;
function renderAvatarPreview(canvas, look) {
  if (!PREV) { PREV = { r: new THREE.WebGLRenderer({ antialias: true, alpha: true }), s: new THREE.Scene(), c: new THREE.PerspectiveCamera(30, 220 / 260, .1, 20) }; PREV.s.add(new THREE.HemisphereLight('#fff', '#334', 1.6)); const d = new THREE.DirectionalLight('#fff', 1.2); d.position.set(2, 3, 4); PREV.s.add(d); PREV.c.position.set(0, 1.25, 5.2); PREV.c.lookAt(0, 1, 0); PREV.r.setSize(220, 260); PREV.r.outputColorSpace = THREE.SRGBColorSpace; }
  if (PREV.a) PREV.s.remove(PREV.a.root); PREV.a = new Avatar(look); PREV.a.root.rotation.y = -.4; PREV.s.add(PREV.a.root);
  PREV.r.render(PREV.s, PREV.c); canvas.getContext('2d').drawImage(PREV.r.domElement, 0, 0);
}
function saveSettings() { try { localStorage.setItem('aa_settings', JSON.stringify(SETTINGS)); } catch (_) { } }
function loadSettings() { try { Object.assign(SETTINGS, JSON.parse(localStorage.getItem('aa_settings')) || {}); } catch (_) { } MOUSE_SENS = .0024 * (SETTINGS.mouseSens || 1); }
