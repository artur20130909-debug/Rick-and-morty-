/* ================= ВВОД: клавиатура+мышь, сенсор, геймпад; до 2 локальных игроков ================= */
// Каждый источник ввода выдаёт одинаковое «состояние» за кадр:
// mx,my — движение (-1..1), lx,ly — поворот камеры (радианы за кадр), held{run,crouch,leanL,leanR}, press{use,light,jump,menu,chat,crouch}
const KEYS = {};
const BIND = { // игрок 1 (WASD + мышь)
  p1: { up: ['KeyW', 'ArrowUp'], down: ['KeyS', 'ArrowDown'], left: ['KeyA', 'ArrowLeft'], right: ['KeyD', 'ArrowRight'], use: ['KeyE'], light: ['KeyF'], run: ['ShiftLeft'], crouch: ['KeyC', 'ControlLeft'], jump: ['Space'], leanL: ['KeyQ'], leanR: ['KeyR'], menu: ['Escape', 'Tab'], chat: ['Enter', 'KeyT'], item: ['KeyG'], slot: ['KeyX'] },
  // игрок 2 на той же клавиатуре: IJKL — ходить, стрелки — смотреть
  p2: { up: ['KeyI'], down: ['KeyK'], left: ['KeyJ'], right: ['KeyL'], lookL: ['ArrowLeft'], lookR: ['ArrowRight'], lookU: ['ArrowUp'], lookD: ['ArrowDown'], use: ['KeyO', 'Numpad0'], light: ['KeyP'], run: ['ShiftRight'], crouch: ['KeyN', 'ControlRight'], jump: ['KeyH'], leanL: ['KeyU'], leanR: ['KeyY'], menu: ['Backspace'], item: ['Semicolon', 'NumpadEnter'], slot: ['Quote', 'NumpadAdd'] },
};
const PRESSED = new Set();
addEventListener('keydown', e => {
  if (document.activeElement && /INPUT|TEXTAREA/.test(document.activeElement.tagName)) return;
  if (!KEYS[e.code]) PRESSED.add(e.code); KEYS[e.code] = true;
  if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Tab'].includes(e.code)) e.preventDefault();
});
addEventListener('keyup', e => { KEYS[e.code] = false; });
addEventListener('blur', () => { for (const k in KEYS) KEYS[k] = false; });
const anyKey = list => list && list.some(k => KEYS[k]);
const anyPress = list => list && list.some(k => PRESSED.has(k));

class InputState { constructor() { this.mx = 0; this.my = 0; this.lx = 0; this.ly = 0; this.held = {}; this.press = {}; } reset() { this.lx = this.ly = 0; this.press = {}; } }

/* ---- клавиатура + мышь ---- */
let MOUSE_SENS = .0024;
class KBMouse {
  constructor(bind, mouse) { this.b = bind; this.mouse = mouse; this.st = new InputState(); this.dx = 0; this.dy = 0; }
  poll(dt) {
    const b = this.b, s = this.st; s.reset();
    s.mx = (anyKey(b.right) ? 1 : 0) - (anyKey(b.left) ? 1 : 0); s.my = (anyKey(b.down) ? 1 : 0) - (anyKey(b.up) ? 1 : 0);
    if (this.mouse) { s.lx = -this.dx * MOUSE_SENS; s.ly = -this.dy * MOUSE_SENS; this.dx = this.dy = 0; }
    else { const k = 2.4 * dt; s.lx = ((anyKey(b.lookL) ? 1 : 0) - (anyKey(b.lookR) ? 1 : 0)) * k; s.ly = ((anyKey(b.lookU) ? 1 : 0) - (anyKey(b.lookD) ? 1 : 0)) * k * .7; }
    s.held = { run: anyKey(b.run), crouch: anyKey(b.crouch), leanL: anyKey(b.leanL), leanR: anyKey(b.leanR) };
    s.press = { use: anyPress(b.use), light: anyPress(b.light), jump: anyPress(b.jump), menu: anyPress(b.menu), chat: anyPress(b.chat), crouch: anyPress(b.crouch), item: anyPress(b.item), slot: anyPress(b.slot) || (this.mouse && this.wheel), };
    this.wheel = 0;
    return s;
  }
}
let POINTER_LOCKED = false;
document.addEventListener('pointerlockchange', () => { POINTER_LOCKED = document.pointerLockElement != null; });
addEventListener('mousemove', e => { if (POINTER_LOCKED) for (const p of LOCALS) if (p.src instanceof KBMouse && p.src.mouse) { p.src.dx += e.movementX; p.src.dy += e.movementY; } });
addEventListener('mousedown', e => { if (POINTER_LOCKED && e.button === 0) PRESSED.add('Mouse0'); });
addEventListener('wheel', e => { if (POINTER_LOCKED) for (const p of LOCALS) if (p.src instanceof KBMouse && p.src.mouse) p.src.wheel = 1; }, { passive: true });

/* ---- геймпад ---- */
class Pad {
  constructor(index) { this.i = index; this.st = new InputState(); this.prev = []; }
  poll(dt) {
    const s = this.st; s.reset(); const gp = (navigator.getGamepads ? navigator.getGamepads() : [])[this.i]; if (!gp) return s;
    const dz = v => Math.abs(v) < .18 ? 0 : v, b = i => gp.buttons[i] && gp.buttons[i].pressed, pr = i => b(i) && !this.prev[i];
    s.mx = dz(gp.axes[0]); s.my = dz(gp.axes[1]); s.lx = -dz(gp.axes[2]) * 3 * dt; s.ly = -dz(gp.axes[3]) * 2.2 * dt;
    s.held = { run: b(6) || b(10), crouch: false, leanL: b(4), leanR: b(5) };
    s.press = { use: pr(0), crouch: pr(1), light: pr(2), jump: pr(3), menu: pr(9), item: pr(7), slot: pr(15) || pr(12) };
    this.prev = gp.buttons.map(x => x.pressed); return s;
  }
}

/* ---- сенсор: джойстик слева, обзор пальцем справа, кнопки ---- */
class Touch {
  constructor(zone) { // zone: DOM-элемент области этого игрока
    this.z = zone; this.st = new InputState(); this.joy = null; this.lookId = null; this.lp = null; this.ldx = 0; this.ldy = 0; this.btn = {}; this.tap = {}; this.runOn = false;
    this.stick = el('div', { class: 'tstick' }, el('div', { class: 'tknob' })); this.stick.style.display = 'none'; zone.append(this.stick);
    const mk = (cls, label, key, hold) => { const b = el('div', { class: 'tbtn ' + cls }, label); zone.append(b);
      b.addEventListener('pointerdown', e => { e.stopPropagation(); e.preventDefault(); if (hold) this.btn[key] = true; else this.tap[key] = true; if (key === 'use') this.useHeld = true; b.classList.add('on'); b.setPointerCapture(e.pointerId); });
      const up = e => { this.btn[key] = false; if (key === 'use') this.useHeld = false; b.classList.remove('on'); }; b.addEventListener('pointerup', up); b.addEventListener('pointercancel', up); return b; };
    this.bUse = mk('b-use', '✋', 'use'); mk('b-light', '🔦', 'light'); mk('b-run', '🏃', 'run', true); mk('b-crouch', '⬇', 'crouch'); mk('b-jump', '⤒', 'jump'); mk('b-lean', '👀', 'leanR', true); this.bItem = mk('b-item', '🎯', 'item'); mk('b-slot', '🔄', 'slot');
    zone.addEventListener('pointerdown', e => {
      const r = zone.getBoundingClientRect(), x = e.clientX - r.left;
      if (x < r.width * .42 && !this.joy) { this.joy = { id: e.pointerId, ox: e.clientX, oy: e.clientY, x: 0, y: 0 }; Object.assign(this.stick.style, { display: 'block', left: (e.clientX - r.left - 55) + 'px', top: (e.clientY - r.top - 55) + 'px' }); }
      else if (this.lookId == null) { this.lookId = e.pointerId; this.lp = [e.clientX, e.clientY]; }
      zone.setPointerCapture(e.pointerId);
    });
    zone.addEventListener('pointermove', e => {
      if (this.joy && e.pointerId === this.joy.id) { let dx = e.clientX - this.joy.ox, dy = e.clientY - this.joy.oy; const m = Math.hypot(dx, dy), R = 50; if (m > R) { dx *= R / m; dy *= R / m; } this.joy.x = dx / R; this.joy.y = dy / R; this.stick.firstChild.style.transform = `translate(${dx}px,${dy}px)`; }
      else if (e.pointerId === this.lookId) { this.ldx += e.clientX - this.lp[0]; this.ldy += e.clientY - this.lp[1]; this.lp = [e.clientX, e.clientY]; }
    });
    const end = e => { if (this.joy && e.pointerId === this.joy.id) { this.joy = null; this.stick.style.display = 'none'; } if (e.pointerId === this.lookId) this.lookId = null; };
    zone.addEventListener('pointerup', end); zone.addEventListener('pointercancel', end);
  }
  poll(dt) {
    const s = this.st; s.reset();
    s.mx = this.joy ? this.joy.x : 0; s.my = this.joy ? this.joy.y : 0;
    const k = .0055 * (SETTINGS.touchSens || 1); s.lx = -this.ldx * k; s.ly = -this.ldy * k * .8; this.ldx = this.ldy = 0;
    const jm = this.joy ? Math.hypot(this.joy.x, this.joy.y) : 0;
    s.held = { run: !!this.btn.run || jm > .97, crouch: false, leanL: false, leanR: !!this.btn.leanR };
    s.press = Object.assign({}, this.tap); this.tap = {};
    return s;
  }
}
// список локальных игроков (заполняется при старте сессии)
const LOCALS = [];
const SETTINGS = { touchSens: 1, mouseSens: 1, volume: .8, quality: IS_TOUCH ? 'low' : 'high', name: '' };
function endFramePresses() { PRESSED.clear(); }
