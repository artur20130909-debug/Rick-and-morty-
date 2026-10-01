// Сборка игры в один HTML-файл: node build.js  ->  index.html
const fs = require('fs'), path = require('path');
const dir = __dirname, src = path.join(dir, 'src');
const b64 = f => fs.readFileSync(path.join(dir, 'fonts', f)).toString('base64');
const js = fs.readdirSync(src).filter(f => f.endsWith('.js')).sort()
  .map(f => `/* ===== ${f} ===== */\n` + fs.readFileSync(path.join(src, f), 'utf8')).join('\n');
const head = fs.readFileSync(path.join(src, 'head.html'), 'utf8')
  .replace('%FONT_CYR%', b64('pix_cyr.woff2'))
  .replace('%FONT_LAT%', b64('pix_lat.woff2'));
const out = head + '<script>\n' + js + '\n</script></body></html>\n';
fs.writeFileSync(path.join(dir, 'index.html'), out);
console.log('index.html', (out.length / 1024).toFixed(1) + ' KB');
