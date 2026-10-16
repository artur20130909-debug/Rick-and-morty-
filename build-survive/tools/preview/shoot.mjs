// Снимки превью: node tools/preview/shoot.mjs <папка_с_превью> <папка_для_png>
import { chromium } from 'playwright';
const [dir, out] = [process.argv[2], process.argv[3]];
const scenes = (process.argv[4] || 'overview,build,siege,nukeIncoming,nuke,laser,tank,shop,siegeMenu').split(',');
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') console.log('[page]', m.type(), m.text()); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
let i = 1;
for (const s of scenes) {
  const t = Date.now();
  await page.goto(`${dir}/index.html?scene=${s}`);
  await page.waitForFunction(() => window.READY === true, null, { timeout: 600000 });
  await page.waitForTimeout(300);
  const name = `${out}/${String(i).padStart(2, '0')}_${s}.png`;
  await page.screenshot({ path: name });
  console.log('saved', name, ((Date.now() - t) / 1000).toFixed(1) + 's');
  i++;
}
await browser.close();
