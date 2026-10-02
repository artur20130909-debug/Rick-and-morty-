/* ================= РЕНДЕР: сцена, камеры, разделённый экран, пул света ================= */
const R = {
  renderer: null, scene: null, root: null, clock: null, w: 1, h: 1,
  init() {
    const lowQ = SETTINGS.quality === 'low';
    const r = this.renderer = new THREE.WebGLRenderer({ antialias: !lowQ, powerPreference: 'high-performance', preserveDrawingBuffer: !!QS.get('test') });
    r.setPixelRatio(Math.min(devicePixelRatio || 1, lowQ ? 1 : 1.6));
    r.outputColorSpace = THREE.SRGBColorSpace; r.toneMapping = THREE.ACESFilmicToneMapping; r.toneMappingExposure = 1.1;
    r.setScissorTest(true);
    $('#view').append(r.domElement);
    this.scene = new THREE.Scene(); this.scene.background = new THREE.Color('#05060a');
    this.hemi = new THREE.HemisphereLight('#6a7aa8', '#1a1410', .35); this.scene.add(this.hemi);
    this.ambient = new THREE.AmbientLight('#ffffff', .08); this.scene.add(this.ambient);
    this.moon = new THREE.DirectionalLight('#8aa0d8', .25); this.moon.position.set(-20, 30, 10); this.scene.add(this.moon); this.scene.add(this.moon.target);
    this.pool = new LightPool(this.scene, lowQ ? 4 : 7);
    this.spots = []; for (let i = 0; i < (lowQ ? 2 : 4); i++) { const s = new THREE.SpotLight('#fff3d6', 0, 20, .52, .55, 1.6); s.position.set(0, -100, 0); this.scene.add(s); this.scene.add(s.target); this.spots.push(s); }
    addEventListener('resize', () => this.resize()); this.resize();
  },
  resize() { this.w = innerWidth; this.h = innerHeight; this.renderer.setSize(this.w, this.h); },
  // видовые экраны для локальных игроков
  viewports() {
    const n = Math.max(1, LOCALS.length), W = this.w, H = this.h;
    if (n === 1) return [[0, 0, W, H]];
    return W >= H ? [[0, 0, W / 2, H], [W / 2, 0, W / 2, H]] : [[0, H / 2, W, H / 2], [0, 0, W, H / 2]];
  },
  render() {
    const vps = this.viewports(), r = this.renderer;
    if (!LOCALS.length) return;
    LOCALS.forEach((p, i) => {
      const v = vps[i] || vps[0], cam = p.cam; cam.aspect = v[2] / v[3]; cam.updateProjectionMatrix();
      r.setViewport(v[0], v[1], v[2], v[3]); r.setScissor(v[0], v[1], v[2], v[3]);
      p.beforeRender && p.beforeRender();
      r.render(this.scene, cam);
      p.afterRender && p.afterRender();
    });
  },
};
// Пул точечных ламп: фиксированное число источников (без перекомпиляции шейдеров),
// присваиваются ближайшим включённым лампам комнат.
class LightPool {
  constructor(scene, n) { this.lights = []; for (let i = 0; i < n; i++) { const l = new THREE.PointLight('#ffd9a0', 0, 9, 1.6); l.position.set(0, -100, 0); scene.add(l); this.lights.push(l); } this.lamps = []; }
  setLamps(lamps) { this.lamps = lamps; } // lamps: [{pos:V3, on:()=>bool, color, power, range, flicker?}]
  update(focusPts) {
    const cand = [];
    for (const L of this.lamps) { if (!L.on()) continue; let d = 1e9; for (const f of focusPts) d = Math.min(d, L.pos.distanceToSquared(f)); cand.push([d, L]); }
    cand.sort((a, b) => a[0] - b[0]);
    this.lights.forEach((l, i) => { const c = cand[i]; if (c) { const L = c[1]; l.position.copy(L.pos); l.color.set(L.color || '#ffd9a0'); l.distance = L.range || 9; l.intensity = (L.power || 6) * (L.flicker ? (.6 + Math.random() * .5) : 1); } else { l.intensity = 0; l.position.set(0, -100, 0); } });
  }
}
