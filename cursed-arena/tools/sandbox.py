#!/usr/bin/env python3
# Песочница: запускает игру без Roblox Studio (мок API Roblox на Lua 5.4 через lupa).
#   python3 -I tools/sandbox.py                       — сервер + 1 игрок, 20 секунд
#   python3 -I tools/sandbox.py --scenario smoke      — сценарий tools/scenarios/smoke.lua
#   python3 -I tools/sandbox.py --players 2 --seconds 60
# Ошибки скриптов, предупреждения и «подозрительные» обращения (нет свойства, неизвестный Enum,
# клиент читает серверное и т.п.) печатаются в конце. Код возврата 1 — если были ошибки.
import argparse
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
sys.path.insert(0, ROOT)

from lupa import lua54  # noqa: E402
import rbxlx  # noqa: E402


class Sandbox:
    def __init__(self, verbose=False, echo_suspicious=False):
        self.L = lua54.LuaRuntime(unpack_returned_tuples=True)
        self.log = []
        self.verbose = verbose
        with open(os.path.join(HERE, 'mock', 'roblox.lua'), encoding='utf-8') as f:
            a = f.read()
        with open(os.path.join(HERE, 'mock', 'part5.lua'), encoding='utf-8') as f:
            b = f.read()
        loader = self.L.eval('function(src, name) local f, e = load(src, name, "t") if not f then error(e) end return f() end')
        self.mock = loader(a + '\n' + b, '@tools/mock/roblox.lua')
        self.mock.echoSuspicious = echo_suspicious

        def out(kind, text):
            self.log.append((kind, text))
            if kind == 'error' or verbose or (kind == 'warn'):
                print('[%s] %s' % (kind, text), flush=True)
            elif kind == 'print' and verbose:
                print(text, flush=True)
        self.mock.output = out
        self.mock.printEnabled = verbose
        self.game = self.mock.newGame()
        self._mk = self.L.eval('''function(mock)
            local Vector3, Vector2, CFrame, Color3, UDim2 = nil, nil, nil, nil, nil
            return function(kind, a, b, c, d, e, f, g, h, i, j, k, l)
                local G = mock.G
                if kind == "V3" then return mock.v3(a, b, c) end
                if kind == "V2" then return mock.v2(a, b) end
                if kind == "C3" then return mock.c3(a, b, c) end
                if kind == "CF" then return mock.cfnew(a, b, c, d, e, f, g, h, i, j, k, l) end
                if kind == "UD2" then return mock.udim2(a, b, c, d) end
                if kind == "E" then return mock.E(a, b) end
                error("mk: unknown kind " .. tostring(kind))
            end
        end''')(self.mock)

    # ---------- загрузка места ----------
    def value(self, p):
        k, v = p.kind, p.value
        if k in ('bool', 'float', 'double', 'int', 'string', 'ProtectedString', 'Content'):
            return v
        if k == 'Vector3':
            return self._mk('V3', *v)
        if k == 'Vector2':
            return self._mk('V2', *v)
        if k == 'Color3':
            return self._mk('C3', *v)
        if k == 'CoordinateFrame':
            return self._mk('CF', *v)
        if k == 'UDim2':
            return self._mk('UD2', *v)
        if k == 'token':
            return self._mk('E', v[0], v[1])
        raise ValueError('sandbox: тип ' + k)

    def spec(self, inst, ids, is_root=False):
        t = self.L.table()
        t['cls'] = inst.cls
        t['name'] = inst.name
        t['id'] = ids.setdefault(id(inst), len(ids) + 1)
        if is_root:
            t['service'] = True
        if inst.src:
            t['src'] = inst.src
        props = self.L.table()
        refs = self.L.table()
        for k, p in inst.props.items():
            if p.kind == 'Ref':
                if p.value is not None:
                    refs[k] = ids.setdefault(id(p.value), len(ids) + 1)
            else:
                props[k] = self.value(p)
        t['props'] = props
        t['refs'] = refs
        if inst.tags:
            t['tags'] = self.L.table(*inst.tags)
        if inst.attrs:
            a = self.L.table()
            for k, v in inst.attrs.items():
                a[k] = v
            t['attrs'] = a
        kids = self.L.table()
        for i, c in enumerate(inst.children):
            kids[i + 1] = self.spec(c, ids)
        t['children'] = kids
        return t

    def load_place(self):
        import build
        roots, manifest = build.build_place()
        ids = {}
        specs = [self.spec(r, ids, is_root=True) for r in roots]
        # одна таблица для всех корней, чтобы ссылки между службами работали
        top = self.L.table()
        top['cls'] = 'Folder'
        top['name'] = '__place'
        kids = self.L.table()
        for i, s in enumerate(specs):
            kids[i + 1] = s
        top['children'] = kids
        build_roots = self.L.eval('''function(mock, top, game)
            local byId, pending = {}, {}
            for _, s in ipairs(top.children) do mock.buildTree(s, game, byId, pending) end
            for _, r in ipairs(pending) do
                local target = byId[r.id]
                if target then
                    local ok, err = pcall(function() r.inst[r.k] = target end)
                    if not ok then mock.suspect("LOAD", "ссылка " .. r.k .. ": " .. tostring(err), "place") end
                end
            end
        end''')
        build_roots(self.mock, top, self.game)
        return roots

    # ---------- запуск ----------
    def start(self):
        self.mock.startServer()

    def add_player(self, name, touch=False):
        opts = self.L.table()
        opts['touch'] = touch
        return self.mock.addPlayer(name, opts)

    def run(self, seconds):
        self.mock.run(seconds)

    def scenario(self, path):
        with open(path, encoding='utf-8') as f:
            src = f.read()
        runner = self.L.eval(r'''function(mock, src, name)
            local H = {}
            local env = setmetatable({ mock = mock, h = H }, { __index = function(t, k)
                local v = mock.G[k]
                if v ~= nil then return v end
                return _G[k]
            end })
            function H.wait(t) coroutine.yield("wait", t or 0) end
            function H.frames(n) coroutine.yield("frames", n or 1) end
            local fn, err = load(src, "=" .. name, "t", env)
            if not fn then error(err) end
            local co = coroutine.create(fn)
            mock.threadCtx[co] = mock.SERVER
            while true do
                local ok, cmd, arg = coroutine.resume(co)
                if not ok then
                    mock.recordError(cmd, debug.traceback(co, tostring(cmd)), { label = "scenario" })
                    return false
                end
                if coroutine.status(co) == "dead" then return true end
                if cmd == "wait" then mock.run(arg)
                elseif cmd == "frames" then for _ = 1, arg do mock.step() end end
            end
        end''')
        return runner(self.mock, src, os.path.basename(path))

    # ---------- отчёт ----------
    def report(self, max_susp=60):
        m = self.mock
        errors = list(m.errors.values()) if m.errors else []
        warns = list(m.warns.values()) if m.warns else []
        susp = list(m.suspicious.values()) if m.suspicious else []
        print('\n==== отчёт песочницы ====')
        print('время %.1f с, кадров %d, скриптов запущено %d, деталей в workspace %d' % (
            m.now, m.frame, m.scriptsRun, m.partsInWorkspace()))
        if warns:
            print('\n-- предупреждения (%d) --' % len(warns))
            for w in warns[:40]:
                print('  [%s] %s  (%s) x%d' % (w.ctx, w.msg, w.loc, w.count))
        if susp:
            print('\n-- подозрительное (%d) --' % len(susp))
            for s in susp[:max_susp]:
                print('  %s %s @ %s x%d' % (s.kind, s.msg, s.loc, s.count))
        if errors:
            print('\n-- ОШИБКИ (%d) --' % len(errors))
            for e in errors:
                print('  [%s] t=%.2f %s x%d' % (e.label, e.t, e.msg, e.count))
                if e.tb:
                    for line in str(e.tb).splitlines()[:12]:
                        print('      ' + line)
        else:
            print('\nошибок нет')
        return len(errors)

    def dump_world(self, path, viewer=None):
        parts = self.mock.dumpParts(viewer)
        lights = self.mock.dumpLights()

        def conv(x):
            if self.L.eval('type')(x) == 'table':
                keys = list(x.keys())
                if keys and all(isinstance(k, int) for k in keys):
                    return [conv(x[k]) for k in sorted(keys)]
                return {str(k): conv(x[k]) for k in keys}
            return x
        data = {'parts': conv(parts), 'lights': conv(lights)}
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False)
        return data


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--scenario', help='имя сценария из tools/scenarios или путь к .lua')
    ap.add_argument('--players', type=int, default=1)
    ap.add_argument('--touch', action='store_true', help='первый игрок — с телефона')
    ap.add_argument('--seconds', type=float, default=20)
    ap.add_argument('--verbose', '-v', action='store_true')
    ap.add_argument('--echo', action='store_true', help='печатать подозрительное сразу')
    args = ap.parse_args()
    t0 = time.time()
    sb = Sandbox(verbose=args.verbose, echo_suspicious=args.echo)
    sb.load_place()
    sb.start()
    if args.scenario:
        path = args.scenario
        if not os.path.exists(path):
            path = os.path.join(HERE, 'scenarios', args.scenario + '.lua')
        for i in range(args.players):
            sb.add_player('Player%d' % (i + 1), touch=(args.touch and i == 0))
        sb.scenario(path)
    else:
        for i in range(args.players):
            sb.add_player('Player%d' % (i + 1), touch=(args.touch and i == 0))
        sb.run(args.seconds)
    n = sb.report()
    print('(%.1f с реального времени)' % (time.time() - t0))
    sys.exit(1 if n else 0)


if __name__ == '__main__':
    main()
