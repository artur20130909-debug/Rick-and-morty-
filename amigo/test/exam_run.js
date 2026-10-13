// Экзамен Амиго: node test/exam_run.js
// Обучает нейросеть как build.js и сдаёт три экзамена на фразах, которых нет в обучении:
// понимание тем, знания без интернета и Claude, и «это игра или разговор» в режиме Кодекс.
const { load, train } = require('../build.js');
const A = load();
const { Text, Brain, U } = A;
const FILE = process.argv.includes('--final') ? './exam_final.js' : './exam.js';
const EXAM = require(FILE);

const offline = () => ({
  Super: { mode: () => null, avail: () => null, ask: async () => { throw { code: 'no_super' }; } },
  wiki: async () => { throw new Error('нет сети'); }, geocode: async () => null, forecast: async () => { throw new Error('нет сети'); },
});

async function exam(model, EX = EXAM) {
  const mk = over => new Brain(model, Object.assign({ rnd: U.rng(7), now: () => new Date(2026, 9, 13, 14, 5), online: offline() }, over));
  const out = { phrases: { ok: 0, n: 0, miss: [] }, knowledge: { ok: 0, n: 0, miss: [] }, codex: { ok: 0, n: 0, miss: [] } };

  // 1. понимание
  const b0 = mk();
  const tags = new Set(model.tags);
  for (const [tag, list] of Object.entries(EX.phrases)) {
    if (!tags.has(tag)) continue;
    for (const p of list) {
      const c = b0.classify(p);
      out.phrases.n++;
      if (c.tag === tag) out.phrases.ok++; else out.phrases.miss.push(`«${p}» → ${c.tag} (${Math.round(c.conf * 100)}%), нужно ${tag}`);
    }
  }
  // 2. знания: отвечает сам, без интернета
  for (const [q, re] of EX.knowledge) {
    const b = mk(); b.settings.online = false;
    const a = await b.reply(q);
    out.knowledge.n++;
    if (re.test(a.text) && !a.unsure) out.knowledge.ok++; else out.knowledge.miss.push(`«${q}» → ${a.text.slice(0, 90).replace(/\n/g, ' ')}`);
  }
  // 3. Кодекс: разговор остаётся разговором, а описание игры становится игрой
  for (const q of EX.codexChat) {
    const b = mk(); b.settings.codexOn = true; b.settings.online = false;
    const a = await b.reply(q);
    out.codex.n++;
    if (!a.game) out.codex.ok++; else out.codex.miss.push(`разговор «${q}» → игра ${a.game.opts && a.game.opts.genre}`);
  }
  for (const q of EX.codexGames) {
    const b = mk(); b.settings.codexOn = true; b.fastThink = true;
    const a = await b.reply(q);
    out.codex.n++;
    if (a.game) out.codex.ok++; else out.codex.miss.push(`игра «${q}» → ${a.text.slice(0, 60).replace(/\n/g, ' ')}`);
  }
  return out;
}

// фразы экзамена не должны встречаться в обучении
function overlap(EX = EXAM) {
  const train = new Set();
  for (const it of A.INTENTS) for (const p of it.p) if (p.indexOf('{') < 0) train.add(Text.clean(p));
  const dup = [];
  for (const list of Object.values(EX.phrases)) for (const p of list) if (train.has(Text.clean(p))) dup.push(p);
  return dup;
}

module.exports = { exam, overlap };

if (require.main === module) (async () => {
  const dup = overlap(EXAM);
  if (dup.length) console.log('⚠️ Эти фразы экзамена есть в обучении:', dup.join(' | '));
  const { model } = await train();
  const r = await exam(model);
  const pct = x => (x.ok / x.n * 100).toFixed(1) + '%';
  for (const [k, name] of [['phrases', 'Понимание'], ['knowledge', 'Знания'], ['codex', 'Кодекс: игра или разговор']]) {
    console.log(`${name}: ${r[k].ok}/${r[k].n} (${pct(r[k])}), ошибок ${r[k].n - r[k].ok}`);
    if (process.argv.includes('-v') && FILE === './exam.js') for (const m of r[k].miss) console.log('   ' + m);
  }
  const total = r.phrases.n + r.knowledge.n + r.codex.n, err = total - r.phrases.ok - r.knowledge.ok - r.codex.ok;
  console.log(`Всего ошибок: ${err} из ${total}`);
})();
