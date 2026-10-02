/* ================= ГЛАВНЫЙ ЦИКЛ, ПОГОДА, НЕБО, ТЕЛЕВИЗОР ================= */
let MAINPROF = null;
/* ---- погода ---- */
const WEATHER = { kind: 'none', pts: null, flashT: 0 };
function setWeather(kind) {
  if (WEATHER.pts) { R.scene.remove(WEATHER.pts); WEATHER.pts.geometry.dispose(); WEATHER.pts = null; }
  WEATHER.kind = kind; if (kind !== 'rain' && kind !== 'snow') return;
  const n = SETTINGS.quality === 'low' ? 900 : 2200, pos = new Float32Array(n * 3);
  for (let i = 0; i < n; i++) { pos[i * 3] = (Math.random() - .5) * 40; pos[i * 3 + 1] = Math.random() * 14; pos[i * 3 + 2] = (Math.random() - .5) * 40; }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const m = new THREE.PointsMaterial({ color: kind === 'rain' ? '#9ab0d0' : '#ffffff', size: kind === 'rain' ? .06 : .09, transparent: true, opacity: kind === 'rain' ? .6 : .9, depthWrite: false });
  WEATHER.pts = new THREE.Points(g, m); WEATHER.pts.frustumCulled = false; R.scene.add(WEATHER.pts);
}
function weatherFrame(dt, focus) {
  const W = WEATHER; if (!W.pts) return; const a = W.pts.geometry.attributes.position, arr = a.array, sp = W.kind === 'rain' ? 16 : 1.3;
  for (let i = 0; i < arr.length; i += 3) { arr[i + 1] -= sp * dt; if (W.kind === 'snow') arr[i] += Math.sin(now() + i) * dt * .3; if (arr[i + 1] < 0) { arr[i + 1] = 13 + Math.random(); arr[i] = focus.x + (Math.random() - .5) * 40; arr[i + 2] = focus.z + (Math.random() - .5) * 40; } }
  a.needsUpdate = true;
  if (W.kind === 'rain' && GAME.st.phase === 'night') { W.flashT -= dt; if (W.flashT < 0) { W.flashT = 8 + Math.random() * 14; W.flash = .25; setTimeout(() => AU.play('bang', null), 600 + Math.random() * 900); } }
  if (W.flash > 0) W.flash -= dt;
}
/* ---- небо и свет по времени суток ---- */
const SKY = { day: new THREE.Color('#87b6e6'), dusk: new THREE.Color('#d8774a'), night: new THREE.Color('#05070d'), lobby: new THREE.Color('#0b1020') };
function skyFrame() {
  const st = GAME.st, sc = R.scene; let k = 0; // k: 1 — день, 0 — ночь
  if (WORLD.level === 'house') { const c = (st.clock || 7) % 24; if (st.phase === 'night' || st.phase === 'alert') k = 0; else if (c >= 7.5 && c <= 18) k = 1; else if (c > 18 && c < 21) k = 1 - (c - 18) / 3; else if (c >= 6 && c < 7.5) k = (c - 6) / 1.5; else k = 0;
    if (WEATHER.kind === 'rain') k *= .55;
    const col = k > .5 ? SKY.dusk.clone().lerp(SKY.day, (k - .5) * 2) : SKY.night.clone().lerp(SKY.dusk, k * 2);
    sc.background = col; if (!sc.fog) sc.fog = new THREE.FogExp2(col, .03); sc.fog.color.copy(col); sc.fog.density = lerp(.055, .012, k) + (WEATHER.kind === 'rain' ? .01 : 0);
    R.hemi.intensity = lerp(.07, 1.05, k); R.moon.intensity = lerp(.12, 1.5, k); R.moon.color.set(k > .5 ? '#fff1d8' : '#8aa0d8'); R.ambient.intensity = lerp(.035, .25, k);
    if (WEATHER.flash > 0) { R.hemi.intensity += 2.5; }
  } else { sc.background = SKY.lobby; if (!sc.fog) sc.fog = new THREE.FogExp2(SKY.lobby, .02); sc.fog.color.copy(SKY.lobby); sc.fog.density = .016; R.hemi.intensity = .45; R.moon.intensity = .4; R.moon.color.set('#8aa0d8'); R.ambient.intensity = .12; }
}
/* ---- телевизор в доме ---- */
let tvT = 0;
function houseFrame(dt) {
  if (WORLD.level !== 'house' || !HOUSE.tv) return;
  drawClocks((GAME.st.clock || 7) % 24);
  tvT += dt; if (tvT < .08) return; tvT = 0;
  const tv = HOUSE.tv, c = tv.canvas, g = c.getContext('2d'), st = GAME.st, on = WS.TV && WS.TV.on && GAME.power();
  tv.screen.material.color.set(on ? '#ffffff' : '#111111');
  if (!on) { g.fillStyle = '#070808'; g.fillRect(0, 0, c.width, c.height); tv.tex.needsUpdate = true; return; }
  if (st.phase === 'alert') drawEAS(c, ['EMERGENCY ALERT', ...(st.alertLines || ['ВНИМАНИЕ'])], now(), { foot: 'ЗАКЛЮЧЁННЫЙ ' + (INMATES.types[st.inmate] && !st.unknown ? INMATES.types[st.inmate].num : '???') });
  else if (st.phase === 'night') { const im = g.createImageData(c.width, c.height); for (let i = 0; i < im.data.length; i += 4) { const v = Math.random() * 200; im.data[i] = im.data[i + 1] = im.data[i + 2] = v; im.data[i + 3] = 255; } g.putImageData(im, 0, 0); if (INM.some(m => m.type === 'dancer')) { g.fillStyle = 'rgba(255,0,120,.35)'; g.fillRect(0, 0, c.width, c.height); g.fillStyle = '#fff'; g.font = '900 40px Arial'; g.textAlign = 'center'; g.fillText('♪ ♫ ♪', c.width / 2, c.height / 2); } }
  else { // «передача 90-х»: цветные полосы утром, мультик днём
    const t = now(); if (((t / 6) | 0) % 3 === 0) { const cols = ['#c0c0c0', '#c0c000', '#00c0c0', '#00c000', '#c000c0', '#c00000', '#0000c0']; cols.forEach((cl, i) => { g.fillStyle = cl; g.fillRect(i * c.width / 7, 0, c.width / 7 + 1, c.height * .7); }); g.fillStyle = '#111'; g.fillRect(0, c.height * .7, c.width, c.height * .3); g.fillStyle = '#fff'; g.font = '700 22px Consolas'; g.fillText('КАНАЛ 9 · ' + String(Math.floor(st.clock % 24)).padStart(2, '0') + ':00', 20, c.height * .88); }
    else { g.fillStyle = '#2a6ad8'; g.fillRect(0, 0, c.width, c.height); g.fillStyle = '#3aa83a'; g.fillRect(0, c.height * .7, c.width, c.height); const x = (t * 60) % (c.width + 80) - 40; g.fillStyle = '#ffd83a'; g.beginPath(); g.arc(x, c.height * .55 - Math.abs(Math.sin(t * 5)) * 40, 26, 0, TAU); g.fill(); g.fillStyle = '#000'; g.fillRect(x - 10, c.height * .5 - Math.abs(Math.sin(t * 5)) * 40, 5, 8); g.fillRect(x + 5, c.height * .5 - Math.abs(Math.sin(t * 5)) * 40, 5, 8); g.fillStyle = '#fff'; g.font = '900 24px Arial'; g.textAlign = 'left'; g.fillText('МУЛЬТИКИ', 12, 30); }
    for (let i = 0; i < 18; i++) { g.fillStyle = `rgba(255,255,255,${Math.random() * .12})`; g.fillRect(0, Math.random() * c.height, c.width, 2); } }
  tv.tex.needsUpdate = true;
}
/* ---- фонарики (пул прожекторов) ---- */
function torchFrame() {
  const want = [];
  for (const lp of LOCALS) if (lp.alive && lp.light) { const t = lp.torch(); want.push([0, t, lp.prof && lp.prof.cls === 'electric' ? 1.3 : 1]); }
  const fp = LOCALS[0] ? LOCALS[0].cam.position : new V3();
  for (const id in GAME.remotes) { const r = GAME.remotes[id]; if (r.alive && r.l && !r.hid) { const t = r.torch(); want.push([t.pos.distanceTo(fp), t, 1]); } }
  want.sort((a, b) => a[0] - b[0]);
  R.spots.forEach((s, i) => { const w = want[i]; if (!w) { s.intensity = 0; s.position.set(0, -100, 0); return; } const t = w[1]; s.position.copy(t.pos); s.target.position.copy(t.pos.clone().add(t.dir)); s.intensity = 26 * w[2] * (WORLD.level === 'house' && INM.some(m => m.T.flickerTorch) && Math.random() < .2 ? .2 : 1); s.distance = 22; });
  for (const lp of LOCALS) { lp.avatar.torchLens.material.color.set(lp.light ? '#fff6c8' : '#333'); }
  for (const id in GAME.remotes) GAME.remotes[id].avatar.torchLens.material.color.set(GAME.remotes[id].l ? '#fff6c8' : '#333');
}
/* ---- скример ---- */
function scareFrame(dt) {
  for (const lp of LOCALS) { const s = lp.scare; if (!s) continue; s.t += dt;
    const f = new V3(0, 0, -1).applyQuaternion(lp.cam.quaternion); const h = s.T.eye || 1.6;
    s.m.position.copy(lp.cam.position).add(f.multiplyScalar(.75 + Math.sin(s.t * 40) * .03)); s.m.position.y -= h * .92; s.m.lookAt(lp.cam.position.x, s.m.position.y, lp.cam.position.z);
    s.m.rotation.z = Math.sin(s.t * 50) * .06; s.m.scale.setScalar(1.05 + s.t * .2);
    if (s.t > 1.3) { R.scene.remove(s.m); lp.scare = null; } }
}
/* ---- камера меню ---- */
const MENUCAM = new THREE.PerspectiveCamera(60, 1, .1, 200);
function menuCamFrame(t) { const a = t * .05; MENUCAM.position.set(Math.sin(a) * 18, 7 + Math.sin(t * .2), Math.cos(a) * 18 + 2); MENUCAM.lookAt(0, 2.5, -6); }
/* ---- захват мыши ---- */
function wantLock() { return !IS_TOUCH && GAME.scene !== 'menu' && !UI.modal && !UI.chatIn && UI.easEl.style.display !== 'flex' && LOCALS.some(l => l.src instanceof KBMouse && l.src.mouse); }
addEventListener('pointerdown', e => { AU.init(); if (wantLock() && !document.pointerLockElement && e.target.tagName === 'CANVAS') { try { R.renderer.domElement.requestPointerLock(); } catch (_) { } } }, true);
document.addEventListener('pointerlockchange', () => { if (!document.pointerLockElement && GAME.scene !== 'menu' && !UI.modal && !UI.chatIn && !IS_TOUCH && !UI.justClosed && UI.easEl.style.display !== 'flex') UI.pause(); });
addEventListener('keydown', () => AU.init());
/* ---- цикл ---- */
let last = performance.now(), fpsAcc = 0, fpsN = 0;
function frame(t) {
  requestAnimationFrame(frame);
  const dt = clamp((t - last) / 1000, 0, .05); last = t;
  try {
    if (GAME.scene !== 'menu') {
      if (!UI.modal && !UI.chatIn) GAME.localTick(dt); else { for (const lp of LOCALS) { lp.src.poll(dt); lp.syncAvatar(dt); } for (const id in GAME.remotes) GAME.remotes[id].update(dt); for (const m of INM) m.render(dt, GAME.isHost()); for (const f of WORLD.ticks) f(dt); }
      if (GAME.isHost()) GAME.hostTick(dt);
      for (const lp of LOCALS) { const s = lp.input; if (!s) continue; if (s.press.menu && !UI.modal) UI.pause(); else if (s.press.menu && UI.modal && now() - (UI.pauseT || 0) > .35) UI.closeModal(); if (s.press.chat && lp.i === 0 && NET.role !== 'solo') UI.openChat(); }
      scareFrame(dt);
    } else { menuCamFrame(t / 1000); for (const f of WORLD.ticks) f(dt); }
    lobbyFrame(dt); houseFrame(dt); skyFrame(); torchFrame();
    const focus = LOCALS.length ? LOCALS.map(l => l.cam.position) : [MENUCAM.position];
    R.pool.update(focus); weatherFrame(dt, focus[0]);
    AU.setListener(LOCALS[0] ? LOCALS[0].cam : MENUCAM);
    UI.frame(dt); UI.easFrame();
    if (LOCALS.length) R.render(); else { R.renderer.setViewport(0, 0, R.w, R.h); R.renderer.setScissor(0, 0, R.w, R.h); MENUCAM.aspect = R.w / R.h; MENUCAM.updateProjectionMatrix(); R.renderer.render(R.scene, MENUCAM); }
  } catch (e) { console.error(e); if (!frame.err) { frame.err = 1; UI.toast('Ошибка: ' + e.message, 6000); } }
  endFramePresses();
}
/* ---- старт ---- */
function boot() {
  loadSettings(); MAINPROF = loadProfile();
  R.init(); UI.init(); buildLobby(); GAME.scene = 'menu'; UI.show('menu'); AU.ambient('lobby');
  window.AA = { GAME, NET, LOCALS, WORLD, WS, INM, UI, R, AU, INMATES, HOUSE, LOBBY, THREE, V3, Inmate, MM, wsSet, setWeather };
  // тестовый помощник: прогнать игровую логику на sec секунд без отрисовки (шаг 50 мс)
  AA.sim = sec => { for (let t = 0; t < sec; t += .05) { GAME.localTick(.05); if (GAME.isHost()) GAME.hostTick(.05); houseFrame(.05); endFramePresses(); } return true; };
  if (QS.get('autostart') === 'solo') UI.startSolo();
  if (QS.get('autostart') === 'split') { UI.needName(); GAME.begin('solo', null, [{ id: 'h1', src: new KBMouse(BIND.p1, true), prof: MAINPROF, profKey: 'aa_profile' }, { id: 'h2', src: new KBMouse(BIND.p2, false), prof: loadProfile('aa_profile2'), profKey: 'aa_profile2' }]); }
  if (QS.get('tabhost')) { const t = new TabTransport(); t.open(QS.get('tabhost'), true).then(() => UI.startHostWith(t, QS.get('tabhost'))); }
  if (QS.get('tabjoin')) { const t = new TabTransport(); t.open(QS.get('tabjoin'), false).then(() => UI.startClientWith(t)).catch(e => UI.toast(netErrorText(e))); }
  if (QS.get('peerhostcode')) { const t = new PeerTransport(); t.host(QS.get('peerhostcode')).then(() => UI.startHostWith(t, QS.get('peerhostcode'))).catch(e => console.error('peer host', e)); }
  if (QS.get('peerjoincode')) { const t = new PeerTransport(); t.join(QS.get('peerjoincode')).then(() => UI.startClientWith(t)).catch(e => console.error('peer join', e)); }
  requestAnimationFrame(frame);
}
boot();
