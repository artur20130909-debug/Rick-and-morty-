// node tools/render/shot.js <снимок.json> <out.jpg> [query] [снимок.gui.json] — картинка превью сцены (+ интерфейс)
// three.js берётся из ../../../amber-alert/vendor, шрифты — tools/render/fonts (см. README, раздел «Песочница»)
const { chromium } = require('playwright');
const path = require('path'), fs = require('fs'), http = require('http');
(async () => {
  const [snap, out, extra, guiPath] = process.argv.slice(2);
  const dir = __dirname;
  const server = http.createServer((req, res) => {
    const u = decodeURIComponent(req.url.split('?')[0]);
    const f = u.startsWith('/snapg/') ? path.resolve(guiPath) : u.startsWith('/snap/') ? path.resolve(snap)
      : u === '/three.module.min.js' ? path.join(dir, '../../../amber-alert/vendor/three.module.min.js') : path.join(dir, u);
    fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; }
      res.writeHead(200, { 'Content-Type': f.endsWith('.js') ? 'text/javascript' : f.endsWith('.json') ? 'application/json' : f.endsWith('.woff2') ? 'font/woff2' : 'text/html' }); res.end(d); });
  }).listen(0);
  const port = server.address().port;
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
  p.on('pageerror', e => console.log('pageerror:', e.message));
  p.on('console', m => { if (m.type() === 'error') console.log('console:', m.text()); });
  await p.goto(`http://127.0.0.1:${port}/render.html?f=/snap/x.json${guiPath ? '&g=/snapg/g.json' : ''}&${extra || ''}`);
  await p.waitForFunction('window.READY !== undefined', null, { timeout: 120000 });
  await p.screenshot({ path: out, type: 'jpeg', quality: 85 });
  console.log('ok', out, await p.evaluate('window.READY'));
  await b.close(); server.close();
})();
