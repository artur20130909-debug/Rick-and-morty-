# Прогон кода игры в песочнице (Lua 5.4 + мок Roblox API) без Roblox Studio.
#   python3 tools/run_map.py            — запустить серверные скрипты, затем клиентские, вывести ошибки
#   python3 tools/run_map.py --json F   — ещё и выгрузить детали и рельеф в файл F (для tools/preview.py)
# Нужен пакет lupa:  pip install lupa
import os, sys, json
from lupa import LuaRuntime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')

lua = LuaRuntime(unpack_returned_tuples=True)
mock_src = open(os.path.join(ROOT, 'tools', 'mock', 'mini.lua'), encoding='utf-8').read()
M = lua.execute(mock_src)

scripts = []  # (класс, экземпляр)

def mount(path, parent):
    entries = sorted(os.listdir(path))
    dirs = [e for e in entries if os.path.isdir(os.path.join(path, e))]
    module_dirs = set()
    for f in entries:
        full = os.path.join(path, f)
        if not f.endswith('.lua'):
            continue
        src = open(full, encoding='utf-8').read()
        if f.endswith('.server.lua'):
            s = M.addScript(parent, 'Script', f[:-len('.server.lua')], src)
            scripts.append(('Script', s))
        elif f.endswith('.client.lua'):
            s = M.addScript(parent, 'LocalScript', f[:-len('.client.lua')], src)
            scripts.append(('LocalScript', s))
        else:
            name = f[:-len('.lua')]
            s = M.addScript(parent, 'ModuleScript', name, src)
            if name in dirs:
                module_dirs.add(name)
                mount(os.path.join(path, name), s)
    for d in dirs:
        if d in module_dirs:
            continue
        if d == 'StarterPlayerScripts':
            mount(os.path.join(path, d), M.service('StarterPlayer').StarterPlayerScripts)
            continue
        mount(os.path.join(path, d), M.addFolder(parent, d))

for svc in sorted(os.listdir(SRC)):
    mount(os.path.join(SRC, svc), M.service(svc))

def report(stage):
    errs = list(M.errors.values())
    warns = list(M.warns.values())
    prints = list(M.prints.values())
    for p in prints:
        print('  [print]', p)
    for w in warns:
        print('  [warn]', w)
    for e in errs:
        print('  [ERROR]', e)
    lua.execute('local M = ...; M.errors = {}; M.warns = {}; M.prints = {}', M)
    return len(errs)

total = 0
print('== сервер')
for cls, s in scripts:
    if cls == 'Script':
        M.runScript(s)
total += report('server')
print('  ', M.stats())
print('   terrain ops:', len(M.terrainOps))

if '--json' in sys.argv:
    out = sys.argv[sys.argv.index('--json') + 1]
    js = M.exportJSON()
    json.loads(js)  # проверка
    open(out, 'w', encoding='utf-8').write(js)
    print('   json ->', out, len(js), 'bytes')

count_spawns = lua.eval('''function(ws)
    local out = {}
    local zones = ws.Map:FindFirstChild("Zones")
    if not zones then return "" end
    for _, z in ipairs(zones:GetChildren()) do
        local s = z:FindFirstChild("Spawns")
        if s then out[#out + 1] = z.Name .. "=" .. #s:GetChildren() end
    end
    table.sort(out)
    return table.concat(out, " ")
end''')
print('   точки появления:', count_spawns(M.workspace))
groups = lua.eval('''function(ws)
    local out = {}
    for _, g in ipairs(ws.Map:GetChildren()) do
        local n = 0
        for _, d in ipairs(g:GetDescendants()) do if d:IsA("BasePart") then n = n + 1 end end
        out[#out + 1] = g.Name .. "=" .. n
    end
    return table.concat(out, " ")
end''')
print('   деталей по разделам:', groups(M.workspace))

print('== клиент')
V3 = M.V3
plr, root = M.makeClient(V3.new(0, 5, 40))
for cls, s in scripts:
    if cls == 'LocalScript':
        M.runScript(s)
# пройтись персонажем по всем зонам: каждые 0.5 с — новая точка
path = [(0, 5, 40), (0, 5, -260), (0, 11, -470), (0, 17, -670), (0, 23, -870), (0, 29, -1070), (310, 5, 0), (-215, 5, 0), (0, 5, 175)]
title_of = lua.eval('function(plr) local g = plr.PlayerGui:FindFirstChild("ZoneTitle") return g and g:FindFirstChildOfClass("TextLabel").Text or "?" end')
seen = []
for (x, y, z) in path:
    root.CFrame = M.CF.new(x, y, z)
    M.step(1 / 30, 40)
    seen.append(title_of(plr))
print('   названия зон по пути:', ' → '.join(seen))
total += report('client')

print('ИТОГ:', 'ошибок нет' if total == 0 else 'ошибок: %d' % total)
sys.exit(1 if total else 0)
