/* ================= ФИЗИКА: коллайдеры-коробки, персонаж, лучи ================= */
// Мир столкновений: список AABB. Персонаж — вертикальный цилиндр (круг в XZ + высота).
class CollisionWorld {
  constructor() { this.boxes = []; this.cell = 4; this.grid = new Map(); }
  clear() { this.boxes.length = 0; this.grid.clear(); }
  // b: {x0,y0,z0,x1,y1,z1, on?:bool, tag?}
  add(b) { b.on = b.on !== false; this.boxes.push(b); this._index(b); return b; }
  addBox(cx, cy, cz, sx, sy, sz, tag) { return this.add({ x0: cx - sx / 2, x1: cx + sx / 2, y0: cy - sy / 2, y1: cy + sy / 2, z0: cz - sz / 2, z1: cz + sz / 2, tag }); }
  _index(b) { const c = this.cell; for (let i = Math.floor(b.x0 / c); i <= Math.floor(b.x1 / c); i++) for (let k = Math.floor(b.z0 / c); k <= Math.floor(b.z1 / c); k++) { const key = i * 10007 + k; let a = this.grid.get(key); if (!a) this.grid.set(key, a = []); a.push(b); } }
  near(x, z, r) {
    const c = this.cell, out = new Set();
    for (let i = Math.floor((x - r) / c); i <= Math.floor((x + r) / c); i++) for (let k = Math.floor((z - r) / c); k <= Math.floor((z + r) / c); k++) { const a = this.grid.get(i * 10007 + k); if (a) for (const b of a) if (b.on) out.add(b); }
    return out;
  }
  // перекрытие круга (x,z,r) с коробкой в плоскости XZ
  static circleHit(b, x, z, r) { const cx = clamp(x, b.x0, b.x1), cz = clamp(z, b.z0, b.z1); return (x - cx) ** 2 + (z - cz) ** 2 < r * r; }
  // высота пола под кругом (наивысшая верхняя грань ≤ maxY)
  groundAt(x, z, r, maxY) { let g = -50; for (const b of this.near(x, z, r)) if (b.y1 <= maxY + 1e-4 && b.y1 > g && CollisionWorld.circleHit(b, x, z, r * .7)) g = b.y1; return g; }
  ceilingAt(x, z, r, minY) { let c = 1e9; for (const b of this.near(x, z, r)) if (b.y0 >= minY - 1e-4 && b.y0 < c && CollisionWorld.circleHit(b, x, z, r * .8)) c = b.y0; return c; }
  // свободно ли место для тела
  blocked(x, y, z, r, h, step) { for (const b of this.near(x, z, r)) if (b.y1 > y + step && b.y0 < y + h && CollisionWorld.circleHit(b, x, z, r)) return b; return null; }
  // луч по коробкам (для видимости и прицела). Возвращает расстояние до первого попадания или Infinity
  ray(ox, oy, oz, dx, dy, dz, maxD, filter) {
    let best = maxD; const steps = Math.ceil(maxD / this.cell) + 1, seen = new Set();
    for (let s = 0; s <= steps; s++) {
      const px = ox + dx * s * this.cell, pz = oz + dz * s * this.cell;
      for (const b of this.near(px, pz, this.cell)) {
        if (seen.has(b)) continue; seen.add(b); if (filter && !filter(b)) continue;
        const t = rayBox(ox, oy, oz, dx, dy, dz, b); if (t >= 0 && t < best) best = t;
      }
      if (s * this.cell > best) break;
    }
    return best;
  }
  los(a, b, filter) { const dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z, d = Math.hypot(dx, dy, dz); if (d < 1e-3) return true; return this.ray(a.x, a.y, a.z, dx / d, dy / d, dz / d, d, filter) >= d - .05; }
}
function rayBox(ox, oy, oz, dx, dy, dz, b) {
  let tmin = -Infinity, tmax = Infinity;
  for (const [o, d, lo, hi] of [[ox, dx, b.x0, b.x1], [oy, dy, b.y0, b.y1], [oz, dz, b.z0, b.z1]]) {
    if (Math.abs(d) < 1e-9) { if (o < lo || o > hi) return -1; continue; }
    let t1 = (lo - o) / d, t2 = (hi - o) / d; if (t1 > t2) [t1, t2] = [t2, t1];
    tmin = Math.max(tmin, t1); tmax = Math.min(tmax, t2); if (tmin > tmax) return -1;
  }
  return tmax < 0 ? -1 : Math.max(0, tmin);
}

// Контроллер персонажа (общий для игроков и угроз)
class Body {
  constructor(o = {}) { this.p = new V3(o.x || 0, o.y || 0, o.z || 0); this.v = new V3(); this.r = o.r || .32; this.h = o.h || 1.75; this.step = o.step || .42; this.ground = true; this.yaw = 0; this.pitch = 0; }
  move(world, wx, wz, dt, jump) {
    // горизонталь по осям раздельно — скольжение вдоль стен
    const nx = this.p.x + wx * dt, nz = this.p.z + wz * dt;
    if (!world.blocked(nx, this.p.y, this.p.z, this.r, this.h, this.step)) this.p.x = nx;
    if (!world.blocked(this.p.x, this.p.y, nz, this.r, this.h, this.step)) this.p.z = nz;
    // вертикаль
    const g = world.groundAt(this.p.x, this.p.z, this.r, this.p.y + this.step);
    if (jump && this.ground) { this.v.y = 6.2; this.ground = false; }
    this.v.y -= 20 * dt; let ny = this.p.y + this.v.y * dt;
    if (this.v.y > 0) { const c = world.ceilingAt(this.p.x, this.p.z, this.r, this.p.y + this.h); if (ny + this.h > c) { ny = c - this.h; this.v.y = 0; } }
    if (this.ground && this.v.y <= 0 && this.p.y - g <= this.step) { ny = g; this.v.y = 0; } // прилипание к полу/ступеням
    else if (ny <= g) { ny = g; this.v.y = 0; this.ground = true; }
    else this.ground = false;
    this.p.y = ny;
    if (this.p.y < -30) { this.p.y = 5; this.v.y = 0; }
  }
}
