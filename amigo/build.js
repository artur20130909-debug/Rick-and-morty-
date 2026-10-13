// Сборка Амиго: node build.js
// 1) обучает нейросеть на фразах из src/03_intents.js,
// 2) проверяет её на фразах из test/phrases.js, которых она не видела,
// 3) встраивает обученные веса и весь код в один файл index.html.
// ARTIFACT_OUT=путь — дополнительно сохранить страницу без <html>/<head> (для публикации в Claude).
const fs = require('fs'), path = require('path'), vm = require('vm');
const dir = __dirname, src = path.join(dir, 'src');
const CFG = { D: 4096, H: 64, epochs: 20, batch: 16, lr: 0.01, smooth: 0.1, dropout: 0.2, seed: 7 };
const BRAIN_FILES = ['00_util.js', '01_text.js', '02_nn.js', '03_intents.js', '03b_content.js', '04_data.js', '05_skills.js', '05c_gamelist.js', '06_online.js', '07_brain.js'];

// загрузить код Амиго в node (как отдельные <script> в браузере)
let loaded = null;
function load() {
  if (loaded) return loaded;
  for (const f of BRAIN_FILES) vm.runInThisContext(fs.readFileSync(path.join(src, f), 'utf8'), { filename: f });
  loaded = vm.runInThisContext('({ U, Text, MLP, INTENTS, FILL, Data, Skills, Online, Brain, KB, JOKES, FACTS, RIDDLES, QUIZ, DICT, BRAIN_TH, GameList, GAME_LIST, extractHtml })');
  return loaded;
}

function accuracy(A, net, tags, D) {
  const V = require('./test/phrases.js');
  let ok = 0, n = 0; const miss = [];
  for (const [tag, list] of Object.entries(V)) {
    const y = tags.indexOf(tag);
    if (y < 0) throw new Error('нет темы ' + tag);
    for (const s of list) {
      const p = net.predict(A.Text.features(s, D));
      let a = 0; for (let c = 1; c < p.length; c++) if (p[c] > p[a]) a = c;
      n++; if (a === y) ok++; else miss.push(`  «${s}» → ${tags[a]} (${(p[a] * 100).toFixed(0)}%), нужно ${tag}`);
    }
  }
  return { acc: ok / n, ok, n, miss };
}

async function train(log = () => {}) {
  const A = load();
  const t0 = Date.now();
  const ds = A.Data.build(A.INTENTS);
  const ex = A.Data.featurize(ds.examples, CFG.D);
  const net = new A.MLP(CFG.D, CFG.H, ds.tags.length, 1);
  const history = await net.train(ex, Object.assign({}, CFG, { onEpoch: r => log(`  эпоха ${String(r.epoch).padStart(2)}: ошибка ${r.loss.toFixed(3)}, точность ${(r.acc * 100).toFixed(1)}%`) }));
  const json = net.toJSON();
  const q = A.MLP.fromJSON(json); // проверяем уже сжатую сеть — именно она попадёт в страницу
  const val = accuracy(A, q, ds.tags, CFG.D);
  const model = { v: 1, D: CFG.D, H: CFG.H, epochs: CFG.epochs, tags: ds.tags, examples: ex.length, params: net.params,
    history: history.map(h => [+h.loss.toFixed(4), +h.acc.toFixed(4)]), val: { acc: +val.acc.toFixed(4), n: val.n }, net: json };
  return { model, val, ms: Date.now() - t0 };
}

async function main() {
  console.log('Обучаю нейросеть Амиго...');
  const { model, val, ms } = await train(console.log);
  console.log(`Готово за ${(ms / 1000).toFixed(1)} с: ${model.tags.length} тем, ${model.examples} примеров, ${model.params} параметров.`);
  console.log(`Точность на новых фразах: ${(val.acc * 100).toFixed(1)}% (${val.ok} из ${val.n})`);
  if (val.miss.length) console.log('Ошибки:\n' + val.miss.join('\n'));

  const js = fs.readdirSync(src).filter(f => f.endsWith('.js')).sort()
    .map(f => `/* ===== ${f} ===== */\n` + fs.readFileSync(path.join(src, f), 'utf8')).join('\n');
  const modelJs = '/* ===== обученная модель (создаётся build.js) ===== */\nconst AMIGO_MODEL = ' + JSON.stringify(model) + ';\n';
  const css = fs.readFileSync(path.join(src, 'style.css'), 'utf8');
  const body = fs.readFileSync(path.join(src, 'body.html'), 'utf8');
  const script = modelJs + js;
  if (/<\/script/i.test(script)) throw new Error('в коде встретилось </script');
  const fonts = '<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>' +
    '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Golos+Text:wght@400;500;600&family=JetBrains+Mono:wght@400;600&family=Unbounded:wght@500;700&display=swap">';
  const icon = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><path d="M50 18V8" stroke="#10302D" stroke-width="5" stroke-linecap="round"/><circle cx="50" cy="8" r="7" fill="#E2566E"/><rect x="10" y="18" width="80" height="74" rx="36" fill="#E8A21A"/><ellipse cx="36" cy="52" rx="9" ry="11" fill="#fff"/><ellipse cx="64" cy="52" rx="9" ry="11" fill="#fff"/><circle cx="37" cy="54" r="5" fill="#10302D"/><circle cx="65" cy="54" r="5" fill="#10302D"/><path d="M38 72q12 10 24 0" stroke="#10302D" stroke-width="5" fill="none" stroke-linecap="round"/></svg>');
  const title = '<title>Амиго</title>';
  const full = '<!doctype html>\n<html lang="ru">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n' + title +
    '\n<meta name="description" content="Амиго — нейросеть-друг, которая учится прямо в браузере">\n<link rel="icon" href="' + icon + '">\n' + fonts +
    '\n<style>\n' + css + '</style>\n</head>\n<body>\n' + body + '<script>\n' + script + '</script>\n</body>\n</html>\n';
  const out = path.join(dir, 'index.html');
  fs.writeFileSync(out, full);
  console.log(out, (full.length / 1024).toFixed(0) + ' КБ');
  if (process.env.ARTIFACT_OUT) {
    const frag = title + '\n' + fonts + '\n<style>\n' + css + '</style>\n' + body + '<script>\n' + script + '</script>\n';
    fs.writeFileSync(process.env.ARTIFACT_OUT, frag);
    console.log(process.env.ARTIFACT_OUT, (frag.length / 1024).toFixed(0) + ' КБ');
  }
}

module.exports = { load, train, CFG };
if (require.main === module) main().catch(e => { console.error(e); process.exit(1); });
