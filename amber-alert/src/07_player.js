/* ================= ИГРОКИ: локальный (камера+управление) и удалённый (интерполяция) ================= */
const EYE = 1.55, EYE_CROUCH = .95;
const WALK = 4.0, RUN = 6.6, CROUCH = 1.9;
class LocalPlayer {
  constructor(i, src, info) {
    this.i = i; this.src = src; this.id = info.id; this.name = info.name; this.look = info.look;
    this.body = new Body({ r: .3, h: 1.75 }); this.cam = new THREE.PerspectiveCamera(74, 1, .05, 120); this.cam.rotation.order = 'YXZ';
    this.cam.layers.enableAll(); this.cam.layers.disable(1 + i);   // своё тело не видно
    this.avatar = new Avatar(this.look, this.name); this.avatar.root.traverse(o => o.layers.set(1 + i)); R.scene.add(this.avatar.root);
    this.eye = EYE; this.stamina = 1; this.crouch = false; this.light = false; this.battery = 1; this.lean = 0; this.bob = 0; this.stepAcc = 0;
    this.hidden = null; this.alive = true; this.spectate = null; this.noise = 0; this.speed = 0; this.focus = null; this.shake = 0; this.frozen = false;
    this.inv = []; this.slot = 0; this.hp = 100;
  }
  setPose(x, y, z, yaw) { this.body.p.set(x, y, z); this.body.v.set(0, 0, 0); this.body.yaw = yaw || 0; this.body.pitch = 0; this.eyeY = y + EYE; }
  update(dt, world) {
    const s = this.src.poll(dt), b = this.body; this.input = s;
    // обзор
    b.yaw += s.lx; b.pitch = clamp(b.pitch + s.ly, -1.45, 1.45);
    if (!this.alive) { this.speed = 0; this.updateSpectate(dt); return s; }
    if (this.hidden) { this.speed = 0; this.noise = 0; this.placeHiddenCam(dt); return s; }
    if (s.press.crouch) this.crouch = !this.crouch; if (s.held.crouch) this.crouchHold = true; const crouching = this.crouch || s.held.crouch;
    let mx = s.mx, my = s.my; const m = Math.hypot(mx, my); if (m > 1) { mx /= m; my /= m; }
    const moving = m > .08 && !this.frozen;
    const running = moving && s.held.run && this.stamina > .05 && !crouching;
    this.stamina = clamp(this.stamina + (running ? -.16 / (this.prof && this.prof.cls === 'runner' ? 1.6 : 1) : .11) * dt, 0, 1);
    const sp = (crouching ? CROUCH : running ? RUN : WALK) * (moving ? 1 : 0);
    const sy = Math.sin(b.yaw), cy = Math.cos(b.yaw);
    const wx = (mx * cy + my * sy) * sp, wz = (-mx * sy + my * cy) * sp;
    b.h = crouching ? 1.15 : 1.75;
    if (!crouching && world.blocked(b.p.x, b.p.y, b.p.z, b.r, 1.75, b.step)) { b.h = 1.15; } // не встать под столом
    b.move(world, wx, wz, dt, s.press.jump && !crouching);
    this.speed = Math.hypot(wx, wz);
    this.noise = !moving ? 0 : running ? 1 : crouching ? .1 : .4;
    // глаза, наклон, покачивание
    const eyeT = b.h < 1.5 ? EYE_CROUCH : EYE; this.eye = damp(this.eye, eyeT, 12, dt);
    this.lean = damp(this.lean, (s.held.leanR ? 1 : 0) - (s.held.leanL ? 1 : 0), 10, dt);
    if (this.speed > .3 && b.ground) { this.bob += dt * this.speed * 2.1; this.stepAcc += this.speed * dt; if (this.stepAcc > (running ? 1.6 : 1.25)) { this.stepAcc = 0; AU.play('step', null, { v: running ? .14 : crouching ? .03 : .08 }); } }
    this.eyeY = this.eyeY === undefined ? b.p.y + this.eye : damp(this.eyeY, b.p.y + this.eye, 18, dt); // сглаживание ступенек
    const lx = Math.cos(b.yaw) * this.lean * .45, lz = -Math.sin(b.yaw) * this.lean * .45;
    this.cam.position.set(b.p.x + lx, this.eyeY + Math.sin(this.bob * 2) * .035 * Math.min(1, this.speed / 4), b.p.z + lz);
    this.cam.rotation.set(b.pitch, b.yaw, -this.lean * .12);
    if (this.shake > 0) { this.cam.position.x += (Math.random() - .5) * this.shake * .1; this.cam.position.y += (Math.random() - .5) * this.shake * .1; this.shake = Math.max(0, this.shake - dt * 3); }
    if (s.press.light) this.toggleLight();
    if (this.light) { this.battery = Math.max(0, this.battery - dt / (this.prof && this.prof.cls === 'electric' ? 840 : 420)); if (this.battery <= 0) this.light = false; }
    return s;
  }
  toggleLight() { if (this.battery <= 0) { AU.play('click'); return; } this.light = !this.light; AU.play('click'); }
  placeHiddenCam(dt) { const h = this.hidden; this.cam.position.lerp(h.eye, 1 - Math.exp(-10 * dt)); this.body.pitch = clamp(this.body.pitch, -.6, .5); this.body.yaw = clamp(angDiff(h.yaw, this.body.yaw), -.9, .9) + h.yaw; this.cam.rotation.set(this.body.pitch, this.body.yaw, 0); }
  updateSpectate(dt) {
    const t = this.spectate; if (!t) { this.cam.position.lerp(new V3(this.body.p.x, this.body.p.y + 4, this.body.p.z + 3), .05); this.cam.lookAt(this.body.p); return; }
    const off = new V3(Math.sin(this.body.yaw) * 3, 1.8 + this.body.pitch * 2, Math.cos(this.body.yaw) * 3);
    this.cam.position.lerp(t.clone().add(off), 1 - Math.exp(-6 * dt)); this.cam.lookAt(t.x, t.y + 1.2, t.z);
  }
  pose() { const b = this.body; return { x: +b.p.x.toFixed(2), y: +b.p.y.toFixed(2), z: +b.p.z.toFixed(2), yaw: +b.yaw.toFixed(2), pitch: +b.pitch.toFixed(2), sp: +this.speed.toFixed(1), cr: b.h < 1.5 ? 1 : 0, l: this.light ? 1 : 0, hid: this.hidden ? this.hidden.id : 0, n: this.noise }; }
  syncAvatar(dt) {
    const b = this.body, a = this.avatar; a.root.position.copy(b.p); a.root.rotation.y = b.yaw + PI; a.root.visible = !this.hidden && this.alive;
    a.anim(dt, this.speed, { crouch: b.h < 1.5, torch: this.light, dead: !this.alive }); a.setPitch(b.pitch);
  }
  // точка и направление фонарика
  torch() { const d = new V3(0, 0, -1).applyQuaternion(this.cam.quaternion); return { pos: this.cam.position.clone().add(new V3(.18, -.2, 0).applyQuaternion(this.cam.quaternion)), dir: d }; }
}
class RemotePlayer {
  constructor(info) {
    this.id = info.id; this.name = info.name; this.look = info.look; this.p = new V3(0, -50, 0); this.t = new V3(0, -50, 0); this.yaw = 0; this.tyaw = 0; this.pitch = 0; this.sp = 0; this.cr = 0; this.l = 0; this.hid = 0; this.alive = true;
    this.avatar = new Avatar(this.look, this.name); R.scene.add(this.avatar.root);
  }
  setPose(s) { this.t.set(s.x, s.y, s.z); this.tyaw = s.yaw; this.pitch = s.pitch; this.sp = s.sp; this.cr = s.cr; this.l = s.l; this.hid = s.hid; if (this.p.y < -40) { this.p.copy(this.t); this.yaw = s.yaw; } }
  update(dt) {
    this.p.lerp(this.t, 1 - Math.exp(-12 * dt)); this.yaw += angDiff(this.yaw, this.tyaw) * (1 - Math.exp(-12 * dt));
    const a = this.avatar; a.root.position.copy(this.p); a.root.rotation.y = this.yaw + PI; a.root.visible = !this.hid && this.p.y > -40;
    a.anim(dt, this.sp, { crouch: !!this.cr, torch: !!this.l, dead: !this.alive }); a.setPitch(this.pitch);
  }
  torch() { const q = new THREE.Quaternion().setFromEuler(new THREE.Euler(this.pitch, this.yaw, 0, 'YXZ')); return { pos: this.p.clone().add(new V3(0, 1.4, 0)), dir: new V3(0, 0, -1).applyQuaternion(q) }; }
  dispose() { R.scene.remove(this.avatar.root); }
}
