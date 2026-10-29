// node render.js scene1.json out1.png [scene2.json out2.png ...]
// Рисует сцены песочницы в безголовом Chromium (WebGL2 через SwiftShader).
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const args = process.argv.slice(2);
  if (args.length < 2 || args.length % 2) {
    console.error('usage: node render.js scene.json out.png [...]');
    process.exit(2);
  }
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  let failed = false;
  page.on('console', (m) => { if (m.type() === 'error') { console.log('page:', m.text()); } });
  page.on('pageerror', (e) => { console.log('pageerror:', e.message); failed = true; });
  await page.goto('file://' + path.join(__dirname, 'render.html'));
  for (let i = 0; i < args.length; i += 2) {
    const scene = JSON.parse(fs.readFileSync(args[i], 'utf8'));
    const w = scene.width || 1280, h = scene.height || 720;
    await page.setViewportSize({ width: w, height: h });
    const t0 = Date.now();
    try {
      await page.evaluate((s) => window.renderScene(s), scene);
    } catch (e) {
      console.log('render error:', e.message.slice(0, 2000));
      failed = true;
      continue;
    }
    await page.screenshot({ path: args[i + 1], clip: { x: 0, y: 0, width: w, height: h } });
    console.log('rendered', args[i + 1], (Date.now() - t0) + 'ms', scene.parts.length, 'parts');
  }
  await browser.close();
  process.exit(failed ? 1 : 0);
})();
