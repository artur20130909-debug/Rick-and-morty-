/* ================= КОСМОС: Цитадель Риков и сцены полёта (прилёт / побег) =================
   drawSpaceScene(k, back, crew) рисует ВЕСЬ кадр полёта: k — кадр сцены (60 в секунду), back=false — прилёт, true — побег;
   crew — функция, рисующая экипаж в кабине корабля (передаётся в ship(..., { crew })).
   SPACE_LEN.in / SPACE_LEN.out — сколько кадров длится полёт до затемнения (сюжет ждёт SCENE.t > SPACE_LEN.*). */
const SPACE_LEN = { in: 420, out: 360 };
function drawCitadel(cx, cy, s, o = {}) {
  x.save(); x.translate(cx, cy); x.scale(s, s);
  if (o.gold) { x.save(); x.globalCompositeOperation = 'lighter'; E(0, 0, 140 + sin(T / 5) * 6, 100, rgrad(0, 0, 10, 140, [[0, 'rgba(255,220,100,.9)'], [1, 'rgba(255,200,60,0)']]), null); x.restore(); }
  const br = o.broken || 0;
  for (let i = -6; i <= 6; i++) { const h = 30 + ((i * 37) % 23 + 23) % 23 * 2, w = 8 + (i % 2 ? 4 : 0), dx = i * 13 + (br ? sin(i * 3 + T / 10) * br * 20 : 0), dy = br ? -br * 30 * abs(sin(i)) : 0; R(dx - w / 2, -h - 6 + dy, w, h, '#8a96a8', OL, .7); R(dx - w / 2, 6 - dy, w, h * .7, '#6a7688', OL, .7); for (let j = 0; j < h / 8; j++) R(dx - w / 2 + 2, -h + j * 8 + dy, w - 4, 2, '#ffe9a0', null); }
  E(0, 0, 100, 16, '#9aa6b8'); E(0, -3, 92, 10, '#b8c4d4', null); R(-6, -70, 12, 64, '#c8d4e4', OL); PG([-6, -70, 6, -70, 0, -96], '#e8f0ff');
  x.restore();
}
function drawSpaceScene(k, back, crew) {
  x.fillStyle = grad(0, 0, 0, H, [[0, '#02030c'], [1, back ? '#2a1a08' : '#0c0a2a']]); x.fillRect(0, 0, W, H);
  for (let i = 0; i < 120; i++) { const sx = ((i * 137.7) - k * (2 + (i % 5))) % (W + 40); const xx = sx < 0 ? sx + W + 40 : sx; LN(xx, (i * 71.3) % H, xx + 6 + (i % 5) * 2, (i * 71.3) % H, 'rgba(255,255,255,' + (.3 + (i % 4) * .15) + ')', 1); }
  if (!back) drawCitadel(560 - Math.min(k, 600) * .25, 170, .4 + Math.min(k, 600) / 600 * 1.4);
  else { drawCitadel(140 + k * .05, 170, 1.4 - Math.min(k, 500) / 500 * .9, { gold: 1, broken: Math.min(1, k / 300) }); }
  ship(back ? 400 + sin(k / 40) * 10 : 220 + sin(k / 40) * 10, 210 + sin(k / 25) * 8, { fly: 1, sc: .8, crew });
}
// силуэт города Цитадели для окон/фонов локаций: прямоугольник [X,Y,w,h] в координатах фона; o.gold — золотое сияние (побег), o.alarm — красная тревога
function citadelSkyline(X, Y, w, h, o = {}) {
  x.save(); x.beginPath(); x.rect(X, Y, w, h); x.clip();
  R(X, Y, w, h, grad(0, Y, 0, Y + h, [[0, '#04061a'], [1, o.gold ? '#5a3a10' : '#14103a']]));
  for (let i = 0; i < w * h / 300; i++) E(X + (i * 97.3) % w, Y + (i * 61.7) % h, .8, .8, '#fff', null);
  for (let i = 0; i < w / 18; i++) { const tw = 8 + (i * 7) % 9, th = h * (.25 + ((i * 37) % 50) / 100), tx0 = X + i * 18 + (i * 5) % 7; R(tx0, Y + h - th, tw, th, '#5a6a80', null); for (let j = 0; j < th / 7; j++) R(tx0 + 2, Y + h - th + 3 + j * 7, tw - 4, 1.5, o.alarm && j % 2 ? '#ff5a5a' : '#ffe9a0', null); }
  x.restore();
}
