// Рендер интерфейса Roblox (выгрузка tools/mock/gui.lua) в HTML поверх 3D-превью.
// Приближение: позиции/размеры UDim2, AnchorPoint, UIListLayout (flex), UIPadding, UICorner,
// UIStroke, UIGradient, UIScale, AutomaticSize, TextScaled, выравнивание текста.
const FONT_MAP = { Nunito: 'Nunito', Montserrat: 'Montserrat', GothamSSm: 'Montserrat', BuilderSans: 'Montserrat',
  AmaticSC: 'Amatic SC', Inconsolata: 'JetBrains Mono', SourceSansPro: 'Montserrat', RobotoMono: 'JetBrains Mono' };
const rgba = (c, a) => `rgba(${Math.round(c[0] * 255)},${Math.round(c[1] * 255)},${Math.round(c[2] * 255)},${a})`;
function gradientCss(g, baseAlpha) {
  const times = new Set();
  g.c.forEach(k => times.add(k[0])); g.t.forEach(k => times.add(k[0]));
  const ts = [...times].sort((a, b) => a - b);
  const at = (seq, t, n) => { for (let i = 0; i < seq.length - 1; i++) { const a = seq[i], b = seq[i + 1];
      if (t >= a[0] && t <= b[0]) { const u = (t - a[0]) / Math.max(1e-6, b[0] - a[0]); return a.slice(1).map((v, j) => v + (b[j + 1] - v) * u); } }
    return seq[seq.length - 1].slice(1); };
  const stops = ts.map(t => { const c = at(g.c, t); const tr = at(g.t, t)[0]; return `${rgba(c, baseAlpha * (1 - tr))} ${(t * 100).toFixed(1)}%`; });
  return `linear-gradient(${90 + g.r}deg, ${stops.join(',')})`;
}
function build(n, parent, inList, bill) {
  const el = document.createElement(n.text !== undefined ? 'div' : 'div');
  el.dataset.name = n.n;
  const st = el.style;
  st.boxSizing = 'border-box';
  st.position = inList ? 'relative' : 'absolute';
  st.flex = 'none';
  const sx = n.size, px = n.pos;
  st.width = `calc(${sx[0] * 100}% + ${sx[1]}px)`;
  st.height = `calc(${sx[2] * 100}% + ${sx[3]}px)`;
  if (n.auto === 'X' || n.auto === 'XY') { st.width = 'max-content'; st.minWidth = `calc(${sx[0] * 100}% + ${sx[1]}px)`; }
  if (n.auto === 'Y' || n.auto === 'XY') { st.height = 'auto'; st.minHeight = `calc(${sx[2] * 100}% + ${sx[3]}px)`; }
  const tf = [];
  if (!inList) {
    st.left = `calc(${px[0] * 100}% + ${px[1]}px)`; st.top = `calc(${px[2] * 100}% + ${px[3]}px)`;
    tf.push(`translate(${-n.ap[0] * 100}%, ${-n.ap[1] * 100}%)`);
  }
  if (n.rot) tf.push(`rotate(${n.rot}deg)`);
  if (n.scale !== undefined && n.scale !== 1) { tf.push(`scale(${n.scale})`); }
  st.transform = tf.join(' ');
  st.transformOrigin = `${n.ap[0] * 100}% ${n.ap[1] * 100}%`;
  st.zIndex = n.z;
  if (inList) st.order = n.lo;
  const bgA = 1 - n.bgT;
  if (n.grad && bgA > 0.001) st.background = gradientCss(n.grad, bgA);
  else if (bgA > 0.001) st.background = rgba(n.bg, bgA);
  if (n.clip) st.overflow = 'hidden';
  if (n.pad) st.padding = `${n.pad[1]}px ${n.pad[2]}px ${n.pad[3]}px ${n.pad[0]}px`;
  if (n.stroke && n.stroke.m === 'Border' || (n.stroke && n.text === undefined)) {
    st.boxShadow = `0 0 0 ${n.stroke.t}px ${rgba(n.stroke.c, 1 - n.stroke.tr)}`;
  }
  if (n.text !== undefined) {
    st.display = 'flex';
    st.alignItems = n.ya === 'Top' ? 'flex-start' : n.ya === 'Bottom' ? 'flex-end' : 'center';
    st.justifyContent = n.xa === 'Left' ? 'flex-start' : n.xa === 'Right' ? 'flex-end' : 'center';
    const t = document.createElement('span');
    t.textContent = n.text;
    t.style.fontFamily = `'${FONT_MAP[n.font.f] || n.font.f}', 'Montserrat', sans-serif`;
    t.style.fontWeight = n.font.w;
    t.style.fontStyle = n.font.i ? 'italic' : 'normal';
    t.style.fontSize = n.ts + 'px';
    t.style.lineHeight = n.lh;
    t.style.whiteSpace = n.wrap ? 'pre-wrap' : 'pre';
    t.style.textAlign = n.xa === 'Left' ? 'left' : n.xa === 'Right' ? 'right' : 'center';
    t.style.width = n.wrap ? '100%' : 'auto';
    t.style.color = rgba(n.tc, 1 - n.tt);
    if (n.grad && bgA <= 0.001) { t.style.background = gradientCss(n.grad, 1); t.style.webkitBackgroundClip = 'text'; t.style.color = 'transparent'; }
    if (n.stroke && n.stroke.m !== 'Border') {
      t.style.webkitTextStroke = `${n.stroke.t * 2}px ${rgba(n.stroke.c, 1 - n.stroke.tr)}`;
      t.style.paintOrder = 'stroke fill';
    }
    if (n.sc) t.dataset.scaled = '1';
    el.appendChild(t);
  }
  if (n.list) {
    st.display = 'flex';
    const vert = n.list.d === 'Vertical';
    st.flexDirection = vert ? 'column' : 'row';
    st.gap = n.list.p + 'px';
    const H = { Left: 'flex-start', Center: 'center', Right: 'flex-end' }[n.list.h];
    const V = { Top: 'flex-start', Center: 'center', Bottom: 'flex-end' }[n.list.v];
    st.justifyContent = vert ? V : H;
    st.alignItems = vert ? H : V;
  }
  if (n.corner) el.dataset.corner = JSON.stringify(n.corner);
  parent.appendChild(el);
  for (const k of n.kids) {
    if (['UICorner'].includes(k.cls)) continue;
    build(k, el, !!n.list);
  }
  return el;
}
export function renderGui(gui, camera, THREE, W, H) {
  const layer = document.createElement('div');
  Object.assign(layer.style, { position: 'absolute', left: 0, top: 0, width: W + 'px', height: H + 'px', overflow: 'hidden' });
  document.body.appendChild(layer);
  const screens = [...gui.screens].sort((a, b) => a.order - b.order);
  for (const s of screens) {
    const root = document.createElement('div');
    Object.assign(root.style, { position: 'absolute', left: 0, top: s.inset ? '58px' : 0, width: W + 'px', height: (s.inset ? H - 58 : H) + 'px', zIndex: s.order + 10 });
    layer.appendChild(root);
    for (const k of s.kids) build(k, root, false);
  }
  // билборды (подсказки, маркер) — проецируем точку на экран
  for (const b of gui.bills) {
    const p = new THREE.Vector3(b.p[0] + b.so[0], b.p[1] + b.so[1], b.p[2] + b.so[2]).project(camera);
    if (p.z > 1) continue;
    const x = (p.x + 1) / 2 * W, y = (1 - p.y) / 2 * H;
    const w = b.size[1], h = b.size[3];
    const root = document.createElement('div');
    Object.assign(root.style, { position: 'absolute', left: (x - w / 2 + b.sizeOff[0] * w) + 'px', top: (y - h / 2 - b.sizeOff[1] * h) + 'px', width: w + 'px', height: h + 'px', zIndex: 5 });
    layer.appendChild(root);
    for (const k of b.kids) build(k, root, false);
  }
  // экраны телефона — отдельной картинкой справа
  let off = 0;
  for (const s of gui.surfaces) {
    const root = document.createElement('div');
    const sc = Math.min(1, (H - 40) / s.h);
    Object.assign(root.style, { position: 'absolute', right: (20 + off) + 'px', top: '20px', width: s.w + 'px', height: s.h + 'px', zIndex: 100,
      transform: `scale(${sc})`, transformOrigin: 'top right', outline: '3px solid #b8f03a', overflow: 'hidden', background: '#000' });
    layer.appendChild(root);
    for (const k of s.kids) build(k, root, false);
    off += s.w * sc + 16;
  }
  // скругления и масштаб текста (после раскладки)
  for (const el of layer.querySelectorAll('[data-corner]')) {
    const c = JSON.parse(el.dataset.corner);
    const r = el.getBoundingClientRect();
    el.style.borderRadius = (c[0] * Math.min(r.width, r.height) + c[1]) + 'px';
  }
  for (const t of layer.querySelectorAll('span[data-scaled]')) {
    const box = t.parentElement;
    let size = 100;
    t.style.fontSize = size + 'px';
    while (size > 6 && (t.scrollWidth > box.clientWidth || t.scrollHeight > box.clientHeight)) { size -= 2; t.style.fontSize = size + 'px'; }
  }
}

// экран SurfaceGui в мире → canvas (для текстуры three.js). Шрифты внутри SVG-картинки — системные.
export async function surfaceCanvas(g) {
  const w = Math.max(8, Math.round(g.w)), h = Math.max(8, Math.round(g.h));
  const box = document.createElement('div');
  Object.assign(box.style, { position: 'absolute', left: '-20000px', top: '0px', width: w + 'px', height: h + 'px', overflow: 'hidden' });
  document.body.appendChild(box);
  for (const k of g.kids) build(k, box, false);
  for (const el of box.querySelectorAll('[data-corner]')) {
    const c = JSON.parse(el.dataset.corner);
    const r = el.getBoundingClientRect();
    el.style.borderRadius = (c[0] * Math.min(r.width, r.height) + c[1]) + 'px';
  }
  for (const t of box.querySelectorAll('span[data-scaled]')) {
    const p = t.parentElement;
    let size = Math.max(8, Math.min(200, p.clientHeight));
    t.style.fontSize = size + 'px';
    while (size > 6 && (t.scrollWidth > p.clientWidth || t.scrollHeight > p.clientHeight)) { size -= 2; t.style.fontSize = size + 'px'; }
  }
  box.style.position = 'relative'; box.style.left = '0px';
  const xml = new XMLSerializer().serializeToString(box);
  document.body.removeChild(box);
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><foreignObject x="0" y="0" width="${w}" height="${h}">${xml}</foreignObject></svg>`;
  const img = new Image();
  img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
  try { await img.decode(); } catch (e) { return null; }
  const k = Math.min(1, 1024 / Math.max(w, h));
  const cv = document.createElement('canvas'); cv.width = Math.round(w * k); cv.height = Math.round(h * k);
  const cx = cv.getContext('2d');
  cx.drawImage(img, 0, 0, cv.width, cv.height);
  return cv;
}
