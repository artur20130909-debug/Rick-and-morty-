# Карта арены (временная заготовка: плита и точки появления)
from rbxlx import Inst, Bool, Float, Int, Vec3, Color, Token, CF, cf, cf_pos, rgb


def P(name, size, cframe, color, material='SmoothPlastic', shape=None, transparency=0, collide=True, cls='Part', **extra):
    p = Inst(cls, name, Anchored=Bool(True), CanCollide=Bool(collide), Size=Vec3(*size), CFrame=CF(cframe),
             Color=Color(*color), Material=Token('Material', material),
             TopSurface=Token('SurfaceType', 'Smooth'), BottomSurface=Token('SurfaceType', 'Smooth'))
    if shape:
        p.set('Shape', Token('PartType', shape))
    if transparency:
        p.set('Transparency', Float(transparency))
    for k, v in extra.items():
        p.set(k, v)
    return p


def build_map():
    m = Inst('Model', 'Map')
    m.add(P('Ground', (512, 2, 512), cf_pos(0, -1, 0), rgb(92, 120, 70), 'Grass'))
    spawns = Inst('Folder', 'Spawns')
    for i, (x, z) in enumerate([(-40, -40), (40, -40), (-40, 40), (40, 40)]):
        spawns.add(P('Spawn%d' % (i + 1), (8, 1, 8), cf_pos(x, 0.5, z), rgb(80, 80, 90), 'Concrete',
                     cls='SpawnLocation', Neutral=Bool(True), Duration=Int(0), Transparency=Float(1), CanCollide=Bool(False)))
    m.add(spawns)
    markers = Inst('Folder', 'Markers')
    for i, (x, z) in enumerate([(-20, 30), (-12, 30), (-4, 30)]):
        markers.add(P('Dummy', (2, 1, 2), cf_pos(x, 0.5, z), rgb(255, 0, 0), transparency=1, collide=False))
    for i, (x, z) in enumerate([(60, 0), (-60, 0), (0, 60)]):
        markers.add(P('BotSpawn', (2, 1, 2), cf_pos(x, 0.5, z), rgb(0, 0, 255), transparency=1, collide=False))
    m.add(markers)
    br = Inst('Folder', 'Breakables')
    lamp = Inst('Model', 'Lamp')
    lamp.add(P('Pole', (0.6, 12, 0.6), cf_pos(10, 6, 10), rgb(40, 40, 46), 'Metal'))
    br.add(lamp)
    m.add(br)
    return {
        'map': m,
        'camera': (60, 40, 60, 0, 0, 0),
        'lighting': dict(brightness=3, time='15:20:00', latitude=35, ambient=rgb(70, 70, 82), outdoor=rgb(128, 128, 140),
                         exposure=0.1, shift_top=rgb(255, 236, 214), fog=rgb(190, 205, 220), atm_density=0.32,
                         atm_color=rgb(199, 214, 230), atm_decay=rgb(120, 130, 150), atm_glare=0.25, atm_haze=1.2,
                         tint=rgb(255, 250, 244)),
    }
