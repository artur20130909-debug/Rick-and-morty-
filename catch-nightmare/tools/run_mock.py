#!/usr/bin/env python3
# Прогон игры в песочнице без Roblox Studio:  python3 tools/run_mock.py [tools/scenario.lua]
# Нужен lupa (pip install lupa). Мок Roblox: tools/mock/roblox.lua (из amber-roblox, с правками) + tools/mock/services.lua.
# Собирает дерево экземпляров из src/ так же, как build.py, запускает серверные и клиентские скрипты,
# выполняет сценарий и печатает ошибки, предупреждения и подозрительные места.
import os, sys
import lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
MOCK = os.path.join(ROOT, 'tools', 'mock', 'roblox.lua')
SERVICES = os.path.join(ROOT, 'tools', 'mock', 'services.lua')

def main():
    scenario = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'tools', 'scenario.lua')
    rt_cls = getattr(lupa, 'LuaRuntime')
    try:
        from lupa import lua54
        rt_cls = lua54.LuaRuntime
    except ImportError:
        pass
    lua = rt_cls(unpack_returned_tuples=True)
    src = open(MOCK, encoding='utf-8').read() + '\n' + open(SERVICES, encoding='utf-8').read() + '\nreturn mock\n'
    def lload(*a):
        r = lua.globals().load(*a)
        return (r[0], r[1]) if isinstance(r, tuple) else (r, None)
    chunk, err = lload(src, '@tools/mock/roblox.lua')
    if chunk is None:
        print('mock load error:', err)
        return 2
    mock = chunk()
    quiet = os.environ.get('QUIET') == '1'
    def out(kind, text):
        if quiet and kind == 'print':
            return
        print('%-7s %s' % (kind, text))
    mock.output = out
    mock.boot()

    def build_dir(parent, path, rel):
        entries = sorted(os.listdir(path))
        files = [e for e in entries if e.endswith('.lua')]
        dirs = [e for e in entries if os.path.isdir(os.path.join(path, e))]
        module_dirs = set()
        for f in files:
            full = os.path.join(path, f)
            code = open(full, encoding='utf-8').read()
            r = rel + '/' + f
            if f.endswith('.server.lua'):
                mock.script(parent, 'Script', f[:-len('.server.lua')], r, code)
            elif f.endswith('.client.lua'):
                mock.script(parent, 'LocalScript', f[:-len('.client.lua')], r, code)
            else:
                name = f[:-len('.lua')]
                inst = mock.script(parent, 'ModuleScript', name, r, code)
                if name in dirs:
                    module_dirs.add(name)
                    build_dir(inst, os.path.join(path, name), rel + '/' + name)
        for d in dirs:
            if d in module_dirs:
                continue
            existing = parent.FindFirstChild(parent, d) if d in ('StarterPlayerScripts', 'StarterCharacterScripts') else None
            inst = existing if existing is not None else mock.folder(parent, d)
            build_dir(inst, os.path.join(path, d), rel + '/' + d)

    for top in sorted(os.listdir(SRC)):
        p = os.path.join(SRC, top)
        if os.path.isdir(p):
            build_dir(mock.service(top), p, 'src/' + top)

    code = open(scenario, encoding='utf-8').read()
    # сценарий видит типы Roblox (Vector3, CFrame ...) и обычные функции Lua
    make_env = lua.eval('function(G) return setmetatable({ print = print }, { __index = function(t, k) local v = G[k]; if v ~= nil then return v end; return _G[k] end }) end')
    fn, err = lload(code, '=scenario', 't', make_env(mock.G))
    if fn is None:
        print('scenario load error:', err)
        return 2
    failures = 0
    try:
        res = fn(mock)
        failures = int(res or 0)
    except Exception as e:
        print('SCENARIO CRASH:', e)
        failures += 1

    # отчёт
    errors = list(mock.errors.values())
    warns = list(mock.warns.values())
    susp = list(mock.suspicious.values())
    print('\n==== ОТЧЁТ ====')
    print('ошибок: %d, предупреждений: %d, подозрительного: %d, провалов сценария: %d' % (len(errors), len(warns), len(susp), failures))
    for e in errors:
        print('\nERROR x%d [%s] t=%.2f %s' % (e.count, e.label, e.t, e.msg))
        if e.tb:
            print('   ' + str(e.tb).replace('\n', '\n   '))
    for w in warns:
        print('WARN x%d [%s] %s (%s)' % (w.count, w.ctx, w.msg, w.loc))
    for s in susp:
        print('SUSP x%d %s %s @ %s' % (s.count, s.kind, s.msg, s.loc))
    return 1 if (errors or failures) else 0

if __name__ == '__main__':
    sys.exit(main())
