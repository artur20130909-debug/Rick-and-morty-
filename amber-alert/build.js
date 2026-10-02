// Сборка игры в один HTML-файл: node build.js  ->  index.html (рядом)
// three.js (ES-модуль) заворачивается в функцию, чтобы его имена не пересекались с кодом игры.
const fs = require('fs'), path = require('path');
const dir = __dirname, src = path.join(dir, 'src');
let three = fs.readFileSync(path.join(dir, 'vendor/three.module.min.js'), 'utf8');
const m = three.match(/export\s*\{([^}]*)\}\s*;?\s*$/);
if (!m) throw new Error('three: export statement not found');
const pairs = m[1].split(',').map(s => s.trim()).filter(Boolean).map(s => { const p = s.split(/\s+as\s+/); return p.length === 2 ? `${p[1]}:${p[0]}` : `${p[0]}:${p[0]}`; });
three = 'const THREE=(()=>{' + three.slice(0, m.index) + '\nreturn{' + pairs.join(',') + '};})();\n';
const peer = fs.readFileSync(path.join(dir, 'vendor/peerjs.min.js'), 'utf8');
// INM_ONLY=key — собрать только с одним файлом заключённого из src/12z_*.js (для изолированных тестов)
const only = process.env.INM_ONLY;
const files = fs.readdirSync(src).filter(f => f.endsWith('.js') && (!only || !f.startsWith('12z_') || f === '12z_' + only + '.js')).sort();
const game = files.map(f => `/* ===== ${f} ===== */\n` + fs.readFileSync(path.join(src, f), 'utf8')).join('\n');
const head = fs.readFileSync(path.join(src, 'head.html'), 'utf8');
for (const [n, s] of [['three', three], ['peer', peer], ['game', game]]) if (/<\/script/i.test(s)) throw new Error(n + ' contains </script');
const out = head + '<script>' + peer + '</script>\n<script type="module">\n' + three + game + '\n</script></body></html>\n';
const outPath = process.env.OUT || path.join(dir, 'index.html');
fs.writeFileSync(outPath, out);
console.log(outPath, (out.length / 1024).toFixed(0) + ' KB, game sources:', files.join(' '));
