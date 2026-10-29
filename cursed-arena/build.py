#!/usr/bin/env python3
# Сборка места Roblox:  python3 build.py  ->  CursedArena.rbxlx
#
# Скрипты лежат в src/ (правила как у Rojo):
#   папка                 -> Folder
#   Имя.server.lua        -> Script
#   Имя.client.lua        -> LocalScript
#   Имя.lua               -> ModuleScript
#   Имя.lua + папка Имя/  -> ModuleScript, содержимое папки — его дети
# Карта (tools/mapgen.py), персонаж R6 (tools/rig.py), свет и настройки — ниже.
import json
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ROOT, 'tools'))

from rbxlx import Inst, Bool, Float, Int, Str, Vec3, Color, Content, Token, Ref, CF, Source, to_xml, cf_look, rgb  # noqa: E402
import rig  # noqa: E402
import mapgen  # noqa: E402

SRC = os.path.join(ROOT, 'src')
OUT = os.path.join(ROOT, 'CursedArena.rbxlx')
MANIFEST = os.path.join(ROOT, 'tools', 'manifest.json')

SPECIAL_DIRS = {'StarterPlayerScripts', 'StarterCharacterScripts'}


def script(cls, name, path, manifest, inst_path):
    with open(path, encoding='utf-8') as f:
        text = f.read()
    s = Inst(cls, name, Source=Source(text))
    rel = os.path.relpath(path, ROOT)
    s.src = rel
    manifest[inst_path + '.' + name] = rel
    return s


def build_dir(path, manifest, inst_path):
    out = []
    entries = sorted(os.listdir(path))
    files = [e for e in entries if e.endswith('.lua')]
    dirs = [e for e in entries if os.path.isdir(os.path.join(path, e))]
    module_dirs = set()
    for f in files:
        full = os.path.join(path, f)
        if f.endswith('.server.lua'):
            out.append(script('Script', f[:-len('.server.lua')], full, manifest, inst_path))
        elif f.endswith('.client.lua'):
            out.append(script('LocalScript', f[:-len('.client.lua')], full, manifest, inst_path))
        else:
            name = f[:-len('.lua')]
            m = script('ModuleScript', name, full, manifest, inst_path)
            if name in dirs:
                module_dirs.add(name)
                for c in build_dir(os.path.join(path, name), manifest, inst_path + '.' + name):
                    m.add(c)
            out.append(m)
    for d in dirs:
        if d in module_dirs:
            continue
        cls = d if d in SPECIAL_DIRS else 'Folder'
        folder = Inst(cls, d)
        for c in build_dir(os.path.join(path, d), manifest, inst_path + '.' + d):
            folder.add(c)
        out.append(folder)
    return out


def src_children(name, manifest):
    p = os.path.join(SRC, name)
    return build_dir(p, manifest, name) if os.path.isdir(p) else []


def build_place():
    manifest = {}
    # ---- Workspace ----
    ws = Inst('Workspace', 'Workspace',
              StreamingEnabled=Bool(False), FallenPartsDestroyHeight=Float(-250), Gravity=Float(196.2))
    world = mapgen.build_map()
    ws.add(world['map'])
    cam = Inst('Camera', 'Camera', CFrame=CF(cf_look(*world['camera'])), FieldOfView=Float(70),
               CameraType=Token('CameraType', 'Fixed'))
    ws.add(cam)
    ws.set('CurrentCamera', Ref(cam))

    # ---- Lighting ----
    L = world['lighting']
    lighting = Inst('Lighting', 'Lighting',
                    Technology=Token('Technology', 'Future'),
                    LightingStyle=Token('LightingStyle', 'Realistic'),
                    PrioritizeLightingQuality=Bool(True),
                    GlobalShadows=Bool(True), ShadowSoftness=Float(0.18),
                    Brightness=Float(L['brightness']), TimeOfDay=Str(L['time']),
                    GeographicLatitude=Float(L['latitude']),
                    Ambient=Color(*L['ambient']), OutdoorAmbient=Color(*L['outdoor']),
                    EnvironmentDiffuseScale=Float(1), EnvironmentSpecularScale=Float(1),
                    ExposureCompensation=Float(L['exposure']),
                    ColorShift_Top=Color(*L['shift_top']), ColorShift_Bottom=Color(0, 0, 0),
                    FogColor=Color(*L['fog']), FogStart=Float(0), FogEnd=Float(100000))
    lighting.add(Inst('Atmosphere', 'Atmosphere', Density=Float(L['atm_density']), Offset=Float(0.25),
                      Color=Color(*L['atm_color']), Decay=Color(*L['atm_decay']), Glare=Float(L['atm_glare']),
                      Haze=Float(L['atm_haze'])))
    lighting.add(Inst('Sky', 'Sky', CelestialBodiesShown=Bool(True), SunAngularSize=Float(14), MoonAngularSize=Float(9),
                      StarCount=Int(3000)))
    lighting.add(Inst('BloomEffect', 'Bloom', Intensity=Float(0.65), Size=Float(30), Threshold=Float(1.6)))
    lighting.add(Inst('ColorCorrectionEffect', 'Grade', Brightness=Float(0.02), Contrast=Float(0.12),
                      Saturation=Float(0.08), TintColor=Color(*L['tint'])))
    lighting.add(Inst('SunRaysEffect', 'SunRays', Intensity=Float(0.06), Spread=Float(0.7)))

    # ---- ReplicatedStorage ----
    rs = Inst('ReplicatedStorage', 'ReplicatedStorage')
    remotes = Inst('Folder', 'Remotes')
    for nm in ('Action', 'FX', 'Private'):
        remotes.add(Inst('RemoteEvent', nm))
    remotes.add(Inst('UnreliableRemoteEvent', 'Aim'))
    rs.add(remotes)
    for c in src_children('ReplicatedStorage', manifest):
        rs.add(c)

    # ---- ServerScriptService ----
    sss = Inst('ServerScriptService', 'ServerScriptService')
    for c in src_children('ServerScriptService', manifest):
        sss.add(c)

    # ---- StarterPlayer ----
    sp = Inst('StarterPlayer', 'StarterPlayer',
              CameraMaxZoomDistance=Float(60), CameraMinZoomDistance=Float(4),
              CharacterWalkSpeed=Float(20), CharacterJumpHeight=Float(7.5), CharacterUseJumpPower=Bool(False),
              EnableMouseLockOption=Bool(True), LoadCharacterAppearance=Bool(False),
              HealthDisplayDistance=Float(0), NameDisplayDistance=Float(70), AutoJumpEnabled=Bool(False))
    for c in src_children('StarterPlayer', manifest):
        sp.add(c)
    sp.add(rig.build_r6())

    players = Inst('Players', 'Players', CharacterAutoLoads=Bool(False), RespawnTime=Float(4))
    sgui = Inst('StarterGui', 'StarterGui', ShowDevelopmentGui=Bool(True))
    sound = Inst('SoundService', 'SoundService', RespectFilteringEnabled=Bool(True), DistanceFactor=Float(3.33),
                 RolloffScale=Float(1))
    roots = [ws, lighting, rs, sss, sp, players, sgui, sound]
    return roots, manifest


def main():
    roots, manifest = build_place()
    xml = to_xml(roots)
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(xml)
    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1, sort_keys=True)
    nparts = sum(1 for r in roots for x in r.walk() if x.cls in ('Part', 'WedgePart', 'CornerWedgePart', 'SpawnLocation', 'TrussPart'))
    nscripts = sum(1 for r in roots for x in r.walk() if x.cls in ('Script', 'LocalScript', 'ModuleScript'))
    print('%s: %d КБ, деталей %d, скриптов %d' % (os.path.basename(OUT), len(xml.encode('utf-8')) // 1024, nparts, nscripts))


if __name__ == '__main__':
    main()
