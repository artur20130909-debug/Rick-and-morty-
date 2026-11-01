const lp = require('luaparse'), fs = require('fs');
for (const f of process.argv.slice(2)) { try { lp.parse(fs.readFileSync(f, 'utf8'), { luaVersion: '5.2' }); console.log('OK  ', f.split('/src/')[1]); } catch (e) { console.log('FAIL', f.split('/src/')[1], e.message); } }
