#!/usr/bin/env python3
# Галерея поз: рисует кадры анимаций на манекенах R6 (проверка Shared/Poses и Shared/Rig).
#   python3 -I tools/pose_gallery.py --base                 — все базовые позы
#   python3 -I tools/pose_gallery.py m1_f1 punch_heavy      — по 6 кадров каждой анимации
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sandbox import Sandbox  # noqa: E402
import shots  # noqa: E402

OUT = os.path.join(os.path.dirname(HERE), 'previews', 'poses')

LUA = r'''
return function(entries, spacing, yaw)
	local RS = game:GetService("ReplicatedStorage")
	local Poses = require(RS.Shared.Poses)
	local Rig = require(RS.Shared.Rig)
	local holder = workspace:FindFirstChild("Gallery")
	if holder then holder:Destroy() end
	holder = Instance.new("Folder")
	holder.Name = "Gallery"
	holder.Parent = workspace
	local n = #entries
	for i, e in ipairs(entries) do
		local m = game.StarterPlayer.StarterCharacter:Clone()
		m.Parent = holder
		local x = (i - 1) * spacing - (n - 1) * spacing / 2
		m:PivotTo(CFrame.new(x, 3, 0) * CFrame.Angles(0, math.rad(yaw), 0))
		m.HumanoidRootPart.Anchored = true
		local motors, rot0 = Rig.find(m)
		local vals = {}
		local base = Poses.BaseVals[e.base or "fists"]
		for _, j in ipairs(Poses.JOINTS) do vals[j] = { table.unpack(base[j]) } end
		if e.anim then
			local anim = Poses.get(e.anim)
			if not anim then error("нет анимации " .. tostring(e.anim)) end
			local s = Poses.sample(anim, e.t or 0, {})
			for j, v in pairs(s) do vals[j] = v end
		end
		Rig.apply(motors, rot0, vals)
		mock.solveJoints(m)
	end
end
'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('anims', nargs='*')
    ap.add_argument('--base', action='store_true')
    ap.add_argument('--frames', type=int, default=6)
    ap.add_argument('--yaw', type=float, default=20)
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    sb = Sandbox()
    sb.load_place()
    L = sb.L
    env_fn = L.eval('function(mock, src) local f = assert(load(src, "=gallery", "t", setmetatable({ mock = mock }, { __index = function(t, k) local v = mock.G[k] if v ~= nil then return v end return _G[k] end }))) return f() end')
    build = env_fn(sb.mock, LUA)
    run_srv = L.eval('function(mock, f, ...) local args = table.pack(...) local ok, err mock.asServer(function() ok, err = pcall(f, table.unpack(args, 1, args.n)) end) if not ok then error(err) end end')
    pairs = []
    jobs = []
    if args.base:
        names = ['stand', 'fists', 'palms', 'sword', 'claws', 'block', 'block_sword', 'stun', 'dizzy', 'air_up', 'air_down']
        jobs.append(('base', [{'base': n, 'label': n} for n in names]))
    for a in args.anims:
        get_d = L.eval('function(mock, name) local d mock.asServer(function() local P = mock.require(mock.game():GetService("ReplicatedStorage").Shared.Poses) d = P.get(name) and P.get(name).d end) return d end')
        dur = get_d(sb.mock, a)
        if dur is None:
            print('нет анимации', a)
            continue
        n = args.frames
        base = 'sword' if a.startswith('m1_s') or a in ('counter_stance', 'slash_through', 'rising_slash', 'overhead') else 'fists'
        jobs.append((a, [{'anim': a, 't': dur * i / (n - 1) if n > 1 else 0, 'base': base} for i in range(n)]))
    for name, entries in jobs:
        lt = L.table()
        for i, e in enumerate(entries):
            t = L.table()
            for k, v in e.items():
                t[k] = v
            lt[i + 1] = t
        run_srv(sb.mock, build, lt, 6.0, args.yaw)
        import math
        span = (len(entries) - 1) * 6.0
        w = 1600 if len(entries) > 6 else 1280
        h = 640
        vfov = 40.0
        hfov = 2 * math.atan(math.tan(math.radians(vfov / 2)) * w / h)
        dist = (span / 2 + 3.5) / math.tan(hfov / 2)
        sc = shots.scene(sb, eye=(dist * 0.18, 4.6, -dist), target=(0, 2.6, 0), tag='поза: ' + name, fov=vfov,
                         width=w, height=h, shadow_focus=dist, shadow_span=max(30, span))
        out = os.path.join(OUT, name + '.png')
        pairs.append((sc, out))
    if pairs:
        shots.render(pairs)
    sb.report(max_susp=20)


if __name__ == '__main__':
    main()
