# Снимки (превью) из песочницы: сцена -> JSON -> render.js -> PNG
import json
import math
import os
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))


def to_py(L, x):
    t = L.eval('type')(x)
    if t == 'table':
        keys = list(x.keys())
        if keys and all(isinstance(k, int) for k in keys):
            return [to_py(L, x[k]) for k in sorted(keys)]
        if not keys:
            return []
        return {str(k): to_py(L, x[k]) for k in keys}
    return x


def sun_dir(clock):
    a = (clock - 6) / 12 * math.pi
    d = (math.cos(a), max(0.08, math.sin(a)), -0.35)
    l = math.sqrt(sum(c * c for c in d))
    return [c / l for c in d]


def lighting_of(sb):
    L = sb.L
    lt = sb.mock.service('Lighting')
    clock = float(lt.ClockTime)
    return {
        'sunDir': sun_dir(clock),
        'sunColor': [1.0, 0.9, 0.78],
        'sunPower': 3.1,
        'skyTop': [0.30, 0.52, 0.92],
        'horizon': [0.80, 0.86, 0.95],
        'ambSky': [0.34, 0.42, 0.58],
        'ambGround': [0.22, 0.2, 0.17],
        'ambPower': 1.0,
        'fog': [0.80, 0.86, 0.95],
        'fogDensity': 0.0018,
        'exposure': 1.05,
    }


def camera_cf(sb, viewer=None, eye=None, target=None):
    if eye is not None:
        ex, ey, ez = eye
        tx, ty, tz = target
        fx, fy, fz = tx - ex, ty - ey, tz - ez
        l = math.sqrt(fx * fx + fy * fy + fz * fz) or 1
        fx, fy, fz = fx / l, fy / l, fz / l
        rx, rz = -fz, fx
        rl = math.sqrt(rx * rx + rz * rz) or 1
        rx, rz = rx / rl, rz / rl
        ux, uy, uz = -rz * fy, rz * fx - rx * fz, rx * fy
        return [ex, ey, ez, rx, ux, -fx, 0, uy, -fy, rz, uz, -fz]
    cam = sb.mock.cameraOf(viewer)
    c = cam.CFrame
    comps = sb.L.eval('function(c) return {c:GetComponents()} end')(c)
    return [float(v) for v in to_py(sb.L, comps)]


def scene(sb, viewer=None, eye=None, target=None, gui=True, tag='', fov=70, width=1280, height=720, shadow_focus=45, shadow_span=150):
    parts = to_py(sb.L, sb.mock.dumpParts(viewer))
    lights = to_py(sb.L, sb.mock.dumpLights())
    for p in parts:
        if p.get('decals') == {}:
            p['decals'] = []
    g = to_py(sb.L, sb.mock.dumpGui(viewer)) if (gui and viewer is not None) else []
    return {
        'width': width, 'height': height, 'tag': tag,
        'camera': {'cf': camera_cf(sb, viewer, eye, target), 'fov': fov},
        'lighting': lighting_of(sb), 'parts': parts, 'lights': lights, 'gui': g,
        'shadowFocus': shadow_focus, 'shadowSpan': shadow_span,
    }


def render(pairs):
    """pairs: [(scene_dict, out_png), ...]"""
    tmp = tempfile.mkdtemp(prefix='shots')
    args = []
    for i, (sc, out) in enumerate(pairs):
        p = os.path.join(tmp, 'scene%d.json' % i)
        with open(p, 'w', encoding='utf-8') as f:
            json.dump(sc, f)
        args += [p, out]
    env = dict(os.environ)
    env['NODE_PATH'] = '/opt/node22/lib/node_modules:/opt/node-tools/node_modules'
    r = subprocess.run(['node', os.path.join(HERE, 'render', 'render.js')] + args, env=env, capture_output=True, text=True, timeout=600)
    print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr[-3000:])
    return r.returncode == 0
