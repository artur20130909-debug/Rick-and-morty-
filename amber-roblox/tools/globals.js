const lp = require('luaparse'), fs = require('fs');
const known = new Set(['game','workspace','script','Instance','Vector3','Vector2','CFrame','Color3','UDim','UDim2','Enum','TweenInfo','NumberSequence','NumberSequenceKeypoint','ColorSequence','ColorSequenceKeypoint','NumberRange','Random','task','math','string','table','utf8','typeof','tostring','tonumber','pairs','ipairs','print','warn','pcall','require','setmetatable','os','type','error','select','unpack','next','rawget','tick','PhysicalProperties','Ray','RaycastParams','BrickColor','Rect','Region3','Faces','Axes','delay','spawn','wait','DateTime','Font','OverlapParams','buffer','debug','coroutine','bit32','time','elapsedTime','settings','UserSettings','shared','_G','xpcall','assert','rawset','rawequal','rawlen','select','TweenInfo','PathWaypoint','NumberRange','Vector3int16','Vector2int16','RotationCurveKey','FloatCurveKey','CatalogSearchParams','SharedTable','gcinfo','version']);
for (const f of process.argv.slice(2)) {
  const ast = lp.parse(fs.readFileSync(f, 'utf8'), { luaVersion: '5.2', scope: true, locations: true });
  const bad = ast.globals.filter(g => !known.has(g.name));
  // report each use with line
  const uses = [];
  (function walk(n) { if (!n || typeof n !== 'object') return; if (Array.isArray(n)) return n.forEach(walk);
    if (n.type === 'Identifier' && n.isLocal === false && !known.has(n.name)) uses.push(n.name + '@' + n.loc.start.line);
    for (const k in n) if (k !== 'loc' && k !== 'range') walk(n[k]); })(ast.body);
  console.log(f.split('/src/')[1], bad.length ? 'GLOBALS: ' + [...new Set(uses)].join(', ') : 'no stray globals');
}
