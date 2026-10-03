// Сборка игры в один HTML-файл: node build.js  ->  index.html
const fs = require('fs'), path = require('path');
const dir = __dirname, src = path.join(dir, 'src');
const b64 = f => fs.readFileSync(path.join(dir, 'fonts', f)).toString('base64');
const js = fs.readdirSync(src).filter(f => f.endsWith('.js')).sort()
  .map(f => `/* ===== ${f} ===== */\n` + fs.readFileSync(path.join(src, f), 'utf8')).join('\n');
// готовые музыкальные треки (assets/music/*.mp3) встраиваются как data URL
const mdir = path.join(dir, 'assets/music');
const tracks = fs.existsSync(mdir) ? fs.readdirSync(mdir).filter(f => f.endsWith('.mp3')).sort() : [];
const trackJs = 'const MUS_SRC = {' + tracks.map(f => `${JSON.stringify(f.replace(/\.mp3$/, ''))}:"data:audio/mpeg;base64,${fs.readFileSync(path.join(mdir, f)).toString('base64')}"`).join(',\n') + '};\n';
const head = fs.readFileSync(path.join(src, 'head.html'), 'utf8')
  .replace('%FONT_CYR%', b64('pix_cyr.woff2'))
  .replace('%FONT_LAT%', b64('pix_lat.woff2'));
const out = head + '<script>\n' + trackJs + js + '\n</script></body></html>\n';
fs.writeFileSync(path.join(dir, 'index.html'), out);
console.log('index.html', (out.length / 1024).toFixed(1) + ' KB', tracks.length ? '| треки: ' + tracks.join(' ') : '');
