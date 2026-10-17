// Превью-рендер «Build & Survive» на three.js.
// Карта, рельеф и постройки берутся из тех же данных, из которых собирается файл игры
// (map.json — tools/gen_map.py, examples.json — tools/gen_examples.py).
// Эффекты и интерфейс повторяют игровые (Fx.lua, UI/*.lua) по форме, цветам и размерам.
import * as THREE from 'three';
import { Sky } from 'three/addons/objects/Sky.js';
import { Water } from 'three/addons/objects/Water.js';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';

const W = 1600, H = 900;
const params = new URLSearchParams(location.search);
const SCENE = params.get('scene') || 'overview';
const map = await (await fetch('map.json')).json();
const examples = await (await fetch('examples.json')).json();
const ROTS = examples.rotations;

// ---------------------------------------------------------------- случайные числа и шум
let seed = 1234567;
function rand() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }
function rr(a, b) { return a + (b - a) * rand(); }
const P = new Uint8Array(512);
{ const p = [...Array(256).keys()]; for (let i = 255; i > 0; i--) { const j = Math.floor(rand() * (i + 1)); [p[i], p[j]] = [p[j], p[i]]; } for (let i = 0; i < 512; i++) P[i] = p[i & 255]; }
function fade(t) { return t * t * t * (t * (t * 6 - 15) + 10); }
function grad(h, x, y) { const u = (h & 1) ? x : -x, v = (h & 2) ? y : -y; return u + v; }
function noise2(x, y) {
  const X = Math.floor(x) & 255, Y = Math.floor(y) & 255; x -= Math.floor(x); y -= Math.floor(y);
  const u = fade(x), v = fade(y), a = P[X] + Y, b = P[X + 1] + Y;
  return THREE.MathUtils.lerp(THREE.MathUtils.lerp(grad(P[a], x, y), grad(P[b], x - 1, y), u),
    THREE.MathUtils.lerp(grad(P[a + 1], x, y - 1), grad(P[b + 1], x - 1, y - 1), u), v);
}
function fbm(x, y, oct = 4) { let s = 0, a = 0.5, f = 1; for (let i = 0; i < oct; i++) { s += a * noise2(x * f, y * f); a *= 0.5; f *= 2; } return s; }

// ---------------------------------------------------------------- рендерер
const canvas = document.getElementById('c');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, preserveDrawingBuffer: true });
renderer.setSize(W, H, false);
renderer.setPixelRatio(1);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.58;
renderer.outputColorSpace = THREE.SRGBColorSpace;

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(70, W / H, 0.5, 9000);

// ---------------------------------------------------------------- текстуры материалов
function tex(size, draw, repeat = true) {
  const c = document.createElement('canvas'); c.width = c.height = size;
  const g = c.getContext('2d'); draw(g, size);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  if (repeat) { t.wrapS = t.wrapT = THREE.RepeatWrapping; }
  t.anisotropy = 8;
  return t;
}
function noiseFill(g, s, sc, lo, hi, oct = 4, warp = 0) {
  const img = g.createImageData(s, s);
  for (let y = 0; y < s; y++) for (let x = 0; x < s; x++) {
    const n = fbm((x + warp * noise2(y / 30, x / 30) * 20) / sc, y / sc, oct) * 0.5 + 0.5;
    const v = Math.max(0, Math.min(255, (lo + (hi - lo) * n) * 255));
    const i = (y * s + x) * 4; img.data[i] = img.data[i + 1] = img.data[i + 2] = v; img.data[i + 3] = 255;
  }
  g.putImageData(img, 0, 0);
}
const TEX = {
  concrete: () => tex(256, (g, s) => { noiseFill(g, s, 24, 0.78, 1.0, 5); for (let i = 0; i < 900; i++) { g.fillStyle = `rgba(0,0,0,${rr(0.04, 0.14)})`; g.fillRect(rand() * s, rand() * s, rr(1, 3), rr(1, 3)); } }),
  slate: () => tex(256, (g, s) => { noiseFill(g, s, 20, 0.72, 1.0, 5); g.strokeStyle = 'rgba(0,0,0,0.35)'; g.lineWidth = 3; for (let i = 0; i <= 2; i++) { g.beginPath(); g.moveTo(0, i * s / 2); g.lineTo(s, i * s / 2); g.stroke(); g.beginPath(); g.moveTo(i * s / 2 + (i % 2) * 20, 0); g.lineTo(i * s / 2, s); g.stroke(); } }),
  planks: () => tex(256, (g, s) => { noiseFill(g, s, 40, 0.8, 1.0, 3); for (let r = 0; r < 4; r++) { const y = r * s / 4; g.fillStyle = `rgba(0,0,0,${0.06 + r % 2 * 0.05})`; g.fillRect(0, y, s, s / 4); for (let k = 0; k < 18; k++) { g.strokeStyle = `rgba(60,30,0,${rr(0.05, 0.18)})`; g.lineWidth = rr(0.5, 1.6); const yy = y + rand() * s / 4; g.beginPath(); g.moveTo(0, yy); g.bezierCurveTo(s / 3, yy + rr(-4, 4), 2 * s / 3, yy + rr(-4, 4), s, yy); g.stroke(); } g.fillStyle = 'rgba(0,0,0,0.45)'; g.fillRect(0, y, s, 2); const cx = (r * 97) % s; g.fillRect(cx, y, 2, s / 4); } }),
  wood: () => tex(256, (g, s) => { noiseFill(g, s, 50, 0.82, 1.0, 3); for (let k = 0; k < 50; k++) { g.strokeStyle = `rgba(70,35,0,${rr(0.05, 0.2)})`; g.lineWidth = rr(0.6, 2); const x = rand() * s; g.beginPath(); g.moveTo(x, 0); g.bezierCurveTo(x + rr(-10, 10), s / 3, x + rr(-10, 10), 2 * s / 3, x, s); g.stroke(); } }),
  brick: () => tex(256, (g, s) => { g.fillStyle = '#d8d8d8'; g.fillRect(0, 0, s, s); const bh = s / 8, bw = s / 4; for (let r = 0; r < 8; r++) for (let c = -1; c < 5; c++) { const x = c * bw + (r % 2) * bw / 2, y = r * bh; const v = rr(0.78, 1); g.fillStyle = `rgb(${v * 255},${v * 255},${v * 255})`; g.fillRect(x + 2, y + 2, bw - 4, bh - 4); } }),
  cobble: () => tex(256, (g, s) => { g.fillStyle = '#7a7a7a'; g.fillRect(0, 0, s, s); for (let i = 0; i < 70; i++) { const v = rr(0.75, 1); g.fillStyle = `rgb(${v * 255},${v * 255},${v * 255})`; g.beginPath(); g.ellipse(rand() * s, rand() * s, rr(12, 22), rr(10, 18), rand() * 3, 0, 7); g.fill(); } }),
  rock: () => tex(256, (g, s) => noiseFill(g, s, 18, 0.6, 1.0, 6, 1)),
  ground: () => tex(256, (g, s) => noiseFill(g, s, 14, 0.65, 1.0, 5)),
  grass: () => tex(256, (g, s) => { noiseFill(g, s, 30, 0.72, 1.0, 5); for (let i = 0; i < 2500; i++) { g.strokeStyle = `rgba(${rand() < 0.5 ? '255,255,200' : '0,40,0'},${rr(0.05, 0.16)})`; g.lineWidth = 1; const x = rand() * s, y = rand() * s; g.beginPath(); g.moveTo(x, y); g.lineTo(x + rr(-2, 2), y - rr(2, 6)); g.stroke(); } }),
  leafy: () => tex(128, (g, s) => { noiseFill(g, s, 6, 0.55, 1.0, 4); }),
  sand: () => tex(256, (g, s) => { noiseFill(g, s, 40, 0.86, 1.0, 4); for (let i = 0; i < 4000; i++) { g.fillStyle = `rgba(0,0,0,${rr(0.02, 0.09)})`; g.fillRect(rand() * s, rand() * s, 1, 1); } }),
  diamond: () => tex(128, (g, s) => { g.fillStyle = '#bdbdbd'; g.fillRect(0, 0, s, s); for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) { const cx = x * 16 + (y % 2) * 8 + 8, cy = y * 16 + 8; g.save(); g.translate(cx, cy); g.rotate(y % 2 ? 0.8 : -0.8); g.fillStyle = '#f2f2f2'; g.fillRect(-6, -1.6, 12, 3.2); g.fillStyle = '#7a7a7a'; g.fillRect(-6, 1.6, 12, 1); g.restore(); } }),
  brushed: () => tex(256, (g, s) => { g.fillStyle = '#e0e0e0'; g.fillRect(0, 0, s, s); for (let i = 0; i < 400; i++) { g.strokeStyle = `rgba(${rand() < 0.5 ? 0 : 255},${rand() < 0.5 ? 0 : 255},${rand() < 0.5 ? 0 : 255},0.05)`; const y = rand() * s; g.beginPath(); g.moveTo(0, y); g.lineTo(s, y + rr(-1, 1)); g.stroke(); } }),
  rust: () => tex(256, (g, s) => { noiseFill(g, s, 22, 0.6, 1.0, 5, 1); const im = g.getImageData(0, 0, s, s); for (let i = 0; i < im.data.length; i += 4) { const v = im.data[i]; if (v < 150) { im.data[i] = Math.min(255, v * 1.25); im.data[i + 1] = v * 0.9; im.data[i + 2] = v * 0.7; } } g.putImageData(im, 0, 0); }),
  fabric: () => tex(64, (g, s) => { g.fillStyle = '#e8e8e8'; g.fillRect(0, 0, s, s); for (let i = 0; i < s; i += 4) { g.fillStyle = 'rgba(0,0,0,0.08)'; g.fillRect(i, 0, 2, s); g.fillRect(0, i, s, 2); } }),
  marble: () => tex(256, (g, s) => { noiseFill(g, s, 50, 0.9, 1.0, 3); for (let k = 0; k < 10; k++) { g.strokeStyle = `rgba(80,80,90,${rr(0.08, 0.2)})`; g.lineWidth = rr(0.6, 2); g.beginPath(); let x = rand() * s, y = 0; g.moveTo(x, y); for (let t = 0; t < 12; t++) { x += rr(-25, 25); y += s / 12; g.lineTo(x, y); } g.stroke(); } }),
  plastic: () => tex(64, (g, s) => noiseFill(g, s, 10, 0.94, 1.0, 2)),
  hex: () => tex(256, (g, s) => { g.fillStyle = '#000'; g.fillRect(0, 0, s, s); g.strokeStyle = '#fff'; g.lineWidth = 2; const r = 16; for (let y = -1; y < 10; y++) for (let x = -1; x < 10; x++) { const cx = x * r * 1.5, cy = y * r * Math.sqrt(3) + (x % 2) * r * Math.sqrt(3) / 2; g.beginPath(); for (let k = 0; k < 6; k++) { const a = k * Math.PI / 3; g.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r); } g.closePath(); g.stroke(); } }),
};
const texCache = {};
function getTex(name) { if (!texCache[name]) texCache[name] = TEX[name](); return texCache[name]; }

const MAT = {
  SmoothPlastic: { rough: 0.42 }, Plastic: { rough: 0.6, tex: 'plastic', tile: 4 },
  Neon: { neon: true }, Glass: { glass: true }, ForceField: { ff: true },
  Wood: { rough: 0.8, tex: 'wood', tile: 6 }, WoodPlanks: { rough: 0.8, tex: 'planks', tile: 8 },
  Marble: { rough: 0.3, tex: 'marble', tile: 14 }, Slate: { rough: 0.9, tex: 'slate', tile: 10 },
  Concrete: { rough: 0.95, tex: 'concrete', tile: 8 }, Brick: { rough: 0.9, tex: 'brick', tile: 8 },
  Cobblestone: { rough: 0.9, tex: 'cobble', tile: 8 }, Rock: { rough: 0.95, tex: 'rock', tile: 14 },
  CorrodedMetal: { rough: 0.7, metal: 0.55, tex: 'rust', tile: 8 }, DiamondPlate: { rough: 0.38, metal: 0.8, tex: 'diamond', tile: 4 },
  Foil: { rough: 0.18, metal: 1.0 }, Metal: { rough: 0.38, metal: 0.82, tex: 'brushed', tile: 8 },
  Grass: { rough: 1, tex: 'grass', tile: 18 }, LeafyGrass: { rough: 1, tex: 'leafy', tile: 4 },
  Sand: { rough: 1, tex: 'sand', tile: 20 }, Ground: { rough: 1, tex: 'ground', tile: 18 }, Snow: { rough: 0.85, tex: 'sand', tile: 30 },
  Fabric: { rough: 1, tex: 'fabric', tile: 3 }, Basalt: { rough: 0.85, tex: 'rock', tile: 6 }, Rubber: { rough: 0.95 },
  Ice: { glass: true, ice: true }, Water: { rough: 0.1 },
};
const matCache = {};
function srgb(c) { return new THREE.Color().setRGB(c[0] / 255, c[1] / 255, c[2] / 255, THREE.SRGBColorSpace); }
function material(name, color, transparency = 0, reflectance = 0) {
  const key = name + color.join(',') + transparency + reflectance;
  if (matCache[key]) return matCache[key];
  const m = MAT[name] || { rough: 0.5 };
  let mat;
  if (m.neon) {
    const c = srgb(color).multiplyScalar(2.6);
    mat = new THREE.MeshBasicMaterial({ color: c });
  } else if (m.ff) {
    const t = getTex('hex'); t.repeat.set(8, 4);
    mat = new THREE.MeshBasicMaterial({ color: srgb(color).multiplyScalar(1.6), map: t, transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
  } else if (m.glass) {
    mat = new THREE.MeshPhysicalMaterial({ color: srgb(color), roughness: m.ice ? 0.25 : 0.05, metalness: 0.0, transparent: true, opacity: Math.max(0.35, 1 - transparency * 0.9), envMapIntensity: 1.6, clearcoat: 1 });
  } else {
    mat = new THREE.MeshStandardMaterial({ color: srgb(color), roughness: Math.max(0.05, (m.rough ?? 0.5) - reflectance * 0.6), metalness: Math.min(1, (m.metal ?? 0) + reflectance * 0.5) });
    if (m.tex) { mat.map = getTex(m.tex); mat.userData.tile = m.tile; }
    if (transparency > 0) { mat.transparent = true; mat.opacity = 1 - transparency; }
  }
  matCache[key] = mat;
  return mat;
}
function tileOf(name) { return (MAT[name] && MAT[name].tile) || 8; }

// ---------------------------------------------------------------- геометрия деталей
function scaleBoxUV(geo, sx, sy, sz, tile) {
  const uv = geo.attributes.uv;
  const dims = [[sz, sy], [sz, sy], [sx, sz], [sx, sz], [sx, sy], [sx, sy]];
  for (let f = 0; f < 6; f++) for (let k = 0; k < 4; k++) { const i = f * 4 + k; uv.setXY(i, uv.getX(i) * dims[f][0] / tile, uv.getY(i) * dims[f][1] / tile); }
}
function wedgeGeo(sx, sy, sz, tile) {
  const x = sx / 2, y = sy / 2, z = sz / 2;
  // скат смотрит вперёд (-Z) и вверх, вертикальная грань сзади (+Z)
  const v = {
    a: [-x, -y, -z], b: [x, -y, -z], c: [x, -y, z], d: [-x, -y, z], e: [-x, y, z], f: [x, y, z],
  };
  const tris = [
    ['a', 'b', 'f'], ['a', 'f', 'e'], // скат
    ['d', 'c', 'b'], ['d', 'b', 'a'], // низ
    ['d', 'e', 'f'], ['d', 'f', 'c'], // зад
    ['a', 'e', 'd'], // левый бок
    ['b', 'c', 'f'], // правый бок
  ];
  const pos = [], uvs = [];
  for (const t of tris) for (const k of t) { pos.push(...v[k]); const p = v[k]; uvs.push((p[0] + p[2]) / tile, (p[1] + p[2] * 0.5) / tile); }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  g.computeVertexNormals();
  return g;
}
function partMesh(shape, size, matName, color, transparency = 0, reflectance = 0) {
  const [sx, sy, sz] = size;
  const tile = tileOf(matName);
  let geo;
  if (shape === 'Cylinder') {
    const d = Math.min(sy, sz);
    geo = new THREE.CylinderGeometry(d / 2, d / 2, sx, 40, 1);
    const uv = geo.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * Math.PI * d / tile, uv.getY(i) * sx / tile);
    geo.rotateZ(-Math.PI / 2);
  } else if (shape === 'Ball') {
    geo = new THREE.SphereGeometry(0.5, 40, 24);
    geo.scale(sx, sy, sz);
    const uv = geo.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * Math.PI * sx / tile, uv.getY(i) * Math.PI * sy / 2 / tile);
  } else if (shape === 'Wedge') {
    geo = wedgeGeo(sx, sy, sz, tile);
  } else {
    geo = new THREE.BoxGeometry(sx, sy, sz);
    scaleBoxUV(geo, sx, sy, sz, tile);
  }
  const mesh = new THREE.Mesh(geo, material(matName, color, transparency, reflectance));
  const isNeon = MAT[matName] && (MAT[matName].neon || MAT[matName].ff);
  mesh.castShadow = !isNeon && transparency < 0.5;
  mesh.receiveShadow = !isNeon;
  return mesh;
}
function cfMatrix(pos, rot) {
  const m = new THREE.Matrix4();
  m.set(rot[0][0], rot[0][1], rot[0][2], pos[0], rot[1][0], rot[1][1], rot[1][2], pos[1], rot[2][0], rot[2][1], rot[2][2], pos[2], 0, 0, 0, 1);
  return m;
}
function placeMesh(mesh, matrix) { mesh.matrixAutoUpdate = false; mesh.matrix.copy(matrix); scene.add(mesh); return mesh; }

// ---------------------------------------------------------------- небо, солнце, вода
const sky = new Sky(); sky.scale.setScalar(8000); scene.add(sky);
const su = sky.material.uniforms;
su.turbidity.value = 1.2; su.rayleigh.value = 1.25; su.mieCoefficient.value = 0.0025; su.mieDirectionalG.value = 0.86;
const sunDir = new THREE.Vector3();
function setSun(elevDeg, azimDeg) {
  const phi = THREE.MathUtils.degToRad(90 - elevDeg), theta = THREE.MathUtils.degToRad(azimDeg);
  sunDir.setFromSphericalCoords(1, phi, theta);
  su.sunPosition.value.copy(sunDir);
}
setSun(52, 200);
const sun = new THREE.DirectionalLight(0xfff1e0, 3.4);
sun.castShadow = true;
sun.shadow.mapSize.set(4096, 4096);
sun.shadow.bias = -0.0004;
sun.shadow.normalBias = 0.6;
scene.add(sun); scene.add(sun.target);
const hemi = new THREE.HemisphereLight(0xbcd6ff, 0x6b5a45, 0.9); scene.add(hemi);
scene.fog = new THREE.FogExp2(0x9db9dc, 0.00028);

function waterNormals() {
  const s = 256, c = document.createElement('canvas'); c.width = c.height = s; const g = c.getContext('2d');
  const img = g.createImageData(s, s); const hgt = (x, y) => fbm(x / 22, y / 22, 4) + 0.5 * fbm(x / 7 + 40, y / 7, 3);
  for (let y = 0; y < s; y++) for (let x = 0; x < s; x++) {
    const dx = hgt(x + 1, y) - hgt(x - 1, y), dy = hgt(x, y + 1) - hgt(x, y - 1);
    const n = new THREE.Vector3(-dx * 3, -dy * 3, 1).normalize(); const i = (y * s + x) * 4;
    img.data[i] = (n.x * 0.5 + 0.5) * 255; img.data[i + 1] = (n.y * 0.5 + 0.5) * 255; img.data[i + 2] = (n.z * 0.5 + 0.5) * 255; img.data[i + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; return t;
}
const water = new Water(new THREE.PlaneGeometry(9000, 9000), {
  textureWidth: 1024, textureHeight: 1024, waterNormals: waterNormals(), sunDirection: sunDir.clone(),
  sunColor: 0xffffff, waterColor: 0x0f4c58, distortionScale: 2.4, fog: true,
});
water.rotation.x = -Math.PI / 2; water.position.y = 0.02;
water.material.uniforms.size.value = 3.2;
scene.add(water);

// ---------------------------------------------------------------- рельеф
const terrainMats = {
  Sand: material('Sand', [214, 196, 150]), Ground: material('Ground', [110, 92, 70]), Grass: material('Grass', [86, 128, 58]),
  Rock: material('Rock', [120, 118, 112]), Snow: material('Snow', [236, 242, 250]),
};
function bumpySphere(r, detail, amp, freq) {
  const g = new THREE.IcosahedronGeometry(r, detail);
  const p = g.attributes.position; const v = new THREE.Vector3();
  for (let i = 0; i < p.count; i++) { v.fromBufferAttribute(p, i); const n = fbm(v.x / freq + 7, v.z / freq + v.y / freq * 0.7, 4); v.multiplyScalar(1 + n * amp); p.setXYZ(i, v.x, v.y, v.z); }
  g.computeVertexNormals();
  const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * r / 6, uv.getY(i) * r / 6);
  return g;
}
for (const op of map.terrain) {
  if (op.material === 'Water') continue;
  const m = terrainMats[op.material] || terrainMats.Rock;
  let mesh;
  if (op.op === 'Cylinder') {
    if (op.pos[1] + op.height / 2 < -1) continue;
    const g = new THREE.CylinderGeometry(op.radius, op.radius + (op.material === 'Sand' ? 3 : 0.8), op.height, 96, 1);
    const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * op.radius / 4, uv.getY(i) * op.height / 18);
    mesh = new THREE.Mesh(g, m);
    mesh.position.set(...op.pos);
    if (op.material === 'Grass') { // верх острова — отдельный диск с травой, чуть выпуклый
      const top = new THREE.Mesh(new THREE.CircleGeometry(op.radius, 96), m); top.rotation.x = -Math.PI / 2;
      const uv2 = top.geometry.attributes.uv; for (let i = 0; i < uv2.count; i++) uv2.setXY(i, uv2.getX(i) * op.radius / 9, uv2.getY(i) * op.radius / 9);
      top.position.set(op.pos[0], op.pos[1] + op.height / 2 + 0.01, op.pos[2]); top.receiveShadow = true; scene.add(top);
    }
  } else if (op.op === 'Ball') {
    if (op.pos[1] + op.radius < -1) continue;
    const big = op.radius > 40;
    mesh = new THREE.Mesh(bumpySphere(op.radius, big ? 6 : 2, big ? 0.22 : 0.3, big ? op.radius * 0.5 : op.radius * 0.8), m);
    mesh.position.set(...op.pos);
  } else continue;
  mesh.receiveShadow = true; mesh.castShadow = op.op === 'Ball' && op.radius < 40;
  scene.add(mesh);
}

// ---------------------------------------------------------------- детали карты
for (const p of map.parts) {
  const mesh = partMesh(p.shape === 'Block' && p.cls === 'WedgePart' ? 'Wedge' : p.shape, p.size, p.material, p.color, p.transparency);
  placeMesh(mesh, cfMatrix(p.pos, p.rot));
}
// таблички с текстом (в игре это SurfaceGui)
function textPlane(lines, w, h, matrix, opts = {}) {
  const c = document.createElement('canvas'); c.width = Math.round(w * 40); c.height = Math.round(h * 40);
  const g = c.getContext('2d');
  g.fillStyle = opts.bg || 'rgb(22,26,36)'; g.fillRect(0, 0, c.width, c.height);
  if (opts.grad) { const gr = g.createLinearGradient(0, 0, 0, c.height); gr.addColorStop(0, 'rgb(40,50,80)'); gr.addColorStop(1, 'rgb(14,16,24)'); g.fillStyle = gr; g.fillRect(0, 0, c.width, c.height); }
  if (opts.stripe) { g.fillStyle = opts.stripe; g.fillRect(0, 0, c.width, c.height * 0.12); }
  for (const L of lines) {
    g.font = `${L.weight || 900} ${L.size * c.height}px Inter, "Noto Color Emoji"`; g.textAlign = L.align || 'center'; g.textBaseline = 'middle';
    if (L.stroke) { g.lineWidth = L.stroke; g.strokeStyle = L.strokeColor || '#3c1400'; g.strokeText(L.text, L.x * c.width, L.y * c.height); }
    g.fillStyle = L.color || '#fff'; g.fillText(L.text, L.x * c.width, L.y * c.height, c.width * 0.94);
  }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ map: t, toneMapped: true }));
  mesh.material.color.setScalar(1.25);
  placeMesh(mesh, matrix);
}
// табло в лобби: та же позиция, что в gen_map.py
{
  const look = (eye, target) => new THREE.Matrix4().lookAt(new THREE.Vector3(...eye), new THREE.Vector3(...target), new THREE.Vector3(0, 1, 0)).setPosition(...eye);
  // Matrix4.lookAt направляет +Z от target к eye: плоскость смотрит «от цели»
  const m1 = look([0, 19, -30.45], [0, 19, -200]);
  textPlane([
    { text: 'BUILD & SURVIVE', size: 0.36, y: 0.3, x: 0.5, color: '#ffc83c', stroke: 10 },
    { text: 'Построй что угодно — и переживи ракетный шторм', size: 0.11, y: 0.66, x: 0.5, color: '#e6ecff' },
    { text: 'Твой участок уже ждёт тебя • кнопка «ОСАДА» — начать испытание', size: 0.075, y: 0.86, x: 0.5, color: '#96aad2', weight: 700 },
  ], 44, 12, m1, { grad: true });
  const m2 = look([-35.55, 14, 4], [-200, 14, 4]);
  textPlane([{ text: '🏆 РЕКОРДЫ СЕРВЕРА', size: 0.1, y: 0.09, x: 0.5, color: '#ffd250' },
    { text: '1. Builder_Pro — волна 14', size: 0.065, y: 0.26, x: 0.08, align: 'left', color: '#ffd65a', weight: 800 },
    { text: '2. Тёма — волна 11', size: 0.065, y: 0.36, x: 0.08, align: 'left', color: '#e6ecfa', weight: 800 },
    { text: '3. NoobMaster — волна 7', size: 0.065, y: 0.46, x: 0.08, align: 'left', color: '#e6ecfa', weight: 800 }], 16, 14, m2);
  const m3 = look([35.55, 14, 4], [200, 14, 4]);
  textPlane([{ text: 'КАК ИГРАТЬ', size: 0.1, y: 0.09, x: 0.5, color: '#78dcff' },
    { text: '1. Строй на своём участке', size: 0.058, y: 0.25, x: 0.06, align: 'left', weight: 700 },
    { text: '2. Нажми «ОСАДА»', size: 0.058, y: 0.40, x: 0.06, align: 'left', weight: 700 },
    { text: '3. Пули → мины → ракеты → ядерка', size: 0.058, y: 0.55, x: 0.06, align: 'left', weight: 700 },
    { text: '4. Получай золото, покупай броню', size: 0.058, y: 0.70, x: 0.06, align: 'left', weight: 700 },
    { text: '5. Постройка восстановится сама', size: 0.058, y: 0.85, x: 0.06, align: 'left', weight: 700 }], 16, 14, m3);
}

// ---------------------------------------------------------------- участки и постройки
const plots = map.plots.map(p => ({ ...p, m: cfMatrix(p.pos, p.rot) }));
const OWNERS = ['Builder_Pro', 'Тёма', 'NoobMaster', 'Lisa_2014', 'Свободный участок', 'Kirill_RB'];
plots.forEach((p, i) => {
  const sign = p.m.clone().multiply(new THREE.Matrix4().makeTranslation(0, 5.2, -43.76)).multiply(new THREE.Matrix4().makeRotationY(Math.PI));
  textPlane([{ text: OWNERS[i], size: 0.42, y: 0.42, x: 0.5 }, { text: `Участок ${i + 1}`, size: 0.18, y: 0.8, x: 0.5, color: '#b4bed2', weight: 700 }],
    12, 3.8, sign, { stripe: `rgb(${p.color.join(',')})` });
});

const COLOR_CHAR = [28, 22, 18];
function lerpColor(a, b, t) { return a.map((v, i) => Math.round(v + (b[i] - v) * t)); }
const ITEM_DECOR = {
  Wheel: (add, s) => add('Cylinder', [s[0] + 0.1, s[1] * 0.45, s[2] * 0.45], [0, 0, 0], 'Metal', [190, 192, 198]),
  Thruster: (add, s) => { add('Cylinder', [0.3, s[1] * 0.8, s[2] * 0.8], [-s[0] / 2 - 0.15, 0, 0], 'Neon', [255, 140, 40]); add('Cylinder', [0.2, s[1] * 1.1, s[2] * 1.1], [s[0] / 2 + 0.1, 0, 0], 'Metal', [60, 62, 70]); },
  Door: (add, s) => { add('Block', [0.3, 0.3, 0.25], [s[0] / 2 - 0.6, 0, -s[2] / 2 - 0.1], 'Metal', [220, 190, 90]); },
  Flag: (add, s, plotColor) => { add('Block', [0.12, 2.4, 3.2], [0, s[1] / 2 - 1.4, -1.6], 'Fabric', plotColor); add('Ball', [0.6, 0.6, 0.6], [0, s[1] / 2 + 0.25, 0], 'Metal', [240, 200, 70]); },
  TNT: (add, s) => { add('Block', [s[0] + 0.05, 0.25, s[2] + 0.05], [0, s[1] * 0.28, 0], 'SmoothPlastic', [30, 30, 30]); add('Block', [s[0] + 0.05, 0.25, s[2] + 0.05], [0, -s[1] * 0.28, 0], 'SmoothPlastic', [30, 30, 30]); },
  Medkit: (add, s) => { add('Block', [s[0] * 0.6, s[1] * 0.18, 0.06], [0, 0, -s[2] / 2 - 0.03], 'Neon', [230, 40, 40]); add('Block', [s[0] * 0.18, s[1] * 0.6, 0.06], [0, 0, -s[2] / 2 - 0.03], 'Neon', [230, 40, 40]); add('Block', [s[0] * 0.6, 0.06, s[2] * 0.18], [0, s[1] / 2 + 0.03, 0], 'Neon', [230, 40, 40]); add('Block', [s[0] * 0.18, 0.06, s[2] * 0.6], [0, s[1] / 2 + 0.03, 0], 'Neon', [230, 40, 40]); },
  AATurret: (add, s) => {
    add('Block', [1.8, 1, 1.8], [0, s[1] / 2 + 0.5, 0], 'Metal', [56, 66, 56]);
    for (const x of [-0.45, 0.45]) add('Cylinder', [2.6, 0.32, 0.32], [x, s[1] / 2 + 1.5, -0.6], 'Metal', [40, 42, 44], new THREE.Matrix4().makeRotationX(THREE.MathUtils.degToRad(50)).multiply(new THREE.Matrix4().makeRotationY(Math.PI / 2)));
    add('Block', [0.9, 0.5, 0.2], [0, s[1] / 2 + 1.1, 0.7], 'Neon', [255, 70, 50]);
  },
  Shield: (add, s) => { add('Ball', [1.8, 1.8, 1.8], [0, s[1] / 2 + 0.3, 0], 'Neon', [90, 200, 255]); add('Cylinder', [0.3, 2.8, 2.8], [0, s[1] / 2, 0], 'Metal', [180, 190, 205], new THREE.Matrix4().makeRotationZ(Math.PI / 2)); },
  Balloon: (add, s) => add('Block', [0.08, 3, 0.08], [0, -s[1] / 2 - 1.4, 0], 'Fabric', [230, 230, 230]),
};
const ITEM_INFO = {
  1: ['Seat', 'WoodPlanks', 'Block'], 2: ['DriverSeat', 'SmoothPlastic', 'Block'], 3: ['Wheel', 'Rubber', 'Cylinder'], 4: ['Thruster', 'Metal', 'Cylinder'],
  5: ['Balloon', 'SmoothPlastic', 'Ball'], 6: ['Door', 'WoodPlanks', 'Block'], 7: ['Lamp', 'Neon', 'Block'], 8: ['Flag', 'Metal', 'Block'],
  9: ['TNT', 'SmoothPlastic', 'Block'], 10: ['Medkit', 'SmoothPlastic', 'Block'], 11: ['AATurret', 'Metal', 'Block'], 12: ['Shield', 'Metal', 'Block'], 13: ['Guard', 'Fabric', 'Block'],
};
const MAT_INFO = { 1: 'WoodPlanks', 2: 'SmoothPlastic', 3: 'Brick', 4: 'Cobblestone', 5: 'Concrete', 6: 'Glass', 7: 'Ice', 8: 'Neon', 9: 'Fabric', 10: 'Rubber', 11: 'DiamondPlate', 12: 'Glass', 13: 'Metal', 14: 'CorrodedMetal', 15: 'Metal', 16: 'Basalt', 17: 'Foil', 18: 'Glass' };
const MAT_TRANSP = { 6: 0.45, 7: 0.15, 12: 0.3, 18: 0.12 };
const MAT_REFL = { 6: 0.15, 12: 0.25, 15: 0.1, 17: 0.35, 18: 0.3 };
const SHAPES = { 1: 'Block', 2: 'Wedge', 3: 'Block', 4: 'Cylinder', 5: 'Ball' };

// построить один блок; возвращает список мешей
function buildBlock(b, worldMatrix, plotColor, opts = {}) {
  const meshes = [];
  let matName, shape;
  if (b.item > 0) { const info = ITEM_INFO[b.item]; matName = info[1]; shape = info[2]; } else { matName = MAT_INFO[b.mat]; shape = SHAPES[b.shape]; }
  const color = opts.char ? lerpColor(b.color, COLOR_CHAR, opts.char) : b.color;
  if (b.item === 6) { // дверь: коробка + полотно с филёнками и ручкой (как BlockFactory.buildDoor)
    const [w, h, d] = b.size, t = 0.35, dark = color.map(v => Math.round(v * 0.75));
    const add = (size, off, mn, col) => { const m = partMesh('Block', size, mn, col); placeMesh(m, worldMatrix.clone().multiply(new THREE.Matrix4().makeTranslation(...off))); meshes.push(m); };
    add([t, h, d], [-w / 2 + t / 2, 0, 0], 'Wood', dark); add([t, h, d], [w / 2 - t / 2, 0, 0], 'Wood', dark); add([w, t, d], [0, h / 2 - t / 2, 0], 'Wood', dark);
    const lw = w - 2 * t, lh = h - t;
    add([lw, lh, 0.3], [0, -t / 2, 0], 'WoodPlanks', color);
    for (const z of [-0.18, 0.18]) { add([lw * 0.62, lh * 0.3, 0.06], [0, -t / 2 - lh * 0.2, z], 'WoodPlanks', dark); add([lw * 0.35, lh * 0.18, 0.06], [0, -t / 2 + lh * 0.25, z], 'Glass', [170, 214, 235]); add([0.2, 0.2, 0.25], [lw / 2 - 0.45, -t / 2, z * 1.6], 'Metal', [220, 190, 90]); }
    return meshes;
  }
  const main = partMesh(shape, b.size, matName, color, opts.ghost ? 0.55 : (MAT_TRANSP[b.mat] && !b.item ? MAT_TRANSP[b.mat] : 0), MAT_REFL[b.mat] || 0);
  placeMesh(main, worldMatrix); meshes.push(main);
  if (b.item > 0) {
    const key = ITEM_INFO[b.item][0];
    const deco = ITEM_DECOR[key];
    if (deco) deco((shp, size, off, mn, col, rotM) => {
      const m = partMesh(shp, size, mn, col);
      const local = new THREE.Matrix4().makeTranslation(...off); if (rotM) local.multiply(rotM);
      placeMesh(m, worldMatrix.clone().multiply(local)); meshes.push(m);
    }, b.size, plotColor);
    if (key === 'Lamp' && !opts.noLight) { const l = new THREE.PointLight(srgb(b.color), 30, 22, 2); l.position.setFromMatrixPosition(worldMatrix); scene.add(l); }
  }
  if (opts.ghost) for (const m of meshes) { m.material = m.material.clone(); m.material.transparent = true; m.material.opacity = 0.5; m.castShadow = false; }
  return meshes;
}
function placeBuild(plotIdx, buildIdx, opts = {}) {
  const p = plots[plotIdx - 1];
  const bd = examples.builds[buildIdx];
  const placed = [];
  bd.blocks.forEach((b, i) => {
    if (opts.skip && opts.skip(b, i)) return;
    const m = p.m.clone().multiply(new THREE.Matrix4().makeTranslation(...b.pos)).multiply(cfMatrix([0, 0, 0], ROTS[b.rot - 1]));
    const charred = opts.char ? opts.char(b, i) : 0;
    placed.push({ b, m, meshes: buildBlock(b, m, p.color, { char: charred }) });
  });
  return placed;
}
function plotPoint(plotIdx, x, y, z) { return new THREE.Vector3(x, y, z).applyMatrix4(plots[plotIdx - 1].m); }

// ---------------------------------------------------------------- персонаж (R6)
function character(pos, yawDeg, colors = {}) {
  const g = new THREE.Group();
  const add = (size, off, col, mn = 'SmoothPlastic') => { const m = partMesh('Block', size, mn, col); m.position.set(...off); g.add(m); return m; };
  const skin = colors.skin || [245, 205, 48];
  add([2, 2, 1], [0, 3, 0], colors.torso || [13, 105, 172]);
  add([1, 2, 1], [-1.5, 3, 0], skin); add([1, 2, 1], [1.5, 3, 0], skin);
  add([1, 2, 1], [-0.5, 1, 0], colors.legs || [40, 127, 71]); add([1, 2, 1], [0.5, 1, 0], colors.legs || [40, 127, 71]);
  const head = new THREE.Mesh(new THREE.CylinderGeometry(0.62, 0.62, 1.2, 24), material('SmoothPlastic', skin)); head.position.set(0, 4.6, 0); head.castShadow = true; g.add(head);
  for (const x of [-0.25, 0.25]) { const e = new THREE.Mesh(new THREE.BoxGeometry(0.14, 0.24, 0.05), new THREE.MeshBasicMaterial({ color: 0x111111 })); e.position.set(x, 4.72, -0.6); g.add(e); }
  const mouth = new THREE.Mesh(new THREE.TorusGeometry(0.2, 0.035, 6, 16, Math.PI), new THREE.MeshBasicMaterial({ color: 0x111111 })); mouth.rotation.z = Math.PI; mouth.position.set(0, 4.42, -0.61); g.add(mouth);
  g.traverse(o => { if (o.isMesh) { o.castShadow = true; } });
  g.position.copy(pos); g.rotation.y = THREE.MathUtils.degToRad(yawDeg);
  scene.add(g); return g;
}

// ---------------------------------------------------------------- частицы и эффекты
const spriteTex = {
  smoke: tex(128, (g, s) => { for (let i = 0; i < 26; i++) { const x = s / 2 + rr(-26, 26), y = s / 2 + rr(-26, 26), r = rr(14, 34); const gr = g.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, 'rgba(255,255,255,0.32)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.beginPath(); g.arc(x, y, r, 0, 7); g.fill(); } }, false),
  fire: tex(128, (g, s) => { const gr = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2); gr.addColorStop(0, 'rgba(255,255,240,1)'); gr.addColorStop(0.3, 'rgba(255,220,120,0.9)'); gr.addColorStop(0.65, 'rgba(255,110,30,0.45)'); gr.addColorStop(1, 'rgba(120,20,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, s, s); }, false),
  spark: tex(32, (g, s) => { const gr = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.4, 'rgba(255,230,150,0.8)'); gr.addColorStop(1, 'rgba(255,120,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, s, s); }, false),
  glow: tex(128, (g, s) => { const gr = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.2, 'rgba(255,255,255,0.5)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.fillRect(0, 0, s, s); }, false),
};
function sprite(kind, pos, size, color, opacity = 1, additive = false, rot = 0) {
  const m = new THREE.SpriteMaterial({ map: spriteTex[kind], color, transparent: true, opacity, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending, rotation: rot, fog: true });
  const s = new THREE.Sprite(m); s.position.copy(pos); s.scale.setScalar(size); scene.add(s); return s;
}
const SMOKE_DARK = new THREE.Color(0.22, 0.2, 0.19), SMOKE_LIGHT = new THREE.Color(0.62, 0.6, 0.58);
function explosion(pos, R, opts = {}) {
  const hdr = (r, g, b, k) => new THREE.Color(r * k, g * k, b * k);
  sprite('glow', pos, R * 2.2, hdr(1, 0.62, 0.3, 1.1), 0.75, true);
  for (let i = 0; i < 22; i++) {
    const d = new THREE.Vector3(rr(-1, 1), rr(-0.3, 1), rr(-1, 1)).normalize().multiplyScalar(rr(0, R * 0.9));
    const k = rr(0, 1);
    sprite('fire', pos.clone().add(d), rr(R * 0.6, R * 1.25), hdr(1, 0.35 + k * 0.4, 0.08 + k * 0.15, 1.5), rr(0.7, 1), i < 6, rr(0, 6));
  }
  for (let i = 0; i < (opts.smoke ?? 22); i++) {
    const d = new THREE.Vector3(rr(-1, 1), rr(0.1, 1.6), rr(-1, 1)).normalize().multiplyScalar(rr(R * 0.5, R * 1.8));
    sprite('smoke', pos.clone().add(d).add(new THREE.Vector3(0, R * 0.4, 0)), rr(R * 1.2, R * 2.4), SMOKE_DARK.clone().lerp(SMOKE_LIGHT, rand() * 0.4), rr(0.7, 0.95), false, rr(0, 6));
  }
  for (let i = 0; i < 40; i++) {
    const d = new THREE.Vector3(rr(-1, 1), rr(-0.2, 1.2), rr(-1, 1)).normalize().multiplyScalar(rr(R, R * 3.2));
    sprite('spark', pos.clone().add(d), rr(0.4, 1.1), hdr(1, 0.8, 0.4, 4), 1, true);
  }
  for (let i = 0; i < (opts.chunks ?? 8); i++) {
    const d = new THREE.Vector3(rr(-1, 1), rr(0, 1.4), rr(-1, 1)).normalize().multiplyScalar(rr(R * 0.8, R * 2.6));
    const c = partMesh('Block', [rr(0.4, 1.4), rr(0.4, 1), rr(0.4, 1.2)], 'Slate', opts.chunkColor || [70, 66, 62]);
    c.position.copy(pos).add(d); c.rotation.set(rand() * 6, rand() * 6, rand() * 6); scene.add(c);
  }
  const l = new THREE.PointLight(0xffaa66, 120 * R, R * 6, 2); l.position.copy(pos); scene.add(l);
}
function smokeTrail(points, size0, size1, color = new THREE.Color(0.85, 0.84, 0.82)) {
  const curve = new THREE.CatmullRomCurve3(points);
  const n = Math.floor(curve.getLength() / 2.2);
  for (let i = 0; i <= n; i++) {
    const t = i / n; const p = curve.getPoint(t);
    const s = size0 + (size1 - size0) * (1 - t);
    sprite('smoke', p.add(new THREE.Vector3(rr(-0.4, 0.4), rr(-0.4, 0.4), rr(-0.4, 0.4)).multiplyScalar(s * (1 - t))), s * rr(0.8, 1.2), color, 0.18 + 0.5 * t, false, rr(0, 6));
  }
  return curve;
}
function missile(pos, dir, kind = 'Missile') {
  const g = new THREE.Group();
  const big = kind === 'BigMissile', len = big ? 9 : kind === 'Missile' ? 5 : 3.2, d = big ? 1.8 : kind === 'Missile' ? 1.1 : 0.8;
  const body = partMesh('Cylinder', [len, d, d], 'SmoothPlastic', kind === 'Rocket' ? [86, 96, 70] : [232, 234, 238]); body.rotation.y = Math.PI / 2; g.add(body);
  const nose = partMesh('Ball', [d, d, d * 1.6], 'SmoothPlastic', [200, 40, 40]); nose.position.z = -len / 2 - d * 0.3; g.add(nose);
  for (let i = 0; i < 4; i++) { const f = partMesh('Block', [0.12, d * 0.9, d * 1.2], 'Metal', [60, 62, 66]); const a = i * Math.PI / 2; f.position.set(-Math.sin(a) * d * 0.75, Math.cos(a) * d * 0.75, len / 2 - d * 0.6); f.rotation.z = a; g.add(f); }
  g.position.copy(pos); g.lookAt(pos.clone().add(dir)); g.rotateY(Math.PI); // -Z вперёд
  scene.add(g);
  const tail = pos.clone().add(dir.clone().normalize().multiplyScalar(-len / 2 - 0.4));
  sprite('fire', tail, d * 3.2, new THREE.Color(4, 2.4, 1), 1, true);
  sprite('glow', tail, d * 7, new THREE.Color(1.6, 0.8, 0.4), 0.8, true);
  const l = new THREE.PointLight(0xffa060, 300, 30, 2); l.position.copy(tail); scene.add(l);
  return g;
}
function tracer(a, b, color = new THREE.Color(3, 2.3, 0.9), streaks = [0.3, 0.62, 0.88]) {
  const dir = b.clone().sub(a).normalize();
  for (const t of streaks) {
    const p = a.clone().lerp(b, t);
    const m = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.07, 6, 6), new THREE.MeshBasicMaterial({ color }));
    m.position.copy(p); m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir); scene.add(m);
  }
}
function ringMarker(center, r, color, segs = 28, thick = 0.5) {
  for (let i = 0; i < segs; i++) {
    const a = i / segs * Math.PI * 2, len = 2 * Math.PI * r / segs * 0.6;
    const m = new THREE.Mesh(new THREE.BoxGeometry(len, 0.25, thick), new THREE.MeshBasicMaterial({ color: color.clone().multiplyScalar(2.2) }));
    m.position.set(center.x + Math.cos(a) * r, center.y + 0.15, center.z + Math.sin(a) * r); m.rotation.y = -a - Math.PI / 2; scene.add(m);
  }
  const disk = new THREE.Mesh(new THREE.CircleGeometry(r, 48), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.16, depthWrite: false }));
  disk.rotation.x = -Math.PI / 2; disk.position.copy(center).add(new THREE.Vector3(0, 0.12, 0)); scene.add(disk);
}
function billboardText(text, pos, color, size = 6) {
  const c = document.createElement('canvas'); c.width = 256; c.height = 96; const g = c.getContext('2d');
  g.font = '900 64px Inter, "Noto Color Emoji"'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.lineWidth = 8; g.strokeStyle = 'rgba(0,0,0,0.7)'; g.strokeText(text, 128, 48); g.fillStyle = color; g.fillText(text, 128, 48);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: t, depthTest: false, transparent: true, fog: false, color: new THREE.Color(1.9, 1.9, 1.9) })); s.scale.set(size * 2.7, size, 1); s.position.copy(pos); s.renderOrder = 10; scene.add(s);
}
function shieldDome(center, r) {
  const hexTex = getTex('hex');
  const mat = new THREE.ShaderMaterial({
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
    uniforms: { hex: { value: hexTex }, color: { value: new THREE.Color(0.25, 0.7, 1.3) } },
    vertexShader: `varying vec3 vN; varying vec3 vV; varying vec2 vUv; void main(){ vUv = uv; vec4 mv = modelViewMatrix * vec4(position,1.0); vN = normalize(normalMatrix * normal); vV = normalize(-mv.xyz); gl_Position = projectionMatrix * mv; }`,
    fragmentShader: `uniform sampler2D hex; uniform vec3 color; varying vec3 vN; varying vec3 vV; varying vec2 vUv; void main(){ float f = pow(1.0 - abs(dot(vN, vV)), 2.2); float h = texture2D(hex, vUv * vec2(10.0, 5.0)).r; gl_FragColor = vec4(color * (f * 1.1 + h * 0.22 + 0.04), 1.0); }`,
  });
  const m = new THREE.Mesh(new THREE.SphereGeometry(r, 64, 40), mat); m.position.copy(center); scene.add(m);
}
function clouds(n = 16) {
  for (let i = 0; i < n; i++) {
    const a = rand() * Math.PI * 2, r = rr(700, 2600);
    const base = new THREE.Vector3(Math.cos(a) * r, rr(520, 760), Math.sin(a) * r);
    for (let k = 0; k < 9; k++) {
      const s = sprite('smoke', base.clone().add(new THREE.Vector3(rr(-110, 110), rr(-18, 30), rr(-60, 60))), rr(110, 210), new THREE.Color(1.25, 1.25, 1.3), rr(0.55, 0.85));
      s.material.fog = false;
    }
  }
}

// ---------------------------------------------------------------- интерфейс (копия игрового)
const ui = document.getElementById('ui');
function el(html) { const d = document.createElement('div'); d.innerHTML = html.trim(); const n = d.firstChild; ui.appendChild(n); return n; }
const fmt = n => n.toLocaleString('ru-RU').replace(/ /g, ' ');
function hudTop(gold = 12450, blocks = 66) {
  el(`<div class="pill" style="left:16px;top:64px"><div class="coin">$</div><div class="heavy" style="margin-left:10px;font-size:26px;color:var(--gold)">${fmt(gold)}</div></div>`);
  el(`<div class="pill" style="left:196px;top:64px"><div class="emoji" style="font-size:22px;margin-left:10px">🧱</div><div class="heavy" style="margin-left:10px;font-size:20px">${blocks} / 1500</div></div>`);
}
function hudMenu() {
  const items = [['🛒', 'Магазин', '64,170,90'], ['💣', 'Осада', '214,64,52'], ['🚀', 'Испытать', '64,120,220'], ['💾', 'Сохранить', '120,90,210'], ['⚙️', 'Настройки', '70,78,100']];
  el(`<div class="menu">${items.map(i => `<div class="btn" style="background:rgb(${i[2]})"><div class="ico emoji">${i[0]}</div><div class="lbl stroke">${i[1]}</div></div>`).join('')}</div>`);
}
function hudHotbar(active) {
  const tools = [['🔨', 'Строить', '1', 'build'], ['🗑️', 'Удалить', '2', 'delete'], ['🎨', 'Красить', '3', 'paint'], ['💧', 'Пипетка', '4', 'pick']];
  el(`<div class="hotbar">${tools.map(t => `<div class="btn ${t[3] === active ? 'active' : ''}"><div class="key">${t[2]}</div><div class="ico emoji">${t[0]}</div><div class="lbl">${t[1]}</div></div>`).join('')}<div class="btn" style="background:var(--panel3)"><div class="key">Z</div><div class="ico" style="font-size:34px;margin-top:4px">↶</div><div class="lbl">Отмена</div></div></div>`);
}
function hint(text) { el(`<div class="hint stroke">${text}</div>`); }
function toast(text, color, top = 132) { const t = el(`<div class="toast" style="top:${top}px"><i style="background:${color}"></i>${text}</div>`); t.style.left = (800 - t.offsetWidth / 2) + 'px'; }

// иконки блоков: отдельный маленький рендер, как ViewportFrame в игре
const iconRenderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
iconRenderer.setSize(180, 110); iconRenderer.toneMapping = THREE.ACESFilmicToneMapping; iconRenderer.toneMappingExposure = 1.0; iconRenderer.outputColorSpace = THREE.SRGBColorSpace;
function blockIcon(b, w = 180, h = 110) {
  iconRenderer.setSize(w, h);
  const s = new THREE.Scene();
  s.add(new THREE.AmbientLight(0xffffff, 1.3)); const dl = new THREE.DirectionalLight(0xfff6ea, 3); dl.position.set(-1, 1.4, 0.8); s.add(dl);
  s.environment = envTex;
  const grp = new THREE.Group();
  // строим блок во временной сцене
  const meshes = [];
  const saveAdd = scene.add; scene.add = (o) => { grp.add(o); meshes.push(o); return scene; };
  buildBlock(b, new THREE.Matrix4(), [226, 64, 64], { noLight: true });
  scene.add = saveAdd;
  s.add(grp);
  const box = new THREE.Box3().setFromObject(grp); const c = box.getCenter(new THREE.Vector3()); const r = box.getSize(new THREE.Vector3()).length();
  const cam = new THREE.PerspectiveCamera(30, w / h, 0.1, 100);
  cam.position.copy(c).add(new THREE.Vector3(Math.sin(0.6), 0.55, Math.cos(0.6)).normalize().multiplyScalar(r * 1.75 + 1)); cam.lookAt(c);
  iconRenderer.render(s, cam);
  return iconRenderer.domElement.toDataURL();
}
const MATS = [
  ['Дерево', 1, 0, 'Дешёвое и лёгкое. Плавает в воде.', 100, 0.35], ['Пластик', 2, 0, 'Красится в любой цвет. Для декора.', 70, 0.25], ['Кирпич', 3, 120, 'Классика для первого бункера.', 220, 0.5],
  ['Камень', 4, 250, 'Крепкий булыжник.', 320, 0.55], ['Бетон', 5, 400, 'Основа любого бункера.', 420, 0.62], ['Стекло', 6, 60, 'Красиво, но хрупко.', 50, 0.1],
  ['Лёд', 7, 150, 'Скользкий. Плавает.', 90, 0.3], ['Неон', 8, 200, 'Светится. Для красоты.', 80, 0.2], ['Мешки с песком', 9, 300, 'Пули почти не берут.', 260, 0.55],
  ['Резина', 10, 450, 'Гасит ударную волну.', 240, 0.45], ['Металл', 11, 800, 'Рифлёный стальной лист.', 650, 0.7], ['Бронестекло', 12, 1800, 'Видно всё, а пули — нет.', 700, 0.7],
  ['Броня', 13, 1500, 'Танковая броня.', 1000, 0.78], ['Свинец', 14, 2600, 'Лучшая защита от радиации.', 800, 0.7], ['Титан', 15, 4000, 'Лёгкий и сверхпрочный.', 1800, 0.85],
  ['Обсидиан', 16, 7000, 'Почти неразрушим.', 2800, 0.9], ['Золото', 17, 10000, 'Отражает орбитальный лазер.', 500, 0.6], ['Энергокристалл', 18, 12000, 'Сам восстанавливает прочность.', 1500, 0.82],
];
const MAT_COLORS = { 1: [161, 115, 72], 2: [232, 232, 236], 3: [168, 84, 62], 4: [128, 128, 124], 5: [162, 162, 157], 6: [170, 214, 235], 7: [176, 222, 255], 8: [0, 255, 210], 9: [196, 172, 124], 10: [44, 44, 48], 11: [152, 157, 162], 12: [120, 184, 255], 13: [88, 94, 102], 14: [96, 102, 124], 15: [206, 210, 220], 16: [44, 26, 60], 17: [255, 204, 64], 18: [80, 255, 240] };
function matBlock(id, shape = 1) { return { mat: id, shape, item: 0, size: [2, 2, 2], rot: 1, color: MAT_COLORS[id] }; }
const stars = (v, max) => { const n = Math.max(1, Math.min(5, Math.ceil(v / max * 5))); return '★'.repeat(n) + '☆'.repeat(5 - n); };

function buildPanel(selected = 11, unlocked = [1, 2, 3, 4, 5, 9, 11, 13]) {
  const tiles = MATS.slice(0, 9).concat(MATS.slice(9, 12)).map(m => {
    const locked = !unlocked.includes(m[1]);
    return `<div class="tile ${m[1] === selected ? 'sel' : ''}"><img src="${blockIcon(matBlock(m[1]), 86, 70)}"><div class="nm">${m[0]}</div>${locked ? `<div class="lock"><div class="emoji" style="font-size:20px">🔒</div><div class="p">${fmt(m[2])}</div></div>` : ''}</div>`;
  }).join('');
  const pal = ['245,245,245', '190,190,195', '120,122,128', '60,62,68', '22,23,26', '235,64,52', '176,32,40', '255,136,40', '255,196,40', '255,236,120', '130,210,70', '52,150,70', '26,90,56', '64,200,190', '40,140,220', '30,70,170', '120,80,220', '190,70,210', '255,120,190', '255,205,170', '196,140,90', '140,92,56', '92,60,38', '210,190,140', '108,120,80'];
  const m = MATS[selected - 1];
  el(`<div class="buildpanel panel">
    <div class="tabs"><div class="btn active" style="box-shadow:none">Материалы</div><div class="btn">Особые</div></div>
    <div class="tiles">${tiles}</div>
    <div class="heavy" style="font-size:20px;margin-top:8px">${m[0]}</div>
    <div class="sub" style="font-size:14px;margin-top:2px">Прочность ${fmt(m[4])} • Защита ${Math.round(m[5] * 100)}%</div>
    <div class="row">${['■', '◢', '◣', '▬', '●'].map((s, i) => `<div class="btn shape ${i === 0 ? 'active' : ''}" style="${i === 0 ? 'box-shadow:none' : ''}">${s}</div>`).join('')}</div>
    <div class="row" style="gap:8px">${['Ш', 'В', 'Д'].map((a, i) => `<div class="stepper"><span class="sub" style="width:18px;font-size:14px">${a}</span><div class="btn s">−</div><span class="heavy" style="width:26px;text-align:center;font-size:18px">${[4, 2, 2][i]}</span><div class="btn s">+</div></div>`).join('')}</div>
    <div class="row"><div class="btn" style="flex:1;height:36px;font-size:15px">⟳ Повернуть&nbsp; R</div><div class="btn" style="flex:1;height:36px;font-size:15px">⤾ Наклонить&nbsp; T</div></div>
    <div style="display:flex;justify-content:space-between;align-items:center;margin-top:8px"><span class="heavy" style="font-size:16px">Цвет</span><div class="btn active" style="width:160px;height:28px;font-size:14px;box-shadow:none">Как у материала</div></div>
    <div class="swatches">${pal.map(c => `<div class="sw" style="background:rgb(${c})"></div>`).join('')}</div>
  </div>`);
}
function waveBar(title, sub, progress) {
  el(`<div class="wavebar panel"><div class="t">${title}</div><div class="s">${sub}</div><div class="track"><div class="fill" style="width:${progress * 100}%"></div></div></div>`);
  el(`<div class="btn abs" style="left:1070px;top:86px;width:110px;height:44px;background:var(--panel3);font-size:16px">Сдаться</div>`);
}
function warnBanner(text) { el(`<div class="warn">${text}</div>`); }
function bigText(text, sub, color = '#fff') {
  el(`<div class="big" style="top:290px;font-size:64px;color:${color};text-shadow:0 0 1px #000, 3px 3px 0 rgba(40,10,0,.9), -3px -3px 0 rgba(40,10,0,.9), 3px -3px 0 rgba(40,10,0,.9), -3px 3px 0 rgba(40,10,0,.9)">${text}</div>`);
  if (sub) el(`<div class="big" style="top:378px;font-size:26px;color:var(--accent);text-shadow:2px 2px 0 rgba(20,10,0,.9),-2px -2px 0 rgba(20,10,0,.9)">${sub}</div>`);
}
function windowFrame(title, w, h) {
  el(`<div class="shade"></div>`);
  const win = el(`<div class="window" style="left:${800 - w / 2}px;top:${450 - h / 2}px;width:${w}px;height:${h}px"><div class="hdr">${title}</div><div class="btn x">✕</div><div class="body"></div></div>`);
  return win.querySelector('.body');
}
function shopWindow() {
  const body = windowFrame('<span class="emoji" style="margin-right:10px">🛒</span>МАГАЗИН БЛОКОВ', 900, 640);
  body.innerHTML = `<div class="btn abs active" style="left:0;top:0;width:180px;height:42px;box-shadow:none">Материалы</div><div class="btn abs" style="left:190px;top:0;width:180px;height:42px">Особые блоки</div>
    <div class="abs panel" style="right:0;top:0;width:190px;height:42px;background:var(--panel2);display:flex;align-items:center"><div class="coin" style="width:26px;height:26px;font-size:15px">$</div><span class="heavy" style="margin-left:10px;font-size:22px;color:var(--gold)">12 450</span></div>`;
  const owned = [1, 2, 3, 4, 5, 9, 11, 13];
  MATS.slice(0, 8).forEach((m, i) => {
    const x = (i % 4) * 208 + 4, y = 56 + Math.floor(i / 4) * 280 + 4;
    let btn;
    if (m[2] === 0) btn = `<div class="btn b" style="background:var(--panel3)">БЕСПЛАТНО</div>`;
    else if (owned.includes(m[1])) btn = `<div class="btn b" style="background:var(--panel3)">✔ КУПЛЕНО</div>`;
    else btn = `<div class="btn b" style="background:var(--good)">${fmt(m[2])}</div>`;
    const card = document.createElement('div'); card.className = 'card'; card.style.left = x + 'px'; card.style.top = y + 'px';
    card.innerHTML = `<div class="vp"><img src="${blockIcon(matBlock(m[1]))}"></div><div class="n">${m[0]}</div><div class="d">${m[3]}</div><div class="st">Прочность ${stars(m[4], 2800)}<br>Защита от взрыва ${stars(m[5] * 100, 90)}</div>${btn}`;
    body.appendChild(card);
  });
}
const WEAPONS = [['•', 'Пуля'], ['⁂', 'Дробь'], ['⋯', 'Пулемёт'], ['◉', 'Граната'], ['☄', 'Миномёт'], ['➶', 'РПГ'], ['➹', 'Самонаводящаяся ракета'], ['✺', 'Кассетная бомба'], ['✈', 'Крылатая ракета'], ['⇓', 'Баллистическая ракета'], ['☢', 'Ядерная бомба'], ['☼', 'Орбитальный лазер']];
function waveColor(i) { const t = i / 11; const a = [80, 200, 110], b = [255, 190, 50], c = [235, 50, 50]; const m = t < 0.5 ? lerpColor(a, b, t * 2) : lerpColor(b, c, t * 2 - 1); return `rgb(${m.join(',')})`; }
function siegeWindow() {
  const body = windowFrame('<span class="emoji" style="margin-right:10px">💣</span>ОСАДА', 940, 620);
  body.innerHTML = `<div class="abs" style="left:0;top:0;width:442px">
      <div class="mode on"><div class="h"><span class="emoji">🛡️</span> ВЫЖИВАНИЕ</div><div class="p">Волна за волной: пули, мины, ракеты... На 11-й волне — ядерная бомба, на 12-й — орбитальный лазер. Чем дольше живёшь — тем больше золота.</div></div>
      <div class="mode"><div class="h"><span class="emoji">🎯</span> ПОЛИГОН</div><div class="p">Выбирай любое оружие и стреляй по своей постройке сам. Проверь, выдержит ли бункер ядерный удар. Без награды.</div></div>
      <div class="heavy" style="font-size:18px;margin-top:2px">Сложность</div>
      <div style="display:flex;gap:8px;margin-top:8px">${[['Лёгкая', ''], ['Нормальная', 'rgb(255,196,64)'], ['Хардкор', ''], ['Апокалипсис', '']].map(d => `<div class="btn" style="flex:1;height:44px;font-size:15px;${d[1] ? `background:${d[1]};color:#1a1200` : ''}">${d[0]}</div>`).join('')}</div>
      <div class="sub" style="font-size:15px;margin-top:12px">Твой рекорд: волна 9 • Пережито ядерок: 2</div>
      <div class="btn" style="height:64px;margin-top:12px;font-size:26px;background:linear-gradient(180deg,rgb(240,70,70),rgb(170,50,50))">НАЧАТЬ ОСАДУ</div>
    </div>
    <div class="abs panel" style="right:0;top:0;width:442px;height:526px;background:var(--panel);padding:8px 10px">
      <div class="heavy" style="font-size:18px;margin:2px 4px 8px">Что прилетит</div>
      ${WEAPONS.map((w, i) => `<div class="wrow"><div class="bar" style="background:${waveColor(i)}"></div><div class="ic">${w[0]}</div><div class="nm">${w[1]}</div><div class="wv" style="color:${waveColor(i)}">волна ${i + 1}</div></div>`).join('')}
    </div>`;
}
function launchBar() {
  el(`<div class="launchbar panel"><div class="heavy abs" style="left:20px;top:12px;font-size:24px;color:var(--info)"><span class="emoji">🚀</span> ИСПЫТАНИЕ</div>
    <div class="sub abs" style="left:20px;top:48px;width:420px;font-size:15px;font-weight:600">Сядь в кресло водителя: W/S — газ, A/D — поворот. Двигатели работают на W.</div>
    <div class="btn abs" style="right:16px;top:18px;width:140px;height:60px;background:var(--bad);font-size:22px">■ СТОП</div></div>`);
}

// ---------------------------------------------------------------- окружение для отражений
const pmrem = new THREE.PMREMGenerator(renderer);
const skyScene = new THREE.Scene(); const sky2 = new Sky(); sky2.scale.setScalar(1000); skyScene.add(sky2);
let envTex;
function updateEnv() {
  for (const k of ['turbidity', 'rayleigh', 'mieCoefficient', 'mieDirectionalG']) sky2.material.uniforms[k].value = su[k].value;
  sky2.material.uniforms.sunPosition.value.copy(sunDir);
  envTex = pmrem.fromScene(skyScene, 0.02).texture; scene.environment = envTex;
  scene.environmentIntensity = 0.75;
}

// ---------------------------------------------------------------- сцены
function look(pos, target) { camera.position.copy(pos); camera.lookAt(target); }
function focusShadows(center, size = 160) {
  sun.position.copy(center).add(sunDir.clone().multiplyScalar(600)); sun.target.position.copy(center);
  const c = sun.shadow.camera; c.left = -size; c.right = size; c.top = size; c.bottom = -size; c.near = 10; c.far = 1400; c.updateProjectionMatrix();
  water.material.uniforms.sunDirection.value.copy(sunDir);
}
const BUNKER = 1, ROBOT = 2, TANK = 3, HUT = 0;
function defaultWorld(opts = {}) {
  placeBuild(1, ROBOT); placeBuild(3, TANK); placeBuild(6, HUT); placeBuild(4, HUT);
  if (!opts.noBunker) placeBuild(2, BUNKER, opts.bunker || {});
  clouds();
  // игроки на участках
  character(plotPoint(1, -12, 0, -16), 200, { torso: [196, 40, 28], legs: [27, 42, 53] });
  character(plotPoint(3, 10, 0, -14), 160);
  character(new THREE.Vector3(6, 5, 18), 30, { torso: [120, 80, 220], legs: [30, 30, 30], skin: [234, 184, 146] });
  character(new THREE.Vector3(-4, 5, 24), -20);
}

const scenes = {
  overview() {
    setSun(48, 195); updateEnv();
    defaultWorld();
    look(new THREE.Vector3(-150, 150, -240), new THREE.Vector3(10, 0, 120));
    focusShadows(new THREE.Vector3(0, 0, 120), 260);
    hudTop(); hudMenu(); hudHotbar(null); hint('Нажми 1 или «Строить», чтобы начать. Справа — магазин, осада и сохранения.');
  },
  build() {
    setSun(55, 160); updateEnv();
    defaultWorld();
    // призрак блока рядом с роботом
    const b = { mat: 11, shape: 1, item: 0, size: [4, 2, 2], rot: 1, color: [152, 157, 162] };
    const m = plots[0].m.clone().multiply(new THREE.Matrix4().makeTranslation(-9, 4, -7));
    const ghost = buildBlock(b, m, [226, 64, 64], { ghost: true });
    const edges = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(4.05, 2.05, 2.05)), new THREE.LineBasicMaterial({ color: new THREE.Color(0.6, 2.4, 1.0) }));
    edges.matrixAutoUpdate = false; edges.matrix.copy(m); scene.add(edges);
    for (const g of ghost) { g.material.color.lerp(new THREE.Color(0.4, 1, 0.55), 0.35); }
    // сетка на полу участка
    const grid = new THREE.GridHelper(64, 32, 0xffffff, 0x2a2e36); grid.material.transparent = true; grid.material.opacity = 0.35;
    grid.matrixAutoUpdate = false; grid.matrix.copy(plots[0].m.clone().multiply(new THREE.Matrix4().makeTranslation(0, 0.03, 0))); scene.add(grid);
    character(plotPoint(1, -16, 0, -12), 230, { torso: [196, 40, 28], legs: [27, 42, 53] });
    look(plotPoint(1, -30, 26, -40), plotPoint(1, 0, 11, 2));
    focusShadows(plotPoint(1, 0, 0, 0), 90);
    hudTop(12450, 34); hudMenu(); hudHotbar('build'); buildPanel(11);
    hint('ЛКМ — поставить (держи, чтобы ставить подряд) • R — повернуть • T — наклонить • Q — пипетка • Ctrl+Z — отмена');
  },
  siege() {
    setSun(40, 230); updateEnv();
    const hitBlocks = new Set();
    defaultWorld({ bunker: { char: (b) => (b.pos[0] < -10 ? 0.55 : (b.pos[2] < -10 ? 0.25 : 0)), skip: (b, i) => b.key === 'Sandbag' && b.pos[1] < 3 && b.pos[0] < -15 && b.pos[2] > 0 } });
    const P2 = (x, y, z) => plotPoint(2, x, y, z);
    shieldDome(P2(-0.5, 13.5, -0.5), 18);
    // самонаводящиеся ракеты летят из-за бункера (со стороны вражеской базы)
    const m1 = [P2(30, 140, 240), P2(28, 110, 150), P2(10, 60, 60), P2(-22, 26, -6)];
    smokeTrail(m1, 1.4, 5, new THREE.Color(0.7, 0.69, 0.68)); missile(m1[3], m1[3].clone().sub(m1[2]), 'Missile');
    const m2 = [P2(-40, 150, 260), P2(-30, 120, 170), P2(-5, 70, 90), P2(8, 44, 26)];
    smokeTrail(m2, 1.4, 5, new THREE.Color(0.7, 0.69, 0.68)); missile(m2[3], m2[3].clone().sub(m2[2]), 'Missile');
    const r1 = [P2(-90, 22, 300), P2(-60, 18, 160), P2(-30, 14, 60)];
    smokeTrail(r1, 1, 3.6, new THREE.Color(0.62, 0.61, 0.6)); missile(r1[2], r1[2].clone().sub(r1[1]), 'Rocket');
    // взрыв у левой стены и сбитая ракета в небе
    explosion(P2(-17, 5, -4), 10, { chunkColor: [130, 128, 122] });
    explosion(P2(14, 52, 34), 5, { smoke: 10, chunks: 0 });
    for (const t of [P2(-10, 13, -10), P2(10, 13, 10)]) tracer(t, P2(14, 52, 34), new THREE.Color(4, 3.6, 1.6));
    for (let i = 0; i < 6; i++) sprite('smoke', P2(rr(-30, 30), rr(40, 70), rr(-10, 60)), rr(4, 8), new THREE.Color(0.12, 0.11, 0.1), 0.85);
    // трассеры с вышек
    const towers = plots[1].towers.map(t => new THREE.Vector3(...t));
    tracer(towers[0], P2(-12, 6, -14)); tracer(towers[1], P2(10, 5, -14)); tracer(towers[0].clone().add(new THREE.Vector3(0, 0.3, 0)), P2(-13, 8, -13));
    sprite('glow', towers[0], 2.2, new THREE.Color(2, 1.6, 0.8), 0.9, true); sprite('glow', towers[1], 2.2, new THREE.Color(2, 1.6, 0.8), 0.9, true);
    // круг-предупреждение о мине
    ringMarker(P2(8, 0.05, -24), 11, new THREE.Color(1, 0.2, 0.15));
    billboardText('⚠ 2.4', P2(8, 8, -24), '#ff3a2a', 5);
    character(P2(1, 1, 3), 180);
    look(P2(-36, 26, -50), P2(-2, 18, 8));
    focusShadows(P2(0, 0, 0), 110);
    hudTop(12450, 66); hudMenu();
    waveBar('ВОЛНА 7', 'Новое: ➹ Самонаводящаяся ракета', 0.42);
    toast('Щит выдержал удар!', 'var(--good)', 172);
  },
  nukeIncoming() {
    setSun(40, 230); updateEnv();
    defaultWorld();
    const P2 = (x, y, z) => plotPoint(2, x, y, z);
    shieldDome(P2(-0.5, 13.5, -0.5), 18);
    // бомба на парашюте
    const bombPos = P2(2, 66, 0);
    const g = new THREE.Group();
    const body = partMesh('Cylinder', [7, 3.2, 3.2], 'Metal', [78, 88, 70]); body.rotation.z = Math.PI / 2; g.add(body);
    const nose = partMesh('Ball', [3.2, 3.4, 3.2], 'Metal', [78, 88, 70]); nose.position.y = -3.6; g.add(nose);
    const band = partMesh('Cylinder', [0.6, 3.3, 3.3], 'SmoothPlastic', [250, 210, 30]); band.rotation.z = Math.PI / 2; band.position.y = 1.4; g.add(band);
    const chute = partMesh('Ball', [24, 9, 24], 'Fabric', [240, 120, 40]); chute.position.y = 22; g.add(chute);
    for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; const top = new THREE.Vector3(Math.cos(a) * 11, 20, Math.sin(a) * 11), bot = new THREE.Vector3(0, 4.5, 0); const ln = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, top.distanceTo(bot), 4), material('SmoothPlastic', [220, 220, 220])); ln.position.copy(top.clone().add(bot).multiplyScalar(0.5)); ln.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), top.clone().sub(bot).normalize()); g.add(ln); }
    const blink = new THREE.Mesh(new THREE.SphereGeometry(0.3), new THREE.MeshBasicMaterial({ color: new THREE.Color(4, 0.3, 0.3) })); blink.position.set(0, -1.8, -1.7); g.add(blink);
    g.position.copy(bombPos); g.rotation.set(0.06, 0.4, -0.05); g.traverse(o => { if (o.isMesh) o.castShadow = true; }); scene.add(g);
    ringMarker(P2(0, 0.05, 0), 60, new THREE.Color(1, 0.85, 0.1), 48, 1.4);
    billboardText('☢ 6.8', P2(0, 26, -26), '#ffdc28', 8);
    character(P2(0, 1, 4), 160);
    look(P2(-40, 18, -86), P2(0, 42, 6));
    focusShadows(P2(0, 0, 0), 110);
    hudTop(12450, 66); hudMenu();
    waveBar('ВОЛНА 11', 'Новое: ☢ Ядерная бомба', 0.18);
    warnBanner('☢ ЯДЕРНЫЙ УДАР! СПРЯЧЬСЯ ЗА ТОЛСТЫЕ СТЕНЫ!');
  },
  nuke() {
    setSun(30, 230); updateEnv();
    scene.fog.color.set(0xb89a86); scene.fog.density = 0.0006;
    su.turbidity.value = 5; su.rayleigh.value = 1.6;
    defaultWorld({ noBunker: true });
    const P2 = (x, y, z) => plotPoint(2, x, y, z);
    // руины бункера: остались только самые толстые части
    placeBuild(2, BUNKER, { skip: (b) => !['Obsidian', 'Lead', 'Concrete'].includes(b.key) || (b.key === 'Concrete' && b.pos[1] > 2 && rand() < 0.75), char: () => 0.7 });
    const ground = P2(0, 0, 0);
    // огненный шар
    sprite('glow', ground.clone().add(new THREE.Vector3(0, 175, 0)), 260, new THREE.Color(1.2, 0.55, 0.25), 0.5, true);
    // шляпка гриба
    const capC = ground.clone().add(new THREE.Vector3(0, 210, 0));
    for (let i = 0; i < 160; i++) {
      const a = rand() * Math.PI * 2, r = rr(0, 80), y = rr(-26, 34) * (1 - r / 110);
      const p = capC.clone().add(new THREE.Vector3(Math.cos(a) * r, y, Math.sin(a) * r));
      const hot = Math.max(0, 1 - r / 70) * (y < 0 ? 1 : 0.4);
      const col = new THREE.Color(0.36, 0.29, 0.25).lerp(new THREE.Color(1.9, 0.75, 0.25), hot * rand());
      sprite('smoke', p, rr(50, 95), col, rr(0.85, 1), false, rr(0, 6));
    }
    // кольцо вокруг шляпки
    for (let i = 0; i < 40; i++) { const a = i / 40 * Math.PI * 2; sprite('smoke', capC.clone().add(new THREE.Vector3(Math.cos(a) * 92, -24 + rr(-6, 6), Math.sin(a) * 92)), rr(40, 60), new THREE.Color(0.5, 0.42, 0.36), 0.75, false, rr(0, 6)); }
    // ножка
    for (let i = 0; i < 90; i++) { const t = rand(); const p = ground.clone().add(new THREE.Vector3(rr(-12, 12) * (1 + t), t * 190, rr(-12, 12) * (1 + t))); const col = new THREE.Color(0.38, 0.31, 0.27).lerp(new THREE.Color(1.8, 0.7, 0.25), (1 - t) * 0.5); sprite('smoke', p, rr(28, 48), col, 0.95, false, rr(0, 6)); }
    // огонь у основания и пылевая волна
    for (let i = 0; i < 26; i++) sprite('fire', ground.clone().add(new THREE.Vector3(rr(-30, 30), rr(0, 30), rr(-30, 30))), rr(30, 60), new THREE.Color(1.8, 0.7, 0.2), 0.9, i < 8, rr(0, 6));
    for (let i = 0; i < 120; i++) { const a = rand() * Math.PI * 2, r = rr(90, 260); sprite('smoke', ground.clone().add(new THREE.Vector3(Math.cos(a) * r, rr(4, 26), Math.sin(a) * r)), rr(30, 60), new THREE.Color(0.62, 0.55, 0.47), rr(0.5, 0.85), false, rr(0, 6)); }
    // ударная волна
    const ring = new THREE.Mesh(new THREE.TorusGeometry(330, 3, 8, 160), new THREE.MeshBasicMaterial({ color: new THREE.Color(2.6, 2.3, 2.0), transparent: true, opacity: 0.6 }));
    ring.rotation.x = Math.PI / 2; ring.position.copy(ground).add(new THREE.Vector3(0, 3, 0)); scene.add(ring);
    const dome = new THREE.Mesh(new THREE.SphereGeometry(300, 64, 32, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshBasicMaterial({ color: new THREE.Color(1.5, 1.3, 1.1), transparent: true, opacity: 0.07, side: THREE.DoubleSide, depthWrite: false }));
    dome.position.copy(ground); scene.add(dome);
    const l = new THREE.PointLight(0xffb070, 3e5, 900, 2); l.position.copy(ground).add(new THREE.Vector3(0, 150, 0)); scene.add(l);
    sun.color.set(0xffc8a0); hemi.color.set(0xffc8a0);
    look(new THREE.Vector3(60, 34, -150), ground.clone().add(new THREE.Vector3(-20, 110, 0)));
    focusShadows(new THREE.Vector3(0, 0, 0), 260);
    hudTop(12450, 66); hudMenu();
    waveBar('ВОЛНА 11', '☢ Ядерная бомба', 0.34);
    toast('☢ Ты пережил ядерный удар!', 'var(--good)', 172);
  },
  laser() {
    setSun(30, 250); updateEnv();
    defaultWorld({ bunker: { skip: (b) => b.pos[1] > 11.5 && Math.abs(b.pos[0] - 7) < 8 && Math.abs(b.pos[2] + 7) < 8, char: (b) => (b.pos[1] > 8 && Math.abs(b.pos[0] - 7) < 9 && Math.abs(b.pos[2] + 7) < 9 ? 0.65 : 0) } });
    const P2 = (x, y, z) => plotPoint(2, x, y, z);
    const hit = P2(7, 9.2, -7);
    const beamH = 1400;
    const core = new THREE.Mesh(new THREE.CylinderGeometry(2.4, 2.4, beamH, 32, 1, true), new THREE.MeshBasicMaterial({ color: new THREE.Color(3.2, 2.9, 2.6) }));
    core.position.copy(hit).add(new THREE.Vector3(0, beamH / 2, 0)); scene.add(core);
    const glow = new THREE.Mesh(new THREE.CylinderGeometry(7, 7, beamH, 32, 1, true), new THREE.MeshBasicMaterial({ color: new THREE.Color(1.8, 0.18, 0.06), transparent: true, opacity: 0.42, blending: THREE.AdditiveBlending, depthWrite: false }));
    glow.position.copy(core.position); scene.add(glow);
    sprite('glow', hit, 30, new THREE.Color(1.8, 0.7, 0.3), 0.9, true);
    for (let i = 0; i < 70; i++) { const d = new THREE.Vector3(rr(-1, 1), rr(0.2, 1.5), rr(-1, 1)).normalize().multiplyScalar(rr(2, 16)); sprite('spark', hit.clone().add(d), rr(0.5, 1.3), new THREE.Color(4, 2.6, 1), 1, true); }
    for (let i = 0; i < 18; i++) sprite('fire', hit.clone().add(new THREE.Vector3(rr(-4, 4), rr(0, 6), rr(-4, 4))), rr(5, 10), new THREE.Color(3.6, 1.6, 0.5), 0.8, true);
    for (let i = 0; i < 26; i++) sprite('smoke', hit.clone().add(new THREE.Vector3(rr(-6, 6), rr(8, 40), rr(-6, 6))), rr(8, 18), new THREE.Color(0.25, 0.23, 0.22), 0.7);
    const l = new THREE.PointLight(0xff8050, 9000, 120, 2); l.position.copy(hit).add(new THREE.Vector3(0, 4, 0)); scene.add(l);
    // прицел на крыше
    for (let i = 0; i < 16; i++) { const a = i / 16 * Math.PI * 2; const m = new THREE.Mesh(new THREE.BoxGeometry(1.6, 0.2, 0.35), new THREE.MeshBasicMaterial({ color: new THREE.Color(3, 0.2, 0.2) })); m.position.copy(hit).add(new THREE.Vector3(Math.cos(a) * 6.5, 0.4, Math.sin(a) * 6.5)); m.rotation.y = -a; scene.add(m); }
    character(P2(-3, 1, 4), 150);
    look(P2(-26, 34, -40), P2(5, 16, -4));
    focusShadows(P2(0, 0, 0), 110);
    hudTop(12450, 61); hudMenu();
    waveBar('ВОЛНА 12', 'Новое: ☼ Орбитальный лазер', 0.55);
    warnBanner('☼ ОРБИТАЛЬНЫЙ ЛАЗЕР НАВОДИТСЯ НА ТЕБЯ — БЕГИ ПОД КРЫШУ!');
  },
  tank() {
    setSun(50, 120); updateEnv();
    placeBuild(1, ROBOT); placeBuild(2, BUNKER); placeBuild(6, HUT); clouds();
    // танк едет по острову: та же постройка, сдвинутая и повёрнутая (физика испытания)
    const p = plots[2];
    const drive = new THREE.Matrix4().makeTranslation(-8, 0, -52).multiply(new THREE.Matrix4().makeRotationY(0.5));
    const bd = examples.builds[TANK];
    for (const b of bd.blocks) {
      const m = p.m.clone().multiply(drive).multiply(new THREE.Matrix4().makeTranslation(...b.pos)).multiply(cfMatrix([0, 0, 0], ROTS[b.rot - 1]));
      buildBlock(b, m, p.color);
    }
    const tp = (x, y, z) => new THREE.Vector3(x, y, z).applyMatrix4(p.m.clone().multiply(drive));
    character(tp(0, 6, 6), 180 + 28.6);
    for (let i = 0; i < 30; i++) sprite('smoke', tp(rr(-9, 9), rr(0.5, 4), rr(10, 30)), rr(3, 8), new THREE.Color(0.66, 0.6, 0.5), rr(0.25, 0.6));
    // робот-сосед и его игрок
    character(plotPoint(1, -12, 0, -16), 200, { torso: [196, 40, 28], legs: [27, 42, 53] });
    look(plotPoint(3, -34, 16, -96), plotPoint(3, -8, 4, -50));
    focusShadows(plotPoint(3, 0, 0, -40), 110);
    hudTop(12450, 21); hudMenu(); launchBar();
    toast('Испытание! Колёс: 8, двигателей: 0', 'var(--info)');
  },
  house() {
    setSun(42, 150); updateEnv();
    placeBuild(6, HUT); placeBuild(1, ROBOT); clouds();
    character(plotPoint(6, 3, 0, -24), 200, { torso: [196, 40, 28], legs: [27, 42, 53] });
    look(plotPoint(6, -30, 20, -52), plotPoint(6, 2, 7, 0));
    focusShadows(plotPoint(6, 0, 0, 0), 90);
    hudTop(500, 170); hudMenu(); hudHotbar(null);
  },
  shop() {
    setSun(48, 195); updateEnv(); defaultWorld();
    look(new THREE.Vector3(-150, 150, -240), new THREE.Vector3(10, 0, 120)); focusShadows(new THREE.Vector3(0, 0, 120), 260);
    hudTop(); hudMenu(); shopWindow();
  },
  siegeMenu() {
    setSun(40, 230); updateEnv(); defaultWorld();
    look(plotPoint(2, -40, 22, -56), plotPoint(2, -2, 14, 6)); focusShadows(plotPoint(2, 0, 0, 0), 110);
    hudTop(); hudMenu(); siegeWindow();
  },
};

(scenes[SCENE] || scenes.overview)();

// ---------------------------------------------------------------- постобработка
const composer = new EffectComposer(renderer, new THREE.WebGLRenderTarget(W, H, { type: THREE.HalfFloatType, samples: 4 }));
composer.addPass(new RenderPass(scene, camera));
const bloom = new UnrealBloomPass(new THREE.Vector2(W, H), 0.42, 0.5, 1.2);
composer.addPass(bloom);
composer.addPass(new OutputPass());
water.material.uniforms.time.value = 2.3;
composer.render();
if (SCENE === 'shop' || SCENE === 'siegeMenu') canvas.style.filter = 'blur(3px) brightness(0.9)';
window.READY = true;
