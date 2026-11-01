#!/usr/bin/env python3
# Песочница: запускает игру из src/ в моке Roblox (Lua 5.4 через lupa) и прогоняет сценарий.
#   python3 tools/run_mock.py                 — сценарий по умолчанию (tools/scenario.lua)
#   python3 tools/run_mock.py tools/x.lua     — свой сценарий
#   python3 tools/run_mock.py --dump out.json — выгрузить детали карты (для рендера в three.js)
# Код игры написан на подмножестве Luau, совместимом с Lua 5.1, поэтому он работает и здесь.
import os, sys, json
from lupa import lua54

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.environ.get('RM_SRC') or os.path.join(ROOT, 'src')
MOCK = os.path.join(ROOT, 'tools', 'mock')

args = sys.argv[1:]
dump = None
if '--dump' in args:
    i = args.index('--dump')
    dump = args[i + 1]
    del args[i:i + 2]
quiet = '--quiet' in args
if quiet:
    args.remove('--quiet')
scenario = args[0] if args else os.path.join(ROOT, 'tools', 'scenario.lua')

lua = lua54.LuaRuntime(unpack_returned_tuples=True)
G = lua.globals()

log = []
def output(kind, text):
    kind = str(kind)
    text = str(text)
    log.append((kind, text))
    if quiet and kind in ('print',):
        return
    print('[%s] %s' % (kind, text))

LOAD = lua.eval('function(src, name) local f, e = load(src, name); return f, e end')
def load_chunk(path, chunkname):
    src = open(path, encoding='utf-8').read()
    fn, err = LOAD(src, '@' + chunkname)
    if fn is None:
        raise SystemExit('load error %s: %s' % (chunkname, err))
    return fn

mock = load_chunk(os.path.join(MOCK, 'roblox.lua'), 'tools/mock/roblox.lua')()
mock.output = output
load_chunk(os.path.join(MOCK, 'services.lua'), 'tools/mock/services.lua')(mock)

make = lua.eval('''function(mock, parent, cls, name, source, path)
  local inst = mock.Instance.new(cls)
  inst.Name = name
  if source then inst[mock.DATA].p.Source = source; inst[mock.DATA].path = path end
  inst.Parent = parent
  return inst
end''')

CHILD = lua.eval('function(p, n) return p:FindFirstChild(n) end')
def build_dir(path, parent, rel):
    entries = sorted(os.listdir(path))
    files = [e for e in entries if e.endswith('.lua')]
    dirs = [e for e in entries if os.path.isdir(os.path.join(path, e))]
    module_dirs = set()
    for f in files:
        full = os.path.join(path, f)
        src = open(full, encoding='utf-8').read()
        relp = rel + '/' + f
        if f.endswith('.server.lua'):
            make(mock, parent, 'Script', f[:-len('.server.lua')], src, relp)
        elif f.endswith('.client.lua'):
            make(mock, parent, 'LocalScript', f[:-len('.client.lua')], src, relp)
        else:
            name = f[:-len('.lua')]
            inst = make(mock, parent, 'ModuleScript', name, src, relp)
            if name in dirs:
                module_dirs.add(name)
                build_dir(os.path.join(path, name), inst, rel + '/' + name)
    for d in dirs:
        if d in module_dirs:
            continue
        child = CHILD(parent, d)
        if child is None:
            child = make(mock, parent, 'Folder', d, None, None)
        build_dir(os.path.join(path, d), child, rel + '/' + d)

for top in sorted(os.listdir(SRC)):
    p = os.path.join(SRC, top)
    if not os.path.isdir(p):
        continue
    svc = mock.services[top]
    if svc is None:
        raise SystemExit('нет службы ' + top)
    build_dir(p, svc, 'src/' + top)

SNAP = os.environ.get('RM_SNAP') or '/tmp/rr_snap'
os.makedirs(SNAP, exist_ok=True)
_dumper = load_chunk(os.path.join(MOCK, 'dump.lua'), 'tools/mock/dump.lua')
_gui = load_chunk(os.path.join(MOCK, 'gui.lua'), 'tools/mock/gui.lua')
def snapshot(name):
    data = _dumper(mock)
    path = os.path.join(SNAP, str(name) + '.json')
    open(path, 'w').write(str(data))
    open(os.path.join(SNAP, str(name) + '.gui.json'), 'w').write(str(_gui(mock)))
    print('[snap] ' + path)
mock.snapshot = snapshot

scen = load_chunk(scenario, os.path.relpath(scenario, ROOT))
ok, err = lua.eval('function(f, mock) local ok, e = xpcall(f, debug.traceback, mock); return ok, tostring(e) end')(scen, mock)

# отчёт
errors = list(mock.errors.values()) if mock.errors else []
susp = list(mock.suspicious.values()) if mock.suspicious else []
print('\n==== ИТОГ ====')
if not ok:
    print('СЦЕНАРИЙ УПАЛ:', err)
print('ошибок в потоках:', len(errors))
for e in errors[:30]:
    try:
        print('  ERR', e['msg'] if e['msg'] else e)
        tb = e['tb']
        if tb:
            print('    ' + '\n    '.join(str(tb).split('\n')[:8]))
    except Exception:
        print('  ERR', e)
print('подозрительное:', len(susp))
seen = set()
for s in susp:
    try:
        key = (s['kind'], s['msg'])
    except Exception:
        key = str(s)
    if key in seen:
        continue
    seen.add(key)
    try:
        print('  SUS', s['kind'], s['msg'], s['loc'] or '')
    except Exception:
        print('  SUS', s)
    if len(seen) > 40:
        break
print('предупреждений (warn):', len(mock.warns))
print('деталей в workspace:', mock.partsInWorkspace())

if dump:
    open(dump, 'w').write(str(_dumper(mock)))
    print('выгружено в', dump)

sys.exit(1 if (not ok or errors) else 0)
